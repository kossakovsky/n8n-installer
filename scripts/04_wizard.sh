#!/bin/bash

# Service Selection Wizard for n8n-installer + Workspace Integration
# Script to guide user through service selection including knowledge management tools

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

# Source the utilities file
source "$(dirname "$0")/utils.sh"

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
# Enhanced service definitions including workspace tools
base_services_data=(
    "n8n" "n8n, n8n-worker, n8n-import (Workflow Automation) [CORE]"
    "flowise" "Flowise (No-code AI Agent Builder)"
    "open-webui" "Open WebUI (ChatGPT-like Interface for Local LLMs)"
    "appflowy" "AppFlowy (Knowledge Management & Notion Alternative) [WORKSPACE]"
    "affine" "Affine (Collaborative Workspace & Block-based Editor) [WORKSPACE]"
    "portainer" "Portainer (Docker Container Management Interface) [MANAGEMENT]"
    "monitoring" "Monitoring Suite (Prometheus, Grafana, cAdvisor, Node-Exporter)"
    "langfuse" "Langfuse Suite (AI Observability - includes Clickhouse, MinIO)"
    "qdrant" "Qdrant (High-Performance Vector Database)"
    "supabase" "Supabase (Backend as a Service with Auth & Database)"
    "weaviate" "Weaviate (AI-Native Vector Database with API Key Auth)"
    "neo4j" "Neo4j (Graph Database for Knowledge Graphs)"
    "searxng" "SearXNG (Private Metasearch Engine)"
    "crawl4ai" "Crawl4ai (AI-Optimized Web Crawler)"
    "letta" "Letta (Agent Server & SDK for LLM Backends)"
    "ollama" "Ollama (Local LLM Runner - select hardware in next step)"
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
        # .env has no COMPOSE_PROFILES or it's empty/just quotes, use intelligent defaults
        case "$tag" in
            "n8n"|"flowise"|"monitoring"|"appflowy") status="ON" ;;
            *) status="OFF" ;;
        esac
    fi
    services+=("$tag" "$description" "$status")
    idx=$((idx + 2))
done

# Show introductory message
whiptail --title "Enhanced n8n-installer + Workspace Setup" --msgbox \
"Welcome to the Enhanced n8n-installer with Workspace Integration!

This installer now includes powerful knowledge management and collaboration tools:

🧠 CORE AI AUTOMATION:
• n8n - Workflow automation platform
• Flowise - No-code AI agent builder  
• Open WebUI - Chat interface for local LLMs

📝 WORKSPACE & KNOWLEDGE MANAGEMENT:
• AppFlowy - Modern Notion alternative with AI features
• Affine - Collaborative workspace with real-time editing
• Portainer - Docker container management

🔧 SUPPORTING SERVICES:
• Vector databases (Qdrant, Weaviate)
• Monitoring (Grafana, Prometheus)
• Search (SearXNG) and more...

Next, you'll select which services to deploy." 20 78

