#!/bin/bash

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
# Use set -a to export all variables read from the file
set -a
source "$ENV_FILE"
set +a

# Function to check if a profile is active
is_profile_active() {
    local profile_to_check="$1"
    # COMPOSE_PROFILES is sourced from .env and will be available here
    if [ -z "$COMPOSE_PROFILES" ]; then
        return 1 # Not active if COMPOSE_PROFILES is empty or not set
    fi
    # Check if the profile_to_check is in the comma-separated list
    # Adding commas at the beginning and end of both strings handles edge cases
    # (e.g., single profile, profile being a substring of another)
    if [[ ",$COMPOSE_PROFILES," == *",$profile_to_check,"* ]]; then
        return 0 # Active
    else
        return 1 # Not active
    fi
}

# --- Service Access Credentials ---

# Display credentials, checking if variables exist
echo
log_info "Service Access Credentials. Save this information securely!"
# Display credentials, checking if variables exist

if is_profile_active "n8n"; then
  echo
  echo "================================= n8n ================================="
  echo
  echo "Host: ${N8N_HOSTNAME:-<hostname_not_set>}"
  N8N_WORKER_COUNT_VAL="${N8N_WORKER_COUNT:-1}"
  echo "Workers: $N8N_WORKER_COUNT_VAL (each with dedicated task runner sidecar)"
fi

if is_profile_active "open-webui"; then
  echo
  echo "================================= WebUI ==============================="
  echo
  echo "Host: ${WEBUI_HOSTNAME:-<hostname_not_set>}"
fi

if is_profile_active "flowise"; then
  echo
  echo "================================= Flowise ============================="
  echo
  echo "Host: ${FLOWISE_HOSTNAME:-<hostname_not_set>}"
  echo "User: ${FLOWISE_USERNAME:-<not_set_in_env>}"
  echo "Password: ${FLOWISE_PASSWORD:-<not_set_in_env>}"
fi

if is_profile_active "dify"; then
  echo
  echo "================================= Dify ================================="
  echo
  echo "Host: ${DIFY_HOSTNAME:-<hostname_not_set>}"
  echo "Description: AI Application Development Platform with LLMOps"
  echo
  echo "API Access:"
  echo "  - Web Interface: https://${DIFY_HOSTNAME:-<hostname_not_set>}"
  echo "  - API Endpoint: https://${DIFY_HOSTNAME:-<hostname_not_set>}/v1"
  echo "  - Internal API: http://dify-api:5001"
fi

if is_profile_active "supabase"; then
  echo
  echo "================================= Supabase ============================"
  echo
  echo "External Host (via Caddy): ${SUPABASE_HOSTNAME:-<hostname_not_set>}"
  echo "Studio User: ${DASHBOARD_USERNAME:-<not_set_in_env>}"
  echo "Studio Password: ${DASHBOARD_PASSWORD:-<not_set_in_env>}"
  echo
  echo "Internal API Gateway: http://kong:8000"
  echo "Service Role Secret: ${SERVICE_ROLE_KEY:-<not_set_in_env>}"
fi

if is_profile_active "langfuse"; then
  echo
  echo "================================= Langfuse ============================"
  echo
  echo "Host: ${LANGFUSE_HOSTNAME:-<hostname_not_set>}"
  echo "User: ${LANGFUSE_INIT_USER_EMAIL:-<not_set_in_env>}"
  echo "Password: ${LANGFUSE_INIT_USER_PASSWORD:-<not_set_in_env>}"
fi

if is_profile_active "monitoring"; then
  echo
  echo "================================= Grafana ============================="
  echo
  echo "Host: ${GRAFANA_HOSTNAME:-<hostname_not_set>}"
  echo "User: admin"
  echo "Password: ${GRAFANA_ADMIN_PASSWORD:-<not_set_in_env>}"
  echo
  echo "================================= Prometheus =========================="
  echo
  echo "Host: ${PROMETHEUS_HOSTNAME:-<hostname_not_set>}"
  echo "User: ${PROMETHEUS_USERNAME:-<not_set_in_env>}"
  echo "Password: ${PROMETHEUS_PASSWORD:-<not_set_in_env>}"
