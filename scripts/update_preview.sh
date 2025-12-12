#!/bin/bash

# Preview available updates for Docker images without applying them
# This is a "dry-run" mode for the update process

set -e

# Source the utilities file and initialize paths
source "$(dirname "$0")/utils.sh"
init_paths

# Load environment variables
load_env || exit 1

echo ""
echo "========================================"
echo "  Update Preview (Dry Run)"
echo "========================================"
echo ""
echo "Checking for available updates..."
echo ""

# Function to get local image digest
get_local_digest() {
    local image="$1"
    docker image inspect "$image" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d'@' -f2 | head -c 19
}

# Function to get remote image digest (without pulling)
get_remote_digest() {
    local image="$1"
    # Use docker manifest inspect to get remote digest without pulling
    docker manifest inspect "$image" 2>/dev/null | grep -m1 '"digest"' | cut -d'"' -f4 | head -c 19
}

# Function to check if an update is available
check_image_update() {
    local service_name="$1"
    local image="$2"

    # Skip if image is empty
    if [ -z "$image" ]; then
        return
    fi

    local local_digest=$(get_local_digest "$image")
    local remote_digest=$(get_remote_digest "$image")

    if [ -z "$local_digest" ]; then
        printf "  ${YELLOW}%-20s${NC} %-45s ${BLUE}[Not installed]${NC}\n" "$service_name" "$image"
        return
    fi

    if [ -z "$remote_digest" ]; then
        printf "  ${YELLOW}%-20s${NC} %-45s ${YELLOW}[Cannot check]${NC}\n" "$service_name" "$image"
        return
    fi

    if [ "$local_digest" != "$remote_digest" ]; then
        printf "  ${GREEN}%-20s${NC} %-45s ${GREEN}[Update available]${NC}\n" "$service_name" "$image"
        echo "                     Local:  $local_digest..."
        echo "                     Remote: $remote_digest..."
        UPDATES_AVAILABLE=$((UPDATES_AVAILABLE + 1))
    else
        printf "  ${NC}%-20s${NC} %-45s ${NC}[Up to date]${NC}\n" "$service_name" "$image"
    fi
}

# Counter for available updates
UPDATES_AVAILABLE=0

# Get list of images from docker-compose
log_info "Scanning images from docker-compose.yml..."
echo ""

# Core services (always checked)
echo "Core Services:"
echo "--------------"
check_image_update "postgres" "postgres:${POSTGRES_VERSION:-17}-alpine"
check_image_update "redis" "valkey/valkey:8-alpine"
check_image_update "caddy" "caddy:2-alpine"
echo ""

# Check n8n if profile is active
if is_profile_active "n8n"; then
    echo "n8n Services:"
    echo "-------------"
    check_image_update "n8n" "docker.n8n.io/n8nio/n8n:${N8N_VERSION:-latest}"
    check_image_update "n8n-runner" "n8nio/runners:${N8N_VERSION:-latest}"
    echo ""
fi

# Check monitoring if profile is active
if is_profile_active "monitoring"; then
    echo "Monitoring Services:"
    echo "--------------------"
    check_image_update "grafana" "grafana/grafana:latest"
    check_image_update "prometheus" "prom/prometheus:latest"
    check_image_update "node-exporter" "prom/node-exporter:latest"
    check_image_update "cadvisor" "gcr.io/cadvisor/cadvisor:latest"
    echo ""
fi

# Check other common services
if is_profile_active "flowise"; then
    echo "Flowise:"
    echo "--------"
    check_image_update "flowise" "flowiseai/flowise:latest"
    echo ""
fi

if is_profile_active "open-webui"; then
    echo "Open WebUI:"
    echo "-----------"
    check_image_update "open-webui" "ghcr.io/open-webui/open-webui:main"
    echo ""
fi

if is_profile_active "portainer"; then
    echo "Portainer:"
    echo "----------"
    check_image_update "portainer" "portainer/portainer-ce:latest"
    echo ""
fi

if is_profile_active "langfuse"; then
    echo "Langfuse:"
    echo "---------"
    check_image_update "langfuse-web" "langfuse/langfuse:latest"
    check_image_update "langfuse-worker" "langfuse/langfuse-worker:latest"
    echo ""
fi

if is_profile_active "cpu" || is_profile_active "gpu-nvidia" || is_profile_active "gpu-amd"; then
    echo "Ollama:"
    echo "-------"
    check_image_update "ollama" "ollama/ollama:latest"
    echo ""
fi

if is_profile_active "qdrant"; then
    echo "Qdrant:"
    echo "-------"
    check_image_update "qdrant" "qdrant/qdrant:latest"
    echo ""
fi

if is_profile_active "searxng"; then
    echo "SearXNG:"
    echo "--------"
    check_image_update "searxng" "searxng/searxng:latest"
    echo ""
fi

if is_profile_active "postgresus"; then
    echo "Postgresus:"
    echo "-----------"
    check_image_update "postgresus" "ghcr.io/postgresus/postgresus:latest"
    echo ""
fi

# Summary
echo "========================================"
echo "  Summary"
echo "========================================"
echo ""

if [ $UPDATES_AVAILABLE -gt 0 ]; then
    echo -e "${GREEN}$UPDATES_AVAILABLE update(s) available.${NC}"
    echo ""
    echo "To apply updates, run:"
    echo "  make update"
    echo ""
    echo "Or manually:"
    echo "  docker compose -p localai pull"
    echo "  docker compose -p localai up -d"
else
    echo -e "${GREEN}All images are up to date!${NC}"
fi

echo ""
