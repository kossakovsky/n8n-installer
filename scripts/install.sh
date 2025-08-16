#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Check for nested n8n-installer directory
current_path=$(pwd)
if [[ "$current_path" == *"/n8n-installer/n8n-installer" ]]; then
    log_info "Detected nested n8n-installer directory. Correcting..."
    cd ..
    log_info "Moved to $(pwd)"
    log_info "Removing redundant n8n-installer directory..."
    rm -rf "n8n-installer"
    log_info "Redundant directory removed."
    # Re-evaluate SCRIPT_DIR after potential path correction
    SCRIPT_DIR_REALPATH_TEMP="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    if [[ "$SCRIPT_DIR_REALPATH_TEMP" == *"/n8n-installer/n8n-installer/scripts" ]]; then
        # If SCRIPT_DIR is still pointing to the nested structure's scripts dir, adjust it
        # This happens if the script was invoked like: sudo bash n8n-installer/scripts/install.sh
        # from the outer n8n-installer directory.
        # We need to ensure that relative paths for other scripts are correct.
        # The most robust way is to re-execute the script from the corrected location
        # if the SCRIPT_DIR itself was nested.
        log_info "Re-executing install script from corrected path..."
        exec sudo bash "./scripts/install.sh" "$@"
    fi
fi

# Get the directory where this script is located (which is the scripts directory)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if all required scripts exist and are executable in the current directory
required_scripts=(
    "01_system_preparation.sh"
    "02_install_docker.sh"
    "03_generate_secrets.sh"
    "04_wizard.sh"
    "05_run_services.sh"
    "06_final_report.sh"
)

missing_scripts=()
non_executable_scripts=()

for script in "${required_scripts[@]}"; do
    # Check directly in the current directory (SCRIPT_DIR)
    script_path="$SCRIPT_DIR/$script"
    if [ ! -f "$script_path" ]; then
        missing_scripts+=("$script")
    elif [ ! -x "$script_path" ]; then
        non_executable_scripts+=("$script")
    fi
done

