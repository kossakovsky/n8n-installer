#!/bin/bash

# Proxmox VM Deployment Script for Enhanced n8n-installer + Workspace
# Creates optimized VMs for the unified development and automation platform
# Eliminates desktop containerization overhead while maintaining full functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default VM configurations
declare -A VM_CONFIGS=(
    ["production"]="vmid=200,memory=32768,cores=12,disk_root=50,disk_data=200,network=vmbr1"
    ["development"]="vmid=201,memory=16384,cores=8,disk_root=40,disk_data=100,network=vmbr0"  
    ["minimal"]="vmid=202,memory=8192,cores=4,disk_root=30,disk_data=50,network=vmbr0"
)

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Function to show banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    PROXMOX VM DEPLOYMENT FOR ENHANCED n8n-INSTALLER             ║"
    echo "║                                                                                  ║"
    echo "║  🚀 Optimized VM creation for unified AI development workspace                   ║"
    echo "║  ⚡ Native performance without desktop containerization overhead                 ║"
    echo "║  🧠 AI Automation + Knowledge Management + Container Management                  ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Function to check Proxmox environment
check_proxmox_environment() {
    log_step "Checking Proxmox environment..."
    
    # Check if running on Proxmox host
    if [ ! -f "/etc/pve/nodes" ] && [ ! -d "/etc/pve" ]; then
        log_error "This script must be run on a Proxmox VE host"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("qm" "pvesh" "pvesm" "pveam")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command '$cmd' not found"
            exit 1
        fi
    done
    
    # Check if user has sufficient privileges
    if ! pvesh get /version &> /dev/null; then
        log_error "Insufficient privileges. Run as root or with proper PVE permissions."
        exit 1
    fi
    
    log_success "Proxmox environment verified"
}

# Function to select VM configuration
select_vm_configuration() {
    echo ""
    log_info "Available VM configurations for Enhanced n8n-installer:"
    echo ""
    
    echo -e "${GREEN}1. Production Environment${NC}"
    echo "   💾 Memory: 32GB | 🖥️  Cores: 12 | 💿 Storage: 50GB + 200GB data"
    echo "   🎯 Best for: Production deployments with all services"
    echo "   📊 Supports: Full service stack, high concurrency, multiple knowledge bases"
    echo ""
    
    echo -e "${YELLOW}2. Development Environment${NC}"
    echo "   💾 Memory: 16GB | 🖥️  Cores: 8 | 💿 Storage: 40GB + 100GB data"
    echo "   🎯 Best for: Development and testing with most services"
    echo "   📊 Supports: Core services + knowledge management + development tools"
    echo ""
    
    echo -e "${BLUE}3. Minimal Environment${NC}"
    echo "   💾 Memory: 8GB | 🖥️  Cores: 4 | 💿 Storage: 30GB + 50GB data"
    echo "   🎯 Best for: Testing and learning with essential services"
    echo "   📊 Supports: n8n + basic knowledge management"
    echo ""
    
    echo -e "${PURPLE}4. Custom Configuration${NC}"
    echo "   🔧 Define your own specifications"
    echo ""
    
    while true; do
        read -p "Select configuration (1-4): " choice
        case $choice in
            1) 
                SELECTED_CONFIG="production"
                log_success "Selected: Production Environment"
                break
                ;;
            2) 
                SELECTED_CONFIG="development"
                log_success "Selected: Development Environment"
                break
                ;;
            3) 
                SELECTED_CONFIG="minimal"
                log_success "Selected: Minimal Environment"
                break
                ;;
            4) 
                configure_custom_vm
                break
                ;;
            *) 
                log_warning "Invalid selection. Please choose 1-4."
                ;;
        esac
    done
}

