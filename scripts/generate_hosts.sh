#!/bin/bash
# =============================================================================
# generate_hosts.sh - Generate /etc/hosts entries for local development
# =============================================================================
# Creates a hosts.txt file with all .local domain entries needed for local
# development mode. Users can then add these entries to their /etc/hosts.
#
# Usage: bash scripts/generate_hosts.sh
# =============================================================================

set -e

source "$(dirname "$0")/utils.sh"
init_paths

# Load environment
load_env || { log_error "Could not load .env file"; exit 1; }

# Check if local mode
INSTALL_MODE="${INSTALL_MODE:-$(read_env_var "INSTALL_MODE")}"
if [ "${INSTALL_MODE:-vps}" != "local" ]; then
    log_info "Not in local mode (INSTALL_MODE=$INSTALL_MODE), skipping hosts generation"
    exit 0
fi

OUTPUT_FILE="$PROJECT_ROOT/hosts.txt"

log_info "Generating hosts file entries for local development..."

# All hostname variables to check
HOSTNAME_VARS=(
    "N8N_HOSTNAME"
    "WEBUI_HOSTNAME"
    "FLOWISE_HOSTNAME"
    "DIFY_HOSTNAME"
    "RAGAPP_HOSTNAME"
    "RAGFLOW_HOSTNAME"
    "LANGFUSE_HOSTNAME"
    "SUPABASE_HOSTNAME"
    "GRAFANA_HOSTNAME"
    "WAHA_HOSTNAME"
    "PROMETHEUS_HOSTNAME"
    "PORTAINER_HOSTNAME"
    "POSTIZ_HOSTNAME"
    "POSTGRESUS_HOSTNAME"
    "LETTA_HOSTNAME"
    "LIGHTRAG_HOSTNAME"
    "WEAVIATE_HOSTNAME"
    "QDRANT_HOSTNAME"
    "COMFYUI_HOSTNAME"
    "LT_HOSTNAME"
    "NEO4J_HOSTNAME"
    "PADDLEOCR_HOSTNAME"
    "DOCLING_HOSTNAME"
    "WELCOME_HOSTNAME"
    "SEARXNG_HOSTNAME"
)

# Create hosts.txt header
cat > "$OUTPUT_FILE" << 'EOF'
# =============================================================================
# n8n-install Local Installation Hosts
# =============================================================================
# Add these lines to your hosts file:
#   macOS/Linux: /etc/hosts
#   Windows:     C:\Windows\System32\drivers\etc\hosts
#
# To add automatically (macOS/Linux):
#   sudo bash -c 'cat hosts.txt >> /etc/hosts'
#
# To flush DNS cache after adding:
#   macOS:   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
#   Linux:   sudo systemd-resolve --flush-caches
#   Windows: ipconfig /flushdns
# =============================================================================

EOF

# Collect unique hostnames
declare -A HOSTNAMES_MAP
for var in "${HOSTNAME_VARS[@]}"; do
    value=$(read_env_var "$var")
    if [[ -n "$value" && "$value" =~ \.local$ ]]; then
        HOSTNAMES_MAP["$value"]=1
    fi
done

# Write sorted hostnames
for hostname in $(echo "${!HOSTNAMES_MAP[@]}" | tr ' ' '\n' | sort); do
    echo "127.0.0.1    $hostname" >> "$OUTPUT_FILE"
done

# Count entries
ENTRY_COUNT=${#HOSTNAMES_MAP[@]}

if [ "$ENTRY_COUNT" -eq 0 ]; then
    log_warning "No .local hostnames found in .env"
    rm -f "$OUTPUT_FILE"
    exit 0
fi

echo "" >> "$OUTPUT_FILE"
echo "# Total: $ENTRY_COUNT entries" >> "$OUTPUT_FILE"

log_success "Generated $ENTRY_COUNT host entries in: $OUTPUT_FILE"
log_info ""
log_info "To add these entries to your hosts file, run:"
log_info "  sudo bash -c 'cat $OUTPUT_FILE >> /etc/hosts'"
log_info ""
log_info "Then flush your DNS cache:"
log_info "  macOS:   sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder"
log_info "  Linux:   sudo systemd-resolve --flush-caches"

exit 0
