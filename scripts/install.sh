#!/bin/bash
# =============================================================================
# install.sh - Main installation orchestrator for n8n-install
# =============================================================================
# This script runs the complete installation process by sequentially executing
# installation steps. The steps vary based on installation mode:
#
# VPS Mode (production with SSL):
#   1. System Preparation - updates packages, installs utilities, configures firewall
#   2. Docker Installation - installs Docker and Docker Compose
#   3-8. Secret generation, wizard, configuration, launch, report, permissions
#
# Local Mode (.local domains, HTTP only):
#   1. Prerequisites Check - verifies Docker, whiptail, openssl, git are installed
#   2-7. Secret generation, wizard, configuration, launch, report, permissions
#
# Usage:
#   VPS:   sudo bash scripts/install.sh
#   Local: bash scripts/install.sh
# =============================================================================

set -e

# Check bash version (requires bash 4+ for associative arrays)
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "[ERROR] Bash 4.0 or higher is required. Current version: $BASH_VERSION"
    echo ""
    echo "On macOS, install modern bash and run with it:"
    echo "  brew install bash"
    echo "  /opt/homebrew/bin/bash ./scripts/install.sh"
    echo ""
    echo "Or add it to your PATH and run without full path."
    exit 1
fi

# Parse command line arguments
DEFAULT_MODE="vps"
for arg in "$@"; do
    case $arg in
        --mode=*)
            DEFAULT_MODE="${arg#*=}"
            ;;
    esac
done

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Check for nested n8n-install directory
current_path=$(pwd)
if [[ "$current_path" == *"/n8n-install/n8n-install" ]]; then
    log_info "Detected nested n8n-install directory. Correcting..."
    cd ..
    log_info "Moved to $(pwd)"
    log_info "Removing redundant n8n-install directory..."
    rm -rf "n8n-install"
    log_info "Redundant directory removed."
    # Re-evaluate SCRIPT_DIR after potential path correction
    SCRIPT_DIR_REALPATH_TEMP="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    if [[ "$SCRIPT_DIR_REALPATH_TEMP" == *"/n8n-install/n8n-install/scripts" ]]; then
        # If SCRIPT_DIR is still pointing to the nested structure's scripts dir, adjust it
        # This happens if the script was invoked like: sudo bash n8n-install/scripts/install.sh
        # from the outer n8n-install directory.
        # We need to ensure that relative paths for other scripts are correct.
        # The most robust way is to re-execute the script from the corrected location
        # if the SCRIPT_DIR itself was nested.
        log_info "Re-executing install script from corrected path..."
        exec sudo bash "./scripts/install.sh" "$@"
    fi
fi

# Initialize paths using utils.sh helper
init_paths

# Source telemetry functions
source "$SCRIPT_DIR/telemetry.sh"

# Setup error telemetry trap for tracking failures
setup_error_telemetry_trap

# Generate installation ID for telemetry correlation (before .env exists)
# This ID will be saved to .env by 03_generate_secrets.sh
INSTALLATION_ID=$(get_installation_id)
export INSTALLATION_ID

# Send telemetry: installation started
send_telemetry "install_start"

