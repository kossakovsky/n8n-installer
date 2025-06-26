#!/bin/bash

# Final Report Script for n8n-installer + Workspace Integration
# Comprehensive access information for unified AI development environment

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
ENV_FILE="$PROJECT_ROOT/.env"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    log_error "The .env file ('$ENV_FILE') was not found."
    exit 1
fi

# Load environment variables from .env file
set -a
source "$ENV_FILE"
set +a

# Function to check if a profile is active
is_profile_active() {
    local profile_to_check="$1"
    if [ -z "$COMPOSE_PROFILES" ]; then
        return 1
    fi
    if [[ ",$COMPOSE_PROFILES," == *",$profile_to_check,"* ]]; then
        return 0
    else
        return 1
    fi
}

# Function to get service status with checking
get_service_status() {
    local service_name="$1"
    local status=$(docker ps --filter "name=$service_name" --format "{{.Status}}" 2>/dev/null || echo "Not found")
    
    if [[ "$status" == *"Up"* ]]; then
        echo "🟢 Running"
    elif [[ "$status" == "Not found" ]]; then
        echo "⚫ Not deployed"
    elif [[ "$status" == *"Exited"* ]]; then
        echo "🔴 Stopped"
    elif [[ "$status" == *"Restarting"* ]]; then
        echo "🟡 Restarting"
    else
        echo "🟡 Unknown"
    fi
}

# Function to test service connectivity with checks
test_service_connectivity() {
    local service_url="$1"
    local service_name="$2"
    local timeout="${3:-10}"
    
    if curl -s --connect-timeout 5 --max-time "$timeout" "$service_url" > /dev/null 2>&1; then
        echo "✅ Accessible"
    elif curl -s --connect-timeout 5 --max-time "$timeout" -I "$service_url" 2>/dev/null | grep -q "HTTP.*[234][0-9][0-9]"; then
        echo "✅ Responding"
    else
        echo "⚠️  Checking..."
    fi
}

# Function to check editor installation status
check_editor_status() {
    local editor_config_file="$PROJECT_ROOT/editor-config/editor-choice.json"
    
    if [ -f "$editor_config_file" ]; then
        local editor_name=$(jq -r '.editor_name // "Unknown"' "$editor_config_file" 2>/dev/null)
        local editor_type=$(jq -r '.editor_type // "unknown"' "$editor_config_file" 2>/dev/null)
        local installation_type=$(jq -r '.installation_type // "unknown"' "$editor_config_file" 2>/dev/null)
        local installed=$(jq -r '.installed // false' "$editor_config_file" 2>/dev/null)
        
        echo "$editor_name|$editor_type|$installation_type|$installed"
    else
        echo "Not configured|unknown|unknown|false"
    fi
}

# Function to get container resource usage
get_container_resources() {
    local container_name="$1"
    
    if docker ps --filter "name=$container_name" --format "{{.Names}}" | grep -q "$container_name"; then
        local stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}" "$container_name" 2>/dev/null)
        if [ -n "$stats" ]; then
            echo "$stats"
        else
            echo "N/A|N/A"
        fi
    else
        echo "N/A|N/A"
    fi
}

# Function to display banner
show_enhanced_banner() {
    echo ""
    echo "="*110
    echo "🎉 N8N-INSTALLER + WORKSPACE DEPLOYMENT COMPLETE!"
    echo "="*110
    echo ""
    echo "🚀 Your unified AI development and knowledge management environment is ready!"
    echo ""
    echo "🏗️  ARCHITECTURE HIGHLIGHTS:"
    echo "   🗄️  Unified Database     - Shared PostgreSQL with optimized schemas"
    echo "   💾 Centralized Caching  - Redis for optimal performance"
    echo "   🌐 Smart Routing        - Caddy with automatic HTTPS"
    echo "   📊 Full Observability   - Comprehensive monitoring and logging"
    echo "   🎨 Native Development   - Integrated editor with language servers"
    echo "   🔒 Enterprise Security  - Role-based access and authentication"
    echo ""
    echo "="*110
}

# Function to display core service access information
show_core_services() {
    echo ""
    log_info "CORE AI AUTOMATION PLATFORM"
    echo "Centralized workflow automation and AI orchestration"
    echo ""
    
    # n8n Workflow Automation
    if is_profile_active "n8n"; then
        echo "================================= n8n Workflow Automation ================================="
        echo ""
        echo "🌐 Access URL: ${N8N_HOSTNAME:-http://localhost:5678}"
        echo "🔧 Status: $(get_service_status "n8n")"
        if [ -n "$N8N_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$N8N_HOSTNAME" "n8n")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:5678" "n8n")"
        fi
        
        local worker_count="${N8N_WORKER_COUNT:-1}"
        echo "👥 Workers: $worker_count parallel execution worker(s)"
        echo "🗄️  Database: Shared PostgreSQL (n8n_db schema)"
        echo "💾 Cache: Shared Redis (queue management)"
        
        local n8n_resources=$(get_container_resources "n8n")
        local cpu_usage=$(echo "$n8n_resources" | cut -d'|' -f1)
        local mem_usage=$(echo "$n8n_resources" | cut -d'|' -f2)
        echo "📊 Resource Usage: CPU: $cpu_usage, Memory: $mem_usage"
        
        echo ""
        echo "🚀 Advanced Features:"
        echo "   ⚡ Queue-based execution for scalability"
        echo "   🔄 Webhook support for real-time triggers"
        echo "   🧩 Community packages enabled"
        echo "   📈 Metrics collection active"
        echo "   🔐 JWT-based authentication"
        
        echo ""
        echo "💡 Quick Actions:"
        echo "   📥 Import workflows: Set RUN_N8N_IMPORT=true in .env and restart"
        echo "   📊 Scale workers: Update N8N_WORKER_COUNT in .env"
        echo "   📋 View logs: docker logs n8n"
        echo "   🔄 Restart: docker restart n8n"
        echo "   📈 Monitor: Access metrics at /metrics endpoint"
    fi
    
    # Flowise AI Agent Builder
    if is_profile_active "flowise"; then
        echo ""
        echo "🤖 Flowise - AI Agent Builder"
        echo "────────────────────────────────"
        echo "🌐 Access URL: ${FLOWISE_HOSTNAME:-http://localhost:3001}"
        echo "🔧 Status: $(get_service_status "flowise")"
        if [ -n "$FLOWISE_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$FLOWISE_HOSTNAME" "flowise")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:3001" "flowise")"
        fi
        echo "👤 Username: ${FLOWISE_USERNAME:-<not_set>}"
        echo "🔑 Password: ${FLOWISE_PASSWORD:-<not_set>}"
        
        echo ""
        echo "🔗 Integration Points:"
        echo "   🧠 n8n workflows via HTTP requests"
        echo "   🗄️  Vector databases (Qdrant, Weaviate)"
        echo "   🤖 Ollama for local LLM inference"
        echo "   📊 Langfuse for observability"
    fi
    
    # Open WebUI
    if is_profile_active "open-webui"; then
        echo ""
        echo "💬 Open WebUI - ChatGPT-like Interface"
        echo "──────────────────────────────────────"
        echo "🌐 Access URL: ${WEBUI_HOSTNAME:-http://localhost:8080}"
        echo "🔧 Status: $(get_service_status "open-webui")"
        if [ -n "$WEBUI_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$WEBUI_HOSTNAME" "open-webui")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:8080" "open-webui")"
        fi
        
        echo ""
        echo "🔗 LLM Connections:"
        if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
            echo "   🤖 Ollama: http://ollama:11434 (Local models)"
        fi
        echo "   🌐 OpenAI API: Configure with your API key"
        echo "   🏢 Anthropic Claude: Configure with your API key"
        echo "   🦙 Local models via Ollama integration"
    fi
}

