#!/bin/bash
# =============================================================================
# 05_configure_services.sh - Service-specific configuration
# =============================================================================
# Collects additional configuration needed by selected services via whiptail
# prompts and writes settings to .env file.
#
# Prompts for:
#   - OpenAI API Key (optional, used by Supabase AI and Crawl4AI)
#   - n8n workflow import option (~300 ready-made workflows)
#   - Number of n8n workers to run
#   - Cloudflare Tunnel token (if cloudflare-tunnel profile is active)
#
# Also handles:
#   - Generates n8n worker-runner pairs configuration
#   - Resolves service conflicts (e.g., removes Dify if Supabase is selected)
#
# Usage: bash scripts/05_configure_services.sh
# =============================================================================

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Ensure .env exists
ensure_file_exists "$ENV_FILE"

# ----------------------------------------------------------------
# Prompt for OpenAI API key (optional) using .env value as source of truth
# ----------------------------------------------------------------
log_subheader "OpenAI API Key"
EXISTING_OPENAI_API_KEY="$(read_env_var OPENAI_API_KEY)"
OPENAI_API_KEY=""
if [[ -z "$EXISTING_OPENAI_API_KEY" ]]; then
    require_whiptail
    OPENAI_API_KEY=$(wt_input "OpenAI API Key" "Optional: Used by Supabase AI (SQL assistance) and Crawl4AI. Leave empty to skip." "") || true
    if [[ -n "$OPENAI_API_KEY" ]]; then
        write_env_var "OPENAI_API_KEY" "$OPENAI_API_KEY"
    fi
else
    # Reuse existing value without prompting
    OPENAI_API_KEY="$EXISTING_OPENAI_API_KEY"
fi


# ----------------------------------------------------------------
# Logic for n8n workflow import (RUN_N8N_IMPORT)
# ----------------------------------------------------------------
log_subheader "n8n Workflow Import"
final_run_n8n_import_decision="false"
require_whiptail
if wt_yesno "Import n8n Workflows" "Import ~300 ready-made n8n workflows now? This can take ~30 minutes." "no"; then
    final_run_n8n_import_decision="true"
else
    final_run_n8n_import_decision="false"
fi

# Persist RUN_N8N_IMPORT to .env
write_env_var "RUN_N8N_IMPORT" "$final_run_n8n_import_decision"


# ----------------------------------------------------------------
# Prompt for number of n8n workers
# ----------------------------------------------------------------
log_subheader "n8n Worker Configuration"
EXISTING_N8N_WORKER_COUNT="$(read_env_var N8N_WORKER_COUNT)"
require_whiptail
if [[ -n "$EXISTING_N8N_WORKER_COUNT" ]]; then
    N8N_WORKER_COUNT_CURRENT="$EXISTING_N8N_WORKER_COUNT"
    N8N_WORKER_COUNT_INPUT_RAW=$(wt_input "n8n Workers (instances)" "Enter new number of n8n workers, or leave as current ($N8N_WORKER_COUNT_CURRENT)." "") || true
    if [[ -z "$N8N_WORKER_COUNT_INPUT_RAW" ]]; then
        N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
    else
        if [[ "$N8N_WORKER_COUNT_INPUT_RAW" =~ ^0*[1-9][0-9]*$ ]]; then
            N8N_WORKER_COUNT_TEMP="$((10#$N8N_WORKER_COUNT_INPUT_RAW))"
            if [[ "$N8N_WORKER_COUNT_TEMP" -ge 1 ]]; then
                if wt_yesno "Confirm Workers" "Update n8n workers to $N8N_WORKER_COUNT_TEMP?" "yes"; then
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_TEMP"
                else
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
                    log_info "Change declined. Keeping N8N_WORKER_COUNT at $N8N_WORKER_COUNT."
                fi
            else
                log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Number must be positive. Keeping $N8N_WORKER_COUNT_CURRENT."
                N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
            fi
        else
            log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Please enter a positive integer. Keeping $N8N_WORKER_COUNT_CURRENT."
            N8N_WORKER_COUNT="$N8N_WORKER_COUNT_CURRENT"
        fi
    fi
