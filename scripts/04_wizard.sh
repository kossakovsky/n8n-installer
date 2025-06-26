#!/bin/bash

# Service Selection Wizard for n8n-installer + Workspace Integration
# Includes editor selection, service configuration, and resource optimization

set -e

# Source utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/.env"

source "$(dirname "$0")/utils.sh"

# Store original DEBIAN_FRONTEND and set to dialog for whiptail
ORIGINAL_DEBIAN_FRONTEND="$DEBIAN_FRONTEND"
export DEBIAN_FRONTEND=dialog

# Function to check if whiptail is installed
check_whiptail() {
    if ! command -v whiptail &> /dev/null; then
        log_error "'whiptail' is not installed."
        log_info "This tool is required for the interactive service selection."
        log_info "On Debian/Ubuntu: sudo apt-get install whiptail"
        log_info "Please install whiptail and try again."
        exit 1
    fi
}

# Function to check system resources
check_system_resources() {
    local memory_gb=0
    local cpu_cores=0
    local disk_free_gb=0
    
    # Get memory info
    if [ -f /proc/meminfo ]; then
        local mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        memory_gb=$((mem_kb / 1024 / 1024))
    fi
    
    # Get CPU cores
    cpu_cores=$(nproc 2>/dev/null || echo "1")
    
    # Get disk space
    local disk_avail=$(df / | tail -1 | awk '{print $4}')
    disk_free_gb=$((disk_avail / 1024 / 1024))
    
    echo "$memory_gb,$cpu_cores,$disk_free_gb"
}

# Function to get resource recommendations
get_resource_recommendations() {
    local memory_gb=$1
    local cpu_cores=$2
    local disk_free_gb=$3
    
    local recommendations=()
    
    if [ "$memory_gb" -lt 8 ]; then
        recommendations+=("⚠️  Limited RAM ($memory_gb GB) - Consider lightweight services only")
    elif [ "$memory_gb" -lt 16 ]; then
        recommendations+=("💡 Moderate RAM ($memory_gb GB) - Avoid multiple knowledge services")
    else
        recommendations+=("✅ Sufficient RAM ($memory_gb GB) - All services supported")
    fi
    
    if [ "$cpu_cores" -lt 4 ]; then
        recommendations+=("⚠️  Limited CPU ($cpu_cores cores) - Performance may be affected")
    else
        recommendations+=("✅ Sufficient CPU ($cpu_cores cores)")
    fi
    
    if [ "$disk_free_gb" -lt 20 ]; then
        recommendations+=("⚠️  Low disk space ($disk_free_gb GB) - Monitor usage closely")
    else
        recommendations+=("✅ Sufficient disk space ($disk_free_gb GB)")
    fi
    
    printf "%s\n" "${recommendations[@]}"
}

# Function to read current COMPOSE_PROFILES from .env
read_current_profiles() {
    local current_profiles=""
    if [ -f "$ENV_FILE" ]; then
        local line_content=$(grep "^COMPOSE_PROFILES=" "$ENV_FILE" 2>/dev/null || echo "")
        if [ -n "$line_content" ]; then
            current_profiles=$(echo "$line_content" | cut -d'=' -f2- | sed 's/^"//' | sed 's/"$//')
        fi
    fi
    echo ",$current_profiles,"
}

