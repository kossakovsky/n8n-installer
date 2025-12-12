#!/bin/bash
# =============================================================================
# 07_final_report.sh - Post-installation summary and credentials display
# =============================================================================
# Generates and displays the final installation report after all services
# are running.
#
# Actions:
#   - Generates welcome page data (via generate_welcome_page.sh)
#   - Displays Welcome Page URL and credentials
#   - Shows next steps for configuring individual services
#   - Provides guidance for first-run setup of n8n, Portainer, Flowise, etc.
#
# The Welcome Page serves as a central dashboard with all service credentials
# and access URLs, protected by basic auth.
#
# Usage: bash scripts/07_final_report.sh
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Load environment variables from .env file
load_env || exit 1

# Generate welcome page data
if [ -f "$SCRIPT_DIR/generate_welcome_page.sh" ]; then
    log_info "Generating welcome page..."
    bash "$SCRIPT_DIR/generate_welcome_page.sh" || log_warning "Failed to generate welcome page"
fi

echo
echo "======================================================================="
echo "                    Installation Complete!"
echo "======================================================================="
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
echo
echo "3. Configure services as needed:"
if is_profile_active "n8n"; then
echo "   - n8n: Complete first-run setup with your email"
fi
if is_profile_active "portainer"; then
echo "   - Portainer: Create admin account on first login"
fi
if is_profile_active "flowise"; then
echo "   - Flowise: Register and create your account"
fi
if is_profile_active "open-webui"; then
echo "   - Open WebUI: Register your account"
fi
echo
echo "4. Run 'make doctor' if you experience any issues"
echo
echo "======================================================================="
echo
log_info "Thank you for using n8n-install!"
echo
