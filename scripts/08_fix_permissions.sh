#!/bin/bash
# =============================================================================
# 08_fix_permissions.sh - Fix file ownership after installation
# =============================================================================
# This script fixes file ownership when the installer was run with sudo.
# It detects the real user who invoked the installation and sets proper
# ownership for all project files.
#
# Usage: bash scripts/08_fix_permissions.sh
# =============================================================================

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Initialize paths
init_paths

log_info "Fixing file permissions..."

# Get the real user who ran the installer
REAL_USER=$(get_real_user)
REAL_GROUP=$(id -gn "$REAL_USER" 2>/dev/null || echo "$REAL_USER")

log_info "Detected user: $REAL_USER (group: $REAL_GROUP)"

# Skip if running as root without sudo (e.g., in Docker)
if [[ "$REAL_USER" == "root" ]]; then
    log_info "Running as root user, no permission changes needed."
    exit 0
fi

# Fix ownership of the entire project directory
if [[ -d "$PROJECT_ROOT" ]]; then
    log_info "Setting ownership of $PROJECT_ROOT to $REAL_USER:$REAL_GROUP"
    chown -R "$REAL_USER:$REAL_GROUP" "$PROJECT_ROOT"

    # Ensure .env has restricted permissions (readable only by owner)
    if [[ -f "$ENV_FILE" ]]; then
        chmod 600 "$ENV_FILE"
        log_info "Set restrictive permissions on .env file"
    fi

    # Ensure scripts are executable
    chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
    chmod +x "$PROJECT_ROOT"/*.py 2>/dev/null || true

    log_success "File permissions fixed successfully!"
else
    log_error "Project root not found: $PROJECT_ROOT"
    exit 1
fi
