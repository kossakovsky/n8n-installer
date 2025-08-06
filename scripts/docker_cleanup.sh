#!/bin/bash

# This script is intended for cleaning up the Docker system.
# It removes all unused containers, images, networks, and volumes.
# Use with caution, as this action is irreversible.

echo "Starting Docker cleanup..."

# The 'docker system prune' command removes:
# - all stopped containers
# - all networks not used by at least one container
# - all "dangling" (unreferenced) images
# - all build cache
#
# Additional flags:
# -a, --all:     Remove all unused images, not just dangling ones.
# --volumes:   Remove all unused volumes.
# -f, --force:   Do not prompt for confirmation.

docker system prune -a --volumes -f

echo "Docker cleanup completed successfully."

