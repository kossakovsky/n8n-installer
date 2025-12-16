#!/bin/bash
# =============================================================================
# install.sh - Main installation orchestrator for n8n-install
# =============================================================================
# This script runs the complete installation process by sequentially executing
# 8 installation steps:
#   1. System Preparation - updates packages, installs utilities, configures firewall
#   2. Docker Installation - installs Docker and Docker Compose
#   3. Secret Generation - creates .env file with secure passwords and secrets
#   4. Service Wizard - interactive service selection using whiptail
#   5. Service Configuration - prompts for API keys and service-specific settings
#   6. Service Launch - starts all selected services via Docker Compose
#   7. Final Report - displays credentials and access URLs
#   8. Fix Permissions - ensures correct file ownership for the invoking user
#
# Usage: sudo bash scripts/install.sh
# =============================================================================

set -e

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

# Run installation steps sequentially using their full paths

show_step 1 8 "System Preparation"
bash "$SCRIPT_DIR/01_system_preparation.sh" || { log_error "System Preparation failed"; exit 1; }
log_success "System preparation complete!"

show_step 2 8 "Installing Docker"
bash "$SCRIPT_DIR/02_install_docker.sh" || { log_error "Docker Installation failed"; exit 1; }
log_success "Docker installation complete!"

show_step 3 8 "Generating Secrets and Configuration"
bash "$SCRIPT_DIR/03_generate_secrets.sh" || { log_error "Secret/Config Generation failed"; exit 1; }
log_success "Secret/Config Generation complete!"

show_step 4 8 "Running Service Selection Wizard"
bash "$SCRIPT_DIR/04_wizard.sh" || { log_error "Service Selection Wizard failed"; exit 1; }
log_success "Service Selection Wizard complete!"

show_step 5 8 "Configure Services"
bash "$SCRIPT_DIR/05_configure_services.sh" || { log_error "Configure Services failed"; exit 1; }
log_success "Configure Services complete!"

show_step 6 8 "Running Services"
bash "$SCRIPT_DIR/06_run_services.sh" || { log_error "Running Services failed"; exit 1; }
log_success "Running Services complete!"

show_step 7 8 "Generating Final Report"
# --- Installation Summary ---
log_info "Installation Summary:"
echo -e "  ${GREEN}*${NC} System updated and basic utilities installed"
echo -e "  ${GREEN}*${NC} Firewall (UFW) configured and enabled"
echo -e "  ${GREEN}*${NC} Fail2Ban activated for brute-force protection"
echo -e "  ${GREEN}*${NC} Automatic security updates enabled"
echo -e "  ${GREEN}*${NC} Docker and Docker Compose installed"
echo -e "  ${GREEN}*${NC} '.env' generated with secure passwords and secrets"
echo -e "  ${GREEN}*${NC} Services launched via Docker Compose"

bash "$SCRIPT_DIR/07_final_report.sh" || { log_error "Final Report Generation failed"; exit 1; }
log_success "Final Report generated!"

show_step 8 8 "Fixing File Permissions"
bash "$SCRIPT_DIR/08_fix_permissions.sh" || { log_error "Fix Permissions failed"; exit 1; }
log_success "File permissions fixed!"

log_success "Installation complete!"

exit 0