fi

if is_profile_active "searxng"; then
  echo
  echo "================================= Searxng ============================="
  echo
  echo "Host: ${SEARXNG_HOSTNAME:-<hostname_not_set>}"
  echo "User: ${SEARXNG_USERNAME:-<not_set_in_env>}"
  echo "Password: ${SEARXNG_PASSWORD:-<not_set_in_env>}"
fi

if is_profile_active "portainer"; then
  echo
  echo "================================= Portainer ==========================="
  echo
  echo "Host: ${PORTAINER_HOSTNAME:-<hostname_not_set>}"
  echo "(Note: On first login, Portainer will prompt to set up an admin user.)"
fi

if is_profile_active "postiz"; then
  echo
  echo "================================= Postiz =============================="
  echo
  echo "Host: ${POSTIZ_HOSTNAME:-<hostname_not_set>}"
  echo "Internal Access (e.g., from n8n): http://postiz:5000"
fi

if is_profile_active "postgresus"; then
  echo
  echo "================================= Postgresus =========================="
  echo
  echo "Host: ${POSTGRESUS_HOSTNAME:-<hostname_not_set>}"
  echo "UI (external via Caddy): https://${POSTGRESUS_HOSTNAME:-<hostname_not_set>}"
  echo "UI (internal): http://postgresus:4005"
  echo "------ Backup Target (internal PostgreSQL) ------"
  echo "PG version: ${POSTGRES_VERSION:-17}"
  echo "Host: postgres"
  echo "Port: ${POSTGRES_PORT:-5432}"
  echo "Username: ${POSTGRES_USER:-postgres}"
  echo "Password: ${POSTGRES_PASSWORD:-<not_set_in_env>}"
  echo "DB name: ${POSTGRES_DB:-postgres}"
  echo "Use HTTPS: false"
fi

if is_profile_active "ragapp"; then
  echo
  echo "================================= RAGApp =============================="
  echo
  echo "Host: ${RAGAPP_HOSTNAME:-<hostname_not_set>}"
  echo "Internal Access (e.g., from n8n): http://ragapp:8000"
  echo "User: ${RAGAPP_USERNAME:-<not_set_in_env>}"
  echo "Password: ${RAGAPP_PASSWORD:-<not_set_in_env>}"
  echo "Admin: https://${RAGAPP_HOSTNAME:-<hostname_not_set>}/admin"
  echo "API Docs: https://${RAGAPP_HOSTNAME:-<hostname_not_set>}/docs"
fi

if is_profile_active "ragflow"; then
  echo
  echo "================================= RAGFlow ============================="
  echo
  echo "Host: ${RAGFLOW_HOSTNAME:-<hostname_not_set>}"
  echo "API (external via Caddy): https://${RAGFLOW_HOSTNAME:-<hostname_not_set>}"
  echo "API (internal): http://ragflow:80"
  echo "Note: Uses built-in authentication (login/registration available in web UI)"
fi

if is_profile_active "comfyui"; then
  echo
  echo "================================= ComfyUI ============================="
  echo
  echo "Host: ${COMFYUI_HOSTNAME:-<hostname_not_set>}"
  echo "User: ${COMFYUI_USERNAME:-<not_set_in_env>}"
  echo "Password: ${COMFYUI_PASSWORD:-<not_set_in_env>}"
fi

if is_profile_active "libretranslate"; then
  echo
  echo "================================= LibreTranslate ==========================="
  echo
  echo "Host: ${LT_HOSTNAME:-<hostname_not_set>}"
  echo "User: ${LT_USERNAME:-<not_set_in_env>}"
  echo "Password: ${LT_PASSWORD:-<not_set_in_env>}"
  echo "API (external via Caddy): https://${LT_HOSTNAME:-<hostname_not_set>}"
  echo "API (internal): http://libretranslate:5000"
  echo "Docs: https://github.com/LibreTranslate/LibreTranslate"
fi