else
    while true; do
        N8N_WORKER_COUNT_INPUT_RAW=$(wt_input "n8n Workers" "Enter number of n8n workers to run (default 1)." "1") || true
        N8N_WORKER_COUNT_CANDIDATE="${N8N_WORKER_COUNT_INPUT_RAW:-1}"
        if [[ "$N8N_WORKER_COUNT_CANDIDATE" =~ ^0*[1-9][0-9]*$ ]]; then
            N8N_WORKER_COUNT_VALIDATED="$((10#$N8N_WORKER_COUNT_CANDIDATE))"
            if [[ "$N8N_WORKER_COUNT_VALIDATED" -ge 1 ]]; then
                if wt_yesno "Confirm Workers" "Run $N8N_WORKER_COUNT_VALIDATED n8n worker(s)?" "yes"; then
                    N8N_WORKER_COUNT="$N8N_WORKER_COUNT_VALIDATED"
                    break
                fi
            else
                log_error "Number of workers must be a positive integer."
            fi
        else
            log_error "Invalid input '$N8N_WORKER_COUNT_CANDIDATE'. Please enter a positive integer (e.g., 1, 2)."
        fi
    done
fi
# Ensure N8N_WORKER_COUNT is definitely set (should be by logic above)
N8N_WORKER_COUNT="${N8N_WORKER_COUNT:-1}"

# Persist N8N_WORKER_COUNT to .env
write_env_var "N8N_WORKER_COUNT" "$N8N_WORKER_COUNT"

# Generate worker-runner pairs configuration
# Each worker gets its own dedicated task runner sidecar
log_info "Generating n8n worker-runner pairs configuration..."
"$BASH" "$SCRIPT_DIR/generate_n8n_workers.sh"


# ----------------------------------------------------------------
# Cloudflare Tunnel Token (if cloudflare-tunnel profile is active)
# ----------------------------------------------------------------
COMPOSE_PROFILES_VALUE="$(read_env_var COMPOSE_PROFILES)"
# Set COMPOSE_PROFILES for is_profile_active to work
COMPOSE_PROFILES="$COMPOSE_PROFILES_VALUE"

if is_profile_active "cloudflare-tunnel"; then
    log_subheader "Cloudflare Tunnel"
    existing_cf_token="$(read_env_var CLOUDFLARE_TUNNEL_TOKEN)"

    if [ -n "$existing_cf_token" ]; then
        log_info "Cloudflare Tunnel token found in .env; reusing it."
        # Do not prompt; keep existing token as-is
    else
        require_whiptail
        input_cf_token=$(wt_input "Cloudflare Tunnel Token" "Enter your Cloudflare Tunnel token (leave empty to skip)." "") || true

        # Update the .env with the token (may be empty if user skipped)
        write_env_var "CLOUDFLARE_TUNNEL_TOKEN" "$input_cf_token"

        if [ -n "$input_cf_token" ]; then
            log_success "Cloudflare Tunnel token saved to .env."
            log_info "After confirming the tunnel works, consider closing ports 80, 443, and 7687 in your firewall."
        else
            log_warning "Cloudflare Tunnel token was left empty. You can set it later in .env."
        fi
    fi
fi


# ----------------------------------------------------------------
# Safety: If Supabase is present, remove Dify from COMPOSE_PROFILES (no prompts)
# ----------------------------------------------------------------
if is_profile_active "supabase"; then
  IFS=',' read -r -a profiles_array <<< "$COMPOSE_PROFILES_VALUE"
  new_profiles=()
  for p in "${profiles_array[@]}"; do
    if [[ "$p" != "dify" ]]; then
      new_profiles+=("$p")
    fi
  done
  COMPOSE_PROFILES_VALUE_UPDATED=$(IFS=','; echo "${new_profiles[*]}")
  if [[ "$COMPOSE_PROFILES_VALUE_UPDATED" != "$COMPOSE_PROFILES_VALUE" ]]; then
    write_env_var "COMPOSE_PROFILES" "$COMPOSE_PROFILES_VALUE_UPDATED"
    log_info "Supabase present: removed 'dify' from COMPOSE_PROFILES due to conflict with Supabase."
    COMPOSE_PROFILES_VALUE="$COMPOSE_PROFILES_VALUE_UPDATED"
  fi
fi

# ----------------------------------------------------------------
# Ensure Supabase Analytics targets the correct Postgres service name used by Supabase docker compose
# ----------------------------------------------------------------
write_env_var "POSTGRES_HOST" "db"
# ----------------------------------------------------------------

log_success "Service configuration complete. .env updated at $ENV_FILE"

# Cleanup any .bak files
cleanup_bak_files "$PROJECT_ROOT"

exit 0
