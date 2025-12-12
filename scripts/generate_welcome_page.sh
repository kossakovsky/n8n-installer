#!/bin/bash

# Generate data.json for the welcome page with active services and credentials

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Get the directory where the script resides
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
ENV_FILE="$PROJECT_ROOT/.env"
OUTPUT_FILE="$PROJECT_ROOT/welcome/data.json"

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    log_error "The .env file ('$ENV_FILE') was not found."
    exit 1
fi

# Ensure welcome directory exists
mkdir -p "$PROJECT_ROOT/welcome"

# Remove existing data.json if it exists (always regenerate)
if [ -f "$OUTPUT_FILE" ]; then
    rm -f "$OUTPUT_FILE"
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

# Function to escape JSON strings
json_escape() {
    local str="$1"
    # Escape backslashes, double quotes, and control characters
    printf '%s' "$str" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr -d '\n\r'
}

# Start building JSON
GENERATED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build services array - each entry is a formatted JSON block
declare -a SERVICES_ARRAY

# n8n
if is_profile_active "n8n"; then
    N8N_WORKER_COUNT_VAL="${N8N_WORKER_COUNT:-1}"
    SERVICES_ARRAY+=("    \"n8n\": {
      \"hostname\": \"$(json_escape "$N8N_HOSTNAME")\",
      \"credentials\": {
        \"note\": \"Use the email you provided during installation\"
      },
      \"extra\": {
        \"workers\": \"$N8N_WORKER_COUNT_VAL\"
      }
    }")
fi

# Flowise
if is_profile_active "flowise"; then
    SERVICES_ARRAY+=("    \"flowise\": {
      \"hostname\": \"$(json_escape "$FLOWISE_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$FLOWISE_USERNAME")\",
        \"password\": \"$(json_escape "$FLOWISE_PASSWORD")\"
      }
    }")
fi

# Open WebUI
if is_profile_active "open-webui"; then
    SERVICES_ARRAY+=("    \"open-webui\": {
      \"hostname\": \"$(json_escape "$WEBUI_HOSTNAME")\",
      \"credentials\": {
        \"note\": \"Create account on first login\"
      }
    }")
fi

# Grafana (monitoring)
if is_profile_active "monitoring"; then
    SERVICES_ARRAY+=("    \"grafana\": {
      \"hostname\": \"$(json_escape "$GRAFANA_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"admin\",
        \"password\": \"$(json_escape "$GRAFANA_ADMIN_PASSWORD")\"
      }
    }")
    SERVICES_ARRAY+=("    \"prometheus\": {
      \"hostname\": \"$(json_escape "$PROMETHEUS_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$PROMETHEUS_USERNAME")\",
        \"password\": \"$(json_escape "$PROMETHEUS_PASSWORD")\"
      }
    }")
fi

# Portainer
if is_profile_active "portainer"; then
    SERVICES_ARRAY+=("    \"portainer\": {
      \"hostname\": \"$(json_escape "$PORTAINER_HOSTNAME")\",
      \"credentials\": {
        \"note\": \"Create admin account on first login\"
      }
    }")
fi

# Postgresus
if is_profile_active "postgresus"; then
    SERVICES_ARRAY+=("    \"postgresus\": {
      \"hostname\": \"$(json_escape "$POSTGRESUS_HOSTNAME")\",
      \"credentials\": {
        \"note\": \"Uses PostgreSQL credentials from .env\"
      },
      \"extra\": {
        \"pg_host\": \"postgres\",
        \"pg_port\": \"${POSTGRES_PORT:-5432}\",
        \"pg_user\": \"$(json_escape "${POSTGRES_USER:-postgres}")\",
        \"pg_password\": \"$(json_escape "$POSTGRES_PASSWORD")\",
        \"pg_db\": \"$(json_escape "${POSTGRES_DB:-postgres}")\"
      }
    }")
fi

