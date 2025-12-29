#!/bin/bash
# =============================================================================
# restart.sh - Restart all services
# =============================================================================
# Restarts all Docker Compose services including dynamically generated
# worker/runner compose files and external service stacks.
#
# Handles compose files via build_compose_files_array() from utils.sh:
#   - docker-compose.yml (main)
#   - docker-compose.n8n-workers.yml (if exists and n8n profile active)
#   - supabase/docker/docker-compose.yml (if exists and supabase profile active)
#   - dify/docker/docker-compose.yaml (if exists and dify profile active)
#
# Usage: bash scripts/restart.sh
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

cd "$PROJECT_ROOT"

# Load environment to check active profiles
load_env

PROJECT_NAME="localai"

# Build compose files array (sets global COMPOSE_FILES)
build_compose_files_array

log_info "Restarting services..."
log_info "Using compose files: ${COMPOSE_FILES[*]}"

# Stop all services
docker compose -p "$PROJECT_NAME" "${COMPOSE_FILES[@]}" down

# Start all services
docker compose -p "$PROJECT_NAME" "${COMPOSE_FILES[@]}" up -d

log_success "Services restarted successfully!"