# Use whiptail to display the enhanced checklist
CHOICES=$(whiptail --title "Enhanced Service Selection Wizard" --checklist \
  "Choose the services you want to deploy.\n\n🧠 CORE services are recommended for all users\n📝 WORKSPACE services add knowledge management\n🔧 MANAGEMENT services help with administration\n\nUse ARROW KEYS to navigate, SPACEBAR to select/deselect, ENTER to confirm." 25 95 18 \
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
    # Set COMPOSE_PROFILES to core services only
    if [ ! -f "$ENV_FILE" ]; then
        touch "$ENV_FILE"
    fi
    if grep -q "^COMPOSE_PROFILES=" "$ENV_FILE"; then
        sed -i.bak "/^COMPOSE_PROFILES=/d" "$ENV_FILE"
    fi
    echo "COMPOSE_PROFILES=n8n,flowise" >> "$ENV_FILE"
    exit 0
fi

# Process selected services
selected_profiles=()
ollama_selected=0
ollama_profile=""
knowledge_management_selected=0

if [ -n "$CHOICES" ]; then
    # Whiptail returns a string like "tag1" "tag2" "tag3"
    # We need to remove quotes and convert to an array
    temp_choices=()
    eval "temp_choices=($CHOICES)"

    for choice in "${temp_choices[@]}"; do
        if [ "$choice" == "ollama" ]; then
            ollama_selected=1
        elif [ "$choice" == "appflowy" ] || [ "$choice" == "affine" ]; then
            knowledge_management_selected=1
            selected_profiles+=("$choice")
        else
            selected_profiles+=("$choice")
        fi
    done
fi

# Show knowledge management configuration if applicable
if [ $knowledge_management_selected -eq 1 ]; then
    whiptail --title "Knowledge Management Configuration" --msgbox \
"📝 KNOWLEDGE MANAGEMENT SERVICES SELECTED

You've selected AppFlowy and/or Affine for knowledge management:

• AppFlowy: Modern Notion alternative with AI-powered features
  - Block-based editor with real-time collaboration
  - Native support for databases, documents, and wikis
  - Mobile apps available for iOS and Android

• Affine: Next-generation collaborative workspace
  - Combines Notion, Miro, and Monday functionality
  - Real-time collaboration and whiteboard features
  - Advanced database and project management tools

📊 DATABASE INTEGRATION:
Both services will use the shared PostgreSQL database with:
- Automatic schema creation and optimization
- Vector search capabilities for AI features
- Backup and migration support

🔧 CONFIGURATION:
- Admin credentials will be configured automatically
- SMTP settings can be added later for user invitations
- Both services integrate with the n8n workflow system" 22 85
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
        "cpu" "CPU (Recommended for most users - no GPU required)" "$ollama_hw_on_cpu"
        "gpu-nvidia" "NVIDIA GPU (Requires NVIDIA drivers & CUDA toolkit)" "$ollama_hw_on_gpu_nvidia"
        "gpu-amd" "AMD GPU (Requires ROCm drivers - experimental)" "$ollama_hw_on_gpu_amd"
    )
    
    CHOSEN_OLLAMA_PROFILE=$(whiptail --title "Ollama Hardware Profile" --default-item "$default_ollama_hardware" --radiolist \
      "Choose the hardware profile for Ollama LLM inference.\n\nℹ️  CPU Profile:\n• Works on all systems\n• Good for small to medium models (7B parameters)\n• Uses system RAM for model storage\n\n🚀 GPU Profiles:\n• Much faster inference\n• Supports larger models\n• Requires specific drivers" 18 85 3 \
      "${ollama_hardware_options[@]}" \
      3>&1 1>&2 2>&3)

    ollama_exitstatus=$?
    if [ $ollama_exitstatus -eq 0 ] && [ -n "$CHOSEN_OLLAMA_PROFILE" ]; then
        selected_profiles+=("$CHOSEN_OLLAMA_PROFILE")
        ollama_profile="$CHOSEN_OLLAMA_PROFILE" # Store for user message
        log_info "Ollama hardware profile selected: $CHOSEN_OLLAMA_PROFILE"
    else
        log_info "Ollama hardware profile selection cancelled or no choice made. Ollama will not be configured."
        ollama_selected=0
    fi
fi