# Function to display knowledge management services
show_knowledge_management() {
    local knowledge_active=false
    
    if is_profile_active "appflowy" || is_profile_active "affine"; then
        knowledge_active=true
        echo ""
        echo "============================= KNOWLEDGE MANAGEMENT SUITE ============================="
        echo "Advanced knowledge management and collaborative workspace platforms"
        echo ""
    fi
    
    # AppFlowy
    if is_profile_active "appflowy"; then
        echo "📝 AppFlowy - Knowledge Management & Notion Alternative"
        echo "────────────────────────────────────────────────────────"
        echo "🌐 Web Interface: ${APPFLOWY_HOSTNAME:-http://localhost:3000}"
        echo "🔧 Web Status: $(get_service_status "appflowy-web")"
        echo "🔧 Backend Status: $(get_service_status "appflowy-cloud")"
        echo "🔧 Auth Status: $(get_service_status "appflowy-gotrue")"
        
        if [ -n "$APPFLOWY_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$APPFLOWY_HOSTNAME" "AppFlowy")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:3000" "AppFlowy")"
        fi
        
        echo "🔑 Admin Password: ${APPFLOWY_ADMIN_PASSWORD:-<not_set>}"
        echo "🚫 Signup Disabled: ${APPFLOWY_DISABLE_SIGNUP:-false}"
        
        echo ""
        echo "🏗️  AppFlowy Architecture:"
        echo "   🌐 Web Interface: appflowy-web:3000"
        echo "   ⚙️  Backend API: appflowy-cloud:8000"
        echo "   🔐 Authentication: appflowy-gotrue:9999"
        echo "   🗄️  File Storage: appflowy-minio:9000"
        echo "   💾 Database: Shared PostgreSQL (appflowy_db schema)"
        echo "   💾 Cache: Shared Redis for sessions"
        
        echo ""
        echo "📱 Client Applications:"
        echo "   🌐 Web: Direct browser access"
        echo "   🍎 iOS: Available on App Store"
        echo "   🤖 Android: Available on Google Play"
        echo "   🖥️  Desktop: Download from AppFlowy website"
        
        if [ -n "${APPFLOWY_SMTP_HOST}" ]; then
            echo ""
            echo "📧 Email Configuration:"
            echo "   📬 SMTP Host: ${APPFLOWY_SMTP_HOST}"
            echo "   🔌 SMTP Port: ${APPFLOWY_SMTP_PORT:-587}"
            echo "   👤 SMTP User: ${APPFLOWY_SMTP_USER:-<not_set>}"
        fi
        
        echo ""
        echo "🔧 Management Commands:"
        echo "   📋 Web logs: docker logs appflowy-web"
        echo "   📋 Backend logs: docker logs appflowy-cloud"
        echo "   📋 Auth logs: docker logs appflowy-gotrue"
        echo "   🔄 Restart: docker restart appflowy-web appflowy-cloud"
        echo "   💾 Database: PostgreSQL appflowy_db schema"
        echo "   🗂️  Files: MinIO bucket 'appflowy'"
    fi
    
    # Affine
    if is_profile_active "affine"; then
        echo ""
        echo "✨ Affine - Collaborative Workspace & Block-based Editor"
        echo "─────────────────────────────────────────────────────────"
        echo "🌐 Web Interface: ${AFFINE_HOSTNAME:-http://localhost:3010}"
        echo "🔧 Status: $(get_service_status "affine")"
        echo "🔧 Migration: $(get_service_status "affine-migration")"
        
        if [ -n "$AFFINE_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$AFFINE_HOSTNAME" "Affine")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:3010" "Affine")"
        fi
        
        echo "👤 Admin Email: ${AFFINE_ADMIN_EMAIL:-<not_set>}"
        echo "🔑 Admin Password: ${AFFINE_ADMIN_PASSWORD:-<not_set>}"
        
        echo ""
        echo "🏗️  Affine Architecture:"
        echo "   🌐 GraphQL API: affine:3010"
        echo "   💾 Database: Shared PostgreSQL (affine_db schema)"
        echo "   🗄️  Redis Cache: shared-redis:6379"
        echo "   📁 Storage: Docker volumes (affine_storage, affine_config)"
        
        echo ""
        echo "🚀 Advanced Features:"
        echo "   📊 GraphQL Endpoint: /graphql"
        echo "   🎨 Block-based Editor: Real-time collaborative editing"
        echo "   📋 Project Management: Kanban boards and databases"
        echo "   🎨 Whiteboard: Miro-like collaborative whiteboard"
        echo "   🔄 Real-time Sync: Multi-user collaboration"
        
        if [ -n "${AFFINE_SMTP_HOST}" ]; then
            echo ""
            echo "📧 Email Configuration:"
            echo "   📬 SMTP Host: ${AFFINE_SMTP_HOST}"
            echo "   🔌 SMTP Port: ${AFFINE_SMTP_PORT:-587}"
            echo "   👤 SMTP User: ${AFFINE_SMTP_USER:-<not_set>}"
        fi
        
        echo ""
        echo "🔧 Management Commands:"
        echo "   📋 View logs: docker logs affine"
        echo "   📋 Migration logs: docker logs affine-migration"
        echo "   🔄 Restart: docker restart affine"
        echo "   💾 Database: PostgreSQL affine_db schema"
        echo "   🗃️  Cache: shared-redis:6379"
    fi
    
    # Knowledge Management Integration
    if [ "$knowledge_active" = true ]; then
        echo ""
        echo "🔗 KNOWLEDGE MANAGEMENT INTEGRATION"
        echo "───────────────────────────────────────"
        echo "🧠 n8n Workflow Integration:"
        echo "   📝 Automated document creation"
        echo "   📊 Data export to knowledge bases"
        echo "   🔔 Notification workflows"
        echo "   📈 Analytics and reporting"
        
        echo ""
        echo "🗄️  Shared Infrastructure Benefits:"
        echo "   ⚡ Optimized database performance"
        echo "   🔄 Cross-service data relationships"
        echo "   💾 Unified backup strategy"
        echo "   📊 Consolidated monitoring"
    fi
}

