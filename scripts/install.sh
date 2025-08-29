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

# Check if all required scripts exist and are executable in the current directory
required_scripts=(
    "01_system_preparation.sh"
    "02_install_docker.sh"
    "03_generate_secrets.sh"
    "04_wizard.sh"
    "05_configure_services.sh"
    "06_run_services.sh"
    "07_final_report.sh"
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

log_info "========== STEP 5: Configure Services =========="
bash "$SCRIPT_DIR/05_configure_services.sh" || { log_error "Configure Services failed"; exit 1; }
log_success "Configure Services complete!"

log_info "========== STEP 6: Running Services =========="
bash "$SCRIPT_DIR/06_run_services.sh" || { log_error "Running Services failed"; exit 1; }
log_success "Running Services complete!"

log_info "========== STEP 7: Generating Final Report =========="
# --- Installation Summary ---
log_info "Installation Summary. The following steps were performed by the scripts:"
log_success "- System updated and basic utilities installed"
log_success "- Firewall (UFW) configured and enabled"
log_success "- Fail2Ban activated for brute-force protection"
log_success "- Automatic security updates enabled"
log_success "- Docker and Docker Compose installed"
log_success "- '.env' generated with secure passwords and secrets"
log_success "- Services launched via Docker Compose"

bash "$SCRIPT_DIR/07_final_report.sh" || { log_error "Final Report Generation failed"; exit 1; }
log_success "Final Report Generation complete!"

exit 0 