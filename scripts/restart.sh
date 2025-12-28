#!/bin/bash
# =============================================================================
# restart.sh - Restart all services
# =============================================================================
# Restarts all Docker Compose services including dynamically generated
# worker/runner compose files.
#
# Handles compose files:
#   - docker-compose.yml (main)
#   - docker-compose.n8n-workers.yml (if exists)
#
# Usage: bash scripts/restart.sh
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

cd "$PROJECT_ROOT"

PROJECT_NAME="localai"

# Build compose files array
COMPOSE_FILES=("-f" "docker-compose.yml")

# Add n8n workers compose file if exists
N8N_WORKERS_COMPOSE="docker-compose.n8n-workers.yml"
if [ -f "$N8N_WORKERS_COMPOSE" ]; then
    COMPOSE_FILES+=("-f" "$N8N_WORKERS_COMPOSE")
fi

log_info "Restarting services..."
log_info "Using compose files: ${COMPOSE_FILES[*]}"

# Stop all services
docker compose -p "$PROJECT_NAME" "${COMPOSE_FILES[@]}" down

# Start all services
docker compose -p "$PROJECT_NAME" "${COMPOSE_FILES[@]}" up -d

log_success "Services restarted successfully!"
