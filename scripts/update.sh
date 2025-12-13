#!/bin/bash
# =============================================================================
# update.sh - Main update orchestrator
# =============================================================================
# Performs a full system and service update:
#   1. Backs up user-customizable directories (e.g., python-runner/)
#   2. Pulls latest changes from the git repository (git reset --hard + pull)
#   3. Restores backed up directories to preserve user modifications
#   4. Updates Ubuntu system packages (apt-get update && upgrade)
#   5. Delegates to apply_update.sh for service updates
#
# This two-stage approach ensures apply_update.sh itself gets updated before
# running, so new update logic is always applied.
#
# Preserved directories: Defined in PRESERVE_DIRS array in utils.sh.
# These directories contain user-customizable content that survives git reset.
#
# Usage: make update  OR  sudo bash scripts/update.sh
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Global variable to track backup path for cleanup
BACKUP_PATH=""

# Cleanup function for interrupted updates
cleanup_on_exit() {
    local exit_code=$?
    if [ -n "$BACKUP_PATH" ] && [ -d "$BACKUP_PATH" ]; then
        log_warning "Cleaning up backup directory: $BACKUP_PATH"
        rm -rf "$BACKUP_PATH"
    fi
    exit $exit_code
}
trap cleanup_on_exit INT TERM

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

    # Backup user-customizable directories before git reset (uses PRESERVE_DIRS from utils.sh)
    if ! BACKUP_PATH=$(backup_preserved_dirs); then
        log_error "Backup failed. Aborting update to prevent data loss."
        exit 1
    fi

    if [ -n "$BACKUP_PATH" ]; then
        log_info "Backup created at: $BACKUP_PATH"
    fi

    # Git operations
    if ! git reset --hard HEAD; then
        log_error "Git reset failed."
        restore_preserved_dirs "$BACKUP_PATH"
        exit 1
    fi

    if ! git pull; then
        log_error "Git pull failed."
        restore_preserved_dirs "$BACKUP_PATH"
        exit 1
    fi

    # Restore user-customizable directories after git pull
    if ! restore_preserved_dirs "$BACKUP_PATH"; then
        log_error "Failed to restore user directories from backup."
        log_error "Backup may still be available at: $BACKUP_PATH"
        BACKUP_PATH=""  # Prevent cleanup from deleting it
        exit 1
    fi

    # Clear backup path after successful restore
    BACKUP_PATH=""
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