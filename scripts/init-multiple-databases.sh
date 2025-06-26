#!/bin/bash
# init-multiple-databases.sh - Automated database setup for unified n8n-installer

set -e
set -u

function create_user_and_database() {
    local database=$1
    local user="${1}_user"
    echo "Creating user '$user' and database '$database'"
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        CREATE USER $user WITH PASSWORD '$POSTGRES_PASSWORD';
        CREATE DATABASE $database;
        GRANT ALL PRIVILEGES ON DATABASE $database TO $user;
        ALTER USER $user CREATEDB;
        
        -- Enable pgvector extension for vector databases
        \c $database
        CREATE EXTENSION IF NOT EXISTS vector;
        
        -- Grant usage on the vector extension
        GRANT USAGE ON SCHEMA public TO $user;
        GRANT CREATE ON SCHEMA public TO $user;
        
        -- Create specific schema for each service if needed
        CREATE SCHEMA IF NOT EXISTS ${database}_schema;
        GRANT ALL PRIVILEGES ON SCHEMA ${database}_schema TO $user;
        
        -- Additional permissions for specific databases
EOSQL

    # Add specific configurations per database
    case "$database" in
        "n8n_db")
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" <<-EOSQL
                -- n8n specific optimizations
                ALTER DATABASE $database SET timezone = 'UTC';
                
                -- Create indexes for performance
                -- These will be created by n8n migration, but we prepare the space
                CREATE SCHEMA IF NOT EXISTS n8n_workflows;
                GRANT ALL PRIVILEGES ON SCHEMA n8n_workflows TO ${user};
EOSQL
            ;;
        "appflowy_db")
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" <<-EOSQL
                -- AppFlowy specific optimizations
                ALTER DATABASE $database SET timezone = 'UTC';
                
                -- AppFlowy requires specific extensions
                CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
                CREATE EXTENSION IF NOT EXISTS pgcrypto;
                
                -- Create AppFlowy specific schemas
                CREATE SCHEMA IF NOT EXISTS appflowy_workspace;
                CREATE SCHEMA IF NOT EXISTS appflowy_user;
                CREATE SCHEMA IF NOT EXISTS appflowy_collab;
                
                GRANT ALL PRIVILEGES ON SCHEMA appflowy_workspace TO ${user};
                GRANT ALL PRIVILEGES ON SCHEMA appflowy_user TO ${user};
                GRANT ALL PRIVILEGES ON SCHEMA appflowy_collab TO ${user};
EOSQL
            ;;
        "affine_db")
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" <<-EOSQL
                -- Affine specific optimizations
                ALTER DATABASE $database SET timezone = 'UTC';
                
                -- Affine requires specific extensions
                CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
                CREATE EXTENSION IF NOT EXISTS pgcrypto;
                
                -- Create Affine specific schemas
                CREATE SCHEMA IF NOT EXISTS affine_workspace;
                CREATE SCHEMA IF NOT EXISTS affine_blocks;
                CREATE SCHEMA IF NOT EXISTS affine_collaboration;
                
                GRANT ALL PRIVILEGES ON SCHEMA affine_workspace TO ${user};
                GRANT ALL PRIVILEGES ON SCHEMA affine_blocks TO ${user};
                GRANT ALL PRIVILEGES ON SCHEMA affine_collaboration TO ${user};
EOSQL
            ;;
        "langfuse_db")
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" <<-EOSQL
                -- Langfuse specific optimizations
                ALTER DATABASE $database SET timezone = 'UTC';
                
                -- Langfuse requires specific extensions for AI observability
                CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
                CREATE EXTENSION IF NOT EXISTS pgcrypto;
                
                -- Create Langfuse specific schemas
                CREATE SCHEMA IF NOT EXISTS langfuse_traces;
                CREATE SCHEMA IF NOT EXISTS langfuse_observations;
                
                GRANT ALL PRIVILEGES ON SCHEMA langfuse_traces TO ${user};
                GRANT ALL PRIVILEGES ON SCHEMA langfuse_observations TO ${user};