# Langfuse
if is_profile_active "langfuse"; then
    SERVICES_ARRAY+=("    \"langfuse\": {
      \"hostname\": \"$(json_escape "$LANGFUSE_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$LANGFUSE_INIT_USER_EMAIL")\",
        \"password\": \"$(json_escape "$LANGFUSE_INIT_USER_PASSWORD")\"
      }
    }")
fi

# Supabase
if is_profile_active "supabase"; then
    SERVICES_ARRAY+=("    \"supabase\": {
      \"hostname\": \"$(json_escape "$SUPABASE_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$DASHBOARD_USERNAME")\",
        \"password\": \"$(json_escape "$DASHBOARD_PASSWORD")\"
      },
      \"extra\": {
        \"internal_api\": \"http://kong:8000\",
        \"service_role_key\": \"$(json_escape "$SERVICE_ROLE_KEY")\"
      }
    }")
fi

# Dify
if is_profile_active "dify"; then
    SERVICES_ARRAY+=("    \"dify\": {
      \"hostname\": \"$(json_escape "$DIFY_HOSTNAME")\",
      \"credentials\": {
        \"note\": \"Create account on first login\"
      },
      \"extra\": {
        \"api_endpoint\": \"https://$(json_escape "$DIFY_HOSTNAME")/v1\",
        \"internal_api\": \"http://dify-api:5001\"
      }
    }")
fi

# Qdrant
if is_profile_active "qdrant"; then
    SERVICES_ARRAY+=("    \"qdrant\": {
      \"hostname\": \"$(json_escape "$QDRANT_HOSTNAME")\",
      \"credentials\": {
        \"api_key\": \"$(json_escape "$QDRANT_API_KEY")\"
      },
      \"extra\": {
        \"dashboard\": \"https://$(json_escape "$QDRANT_HOSTNAME")/dashboard\",
        \"internal_api\": \"http://qdrant:6333\"
      }
    }")
fi

# Weaviate
if is_profile_active "weaviate"; then
    SERVICES_ARRAY+=("    \"weaviate\": {
      \"hostname\": \"$(json_escape "$WEAVIATE_HOSTNAME")\",
      \"credentials\": {
        \"api_key\": \"$(json_escape "$WEAVIATE_API_KEY")\",
        \"username\": \"$(json_escape "$WEAVIATE_USERNAME")\"
      }
    }")
fi

# Neo4j
if is_profile_active "neo4j"; then
    SERVICES_ARRAY+=("    \"neo4j\": {
      \"hostname\": \"$(json_escape "$NEO4J_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$NEO4J_AUTH_USERNAME")\",
        \"password\": \"$(json_escape "$NEO4J_AUTH_PASSWORD")\"
      },
      \"extra\": {
        \"bolt_port\": \"7687\"
      }
    }")
fi

# SearXNG
if is_profile_active "searxng"; then
    SERVICES_ARRAY+=("    \"searxng\": {
      \"hostname\": \"$(json_escape "$SEARXNG_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$SEARXNG_USERNAME")\",
        \"password\": \"$(json_escape "$SEARXNG_PASSWORD")\"
      }
    }")
fi

# RAGApp
if is_profile_active "ragapp"; then
    SERVICES_ARRAY+=("    \"ragapp\": {
      \"hostname\": \"$(json_escape "$RAGAPP_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$RAGAPP_USERNAME")\",
        \"password\": \"$(json_escape "$RAGAPP_PASSWORD")\"
      },
      \"extra\": {
        \"admin\": \"https://$(json_escape "$RAGAPP_HOSTNAME")/admin\",
        \"docs\": \"https://$(json_escape "$RAGAPP_HOSTNAME")/docs\",
        \"internal_api\": \"http://ragapp:8000\"
      }
    }")
fi

# RAGFlow
if is_profile_active "ragflow"; then
    SERVICES_ARRAY+=("    \"ragflow\": {
      \"hostname\": \"$(json_escape "$RAGFLOW_HOSTNAME")\",
      \"credentials\": {
        \"note\": \"Create account on first login\"
      },
      \"extra\": {
        \"internal_api\": \"http://ragflow:80\"
      }
    }")
fi