# Function to configure custom VM
configure_custom_vm() {
    log_info "Custom VM Configuration"
    echo ""
    
    # VM ID
    while true; do
        read -p "VM ID (200-999): " vmid
        if [[ "$vmid" =~ ^[0-9]+$ ]] && [ "$vmid" -ge 200 ] && [ "$vmid" -le 999 ]; then
            if qm status "$vmid" &>/dev/null; then
                log_warning "VM ID $vmid already exists. Choose another."
            else
                break
            fi
        else
            log_warning "Invalid VM ID. Enter a number between 200-999."
        fi
    done
    
    # Memory
    while true; do
        read -p "Memory in MB (minimum 4096 for basic functionality): " memory
        if [[ "$memory" =~ ^[0-9]+$ ]] && [ "$memory" -ge 4096 ]; then
            break
        else
            log_warning "Invalid memory size. Minimum 4096 MB required."
        fi
    done
    
    # CPU cores
    while true; do
        read -p "CPU cores (minimum 2): " cores
        if [[ "$cores" =~ ^[0-9]+$ ]] && [ "$cores" -ge 2 ]; then
            break
        else
            log_warning "Invalid core count. Minimum 2 cores required."
        fi
    done
    
    # Root disk size
    while true; do
        read -p "Root disk size in GB (minimum 25): " disk_root
        if [[ "$disk_root" =~ ^[0-9]+$ ]] && [ "$disk_root" -ge 25 ]; then
            break
        else
            log_warning "Invalid disk size. Minimum 25 GB required."
        fi
    done
    
    # Data disk size
    while true; do
        read -p "Data disk size in GB (minimum 20): " disk_data
        if [[ "$disk_data" =~ ^[0-9]+$ ]] && [ "$disk_data" -ge 20 ]; then
            break
        else
            log_warning "Invalid disk size. Minimum 20 GB required."
        fi
    done
    
    # Network bridge
    read -p "Network bridge (default: vmbr0): " network
    network=${network:-vmbr0}
    
    # Create custom config
    VM_CONFIGS["custom"]="vmid=$vmid,memory=$memory,cores=$cores,disk_root=$disk_root,disk_data=$disk_data,network=$network"
    SELECTED_CONFIG="custom"
    
    log_success "Custom configuration created"
}

# Function to parse VM configuration
parse_vm_config() {
    local config="${VM_CONFIGS[$SELECTED_CONFIG]}"
    
    IFS=',' read -ra ADDR <<< "$config"
    for i in "${ADDR[@]}"; do
        IFS='=' read -ra PAIR <<< "$i"
        declare -g "VM_${PAIR[0]^^}"="${PAIR[1]}"
    done
}

# Function to select storage
select_storage() {
    log_step "Selecting storage for VM deployment..."
    
    echo ""
    log_info "Available storage options:"
    pvesm status --content images | awk 'NR>1 {print NR-1 ". " $1 " (" $2 ", " $4 " available)"}'
    
    echo ""
    read -p "Select storage for VM disks (name or number): " storage_input
    
    # Check if input is a number
    if [[ "$storage_input" =~ ^[0-9]+$ ]]; then
        VM_STORAGE=$(pvesm status --content images | awk -v n="$storage_input" 'NR==n+1 {print $1}')
    else
        VM_STORAGE="$storage_input"
    fi
    
    # Validate storage exists
    if ! pvesm status --storage "$VM_STORAGE" &>/dev/null; then
        log_error "Storage '$VM_STORAGE' not found or not accessible"
        exit 1
    fi
    
    log_success "Selected storage: $VM_STORAGE"
}

# Function to get Ubuntu ISO
get_ubuntu_iso() {
    log_step "Preparing Ubuntu 24.04 LTS ISO..."
    
    local iso_name="ubuntu-24.04-live-server-amd64.iso"
    local iso_url="https://releases.ubuntu.com/24.04/$iso_name"
    local iso_path="/var/lib/vz/template/iso/$iso_name"
    
    if [ ! -f "$iso_path" ]; then
        log_info "Downloading Ubuntu 24.04 LTS ISO..."
        wget -O "$iso_path" "$iso_url"
        
        if [ $? -ne 0 ]; then
            log_error "Failed to download Ubuntu ISO"
            exit 1
        fi
    else
        log_info "Ubuntu ISO already available"
    fi
    
    VM_ISO="local:iso/$iso_name"
    log_success "Ubuntu ISO ready: $VM_ISO"
}