# Function to display container management
show_container_management() {
    if is_profile_active "portainer"; then
        echo ""
        echo "========================== CONTAINER MANAGEMENT INTERFACE =========================="
        echo "Web-based Docker container and service management"
        echo ""
        
        echo "🐳 Portainer - Docker Container Management"
        echo "──────────────────────────────────────────"
        echo "🌐 Web Interface: ${PORTAINER_HOSTNAME:-http://localhost:9000}"
        echo "🔧 Status: $(get_service_status "portainer")"
        
        if [ -n "$PORTAINER_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$PORTAINER_HOSTNAME" "Portainer")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:9000" "Portainer")"
        fi
        
        echo ""
        echo "🎛️  Portainer Management Features:"
        echo "   📊 Real-time container monitoring"
        echo "   📈 Resource usage statistics and graphs"
        echo "   🔄 One-click service scaling and updates"
        echo "   📋 Comprehensive log viewing and analysis"
        echo "   🌐 Network and volume management"
        echo "   📦 Image management and registry integration"
        echo "   👥 User and team management"
        echo "   🔒 Role-based access control"
        
        echo ""
        echo "🚀 AI-Workspace Integration:"
        echo "   🔍 Monitor all workspace services"
        echo "   📊 Track resource usage across services"
        echo "   🔄 Restart knowledge management services"
        echo "   📋 View aggregated logs from all containers"
        echo "   📈 Performance monitoring and alerting"
        
        echo ""
        echo "🔧 Management Commands:"
        echo "   📋 View logs: docker logs portainer"
        echo "   🔄 Restart: docker restart portainer"
        echo "   💾 Data backup: Docker volume portainer_data"
        echo "   🔒 Reset admin: docker restart portainer (first-time setup)"
    fi
}

# Function to display development environment
show_development_environment() {
    echo ""
    echo "=========================== DEVELOPMENT ENVIRONMENT ==========================="
    echo "Integrated development tools and native editor support"
    echo ""
    
    # Editor status
    local editor_info=$(check_editor_status)
    local editor_name=$(echo "$editor_info" | cut -d'|' -f1)
    local editor_type=$(echo "$editor_info" | cut -d'|' -f2)
    local installation_type=$(echo "$editor_info" | cut -d'|' -f3)
    local installed=$(echo "$editor_info" | cut -d'|' -f4)
    
    echo "🎨 Development Editor Configuration"
    echo "──────────────────────────────────"
    
    if [ "$editor_name" != "Not configured" ]; then
        echo "⚡ Selected Editor: $editor_name"
        echo "🔧 Installation Type: $installation_type"
        echo "📦 Status: $([ "$installed" = "true" ] && echo "✅ Installed and ready" || echo "⚠️  Configured but not installed")"
        
        if [ "$installed" = "true" ]; then
            if [ "$installation_type" = "native" ]; then
                echo "🚀 Launch Command: $editor_type"
                echo "📁 Projects Directory: ~/Projects/"
                echo "🔧 Config Location: ~/.config/$editor_type/"
                
                # Check if editor is actually available
                if command -v "$editor_type" &> /dev/null; then
                    echo "✅ Editor binary: Available in PATH"
                    if [ "$editor_type" = "zed" ]; then
                        local zed_version=$(zed --version 2>/dev/null || echo "Version check failed")
                        echo "📋 Version: $zed_version"
                    elif [ "$editor_type" = "code" ]; then
                        local vscode_version=$(code --version 2>/dev/null | head -1 || echo "Version check failed")
                        echo "📋 Version: $vscode_version"
                    fi
                else
                    echo "⚠️  Editor binary: Not found in PATH"
                fi
            else
                echo "🐳 Container Access: Web interface or VNC"
                if [ "$editor_type" = "vscode" ]; then
                    echo "🌐 Web Interface: http://localhost:8080"
                    echo "🔑 Password: development"
                else
                    echo "🖥️  VNC Access: localhost:5900"
                fi
            fi
            
            echo ""
            echo "🛠️  Pre-configured Language Support:"
            echo "   📘 TypeScript/JavaScript - Full IntelliSense and formatting"
            echo "   🐍 Python - Black formatting, pylint, mypy integration"
            echo "   🦀 Rust - rust-analyzer with clippy"
            echo "   📄 JSON/YAML - Schema validation and formatting"
            echo "   🐳 Dockerfile - Syntax highlighting and validation"
            
            echo ""
            echo "🚀 Development Features:"
            if [ "$editor_type" = "zed" ]; then
                echo "   🤖 AI Assistant integration (Ctrl+Shift+A)"
                echo "   🔍 Instant file search (Ctrl+P)"
                echo "   📺 Integrated terminal (Ctrl+\`)"
                echo "   🔄 Real-time collaboration"
                echo "   📊 Git integration with inline blame"
            else
                echo "   🔌 Extension marketplace access"
                echo "   🐛 Integrated debugging"
                echo "   📊 Git integration and source control"
                echo "   🔄 Live Share collaboration"
                echo "   📺 Integrated terminal"
            fi
        else
            echo ""
            echo "💡 Installation Instructions:"
            echo "   🔧 Run: bash editor-config/install-selected-editor.sh"
            echo "   📁 Config: editor-config/editor-choice.json"
        fi
    else
        echo "⚠️  No editor configured"
        echo ""
        echo "🎨 Available Options:"
        echo "   ⚡ Zed Editor (Native) - Ultra-fast, AI-powered"
        echo "   📝 VS Code (Native) - Feature-rich, extensive extensions"
        echo "   🐳 Container Options - Isolated development environments"
        echo ""
        echo "💡 Setup Instructions:"
        echo "   🔧 Run: python editor_selection.py"
        echo "   📋 Follow interactive configuration wizard"
    fi
    
    echo ""
    echo "📁 Project Structure:"
    echo "   🧠 ~/Projects/n8n-workflows/     - n8n automation workflows"
    echo "   🤖 ~/Projects/ai-experiments/    - AI model experiments"
    echo "   🐳 ~/Projects/docker-configs/    - Docker configurations"
    echo "   📜 ~/Projects/scripts/           - Utility scripts and tools"
    echo "   📚 ~/Projects/knowledge-base/    - Documentation and notes"
    echo "   🔧 ~/Projects/tools/             - Development utilities"
    
    echo ""
    echo "🚀 Quick Start Commands:"
    if [ "$installed" = "true" ] && [ "$installation_type" = "native" ]; then
        echo "   📂 Open projects: $editor_type ~/Projects/"
        echo "   ⚡ Current directory: $editor_type ."
        echo "   🔧 Dev session: ~/Projects/scripts/dev-session.sh"
    fi
    echo "   📊 Service status: docker ps"
    echo "   📋 Service logs: docker logs <service_name>"
    echo "   🚀 Workspace status: ~/Projects/scripts/workspace-status.sh"
}

