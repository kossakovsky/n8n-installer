#!/bin/bash
# =============================================================================
# databases.sh - PostgreSQL database initialization library
# =============================================================================
# Creates isolated PostgreSQL databases for services.
# Can be sourced as library or run directly.
#
# Functions:
#   wait_for_postgres()     - Wait for PostgreSQL to be ready
#   create_database()       - Create a single database if not exists
#   init_all_databases()    - Initialize all service databases
#
# Usage as library:
#   source "$SCRIPT_DIR/databases.sh"
#   init_all_databases
#
# Usage as script:
#   bash scripts/databases.sh
# =============================================================================

# Only source utils.sh if not already sourced (check for init_paths function)
if ! declare -f init_paths > /dev/null 2>&1; then
    source "$(dirname "$0")/utils.sh" && init_paths
fi

# List of databases to create (add new services here)
# Note: n8n uses the default 'postgres' database
INIT_DB_DATABASES=(
    "langfuse"
    "lightrag"
    "nocodb"
    "postiz"
    "waha"
)

#=============================================================================
# FUNCTIONS
#=============================================================================

# Wait for PostgreSQL to be ready
# Usage: wait_for_postgres [timeout_seconds]
# Returns: 0 on success, 1 on timeout
wait_for_postgres() {
    local max_wait="${1:-60}"
    local waited=0

    log_info "Waiting for PostgreSQL to be ready..."

    while ! docker exec postgres pg_isready -U postgres > /dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            log_error "PostgreSQL did not become ready in ${max_wait}s"
            return 1
        fi
        sleep 1
        ((waited++))
    done

    log_success "PostgreSQL is ready"
    return 0
}

# Create a single database if it doesn't exist
# Usage: create_database "dbname"
# Returns: 0 on success (created or already exists), 1 on failure
# Sets: CREATE_DB_RESULT to "created", "exists", or "failed"
create_database() {
    local db="$1"
    CREATE_DB_RESULT=""

    # Check if database exists
    local exists
    exists=$(docker exec postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$db'" 2>/dev/null | tr -d ' ')

    if [ "$exists" = "1" ]; then
        log_info "Database '$db' already exists"
        CREATE_DB_RESULT="exists"
        return 0
    else
        log_info "Creating database '$db'..."
        if docker exec postgres psql -U postgres -c "CREATE DATABASE $db" > /dev/null 2>&1; then
            log_success "Database '$db' created"
            CREATE_DB_RESULT="created"
            return 0
        else
            log_error "Failed to create database '$db'"
            CREATE_DB_RESULT="failed"
            return 1
        fi
    fi
}

# Initialize all service databases
# Usage: init_all_databases
# Returns: 0 on success, 1 on failure
init_all_databases() {
    log_header "Initializing PostgreSQL Databases"

    # Wait for PostgreSQL to be ready
    wait_for_postgres || return 1

    # Create databases
    local created=0
    local existing=0
    local failed=0

    for db in "${INIT_DB_DATABASES[@]}"; do
        create_database "$db"
        case "$CREATE_DB_RESULT" in
            created)  ((created++)) ;;
            exists)   ((existing++)) ;;
            failed)   ((failed++)) ;;
        esac
    done

    log_divider
    log_success "Database initialization complete: $created created, $existing already existed"

    # Return failure if any database failed to create
    [[ $failed -eq 0 ]] && return 0 || return 1
}

#=============================================================================
# ENTRY POINT
#=============================================================================
# Only run if executed directly (not sourced)

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    init_all_databases
fi
