#!/bin/bash

# AppFlowy & Affine Debug Script
# This script helps diagnose issues with AppFlowy and Affine services

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

log_info "Starting AppFlowy & Affine Debug Analysis..."

# Check if .env file exists
if [ ! -f ".env" ]; then
    log_error ".env file not found. Please run the installer first."
    exit 1
fi

# Load environment variables
set -a
source ".env"
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

# Check enabled services
echo
log_info "=== ENABLED SERVICES ==="
echo "COMPOSE_PROFILES: $COMPOSE_PROFILES"
echo

if is_profile_active "appflowy"; then
    echo "✓ AppFlowy is enabled"
else
    echo "✗ AppFlowy is disabled"
fi

if is_profile_active "affine"; then
    echo "✓ Affine is enabled"
else
    echo "✗ Affine is disabled"
fi

# Check Docker Compose syntax
echo
log_info "=== DOCKER COMPOSE VALIDATION ==="
if docker compose config > /dev/null 2>&1; then
    log_success "Docker Compose syntax is valid"
else
    log_error "Docker Compose syntax error:"
    docker compose config
    exit 1
fi

# Check service status
echo
log_info "=== SERVICE STATUS ==="
docker compose -p localai ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}"

# Check AppFlowy services if enabled
if is_profile_active "appflowy"; then
    echo
    log_info "=== APPFLOWY SERVICE ANALYSIS ==="
    
    # Check AppFlowy environment variables
    echo "Required AppFlowy variables:"
    echo "  APPFLOWY_HOSTNAME: ${APPFLOWY_HOSTNAME:-NOT_SET}"
    echo "  APPFLOWY_POSTGRES_PASSWORD: ${APPFLOWY_POSTGRES_PASSWORD:+SET}"
    echo "  APPFLOWY_JWT_SECRET: ${APPFLOWY_JWT_SECRET:+SET}"
    echo "  APPFLOWY_ADMIN_PASSWORD: ${APPFLOWY_ADMIN_PASSWORD:+SET}"
    echo "  APPFLOWY_MINIO_PASSWORD: ${APPFLOWY_MINIO_PASSWORD:+SET}"
    
    # Check individual AppFlowy containers
    appflowy_services=("appflowy-postgres" "appflowy-redis" "appflowy-minio" "appflowy-gotrue" "appflowy-cloud" "appflowy-web")
    
    for service in "${appflowy_services[@]}"; do
        echo
        echo "--- $service ---"
        if docker ps --filter name=$service --format "table {{.Names}}\t{{.Status}}" | grep -q $service; then
            log_success "$service is running"
            # Show last few log lines
            echo "Recent logs:"
            docker logs --tail 10 $service 2>&1 | sed 's/^/  /'
        else
            log_warning "$service is not running"
            echo "Recent logs:"
            docker logs --tail 20 $service 2>&1 | sed 's/^/  /' || echo "  No logs available"
        fi
    done
    
    # Check AppFlowy health
    echo
    echo "=== APPFLOWY HEALTH CHECKS ==="
    for service in "${appflowy_services[@]}"; do
        health=$(docker inspect $service --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
        case $health in
            "healthy") log_success "$service: healthy" ;;
            "unhealthy") log_error "$service: unhealthy" ;;
            "starting") log_warning "$service: starting" ;;
            *) echo "$service: $health" ;;
        esac
    done
fi

# Check Affine services if enabled
if is_profile_active "affine"; then
    echo
    log_info "=== AFFINE SERVICE ANALYSIS ==="
    
    # Check Affine environment variables
    echo "Required Affine variables:"
    echo "  AFFINE_HOSTNAME: ${AFFINE_HOSTNAME:-NOT_SET}"
    echo "  AFFINE_POSTGRES_PASSWORD: ${AFFINE_POSTGRES_PASSWORD:+SET}"
    echo "  AFFINE_ADMIN_EMAIL: ${AFFINE_ADMIN_EMAIL:-NOT_SET}"
    echo "  AFFINE_ADMIN_PASSWORD: ${AFFINE_ADMIN_PASSWORD:+SET}"
    
    # Check individual Affine containers
    affine_services=("affine-postgres" "affine-redis" "affine-migration" "affine")
    
    for service in "${affine_services[@]}"; do
        echo
        echo "--- $service ---"
        if docker ps --filter name=$service --format "table {{.Names}}\t{{.Status}}" | grep -q $service; then
            log_success "$service is running"
            echo "Recent logs:"
            docker logs --tail 10 $service 2>&1 | sed 's/^/  /'
        else
            log_warning "$service is not running"
            echo "Recent logs:"
            docker logs --tail 20 $service 2>&1 | sed 's/^/  /' || echo "  No logs available"
        fi
    done
    
    # Check Affine health
    echo
    echo "=== AFFINE HEALTH CHECKS ==="
    for service in "${affine_services[@]}"; do
        if [ "$service" != "affine-migration" ]; then # Migration doesn't have health check
            health=$(docker inspect $service --format='{{.State.Health.Status}}' 2>/dev/null || echo "no-health-check")
            case $health in
                "healthy") log_success "$service: healthy" ;;
                "unhealthy") log_error "$service: unhealthy" ;;
                "starting") log_warning "$service: starting" ;;
                *) echo "$service: $health" ;;
            esac
        fi
    done