# Check if all required scripts exist and are executable in the current directory
required_scripts=(
    "01_system_preparation.sh"
    "02_install_docker.sh"
    "03_generate_secrets.sh"
    "04_wizard.sh"
    "05_configure_services.sh"
    "06_run_services.sh"
    "07_final_report.sh"
    "08_fix_permissions.sh"
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

# =============================================================================
# Installation Mode Selection
# =============================================================================
log_header "Installation Mode"

# Require whiptail for mode selection
if ! command -v whiptail &> /dev/null; then
    log_error "whiptail is required but not found."
    log_info "Please install whiptail first:"
    log_info "  macOS: brew install newt"
    log_info "  Linux: sudo apt-get install -y whiptail"
    exit 1
fi

# Set selection based on DEFAULT_MODE
if [ "$DEFAULT_MODE" = "local" ]; then
    VPS_SELECTED="OFF"
    LOCAL_SELECTED="ON"
else
    VPS_SELECTED="ON"
    LOCAL_SELECTED="OFF"
fi

INSTALL_MODE=$(wt_radiolist "Installation Mode" \
    "Choose your installation environment:" \
    "$DEFAULT_MODE" \
    "vps" "VPS/Production - Real domain with Let's Encrypt SSL" "$VPS_SELECTED" \
    "local" "Local Installation - .local domains, HTTP only" "$LOCAL_SELECTED") || true

if [ -z "$INSTALL_MODE" ]; then
    log_error "Installation mode not selected. Exiting."
    exit 1
fi

export INSTALL_MODE
log_info "Installation mode: $INSTALL_MODE"

# Determine total steps based on mode
if [ "$INSTALL_MODE" = "local" ]; then
    TOTAL_STEPS=7
else
    TOTAL_STEPS=8
fi

# =============================================================================
# Run installation steps sequentially
# =============================================================================

if [ "$INSTALL_MODE" = "vps" ]; then
    # VPS Mode: Full system preparation and Docker installation
    show_step 1 $TOTAL_STEPS "System Preparation"
    set_telemetry_stage "system_prep"
    "$BASH" "$SCRIPT_DIR/01_system_preparation.sh" || { log_error "System Preparation failed"; exit 1; }
    log_success "System preparation complete!"

    show_step 2 $TOTAL_STEPS "Installing Docker"
    set_telemetry_stage "docker_install"
    "$BASH" "$SCRIPT_DIR/02_install_docker.sh" || { log_error "Docker Installation failed"; exit 1; }
    log_success "Docker installation complete!"

    STEP_OFFSET=2
else
    # Local Mode: Just check prerequisites
    show_step 1 $TOTAL_STEPS "Checking Prerequisites"
    "$BASH" "$SCRIPT_DIR/00_check_prerequisites.sh" || { log_error "Prerequisites check failed"; exit 1; }
    log_success "Prerequisites check complete!"

    # Pull Caddy image for bcrypt hash generation
    log_info "Pulling Caddy image for password hashing..."
    docker pull caddy:latest 2>/dev/null || log_warning "Could not pull Caddy image, will try during installation"

    STEP_OFFSET=1
fi

CURRENT_STEP=$((STEP_OFFSET + 1))
show_step $CURRENT_STEP $TOTAL_STEPS "Generating Secrets and Configuration"
set_telemetry_stage "secrets_gen"
"$BASH" "$SCRIPT_DIR/03_generate_secrets.sh" || { log_error "Secret/Config Generation failed"; exit 1; }
log_success "Secret/Config Generation complete!"

CURRENT_STEP=$((STEP_OFFSET + 2))
show_step $CURRENT_STEP $TOTAL_STEPS "Running Service Selection Wizard"
set_telemetry_stage "wizard"
"$BASH" "$SCRIPT_DIR/04_wizard.sh" || { log_error "Service Selection Wizard failed"; exit 1; }
log_success "Service Selection Wizard complete!"

CURRENT_STEP=$((STEP_OFFSET + 3))
show_step $CURRENT_STEP $TOTAL_STEPS "Configure Services"
set_telemetry_stage "configure"
"$BASH" "$SCRIPT_DIR/05_configure_services.sh" || { log_error "Configure Services failed"; exit 1; }
log_success "Configure Services complete!"

CURRENT_STEP=$((STEP_OFFSET + 4))
show_step $CURRENT_STEP $TOTAL_STEPS "Running Services"
set_telemetry_stage "db_init"
# Start PostgreSQL first to initialize databases before other services
log_info "Starting PostgreSQL..."
docker compose -p localai up -d postgres || { log_error "Failed to start PostgreSQL"; exit 1; }

# Initialize PostgreSQL databases for services (creates if not exist)
# This must run BEFORE other services that depend on these databases
source "$SCRIPT_DIR/databases.sh"
init_all_databases || { log_warning "Database initialization had issues, but continuing..."; }

# Now start all services (postgres is already running)
set_telemetry_stage "services_start"
"$BASH" "$SCRIPT_DIR/06_run_services.sh" || { log_error "Running Services failed"; exit 1; }
log_success "Running Services complete!"

CURRENT_STEP=$((STEP_OFFSET + 5))
show_step $CURRENT_STEP $TOTAL_STEPS "Generating Final Report"
set_telemetry_stage "final_report"
# --- Installation Summary ---
log_info "Installation Summary:"
if [ "$INSTALL_MODE" = "vps" ]; then
    echo -e "  ${GREEN}*${NC} System updated and basic utilities installed"
    echo -e "  ${GREEN}*${NC} Firewall (UFW) configured and enabled"
    echo -e "  ${GREEN}*${NC} Fail2Ban activated for brute-force protection"
    echo -e "  ${GREEN}*${NC} Automatic security updates enabled"
    echo -e "  ${GREEN}*${NC} Docker and Docker Compose installed"
else
    echo -e "  ${GREEN}*${NC} Prerequisites verified (Docker, whiptail, openssl, git)"
    echo -e "  ${GREEN}*${NC} Local installation mode configured (.local domains)"
fi
echo -e "  ${GREEN}*${NC} '.env' generated with secure passwords and secrets"
echo -e "  ${GREEN}*${NC} Services launched via Docker Compose"

"$BASH" "$SCRIPT_DIR/07_final_report.sh" || { log_error "Final Report Generation failed"; exit 1; }
log_success "Final Report generated!"

CURRENT_STEP=$((STEP_OFFSET + 6))
show_step $CURRENT_STEP $TOTAL_STEPS "Fixing File Permissions"
set_telemetry_stage "fix_perms"
"$BASH" "$SCRIPT_DIR/08_fix_permissions.sh" || { log_error "Fix Permissions failed"; exit 1; }
log_success "File permissions fixed!"

log_success "Installation complete!"

# Send telemetry: installation completed with selected services
send_telemetry "install_complete" "$(read_env_var COMPOSE_PROFILES)"

exit 0