if is_profile_active "qdrant"; then
  echo
  echo "================================= Qdrant =============================="
  echo
  echo "Dashboard: https://${QDRANT_HOSTNAME:-<hostname_not_set>}/dashboard"
  echo "Host: https://${QDRANT_HOSTNAME:-<hostname_not_set>}"
  echo "API Key: ${QDRANT_API_KEY:-<not_set_in_env>}"
  echo "Internal REST API Access (e.g., from backend): http://qdrant:6333"
fi

if is_profile_active "crawl4ai"; then
  echo
  echo "================================= Crawl4AI ============================"
  echo
  echo "Internal Access (e.g., from n8n): http://crawl4ai:11235"
  echo "(Note: Not exposed externally via Caddy by default)"
fi

if is_profile_active "docling"; then
  echo
  echo "================================= Docling ============================="
  echo
  echo "Web UI: https://${DOCLING_HOSTNAME:-<hostname_not_set>}/ui"
  echo "API Docs: https://${DOCLING_HOSTNAME:-<hostname_not_set>}/docs"
  echo
  echo "Credentials (Caddy Basic Auth):"
  echo "User: ${DOCLING_USERNAME:-<not_set_in_env>}"
  echo "Password: ${DOCLING_PASSWORD:-<not_set_in_env>}"
  echo
  echo "API Endpoints:"
  echo "External (via Caddy): https://${DOCLING_HOSTNAME:-<hostname_not_set>}"
  echo "Internal (from n8n):  http://docling:5001"
  echo
  echo "VLM Pipeline (Vision Language Model):"
  echo "  1. Load VLM model in Ollama via Open WebUI -> Settings -> Models"
  echo "     Example: granite3.2-vision:2b"
  echo
  echo "  2. API request with VLM pipeline:"
  echo '     curl -X POST "https://'"${DOCLING_HOSTNAME:-<hostname_not_set>}"'/v1/convert/source" \'
  echo '       -H "Content-Type: application/json" \'
  echo '       -u "'"${DOCLING_USERNAME:-<not_set_in_env>}"':'"${DOCLING_PASSWORD:-<not_set_in_env>}"'" \'
  echo "       -d '{"
  echo '         "source": "https://arxiv.org/pdf/2501.17887",'
  echo '         "options": {'
  echo '           "pipeline": "vlm",'
  echo '           "vlm_pipeline_model_api": {'
  echo '             "url": "http://ollama:11434/v1/chat/completions",'
  echo '             "params": {"model": "granite3.2-vision:2b"},'
  echo '             "prompt": "Convert this page to docling.",'
  echo '             "timeout": 300'
  echo "           }"
  echo "         }"
  echo "       }'"
fi

if is_profile_active "gotenberg"; then
  echo
  echo "================================= Gotenberg ============================"
  echo
  echo "Internal Access (e.g., from n8n): http://gotenberg:3000"
  echo "API Documentation: https://gotenberg.dev/docs"
  echo
  echo "Common API Endpoints:"
  echo "  HTML to PDF: POST /forms/chromium/convert/html"
  echo "  URL to PDF: POST /forms/chromium/convert/url"
  echo "  Markdown to PDF: POST /forms/chromium/convert/markdown"
  echo "  Office to PDF: POST /forms/libreoffice/convert"
fi

if is_profile_active "waha"; then
  echo
  echo "============================== WAHA (WhatsApp HTTP API) =============================="
  echo
  echo "Dashboard: https://${WAHA_HOSTNAME:-<hostname_not_set>}/dashboard"
  echo "Swagger:   https://${WAHA_HOSTNAME:-<hostname_not_set>}"
  echo "Internal:  http://waha:3000"
  echo
  echo "Dashboard User: ${WAHA_DASHBOARD_USERNAME:-<not_set_in_env>}"
  echo "Dashboard Pass: ${WAHA_DASHBOARD_PASSWORD:-<not_set_in_env>}"
  echo "Swagger User:   ${WHATSAPP_SWAGGER_USERNAME:-<not_set_in_env>}"
  echo "Swagger Pass:   ${WHATSAPP_SWAGGER_PASSWORD:-<not_set_in_env>}"
  echo "API key (plain): ${WAHA_API_KEY_PLAIN:-<not_set_in_env>}"
