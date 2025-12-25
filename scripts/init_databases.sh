#!/bin/bash
# =============================================================================
# init_databases.sh - Create isolated PostgreSQL databases for services
# =============================================================================
# This script runs during install/update and creates databases if they don't exist.
# Safe to run multiple times - only creates missing databases.
#
# Usage: Called automatically from install.sh and apply_update.sh
# =============================================================================

source "$(dirname "$0")/utils.sh" && init_paths

# List of databases to create (add new services here)
# Note: n8n uses the default 'postgres' database
DATABASES=(
    "langfuse"
    "lightrag"
    "postiz"
    "waha"
)

log_header "Initializing PostgreSQL Databases"

# Ensure postgres is running and healthy
log_info "Waiting for PostgreSQL to be ready..."
MAX_WAIT=60
WAITED=0

while ! docker exec postgres pg_isready -U postgres > /dev/null 2>&1; do
    if [ $WAITED -ge $MAX_WAIT ]; then
        log_error "PostgreSQL did not become ready in ${MAX_WAIT}s"
        exit 1
    fi
    sleep 1
    ((WAITED++))
done

log_success "PostgreSQL is ready"

# Create databases
CREATED=0
EXISTING=0

for db in "${DATABASES[@]}"; do
    # Check if database exists
    EXISTS=$(docker exec postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$db'" 2>/dev/null | tr -d ' ')

    if [ "$EXISTS" = "1" ]; then
        log_info "Database '$db' already exists"
        ((EXISTING++))
    else
        log_info "Creating database '$db'..."
        if docker exec postgres psql -U postgres -c "CREATE DATABASE $db" > /dev/null 2>&1; then
            log_success "Database '$db' created"
            ((CREATED++))
        else
            log_error "Failed to create database '$db'"
        fi
    fi
done

log_divider
log_success "Database initialization complete: $CREATED created, $EXISTING already existed"
