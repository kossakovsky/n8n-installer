#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Ensure .env exists
if [ ! -f "$ENV_FILE" ]; then
  touch "$ENV_FILE"
fi

# Helper: read value from .env (without surrounding quotes)
read_env_var() {
  local var_name="$1"
  if grep -q "^${var_name}=" "$ENV_FILE"; then
    grep "^${var_name}=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//'
  else
    echo ""
  fi
}

# Helper: upsert value into .env (quote the value)
write_env_var() {
  local var_name="$1"
  local var_value="$2"
  if grep -q "^${var_name}=" "$ENV_FILE"; then
    # use different delimiter to be safe
    sed -i.bak "\|^${var_name}=|d" "$ENV_FILE"
  fi
  echo "${var_name}=\"${var_value}\"" >> "$ENV_FILE"
}

log_info "Configuring service options in .env..."

# ---------------------------
# OPENAI_API_KEY (optional)
# ---------------------------
EXISTING_OPENAI_API_KEY="$(read_env_var OPENAI_API_KEY)"
if [ -z "$EXISTING_OPENAI_API_KEY" ]; then
  echo ""
  echo "OpenAI API Key (optional). This key will be used for:"
  echo "   - Supabase: AI services to help with writing SQL queries, statements, and policies"
  echo "   - Crawl4AI: Default LLM configuration for web crawling capabilities"
  echo "   You can skip this by leaving it empty."
  echo ""
  read -p "OpenAI API Key: " INPUT_OPENAI_API_KEY
  write_env_var OPENAI_API_KEY "$INPUT_OPENAI_API_KEY"
else
  # Keep as-is if set (even if user wants to change later, they can edit .env)
  log_info "OPENAI_API_KEY already set in .env; leaving unchanged."
fi