# Resource requirement check
if [ ${#selected_profiles[@]} -gt 6 ]; then
    whiptail --title "Resource Requirements" --yesno \
"⚠️  RESOURCE REQUIREMENTS WARNING

You've selected ${#selected_profiles[@]} services, which may require significant system resources:

💾 MINIMUM RECOMMENDED:
• RAM: 8GB (16GB preferred for knowledge management)
• CPU: 4 cores (8 cores preferred)
• Storage: 50GB free space
• Network: Stable internet connection

🚀 SELECTED SERVICES REQUIRE:
• PostgreSQL: ~1GB RAM (shared database)
• AppFlowy/Affine: ~2GB RAM each (if selected)
• n8n + Workers: ~1GB RAM  
• Monitoring: ~1GB RAM (if selected)
• Ollama: 4-32GB RAM (depending on models)

Continue with current selection?" 20 75

    if [ $? -ne 0 ]; then
        log_info "User cancelled due to resource requirements. Please restart and select fewer services."
        exit 0
    fi
fi

# Final confirmation and summary
if [ ${#selected_profiles[@]} -eq 0 ]; then
    log_info "No optional services selected. Only core services (n8n, Caddy, PostgreSQL, Redis) will be deployed."
    COMPOSE_PROFILES_VALUE="n8n"
else
    # Build summary message
    SUMMARY_MSG="🎯 DEPLOYMENT SUMMARY\n\nThe following services will be deployed:\n\n"
    
    # Add core services
    SUMMARY_MSG+="🧠 CORE SERVICES:\n"
    SUMMARY_MSG+="• n8n - Workflow Automation\n"
    SUMMARY_MSG+="• PostgreSQL - Shared Database\n"
    SUMMARY_MSG+="• Redis - Caching Layer\n"
    SUMMARY_MSG+="• Caddy - Reverse Proxy\n\n"
    
    # Add selected services by category
    workspace_services=()
    ai_services=()
    infra_services=()
    
    for profile in "${selected_profiles[@]}"; do
        case "$profile" in
            "appflowy"|"affine"|"portainer") workspace_services+=("$profile") ;;
            "flowise"|"open-webui"|"ollama"|"cpu"|"gpu-nvidia"|"gpu-amd"|"qdrant"|"weaviate"|"langfuse") ai_services+=("$profile") ;;
            *) infra_services+=("$profile") ;;
        esac
    done
    
    if [ ${#workspace_services[@]} -gt 0 ]; then
        SUMMARY_MSG+="📝 WORKSPACE SERVICES:\n"
        for service in "${workspace_services[@]}"; do
            case "$service" in
                "appflowy") SUMMARY_MSG+="• AppFlowy - Knowledge Management\n" ;;
                "affine") SUMMARY_MSG+="• Affine - Collaborative Workspace\n" ;;
                "portainer") SUMMARY_MSG+="• Portainer - Container Management\n" ;;
            esac
        done
        SUMMARY_MSG+="\n"
    fi
    
    if [ ${#ai_services[@]} -gt 0 ]; then
        SUMMARY_MSG+="🤖 AI SERVICES:\n"
        for service in "${ai_services[@]}"; do
            case "$service" in
                "flowise") SUMMARY_MSG+="• Flowise - AI Agent Builder\n" ;;
                "open-webui") SUMMARY_MSG+="• Open WebUI - LLM Chat Interface\n" ;;
                "cpu"|"gpu-nvidia"|"gpu-amd") 
                    if [ "$service" == "$ollama_profile" ]; then
                        SUMMARY_MSG+="• Ollama ($service profile) - Local LLMs\n"
                    fi ;;
                "qdrant") SUMMARY_MSG+="• Qdrant - Vector Database\n" ;;
                "weaviate") SUMMARY_MSG+="• Weaviate - AI-Native Vector DB\n" ;;
                "langfuse") SUMMARY_MSG+="• Langfuse - AI Observability\n" ;;
            esac
        done
        SUMMARY_MSG+="\n"
    fi
    
    if [ ${#infra_services[@]} -gt 0 ]; then
        SUMMARY_MSG+="🔧 INFRASTRUCTURE:\n"
        for service in "${infra_services[@]}"; do
            case "$service" in
                "monitoring") SUMMARY_MSG+="• Prometheus + Grafana - Monitoring\n" ;;
                "supabase") SUMMARY_MSG+="• Supabase - Backend as a Service\n" ;;
                "searxng") SUMMARY_MSG+="• SearXNG - Private Search\n" ;;
                "neo4j") SUMMARY_MSG+="• Neo4j - Graph Database\n" ;;
                "crawl4ai") SUMMARY_MSG+="• Crawl4ai - Web Crawler\n" ;;
                "letta") SUMMARY_MSG+="• Letta - Agent Server\n" ;;
            esac
        done
        SUMMARY_MSG+="\n"
    fi
    
    SUMMARY_MSG+="💡 All services will be accessible via:\n"
    SUMMARY_MSG+="• Internal Docker network for inter-service communication\n"
    SUMMARY_MSG+="• Caddy reverse proxy with automatic HTTPS\n"
    SUMMARY_MSG+="• Shared PostgreSQL database for optimal performance"
    
    whiptail --title "Deployment Confirmation" --yesno "$SUMMARY_MSG" 25 90
    
    if [ $? -ne 0 ]; then
        log_info "Deployment cancelled by user. No changes made."
        exit 0
    fi
    
    log_info "You have selected the following service profiles to be deployed:"
    # Join the array into a comma-separated string
    COMPOSE_PROFILES_VALUE=$(IFS=,; echo "${selected_profiles[*]}")
    for profile in "${selected_profiles[@]}"; do
        # Check if the current profile is an Ollama hardware profile that was chosen
        if [[ "$profile" == "cpu" || "$profile" == "gpu-nvidia" || "$profile" == "gpu-amd" ]]; then
            if [ "$profile" == "$ollama_profile" ]; then
                 echo "  - Ollama ($profile profile)"
            fi
        else
            case "$profile" in
                "appflowy") echo "  - AppFlowy (Knowledge Management & Notion Alternative)" ;;
                "affine") echo "  - Affine (Collaborative Workspace & Block-based Editor)" ;;
                "portainer") echo "  - Portainer (Container Management Interface)" ;;
                *) echo "  - $profile" ;;
            esac
        fi
    done
