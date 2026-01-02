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

# Start services in correct order (matching start_services.py behavior)
# Supabase must be started separately due to relative path resolution in its compose file
if is_profile_active "supabase"; then
    SUPABASE_COMPOSE="$PROJECT_ROOT/supabase/docker/docker-compose.yml"
    if [ -f "$SUPABASE_COMPOSE" ]; then
        log_info "Starting Supabase services..."
        docker compose -p "$PROJECT_NAME" -f "$SUPABASE_COMPOSE" up -d
        log_info "Waiting for Supabase to initialize..."
        sleep 10
    fi
fi

# Start Dify separately (same relative path issue)
if is_profile_active "dify"; then
    DIFY_COMPOSE="$PROJECT_ROOT/dify/docker/docker-compose.yaml"
    if [ -f "$DIFY_COMPOSE" ]; then
        log_info "Starting Dify services..."
        docker compose -p "$PROJECT_NAME" -f "$DIFY_COMPOSE" up -d
        log_info "Waiting for Dify to initialize..."
        sleep 10
    fi
fi

# Build main compose files (exclude external stacks that were started separately)
MAIN_COMPOSE_FILES=("-f" "$PROJECT_ROOT/docker-compose.yml")
if path=$(get_n8n_workers_compose); then
    MAIN_COMPOSE_FILES+=("-f" "$path")
fi

# Start main services
log_info "Starting main services..."
docker compose -p "$PROJECT_NAME" "${MAIN_COMPOSE_FILES[@]}" up -d

log_success "Services restarted successfully!"
