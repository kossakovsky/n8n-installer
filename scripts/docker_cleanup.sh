#!/bin/bash
# =============================================================================
# docker_cleanup.sh - Complete Docker system cleanup
# =============================================================================
# Aggressively cleans up the Docker system to reclaim disk space.
# WARNING: This action is irreversible!
#
# Removes:
#   - All stopped containers
#   - All networks not used by at least one container
#   - All unused images (not just dangling ones)
#   - All unused volumes
#   - All build cache
#
# Usage: make clean  OR  sudo bash scripts/docker_cleanup.sh
# =============================================================================

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

log_info "Starting Docker cleanup..."

# The 'docker system prune' command removes:
# - all stopped containers
# - all networks not used by at least one container
# - all "dangling" (unreferenced) images
# - all build cache
#
# Additional flags:
# -a, --all:     Remove all unused images, not just dangling ones.
# --volumes:   Remove all unused volumes.
# -f, --force:   Do not prompt for confirmation.

docker system prune -a --volumes -f

log_success "Docker cleanup completed successfully."