#!/bin/bash

# QUICK FIX für AppFlowy GoTrue Problem
echo "=== APPFLOWY QUICK FIX ==="

# 1. Stoppe alle Services
echo "1. Stopping all services..."
sudo docker compose -p localai down

# 2. Check GoTrue logs to diagnose issue
echo "2. Checking existing GoTrue logs..."
sudo docker logs appflowy-gotrue --tail 20 2>/dev/null || echo "No GoTrue container found"

# 3. Debug: Manually test GoTrue with minimal config
echo "3. Testing GoTrue manually..."

# Start only the prerequisite services first
echo "Starting PostgreSQL and Redis..."
sudo docker compose -p localai up -d appflowy-postgres appflowy-redis

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
sleep 15

# Now try GoTrue with verbose logging
echo "Testing GoTrue connection..."
sudo docker run --rm --network localai_default \
  -e GOTRUE_LOG_LEVEL=debug \
  -e GOTRUE_DB_DRIVER=postgres \
  -e DATABASE_URL="postgres://postgres:${APPFLOWY_POSTGRES_PASSWORD}@appflowy-postgres:5432/postgres?sslmode=disable" \
  -e GOTRUE_JWT_SECRET="${APPFLOWY_JWT_SECRET}" \
  -e PORT=9999 \
  appflowyinc/gotrue:latest &

GOTRUE_PID=$!
sleep 10

# Test if GoTrue responds
echo "Testing GoTrue health endpoint..."
if curl -f http://localhost:9999/health 2>/dev/null; then
    echo "✓ GoTrue is working!"
else
    echo "✗ GoTrue still has issues"
    
    # Kill the test GoTrue
    kill $GOTRUE_PID 2>/dev/null
    
    echo "Checking database connection..."
    sudo docker exec appflowy-postgres psql -U postgres -d postgres -c "\l" || echo "Database connection failed"
fi

# 4. Clean up test and restart with new config
echo "4. Restarting with corrected configuration..."
sudo docker compose -p localai down
sudo docker compose -p localai up -d

echo "=== FIX COMPLETE ==="
echo "Monitor with: sudo docker logs appflowy-gotrue -f"