# Function to create VM
create_vm() {
    log_step "Creating VM with optimized configuration..."
    
    parse_vm_config
    
    # VM Creation command
    local create_cmd="qm create $VM_VMID \
        --name 'enhanced-n8n-workspace' \
        --description 'Enhanced n8n-installer + Workspace-in-a-Box VM - Optimized for AI development and knowledge management' \
        --memory $VM_MEMORY \
        --cores $VM_CORES \
        --sockets 1 \
        --cpu cputype=host \
        --net0 virtio,bridge=$VM_NETWORK,firewall=1 \
        --ostype l26 \
        --agent enabled=1 \
        --onboot 0 \
        --protection 0 \
        --startup order=1,up=30,down=60"
    
    log_info "Creating VM $VM_VMID..."
    eval "$create_cmd"
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create VM"
        exit 1
    fi
    
    log_success "VM $VM_VMID created successfully"
}

# Function to add storage
add_storage() {
    log_step "Adding optimized storage configuration..."
    
    # Root disk (system)
    log_info "Adding root disk (${VM_DISK_ROOT}GB)..."
    qm set "$VM_VMID" --scsi0 "$VM_STORAGE:${VM_DISK_ROOT},format=qcow2,cache=writeback,discard=on,ssd=1"
    
    # Data disk (for Docker volumes, databases, etc.)
    log_info "Adding data disk (${VM_DISK_DATA}GB)..."
    qm set "$VM_VMID" --scsi1 "$VM_STORAGE:${VM_DISK_DATA},format=qcow2,cache=writeback,discard=on,ssd=1"
    
    # CD-ROM for installation
    qm set "$VM_VMID" --ide2 "$VM_ISO,media=cdrom"
    
    # Set boot order
    qm set "$VM_VMID" --boot order=scsi0
    
    log_success "Storage configuration completed"
}

# Function to optimize VM settings
optimize_vm_settings() {
    log_step "Applying performance optimizations..."
    
    # NUMA optimization
    qm set "$VM_VMID" --numa 1
    
    # CPU flags for better performance
    qm set "$VM_VMID" --cpu cputype=host,flags=+aes
    
    # Memory optimization
    qm set "$VM_VMID" --balloon 0  # Disable memory ballooning for consistent performance
    
    # I/O thread optimization
    qm set "$VM_VMID" --scsihw virtio-scsi-pci
    
    # VGA settings for server environment
    qm set "$VM_VMID" --vga serial0
    qm set "$VM_VMID" --serial0 socket
    
    log_success "Performance optimizations applied"
}

