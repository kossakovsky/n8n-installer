#!/bin/bash
# =============================================================================
# update.sh - Main update orchestrator
# =============================================================================
# Performs a full system and service update:
#   1. Pulls latest changes from the git repository (git reset --hard + pull)
#   2. Updates Ubuntu system packages (apt-get update && upgrade)
#   3. Delegates to apply_update.sh for service updates
#
# This two-stage approach ensures apply_update.sh itself gets updated before
# running, so new update logic is always applied.
#
# Usage: make update  OR  sudo bash scripts/update.sh
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Path to the apply_update.sh script
APPLY_UPDATE_SCRIPT="$SCRIPT_DIR/apply_update.sh"

# Check if apply update script exists
if [ ! -f "$APPLY_UPDATE_SCRIPT" ]; then
    log_error "Crucial update script $APPLY_UPDATE_SCRIPT not found. Cannot proceed."
    exit 1
fi


log_info "Starting update process..."

# Pull the latest repository changes
log_info "Pulling latest repository changes..."
# Check if git is installed
if ! command -v git &> /dev/null; then
    log_warning "'git' command not found. Skipping repository update."
    # Decide if we should proceed without git pull or exit. Exiting is safer.
    log_error "Cannot proceed with update without git. Please install git."
    exit 1
    # Or, if allowing update without pull:
    # log_warning "Proceeding without pulling latest changes..."
else
    # Change to project root for git pull
    cd "$PROJECT_ROOT" || { log_error "Failed to change directory to $PROJECT_ROOT"; exit 1; }
    git reset --hard HEAD || { log_warning "Failed to reset repository. Continuing update with potentially unreset local changes..."; }
    git pull || { log_warning "Failed to pull latest repository changes. Continuing update with potentially old version of apply_update.sh..."; }
    # Change back to script dir or ensure apply_update.sh uses absolute paths or cd's itself
    # (apply_update.sh already handles cd to PROJECT_ROOT, so we're good)
fi

# Update Ubuntu packages before running apply_update
log_info "Updating system packages..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get upgrade -y
    log_info "System packages updated successfully."
else
    log_warning "'apt-get' not found. Skipping system package update. This is normal on non-debian systems."
fi


# Execute the rest of the update process using the (potentially updated) apply_update.sh
bash "$APPLY_UPDATE_SCRIPT"

# The final success message will now come from apply_update.sh
log_info "Update script finished." # Changed final message

exit 0