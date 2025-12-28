#!/bin/bash
# =============================================================================
# install-vps.sh - VPS installation orchestrator for n8n-install
# =============================================================================
# Runs the complete VPS installation process:
#   1. System Preparation - updates packages, installs utilities, configures firewall
#   2. Docker Installation - installs Docker and Docker Compose
#   3. Secret Generation - generates passwords, API keys, bcrypt hashes
#   4. Service Selection Wizard - interactive service selection
#   5. Configure Services - service-specific configuration
#   6. Run Services - starts Docker Compose stack
#   7. Final Report - displays credentials and URLs
#   8. Fix Permissions - fixes file ownership
#
# Usage: sudo bash scripts/install-vps.sh
# Note: This script should be called from install.sh (entry point)
# =============================================================================

set -e

# VPS mode is fixed for this script
export INSTALL_MODE="vps"

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Initialize paths
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
# Run VPS installation steps sequentially (8 steps total)
# =============================================================================
TOTAL_STEPS=8

log_header "VPS Installation"
log_info "Starting VPS installation..."

# Step 1: System Preparation
show_step 1 $TOTAL_STEPS "System Preparation"
set_telemetry_stage "system_prep"
"$BASH" "$SCRIPT_DIR/01_system_preparation.sh" || { log_error "System Preparation failed"; exit 1; }
log_success "System preparation complete!"

# Step 2: Docker Installation
show_step 2 $TOTAL_STEPS "Installing Docker"
set_telemetry_stage "docker_install"
"$BASH" "$SCRIPT_DIR/02_install_docker.sh" || { log_error "Docker Installation failed"; exit 1; }
log_success "Docker installation complete!"

# Step 3: Secrets Generation
show_step 3 $TOTAL_STEPS "Generating Secrets and Configuration"
set_telemetry_stage "secrets_gen"
"$BASH" "$SCRIPT_DIR/03_generate_secrets.sh" || { log_error "Secret/Config Generation failed"; exit 1; }
log_success "Secret/Config Generation complete!"

# Step 4: Service Selection Wizard
show_step 4 $TOTAL_STEPS "Running Service Selection Wizard"
set_telemetry_stage "wizard"
"$BASH" "$SCRIPT_DIR/04_wizard.sh" || { log_error "Service Selection Wizard failed"; exit 1; }
log_success "Service Selection Wizard complete!"

# Step 5: Configure Services
show_step 5 $TOTAL_STEPS "Configure Services"
set_telemetry_stage "configure"
"$BASH" "$SCRIPT_DIR/05_configure_services.sh" || { log_error "Configure Services failed"; exit 1; }
log_success "Configure Services complete!"

# Step 6: Running Services
show_step 6 $TOTAL_STEPS "Running Services"
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

# Step 7: Final Report
show_step 7 $TOTAL_STEPS "Generating Final Report"
set_telemetry_stage "final_report"
log_info "Installation Summary:"
echo -e "  ${GREEN}*${NC} System updated and basic utilities installed"
echo -e "  ${GREEN}*${NC} Firewall (UFW) configured and enabled"
echo -e "  ${GREEN}*${NC} Fail2Ban activated for brute-force protection"
echo -e "  ${GREEN}*${NC} Automatic security updates enabled"
echo -e "  ${GREEN}*${NC} Docker and Docker Compose installed"
echo -e "  ${GREEN}*${NC} '.env' generated with secure passwords and secrets"
echo -e "  ${GREEN}*${NC} Services launched via Docker Compose"

"$BASH" "$SCRIPT_DIR/07_final_report.sh" || { log_error "Final Report Generation failed"; exit 1; }
log_success "Final Report generated!"

# Step 8: Fix Permissions
show_step 8 $TOTAL_STEPS "Fixing File Permissions"
set_telemetry_stage "fix_perms"
"$BASH" "$SCRIPT_DIR/08_fix_permissions.sh" || { log_error "Fix Permissions failed"; exit 1; }
log_success "File permissions fixed!"

log_success "Installation complete!"

# Send telemetry: installation completed with selected services
send_telemetry "install_complete" "$(read_env_var COMPOSE_PROFILES)"

exit 0