# Enhanced service definitions including workspace tools and editor options
prepare_service_data() {
    local current_profiles="$1"
    
    base_services_data=(
        # Core AI Services
        "n8n" "n8n Workflow Automation [CORE] - Essential automation platform"
        "flowise" "Flowise AI Agent Builder - No-code AI workflow creation"
        "open-webui" "Open WebUI - ChatGPT-like interface for local LLMs"
        
        # Knowledge Management Services [NEW]
        "appflowy" "AppFlowy Knowledge Management [WORKSPACE] - Notion alternative with AI"
        "affine" "Affine Collaborative Workspace [WORKSPACE] - Block-based editor with real-time collaboration"
        
        # Container Management [NEW]
        "portainer" "Portainer Container Management [MANAGEMENT] - Web-based Docker interface"
        
        # Infrastructure Services
        "monitoring" "Monitoring Suite - Prometheus, Grafana, cAdvisor, Node-Exporter"
        "langfuse" "Langfuse AI Observability - Track and analyze AI model performance"
        "supabase" "Supabase Backend Services - Auth, database, and APIs"
        
        # Vector Databases
        "qdrant" "Qdrant Vector Database - High-performance similarity search"
        "weaviate" "Weaviate AI-Native Vector Database - GraphQL API with vectorization"
        "neo4j" "Neo4j Graph Database - Advanced graph analytics and queries"
        
        # Additional Services
        "searxng" "SearXNG Private Search Engine - Privacy-focused metasearch"
        "crawl4ai" "Crawl4AI Web Crawler - AI-optimized web scraping"
        "letta" "Letta Agent Server - Advanced LLM agent management"
        "ollama" "Ollama Local LLMs - Run models locally (select hardware in next step)"
    )
    
    services=() # Array for whiptail
    
    # Populate services array with current status
    local idx=0
    while [ $idx -lt ${#base_services_data[@]} ]; do
        local tag="${base_services_data[idx]}"
        local description="${base_services_data[idx+1]}"
        local status="OFF"
        
        # Check if service is currently enabled
        if [ -n "$current_profiles" ] && [ "$current_profiles" != '""' ]; then
            if [[ "$tag" == "ollama" ]]; then
                if [[ "$current_profiles" == *",cpu,"* || \
                      "$current_profiles" == *",gpu-nvidia,"* || \
                      "$current_profiles" == *",gpu-amd,"* ]]; then
                    status="ON"
                fi
            elif [[ "$current_profiles" == *",$tag,"* ]]; then
                status="ON"
            fi
        else
            # Default selections for new installations
            case "$tag" in
                "n8n"|"flowise"|"monitoring"|"appflowy") status="ON" ;;
                *) status="OFF" ;;
            esac
        fi
        
        services+=("$tag" "$description" "$status")
        idx=$((idx + 2))
    done
}

# Function to show system analysis
show_system_analysis() {
    local memory_gb=$1
    local cpu_cores=$2
    local disk_free_gb=$3
    
    whiptail --title "System Analysis" --msgbox \
"🖥️  SYSTEM RESOURCE ANALYSIS

Current System Specifications:
💾 Memory: ${memory_gb}GB RAM
⚡ CPU: ${cpu_cores} cores
💿 Disk: ${disk_free_gb}GB available

$(get_resource_recommendations "$memory_gb" "$cpu_cores" "$disk_free_gb")

RECOMMENDATIONS:
• Lightweight setup: n8n + monitoring (4GB+ RAM)
• Standard setup: Add AppFlowy or Affine (8GB+ RAM)  
• Full workspace: All services (16GB+ RAM)
• Performance setup: Add Ollama GPU (32GB+ RAM)

Continue to select services that match your system capabilities." 20 85
}