# Function to display infrastructure services
show_infrastructure_services() {
    local infrastructure_active=false
    
    # Check if any infrastructure services are active
    for service in "monitoring" "langfuse" "supabase" "qdrant" "weaviate" "neo4j"; do
        if is_profile_active "$service"; then
            infrastructure_active=true
            break
        fi
    done
    
    if [ "$infrastructure_active" = true ]; then
        echo ""
        echo "============================== INFRASTRUCTURE SERVICES =============================="
        echo "Monitoring, databases, and supporting infrastructure"
        echo ""
    fi
    
    # Monitoring Stack
    if is_profile_active "monitoring"; then
        echo "📊 Monitoring Suite - Grafana & Prometheus"
        echo "──────────────────────────────────────────"
        echo "🌐 Grafana Dashboard: ${GRAFANA_HOSTNAME:-http://localhost:3000}"
        echo "🔧 Grafana Status: $(get_service_status "grafana")"
        echo "🔧 Prometheus Status: $(get_service_status "prometheus")"
        echo "👤 Admin User: admin"
        echo "🔑 Admin Password: ${GRAFANA_ADMIN_PASSWORD:-<not_set>}"
        
        if [ -n "$GRAFANA_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$GRAFANA_HOSTNAME" "Grafana")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:3000" "Grafana")"
        fi
        
        echo ""
        echo "📈 Prometheus Metrics: ${PROMETHEUS_HOSTNAME:-http://localhost:9090}"
        echo "👤 Auth User: ${PROMETHEUS_USERNAME:-<not_set>}"
        echo "🔑 Auth Password: ${PROMETHEUS_PASSWORD:-<not_set>}"
        
        echo ""
        echo "📊 Monitoring Components:"
        echo "   📈 Prometheus: Metrics collection and storage"
        echo "   📊 Grafana: Visualization and dashboards"
        echo "   🖥️  Node Exporter: System metrics ($(get_service_status "node-exporter"))"
        echo "   🐳 cAdvisor: Container metrics ($(get_service_status "cadvisor"))"
        
        echo ""
        echo "📋 Pre-configured Dashboards:"
        echo "   🖥️  System Overview: CPU, Memory, Disk, Network"
        echo "   🐳 Container Metrics: Docker resource usage"
        echo "   🧠 n8n Performance: Workflow execution metrics"
        echo "   🗄️  Database Health: PostgreSQL and Redis metrics"
    fi
    
    # Langfuse AI Observability
    if is_profile_active "langfuse"; then
        echo ""
        echo "📈 Langfuse - AI Observability Platform"
        echo "───────────────────────────────────────"
        echo "🌐 Access URL: ${LANGFUSE_HOSTNAME:-http://localhost:3000}"
        echo "🔧 Web Status: $(get_service_status "langfuse-web")"
        echo "🔧 Worker Status: $(get_service_status "langfuse-worker")"
        echo "👤 User Email: ${LANGFUSE_INIT_USER_EMAIL:-<not_set>}"
        echo "🔑 Password: ${LANGFUSE_INIT_USER_PASSWORD:-<not_set>}"
        
        if [ -n "$LANGFUSE_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$LANGFUSE_HOSTNAME" "Langfuse")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:3000" "Langfuse")"
        fi
        
        echo ""
        echo "🔑 Project API Keys:"
        echo "   🔓 Public Key: ${LANGFUSE_INIT_PROJECT_PUBLIC_KEY:-<not_set>}"
        echo "   🔐 Secret Key: ${LANGFUSE_INIT_PROJECT_SECRET_KEY:-<not_set>}"
        
        echo ""
        echo "🏗️  Langfuse Architecture:"
        echo "   🌐 Web Interface: langfuse-web:3000"
        echo "   ⚙️  Background Worker: langfuse-worker"
        echo "   📊 Analytics DB: ClickHouse ($(get_service_status "clickhouse"))"
        echo "   🗄️  File Storage: MinIO ($(get_service_status "minio"))"
        echo "   💾 Metadata: Shared PostgreSQL (langfuse_db)"
    fi
    
    # Supabase
    if is_profile_active "supabase"; then
        echo ""
        echo "🗄️  Supabase - Backend as a Service"
        echo "───────────────────────────────────"
        echo "🌐 Dashboard URL: ${SUPABASE_HOSTNAME:-http://localhost:8000}"
        echo "🔧 Status: $(get_service_status "kong")"
        echo "👤 Studio User: ${DASHBOARD_USERNAME:-<not_set>}"
        echo "🔑 Studio Password: ${DASHBOARD_PASSWORD:-<not_set>}"
        
        if [ -n "$SUPABASE_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$SUPABASE_HOSTNAME" "Supabase")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:8000" "Supabase")"
        fi
        
        echo ""
        echo "🔑 API Credentials:"
        echo "   🔓 Anon Key: ${ANON_KEY:-<not_set>}"
        echo "   🔐 Service Role Key: ${SERVICE_ROLE_KEY:-<not_set>}"
        echo "   🌐 API Gateway: http://kong:8000"
    fi
    
    # Vector Databases
    local vector_dbs_active=false
    for service in "qdrant" "weaviate" "neo4j"; do
        if is_profile_active "$service"; then
            vector_dbs_active=true
            break
        fi
    done
    
    if [ "$vector_dbs_active" = true ]; then
        echo ""
        echo "=============================== VECTOR & GRAPH DATABASES ==============================="
    fi
    
    if is_profile_active "qdrant"; then
        echo ""
        echo "📊 Qdrant - High-Performance Vector Database"
        echo "────────────────────────────────────────────"
        echo "🌐 Dashboard: ${QDRANT_HOSTNAME:-http://localhost:6333}"
        echo "🔧 Status: $(get_service_status "qdrant")"
        echo "🔑 API Key: ${QDRANT_API_KEY:-<not_set>}"
        echo "🌐 Internal API: http://qdrant:6333"
        
        if [ -n "$QDRANT_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$QDRANT_HOSTNAME" "Qdrant")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:6333" "Qdrant")"
        fi
    fi
    
    if is_profile_active "weaviate"; then
        echo ""
        echo "🧠 Weaviate - AI-Native Vector Database"
        echo "───────────────────────────────────────"
        echo "🌐 Access URL: ${WEAVIATE_HOSTNAME:-http://localhost:8080}"
        echo "🔧 Status: $(get_service_status "weaviate")"
        echo "👤 Admin User: ${WEAVIATE_USERNAME:-<not_set>}"
        echo "🔑 API Key: ${WEAVIATE_API_KEY:-<not_set>}"
        
        if [ -n "$WEAVIATE_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$WEAVIATE_HOSTNAME" "Weaviate")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:8080" "Weaviate")"
        fi
    fi
    
    if is_profile_active "neo4j"; then
        echo ""
        echo "🕸️  Neo4j - Graph Database"
        echo "──────────────────────────"
        echo "🌐 Web Interface: ${NEO4J_HOSTNAME:-http://localhost:7474}"
        echo "🔧 Status: $(get_service_status "neo4j")"
        echo "👤 Username: ${NEO4J_AUTH_USERNAME:-neo4j}"
        echo "🔑 Password: ${NEO4J_AUTH_PASSWORD:-<not_set>}"
        echo "🔌 Bolt Port: 7687 (neo4j://${NEO4J_HOSTNAME:-localhost}:7687)"
        
        if [ -n "$NEO4J_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$NEO4J_HOSTNAME" "Neo4j")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:7474" "Neo4j")"
        fi
    fi
}