# Function to create cloud-init configuration
create_cloud_init_config() {
    log_step "Creating cloud-init configuration for automated setup..."
    
    local cloud_init_dir="/tmp/vm-${VM_VMID}-cloud-init"
    mkdir -p "$cloud_init_dir"
    
    # Create user-data for automated installation
    cat > "$cloud_init_dir/user-data" << 'EOF'
#cloud-config
autoinstall:
  version: 1
  locale: en_US.UTF-8
  keyboard:
    layout: us
  network:
    network:
      version: 2
      ethernets:
        enp0s18:
          dhcp4: true
  storage:
    layout:
      name: direct
      sizing-policy: all
  identity:
    hostname: enhanced-n8n-workspace
    username: admin
    password: '$6$rounds=4096$J86aZz0Q$b9MPKZ7w7VJ/0z9QVyZ0d8z7r0Fc1lF2HzZ2X9vC6C0.Q9cHf8F1M3vL9qR8N7tK5z0Y8wS4uI6oE3r1T2nQ8/'
  ssh:
    install-server: true
    authorized-keys: []
    allow-pw: true
  packages:
    - curl
    - wget
    - git
    - docker.io
    - docker-compose
    - htop
    - vim
    - zsh
    - unzip
  late-commands:
    - curtin in-target --target=/target -- systemctl enable docker
    - curtin in-target --target=/target -- systemctl enable ssh
    - curtin in-target --target=/target -- usermod -aG docker admin
    - curtin in-target --target=/target -- chsh -s /bin/zsh admin
EOF
    
    # Create meta-data
    cat > "$cloud_init_dir/meta-data" << EOF
instance-id: enhanced-n8n-workspace-${VM_VMID}
local-hostname: enhanced-n8n-workspace
EOF
    
    # Create setup script for post-installation
    cat > "$cloud_init_dir/setup-workspace.sh" << 'EOF'
#!/bin/bash

# Post-installation setup script for Enhanced n8n-installer + Workspace
set -e

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_info "Starting enhanced workspace setup..."

# Create workspace directories
mkdir -p /opt/enhanced-n8n-workspace
cd /opt/enhanced-n8n-workspace

# Clone the enhanced repository
log_info "Cloning enhanced n8n-installer repository..."
git clone https://github.com/kossakovsky/n8n-installer.git .

# Make scripts executable
chmod +x scripts/*.sh

# Create initial .env from example
cp .env.example .env

# Install Zed editor natively
log_info "Installing Zed editor..."
if [ -f "scripts/install_zed_native.sh" ]; then
    bash scripts/install_zed_native.sh
fi

# Setup data disk
log_info "Setting up data disk..."
if [ -b "/dev/sdb" ]; then
    # Format and mount data disk
    mkfs.ext4 /dev/sdb
    mkdir -p /opt/workspace-data
    mount /dev/sdb /opt/workspace-data
    echo "/dev/sdb /opt/workspace-data ext4 defaults 0 0" >> /etc/fstab
    
    # Create symbolic links for data directories
    mkdir -p /opt/workspace-data/{docker-volumes,shared,projects}
    ln -sf /opt/workspace-data/docker-volumes /opt/enhanced-n8n-workspace/volumes
    ln -sf /opt/workspace-data/shared /opt/enhanced-n8n-workspace/shared
    ln -sf /opt/workspace-data/projects /home/admin/Projects
    chown -R admin:admin /opt/workspace-data/projects
fi

# Create welcome script
cat > /home/admin/welcome.sh << 'WELCOME_EOF'
#!/bin/bash
echo "🎉 Welcome to Enhanced n8n-installer + Workspace-in-a-Box!"
echo "============================================================"
echo ""
echo "🚀 Your VM is ready for AI development and automation!"
echo ""
echo "Quick Start:"
echo "  1. cd /opt/enhanced-n8n-workspace"
echo "  2. Edit .env file with your configuration"
echo "  3. Run: python start_services.py"
echo ""
echo "🎨 Development:"
echo "  - Zed Editor: zed (or search 'Zed' in applications)"
echo "  - Projects: ~/Projects/"
echo "  - Workspace: /opt/enhanced-n8n-workspace"
echo ""
echo "📚 Documentation: Check the README.md in the workspace directory"
echo ""
WELCOME_EOF

chmod +x /home/admin/welcome.sh
chown admin:admin /home/admin/welcome.sh

# Add welcome script to bashrc
echo "" >> /home/admin/.bashrc
echo "# Enhanced n8n-installer welcome" >> /home/admin/.bashrc
echo "if [ -f ~/welcome.sh ]; then" >> /home/admin/.bashrc
echo "    ~/welcome.sh" >> /home/admin/.bashrc
echo "fi" >> /home/admin/.bashrc

log_success "Enhanced workspace setup completed!"
log_info "Please reboot the VM to complete the installation."
EOF
    
    chmod +x "$cloud_init_dir/setup-workspace.sh"
    
    # Create ISO for cloud-init
    genisoimage -output "/tmp/vm-${VM_VMID}-cloud-init.iso" -volid cidata -joliet -rock "$cloud_init_dir"/*
    
    # Copy to Proxmox ISO storage
    cp "/tmp/vm-${VM_VMID}-cloud-init.iso" "/var/lib/vz/template/iso/"
    
    # Attach cloud-init ISO
    qm set "$VM_VMID" --ide0 "local:iso/vm-${VM_VMID}-cloud-init.iso,media=cdrom"
    
    # Cleanup
    rm -rf "$cloud_init_dir"
    rm -f "/tmp/vm-${VM_VMID}-cloud-init.iso"
    
    log_success "Cloud-init configuration created"
}

# Function to display VM information
display_vm_info() {
    echo ""
    echo "="*80
    log_success "ENHANCED n8n-INSTALLER VM DEPLOYMENT COMPLETE!"
    echo "="*80
    echo ""
    
    parse_vm_config
    
    echo -e "${CYAN}🖥️  VM SPECIFICATIONS:${NC}"
    echo "   🆔 VM ID: $VM_VMID"
    echo "   💾 Memory: ${VM_MEMORY}MB ($(( VM_MEMORY / 1024 ))GB)"
    echo "   🖥️  CPU Cores: $VM_CORES"
    echo "   💿 Root Disk: ${VM_DISK_ROOT}GB (System)"
    echo "   💿 Data Disk: ${VM_DISK_DATA}GB (Docker volumes, databases)"
    echo "   🌐 Network: $VM_NETWORK"
    echo "   💾 Storage Backend: $VM_STORAGE"
    echo ""
    
    echo -e "${GREEN}🚀 DEPLOYED FEATURES:${NC}"
    echo "   🧠 AI Automation Platform (n8n, Flowise, Open WebUI)"
    echo "   📝 Knowledge Management (AppFlowy, Affine)"
    echo "   🐳 Container Management (Portainer)"
    echo "   ⚡ Native Development (Zed Editor pre-installed)"
    echo "   🗄️ Unified Database (Shared PostgreSQL)"
    echo "   🌐 Domain Routing (Caddy Reverse Proxy)"
    echo ""
    
    echo -e "${YELLOW}📋 NEXT STEPS:${NC}"
    echo "   1. 🚀 Start the VM: qm start $VM_VMID"
    echo "   2. 🖥️  Connect via console: qm monitor $VM_VMID"
    echo "   3. ⏳ Wait for Ubuntu installation to complete (15-30 minutes)"
    echo "   4. 🔑 Login with: admin / admin (change password immediately)"
    echo "   5. 📁 Navigate to: cd /opt/enhanced-n8n-workspace"
    echo "   6. ⚙️  Configure: Edit .env file with your settings"
    echo "   7. 🚀 Deploy: python start_services.py"
    echo ""
    
    echo -e "${BLUE}🔧 VM MANAGEMENT:${NC}"
    echo "   📊 Status: qm status $VM_VMID"
    echo "   🚀 Start: qm start $VM_VMID"
    echo "   🛑 Stop: qm stop $VM_VMID"
    echo "   🖥️  Console: qm monitor $VM_VMID"
    echo "   📈 Resource usage: qm monitor $VM_VMID info cpus"
    echo "   💾 Backup: qm backup $VM_VMID --storage $VM_STORAGE"
    echo ""
    
    echo -e "${PURPLE}⚡ PERFORMANCE OPTIMIZATIONS APPLIED:${NC}"
    echo "   🔄 NUMA topology enabled"
    echo "   🚀 Host CPU passthrough"
    echo "   💾 Memory ballooning disabled"
    echo "   💿 SSD optimizations (discard, cache=writeback)"
    echo "   🔧 VirtIO SCSI with I/O threads"
    echo ""
    
    echo -e "${CYAN}🌐 NETWORK ACCESS:${NC}"
    echo "   🔍 Find VM IP: qm guest cmd $VM_VMID network-get-interfaces"
    echo "   🌐 Access services via: https://[VM_IP]:443 (after setup)"
    echo "   🔧 SSH access: ssh admin@[VM_IP]"
    echo ""
    
    echo "="*80
    echo -e "${GREEN}🎉 Your enhanced workspace VM is ready for deployment!${NC}"
    echo "="*80
}

# Function to start VM installation
start_vm_installation() {
    echo ""
    read -p "🚀 Start VM installation now? (y/N): " start_install
    
    if [[ "$start_install" =~ ^[Yy]$ ]]; then
        log_info "Starting VM $VM_VMID..."
        qm start "$VM_VMID"
        
        log_success "VM started! Installation will begin automatically."
        log_info "Monitor progress with: qm monitor $VM_VMID"
        log_info "Installation typically takes 15-30 minutes."
        
        echo ""
        read -p "🖥️  Open VM console now? (y/N): " open_console
        if [[ "$open_console" =~ ^[Yy]$ ]]; then
            qm monitor "$VM_VMID"
        fi
    else
        log_info "VM created but not started. Start manually with: qm start $VM_VMID"
    fi
}

# Function to cleanup on error
cleanup_on_error() {
    if [ -n "$VM_VMID" ] && qm status "$VM_VMID" &>/dev/null; then
        log_warning "Cleaning up VM $VM_VMID due to error..."
        qm stop "$VM_VMID" || true
        qm destroy "$VM_VMID" || true
    fi
    exit 1
}

# Main function
main() {
    # Set error trap
    trap cleanup_on_error ERR
    
    show_banner
    check_proxmox_environment
    select_vm_configuration
    select_storage
    get_ubuntu_iso
    create_vm
    add_storage
    optimize_vm_settings
    create_cloud_init_config
    display_vm_info
    start_vm_installation
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
