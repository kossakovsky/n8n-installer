#!/bin/bash
# =============================================================================
# utils.sh - Shared utilities for n8n-install scripts
# =============================================================================
# Common functions and utilities used across all installation scripts.
#
# Provides:
#   - Path initialization (init_paths): Sets SCRIPT_DIR, PROJECT_ROOT, ENV_FILE
#   - Logging functions: log_info, log_success, log_warning, log_error
#   - .env manipulation: read_env_var, write_env_var, load_env
#   - Whiptail wrappers: wt_input, wt_yesno, require_whiptail
#   - Validation helpers: require_command, require_file, ensure_file_exists
#   - Profile management: is_profile_active, update_compose_profiles
#   - Doctor output helpers: print_ok, print_warning, print_error
#
# Usage: source "$(dirname "$0")/utils.sh" && init_paths
# =============================================================================

#=============================================================================
# CONSTANTS
#=============================================================================
DOMAIN_PLACEHOLDER="yourdomain.com"

#=============================================================================
# PATH INITIALIZATION
#=============================================================================

# Initialize standard paths - call at start of each script
# WARNING: Must be called directly from script top-level, NOT from within functions.
#          BASH_SOURCE[1] refers to the script that sourced utils.sh.
# Usage: source utils.sh && init_paths
init_paths() {
    # BASH_SOURCE[1] = the script that called this function (not utils.sh itself)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    ENV_FILE="$PROJECT_ROOT/.env"
}

#=============================================================================
# LOGGING (Simplified)
#=============================================================================

# Internal logging function
_log() {
    local level="$1"
    local message="$2"
    echo ""
    echo "[$level] $(date +%H:%M:%S): $message"
}

log_info() {
    _log "INFO" "$1"
}

log_success() {
    _log "OK" "$1"
}

log_warning() {
    _log "WARN" "$1"
}

log_error() {
    _log "ERROR" "$1" >&2
}

# Display a header for major sections
log_header() {
    local message="$1"
    echo ""
    echo ""
    echo "========== $message =========="
}

#=============================================================================
# COLOR OUTPUT (for diagnostics and previews)
#=============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_ok() {
    echo ""
    echo -e "  ${GREEN}[OK]${NC} $1"
}

print_error() {
    echo ""
    echo -e "  ${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo ""
    echo -e "  ${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo ""
    echo -e "  ${BLUE}[INFO]${NC} $1"
}

#=============================================================================
# ENVIRONMENT MANAGEMENT
#=============================================================================

# Load .env file safely
# Usage: load_env [env_file_path]
load_env() {
    local env_file="${1:-$ENV_FILE}"
    if [[ ! -f "$env_file" ]]; then
        log_error ".env file not found: $env_file"
        return 1
    fi
    set -a
    source "$env_file"
    set +a
}

# Read a variable from .env file
# Usage: value=$(read_env_var "VAR_NAME" [env_file])
read_env_var() {
    local var_name="$1"
    local env_file="${2:-$ENV_FILE}"
    if grep -q "^${var_name}=" "$env_file" 2>/dev/null; then
        grep "^${var_name}=" "$env_file" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//"
    fi
}

# Write/update a variable in .env file (with automatic .bak cleanup)
# Usage: write_env_var "VAR_NAME" "value" [env_file]
write_env_var() {
    local var_name="$1"
    local var_value="$2"
    local env_file="${3:-$ENV_FILE}"

    if grep -q "^${var_name}=" "$env_file" 2>/dev/null; then
        sed -i.bak "\|^${var_name}=|d" "$env_file"
        rm -f "${env_file}.bak"
    fi
    echo "${var_name}=\"${var_value}\"" >> "$env_file"
}

# Check if a Docker Compose profile is active
# IMPORTANT: Requires COMPOSE_PROFILES to be set before calling (via load_env or direct assignment)
# Usage: is_profile_active "n8n" && echo "n8n is active"
is_profile_active() {
    local profile="$1"
    [[ -n "$COMPOSE_PROFILES" && ",$COMPOSE_PROFILES," == *",$profile,"* ]]
}

#=============================================================================
# UTILITIES
#=============================================================================

# Require a command to be available
# Usage: require_command "docker" "Install Docker: https://docs.docker.com/engine/install/"
require_command() {
    local cmd="$1"
    local install_hint="${2:-Please install $cmd}"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "'$cmd' not found. $install_hint"
        exit 1
    fi
}

# Cleanup .bak files created by sed -i
# Usage: cleanup_bak_files [directory]
cleanup_bak_files() {
    local directory="${1:-$PROJECT_ROOT}"
    find "$directory" -maxdepth 1 -name "*.bak" -type f -delete 2>/dev/null || true
}

# Escape string for JSON output
# Usage: escaped=$(json_escape "string with \"quotes\"")
json_escape() {
    local str="$1"
    printf '%s' "$str" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr -d '\n\r'
}

#=============================================================================
# FILE UTILITIES
#=============================================================================

# Require a file to exist, exit with error if not found
# Usage: require_file "/path/to/file" "Custom error message"
require_file() {
    local file="$1"
    local error_msg="${2:-File not found: $file}"
    if [[ ! -f "$file" ]]; then
        log_error "$error_msg"
        exit 1
    fi
}