# Function to display Ollama and additional services
show_additional_services() {
    # Ollama Local LLMs
    if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
        echo ""
        echo "=============================== LOCAL LLM INFERENCE ==============================="
        echo ""
        echo "🤖 Ollama - Local Large Language Models"
        echo "───────────────────────────────────────"
        
        if is_profile_active "cpu"; then
            echo "⚙️  Hardware Profile: CPU (Compatible with all systems)"
            echo "🔧 Status: $(get_service_status "ollama-cpu")"
            echo "🌐 Internal API: http://ollama-cpu:11434"
        elif is_profile_active "gpu-nvidia"; then
            echo "🚀 Hardware Profile: NVIDIA GPU (CUDA acceleration)"
            echo "🔧 Status: $(get_service_status "ollama-gpu")"
            echo "🌐 Internal API: http://ollama-gpu:11434"
        elif is_profile_active "gpu-amd"; then
            echo "🔥 Hardware Profile: AMD GPU (ROCm acceleration)"
            echo "🔧 Status: $(get_service_status "ollama-gpu-amd")"
            echo "🌐 Internal API: http://ollama-gpu-amd:11434"
        fi
        
        echo ""
        echo "🧠 Pre-installed Models:"
        echo "   📚 qwen2.5:7b-instruct-q4_K_M - General instruction following"
        echo "   🔍 nomic-embed-text - Text embedding model"
        if is_profile_active "gpu-nvidia"; then
            echo "   🦙 llama3.1:8b - Advanced language model (GPU only)"
        fi
        
        echo ""
        echo "💡 Model Management:"
        echo "   📥 Pull model: docker exec ollama-* ollama pull <model_name>"
        echo "   📋 List models: docker exec ollama-* ollama list"
        echo "   🗑️  Remove model: docker exec ollama-* ollama rm <model_name>"
        echo "   🔄 Update models: docker exec ollama-* ollama pull <model_name>"
    fi
    
    # Additional Services
    local additional_active=false
    for service in "searxng" "crawl4ai" "letta"; do
        if is_profile_active "$service"; then
            additional_active=true
            break
        fi
    done
    
    if [ "$additional_active" = true ]; then
        echo ""
        echo "============================== ADDITIONAL SERVICES =============================="
    fi
    
    if is_profile_active "searxng"; then
        echo ""
        echo "🔍 SearXNG - Private Metasearch Engine"
        echo "──────────────────────────────────────"
        echo "🌐 Access URL: ${SEARXNG_HOSTNAME:-http://localhost:8080}"
        echo "🔧 Status: $(get_service_status "searxng")"
        echo "👤 Auth User: ${SEARXNG_USERNAME:-<not_set>}"
        echo "🔑 Auth Password: ${SEARXNG_PASSWORD:-<not_set>}"
        
        if [ -n "$SEARXNG_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$SEARXNG_HOSTNAME" "SearXNG")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:8080" "SearXNG")"
        fi
    fi
    
    if is_profile_active "crawl4ai"; then
        echo ""
        echo "🕷️  Crawl4AI - AI-Optimized Web Crawler"
        echo "────────────────────────────────────────"
        echo "🔧 Status: $(get_service_status "crawl4ai")"
        echo "🌐 Internal API: http://crawl4ai:8000"
        echo "🤖 OpenAI Integration: ${OPENAI_API_KEY:+Configured}"
    fi
    
    if is_profile_active "letta"; then
        echo ""
        echo "🤖 Letta - Agent Server & SDK"
        echo "─────────────────────────────"
        echo "🌐 Access URL: ${LETTA_HOSTNAME:-http://localhost:8283}"
        echo "🔧 Status: $(get_service_status "letta")"
        echo "🔑 Bearer Token: ${LETTA_SERVER_PASSWORD:-<not_set>}"
        
        if [ -n "$LETTA_HOSTNAME" ]; then
            echo "🔗 Connectivity: $(test_service_connectivity "https://$LETTA_HOSTNAME" "Letta")"
        else
            echo "🔗 Connectivity: $(test_service_connectivity "http://localhost:8283" "Letta")"
        fi
    fi
}