EOSQL
            ;;
        "supabase_db")
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -d "$database" <<-EOSQL
                -- Supabase specific optimizations
                ALTER DATABASE $database SET timezone = 'UTC';
                
                -- Supabase requires multiple extensions
                CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
                CREATE EXTENSION IF NOT EXISTS pgcrypto;
                CREATE EXTENSION IF NOT EXISTS pgjwt;
                CREATE EXTENSION IF NOT EXISTS pgsodium;
                
                -- Create Supabase specific schemas
                CREATE SCHEMA IF NOT EXISTS auth;
                CREATE SCHEMA IF NOT EXISTS storage;
                CREATE SCHEMA IF NOT EXISTS realtime;
                CREATE SCHEMA IF NOT EXISTS supabase_functions;
                
                GRANT ALL PRIVILEGES ON SCHEMA auth TO ${user};
                GRANT ALL PRIVILEGES ON SCHEMA storage TO ${user};
                GRANT ALL PRIVILEGES ON SCHEMA realtime TO ${user};
                GRANT ALL PRIVILEGES ON SCHEMA supabase_functions TO ${user};
EOSQL
            ;;
    esac
    
    echo "Database '$database' and user '$user' created successfully with optimizations"
}

function optimize_shared_postgres() {
    echo "Applying shared PostgreSQL optimizations..."
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        -- Shared PostgreSQL optimizations for multiple databases
        
        -- Memory settings for multiple databases
        ALTER SYSTEM SET shared_buffers = '256MB';
        ALTER SYSTEM SET effective_cache_size = '1GB';
        ALTER SYSTEM SET maintenance_work_mem = '64MB';
        ALTER SYSTEM SET checkpoint_completion_target = 0.9;
        ALTER SYSTEM SET wal_buffers = '16MB';
        ALTER SYSTEM SET default_statistics_target = 100;
        
        -- Connection settings
        ALTER SYSTEM SET max_connections = 200;
        ALTER SYSTEM SET max_worker_processes = 8;
        ALTER SYSTEM SET max_parallel_workers_per_gather = 2;
        ALTER SYSTEM SET max_parallel_workers = 8;
        
        -- Logging for debugging
        ALTER SYSTEM SET log_statement = 'mod';
        ALTER SYSTEM SET log_duration = on;
        ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';
        
        -- Apply settings
        SELECT pg_reload_conf();
EOSQL
    
    echo "Shared PostgreSQL optimizations applied"
}

function create_monitoring_user() {
    echo "Creating monitoring user for database health checks..."
    
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        -- Create monitoring user for health checks
        CREATE USER postgres_monitor WITH PASSWORD '$POSTGRES_PASSWORD';
        
        -- Grant necessary permissions for monitoring
        GRANT CONNECT ON DATABASE postgres TO postgres_monitor;
        GRANT pg_monitor TO postgres_monitor;
        
        -- Allow monitoring user to check all databases
EOSQL
    
    if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
        for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
            psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
                GRANT CONNECT ON DATABASE $db TO postgres_monitor;
EOSQL
        done
    fi
    
    echo "Monitoring user created successfully"
}

# Main execution
if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
    
    # Apply shared optimizations first
    optimize_shared_postgres
    
    # Create each database with optimizations
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_user_and_database $db
    done
    
    # Create monitoring user
    create_monitoring_user
    
    echo "All databases created successfully with optimizations"
    
    # Display summary
    echo "=== Database Creation Summary ==="
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        echo "  ✓ Database: $db"
        echo "    User: ${db}_user"
        echo "    Extensions: vector, uuid-ossp, pgcrypto (+ service-specific)"
        echo "    Schemas: public, ${db}_schema (+ service-specific)"
    done
    echo "  ✓ Monitoring user: postgres_monitor"
    echo "  ✓ Shared optimizations applied"
    echo "==============================="
else
    echo "No multiple databases specified in POSTGRES_MULTIPLE_DATABASES"
fi
