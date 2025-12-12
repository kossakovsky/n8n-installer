#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Get the directory where the script resides
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
ENV_FILE="$PROJECT_ROOT/.env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    log_error "The .env file ('$ENV_FILE') was not found."
    exit 1
fi

# Load environment variables from .env file
set -a
source "$ENV_FILE"
set +a

# Generate welcome page data
if [ -f "$SCRIPT_DIR/generate_welcome_page.sh" ]; then
    log_info "Generating welcome page..."
    bash "$SCRIPT_DIR/generate_welcome_page.sh" || log_warning "Failed to generate welcome page"
fi

# Function to check if a profile is active
is_profile_active() {
    local profile_to_check="$1"
    if [ -z "$COMPOSE_PROFILES" ]; then
        return 1
    fi
    if [[ ",$COMPOSE_PROFILES," == *",$profile_to_check,"* ]]; then
        return 0
    else
        return 1
    fi
}

echo
echo "======================================================================="
echo "                    Installation Complete!"
echo "======================================================================="
echo

# --- Make Commands ---
echo "================================= Make Commands ========================="
echo
echo "  make logs              View logs (all services)"
echo "  make logs s=<service>  View logs for specific service"
echo "  make status            Show container status"
echo "  make monitor           Live CPU/memory monitoring"
echo "  make restarts          Show restart count per container"
echo
echo "  make update            Update system and services"
echo "  make update-preview    Preview available updates (dry-run)"
echo "  make doctor            Run system diagnostics"
echo "  make clean             Remove unused Docker resources"
echo
echo "  make switch-beta       Switch to beta (develop branch)"
echo "  make switch-stable     Switch to stable (main branch)"
echo

# --- Welcome Page ---
echo "================================= Welcome Page =========================="
echo
echo "All your service credentials are available on the Welcome Page:"
echo
echo "  URL:      https://${WELCOME_HOSTNAME:-welcome.${USER_DOMAIN_NAME}}"
echo "  Username: ${WELCOME_USERNAME:-<not_set>}"
echo "  Password: ${WELCOME_PASSWORD:-<not_set>}"
echo
echo "The Welcome Page displays:"
echo "  - All installed services with their hostnames"
echo "  - Login credentials (username/password/API keys)"
echo "  - Internal URLs for service-to-service communication"
echo

# --- Next Steps ---
echo "======================================================================="
echo "                          Next Steps"
echo "======================================================================="
echo
echo "1. Visit your Welcome Page to view all service credentials"
echo "   https://${WELCOME_HOSTNAME:-welcome.${USER_DOMAIN_NAME}}"
echo
echo "2. Store the Welcome Page credentials securely"
echo "   (Username: ${WELCOME_USERNAME:-<not_set>})"
echo
echo "3. Configure services as needed:"
echo "   - n8n: Complete first-run setup with your email"
echo "   - Portainer: Create admin account on first login"
echo "   - Open WebUI: Register your account"
echo
echo "4. Run 'make doctor' if you experience any issues"
echo
echo "======================================================================="
echo
log_info "Thank you for using n8n-install!"
echo