# Function to show editor selection
show_editor_selection() {
    local editor_configured=false
    local editor_config_file="$PROJECT_ROOT/editor-config/editor-choice.json"
    
    if [ -f "$editor_config_file" ]; then
        editor_configured=true
    fi
    
    if [ "$editor_configured" = true ]; then
        local current_editor=$(jq -r '.editor_name // "Unknown"' "$editor_config_file" 2>/dev/null)
        local install_type=$(jq -r '.installation_type // "unknown"' "$editor_config_file" 2>/dev/null)
        
        whiptail --title "Editor Configuration" --yesno \
"🎨 DEVELOPMENT EDITOR STATUS

Currently configured: $current_editor ($install_type)

The enhanced workspace includes integrated development editor support:

NATIVE EDITORS (Recommended):
• ⚡ Zed Editor - Ultra-fast, AI-powered, collaborative
• 📝 VS Code - Feature-rich with extensive extensions

CONTAINER EDITORS:
• 🐳 Zed Container - Isolated development environment  
• 🌐 VS Code Server - Web-based development interface

Would you like to reconfigure your editor selection?" 18 80
        
        if [ $? -eq 0 ]; then
            run_editor_selection
        fi
    else
        whiptail --title "Editor Setup Required" --yesno \
"🎨 DEVELOPMENT EDITOR SETUP

The enhanced workspace includes integrated development tools. 
You can choose between multiple editor options:

⚡ NATIVE INSTALLATION (Recommended):
   • Best performance and system integration
   • Direct file system access
   • Lower resource usage

🐳 CONTAINER INSTALLATION:
   • Isolated development environment
   • Easy backup and portability
   • Web-based access options

Would you like to configure your development editor now?
(You can also run this later with: python enhanced_editor_selection.py)" 18 85
        
        if [ $? -eq 0 ]; then
            run_editor_selection
        fi
    fi
}

# Function to run editor selection
run_editor_selection() {
    # Check if the enhanced editor selection script exists
    local editor_script="$PROJECT_ROOT/enhanced_editor_selection.py"
    
    if [ ! -f "$editor_script" ]; then
        whiptail --title "Editor Selection" --msgbox \
"❌ Enhanced editor selection script not found.

The editor setup will be skipped. You can manually:
1. Install Zed: curl https://zed.dev/install.sh | sh
2. Install VS Code: Install from Microsoft repository
3. Configure manually in editor-config/ directory" 12 70
        return
    fi
    
    # Temporarily switch back to normal terminal for Python script
    export DEBIAN_FRONTEND="$ORIGINAL_DEBIAN_FRONTEND"
    
    clear
    echo "🎨 Starting Enhanced Editor Selection..."
    echo "======================================"
    
    if python3 "$editor_script"; then
        echo ""
        echo "✅ Editor selection completed successfully!"
        read -p "Press Enter to continue with service selection..."
    else
        echo ""
        echo "⚠️  Editor selection encountered issues. Continuing with service setup..."
        read -p "Press Enter to continue..."
    fi
    
    # Switch back to dialog mode
    export DEBIAN_FRONTEND=dialog
}

