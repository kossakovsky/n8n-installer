#!/bin/bash

# Script to guide user through service selection for n8n-installer

# Source utility functions, if any, assuming it's in the same directory
# and .env is in the parent directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# UTILS_SCRIPT="$SCRIPT_DIR/utils.sh" # Uncomment if utils.sh contains relevant functions

# if [ -f "$UTILS_SCRIPT" ]; then
#     source "$UTILS_SCRIPT"
# fi

# Function to check if whiptail is installed
check_whiptail() {
    if ! command -v whiptail &> /dev/null; then
        log_error "'whiptail' is not installed."
        log_info "This tool is required for the interactive service selection."
        log_info "On Debian/Ubuntu, you can install it using: sudo apt-get install whiptail"
        log_info "Please install whiptail and try again."
        exit 1
    fi
}

# Call the check
check_whiptail

# Store original DEBIAN_FRONTEND and set to dialog for whiptail
ORIGINAL_DEBIAN_FRONTEND="$DEBIAN_FRONTEND"
export DEBIAN_FRONTEND=dialog

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
    "n8n" "n8n, n8n-worker, n8n-import (Workflow Automation)"
    "dify" "Dify (AI Application Development Platform with LLMOps)"
    "flowise" "Flowise (AI Agent Builder)"
    "bolt" "bolt.diy (AI Web Development)"
    "openui" "OpenUI (AI Frontend/UI Generator - EXPERIMENTAL, best with Claude/GPT-4)"
    "monitoring" "Monitoring Suite (Prometheus, Grafana, cAdvisor, Node-Exporter)"
    "portainer" "Portainer (Docker management UI)"
    "cloudflare-tunnel" "Cloudflare Tunnel (Zero-Trust Secure Access)"
    "postiz" "Postiz (Social publishing platform)"
    "langfuse" "Langfuse Suite (AI Observability - includes Clickhouse, Minio)"
    "qdrant" "Qdrant (Vector Database)"
    "supabase" "Supabase (Backend as a Service)"
    "weaviate" "Weaviate (Vector Database with API Key Auth)"
    "neo4j" "Neo4j (Graph Database)"
    "letta" "Letta (Agent Server & SDK)"
    "gotenberg" "Gotenberg (Document Conversion API)"
    "crawl4ai" "Crawl4ai (Web Crawler for AI)"
    "ragapp" "RAGApp (Open-source RAG UI + API)"
    "open-webui" "Open WebUI (ChatGPT-like Interface)"
    "searxng" "SearXNG (Private Metasearch Engine)"
    "python-runner" "Python Runner (Run your custom Python code from ./python-runner)"
    "ollama" "Ollama (Local LLM Runner - select hardware in next step)"
    "comfyui" "ComfyUI (Node-based Stable Diffusion UI)"
    "speech" "Speech Stack (Whisper ASR + OpenedAI TTS - CPU optimized)"
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
            "n8n"|"flowise"|"monitoring") status="ON" ;;
            *) status="OFF" ;;
        esac
    fi
    services+=("$tag" "$description" "$status")
    idx=$((idx + 2))
done

# Use whiptail to display the checklist
CHOICES=$(whiptail --title "Service Selection Wizard" --checklist \
  "Choose the services you want to deploy.\nUse ARROW KEYS to navigate, SPACEBAR to select/deselect, ENTER to confirm." 32 90 21 \
  "${services[@]}" \
  3>&1 1>&2 2>&3)

# Restore original DEBIAN_FRONTEND
if [ -n "$ORIGINAL_DEBIAN_FRONTEND" ]; then
  export DEBIAN_FRONTEND="$ORIGINAL_DEBIAN_FRONTEND"
else
  unset DEBIAN_FRONTEND
fi

# Exit if user pressed Cancel or Esc
exitstatus=$?
if [ $exitstatus -ne 0 ]; then
    log_info "Service selection cancelled by user. Exiting wizard."
    log_info "No changes made to service profiles. Default services will be used."
    # Set COMPOSE_PROFILES to empty to ensure only core services run
    if [ ! -f "$ENV_FILE" ]; then
        touch "$ENV_FILE"
    fi
    if grep -q "^COMPOSE_PROFILES=" "$ENV_FILE"; then
        sed -i.bak "/^COMPOSE_PROFILES=/d" "$ENV_FILE"
    fi
    echo "COMPOSE_PROFILES=" >> "$ENV_FILE"
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
# Ensure .env file exists (it should have been created by 03_generate_secrets.sh or exist from previous run)
if [ ! -f "$ENV_FILE" ]; then
    log_warning "'.env' file not found at $ENV_FILE. Creating it."
    touch "$ENV_FILE"
fi

# If Cloudflare Tunnel is selected, prompt for the token and write to .env
cloudflare_selected=0
for profile in "${selected_profiles[@]}"; do
    if [ "$profile" == "cloudflare-tunnel" ]; then
        cloudflare_selected=1
        break
    fi
done

