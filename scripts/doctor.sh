#!/bin/bash

# System diagnostics script for n8n-install
# Checks DNS, SSL, containers, disk space, memory, and configuration

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Get the directory where the script resides
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
ENV_FILE="$PROJECT_ROOT/.env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
OK=0

# Print status functions
print_ok() {
    echo -e "  ${GREEN}[OK]${NC} $1"
    OK=$((OK + 1))
}

print_warning() {
    echo -e "  ${YELLOW}[WARNING]${NC} $1"
    WARNINGS=$((WARNINGS + 1))
}

print_error() {
    echo -e "  ${RED}[ERROR]${NC} $1"
    ERRORS=$((ERRORS + 1))
}

print_info() {
    echo -e "  ${BLUE}[INFO]${NC} $1"
}

echo ""
echo "========================================"
echo "  n8n-install System Diagnostics"
echo "========================================"
echo ""

# Check if .env file exists
echo "Configuration:"
echo "--------------"

if [ -f "$ENV_FILE" ]; then
    print_ok ".env file exists"

    # Load environment variables
    set -a
    source "$ENV_FILE"
    set +a

    # Check required variables
    if [ -n "$USER_DOMAIN_NAME" ]; then
        print_ok "USER_DOMAIN_NAME is set: $USER_DOMAIN_NAME"
    else
        print_error "USER_DOMAIN_NAME is not set"
    fi

    if [ -n "$LETSENCRYPT_EMAIL" ]; then
        print_ok "LETSENCRYPT_EMAIL is set"
    else
        print_warning "LETSENCRYPT_EMAIL is not set (SSL certificates may not work)"
    fi

    if [ -n "$COMPOSE_PROFILES" ]; then
        print_ok "Active profiles: $COMPOSE_PROFILES"
    else
        print_warning "No service profiles are active"
    fi
else
    print_error ".env file not found at $ENV_FILE"
    echo ""
    echo "Run 'make install' to set up the environment."
    exit 1
fi

echo ""

# Check Docker
echo "Docker:"
echo "-------"

if command -v docker &> /dev/null; then
    print_ok "Docker is installed"

    if docker info &> /dev/null; then
        print_ok "Docker daemon is running"
    else
        print_error "Docker daemon is not running or not accessible"
    fi
else
    print_error "Docker is not installed"
fi

if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    print_ok "Docker Compose is available"
else
    print_warning "Docker Compose is not available"
fi

echo ""

# Check disk space
echo "Disk Space:"
echo "-----------"

DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
DISK_AVAIL=$(df -h / | awk 'NR==2 {print $4}')

if [ "$DISK_USAGE" -lt 80 ]; then
    print_ok "Disk usage: ${DISK_USAGE}% (${DISK_AVAIL} available)"
elif [ "$DISK_USAGE" -lt 90 ]; then
    print_warning "Disk usage: ${DISK_USAGE}% (${DISK_AVAIL} available) - Consider freeing space"
else
    print_error "Disk usage: ${DISK_USAGE}% (${DISK_AVAIL} available) - Critical!"
fi

# Check Docker disk usage
DOCKER_DISK=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1)
if [ -n "$DOCKER_DISK" ]; then
    print_info "Docker using: $DOCKER_DISK"
fi

echo ""

# Check memory
echo "Memory:"
echo "-------"

if command -v free &> /dev/null; then
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    MEM_AVAIL=$(free -h | awk '/^Mem:/ {print $7}')
    MEM_PERCENT=$(free | awk '/^Mem:/ {printf("%.0f", $3/$2 * 100)}')

    if [ "$MEM_PERCENT" -lt 80 ]; then
        print_ok "Memory usage: ${MEM_PERCENT}% (${MEM_AVAIL} available of ${MEM_TOTAL})"
    elif [ "$MEM_PERCENT" -lt 90 ]; then
        print_warning "Memory usage: ${MEM_PERCENT}% (${MEM_AVAIL} available)"
    else
        print_error "Memory usage: ${MEM_PERCENT}% - High memory pressure!"
    fi
else
    print_info "Memory info not available (free command not found)"
fi

echo ""

# Check containers
echo "Containers:"
echo "-----------"

