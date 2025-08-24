#!/bin/bash
# Get the gateway IP dynamically
GATEWAY_IP=$(docker network inspect n8n-installer-enhanced_default | grep -o '"Gateway": "[^"]*' | grep -o '[0-9.]*')
echo "Gateway IP: $GATEWAY_IP"

# Update OpenHands environment
docker exec openhands sh -c "echo '$GATEWAY_IP host.docker.internal' >> /etc/hosts"