fi

# Network connectivity tests
echo
log_info "=== NETWORK CONNECTIVITY ==="

if is_profile_active "appflowy"; then
    echo "Testing AppFlowy internal connectivity:"
    # Test database connection from appflowy-cloud (if running)
    if docker ps --filter name=appflowy-cloud --format "{{.Names}}" | grep -q appflowy-cloud; then
        if docker exec appflowy-cloud sh -c "timeout 5 nc -z appflowy-postgres 5432" 2>/dev/null; then
            log_success "AppFlowy Cloud -> PostgreSQL: Connected"
        else
            log_error "AppFlowy Cloud -> PostgreSQL: Failed"
        fi
        
        if docker exec appflowy-cloud sh -c "timeout 5 nc -z appflowy-redis 6379" 2>/dev/null; then
            log_success "AppFlowy Cloud -> Redis: Connected"
        else
            log_error "AppFlowy Cloud -> Redis: Failed"
        fi
        
        if docker exec appflowy-cloud sh -c "timeout 5 nc -z appflowy-minio 9000" 2>/dev/null; then
            log_success "AppFlowy Cloud -> MinIO: Connected"
        else
            log_error "AppFlowy Cloud -> MinIO: Failed"
        fi
    fi
fi

if is_profile_active "affine"; then
    echo "Testing Affine internal connectivity:"
    # Test database connection from affine (if running)
    if docker ps --filter name=affine --format "{{.Names}}" | grep -q "^affine$"; then
        if docker exec affine sh -c "timeout 5 nc -z affine-postgres 5432" 2>/dev/null; then
            log_success "Affine -> PostgreSQL: Connected"
        else
            log_error "Affine -> PostgreSQL: Failed"
        fi
        
        if docker exec affine sh -c "timeout 5 nc -z affine-redis 6379" 2>/dev/null; then
            log_success "Affine -> Redis: Connected"
        else
            log_error "Affine -> Redis: Failed"
        fi
    fi
fi

# Resource usage
echo
log_info "=== RESOURCE USAGE ==="
echo "Docker system resource usage:"
docker system df

echo
echo "Container resource usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Volume information
echo
log_info "=== VOLUME INFORMATION ==="
if is_profile_active "appflowy"; then
    echo "AppFlowy volumes:"
    docker volume ls | grep appflowy || echo "No AppFlowy volumes found"
fi

if is_profile_active "affine"; then
    echo "Affine volumes:"
    docker volume ls | grep affine || echo "No Affine volumes found"
fi

# Recommendations
echo
log_info "=== RECOMMENDATIONS ==="

if is_profile_active "appflowy"; then
    # Check if GoTrue is the problem
    gotrue_health=$(docker inspect appflowy-gotrue --format='{{.State.Health.Status}}' 2>/dev/null || echo "not-running")
    if [ "$gotrue_health" = "unhealthy" ] || [ "$gotrue_health" = "not-running" ]; then
        echo "🔧 AppFlowy GoTrue Issues Detected:"
        echo "   1. Try restarting AppFlowy services:"
        echo "      docker compose -p localai restart appflowy-gotrue appflowy-cloud appflowy-web"
        echo "   2. Check GoTrue logs for specific errors:"
        echo "      docker logs appflowy-gotrue"
        echo "   3. Verify JWT_SECRET is properly set in .env"
    fi
fi

if is_profile_active "affine"; then
    # Check if migration completed
    migration_exit_code=$(docker inspect affine-migration --format='{{.State.ExitCode}}' 2>/dev/null || echo "unknown")
    if [ "$migration_exit_code" != "0" ] && [ "$migration_exit_code" != "unknown" ]; then
        echo "🔧 Affine Migration Issues Detected:"
        echo "   1. Check migration logs:"
        echo "      docker logs affine-migration"
        echo "   2. Try rerunning migration:"
        echo "      docker compose -p localai up affine-migration"
    fi
fi

echo
echo "=== USEFUL COMMANDS ==="
echo "Restart all services:       docker compose -p localai restart"
echo "View service logs:          docker logs <container_name>"
echo "Check service health:       docker inspect <container_name> --format='{{.State.Health.Status}}'"
echo "Remove and recreate:        docker compose -p localai down && docker compose -p localai up -d"

echo
log_success "Debug analysis complete!"
echo "If issues persist, please share the output of this script for further assistance."

exit 0