# Enhanced service selection with categories
show_enhanced_service_selection() {
    local services=("$@")
    
    CHOICES=$(whiptail --title "Enhanced Service Selection Wizard" --checklist \
"🚀 ENHANCED n8n-INSTALLER + WORKSPACE SERVICES

Select services for your unified AI development environment:

🧠 CORE AI AUTOMATION:
   Essential workflow automation and AI agent platforms

📝 WORKSPACE & KNOWLEDGE:
   Modern knowledge management and collaboration tools
   
🐳 CONTAINER MANAGEMENT:
   Web-based Docker and service management

🔧 INFRASTRUCTURE:
   Monitoring, databases, and supporting services

💡 RESOURCE TIPS:
   • Start with Core services (4GB+ RAM)
   • Add Workspace services (8GB+ RAM)
   • Full setup recommended for 16GB+ RAM

Use ARROW KEYS to navigate, SPACEBAR to select, ENTER to confirm." 25 95 18 \
      "${services[@]}" \
      3>&1 1>&2 2>&3)
    
    echo "$CHOICES"
}

# Function to handle Ollama hardware selection
select_ollama_hardware() {
    local current_profiles="$1"
    
    # Determine current selection
    local default_hardware="cpu"
    local hw_on_cpu="OFF"
    local hw_on_gpu_nvidia="OFF" 
    local hw_on_gpu_amd="OFF"
    
    if [[ "$current_profiles" == *",cpu,"* ]]; then
        hw_on_cpu="ON"
        default_hardware="cpu"
    elif [[ "$current_profiles" == *",gpu-nvidia,"* ]]; then
        hw_on_gpu_nvidia="ON"
        default_hardware="gpu-nvidia"
    elif [[ "$current_profiles" == *",gpu-amd,"* ]]; then
        hw_on_gpu_amd="ON"
        default_hardware="gpu-amd"
    else
        hw_on_cpu="ON"
    fi
    
    local ollama_options=(
        "cpu" "CPU - Works on all systems, good for 7B models" "$hw_on_cpu"
        "gpu-nvidia" "NVIDIA GPU - Requires CUDA drivers, much faster" "$hw_on_gpu_nvidia"
        "gpu-amd" "AMD GPU - Requires ROCm drivers (experimental)" "$hw_on_gpu_amd"
    )
    
    CHOSEN_OLLAMA=$(whiptail --title "Ollama Hardware Configuration" --default-item "$default_hardware" --radiolist \
"🤖 OLLAMA LOCAL LLM HARDWARE SELECTION

Choose the hardware acceleration for Ollama:

💾 SYSTEM REQUIREMENTS:
CPU Mode:  4GB+ RAM, any system
GPU Mode:  8GB+ VRAM, 16GB+ RAM, proper drivers

🚀 PERFORMANCE COMPARISON:
CPU:       ~5-15 tokens/sec (7B models)
NVIDIA:    ~50-200 tokens/sec (larger models supported)
AMD:       ~30-100 tokens/sec (experimental support)

📦 DRIVER REQUIREMENTS:
NVIDIA:    CUDA toolkit and drivers
AMD:       ROCm drivers and libraries
CPU:       No additional requirements

Select the option that matches your hardware:" 22 85 3 \
      "${ollama_options[@]}" \
      3>&1 1>&2 2>&3)
    
    echo "$CHOSEN_OLLAMA"
}

# Function to show workspace integration information
show_workspace_integration() {
    local selected_services="$1"
    
    # Check which workspace services are selected
    local has_knowledge_mgmt=false
    local has_container_mgmt=false
    local has_ai_services=false
    
    if [[ "$selected_services" == *"appflowy"* || "$selected_services" == *"affine"* ]]; then
        has_knowledge_mgmt=true
    fi
    
    if [[ "$selected_services" == *"portainer"* ]]; then
        has_container_mgmt=true
    fi
    
    if [[ "$selected_services" == *"n8n"* || "$selected_services" == *"flowise"* ]]; then
        has_ai_services=true
    fi
    
    local integration_info="🔗 WORKSPACE INTEGRATION FEATURES\n\n"
    
    if [ "$has_ai_services" = true ] && [ "$has_knowledge_mgmt" = true ]; then
        integration_info+="🧠 AI ↔️ Knowledge Management:\n"
        integration_info+="   • Automated documentation generation\n"
        integration_info+="   • Workflow-driven content creation\n"
        integration_info+="   • AI-powered knowledge search\n\n"
    fi
    
    if [ "$has_container_mgmt" = true ]; then
        integration_info+="🐳 Container Management:\n"
        integration_info+="   • Visual service monitoring\n"
        integration_info+="   • One-click service restarts\n"
        integration_info+="   • Resource usage tracking\n\n"
    fi
    
    integration_info+="🗄️ Unified Architecture:\n"
    integration_info+="   • Shared PostgreSQL database\n"
    integration_info+="   • Centralized Redis caching\n"
    integration_info+="   • Caddy reverse proxy with HTTPS\n"
    integration_info+="   • Optimized resource allocation\n\n"
    
    integration_info+="🎨 Development Integration:\n"
    integration_info+="   • Native editor installation\n"
    integration_info+="   • Project template generation\n"
    integration_info+="   • Language server configuration\n"
    integration_info+="   • Git workflow integration"
    
    whiptail --title "Workspace Integration" --msgbox "$integration_info" 22 80
}

# Function to show resource requirements warning
check_resource_requirements() {
    local selected_services="$1"
    local memory_gb=$2
    local cpu_cores=$3
    local disk_free_gb=$4
    
    local service_count=$(echo "$selected_services" | tr ' ' '\n' | wc -l)
    local estimated_ram=2 # Base overhead
    local estimated_cpu=1
    local estimated_disk=5
    
    # Calculate resource requirements
    for service in $selected_services; do
        case "$service" in
            "n8n") estimated_ram=$((estimated_ram + 2)); estimated_cpu=$((estimated_cpu + 1)) ;;
            "appflowy") estimated_ram=$((estimated_ram + 3)); estimated_cpu=$((estimated_cpu + 1)) ;;
            "affine") estimated_ram=$((estimated_ram + 2)); estimated_cpu=$((estimated_cpu + 1)) ;;
            "monitoring") estimated_ram=$((estimated_ram + 2)); estimated_cpu=$((estimated_cpu + 1)) ;;
            "langfuse") estimated_ram=$((estimated_ram + 3)); estimated_cpu=$((estimated_cpu + 1)) ;;
            "ollama"|"cpu"|"gpu-nvidia"|"gpu-amd") estimated_ram=$((estimated_ram + 4)); estimated_cpu=$((estimated_cpu + 2)) ;;
            *) estimated_ram=$((estimated_ram + 1)) ;;
        esac
        estimated_disk=$((estimated_disk + 2))
    done
    
    local warnings=()
    
    if [ "$estimated_ram" -gt "$memory_gb" ]; then
        warnings+=("⚠️ RAM: Need ${estimated_ram}GB, have ${memory_gb}GB")
    fi
    
    if [ "$estimated_cpu" -gt "$cpu_cores" ]; then
        warnings+=("⚠️ CPU: Need ${estimated_cpu} cores, have ${cpu_cores}")
    fi
    
    if [ "$estimated_disk" -gt "$disk_free_gb" ]; then
        warnings+=("⚠️ Disk: Need ${estimated_disk}GB, have ${disk_free_gb}GB available")
    fi
    
    if [ ${#warnings[@]} -gt 0 ]; then
        local warning_text="⚠️ RESOURCE REQUIREMENTS WARNING\n\n"
        warning_text+="Selected ${service_count} services may require:\n"
        warning_text+="💾 RAM: ~${estimated_ram}GB\n"
        warning_text+="⚡ CPU: ~${estimated_cpu} cores\n" 
        warning_text+="💿 Disk: ~${estimated_disk}GB\n\n"
        warning_text+="DETECTED ISSUES:\n"
        
        for warning in "${warnings[@]}"; do
            warning_text+="   $warning\n"
        done
        
        warning_text+="\nCONTINUE WITH CURRENT SELECTION?\n"
        warning_text+="Services may run slower or fail to start."
        
        whiptail --title "Resource Requirements" --yesno "$warning_text" 18 75
        return $?
    fi
    
    return 0
}

# Function to show deployment summary
show_deployment_summary() {
    local selected_profiles="$1"
    local editor_configured="$2"
    
    local summary="🎯 DEPLOYMENT SUMMARY\n\n"
    
    # Core infrastructure
    summary+="🏗️ CORE INFRASTRUCTURE:\n"
    summary+="   ✅ PostgreSQL - Shared database\n"
    summary+="   ✅ Redis - Caching layer\n"
    summary+="   ✅ Caddy - Reverse proxy with HTTPS\n\n"
    
    # Selected services by category
    local ai_services=()
    local workspace_services=()
    local infra_services=()
    
    for profile in $selected_profiles; do
        case "$profile" in
            "n8n"|"flowise"|"open-webui"|"cpu"|"gpu-nvidia"|"gpu-amd"|"ollama") 
                ai_services+=("$profile") ;;
            "appflowy"|"affine"|"portainer") 
                workspace_services+=("$profile") ;;
            *) 
                infra_services+=("$profile") ;;
        esac
    done
    
    if [ ${#ai_services[@]} -gt 0 ]; then
        summary+="🧠 AI SERVICES:\n"
        for service in "${ai_services[@]}"; do
            case "$service" in
                "n8n") summary+="   ✅ n8n - Workflow automation\n" ;;
                "flowise") summary+="   ✅ Flowise - AI agent builder\n" ;;
                "open-webui") summary+="   ✅ Open WebUI - LLM interface\n" ;;
                "cpu"|"gpu-nvidia"|"gpu-amd") 
                    summary+="   ✅ Ollama ($service) - Local LLMs\n" ;;
            esac
        done
        summary+="\n"
    fi
    
    if [ ${#workspace_services[@]} -gt 0 ]; then
        summary+="📝 WORKSPACE SERVICES:\n"
        for service in "${workspace_services[@]}"; do
            case "$service" in
                "appflowy") summary+="   ✅ AppFlowy - Knowledge management\n" ;;
                "affine") summary+="   ✅ Affine - Collaborative workspace\n" ;;
                "portainer") summary+="   ✅ Portainer - Container management\n" ;;
            esac
        done
        summary+="\n"
    fi
    
    if [ ${#infra_services[@]} -gt 0 ]; then
        summary+="🔧 INFRASTRUCTURE:\n"
        for service in "${infra_services[@]}"; do
            case "$service" in
                "monitoring") summary+="   ✅ Grafana + Prometheus\n" ;;
                "langfuse") summary+="   ✅ Langfuse - AI observability\n" ;;
                "supabase") summary+="   ✅ Supabase - Backend services\n" ;;
                "qdrant") summary+="   ✅ Qdrant - Vector database\n" ;;
                "weaviate") summary+="   ✅ Weaviate - AI vector DB\n" ;;
                "neo4j") summary+="   ✅ Neo4j - Graph database\n" ;;
                "searxng") summary+="   ✅ SearXNG - Private search\n" ;;
                "crawl4ai") summary+="   ✅ Crawl4AI - Web crawler\n" ;;
                "letta") summary+="   ✅ Letta - Agent server\n" ;;
            esac
        done
        summary+="\n"
    fi
    
    # Development environment
    summary+="🎨 DEVELOPMENT ENVIRONMENT:\n"
    if [ "$editor_configured" = "true" ]; then
        summary+="   ✅ Editor configured and ready\n"
    else
        summary+="   ⚠️ Editor not configured (optional)\n"
    fi
    summary+="   ✅ Project structure setup\n"
    summary+="   ✅ Management scripts included\n\n"
    
    # Next steps
    summary+="🚀 NEXT STEPS:\n"
    summary+="   1. Services will start automatically\n"
    summary+="   2. Access via web interfaces\n"
    summary+="   3. Check final report for URLs\n"
    summary+="   4. Start developing with your editor!"
    
    whiptail --title "Deployment Summary" --msgbox "$summary" 24 80
}