RUNNING=$(docker ps -q 2>/dev/null | wc -l)
TOTAL=$(docker ps -aq 2>/dev/null | wc -l)

print_info "$RUNNING of $TOTAL containers running"

# Check for containers with high restart counts
HIGH_RESTARTS=0
while read -r line; do
    if [ -n "$line" ]; then
        name=$(echo "$line" | cut -d'|' -f1)
        restarts=$(echo "$line" | cut -d'|' -f2)
        if [ "$restarts" -gt 3 ]; then
            print_warning "$name has restarted $restarts times"
            HIGH_RESTARTS=$((HIGH_RESTARTS + 1))
        fi
    fi
done < <(docker ps --format '{{.Names}}|{{.Status}}' 2>/dev/null | while read container; do
    name=$(echo "$container" | cut -d'|' -f1)
    restarts=$(docker inspect --format '{{.RestartCount}}' "$name" 2>/dev/null || echo "0")
    echo "$name|$restarts"
done)

if [ "$HIGH_RESTARTS" -eq 0 ]; then
    print_ok "No containers with excessive restarts"
fi

# Check unhealthy containers
UNHEALTHY=$(docker ps --filter "health=unhealthy" --format '{{.Names}}' 2>/dev/null)
if [ -n "$UNHEALTHY" ]; then
    for container in $UNHEALTHY; do
        print_error "Container $container is unhealthy"
    done
else
    print_ok "No unhealthy containers"
fi

echo ""

# Check DNS resolution
echo "DNS Resolution:"
echo "---------------"

check_dns() {
    local hostname="$1"
    local varname="$2"

    if [ -z "$hostname" ] || [ "$hostname" == "yourdomain.com" ] || [[ "$hostname" == *".yourdomain.com" ]]; then
        return
    fi

    if host "$hostname" &> /dev/null; then
        print_ok "$varname ($hostname) resolves"
    else
        print_error "$varname ($hostname) does not resolve"
    fi
}

# Only check if we have a real domain
if [ -n "$USER_DOMAIN_NAME" ] && [ "$USER_DOMAIN_NAME" != "yourdomain.com" ]; then
    check_dns "$N8N_HOSTNAME" "N8N_HOSTNAME"
    check_dns "$GRAFANA_HOSTNAME" "GRAFANA_HOSTNAME"
    check_dns "$PORTAINER_HOSTNAME" "PORTAINER_HOSTNAME"
    check_dns "$WELCOME_HOSTNAME" "WELCOME_HOSTNAME"
else
    print_info "Skipping DNS checks (no domain configured)"
fi

echo ""

# Check SSL (Caddy)
echo "SSL/Caddy:"
echo "----------"

if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "caddy"; then
    print_ok "Caddy container is running"

    # Check if Caddy can reach the config
    if docker exec caddy caddy validate --config /etc/caddy/Caddyfile &> /dev/null; then
        print_ok "Caddyfile is valid"
    else
        print_warning "Caddyfile validation failed (may be fine if using default)"
    fi
else
    print_warning "Caddy container is not running"
fi

echo ""

# Check key services
echo "Key Services:"
echo "-------------"

check_service() {
    local container="$1"
    local port="$2"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        print_ok "$container is running"
    else
        if [[ ",$COMPOSE_PROFILES," == *",$container,"* ]] || [ "$container" == "postgres" ] || [ "$container" == "redis" ]; then
            print_error "$container is not running (but expected)"
        fi
    fi
}

check_service "postgres" "5432"
check_service "redis" "6379"
check_service "caddy" "80"

if [[ ",$COMPOSE_PROFILES," == *",n8n,"* ]]; then
    check_service "n8n" "5678"
fi

if [[ ",$COMPOSE_PROFILES," == *",monitoring,"* ]]; then
    check_service "grafana" "3000"
    check_service "prometheus" "9090"
fi

echo ""

# Summary
echo "========================================"
echo "  Summary"
echo "========================================"
echo ""

echo -e "  ${GREEN}OK:${NC} $OK"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "  ${RED}Errors:${NC} $ERRORS"
echo ""

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}Some issues were found. Please review the errors above.${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}System is mostly healthy with some warnings.${NC}"
    exit 0
else
    echo -e "${GREEN}System is healthy!${NC}"
    exit 0
fi