fi

if is_profile_active "paddleocr"; then
  echo
  echo "================================= PaddleOCR ==========================="
  echo
  echo "Host: ${PADDLEOCR_HOSTNAME:-<hostname_not_set>}"
  echo "User: ${PADDLEOCR_USERNAME:-<not_set_in_env>}"
  echo "Password: ${PADDLEOCR_PASSWORD:-<not_set_in_env>}"
  echo "API (external via Caddy): https://${PADDLEOCR_HOSTNAME:-<hostname_not_set>}"
  echo "API (internal): http://paddleocr:8080"
  echo "Docs: https://paddleocr.a2.fyi/docs"
  echo "Notes: PaddleX Basic Serving (CPU), pipeline=OCR"
fi

if is_profile_active "python-runner"; then
  echo
  echo "================================= Python Runner ========================"
  echo
  echo "Internal Container DNS: python-runner"
  echo "Mounted Code Directory: ./python-runner (host) -> /app (container)"
  echo "Entry File: /app/main.py"
  echo "(Note: Internal-only service with no exposed ports; view output via logs)"
  echo "Logs: docker compose -p localai logs -f python-runner"
fi

if is_profile_active "n8n" || is_profile_active "langfuse"; then
  echo
  echo "================================= Redis (Valkey) ======================"
  echo
  echo "Internal Host: ${REDIS_HOST:-redis}"
  echo "Internal Port: ${REDIS_PORT:-6379}"
  echo "Password: ${REDIS_AUTH:-}"
  echo "(Note: Primarily for internal service communication, not exposed externally by default)"
fi

if is_profile_active "letta"; then
  echo
  echo "================================= Letta ================================"
  echo
  echo "Host: ${LETTA_HOSTNAME:-<hostname_not_set>}"
  echo "Authorization: Bearer ${LETTA_SERVER_PASSWORD}"
fi

if is_profile_active "lightrag"; then
  echo
  echo "================================= LightRAG ============================="
  echo
  echo "Host: ${LIGHTRAG_HOSTNAME:-<hostname_not_set>}"
  echo "Web UI: https://${LIGHTRAG_HOSTNAME:-<hostname_not_set>}"
  echo "Internal Access (e.g., from n8n): http://lightrag:9621"
  echo ""
  echo "Authentication (Web UI):"
  echo "  User: ${LIGHTRAG_USERNAME:-<not_set_in_env>}"
  echo "  Password: ${LIGHTRAG_PASSWORD:-<not_set_in_env>}"
  echo ""
  echo "API Access:"
  echo "  API Key: ${LIGHTRAG_API_KEY:-<not_set_in_env>}"
  echo "  API Docs: https://${LIGHTRAG_HOSTNAME:-<hostname_not_set>}/docs"
  echo "  Ollama-compatible: https://${LIGHTRAG_HOSTNAME:-<hostname_not_set>}/v1/chat/completions"
  echo ""
  echo "Configuration:"
  echo "  LLM: Ollama (qwen2.5:32b) at http://ollama:11434"
  echo "  Embeddings: Ollama (bge-m3:latest) at http://ollama:11434"
  echo "  Storage: Flexible (JSON/PostgreSQL/Neo4j based on installed services)"
  echo ""
  echo "Note: Requires Ollama to be installed and running for LLM and embeddings."
  echo "      Upload documents via /app/data/inputs volume or Web UI."
fi

if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
  echo
  echo "================================= Ollama =============================="
  echo
  echo "Internal Access (e.g., from n8n, Open WebUI): http://ollama:11434"
  echo "(Note: Ollama runs with the selected profile: cpu, gpu-nvidia, or gpu-amd)"
fi

if is_profile_active "weaviate"; then
  echo
  echo "================================= Weaviate ============================"
  echo
  echo "Host: ${WEAVIATE_HOSTNAME:-<hostname_not_set>}"
  echo "Admin User (for Weaviate RBAC): ${WEAVIATE_USERNAME:-<not_set_in_env>}"
  echo "Weaviate API Key: ${WEAVIATE_API_KEY:-<not_set_in_env>}"
