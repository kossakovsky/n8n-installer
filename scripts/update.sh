#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Set the compose command explicitly to use docker compose subcommand
COMPOSE_CMD="docker compose"
log_info "Using $COMPOSE_CMD as compose command"

# Navigate to the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Project root directory (one level up from scripts)
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
# Path to the 04_run_services.sh script
RUN_SERVICES_SCRIPT="$SCRIPT_DIR/04_run_services.sh"
# Compose files
MAIN_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
SUPABASE_COMPOSE_FILE="$PROJECT_ROOT/supabase/docker/docker-compose.yml"


# Check if run services script exists
if [ ! -f "$RUN_SERVICES_SCRIPT" ]; then
    log_error "$RUN_SERVICES_SCRIPT not found."
    exit 1
fi

log_info "Starting update process..."

# Pull the latest repository changes
log_info "Pulling latest repository changes..."
# Check if git is installed
if ! command -v git &> /dev/null; then
    log_warning "'git' command not found. Skipping repository update."
else
    # Since script is run from root, just do git pull in current directory
    git pull || { log_warning "Failed to pull latest repository changes. Continuing with update..."; }
fi

cd "$PROJECT_ROOT"

# Stop all services
log_info "Stopping all services..."
$COMPOSE_CMD down || { 
  log_warning "Failed to stop containers with 'docker compose down'. Continuing with update anyway..."; 
}

# Pull latest versions of all containers
log_info "Pulling latest versions of all containers..."
$COMPOSE_CMD pull || { log_error "Failed to pull Docker images. Check network connection and Docker Hub status."; exit 1; }

# Ask user about n8n import and modify .env file
ENV_FILE="$PROJECT_ROOT/.env"

if [ -f "$ENV_FILE" ]; then
    read -p "Import n8n workflow? (y/n): " import_choice
    case "$import_choice" in
        [yY] | [yY][eE][sS] )
            sed -i 's/^RUN_N8N_IMPORT=.*/RUN_N8N_IMPORT=true/' "$ENV_FILE" || log_error "Failed to set RUN_N8N_IMPORT in $ENV_FILE. Check permissions."
            ;;
        * )
            sed -i 's/^RUN_N8N_IMPORT=.*/RUN_N8N_IMPORT=false/' "$ENV_FILE" || log_error "Failed to set RUN_N8N_IMPORT in $ENV_FILE. Check permissions."
            ;;
    esac
else
    log_warning "$ENV_FILE not found. Cannot configure RUN_N8N_IMPORT."
fi

# Start services using the 04_run_services.sh script
log_info "Running Services..."
bash "$RUN_SERVICES_SCRIPT" || { log_error "Failed to start services. Check logs for details."; exit 1; }

log_success "Update completed successfully!"

exit 0 