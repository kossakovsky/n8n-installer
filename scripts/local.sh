#!/bin/bash
# =============================================================================
# local.sh - Local installation mode utilities
# =============================================================================
# Encapsulates all logic related to local vs VPS installation modes.
# Provides functions for mode detection, environment configuration,
# and mode-specific settings.
#
# Usage: source "$(dirname "$0")/local.sh"
#
# Functions:
#   - get_install_mode: Get current installation mode (vps|local)
#   - is_local_mode: Check if running in local mode
#   - is_vps_mode: Check if running in VPS mode
#   - get_protocol: Get protocol based on mode (http|https)
#   - get_caddy_auto_https: Get Caddy auto_https setting (on|off)
#   - get_n8n_secure_cookie: Get n8n secure cookie setting (true|false)
#   - get_local_domain: Get default domain for local mode (.local)
#   - configure_mode_env: Set all mode-specific environment variables
#   - print_local_hosts_instructions: Display hosts file setup instructions
# =============================================================================

#=============================================================================
# CONSTANTS
#=============================================================================

# Local mode defaults
LOCAL_MODE_DOMAIN="local"
LOCAL_MODE_PROTOCOL="http"
LOCAL_MODE_CADDY_AUTO_HTTPS="off"
LOCAL_MODE_N8N_SECURE_COOKIE="false"

# VPS mode defaults
VPS_MODE_PROTOCOL="https"
VPS_MODE_CADDY_AUTO_HTTPS="on"
VPS_MODE_N8N_SECURE_COOKIE="true"

#=============================================================================
# MODE DETECTION
#=============================================================================

