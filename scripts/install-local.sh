#!/bin/bash
# =============================================================================
# install-local.sh - Local installation for n8n-install
# =============================================================================
# Runs the local development installation process (6 steps):
#   1. Secret Generation - generates passwords, API keys, bcrypt hashes
#   2. Service Selection Wizard - interactive service selection
#   3. Configure Services - service-specific configuration
#   4. Run Services - starts Docker Compose stack
#   5. Final Report - displays credentials and URLs
#   6. Fix Permissions - fixes file permissions
#
# Requirements:
#   - Docker and Docker Compose installed and running
#   - Bash 4.0+ (macOS: brew install bash)
#   - whiptail (macOS: brew install newt)
#   - openssl, git, python3
#
# Usage:
#   make install-local
#   Or directly: bash scripts/install-local.sh
# =============================================================================

# =============================================================================
# Check bash version FIRST (requires bash 4+ for associative arrays)
# =============================================================================
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "[ERROR] Bash 4.0 or higher is required. Current version: $BASH_VERSION"
    echo ""
    echo "On macOS, install modern bash and run with it:"
    echo "  brew install bash"
    echo "  /opt/homebrew/bin/bash ./scripts/install-local.sh"
    echo ""
    echo "Or use: make install-local"
    exit 1
fi

set -e

# Local mode is fixed for this script
export INSTALL_MODE="local"

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Initialize paths
init_paths

# Source local mode utilities
source "$SCRIPT_DIR/local.sh"

# Source telemetry functions
source "$SCRIPT_DIR/telemetry.sh"

# =============================================================================
# Prerequisites Check (inline)
# =============================================================================
check_prerequisites() {
    log_subheader "Checking Prerequisites for Local Installation"

    local MISSING_DEPS=()

    # Check Docker
    log_info "Checking Docker..."
    if ! command -v docker &> /dev/null; then
        MISSING_DEPS+=("docker")
        print_error "Docker is not installed"
        case "$(uname)" in
            Darwin)
                log_info "  Install Docker Desktop: https://www.docker.com/products/docker-desktop"
                ;;
            Linux)
                log_info "  Install Docker: https://docs.docker.com/engine/install/"
                ;;
            MINGW*|MSYS*|CYGWIN*)
                log_info "  Install Docker Desktop for Windows: https://www.docker.com/products/docker-desktop"
                log_info "  Then enable WSL2 integration in Docker Desktop settings"
                ;;
        esac
    else
        local docker_version
        docker_version=$(docker --version 2>/dev/null || echo "unknown")
        print_ok "Docker is installed: $docker_version"

        # Check Docker daemon
        if ! docker info > /dev/null 2>&1; then
            MISSING_DEPS+=("docker-daemon")
            print_error "Docker daemon is not running"
            case "$(uname)" in
                Darwin)
                    log_info "  Start Docker Desktop from Applications"
                    ;;
                Linux)
                    log_info "  Start Docker: sudo systemctl start docker"
                    ;;
            esac
        else
            print_ok "Docker daemon is running"
        fi
    fi

    # Check Docker Compose
    log_info "Checking Docker Compose..."
    if ! docker compose version &> /dev/null 2>&1; then
        MISSING_DEPS+=("docker-compose")
        print_error "Docker Compose plugin is not installed"
        log_info "  Docker Compose should be included with Docker Desktop"
        log_info "  Or install: https://docs.docker.com/compose/install/"
    else
        local compose_version
        compose_version=$(docker compose version 2>/dev/null || echo "unknown")
        print_ok "Docker Compose is installed: $compose_version"
    fi

    # Check whiptail
    log_info "Checking whiptail..."
    if ! command -v whiptail &> /dev/null; then
        MISSING_DEPS+=("whiptail")
        print_error "whiptail is not installed"
        case "$(uname)" in
            Darwin)
                log_info "  Install with: brew install newt"
                ;;
            Linux)
                if command -v apt-get &> /dev/null; then
                    log_info "  Install with: sudo apt-get install -y whiptail"
                elif command -v yum &> /dev/null; then
                    log_info "  Install with: sudo yum install -y newt"
                elif command -v pacman &> /dev/null; then
                    log_info "  Install with: sudo pacman -S libnewt"
                else
                    log_info "  Install the 'newt' or 'whiptail' package for your distribution"
                fi
                ;;
        esac
    else
        print_ok "whiptail is installed"
    fi

    # Check openssl
    log_info "Checking openssl..."
    if ! command -v openssl &> /dev/null; then
        MISSING_DEPS+=("openssl")
        print_error "openssl is not installed"
        case "$(uname)" in
            Darwin)
                log_info "  openssl should be pre-installed on macOS"
                log_info "  Or install with: brew install openssl"
                ;;
            Linux)
                if command -v apt-get &> /dev/null; then
                    log_info "  Install with: sudo apt-get install -y openssl"
                elif command -v yum &> /dev/null; then
                    log_info "  Install with: sudo yum install -y openssl"
                else
                    log_info "  Install openssl for your distribution"
                fi
                ;;
        esac
    else
        local openssl_version
        openssl_version=$(openssl version 2>/dev/null || echo "unknown")
        print_ok "openssl is installed: $openssl_version"
    fi

    # Check git
    log_info "Checking git..."
    if ! command -v git &> /dev/null; then
        MISSING_DEPS+=("git")
        print_error "git is not installed"
        log_info "  Install git: https://git-scm.com/downloads"
    else
        local git_version
        git_version=$(git --version 2>/dev/null || echo "unknown")
        print_ok "git is installed: $git_version"
    fi

    # Check Python3 and required modules
    log_info "Checking Python3..."
    if ! command -v python3 &> /dev/null; then
        MISSING_DEPS+=("python3")
        print_error "Python3 is not installed"
        log_info "  Install Python3: https://www.python.org/downloads/"
    else
        local python_version
        python_version=$(python3 --version 2>/dev/null || echo "unknown")
        print_ok "Python3 is installed: $python_version"

        # Check and install required Python modules
        local PYTHON_MODULES=("yaml:pyyaml" "dotenv:python-dotenv")
        for module_pair in "${PYTHON_MODULES[@]}"; do
            local import_name="${module_pair%%:*}"
            local package_name="${module_pair##*:}"
            log_info "Checking Python module: $package_name..."
            if ! python3 -c "import $import_name" 2>/dev/null; then
                print_warning "$package_name not found. Installing..."
                if python3 -m pip install --user "$package_name" 2>/dev/null; then
                    print_ok "$package_name installed successfully"
                else
                    MISSING_DEPS+=("$package_name")
                    print_error "Failed to install $package_name"
                    log_info "  Install manually: pip3 install $package_name"
                fi
            else
                print_ok "$package_name is available"
            fi
        done
    fi

    # Summary
    echo ""
    if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${MISSING_DEPS[*]}"
        log_info "Please install the missing dependencies and try again."
        return 1
    else
        log_success "All prerequisites are satisfied!"
        return 0
    fi
}

