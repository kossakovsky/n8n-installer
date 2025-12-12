#!/bin/bash
# =============================================================================
# 04_wizard.sh - Interactive service selection wizard
# =============================================================================
# Guides the user through selecting which services to install using whiptail.
#
# Features:
#   - Single-screen checklist for service selection
#   - Default services: n8n, portainer, monitoring, postgresus
#   - Preserves previously selected services on re-run
#   - Updates COMPOSE_PROFILES in .env file
#
# Usage: bash scripts/04_wizard.sh
# =============================================================================

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Verify whiptail is available
require_whiptail

# Set DEBIAN_FRONTEND for whiptail
save_debian_frontend

# --- Read current COMPOSE_PROFILES from .env ---
CURRENT_PROFILES_VALUE=""
if [ -f "$ENV_FILE" ]; then
    LINE_CONTENT=$(grep "^COMPOSE_PROFILES=" "$ENV_FILE" || echo "")
    if [ -n "$LINE_CONTENT" ]; then
        # Get value after '=', remove potential surrounding quotes
        CURRENT_PROFILES_VALUE=$(echo "$LINE_CONTENT" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//')
    fi
fi
# Prepare comma-separated current profiles for easy matching, adding leading/trailing commas
current_profiles_for_matching=",$CURRENT_PROFILES_VALUE,"

# --- Define available services and their descriptions ---
# Base service definitions (tag, description)
base_services_data=(
    "cloudflare-tunnel" "Cloudflare Tunnel (Zero-Trust Secure Access)"
    "comfyui" "ComfyUI (Node-based Stable Diffusion UI)"
    "crawl4ai" "Crawl4ai (Web Crawler for AI)"
    "docling" "Docling (Universal Document Converter to Markdown/JSON)"
    "dify" "Dify (AI Application Development Platform with LLMOps)"
    "flowise" "Flowise (AI Agent Builder)"
    "gotenberg" "Gotenberg (Document Conversion API)"
    "langfuse" "Langfuse Suite (AI Observability - includes Clickhouse, Minio)"
    "letta" "Letta (Agent Server & SDK)"
    "lightrag" "LightRAG (Graph-based RAG with knowledge graphs)"
    "libretranslate" "LibreTranslate (Self-hosted translation API - 50+ languages)"
    "monitoring" "Monitoring Suite (Prometheus, Grafana, cAdvisor, Node-Exporter)"
    "n8n" "n8n, n8n-worker, n8n-import (Workflow Automation)"
    "neo4j" "Neo4j (Graph Database)"
    "ollama" "Ollama (Local LLM Runner - select hardware in next step)"
    "open-webui" "Open WebUI (ChatGPT-like Interface)"
    "paddleocr" "PaddleOCR (OCR API Server)"
    "portainer" "Portainer (Docker management UI)"
    "postgresus" "Postgresus (PostgreSQL backups & monitoring)"
    "postiz" "Postiz (Social publishing platform)"
    "python-runner" "Python Runner (Run your custom Python code from ./python-runner)"
    "qdrant" "Qdrant (Vector Database)"
    "ragapp" "RAGApp (Open-source RAG UI + API)"
    "ragflow" "RAGFlow (Deep document understanding RAG engine)"
    "searxng" "SearXNG (Private Metasearch Engine)"
    "supabase" "Supabase (Backend as a Service)"
    "waha" "WAHA – WhatsApp HTTP API (NOWEB engine)"
    "weaviate" "Weaviate (Vector Database with API Key Auth)"
)

services=() # This will be the final array for whiptail

# Populate the services array for whiptail based on current profiles or defaults
idx=0
while [ $idx -lt ${#base_services_data[@]} ]; do
    tag="${base_services_data[idx]}"
    description="${base_services_data[idx+1]}"
    status="OFF" # Default to OFF

    if [ -n "$CURRENT_PROFILES_VALUE" ] && [ "$CURRENT_PROFILES_VALUE" != '""' ]; then # Check if .env has profiles
        if [[ "$tag" == "ollama" ]]; then
            if [[ "$current_profiles_for_matching" == *",cpu,"* || \
                  "$current_profiles_for_matching" == *",gpu-nvidia,"* || \
                  "$current_profiles_for_matching" == *",gpu-amd,"* ]]; then
                status="ON"
            fi
        elif [[ "$current_profiles_for_matching" == *",$tag,"* ]]; then
            status="ON"
        fi
    else
        # .env has no COMPOSE_PROFILES or it's empty/just quotes, use hardcoded defaults
        case "$tag" in
            "n8n"|"portainer"|"monitoring"|"postgresus") status="ON" ;;
            *) status="OFF" ;;
        esac
    fi
    services+=("$tag" "$description" "$status")
    idx=$((idx + 2))
done

# Use whiptail to display the checklist
num_services=$(( ${#services[@]} / 3 ))
CHOICES=$(whiptail --title "Service Selection Wizard" --checklist \
  "Choose the services you want to deploy.\nUse ARROW KEYS to navigate, SPACEBAR to select/deselect, ENTER to confirm." 32 90 $num_services \
  "${services[@]}" \
  3>&1 1>&2 2>&3)

# Restore original DEBIAN_FRONTEND
restore_debian_frontend

# Exit if user pressed Cancel or Esc
exitstatus=$?
if [ $exitstatus -ne 0 ]; then
    log_info "Service selection cancelled by user. Exiting wizard."
    log_info "No changes made to service profiles. Default services will be used."
    # Set COMPOSE_PROFILES to empty to ensure only core services run
    update_compose_profiles ""
    exit 0
fi

# Process selected services
selected_profiles=()
ollama_selected=0
ollama_profile=""

if [ -n "$CHOICES" ]; then
    # Whiptail returns a string like "tag1" "tag2" "tag3"
    # We need to remove quotes and convert to an array
    temp_choices=()
    eval "temp_choices=($CHOICES)"

    for choice in "${temp_choices[@]}"; do
        if [ "$choice" == "ollama" ]; then
            ollama_selected=1
        else
            selected_profiles+=("$choice")
        fi
    done
fi

# Enforce mutual exclusivity between Dify and Supabase (compact)
if printf '%s\n' "${selected_profiles[@]}" | grep -qx "dify" && \
   printf '%s\n' "${selected_profiles[@]}" | grep -qx "supabase"; then
    CHOSEN_EXCLUSIVE=$(whiptail --title "Conflict: Dify and Supabase" --default-item "supabase" --radiolist \
      "Dify and Supabase are mutually exclusive. Choose which one to keep." 15 78 2 \
      "dify" "Keep Dify (AI App Platform)" OFF \
      "supabase" "Keep Supabase (Backend as a Service)" ON \
      3>&1 1>&2 2>&3)
    [ -z "$CHOSEN_EXCLUSIVE" ] && CHOSEN_EXCLUSIVE="supabase"

    to_remove=$([ "$CHOSEN_EXCLUSIVE" = "dify" ] && echo "supabase" || echo "dify")
    tmp=()
    for p in "${selected_profiles[@]}"; do
        [ "$p" = "$to_remove" ] || tmp+=("$p")
    done
    selected_profiles=("${tmp[@]}")
    log_info "Mutual exclusivity enforced: kept '$CHOSEN_EXCLUSIVE', removed '$to_remove'."
fi

# If Ollama was selected, prompt for the hardware profile
if [ $ollama_selected -eq 1 ]; then
    # Determine default selected Ollama hardware profile from .env
    default_ollama_hardware="cpu" # Fallback default
    ollama_hw_on_cpu="OFF"
    ollama_hw_on_gpu_nvidia="OFF"
    ollama_hw_on_gpu_amd="OFF"

    # Check current_profiles_for_matching which includes commas, e.g., ",cpu,"
    if [[ "$current_profiles_for_matching" == *",cpu,"* ]]; then
        ollama_hw_on_cpu="ON"
        default_ollama_hardware="cpu"
    elif [[ "$current_profiles_for_matching" == *",gpu-nvidia,"* ]]; then
        ollama_hw_on_gpu_nvidia="ON"
        default_ollama_hardware="gpu-nvidia"
    elif [[ "$current_profiles_for_matching" == *",gpu-amd,"* ]]; then
        ollama_hw_on_gpu_amd="ON"
        default_ollama_hardware="gpu-amd"
    else
        # If ollama was selected in the main list, but no specific hardware profile was previously set,
        # default to CPU ON for the radiolist.
        ollama_hw_on_cpu="ON"
        default_ollama_hardware="cpu"
    fi

    ollama_hardware_options=(
        "cpu" "CPU (Recommended for most users)" "$ollama_hw_on_cpu"
        "gpu-nvidia" "NVIDIA GPU (Requires NVIDIA drivers & CUDA)" "$ollama_hw_on_gpu_nvidia"
        "gpu-amd" "AMD GPU (Requires ROCm drivers)" "$ollama_hw_on_gpu_amd"
    )
    CHOSEN_OLLAMA_PROFILE=$(whiptail --title "Ollama Hardware Profile" --default-item "$default_ollama_hardware" --radiolist \
      "Choose the hardware profile for Ollama. This will be added to your Docker Compose profiles." 15 78 3 \
      "${ollama_hardware_options[@]}" \
      3>&1 1>&2 2>&3)

    ollama_exitstatus=$?
    if [ $ollama_exitstatus -eq 0 ] && [ -n "$CHOSEN_OLLAMA_PROFILE" ]; then
        selected_profiles+=("$CHOSEN_OLLAMA_PROFILE")
        ollama_profile="$CHOSEN_OLLAMA_PROFILE" # Store for user message
        log_info "Ollama hardware profile selected: $CHOSEN_OLLAMA_PROFILE"
    else
        log_info "Ollama hardware profile selection cancelled or no choice made. Ollama will not be configured with a specific hardware profile."
        # ollama_selected remains 1, but no specific profile is added.
        # This means "ollama" won't be in COMPOSE_PROFILES unless a hardware profile is chosen.
        ollama_selected=0 # Mark as not fully selected if profile choice is cancelled
    fi
fi

if [ ${#selected_profiles[@]} -eq 0 ]; then
    log_info "No optional services selected."
    COMPOSE_PROFILES_VALUE=""
else
    log_info "You have selected the following service profiles to be deployed:"
    # Join the array into a comma-separated string
    COMPOSE_PROFILES_VALUE=$(IFS=,; echo "${selected_profiles[*]}")
    for profile in "${selected_profiles[@]}"; do
        # Check if the current profile is an Ollama hardware profile that was chosen
        if [[ "$profile" == "cpu" || "$profile" == "gpu-nvidia" || "$profile" == "gpu-amd" ]]; then
            if [ "$profile" == "$ollama_profile" ]; then # ollama_profile stores the CHOSEN_OLLAMA_PROFILE from this wizard run
                 echo "  - Ollama ($profile profile)"
            else # This handles a (highly unlikely) non-Ollama service named "cpu", "gpu-nvidia", or "gpu-amd"
                 echo "  - $profile"
            fi
        else
            echo "  - $profile"
        fi
    done
fi

# Update or add COMPOSE_PROFILES in .env file
update_compose_profiles "$COMPOSE_PROFILES_VALUE"
if [ -z "$COMPOSE_PROFILES_VALUE" ]; then
    log_info "Only core services (Caddy, Postgres, Redis) will be started."
else
    log_info "The following Docker Compose profiles will be active: ${COMPOSE_PROFILES_VALUE}"
fi

# Cleanup any .bak files created by sed
cleanup_bak_files "$PROJECT_ROOT"

exit 0