# Get the current installation mode
# Checks: 1) exported INSTALL_MODE, 2) .env file, 3) defaults to "vps"
# Usage: mode=$(get_install_mode)
get_install_mode() {
    local mode="${INSTALL_MODE:-}"

    # If not set, try to read from .env
    if [[ -z "$mode" && -n "${ENV_FILE:-}" && -f "$ENV_FILE" ]]; then
        mode=$(grep "^INSTALL_MODE=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- | tr -d '"'"'" || true)
    fi

    # Default to vps for backward compatibility
    echo "${mode:-vps}"
}

# Check if running in local mode
# Usage: is_local_mode && echo "Local mode"
is_local_mode() {
    [[ "$(get_install_mode)" == "local" ]]
}

# Check if running in VPS mode
# Usage: is_vps_mode && echo "VPS mode"
is_vps_mode() {
    [[ "$(get_install_mode)" != "local" ]]
}

#=============================================================================
# MODE-SPECIFIC GETTERS
#=============================================================================

# Get protocol based on installation mode
# Usage: protocol=$(get_protocol)
get_protocol() {
    if is_local_mode; then
        echo "$LOCAL_MODE_PROTOCOL"
    else
        echo "$VPS_MODE_PROTOCOL"
    fi
}

# Get Caddy auto_https setting based on installation mode
# Usage: auto_https=$(get_caddy_auto_https)
get_caddy_auto_https() {
    if is_local_mode; then
        echo "$LOCAL_MODE_CADDY_AUTO_HTTPS"
    else
        echo "$VPS_MODE_CADDY_AUTO_HTTPS"
    fi
}

# Get n8n secure cookie setting based on installation mode
# Usage: secure_cookie=$(get_n8n_secure_cookie)
get_n8n_secure_cookie() {
    if is_local_mode; then
        echo "$LOCAL_MODE_N8N_SECURE_COOKIE"
    else
        echo "$VPS_MODE_N8N_SECURE_COOKIE"
    fi
}

# Get default domain for local mode
# Usage: domain=$(get_local_domain)
get_local_domain() {
    echo "$LOCAL_MODE_DOMAIN"
}

#=============================================================================
# ENVIRONMENT CONFIGURATION
#=============================================================================

# Configure all mode-specific environment variables
# Populates the provided associative array with mode settings
# Usage: declare -A settings; configure_mode_env settings "local"
# Arguments:
#   $1 - nameref to associative array for storing values
#   $2 - mode (optional, defaults to get_install_mode())
configure_mode_env() {
    local -n _env_ref=$1
    local mode="${2:-$(get_install_mode)}"

    _env_ref["INSTALL_MODE"]="$mode"

    if [[ "$mode" == "local" ]]; then
        _env_ref["PROTOCOL"]="$LOCAL_MODE_PROTOCOL"
        _env_ref["CADDY_AUTO_HTTPS"]="$LOCAL_MODE_CADDY_AUTO_HTTPS"
        _env_ref["N8N_SECURE_COOKIE"]="$LOCAL_MODE_N8N_SECURE_COOKIE"
    else
        _env_ref["PROTOCOL"]="$VPS_MODE_PROTOCOL"
        _env_ref["CADDY_AUTO_HTTPS"]="$VPS_MODE_CADDY_AUTO_HTTPS"
        _env_ref["N8N_SECURE_COOKIE"]="$VPS_MODE_N8N_SECURE_COOKIE"
    fi
}

#=============================================================================
# HOSTS FILE UTILITIES
#=============================================================================

# All hostname variables used in the project
# Used by generate_hosts.sh and other scripts that need hostname list
get_all_hostname_vars() {
    local vars=(
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
        "NOCODB_HOSTNAME"
        "PADDLEOCR_HOSTNAME"
        "DOCLING_HOSTNAME"
        "WELCOME_HOSTNAME"
        "SEARXNG_HOSTNAME"
    )
    printf '%s\n' "${vars[@]}"
}

# Print instructions for setting up /etc/hosts for local mode
# Usage: print_local_hosts_instructions
print_local_hosts_instructions() {
    # Requires color variables from utils.sh
    local cyan="${CYAN:-}"
    local white="${WHITE:-}"
    local dim="${DIM:-}"
    local nc="${NC:-}"

    echo ""
    echo -e "  ${white}Before accessing services, add entries to your hosts file:${nc}"
    echo ""
    echo -e "  ${cyan}sudo bash -c 'cat hosts.txt >> /etc/hosts'${nc}"
    echo ""
    echo -e "  ${dim}Then flush your DNS cache:${nc}"
    echo -e "  ${cyan}macOS: sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder${nc}"
    echo -e "  ${cyan}Linux: sudo systemd-resolve --flush-caches${nc}"
}

#=============================================================================
# PREREQUISITES CHECK (for local mode)
#=============================================================================

# Check if all prerequisites for local mode are met
# Returns 0 if all prerequisites are met, 1 otherwise
# Usage: check_local_prerequisites || exit 1
check_local_prerequisites() {
    local missing=()

    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    elif ! docker info > /dev/null 2>&1; then
        missing+=("docker-daemon")
    fi

    # Check Docker Compose
    if ! docker compose version &> /dev/null 2>&1; then
        missing+=("docker-compose")
    fi

    # Check whiptail
    if ! command -v whiptail &> /dev/null; then
        missing+=("whiptail")
    fi

    # Check openssl
    if ! command -v openssl &> /dev/null; then
        missing+=("openssl")
    fi

    # Check git
    if ! command -v git &> /dev/null; then
        missing+=("git")
    fi

    # Check Python3
    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Missing prerequisites: ${missing[*]}"
        return 1
    fi

    return 0
}

# Print installation instructions for missing prerequisites
# Usage: print_prerequisite_instructions "docker" "whiptail"
print_prerequisite_instructions() {
    local os_type
    os_type=$(uname)

    for dep in "$@"; do
        case "$dep" in
            docker)
                echo "  Docker:"
                case "$os_type" in
                    Darwin) echo "    Install Docker Desktop: https://www.docker.com/products/docker-desktop" ;;
                    Linux)  echo "    Install Docker: https://docs.docker.com/engine/install/" ;;
                esac
                ;;
            docker-daemon)
                echo "  Docker daemon is not running:"
                case "$os_type" in
                    Darwin) echo "    Start Docker Desktop from Applications" ;;
                    Linux)  echo "    Run: sudo systemctl start docker" ;;
                esac
                ;;
            docker-compose)
                echo "  Docker Compose:"
                echo "    Should be included with Docker Desktop"
                echo "    Or install: https://docs.docker.com/compose/install/"
                ;;
            whiptail)
                echo "  whiptail:"
                case "$os_type" in
                    Darwin) echo "    Run: brew install newt" ;;
                    Linux)  echo "    Run: sudo apt-get install -y whiptail" ;;
                esac
                ;;
            openssl)
                echo "  openssl:"
                case "$os_type" in
                    Darwin) echo "    Usually pre-installed, or: brew install openssl" ;;
                    Linux)  echo "    Run: sudo apt-get install -y openssl" ;;
                esac
                ;;
            git)
                echo "  git:"
                echo "    Install: https://git-scm.com/downloads"
                ;;
            python3)
                echo "  Python3:"
                echo "    Install: https://www.python.org/downloads/"
                ;;
        esac
    done
}
