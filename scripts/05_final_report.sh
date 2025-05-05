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
# Use set -a to export all variables read from the file
set -a
source "$ENV_FILE"
set +a

# --- Installation Summary ---
log_info "Installation Summary. The following steps were performed by the scripts:"
log_success "- System updated and basic utilities installed"
log_success "- Firewall (UFW) configured and enabled"
log_success "- Fail2Ban activated for brute-force protection"
log_success "- Automatic security updates enabled"
log_success "- Docker and Docker Compose installed"
log_success "- '.env' generated with secure passwords and secrets"
log_success "- Services launched via Docker Compose"

# --- Service Access Credentials ---

# Display credentials, checking if variables exist
echo
echo "======================================================================="
echo
log_info "Service Access Credentials. Save this information securely!"
# Display credentials, checking if variables exist
echo
echo "================================= n8n ================================="
echo
echo "Host: ${N8N_HOSTNAME:-<hostname_not_set>}"
echo
echo "================================= Langfuse ============================"
echo
echo "Host: ${LANGFUSE_HOSTNAME:-<hostname_not_set>}"
echo
echo "================================= WebUI ==============================="
echo
echo "Host: ${WEBUI_HOSTNAME:-<hostname_not_set>}"
echo
echo "================================= Flowise ============================="
echo
echo "Host: ${FLOWISE_HOSTNAME:-<hostname_not_set>}"
echo "User: ${FLOWISE_USERNAME:-<not_set_in_env>}"
echo "Password: ${FLOWISE_PASSWORD:-<not_set_in_env>}"
echo
echo "================================= Supabase ============================"
echo
echo "External Host (via Caddy): ${SUPABASE_HOSTNAME:-<hostname_not_set>}"
echo "Internal API Gateway: http://kong:8000"
echo "Studio User: ${DASHBOARD_USERNAME:-<not_set_in_env>}"
echo "Studio Password: ${DASHBOARD_PASSWORD:-<not_set_in_env>}"
echo
echo "================================= Grafana ============================="
echo
echo "Host: ${GRAFANA_HOSTNAME:-<hostname_not_set>}"
echo "User: admin"
echo "Password: ${GRAFANA_ADMIN_PASSWORD:-<not_set_in_env>}"
echo
echo "================================= Prometheus =========================="
echo
echo "Host: ${PROMETHEUS_HOSTNAME:-<hostname_not_set>}"
echo "User: ${PROMETHEUS_USERNAME:-<not_set_in_env>}"
echo "Password: ${PROMETHEUS_PASSWORD:-<not_set_in_env>}"
echo
echo "================================= Searxng ============================="
echo
echo "Host: ${SEARXNG_HOSTNAME:-<hostname_not_set>}"
echo "User: ${SEARXNG_USERNAME:-<not_set_in_env>}"
echo "Password: ${SEARXNG_PASSWORD:-<not_set_in_env>}"
echo
echo "================================= Qdrant =============================="
echo
echo "Internal gRPC Access (e.g., from backend): qdrant:6333"
echo "Internal REST API Access (e.g., from backend): http://qdrant:6334"
echo "(Note: Not exposed externally via Caddy by default)"
echo
echo "================================= Crawl4AI ============================"
echo
echo "Internal Access (e.g., from n8n): http://crawl4ai:11235"
echo "(Note: Not exposed externally via Caddy by default)"
echo
echo "======================================================================="
echo

# --- Update Script Info (Placeholder) ---
log_info "To update the services, run the 'update.sh' script: bash ./scripts/update.sh"

echo
echo "======================================================================"
echo
echo "Next Steps:"
echo "1. Review the credentials above and store them safely."
echo "2. Access the services via their respective URLs (check \`docker compose ps\` if needed)."
echo "3. Configure services as needed (e.g., first-run setup for n8n)."
echo
echo "======================================================================"
echo
log_info "Thank you for using this installer setup!"
echo

exit 0 