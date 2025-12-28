#!/bin/bash
# =============================================================================
# docker_cleanup.sh - Docker system cleanup (preserves volumes)
# =============================================================================
# Cleans up the Docker system to reclaim disk space.
#
# Removes:
#   - All stopped containers
#   - All networks not used by at least one container
#   - All unused images (not just dangling ones)
#   - All build cache
#
# Preserves:
#   - All volumes (to protect application data like Redis, PostgreSQL, etc.)
#
# Usage: make clean  OR  sudo bash scripts/docker_cleanup.sh
# =============================================================================

set -e

source "$(dirname "$0")/utils.sh"

log_info "Starting Docker cleanup..."

# Clean containers, networks, images, and build cache
# NOTE: --volumes flag removed to preserve application data
docker system prune -a -f

log_success "Docker cleanup completed. Volumes preserved."
