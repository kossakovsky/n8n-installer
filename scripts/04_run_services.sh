#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# 1. Check for .env file
if [ ! -f ".env" ]; then
  log_error ".env file not found in project root." >&2
  exit 1
fi

# 2. Check for docker-compose.yml file
if [ ! -f "docker-compose.yml" ]; then
  log_error "docker-compose.yml file not found in project root." >&2
  exit 1
fi

# 3. Check for Caddyfile (optional but recommended for reverse proxy)
if [ ! -f "Caddyfile" ]; then
  log_warning "Caddyfile not found in project root. Reverse proxy might not work as expected." >&2
  exit 1
fi

# 4. Check if Docker daemon is running
if ! docker info > /dev/null 2>&1; then
  log_error "Docker daemon is not running. Please start Docker and try again." >&2
  exit 1
fi

# 5. Check if start_services.py exists and is executable
if [ ! -f "start_services.py" ]; then
  log_error "start_services.py file not found in project root." >&2
  exit 1
fi

if [ ! -x "start_services.py" ]; then
  log_warning "start_services.py is not executable. Making it executable..."
  chmod +x "start_services.py"
fi

log_info "Launching services using start_services.py..."
# Execute start_services.py
./start_services.py

exit 0 