# Main function
main() {
    check_whiptail
    
    # Get system resources
    local resource_info=$(check_system_resources)
    local memory_gb=$(echo "$resource_info" | cut -d',' -f1)
    local cpu_cores=$(echo "$resource_info" | cut -d',' -f2)
    local disk_free_gb=$(echo "$resource_info" | cut -d',' -f3)
    
    # Show system analysis
    show_system_analysis "$memory_gb" "$cpu_cores" "$disk_free_gb"
    
    # Check for editor configuration
    show_editor_selection
    local editor_configured=false
    if [ -f "$PROJECT_ROOT/editor-config/editor-choice.json" ]; then
        editor_configured=true
    fi
    
    # Read current profiles
    local current_profiles=$(read_current_profiles)
    
    # Prepare service data
    prepare_service_data "$current_profiles"
    
    # Show service selection
    local choices=$(show_enhanced_service_selection "${services[@]}")
    
    # Exit if user cancelled
    if [ $? -ne 0 ]; then
        log_info "Service selection cancelled by user."
        exit 0
    fi
    
    # Process selections
    local selected_profiles=()
    local ollama_selected=false
    local knowledge_selected=false
    
    if [ -n "$choices" ]; then
        eval "temp_choices=($choices)"
        
        for choice in "${temp_choices[@]}"; do
            if [ "$choice" == "ollama" ]; then
                ollama_selected=true
            elif [ "$choice" == "appflowy" ] || [ "$choice" == "affine" ]; then
                knowledge_selected=true
                selected_profiles+=("$choice")
            else
                selected_profiles+=("$choice")
            fi
        done
    fi
    
    # Handle Ollama hardware selection
    if [ "$ollama_selected" = true ]; then
        local ollama_hardware=$(select_ollama_hardware "$current_profiles")
        if [ -n "$ollama_hardware" ]; then
            selected_profiles+=("$ollama_hardware")
        else
            ollama_selected=false
        fi
    fi
    
    # Show workspace integration info if relevant
    if [ "$knowledge_selected" = true ] || [ "$ollama_selected" = true ]; then
        show_workspace_integration "${selected_profiles[*]}"
    fi
    
    # Check resource requirements
    if ! check_resource_requirements "${selected_profiles[*]}" "$memory_gb" "$cpu_cores" "$disk_free_gb"; then
        log_info "Deployment cancelled due to resource constraints."
        exit 0
    fi
    
    # Show final summary and confirm
    show_deployment_summary "${selected_profiles[*]}" "$editor_configured"
    
    if ! whiptail --title "Final Confirmation" --yesno \
"🚀 START ENHANCED WORKSPACE DEPLOYMENT?

This will:
• Configure ${#selected_profiles[@]} services
• Set up unified database and caching
• Configure reverse proxy with HTTPS
• Create development environment
• Generate management scripts

Estimated deployment time: 5-15 minutes

Proceed with deployment?" 15 60; then
        log_info "Deployment cancelled by user."
        exit 0
    fi
    
    # Build final profiles string
    local compose_profiles_value=""
    if [ ${#selected_profiles[@]} -gt 0 ]; then
        compose_profiles_value=$(IFS=,; echo "${selected_profiles[*]}")
    else
        compose_profiles_value="n8n"
    fi
    
    # Update .env file
    if [ ! -f "$ENV_FILE" ]; then
        log_warning ".env file not found. Creating minimal version."
        touch "$ENV_FILE"
    fi
    
    # Remove existing COMPOSE_PROFILES line
    if grep -q "^COMPOSE_PROFILES=" "$ENV_FILE"; then
        sed -i.bak "/^COMPOSE_PROFILES=/d" "$ENV_FILE"
    fi
    
    # Add new COMPOSE_PROFILES line
    echo "COMPOSE_PROFILES=${compose_profiles_value}" >> "$ENV_FILE"
    
    # Restore DEBIAN_FRONTEND
    if [ -n "$ORIGINAL_DEBIAN_FRONTEND" ]; then
        export DEBIAN_FRONTEND="$ORIGINAL_DEBIAN_FRONTEND"
    else
        unset DEBIAN_FRONTEND
    fi
    
    # Success message
    log_success "Enhanced workspace configuration completed!"
    echo ""
    log_info "Selected profiles: ${compose_profiles_value}"
    log_info "Editor configured: $editor_configured"
    echo ""
    log_info "🎯 Configuration saved to .env file"
    log_info "🚀 Ready to start services with: python start_services.py"
    echo ""
    
    if [ "$knowledge_selected" = true ]; then
        log_info "📝 Knowledge Management Services Enabled:"
        log_info "   • Unified database for optimal performance"
        log_info "   • Integrated with n8n workflows"
        log_info "   • Real-time collaboration features"
        echo ""
    fi
    
    if [ "$editor_configured" = true ]; then
        log_info "🎨 Development Environment Ready:"
        log_info "   • Editor installation will be handled automatically"
        log_info "   • Project structure will be created"
        log_info "   • Language servers will be configured"
    fi
}

# Execute main function
main "$@"

exit 0