# Setup error telemetry trap for tracking failures
setup_error_telemetry_trap

# Generate installation ID for telemetry correlation
INSTALLATION_ID=$(get_installation_id)
export INSTALLATION_ID

# Send telemetry: installation started
send_telemetry "install_start"

# Check required scripts
required_scripts=(
    "03_generate_secrets.sh"
    "04_wizard.sh"
    "05_configure_services.sh"
    "06_run_services.sh"
    "07_final_report.sh"
    "08_fix_permissions.sh"
)

missing_scripts=()
for script in "${required_scripts[@]}"; do
    script_path="$SCRIPT_DIR/$script"
    if [ ! -f "$script_path" ]; then
        missing_scripts+=("$script")
    fi
done

if [ ${#missing_scripts[@]} -gt 0 ]; then
    log_error "The following required scripts are missing in $SCRIPT_DIR:"
    printf " - %s\n" "${missing_scripts[@]}"
    exit 1
fi

# Make scripts executable
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# =============================================================================
# Run Local installation steps sequentially (6 steps total)
# =============================================================================
TOTAL_STEPS=6

log_header "Local Installation"
log_info "Starting local development installation..."

# Step 1: Prerequisites Check (inline)
show_step 1 $TOTAL_STEPS "Checking Prerequisites"
check_prerequisites || { log_error "Prerequisites check failed"; exit 1; }
log_success "Prerequisites check complete!"

# Pull Caddy image for bcrypt hash generation
log_info "Pulling Caddy image for password hashing..."
docker pull caddy:latest 2>/dev/null || log_warning "Could not pull Caddy image, will try during installation"

# Step 2: Secrets Generation
show_step 2 $TOTAL_STEPS "Generating Secrets and Configuration"
set_telemetry_stage "secrets_gen"
"$BASH" "$SCRIPT_DIR/03_generate_secrets.sh" || { log_error "Secret/Config Generation failed"; exit 1; }
log_success "Secret/Config Generation complete!"

# Step 3: Service Selection Wizard
show_step 3 $TOTAL_STEPS "Running Service Selection Wizard"
set_telemetry_stage "wizard"
"$BASH" "$SCRIPT_DIR/04_wizard.sh" || { log_error "Service Selection Wizard failed"; exit 1; }
log_success "Service Selection Wizard complete!"

# Step 4: Configure Services
show_step 4 $TOTAL_STEPS "Configure Services"
set_telemetry_stage "configure"
"$BASH" "$SCRIPT_DIR/05_configure_services.sh" || { log_error "Configure Services failed"; exit 1; }
log_success "Configure Services complete!"

# Step 5: Running Services
show_step 5 $TOTAL_STEPS "Running Services"
set_telemetry_stage "db_init"
# Start PostgreSQL first to initialize databases before other services
log_info "Starting PostgreSQL..."
docker compose -p localai up -d postgres || { log_error "Failed to start PostgreSQL"; exit 1; }

# Initialize PostgreSQL databases for services (creates if not exist)
source "$SCRIPT_DIR/databases.sh"
init_all_databases || { log_warning "Database initialization had issues, but continuing..."; }

# Now start all services (postgres is already running)
set_telemetry_stage "services_start"
"$BASH" "$SCRIPT_DIR/06_run_services.sh" || { log_error "Running Services failed"; exit 1; }
log_success "Running Services complete!"

# Step 6: Final Report
show_step 6 $TOTAL_STEPS "Generating Final Report"
set_telemetry_stage "final_report"
log_info "Installation Summary:"
echo -e "  ${GREEN}*${NC} Prerequisites verified (Docker, whiptail, openssl, git)"
echo -e "  ${GREEN}*${NC} Local installation mode configured (.local domains)"
echo -e "  ${GREEN}*${NC} '.env' generated with secure passwords and secrets"
echo -e "  ${GREEN}*${NC} Services launched via Docker Compose"

"$BASH" "$SCRIPT_DIR/07_final_report.sh" || { log_error "Final Report Generation failed"; exit 1; }
log_success "Final Report generated!"

# Fix Permissions (run silently, not as a numbered step for local)
set_telemetry_stage "fix_perms"
"$BASH" "$SCRIPT_DIR/08_fix_permissions.sh" || { log_warning "Fix Permissions had issues"; }

log_success "Local installation complete!"

# Send telemetry: installation completed with selected services
send_telemetry "install_complete" "$(read_env_var COMPOSE_PROFILES)"

exit 0