# ---------------------------
# RUN_N8N_IMPORT (300 workflows)
# ---------------------------
EXISTING_RUN_N8N_IMPORT="$(read_env_var RUN_N8N_IMPORT)"
if [ -n "$EXISTING_RUN_N8N_IMPORT" ]; then
  echo ""
  read -p "Change n8n workflows import setting? Current: $EXISTING_RUN_N8N_IMPORT (y/N): " CHANGE_IMPORT
  if [[ "$CHANGE_IMPORT" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Do you want to import 300 ready-made workflows for n8n? This process may take about 30 minutes to complete."
    echo ""
    read -p "Import workflows? (y/n): " import_workflow_choice
    if [[ "$import_workflow_choice" =~ ^[Yy]$ ]]; then
      write_env_var RUN_N8N_IMPORT "true"
    else
      write_env_var RUN_N8N_IMPORT "false"
    fi
  else
    log_info "Keeping existing RUN_N8N_IMPORT value: $EXISTING_RUN_N8N_IMPORT"
  fi
else
  echo ""
  echo "Do you want to import 300 ready-made workflows for n8n? This process may take about 30 minutes to complete."
  echo ""
  read -p "Import workflows? (y/n): " import_workflow_choice
  if [[ "$import_workflow_choice" =~ ^[Yy]$ ]]; then
    write_env_var RUN_N8N_IMPORT "true"
  else
    write_env_var RUN_N8N_IMPORT "false"
  fi
fi

# ---------------------------
# N8N_WORKER_COUNT
# ---------------------------
EXISTING_N8N_WORKER_COUNT="$(read_env_var N8N_WORKER_COUNT)"
if [ -n "$EXISTING_N8N_WORKER_COUNT" ]; then
  echo ""
  read -p "Do you want to change the number of n8n workers? Current: $EXISTING_N8N_WORKER_COUNT. (Enter new number, or press Enter to keep current): " N8N_WORKER_COUNT_INPUT_RAW
  if [ -z "$N8N_WORKER_COUNT_INPUT_RAW" ]; then
    log_info "Keeping N8N_WORKER_COUNT at $EXISTING_N8N_WORKER_COUNT."
  else
    if [[ "$N8N_WORKER_COUNT_INPUT_RAW" =~ ^0*[1-9][0-9]*$ ]]; then
      N8N_WORKER_COUNT_TEMP="$((10#$N8N_WORKER_COUNT_INPUT_RAW))"
      if [ "$N8N_WORKER_COUNT_TEMP" -ge 1 ]; then
        echo ""
        read -p "Update n8n workers to $N8N_WORKER_COUNT_TEMP? (y/N): " confirm_change
        if [[ "$confirm_change" =~ ^[Yy]$ ]]; then
          write_env_var N8N_WORKER_COUNT "$N8N_WORKER_COUNT_TEMP"
        else
          log_info "Change declined. Keeping N8N_WORKER_COUNT at $EXISTING_N8N_WORKER_COUNT."
        fi
      else
        log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Number must be positive. Keeping $EXISTING_N8N_WORKER_COUNT."
      fi
    else
      log_warning "Invalid input '$N8N_WORKER_COUNT_INPUT_RAW'. Please enter a positive integer. Keeping $EXISTING_N8N_WORKER_COUNT."
    fi
  fi
else
  while true; do
    echo ""
    read -p "Enter the number of n8n workers to run (e.g., 1, 2, 3; default is 1): " N8N_WORKER_COUNT_INPUT_RAW
    N8N_WORKER_COUNT_CANDIDATE="${N8N_WORKER_COUNT_INPUT_RAW:-1}"
    if [[ "$N8N_WORKER_COUNT_CANDIDATE" =~ ^0*[1-9][0-9]*$ ]]; then
      N8N_WORKER_COUNT_VALIDATED="$((10#$N8N_WORKER_COUNT_CANDIDATE))"
      if [ "$N8N_WORKER_COUNT_VALIDATED" -ge 1 ]; then
        echo ""
        read -p "Run $N8N_WORKER_COUNT_VALIDATED n8n worker(s)? (y/N): " confirm_workers
        if [[ "$confirm_workers" =~ ^[Yy]$ ]]; then
          write_env_var N8N_WORKER_COUNT "$N8N_WORKER_COUNT_VALIDATED"
          break
        else
          log_info "Please try entering the number of workers again."
        fi
      else
        log_error "Number of workers must be a positive integer." >&2
      fi
    else
      log_error "Invalid input '$N8N_WORKER_COUNT_CANDIDATE'. Please enter a positive integer (e.g., 1, 2)." >&2
    fi
  done
fi

# ---------------------------
# Cloudflare Tunnel Token (if cloudflare-tunnel profile is active)
# ---------------------------
CURRENT_PROFILES_VALUE=""
if grep -q "^COMPOSE_PROFILES=" "$ENV_FILE"; then
  CURRENT_PROFILES_VALUE=$(grep "^COMPOSE_PROFILES=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//')
fi

if [ -n "$CURRENT_PROFILES_VALUE" ]; then
  PROFILES_CSV=",$CURRENT_PROFILES_VALUE,"
else
  PROFILES_CSV=","  # no profiles
fi

if [[ "$PROFILES_CSV" == *",cloudflare-tunnel,"* ]]; then
  EXISTING_CF_TOKEN="$(read_env_var CLOUDFLARE_TUNNEL_TOKEN)"
  if [ -n "$EXISTING_CF_TOKEN" ]; then
    log_info "Cloudflare Tunnel token found in .env; reusing it."
  else
    log_info "Cloudflare Tunnel profile is active. Please provide your Cloudflare Tunnel token."
    echo ""
    read -p "Cloudflare Tunnel Token: " input_cf_token
    write_env_var CLOUDFLARE_TUNNEL_TOKEN "$input_cf_token"
    if [ -n "$input_cf_token" ]; then
      log_success "Cloudflare Tunnel token saved to .env."
      echo ""
      echo "🔒 After confirming the tunnel works, consider closing ports 80, 443, and 7687 in your firewall."
    else
      log_warning "Cloudflare Tunnel token was left empty. You can set it later in .env."
    fi
  fi
else
  log_info "Cloudflare Tunnel profile is not active; skipping Cloudflare token configuration."
fi

log_success "Service configuration complete. .env updated at $ENV_FILE"

exit 0