# LightRAG
if is_profile_active "lightrag"; then
    SERVICES_ARRAY+=("    \"lightrag\": {
      \"hostname\": \"$(json_escape "$LIGHTRAG_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$LIGHTRAG_USERNAME")\",
        \"password\": \"$(json_escape "$LIGHTRAG_PASSWORD")\",
        \"api_key\": \"$(json_escape "$LIGHTRAG_API_KEY")\"
      },
      \"extra\": {
        \"docs\": \"https://$(json_escape "$LIGHTRAG_HOSTNAME")/docs\",
        \"internal_api\": \"http://lightrag:9621\"
      }
    }")
fi

# Letta
if is_profile_active "letta"; then
    SERVICES_ARRAY+=("    \"letta\": {
      \"hostname\": \"$(json_escape "$LETTA_HOSTNAME")\",
      \"credentials\": {
        \"api_key\": \"$(json_escape "$LETTA_SERVER_PASSWORD")\"
      }
    }")
fi

# ComfyUI
if is_profile_active "comfyui"; then
    SERVICES_ARRAY+=("    \"comfyui\": {
      \"hostname\": \"$(json_escape "$COMFYUI_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$COMFYUI_USERNAME")\",
        \"password\": \"$(json_escape "$COMFYUI_PASSWORD")\"
      }
    }")
fi

# LibreTranslate
if is_profile_active "libretranslate"; then
    SERVICES_ARRAY+=("    \"libretranslate\": {
      \"hostname\": \"$(json_escape "$LT_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$LT_USERNAME")\",
        \"password\": \"$(json_escape "$LT_PASSWORD")\"
      },
      \"extra\": {
        \"internal_api\": \"http://libretranslate:5000\"
      }
    }")
fi

# Docling
if is_profile_active "docling"; then
    SERVICES_ARRAY+=("    \"docling\": {
      \"hostname\": \"$(json_escape "$DOCLING_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$DOCLING_USERNAME")\",
        \"password\": \"$(json_escape "$DOCLING_PASSWORD")\"
      },
      \"extra\": {
        \"ui\": \"https://$(json_escape "$DOCLING_HOSTNAME")/ui\",
        \"docs\": \"https://$(json_escape "$DOCLING_HOSTNAME")/docs\",
        \"internal_api\": \"http://docling:5001\"
      }
    }")
fi

# PaddleOCR
if is_profile_active "paddleocr"; then
    SERVICES_ARRAY+=("    \"paddleocr\": {
      \"hostname\": \"$(json_escape "$PADDLEOCR_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$PADDLEOCR_USERNAME")\",
        \"password\": \"$(json_escape "$PADDLEOCR_PASSWORD")\"
      },
      \"extra\": {
        \"internal_api\": \"http://paddleocr:8080\"
      }
    }")
fi

# Postiz
if is_profile_active "postiz"; then
    SERVICES_ARRAY+=("    \"postiz\": {
      \"hostname\": \"$(json_escape "$POSTIZ_HOSTNAME")\",
      \"credentials\": {
        \"note\": \"Create account on first login\"
      },
      \"extra\": {
        \"internal_api\": \"http://postiz:5000\"
      }
    }")
fi

# WAHA
if is_profile_active "waha"; then
    SERVICES_ARRAY+=("    \"waha\": {
      \"hostname\": \"$(json_escape "$WAHA_HOSTNAME")\",
      \"credentials\": {
        \"username\": \"$(json_escape "$WAHA_DASHBOARD_USERNAME")\",
        \"password\": \"$(json_escape "$WAHA_DASHBOARD_PASSWORD")\",
        \"api_key\": \"$(json_escape "$WAHA_API_KEY_PLAIN")\"
      },
      \"extra\": {
        \"dashboard\": \"https://$(json_escape "$WAHA_HOSTNAME")/dashboard\",
        \"swagger_user\": \"$(json_escape "$WHATSAPP_SWAGGER_USERNAME")\",
        \"swagger_pass\": \"$(json_escape "$WHATSAPP_SWAGGER_PASSWORD")\",
        \"internal_api\": \"http://waha:3000\"
      }
    }")