if [ ${#missing_scripts[@]} -gt 0 ]; then
    # Update error message to reflect current directory check
    log_error "The following required scripts are missing in $SCRIPT_DIR:"
    printf " - %s\n" "${missing_scripts[@]}"
    exit 1
fi

# Attempt to make scripts executable if they are not
if [ ${#non_executable_scripts[@]} -gt 0 ]; then
    log_warning "The following scripts were not executable and will be made executable:"
    printf " - %s\n" "${non_executable_scripts[@]}"
    # Make all .sh files in the current directory executable
    chmod +x "$SCRIPT_DIR"/*.sh
    # Re-check after chmod
    for script in "${non_executable_scripts[@]}"; do
         script_path="$SCRIPT_DIR/$script"
         if [ ! -x "$script_path" ]; then
            # Update error message
            log_error "Failed to make '$script' in $SCRIPT_DIR executable. Please check permissions."
            exit 1
         fi
    done
    log_success "Scripts successfully made executable."
fi

# ------------------ OPTIONAL WORDPRESS ADDER (function) ------------------
# Эта функция добавляет WordPress-сайт на отдельном домене/поддомене.
# Вызывается ПОСЛЕ запуска базовых сервисов (Caddy, и т.п.), но ДО финального отчёта.
add_website_interactive() {
  echo
  read -r -p "Добавить WordPress-сайт на отдельном домене/поддомене? (y/N): " ADD_WP
  if [[ ! "${ADD_WP}" =~ ^[Yy]$ ]]; then
    return 0
  fi

  # Переходим в корень репозитория для работы с .env / Caddyfile / compose
  pushd "$REPO_ROOT" >/dev/null

  # Попробуем подтянуть PRIMARY_DOMAIN из .env, если он там уже есть
  if [[ -z "${PRIMARY_DOMAIN:-}" && -f ".env" ]]; then
    # shellcheck disable=SC1090
    source ./.env || true
  fi

  # Предложим домен с подсказкой
  local hint_domain="site.${PRIMARY_DOMAIN:-yourdomain.com}"
  read -r -p "Введите домен для сайта (например, ${hint_domain}): " WP_DOMAIN
  if [[ -z "$WP_DOMAIN" ]]; then
    echo "Домен не задан, пропуск..."
    popd >/dev/null
    return 0
  fi

  # Проверка наличия openssl (обычно ставится на шаге подготовки системы)
  if ! command -v openssl >/dev/null 2>&1; then
    log_warning "openssl не найден — установлю."
    sudo apt-get update -y && sudo apt-get install -y openssl
  fi

  # Генерируем пароли БД
  WP_DB_PASS=$(openssl rand -base64 24 | tr -d '=+/')
  WP_DB_ROOT_PASS=$(openssl rand -base64 24 | tr -d '=+/')

  # Убедимся, что есть .env
  if [[ ! -f ".env" && -f ".env.example" ]]; then
    cp .env.example .env
  fi
  if [[ ! -f ".env" ]]; then
    touch .env
  fi

  # Обновляем .env (idempotent)
  sed -i "/^WORDPRESS_DOMAIN=/d" .env || true
  sed -i "/^WORDPRESS_DB_NAME=/d" .env || true
  sed -i "/^WORDPRESS_DB_USER=/d" .env || true
  sed -i "/^WORDPRESS_DB_PASSWORD=/d" .env || true
  sed -i "/^WORDPRESS_DB_ROOT_PASSWORD=/d" .env || true
  {
    echo "WORDPRESS_DOMAIN=${WP_DOMAIN}"
    echo "WORDPRESS_DB_NAME=${WORDPRESS_DB_NAME:-wordpress}"
    echo "WORDPRESS_DB_USER=${WORDPRESS_DB_USER:-wpuser}"
    echo "WORDPRESS_DB_PASSWORD=${WP_DB_PASS}"
    echo "WORDPRESS_DB_ROOT_PASSWORD=${WP_DB_ROOT_PASS}"
  } >> .env

  # Убедимся, что существует Caddyfile
  if [[ ! -f "Caddyfile" ]]; then
    touch Caddyfile
  fi

  # Добавим блок домена в Caddyfile, если его ещё нет
  if ! grep -q "${WP_DOMAIN}" Caddyfile; then
    cat >> Caddyfile <<EOF

# ------------------------------------------------------------------------------
# WordPress site (${WP_DOMAIN})
# ------------------------------------------------------------------------------
www.${WP_DOMAIN} {
  redir https://${WP_DOMAIN}{uri}
}

${WP_DOMAIN} {
  encode zstd gzip

  @acme {
    path /.well-known/acme-challenge/*
  }
  handle @acme {
    respond "OK" 200
  }

  reverse_proxy wordpress:80

  header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    X-Frame-Options "SAMEORIGIN"
    X-Content-Type-Options "nosniff"
    Referrer-Policy "no-referrer-when-downgrade"
  }
}
EOF
  fi

  # Запуск профиля WordPress
  log_info "Запускаю WordPress (docker compose --profile wordpress up -d)..."
  docker compose --profile wordpress up -d

  echo
  log_success "Готово! WordPress: https://${WP_DOMAIN}"
  echo "DB user: ${WORDPRESS_DB_USER:-wpuser}"
  echo "DB pass: ${WP_DB_PASS}"
  echo "DB root pass: ${WP_DB_ROOT_PASS}"

  popd >/dev/null
}
# ---------------- END OPTIONAL WORDPRESS ADDER (function) ----------------

# Run installation steps sequentially using their full paths

log_info "========== STEP 1: System Preparation =========="
bash "$SCRIPT_DIR/01_system_preparation.sh" || { log_error "System Preparation failed"; exit 1; }
log_success "System preparation complete!"

log_info "========== STEP 2: Installing Docker =========="
bash "$SCRIPT_DIR/02_install_docker.sh" || { log_error "Docker Installation failed"; exit 1; }
log_success "Docker installation complete!"

log_info "========== STEP 3: Generating Secrets and Configuration =========="
bash "$SCRIPT_DIR/03_generate_secrets.sh" || { log_error "Secret/Config Generation failed"; exit 1; }
log_success "Secret/Config Generation complete!"

log_info "========== STEP 4: Running Service Selection Wizard =========="
bash "$SCRIPT_DIR/04_wizard.sh" || { log_error "Service Selection Wizard failed"; exit 1; }
log_success "Service Selection Wizard complete!"

log_info "========== STEP 5: Running Services =========="
bash "$SCRIPT_DIR/05_run_services.sh" || { log_error "Running Services failed"; exit 1; }
log_success "Running Services complete!"

# >>>>>>> Наш дополнительный шаг: предложение добавить WordPress-сайт
add_website_interactive
# <<<<<<< конец дополнительного шага

log_info "========== STEP 6: Generating Final Report =========="
# --- Installation Summary ---
log_info "Installation Summary. The following steps were performed by the scripts:"
log_success "- System updated and basic utilities installed"
log_success "- Firewall (UFW) configured and enabled"
log_success "- Fail2Ban activated for brute-force protection"
log_success "- Automatic security updates enabled"
log_success "- Docker and Docker Compose installed"
log_success "- '.env' generated with secure passwords and secrets"
log_success "- Services launched via Docker Compose"

bash "$SCRIPT_DIR/06_final_report.sh" || { log_error "Final Report Generation failed"; exit 1; }
log_success "Final Report Generation complete!"

exit 0
