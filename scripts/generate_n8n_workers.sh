#!/bin/bash
# Генерирует docker-compose.n8n-workers.yml с N парами worker-runner
# Использование: N8N_WORKER_COUNT=3 bash scripts/generate_n8n_workers.sh
#
# Этот скрипт идемпотентен - при повторном запуске файл перезаписывается

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source utilities if available
if [[ -f "$SCRIPT_DIR/utils.sh" ]]; then
    source "$SCRIPT_DIR/utils.sh"
else
    # Fallback logging functions
    log_info() { echo "[INFO] $*"; }
    log_warning() { echo "[WARN] $*"; }
    log_error() { echo "[ERROR] $*" >&2; }
fi

# Загрузить N8N_WORKER_COUNT из .env если не задан
if [[ -z "${N8N_WORKER_COUNT:-}" ]] && [[ -f "$PROJECT_DIR/.env" ]]; then
    N8N_WORKER_COUNT=$(grep -E "^N8N_WORKER_COUNT=" "$PROJECT_DIR/.env" | cut -d'=' -f2 || echo "1")
fi
N8N_WORKER_COUNT=${N8N_WORKER_COUNT:-1}

# Валидация N8N_WORKER_COUNT
if ! [[ "$N8N_WORKER_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    log_error "N8N_WORKER_COUNT must be a positive integer, got: '$N8N_WORKER_COUNT'"
    exit 1
fi

OUTPUT_FILE="$PROJECT_DIR/docker-compose.n8n-workers.yml"

log_info "Generating n8n worker-runner pairs configuration..."
log_info "N8N_WORKER_COUNT=$N8N_WORKER_COUNT"

# Перезаписываем файл (идемпотентно)
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
        condition: service_started
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
        condition: service_started

EOF
done

log_info "Generated $OUTPUT_FILE with $N8N_WORKER_COUNT worker-runner pair(s)"