fi

# Update or add COMPOSE_PROFILES in .env file
# Ensure .env file exists (it should have been created by 03_generate_secrets.sh or exist from previous run)
if [ ! -f "$ENV_FILE" ]; then
    log_warning "'.env' file not found at $ENV_FILE. Creating it."
    touch "$ENV_FILE"
fi

# Remove existing COMPOSE_PROFILES line if it exists
if grep -q "^COMPOSE_PROFILES=" "$ENV_FILE"; then
    # Using a different delimiter for sed because a profile name might contain '/' (unlikely here)
    sed -i.bak "\|^COMPOSE_PROFILES=|d" "$ENV_FILE"
fi

# Add the new COMPOSE_PROFILES line
echo "COMPOSE_PROFILES=${COMPOSE_PROFILES_VALUE}" >> "$ENV_FILE"

# Final status message
if [ -z "$COMPOSE_PROFILES_VALUE" ] || [ "$COMPOSE_PROFILES_VALUE" == "n8n" ]; then
    log_info "Core services (n8n, Caddy, PostgreSQL, Redis) will be started."
else
    log_info "The following Docker Compose profiles will be active: ${COMPOSE_PROFILES_VALUE}"
fi

# Display next steps
echo ""
log_info "🎯 CONFIGURATION COMPLETE!"
echo ""
echo "Next steps:"
echo "1. Review your .env file for any additional configuration"
echo "2. Run the installation: bash ./scripts/05_run_services.sh"
echo "3. Access services via the URLs provided in the final report"
echo ""
if [ $knowledge_management_selected -eq 1 ]; then
    echo "📝 Knowledge Management Services:"
    echo "• Configure SMTP settings in .env for user invitations (optional)"
    echo "• Both AppFlowy and Affine will be accessible via web browser"
    echo "• Integration with n8n workflows available for automation"
    echo ""
fi

# Make the script executable (though install.sh calls it with bash)
chmod +x "$SCRIPT_DIR/04_wizard.sh"

exit 0