fi

# Crawl4AI (internal only)
if is_profile_active "crawl4ai"; then
    SERVICES_ARRAY+=("    \"crawl4ai\": {
      \"hostname\": null,
      \"credentials\": {
        \"note\": \"Internal service only\"
      },
      \"extra\": {
        \"internal_api\": \"http://crawl4ai:11235\"
      }
    }")
fi

# Gotenberg (internal only)
if is_profile_active "gotenberg"; then
    SERVICES_ARRAY+=("    \"gotenberg\": {
      \"hostname\": null,
      \"credentials\": {
        \"note\": \"Internal service only\"
      },
      \"extra\": {
        \"internal_api\": \"http://gotenberg:3000\",
        \"docs\": \"https://gotenberg.dev/docs\"
      }
    }")
fi

# Ollama (internal only)
if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
    SERVICES_ARRAY+=("    \"ollama\": {
      \"hostname\": null,
      \"credentials\": {
        \"note\": \"Internal service only\"
      },
      \"extra\": {
        \"internal_api\": \"http://ollama:11434\"
      }
    }")
fi

# Redis/Valkey (internal only, shown if n8n or langfuse active)
if is_profile_active "n8n" || is_profile_active "langfuse"; then
    SERVICES_ARRAY+=("    \"redis\": {
      \"hostname\": null,
      \"credentials\": {
        \"password\": \"$(json_escape "$REDIS_AUTH")\"
      },
      \"extra\": {
        \"internal_host\": \"${REDIS_HOST:-redis}\",
        \"internal_port\": \"${REDIS_PORT:-6379}\"
      }
    }")
fi

# PostgreSQL (internal only, shown if n8n or langfuse active)
if is_profile_active "n8n" || is_profile_active "langfuse"; then
    SERVICES_ARRAY+=("    \"postgres\": {
      \"hostname\": null,
      \"credentials\": {
        \"username\": \"$(json_escape "${POSTGRES_USER:-postgres}")\",
        \"password\": \"$(json_escape "$POSTGRES_PASSWORD")\"
      },
      \"extra\": {
        \"internal_host\": \"postgres\",
        \"internal_port\": \"${POSTGRES_PORT:-5432}\",
        \"database\": \"$(json_escape "${POSTGRES_DB:-postgres}")\"
      }
    }")
fi

# Python Runner (internal only)
if is_profile_active "python-runner"; then
    SERVICES_ARRAY+=("    \"python-runner\": {
      \"hostname\": null,
      \"credentials\": {
        \"note\": \"Internal service only\"
      },
      \"extra\": {
        \"logs_command\": \"docker compose -p localai logs -f python-runner\"
      }
    }")
fi

# Cloudflare Tunnel
if is_profile_active "cloudflare-tunnel"; then
    SERVICES_ARRAY+=("    \"cloudflare-tunnel\": {
      \"hostname\": null,
      \"credentials\": {
        \"note\": \"Zero-trust access via Cloudflare network\"
      },
      \"extra\": {
        \"recommendation\": \"Close ports 80, 443, 7687 in your VPS firewall after confirming tunnel connectivity\"
      }
    }")
fi

# Join array with commas and newlines
SERVICES_JSON=""
for i in "${!SERVICES_ARRAY[@]}"; do
    if [ $i -gt 0 ]; then
        SERVICES_JSON+=",
"
    fi
    SERVICES_JSON+="${SERVICES_ARRAY[$i]}"
done

# Write final JSON with proper formatting
cat > "$OUTPUT_FILE" << EOF
{
  "domain": "$(json_escape "$USER_DOMAIN_NAME")",
  "generated_at": "$GENERATED_AT",
  "services": {
$SERVICES_JSON
  }
}
EOF

log_success "Welcome page data generated at: $OUTPUT_FILE"
log_info "Access it at: https://${WELCOME_HOSTNAME:-welcome.${USER_DOMAIN_NAME}}"
