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

# Function to check if a profile is active
is_profile_active() {
    local profile_to_check="$1"
    # COMPOSE_PROFILES is sourced from .env and will be available here
    if [ -z "$COMPOSE_PROFILES" ]; then
        return 1 # Not active if COMPOSE_PROFILES is empty or not set
    fi
    # Check if the profile_to_check is in the comma-separated list
    # Adding commas at the beginning and end of both strings handles edge cases
    # (e.g., single profile, profile being a substring of another)
    if [[ ",$COMPOSE_PROFILES," == *",$profile_to_check,"* ]]; then
        return 0 # Active
    else
        return 1 # Not active
    fi
}

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

if is_profile_active "n8n"; then
  echo
  echo "================================= n8n ================================="
  echo
  echo "Host: ${N8N_HOSTNAME:-<hostname_not_set>}"
fi

if is_profile_active "langfuse"; then
  echo
  echo "================================= Langfuse ============================"
  echo
  echo "Host: ${LANGFUSE_HOSTNAME:-<hostname_not_set>}"
fi

if is_profile_active "open-webui"; then
  echo
  echo "================================= WebUI ==============================="
  echo
  echo "Host: ${WEBUI_HOSTNAME:-<hostname_not_set>}"
fi

if is_profile_active "flowise"; then
  echo
  echo "================================= Flowise ============================="
  echo
  echo "Host: ${FLOWISE_HOSTNAME:-<hostname_not_set>}"
  echo "User: ${FLOWISE_USERNAME:-<not_set_in_env>}"
  echo "Password: ${FLOWISE_PASSWORD:-<not_set_in_env>}"
fi

if is_profile_active "supabase"; then
  echo
  echo "================================= Supabase ============================"
  echo
  echo "External Host (via Caddy): ${SUPABASE_HOSTNAME:-<hostname_not_set>}"
  echo "Internal API Gateway: http://kong:8000"
  echo "Studio User: ${DASHBOARD_USERNAME:-<not_set_in_env>}"
  echo "Studio Password: ${DASHBOARD_PASSWORD:-<not_set_in_env>}"
  echo
  echo "================================= PostgreSQL (Supabase) ============================"
  echo
  echo "Host: ${POSTGRES_HOST:-db}"
  echo "Port: ${POSTGRES_PORT:-5432}"
  echo "Database: ${POSTGRES_DB:-postgres}"
  echo "User: ${POSTGRES_USER:-postgres}"
  echo "Password: ${POSTGRES_PASSWORD:-<not_set_in_env>}"
fi

if is_profile_active "monitoring"; then
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
fi

if is_profile_active "searxng"; then
  echo
  echo "================================= Searxng ============================="
  echo
  echo "Host: ${SEARXNG_HOSTNAME:-<hostname_not_set>}"
  echo "User: ${SEARXNG_USERNAME:-<not_set_in_env>}"
  echo "Password: ${SEARXNG_PASSWORD:-<not_set_in_env>}"
fi

if is_profile_active "qdrant"; then
  echo
  echo "================================= Qdrant =============================="
  echo
  echo "Internal gRPC Access (e.g., from backend): qdrant:6333"
  echo "Internal REST API Access (e.g., from backend): http://qdrant:6334"
  echo "(Note: Not exposed externally via Caddy by default)"
fi

if is_profile_active "crawl4ai"; then
  echo
  echo "================================= Crawl4AI ============================"
  echo
  echo "Internal Access (e.g., from n8n): http://crawl4ai:11235"
  echo "(Note: Not exposed externally via Caddy by default)"
fi

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