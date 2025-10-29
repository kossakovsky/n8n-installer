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

exit 0 