if [ $cloudflare_selected -eq 1 ]; then
    existing_cf_token=""
    if grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" "$ENV_FILE"; then
        existing_cf_token=$(grep "^CLOUDFLARE_TUNNEL_TOKEN=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/^\"//' | sed 's/\"$//')
    fi

    if [ -n "$existing_cf_token" ]; then
        log_info "Cloudflare Tunnel token found in .env; reusing it."
        # Do not prompt; keep existing token as-is
    else
        log_info "Cloudflare Tunnel selected. Please provide your Cloudflare Tunnel token."
        echo ""
        read -p "Cloudflare Tunnel Token: " input_cf_token
        token_to_write="$input_cf_token"

        # Update the .env with the token (may be empty if user skipped)
        if grep -q "^CLOUDFLARE_TUNNEL_TOKEN=" "$ENV_FILE"; then
            sed -i.bak "/^CLOUDFLARE_TUNNEL_TOKEN=/d" "$ENV_FILE"
        fi
        echo "CLOUDFLARE_TUNNEL_TOKEN=\"$token_to_write\"" >> "$ENV_FILE"

        if [ -n "$token_to_write" ]; then
            log_success "Cloudflare Tunnel token saved to .env."
            echo ""
            echo "🔒 After confirming the tunnel works, consider closing ports 80, 443, and 7687 in your firewall."
        else
            log_warning "Cloudflare Tunnel token was left empty. You can set it later in .env."
        fi
    fi
fi

# Remove existing COMPOSE_PROFILES line if it exists
if grep -q "^COMPOSE_PROFILES=" "$ENV_FILE"; then
    # Using a different delimiter for sed because a profile name might contain '/' (unlikely here)
    sed -i.bak "\|^COMPOSE_PROFILES=|d" "$ENV_FILE"
fi

# Add the new COMPOSE_PROFILES line
echo "COMPOSE_PROFILES=${COMPOSE_PROFILES_VALUE}" >> "$ENV_FILE"
if [ -z "$COMPOSE_PROFILES_VALUE" ]; then
    log_info "Only core services (Caddy, Postgres, Redis) will be started."
else
    log_info "The following Docker Compose profiles will be active: ${COMPOSE_PROFILES_VALUE}"
fi

# Speech Stack Authentication Setup (if speech profile was selected)
if [[ ",$COMPOSE_PROFILES_VALUE," == *",speech,"* ]]; then
    log_info ""
    log_info "Speech Stack Authentication Setup"
    log_info "================================="
    log_info "The Speech services (Whisper STT and TTS) need authentication for security."
    log_info ""
    
    # Ask for username
    read -p "Enter username for Speech services [admin]: " speech_user
    speech_user=${speech_user:-admin}
    
    # Ask for password
    while true; do
        read -s -p "Enter password for Speech services: " speech_password
        echo
        if [ -z "$speech_password" ]; then
            log_warning "Password cannot be empty. Please try again."
        else
            break
        fi
    done
    
    # Generate password hashes
    log_info "Generating secure password hashes..."
    
    # Check if Docker is available
    if command -v docker &> /dev/null; then
        # Generate hash for Whisper
        whisper_hash=$(docker run --rm caddy:alpine caddy hash-password --plaintext "$speech_password" 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$whisper_hash" ]; then
            # Use same hash for both services (simpler for users)
            tts_hash="$whisper_hash"
            
            # Update .env file with auth settings
            # Remove existing entries if present
            sed -i.bak "/^WHISPER_AUTH_USER=/d" "$ENV_FILE"
            sed -i.bak "/^WHISPER_AUTH_PASSWORD_HASH=/d" "$ENV_FILE"
            sed -i.bak "/^TTS_AUTH_USER=/d" "$ENV_FILE"
            sed -i.bak "/^TTS_AUTH_PASSWORD_HASH=/d" "$ENV_FILE"
            
            # Add new entries
            echo "WHISPER_AUTH_USER=$speech_user" >> "$ENV_FILE"
            echo "WHISPER_AUTH_PASSWORD_HASH=${whisper_hash//\$/\$\$}" >> "$ENV_FILE"
            echo "TTS_AUTH_USER=$speech_user" >> "$ENV_FILE"
            echo "TTS_AUTH_PASSWORD_HASH=${tts_hash//\$/\$\$}" >> "$ENV_FILE"
            
            log_success "Speech services authentication configured successfully."
            log_info "Username: $speech_user"
            log_info "Use this username and password to access:"
            log_info "  - Whisper: https://asr.yourdomain.com"
            log_info "  - TTS: https://tts.yourdomain.com"
            log_info ""
        else
            log_warning "Could not generate password hash. Docker might not be installed yet."
            log_warning "You'll need to manually set WHISPER_AUTH_PASSWORD_HASH and TTS_AUTH_PASSWORD_HASH in .env"
            log_info "Run after installation: docker run --rm caddy:alpine caddy hash-password --plaintext 'your-password'"
        fi
    else
        log_warning "Docker not available. Saving plaintext password for later hashing."
        log_warning "The installer will generate the hash during Docker setup."
        
        # Save as temporary placeholder
        sed -i.bak "/^WHISPER_AUTH_USER=/d" "$ENV_FILE"
        sed -i.bak "/^SPEECH_TEMP_PASSWORD=/d" "$ENV_FILE"
        
        echo "WHISPER_AUTH_USER=$speech_user" >> "$ENV_FILE"
        echo "TTS_AUTH_USER=$speech_user" >> "$ENV_FILE"
        echo "SPEECH_TEMP_PASSWORD=$speech_password" >> "$ENV_FILE"
        echo "# Note: Password hashes will be generated during installation" >> "$ENV_FILE"
    fi
fi

# Make the script executable (though install.sh calls it with bash)
chmod +x "$SCRIPT_DIR/04_wizard.sh"

exit 0 