# Ensure a file exists, create empty file if it doesn't
# Usage: ensure_file_exists "/path/to/file"
ensure_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        touch "$file"
    fi
}

#=============================================================================
# COMPOSE PROFILES MANAGEMENT
#=============================================================================

# Update COMPOSE_PROFILES in .env file
# Usage: update_compose_profiles "n8n,monitoring,portainer" [env_file]
update_compose_profiles() {
    local profiles="$1"
    local env_file="${2:-$ENV_FILE}"
    ensure_file_exists "$env_file"
    if grep -q "^COMPOSE_PROFILES=" "$env_file"; then
        sed -i.bak "\|^COMPOSE_PROFILES=|d" "$env_file"
        rm -f "${env_file}.bak"
    fi
    echo "COMPOSE_PROFILES=${profiles}" >> "$env_file"
}

#=============================================================================
# DEBIAN_FRONTEND MANAGEMENT
#=============================================================================
ORIGINAL_DEBIAN_FRONTEND=""

# Save current DEBIAN_FRONTEND and set to dialog for whiptail
# Usage: save_debian_frontend
save_debian_frontend() {
    ORIGINAL_DEBIAN_FRONTEND="$DEBIAN_FRONTEND"
    export DEBIAN_FRONTEND=dialog
}

# Restore original DEBIAN_FRONTEND value
# Usage: restore_debian_frontend
restore_debian_frontend() {
    if [[ -n "$ORIGINAL_DEBIAN_FRONTEND" ]]; then
        export DEBIAN_FRONTEND="$ORIGINAL_DEBIAN_FRONTEND"
    else
        unset DEBIAN_FRONTEND
    fi
}

#=============================================================================
# SECRET GENERATION
#=============================================================================

# Generate random string with specified characters
# Usage: gen_random 32 'A-Za-z0-9'
gen_random() {
    local length="$1"
    local characters="$2"
    head /dev/urandom | tr -dc "$characters" | head -c "$length"
}

# Generate alphanumeric password
# Usage: gen_password 32
gen_password() {
    gen_random "$1" 'A-Za-z0-9'
}

# Generate hex string
# Usage: gen_hex 64  (returns 64 hex characters)
gen_hex() {
    local length="$1"
    local bytes=$(( (length + 1) / 2 ))
    openssl rand -hex "$bytes" | head -c "$length"
}

# Generate base64 string
# Usage: gen_base64 64  (returns 64 base64 characters)
gen_base64() {
    local length="$1"
    local bytes=$(( (length * 3 + 3) / 4 ))
    openssl rand -base64 "$bytes" | head -c "$length"
}

# Generate bcrypt hash using Caddy
# Usage: hash=$(generate_bcrypt_hash "plaintext_password")
generate_bcrypt_hash() {
    local plaintext="$1"
    if [[ -n "$plaintext" ]]; then
        caddy hash-password --algorithm bcrypt --plaintext "$plaintext" 2>/dev/null
    fi
}

#=============================================================================
# VALIDATION
#=============================================================================

# Validate that a value is a positive integer
# Usage: validate_positive_integer "5" && echo "valid"
validate_positive_integer() {
    local value="$1"
    [[ "$value" =~ ^0*[1-9][0-9]*$ ]]
}

#=============================================================================
# WHIPTAIL HELPERS
#=============================================================================

# Ensure whiptail is available
require_whiptail() {
    if ! command -v whiptail >/dev/null 2>&1; then
        log_error "'whiptail' is not installed. Install with: sudo apt-get install -y whiptail"
        exit 1
    fi
}

# Input box
# Usage: result=$(wt_input "Title" "Prompt" "default")
# Returns 0 on OK, 1 on Cancel
wt_input() {
    local title="$1"
    local prompt="$2"
    local default_value="$3"
    local result
    result=$(whiptail --title "$title" --inputbox "$prompt" 15 80 "$default_value" 3>&1 1>&2 2>&3)
    local status=$?
    if [ $status -ne 0 ]; then
        return 1
    fi
    echo "$result"
    return 0
}

# Password box
# Usage: result=$(wt_password "Title" "Prompt")
# Returns 0 on OK, 1 on Cancel
wt_password() {
    local title="$1"
    local prompt="$2"
    local result
    result=$(whiptail --title "$title" --passwordbox "$prompt" 15 80 3>&1 1>&2 2>&3)
    local status=$?
    if [ $status -ne 0 ]; then
        return 1
    fi
    echo "$result"
    return 0
}

# Yes/No box
# Usage: wt_yesno "Title" "Prompt" "default" (default: yes|no)
# Returns 0 for Yes, 1 for No/Cancel
wt_yesno() {
    local title="$1"
    local prompt="$2"
    local default_choice="$3"
    if [ "$default_choice" = "yes" ]; then
        whiptail --title "$title" --yesno "$prompt" 10 80
    else
        whiptail --title "$title" --defaultno --yesno "$prompt" 10 80
    fi
}

# Message box
# Usage: wt_msg "Title" "Message"
wt_msg() {
    local title="$1"
    local message="$2"
    whiptail --title "$title" --msgbox "$message" 10 80
}
