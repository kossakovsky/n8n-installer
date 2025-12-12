#!/bin/bash
# Generates docker-compose.n8n-workers.yml with N worker-runner pairs
# Usage: N8N_WORKER_COUNT=3 bash scripts/generate_n8n_workers.sh
#
# This script is idempotent - file is overwritten on each run

set -euo pipefail

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Load N8N_WORKER_COUNT from .env if not set
if [[ -z "${N8N_WORKER_COUNT:-}" ]] && [[ -f "$ENV_FILE" ]]; then
    N8N_WORKER_COUNT=$(read_env_var "N8N_WORKER_COUNT" || echo "1")
fi
N8N_WORKER_COUNT=${N8N_WORKER_COUNT:-1}

# Validate N8N_WORKER_COUNT
if ! [[ "$N8N_WORKER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    log_error "N8N_WORKER_COUNT must be a positive integer, got: '$N8N_WORKER_COUNT'"
    exit 1
fi

OUTPUT_FILE="$PROJECT_ROOT/docker-compose.n8n-workers.yml"

log_info "Generating n8n worker-runner pairs configuration..."
log_info "N8N_WORKER_COUNT=$N8N_WORKER_COUNT"

# Overwrite file (idempotent)
cat > "$OUTPUT_FILE" << 'EOF'
# Auto-generated file for n8n worker-runner pairs
# Regenerate with: bash scripts/generate_n8n_workers.sh
# DO NOT EDIT MANUALLY - this file is overwritten on each run

services:
EOF

for i in $(seq 1 "$N8N_WORKER_COUNT"); do
cat >> "$OUTPUT_FILE" << EOF
  n8n-worker-$i:
    extends:
      file: docker-compose.yml
      service: n8n-worker-template
    container_name: n8n-worker-$i
    profiles: ["n8n"]
    restart: unless-stopped
    depends_on:
      n8n:
        condition: service_healthy
      redis:
        condition: service_healthy
      postgres:
        condition: service_healthy

  n8n-runner-$i:
    extends:
      file: docker-compose.yml
      service: n8n-runner-template
    container_name: n8n-runner-$i
    profiles: ["n8n"]
    restart: unless-stopped
    network_mode: "service:n8n-worker-$i"
    depends_on:
      n8n-worker-$i:
        condition: service_healthy

EOF
done

log_info "Generated $OUTPUT_FILE with $N8N_WORKER_COUNT worker-runner pair(s)"
