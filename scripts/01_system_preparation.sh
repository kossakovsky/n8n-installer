#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

export DEBIAN_FRONTEND=noninteractive

# System Update
log_info "Updating package list and upgrading the system..."
apt update -y && apt upgrade -y

# Installing Basic Utilities
log_info "Installing standard CLI tools..."
apt install -y \
  htop git curl make unzip ufw fail2ban python3 psmisc whiptail \
  build-essential ca-certificates gnupg lsb-release openssl \
  debian-keyring debian-archive-keyring apt-transport-https python3-pip python3-dotenv python3-yaml

# Configuring Firewall (UFW)
log_info "Configuring firewall (UFW)..."
echo "y" | ufw reset
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https
ufw reload
ufw status

# Configuring Fail2Ban
log_info "Enabling brute-force protection (Fail2Ban)..."
systemctl enable fail2ban
sleep 1
systemctl start fail2ban
sleep 1
fail2ban-client status
sleep 1
fail2ban-client status sshd

# Automatic Security Updates
log_info "Enabling automatic security updates..."
apt install -y unattended-upgrades
# Automatic confirmation for dpkg-reconfigure
echo "y" | dpkg-reconfigure --priority=low unattended-upgrades

# Set vm.max_map_count for Elasticsearch (required for RAGFlow if using ES backend)
log_info "Configuring vm.max_map_count for Elasticsearch support..."
if [ -f /etc/sysctl.conf ]; then
    if ! grep -q "^vm.max_map_count" /etc/sysctl.conf; then
        echo "vm.max_map_count=262144" >> /etc/sysctl.conf
        log_info "Added vm.max_map_count=262144 to /etc/sysctl.conf"
    fi
fi
# Apply immediately
sysctl -w vm.max_map_count=262144 > /dev/null 2>&1 || true

exit 0 