#!/bin/bash
# Sample scaffold (not wired into installer) showing how proxy/TLS prompts could work.
# Intended to be refactored into scripts/03_generate_secrets.sh + utils.sh helpers.

set -e

# shellcheck source=/dev/null
source "$(dirname "$0")/../../scripts/utils.sh"
init_paths

require_whiptail

# Load existing choices if present
load_env 2>/dev/null || true

DEFAULT_PROXY="${REVERSE_PROXY:-caddy}"
DEFAULT_TLS_MODE="${TLS_MODE:-public}"

PROXY_CHOICE=$(wt_radiolist "Reverse Proxy" \
    "Choose which proxy to configure." \
    "$DEFAULT_PROXY" \
    "caddy" "Keep current Caddy-based setup" ON \
    "traefik" "Switch to Traefik (Docker provider + ACME/file providers)" OFF) || exit 1

TLS_MODE_CHOICE=$(wt_radiolist "TLS Mode" \
    "How should certificates be handled?" \
    "$DEFAULT_TLS_MODE" \
    "public" "Public ACME/Let's Encrypt" ON \
    "local" "Local CA + wildcard cert (homelab/local TLDs)" OFF) || exit 1

DOMAIN_INPUT=$(wt_input "Primary Domain" "Enter base domain (e.g., example.com or homelab.lan)." "${USER_DOMAIN_NAME}") || exit 1

if [[ "$TLS_MODE_CHOICE" == "public" ]]; then
    ACME_EMAIL_INPUT=$(wt_input "ACME Email" "Email for Let's Encrypt/ACME registration." "${ACME_EMAIL:-$LETSENCRYPT_EMAIL}") || exit 1
else
    WILDCARD_DEFAULT="${WILDCARD_DOMAIN:-*.${DOMAIN_INPUT}}"
    WILDCARD_INPUT=$(wt_input "Wildcard CN" "Wildcard certificate CN" "$WILDCARD_DEFAULT") || exit 1
    # In a real flow, we would generate/store CA + cert paths here.
fi

cat <<EOF
Chosen proxy: $PROXY_CHOICE
TLS mode: $TLS_MODE_CHOICE
Domain: $DOMAIN_INPUT
EOF