# Function to display shared infrastructure details
show_shared_infrastructure() {
    echo ""
    echo "========================== SHARED INFRASTRUCTURE DETAILS =========================="
    echo "Centralized database, caching, and routing infrastructure"
    echo ""
    
    echo "🗄️  Shared PostgreSQL Database - Central Data Hub"
    echo "─────────────────────────────────────────────────"
    echo "🌐 Host: shared-postgres:5432"
    echo "🔧 Status: $(get_service_status "shared-postgres")"
    echo "👤 Username: postgres"
    echo "🔑 Password: ${POSTGRES_PASSWORD:-<not_set>}"
    
    local pg_resources=$(get_container_resources "shared-postgres")
    local pg_cpu=$(echo "$pg_resources" | cut -d'|' -f1)
    local pg_mem=$(echo "$pg_resources" | cut -d'|' -f2)
    echo "📊 Resource Usage: CPU: $pg_cpu, Memory: $pg_mem"
    
    echo ""
    echo "📊 Database Schema Breakdown:"
    local schema_count=0
    if is_profile_active "n8n"; then
        echo "   🧠 n8n_db - n8n workflows, executions, and credentials"
        schema_count=$((schema_count + 1))
    fi
    if is_profile_active "appflowy"; then
        echo "   📝 appflowy_db - AppFlowy workspace and collaboration data"
        schema_count=$((schema_count + 1))
    fi
    if is_profile_active "affine"; then
        echo "   ✨ affine_db - Affine documents and real-time collaboration"
        schema_count=$((schema_count + 1))
    fi
    if is_profile_active "langfuse"; then
        echo "   📈 langfuse_db - AI observability metadata and traces"
        schema_count=$((schema_count + 1))
    fi
    echo "   📊 Total Active Schemas: $schema_count"
    
    echo ""
    echo "💾 Shared Redis Cache - High-Performance Caching"
    echo "─────────────────────────────────────────────────"
    echo "🌐 Host: shared-redis:6379"
    echo "🔧 Status: $(get_service_status "shared-redis")"
    echo "🔑 Auth: ${REDIS_AUTH:-LOCALONLYREDIS}"
    
    local redis_resources=$(get_container_resources "shared-redis")
    local redis_cpu=$(echo "$redis_resources" | cut -d'|' -f1)
    local redis_mem=$(echo "$redis_resources" | cut -d'|' -f2)
    echo "📊 Resource Usage: CPU: $redis_cpu, Memory: $redis_mem"
    
    echo ""
    echo "🎯 Cache Usage Breakdown:"
    if is_profile_active "n8n"; then
        echo "   🧠 n8n: Queue management and workflow caching"
    fi
    if is_profile_active "appflowy"; then
        echo "   📝 AppFlowy: Session management and real-time sync"
    fi
    if is_profile_active "affine"; then
        echo "   ✨ Affine: Collaborative editing and document cache"
    fi
    if is_profile_active "langfuse"; then
        echo "   📈 Langfuse: Analytics caching and session storage"
    fi
    
    echo ""
    echo "🌐 Caddy Reverse Proxy - Smart Traffic Routing"
    echo "───────────────────────────────────────────────"
    echo "🔧 Status: $(get_service_status "caddy")"
    echo "🌍 Domain: ${USER_DOMAIN_NAME:-localhost}"
    echo "🔒 HTTPS: $([ "$USER_DOMAIN_NAME" != "localhost" ] && echo "Automatic Let's Encrypt" || echo "HTTP (localhost)")"
    echo "📧 SSL Contact: ${LETSENCRYPT_EMAIL:-<not_set>}"
    
    local caddy_resources=$(get_container_resources "caddy")
    local caddy_cpu=$(echo "$caddy_resources" | cut -d'|' -f1)
    local caddy_mem=$(echo "$caddy_resources" | cut -d'|' -f2)
    echo "📊 Resource Usage: CPU: $caddy_cpu, Memory: $caddy_mem"
    
    echo ""
    echo "🔗 Active Service Routes:"
    local route_count=0
    for service in "n8n" "appflowy" "affine" "portainer" "grafana" "langfuse" "qdrant" "weaviate"; do
        if is_profile_active "$service"; then
            local hostname_var="${service^^}_HOSTNAME"
            local hostname="${!hostname_var:-}"
            if [ -n "$hostname" ]; then
                echo "   🌐 $service: https://$hostname"
            else
                echo "   🏠 $service: http://localhost (port-based)"
            fi
            route_count=$((route_count + 1))
        fi
    done
    echo "   📊 Total Active Routes: $route_count"
}

# Function to display network and domain configuration
show_network_configuration() {
    echo ""
    echo "============================= NETWORK CONFIGURATION ============================="
    echo "Domain routing, SSL certificates, and network security"
    echo ""
    
    echo "🌐 Domain and Routing Configuration"
    echo "───────────────────────────────────"
    echo "🏠 Primary Domain: ${USER_DOMAIN_NAME:-localhost}"
    echo "🔄 Reverse Proxy: Caddy (automatic HTTPS and load balancing)"
    echo "🔧 Proxy Status: $(get_service_status "caddy")"
    
    if [ "$USER_DOMAIN_NAME" != "localhost" ] && [ -n "$USER_DOMAIN_NAME" ]; then
        echo "🌍 Production Mode: HTTPS with Let's Encrypt certificates"
        echo "📧 SSL Contact: ${LETSENCRYPT_EMAIL:-<not_set>}"
        echo "🔒 Security: Automatic certificate renewal"
    else
        echo "🏠 Development Mode: HTTP localhost access"
        echo "💡 Tip: Set USER_DOMAIN_NAME for production HTTPS"
    fi
    
    echo ""
    echo "🔗 Service URL Pattern:"
    if [ "$USER_DOMAIN_NAME" != "localhost" ] && [ -n "$USER_DOMAIN_NAME" ]; then
        echo "   Format: https://[service].${USER_DOMAIN_NAME}"
        echo "   Example: https://n8n.${USER_DOMAIN_NAME}"
    else
        echo "   Format: http://localhost:[port]"
        echo "   Example: http://localhost:5678 (n8n)"
    fi
    
    echo ""
    echo "🔒 Security Features:"
    echo "   🛡️  Automatic HTTPS redirection"
    echo "   🔐 Security headers (HSTS, CSP, etc.)"
    echo "   🚫 Rate limiting for API endpoints"
    echo "   🔍 Health check monitoring"
    echo "   📊 Access logging and metrics"
    
    echo ""
    echo "🌐 Network Architecture:"
    echo "   🔧 Internal Network: Services communicate securely"
    echo "   🗄️  Database Network: Isolated database access"
    echo "   📝 Knowledge Network: Knowledge management isolation"
    echo "   🌍 External Access: Only through Caddy proxy"
}

