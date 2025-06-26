#!/bin/bash

# Enhanced Final Report Script for n8n-installer + Workspace Integration
# Displays comprehensive access information for all deployed services

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Get the directory where the script resides
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
        return 1 # Not active if COMPOSE_PROFILES is empty or not set
    fi
    # Check if the profile_to_check is in the comma-separated list
    if [[ ",$COMPOSE_PROFILES," == *",$profile_to_check,"* ]]; then
        return 0 # Active
    else
        return 1 # Not active
    fi
}

# Function to check if Zed is installed
check_zed_installation() {
    if command -v zed &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to get service status
get_service_status() {
    local service_name="$1"
    local status=$(docker ps --filter "name=$service_name" --format "{{.Status}}" 2>/dev/null || echo "Not found")
    if [[ "$status" == *"Up"* ]]; then
        echo "🟢 Running"
    elif [[ "$status" == "Not found" ]]; then
        echo "⚫ Not deployed"
    else
        echo "🔴 Stopped"
    fi
}

# Function to test service connectivity
test_service_connectivity() {
    local service_url="$1"
    local service_name="$2"
    
    if curl -s --connect-timeout 5 --max-time 10 "$service_url" > /dev/null 2>&1; then
        echo "✅ Accessible"
    else
        echo "⚠️  Checking..."
    fi
}

# Function to display enhanced banner
show_enhanced_banner() {
    echo ""
    echo "="*100
    echo "🎉 ENHANCED n8n-INSTALLER + WORKSPACE-IN-A-BOX DEPLOYMENT COMPLETE!"
    echo "="*100
    echo ""
    echo "🚀 Your unified AI development and knowledge management workspace is ready!"
    echo ""
    echo "Key Features Deployed:"
    echo "  🧠 AI Automation Platform (n8n, Flowise, Open WebUI)"
    echo "  📝 Knowledge Management Suite (AppFlowy, Affine)" 
    echo "  🐳 Container Management (Portainer)"
    echo "  ⚡ Native Development Environment (Zed Editor)"
    echo "  🗄️ Unified Database Architecture (Shared PostgreSQL)"
    echo "  🌐 Domain-based Routing (Caddy Reverse Proxy)"
    echo ""
    echo "="*100
}

# Display the enhanced banner
show_enhanced_banner

# --- Core Service Access Information ---
echo ""
log_info "CORE SERVICE ACCESS CREDENTIALS"
echo "Save this information securely for future reference!"
echo ""

# Core n8n service
if is_profile_active "n8n"; then
  echo "================================= n8n Workflow Automation ================================="
  echo ""
  echo "🌐 Access URL: ${N8N_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "n8n")"
  if [ -n "$N8N_HOSTNAME" ]; then
      echo "🔗 Connectivity: $(test_service_connectivity "https://$N8N_HOSTNAME" "n8n")"
  fi
  echo "📊 Workers: ${N8N_WORKER_COUNT:-1} parallel execution worker(s)"
  echo "🗄️ Database: Shared PostgreSQL (n8n_db)"
  echo "💾 Cache: Shared Redis"
  echo ""
  echo "💡 Quick Actions:"
  echo "   - Import workflows: Set RUN_N8N_IMPORT=true in .env and restart"
  echo "   - Scale workers: Update N8N_WORKER_COUNT in .env and restart"
  echo "   - View logs: docker logs n8n"
  echo "   - Access queue: Redis at shared-redis:6379"
fi

# Knowledge Management Services
knowledge_services_active=false
if is_profile_active "appflowy" || is_profile_active "affine"; then
    knowledge_services_active=true
    echo ""
    echo "============================= KNOWLEDGE MANAGEMENT SUITE ============================="
fi

if is_profile_active "appflowy"; then
  echo ""
  echo "📝 AppFlowy - Knowledge Management & Notion Alternative"
  echo "────────────────────────────────────────────────────────"
  echo "🌐 Web Interface: https://${APPFLOWY_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "appflowy-web")"
  if [ -n "$APPFLOWY_HOSTNAME" ]; then
      echo "🔗 Connectivity: $(test_service_connectivity "https://$APPFLOWY_HOSTNAME" "AppFlowy")"
  fi
  echo "👤 Admin Password: ${APPFLOWY_ADMIN_PASSWORD:-<not_set_in_env>}"
  echo "🚫 Signup Disabled: ${APPFLOWY_DISABLE_SIGNUP:-false}"
  echo ""
  echo "🏗️ AppFlowy Architecture:"
  echo "   🌐 Web Interface: appflowy-web:3000"
  echo "   ⚙️  Backend API: appflowy-cloud:8000"
  echo "   🔐 Authentication: appflowy-gotrue:9999"
  echo "   🗄️ File Storage: appflowy-minio:9000"
  echo "   💾 Database: Shared PostgreSQL (appflowy_db)"
  echo ""
  echo "📱 Mobile Apps:"
  echo "   🍎 iOS: Available on App Store (connect to your instance)"
  echo "   🤖 Android: Available on Google Play (connect to your instance)"
  echo ""
  if [[ -n "${APPFLOWY_SMTP_HOST}" ]]; then
    echo "📧 Email Configuration:"
    echo "   📬 SMTP Host: ${APPFLOWY_SMTP_HOST}"
    echo "   🔌 SMTP Port: ${APPFLOWY_SMTP_PORT:-587}"
    echo "   👤 SMTP User: ${APPFLOWY_SMTP_USER:-<not_set>}"
    echo ""
  fi
  echo "🔧 Management Commands:"
  echo "   📋 View logs: docker logs appflowy-web"
  echo "   🔄 Restart service: docker restart appflowy-web appflowy-cloud"
  echo "   💾 Database access: PostgreSQL appflowy_db"
  echo "   🗂️ File storage: MinIO bucket 'appflowy'"
fi

if is_profile_active "affine"; then
  echo ""
  echo "✨ Affine - Collaborative Workspace & Block-based Editor"
  echo "─────────────────────────────────────────────────────────"
  echo "🌐 Web Interface: https://${AFFINE_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "affine")"
  if [ -n "$AFFINE_HOSTNAME" ]; then
      echo "🔗 Connectivity: $(test_service_connectivity "https://$AFFINE_HOSTNAME" "Affine")"
  fi
  echo "👤 Admin Email: ${AFFINE_ADMIN_EMAIL:-<not_set_in_env>}"
  echo "🔑 Admin Password: ${AFFINE_ADMIN_PASSWORD:-<not_set_in_env>}"
  echo ""
  echo "🏗️ Affine Architecture:"
  echo "   🌐 GraphQL API: affine:3010"
  echo "   💾 Database: Shared PostgreSQL (affine_db)"
  echo "   🗄️ Redis Cache: shared-redis:6379"
  echo "   📁 Storage: Docker volumes (affine_storage, affine_config)"
  echo ""
  echo "🚀 Advanced Features:"
  echo "   📊 GraphQL Endpoint: https://${AFFINE_HOSTNAME}/graphql"
  echo "   🎨 Block-based Editor: Real-time collaborative editing"
  echo "   📋 Project Management: Kanban boards and databases"
  echo "   🎨 Whiteboard: Miro-like collaborative whiteboard"
  echo ""
  if [[ -n "${AFFINE_SMTP_HOST}" ]]; then
    echo "📧 Email Configuration:"
    echo "   📬 SMTP Host: ${AFFINE_SMTP_HOST}"
    echo "   🔌 SMTP Port: ${AFFINE_SMTP_PORT:-587}"
    echo "   👤 SMTP User: ${AFFINE_SMTP_USER:-<not_set>}"
    echo ""
  fi
  echo "🔧 Management Commands:"
  echo "   📋 View logs: docker logs affine"
  echo "   🔄 Restart service: docker restart affine"
  echo "   💾 Database access: PostgreSQL affine_db"
  echo "   🗃️ Redis access: shared-redis:6379"
fi

# Container Management
if is_profile_active "portainer"; then
  echo ""
  echo "========================== CONTAINER MANAGEMENT INTERFACE =========================="
  echo ""
  echo "🐳 Portainer - Docker Container Management"
  echo "──────────────────────────────────────────"
  echo "🌐 Web Interface: https://${PORTAINER_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "portainer")"
  if [ -n "$PORTAINER_HOSTNAME" ]; then
      echo "🔗 Connectivity: $(test_service_connectivity "https://$PORTAINER_HOSTNAME" "Portainer")"
  fi
  echo ""
  echo "🎛️ Portainer Features:"
  echo "   📊 Container monitoring and management"
  echo "   📈 Resource usage statistics"
  echo "   🔄 Service scaling and updates"
  echo "   📋 Log viewing and analysis"
  echo "   🌐 Network and volume management"
  echo ""
  echo "🔧 Management Commands:"
  echo "   📋 View logs: docker logs portainer"
  echo "   🔄 Restart service: docker restart portainer"
  echo "   💾 Data location: Docker volume portainer_data"
fi

# AI Services
if is_profile_active "flowise" || is_profile_active "open-webui"; then
  echo ""
  echo "================================ AI SERVICE INTERFACES ================================"
fi

if is_profile_active "flowise"; then
  echo ""
  echo "🤖 Flowise - No-code AI Agent Builder"
  echo "─────────────────────────────────────"
  echo "🌐 Access URL: ${FLOWISE_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "flowise")"
  echo "👤 Username: ${FLOWISE_USERNAME:-<not_set_in_env>}"
  echo "🔑 Password: ${FLOWISE_PASSWORD:-<not_set_in_env>}"
  echo ""
  echo "🔗 Integration Points:"
  echo "   🧠 n8n workflows via HTTP requests"
  echo "   🗄️ Vector databases (Qdrant, Weaviate)"
  echo "   🤖 Ollama for local LLM inference"
fi

if is_profile_active "open-webui"; then
  echo ""
  echo "💬 Open WebUI - ChatGPT-like Interface"
  echo "──────────────────────────────────────"
  echo "🌐 Access URL: ${WEBUI_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "open-webui")"
  echo ""
  echo "🔗 LLM Connections:"
  if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
      echo "   🤖 Ollama: http://ollama:11434 (Local models)"
  fi
  echo "   🌐 OpenAI API: Configure with API key"
  echo "   🏢 Anthropic Claude: Configure with API key"
fi

# Infrastructure Services
infrastructure_active=false
if is_profile_active "supabase" || is_profile_active "monitoring" || is_profile_active "langfuse"; then
    infrastructure_active=true
    echo ""
    echo "============================== INFRASTRUCTURE SERVICES =============================="
fi

if is_profile_active "supabase"; then
  echo ""
  echo "🗄️ Supabase - Backend as a Service"
  echo "───────────────────────────────────"
  echo "🌐 Dashboard URL: ${SUPABASE_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "kong")"
  echo "👤 Studio User: ${DASHBOARD_USERNAME:-<not_set_in_env>}"
  echo "🔑 Studio Password: ${DASHBOARD_PASSWORD:-<not_set_in_env>}"
  echo ""
  echo "🔑 API Credentials:"
  echo "   🔓 Anon Key: ${ANON_KEY:-<not_set_in_env>}"
  echo "   🔐 Service Role Key: ${SERVICE_ROLE_KEY:-<not_set_in_env>}"
  echo "   🌐 API Gateway: http://kong:8000"
fi

if is_profile_active "langfuse"; then
  echo ""
  echo "📈 Langfuse - AI Observability Platform"
  echo "───────────────────────────────────────"
  echo "🌐 Access URL: ${LANGFUSE_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "langfuse-web")"
  echo "👤 User Email: ${LANGFUSE_INIT_USER_EMAIL:-<not_set_in_env>}"
  echo "🔑 Password: ${LANGFUSE_INIT_USER_PASSWORD:-<not_set_in_env>}"
  echo ""
  echo "🔑 Project API Keys:"
  echo "   🔓 Public Key: ${LANGFUSE_INIT_PROJECT_PUBLIC_KEY:-<not_set_in_env>}"
  echo "   🔐 Secret Key: ${LANGFUSE_INIT_PROJECT_SECRET_KEY:-<not_set_in_env>}"
fi

if is_profile_active "monitoring"; then
  echo ""
  echo "📊 Monitoring Suite - Grafana & Prometheus"
  echo "──────────────────────────────────────────"
  echo "🌐 Grafana Dashboard: ${GRAFANA_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "grafana")"
  echo "👤 Admin User: admin"
  echo "🔑 Admin Password: ${GRAFANA_ADMIN_PASSWORD:-<not_set_in_env>}"
  echo ""
  echo "📈 Prometheus Metrics: ${PROMETHEUS_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "prometheus")"
  echo "👤 Auth User: ${PROMETHEUS_USERNAME:-<not_set_in_env>}"
  echo "🔑 Auth Password: ${PROMETHEUS_PASSWORD:-<not_set_in_env>}"
fi

# Vector Databases
vector_dbs_active=false
if is_profile_active "qdrant" || is_profile_active "weaviate"; then
    vector_dbs_active=true
    echo ""
    echo "=============================== VECTOR DATABASES ==============================="
fi

if is_profile_active "qdrant"; then
  echo ""
  echo "📊 Qdrant - High-Performance Vector Database"
  echo "────────────────────────────────────────────"
  echo "🌐 Dashboard: https://${QDRANT_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "qdrant")"
  echo "🔑 API Key: ${QDRANT_API_KEY:-<not_set_in_env>}"
  echo "🌐 Internal API: http://qdrant:6333"
fi

if is_profile_active "weaviate"; then
  echo ""
  echo "🧠 Weaviate - AI-Native Vector Database"
  echo "───────────────────────────────────────"
  echo "🌐 Access URL: https://${WEAVIATE_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "weaviate")"
  echo "👤 Admin User: ${WEAVIATE_USERNAME:-<not_set_in_env>}"
  echo "🔑 API Key: ${WEAVIATE_API_KEY:-<not_set_in_env>}"
fi

# Additional Services
if is_profile_active "searxng" || is_profile_active "neo4j" || is_profile_active "letta"; then
    echo ""
    echo "============================== ADDITIONAL SERVICES =============================="
fi

if is_profile_active "searxng"; then
  echo ""
  echo "🔍 SearXNG - Private Metasearch Engine"
  echo "──────────────────────────────────────"
  echo "🌐 Access URL: ${SEARXNG_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "searxng")"
  echo "👤 Auth User: ${SEARXNG_USERNAME:-<not_set_in_env>}"
  echo "🔑 Auth Password: ${SEARXNG_PASSWORD:-<not_set_in_env>}"
fi

if is_profile_active "neo4j"; then
  echo ""
  echo "🕸️ Neo4j - Graph Database"
  echo "──────────────────────────"
  echo "🌐 Web Interface: https://${NEO4J_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "neo4j")"
  echo "👤 Username: ${NEO4J_AUTH_USERNAME:-<not_set_in_env>}"
  echo "🔑 Password: ${NEO4J_AUTH_PASSWORD:-<not_set_in_env>}"
  echo "🔌 Bolt Port: 7687 (neo4j://${NEO4J_HOSTNAME:-localhost}:7687)"
fi

if is_profile_active "letta"; then
  echo ""
  echo "🤖 Letta - Agent Server & SDK"
  echo "─────────────────────────────"
  echo "🌐 Access URL: ${LETTA_HOSTNAME:-<hostname_not_set>}"
  echo "🔧 Status: $(get_service_status "letta")"
  echo "🔑 Bearer Token: ${LETTA_SERVER_PASSWORD:-<not_set_in_env>}"
fi

# Ollama Local LLMs
if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
  echo ""
  echo "=============================== LOCAL LLM INFERENCE ==============================="
  echo ""
  echo "🤖 Ollama - Local Large Language Models"
  echo "───────────────────────────────────────"
  
  # Determine which profile is active
  if is_profile_active "cpu"; then
      echo "⚙️  Hardware Profile: CPU (Compatible with all systems)"
      echo "🔧 Status: $(get_service_status "ollama-cpu")"
  elif is_profile_active "gpu-nvidia"; then
      echo "🚀 Hardware Profile: NVIDIA GPU (CUDA acceleration)"
      echo "🔧 Status: $(get_service_status "ollama-gpu")"
  elif is_profile_active "gpu-amd"; then
      echo "🔥 Hardware Profile: AMD GPU (ROCm acceleration)"
      echo "🔧 Status: $(get_service_status "ollama-gpu-amd")"
  fi
  
  echo "🌐 Internal API: http://ollama:11434"
  echo ""
  echo "🧠 Pre-installed Models:"
  echo "   📚 qwen2.5:7b-instruct-q4_K_M - General instruction following"
  echo "   🔍 nomic-embed-text - Text embedding model"
  echo ""
  echo "💡 Model Management:"
  echo "   📥 Pull model: docker exec ollama ollama pull <model_name>"
  echo "   📋 List models: docker exec ollama ollama list"
  echo "   🗑️ Remove model: docker exec ollama ollama rm <model_name>"
fi

# Shared Infrastructure Details
echo ""
echo "========================== SHARED INFRASTRUCTURE DETAILS =========================="
echo ""
echo "🗄️ Shared PostgreSQL Database"
echo "─────────────────────────────"
echo "🌐 Host: shared-postgres:5432"
echo "🔧 Status: $(get_service_status "shared-postgres")"
echo "👤 Username: postgres"
echo "🔑 Password: ${POSTGRES_PASSWORD:-<not_set_in_env>}"
echo ""
echo "📊 Database Breakdown:"
if is_profile_active "n8n"; then
    echo "   🧠 n8n_db - n8n workflows and executions"
fi
if is_profile_active "appflowy"; then
    echo "   📝 appflowy_db - AppFlowy workspace data"
fi
if is_profile_active "affine"; then
    echo "   ✨ affine_db - Affine collaborative data"
fi
if is_profile_active "langfuse"; then
    echo "   📈 langfuse_db - AI observability data"
fi
if is_profile_active "supabase"; then
    echo "   🗄️ supabase_db - Supabase backend data"
fi
echo ""
echo "💾 Shared Redis Cache"
echo "────────────────────"
echo "🌐 Host: shared-redis:6379"
echo "🔧 Status: $(get_service_status "shared-redis")"
echo "🔑 Auth: ${REDIS_AUTH:-LOCALONLYREDIS}"
echo ""
echo "🎯 Usage Breakdown:"
if is_profile_active "n8n"; then
    echo "   🧠 n8n queue management and workflow caching"
fi
if is_profile_active "appflowy"; then
    echo "   📝 AppFlowy session management"
fi
if is_profile_active "affine"; then
    echo "   ✨ Affine real-time collaboration"
fi
if is_profile_active "langfuse"; then
    echo "   📈 Langfuse analytics caching"
fi

# Development Environment
echo ""
echo "=========================== DEVELOPMENT ENVIRONMENT ==========================="
echo ""
echo "🎨 Native Development Setup"
echo "──────────────────────────"

if check_zed_installation; then
    echo "⚡ Zed Editor: ✅ Installed and ready"
    echo "🚀 Launch Command: zed"
    echo "📁 Projects Directory: ~/Projects/"
    echo "🔧 Config Location: ~/.config/zed/"
    echo ""
    echo "🛠️ Pre-configured Language Support:"
    echo "   📘 TypeScript/JavaScript - Full IntelliSense"
    echo "   🐍 Python - Black, pylint, mypy integration"
    echo "   🦀 Rust - rust-analyzer with clippy"
    echo "   📄 JSON/YAML - Schema validation"
    echo "   🐳 Dockerfile - Syntax highlighting"
    echo ""
    echo "🚀 Quick Start Commands:"
    echo "   📂 Open projects: zed ~/Projects/"
    echo "   ⚡ Current directory: zed ."
    echo "   🔧 Development setup: ~/setup-dev-session.sh"
else
    echo "⚡ Zed Editor: ❌ Not installed"
    echo "💡 Install manually: bash scripts/install_zed_native.sh"
fi

echo ""
echo "📁 Project Structure:"
echo "   🧠 ~/Projects/n8n-workflows/     - n8n automation workflows"
echo "   🤖 ~/Projects/ai-experiments/    - AI model experiments"
echo "   🐳 ~/Projects/docker-configs/    - Docker configurations"
echo "   📜 ~/Projects/scripts/           - Utility scripts"
echo "   📚 ~/Projects/knowledge-base/    - Documentation and notes"

# Network and Domain Configuration
echo ""
echo "============================= NETWORK CONFIGURATION ============================="
echo ""
echo "🌐 Domain and Routing"
echo "─────────────────────"
echo "🏠 Primary Domain: ${USER_DOMAIN_NAME:-localhost}"
echo "🔄 Reverse Proxy: Caddy (automatic HTTPS)"
echo "🔧 Status: $(get_service_status "caddy")"

if [ "$USER_DOMAIN_NAME" != "localhost" ] && [ -n "$USER_DOMAIN_NAME" ]; then
    echo "🌍 Production Mode: HTTPS with Let's Encrypt"
    echo "📧 SSL Contact: ${LETSENCRYPT_EMAIL:-<not_set>}"
else
    echo "🏠 Development Mode: HTTP localhost access"
fi

echo ""
echo "🔗 Service URL Pattern:"
if [ "$USER_DOMAIN_NAME" != "localhost" ] && [ -n "$USER_DOMAIN_NAME" ]; then
    echo "   Format: https://[service].${USER_DOMAIN_NAME}"
else
    echo "   Format: http://localhost:[port]"
fi

# Integration and Workflow Information
if [ "$knowledge_services_active" = true ]; then
    echo ""
    echo "========================== KNOWLEDGE MANAGEMENT INTEGRATION =========================="
    echo ""
    echo "🔗 Service Integration Possibilities"
    echo "───────────────────────────────────"
    echo ""
    echo "🧠 n8n ↔️ Knowledge Management:"
    echo "   📝 Automated content creation in AppFlowy/Affine"
    echo "   📊 Data synchronization between services"
    echo "   🔔 Notification workflows for document updates"
    echo "   📈 Analytics and reporting automation"
    echo ""
    echo "🗄️ Shared Database Benefits:"
    echo "   ⚡ Optimized performance with connection pooling"
    echo "   🔄 Cross-service data relationships"
    echo "   💾 Unified backup and recovery"
    echo "   📊 Consolidated monitoring and analytics"
    echo ""
    echo "💡 Workflow Ideas:"
    echo "   📧 Email → AppFlowy page creation"
    echo "   📊 Daily reports → Affine dashboard"
    echo "   🔔 Team notifications → Knowledge base updates"
    echo "   🤖 AI content generation → Document automation"
fi

# Backup and Maintenance
echo ""
echo "============================== BACKUP & MAINTENANCE =============================="
echo ""
echo "💾 Data Persistence"
echo "──────────────────"
echo "🗄️ Database: Docker volume 'shared_postgres_data'"
echo "💾 Redis: Docker volume 'valkey-data'"
echo "📁 File Storage:"
if is_profile_active "appflowy"; then
    echo "   📝 AppFlowy: volumes 'appflowy_minio_data'"
fi
if is_profile_active "affine"; then
    echo "   ✨ Affine: volumes 'affine_storage', 'affine_config'"
fi
if is_profile_active "portainer"; then
    echo "   🐳 Portainer: volume 'portainer_data'"
fi

echo ""
echo "🔧 Maintenance Commands"
echo "──────────────────────"
echo "   📊 Service status: docker ps"
echo "   📋 Service logs: docker logs <service_name>"
echo "   🔄 Restart service: docker restart <service_name>"
echo "   🛑 Stop all: docker-compose -p localai down"
echo "   🚀 Start all: python start_services.py"
echo "   📦 Update services: bash ./scripts/update.sh"
echo ""
echo "💾 Backup Commands:"
echo "   🗄️ Database backup: docker exec shared-postgres pg_dumpall -U postgres > backup.sql"
echo "   📁 Volume backup: docker run --rm -v shared_postgres_data:/data -v \$(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz -C /data ."

# Security Information
echo ""
echo "================================= SECURITY NOTES ================================="
echo ""
echo "🔐 Security Configuration"
echo "────────────────────────"
echo "🔒 Database: Internal network only (not exposed)"
echo "🔒 Redis: Internal network only (not exposed)"
echo "🌐 Web Services: HTTPS with Caddy reverse proxy"
echo "🔑 Passwords: Generated securely and stored in .env"
echo ""
echo "⚠️ Important Security Reminders:"
echo "   🔐 Change default passwords after first login"
echo "   📧 Configure SMTP for password reset functionality"
echo "   🔄 Regularly update services with: bash ./scripts/update.sh"
echo "   💾 Backup .env file securely (contains all credentials)"
echo "   🌐 Use strong domain SSL certificates in production"

# Final Status Summary
echo ""
echo "============================== DEPLOYMENT SUMMARY =============================="
echo ""

# Count active services
active_services=0
total_services=16  # Approximate total available services

for service in "n8n" "flowise" "open-webui" "appflowy" "affine" "portainer" "supabase" "qdrant" "weaviate" "neo4j" "monitoring" "langfuse" "searxng" "crawl4ai" "letta"; do
    if is_profile_active "$service"; then
        ((active_services++))
    fi
done

# Check Ollama variants
if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
    ((active_services++))
fi

echo "📊 Services Deployed: $active_services active services"
echo "🗄️ Database: Shared PostgreSQL with optimized schemas"
echo "💾 Cache: Shared Redis for optimal performance"
echo "🌐 Proxy: Caddy with automatic HTTPS"

if check_zed_installation; then
    echo "🎨 Development: Zed editor ready for native development"
else
    echo "🎨 Development: Zed editor not installed (optional)"
fi

echo ""
echo "🎉 SUCCESS! Your enhanced workspace is ready for:"
echo "   🧠 AI workflow automation with n8n"
if [ "$knowledge_services_active" = true ]; then
    echo "   📝 Knowledge management and collaboration"
fi
if is_profile_active "portainer"; then
    echo "   🐳 Container management and monitoring"
fi
echo "   ⚡ High-performance native development"
echo ""

# Final Tips
echo "💡 NEXT STEPS:"
echo "1. 🔐 Change default passwords on first login"
echo "2. 📧 Configure SMTP settings for email features (optional)"
echo "3. 🧠 Import n8n workflows: Set RUN_N8N_IMPORT=true and restart"
if check_zed_installation; then
    echo "4. 🎨 Start developing: Run 'zed ~/Projects/' to open your workspace"
else
    echo "4. 🎨 Install Zed editor: bash scripts/install_zed_native.sh"
fi
echo "5. 📚 Explore the knowledge management tools for documentation"
echo "6. 🤖 Set up your first AI automation workflows"
echo ""

echo "🚀 Happy automating and developing with your enhanced workspace!"
echo "="*100

exit 0