fi

if is_profile_active "neo4j"; then
  echo
  echo "================================= Neo4j =================================="
  echo
  echo "Web UI Host: https://${NEO4J_HOSTNAME:-<hostname_not_set>}"
  echo "Bolt Port (for drivers): 7687 (e.g., neo4j://\\${NEO4J_HOSTNAME:-<hostname_not_set>}:7687)"
  echo "User (for Web UI & API): ${NEO4J_AUTH_USERNAME:-<not_set_in_env>}"
  echo "Password (for Web UI & API): ${NEO4J_AUTH_PASSWORD:-<not_set_in_env>}"
  echo
  echo "HTTP API Access (e.g., for N8N):"
  echo "  Authentication: Basic (use User/Password above)"
  echo "  Cypher API Endpoint (POST): https://\\${NEO4J_HOSTNAME:-<hostname_not_set>}/db/neo4j/tx/commit"
  echo "  Authorization Header Value (for 'Authorization: Basic <value>'): \$(echo -n \"${NEO4J_AUTH_USERNAME:-neo4j}:${NEO4J_AUTH_PASSWORD}\" | base64)"
fi

# Standalone PostgreSQL (used by n8n, Langfuse, etc.)
# Check if n8n or langfuse is active, as they use this PostgreSQL instance.
# The Supabase section already details its own internal Postgres.
if is_profile_active "n8n" || is_profile_active "langfuse"; then
  # Check if Supabase is NOT active, to avoid confusion with Supabase's Postgres if both are present
  # However, the main POSTGRES_PASSWORD is used by this standalone instance.
  # Supabase has its own environment variables for its internal Postgres if configured differently,
  # but the current docker-compose.yml uses the main POSTGRES_PASSWORD for langfuse's postgres dependency too.
  # For clarity, we will label this distinctly.
  echo
  echo "==================== Standalone PostgreSQL (for n8n, Langfuse, etc.) ====================="
  echo
  echo "Host: postgres"
  echo "Port: ${POSTGRES_PORT:-5432}"
  echo "Database: ${POSTGRES_DB:-postgres}" # This is typically 'postgres' or 'n8n' for n8n, and 'langfuse' for langfuse, but refers to the service.
  echo "User: ${POSTGRES_USER:-postgres}"
  echo "Password: ${POSTGRES_PASSWORD:-<not_set_in_env>}"
  echo "(Note: This is the PostgreSQL instance used by services like n8n and Langfuse.)"
  echo "(It is separate from Supabase's internal PostgreSQL if Supabase is also enabled.)"
fi

echo
echo "======================================================================="
echo

# --- Update Script Info (Placeholder) ---
log_info "To update the services, run the 'update.sh' script: bash ./scripts/update.sh"

# ============================================
# Cloudflare Tunnel Security Notice
# ============================================
if is_profile_active "cloudflare-tunnel"; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔒 CLOUDFLARE TUNNEL SECURITY"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "✅ Cloudflare Tunnel is configured and running!"
  echo ""
  echo "Your services are accessible through Cloudflare's secure network."
  echo "All traffic is encrypted and routed through the tunnel."
  echo ""
  echo "🛡️  RECOMMENDED SECURITY ENHANCEMENT:"
  echo "   For maximum security, close the following ports in your VPS firewall:"
  echo "   • Port 80 (HTTP)"
  echo "   • Port 443 (HTTPS)" 
  echo "   • Port 7687 (Neo4j Bolt)"
  echo ""
  echo "   ⚠️  Only close ports AFTER confirming tunnel connectivity!"
  echo ""
fi

echo
echo "======================================================================"
echo
echo "Next Steps:"
echo "1. Review the credentials above and store them safely."
echo "2. Access the services via their respective URLs (check \`docker compose ps\` if needed)."
echo "3. Configure services as needed (e.g., first-run setup for n8n)."
echo
echo "======================================================================"
echo
log_info "Thank you for using this repository!"
echo