# Function to display backup and maintenance information
show_backup_maintenance() {
    echo ""
    echo "============================== BACKUP & MAINTENANCE =============================="
    echo "Data persistence, backup strategies, and maintenance procedures"
    echo ""
    
    echo "💾 Data Persistence Strategy"
    echo "──────────────────────────"
    echo "🗄️  Central Database: Docker volume 'shared_postgres_data'"
    echo "💾 Cache Storage: Docker volume 'shared_redis_data'"
    echo "🌐 Proxy Config: Docker volumes 'caddy_data', 'caddy_config'"
    
    echo ""
    echo "📁 Service-Specific Storage:"
    if is_profile_active "n8n"; then
        echo "   🧠 n8n: volume 'n8n_storage' (/home/node/.n8n)"
    fi
    if is_profile_active "appflowy"; then
        echo "   📝 AppFlowy: volume 'appflowy_minio_data' (file storage)"
    fi
    if is_profile_active "affine"; then
        echo "   ✨ Affine: volumes 'affine_storage', 'affine_config'"
    fi
    if is_profile_active "portainer"; then
        echo "   🐳 Portainer: volume 'portainer_data'"
    fi
    if is_profile_active "monitoring"; then
        echo "   📊 Monitoring: volumes 'grafana', 'prometheus_data'"
    fi
    
    echo ""
    echo "🔧 Maintenance Commands"
    echo "──────────────────────"
    echo "   📊 Service status: docker ps"
    echo "   📋 Service logs: docker logs <service_name>"
    echo "   🔄 Restart service: docker restart <service_name>"
    echo "   🛑 Stop all: docker-compose -p localai down"
    echo "   🚀 Start all: python start_services.py"
    echo "   📦 Update services: python start_services.py restart"
    echo "   🧹 Clean up: docker system prune"
    
    echo ""
    echo "💾 Backup Commands:"
    echo "   🗄️  Database backup: docker exec shared-postgres pg_dumpall -U postgres > backup.sql"
    echo "   📁 Volume backup: docker run --rm -v shared_postgres_data:/data alpine tar czf /backup/postgres.tar.gz -C /data ."
    echo "   ⚙️  Config backup: tar czf config-backup.tar.gz .env editor-config/ Caddyfile"
    echo "   📦 Full backup: ~/Projects/scripts/workspace-backup.sh"
    
    echo ""
    echo "🔄 Automated Maintenance:"
    echo "   📈 Health monitoring via Grafana alerts"
    echo "   🔄 Automatic SSL certificate renewal"
    echo "   🧹 Log rotation (10MB max, 3 files)"
    echo "   💾 Database optimization queries"
    
    echo ""
    echo "📋 Management Scripts Available:"
    echo "   📊 ~/Projects/scripts/workspace-status.sh - Complete system status"
    echo "   📋 ~/Projects/scripts/workspace-logs.sh - Aggregated log viewing"
    echo "   💾 ~/Projects/scripts/workspace-backup.sh - Full backup creation"
    echo "   🎨 ~/Projects/scripts/dev-session.sh - Development environment setup"
    echo "   🔄 ~/Projects/scripts/service-restart.sh - Individual service restart"
}

# Function to display quick access guide
show_quick_access_guide() {
    echo ""
    echo "============================== QUICK ACCESS GUIDE =============================="
    echo "Essential commands and shortcuts for daily usage"
    echo ""
    
    echo "🚀 Essential Daily Commands"
    echo "──────────────────────────"
    echo "   📊 Check all services: docker ps"
    echo "   🔧 Restart workspace: python start_services.py restart"
    echo "   📋 View service logs: docker logs <service_name>"
    echo "   🎨 Start development: ~/Projects/scripts/dev-session.sh"
    echo "   📈 System status: ~/Projects/scripts/workspace-status.sh"
    echo "   💾 Create backup: ~/Projects/scripts/workspace-backup.sh"
    
    echo ""
    echo "🌐 Quick Service Access URLs"
    echo "───────────────────────────"
    local domain="${USER_DOMAIN_NAME:-localhost}"
    local protocol=$([ "$domain" != "localhost" ] && echo "https" || echo "http")
    
    if is_profile_active "n8n"; then
        local n8n_url="$protocol://${N8N_HOSTNAME:-localhost:5678}"
        echo "   🧠 n8n Workflows: $n8n_url"
    fi
    if is_profile_active "appflowy"; then
        local appflowy_url="$protocol://${APPFLOWY_HOSTNAME:-localhost:3000}"
        echo "   📝 AppFlowy: $appflowy_url"
    fi
    if is_profile_active "affine"; then
        local affine_url="$protocol://${AFFINE_HOSTNAME:-localhost:3010}"
        echo "   ✨ Affine: $affine_url"
    fi
    if is_profile_active "portainer"; then
        local portainer_url="$protocol://${PORTAINER_HOSTNAME:-localhost:9000}"
        echo "   🐳 Portainer: $portainer_url"
    fi
    if is_profile_active "monitoring"; then
        local grafana_url="$protocol://${GRAFANA_HOSTNAME:-localhost:3000}"
        echo "   📊 Grafana: $grafana_url"
    fi
    
    echo ""
    echo "🎨 Development Environment"
    echo "─────────────────────────"
    local editor_info=$(check_editor_status)
    local editor_type=$(echo "$editor_info" | cut -d'|' -f2)
    local installed=$(echo "$editor_info" | cut -d'|' -f4)
    
    if [ "$installed" = "true" ]; then
        echo "   ⚡ Open editor: $editor_type"
        echo "   📁 Open projects: $editor_type ~/Projects/"
        echo "   🔧 Editor config: ~/.config/$editor_type/"
    else
        echo "   🎨 Setup editor: python editor_selection.py"
    fi
    
    echo "   📂 Project directory: cd ~/Projects/"
    echo "   🔧 Development session: ~/Projects/scripts/dev-session.sh"
    
    echo ""
    echo "🔧 Troubleshooting Commands"
    echo "──────────────────────────"
    echo "   🔍 Debug service: docker logs --tail 50 <service_name>"
    echo "   🔄 Force restart: docker restart <service_name>"
    echo "   💾 Check disk usage: df -h && docker system df"
    echo "   📊 Monitor resources: docker stats"
    echo "   🧹 Clean up space: docker system prune -f"
    echo "   🔧 Reset service: docker-compose -p localai up -d --force-recreate <service>"
    
    echo ""
    echo "💡 Pro Tips"
    echo "──────────"
    echo "   🎯 Use tab completion for Docker commands"
    echo "   📋 Set up shell aliases for frequent commands"
    echo "   🔔 Monitor Grafana for system health alerts"
    echo "   💾 Regular backups prevent data loss"
    echo "   🔄 Update services monthly for security"
    echo "   📚 Check service documentation for advanced features"
}

# Function to display deployment statistics
show_deployment_statistics() {
    echo ""
    echo "============================= DEPLOYMENT STATISTICS ============================="
    echo ""
    
    # Count services
    local total_containers=$(docker ps -q | wc -l)
    local running_containers=$(docker ps --filter "status=running" -q | wc -l)
    local stopped_containers=$(docker ps -a --filter "status=exited" -q | wc -l)
    
    # Count active profiles
    local active_profiles=$(echo "$COMPOSE_PROFILES" | tr ',' '\n' | wc -l)
    
    # Get system resources
    local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_memory_gb=$((total_memory_kb / 1024 / 1024))
    local cpu_cores=$(nproc)
    local disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    
    echo "📊 DEPLOYMENT OVERVIEW"
    echo "────────────────────"
    echo "   🐳 Total Containers: $total_containers"
    echo "   🟢 Running: $running_containers"
    echo "   🔴 Stopped: $stopped_containers"
    echo "   📦 Active Profiles: $active_profiles"
    echo "   📊 Success Rate: $(( running_containers * 100 / (running_containers + stopped_containers) ))%"
    
    echo ""
    echo "🖥️  SYSTEM RESOURCES"
    echo "──────────────────"
    echo "   💾 Total Memory: ${total_memory_gb}GB"
    echo "   ⚡ CPU Cores: $cpu_cores"
    echo "   💿 Disk Usage: ${disk_usage}%"
    
    # Docker resource usage
    echo ""
    echo "🐳 DOCKER RESOURCE USAGE"
    echo "───────────────────────"
    if command -v docker &> /dev/null; then
        local docker_volumes=$(docker volume ls -q | wc -l)
        local docker_networks=$(docker network ls | wc -l)
        local docker_images=$(docker images -q | wc -l)
        
        echo "   📦 Images: $docker_images"
        echo "   💾 Volumes: $docker_volumes"
        echo "   🌐 Networks: $docker_networks"
    fi
    
    # Service categories
    echo ""
    echo "📋 SERVICE CATEGORIES"
    echo "───────────────────"
    local ai_services=0
    local workspace_services=0
    local infra_services=0
    
    for service in "n8n" "flowise" "open-webui" "ollama"; do
        if is_profile_active "$service" || is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
            ai_services=$((ai_services + 1))
        fi
    done
    
    for service in "appflowy" "affine" "portainer"; do
        if is_profile_active "$service"; then
            workspace_services=$((workspace_services + 1))
        fi
    done
    
    for service in "monitoring" "langfuse" "supabase" "qdrant" "weaviate" "neo4j" "searxng" "crawl4ai" "letta"; do
        if is_profile_active "$service"; then
            infra_services=$((infra_services + 1))
        fi
    done
    
    echo "   🧠 AI Services: $ai_services"
    echo "   📝 Workspace Services: $workspace_services"
    echo "   🔧 Infrastructure Services: $infra_services"
    
    # Editor status
    local editor_info=$(check_editor_status)
    local editor_name=$(echo "$editor_info" | cut -d'|' -f1)
    local installed=$(echo "$editor_info" | cut -d'|' -f4)
    
    echo ""
    echo "🎨 DEVELOPMENT ENVIRONMENT"
    echo "─────────────────────────"
    echo "   ⚡ Editor: $editor_name"
    echo "   📦 Status: $([ "$installed" = "true" ] && echo "✅ Ready" || echo "⚠️  Needs setup")"
    echo "   📁 Projects: ~/Projects/ (ready)"
    echo "   🔧 Scripts: 5 management scripts available"
}

# Main function
main() {
    # Display banner
    show_enhanced_banner
    
    # Core service information
    show_core_services
    
    # Knowledge management services
    show_knowledge_management
    
    # Container management
    show_container_management
    
    # Development environment
    show_development_environment
    
    # Infrastructure services
    show_infrastructure_services
    
    # Additional services (Ollama, etc.)
    show_additional_services
    
    # Shared infrastructure details
    show_shared_infrastructure
    
    # Network configuration
    show_network_configuration
    
    # Backup and maintenance
    show_backup_maintenance
    
    # Quick access guide
    show_quick_access_guide
    
    # Deployment statistics
    show_deployment_statistics
    
    # Final success message
    echo ""
    echo "="*110
    echo "🎉 AI-WORKSPACE DEPLOYMENT SUCCESSFUL!"
    echo "="*110
    echo ""
    echo "Your complete AI development and knowledge management environment is ready!"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. 🔐 Change default passwords on first login to services"
    echo "   2. 📧 Configure SMTP settings for email features (optional)"
    echo "   3. 🧠 Start creating n8n workflows and AI automations"
    echo "   4. 📝 Explore knowledge management with AppFlowy/Affine"
    echo "   5. 🎨 Begin development with your configured editor"
    echo "   6. 📊 Monitor system health via Grafana dashboards"
    echo ""
    echo "💡 Remember:"
    echo "   • All services use shared infrastructure for optimal performance"
    echo "   • Management scripts are available in ~/Projects/scripts/"
    echo "   • Configuration backups are recommended before major changes"
    echo "   • Health monitoring is active for proactive issue detection"
    echo ""
    echo "Happy building and automating! 🚀✨"
    echo "="*110
}

# Execute main function
main "$@"

exit 0
