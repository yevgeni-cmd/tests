#!/bin/bash

# =================================================================
# Custom AMI Setup Script (Fixed Version for SSH Reboot & Build Types)
# This script prepares Ubuntu 24.04 with Docker and required tools
# Run this on a base Ubuntu 24.04 instance to create your custom AMI
# =================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] AMI Setup: $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] SUCCESS: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}" >&2
}

# Update system
update_system() {
    log "Updating system packages..."
    apt-get update
    apt-get upgrade -y
    success "System updated"
}

# Install essential packages
install_packages() {
    log "Installing essential packages..."
    # Pre-configure iptables-persistent to auto-save rules without prompting
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

    apt-get install -y \
        curl \
        wget \
        git \
        vim \
        htop \
        net-tools \
        netcat-openbsd \
        tcpdump \
        nmap \
        iptables \
        iptables-persistent \
        netfilter-persistent \
        socat \
        jq \
        unzip \
        python3 \
        python3-pip \
        ca-certificates \
        gnupg \
        lsb-release
    
    success "Essential packages installed"
}

# Setup base firewall rules, including SSH access
setup_firewall() {
    log "Setting up base firewall rules..."
    
    # Allow all incoming traffic on the loopback interface
    iptables -A INPUT -i lo -j ACCEPT
    
    # Allow all established and related incoming connections
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # CRITICAL: Allow incoming SSH connections on port 22
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # Save the rules to make them persistent across reboots
    log "Saving iptables rules..."
    netfilter-persistent save
    
    success "Base firewall rules configured to allow SSH"
}


# Install NVIDIA drivers and GPU tools (for GPU AMI variant)
install_nvidia_gpu_support() {
    log "Installing NVIDIA drivers and GPU support..."
    
    # Add NVIDIA package repository
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.0-1_all.deb
    dpkg -i cuda-keyring_1.0-1_all.deb
    apt-get update
    
    # Install NVIDIA driver
    apt-get install -y ubuntu-drivers-common
    ubuntu-drivers autoinstall
    
    # Install CUDA toolkit (for development)
    apt-get install -y cuda-toolkit-12-2
    
    # Install NVIDIA Container Toolkit for Docker
    distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    apt-get update
    apt-get install -y nvidia-container-toolkit
    
    # Configure Docker to use NVIDIA runtime
    nvidia-ctk runtime configure --runtime=docker
    
    # Create Docker daemon configuration for GPU
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
    "default-runtime": "nvidia",
    "runtimes": {
        "nvidia": {
            "path": "nvidia-container-runtime",
            "runtimeArgs": []
        }
    }
}
EOF
    
    success "NVIDIA GPU support installed"
}
install_docker() {
    log "Installing Docker..."
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index
    apt-get update
    
    # Install Docker
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add ubuntu user to docker group
    usermod -aG docker ubuntu
    
    # Enable Docker service
    systemctl enable docker
    systemctl start docker
    
    success "Docker installed and configured"
}

# Install AWS CLI v2
install_aws_cli() {
    log "Installing AWS CLI v2..."
    
    cd /tmp
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf aws awscliv2.zip
    
    success "AWS CLI v2 installed"
}

# Create UDP forwarding script
create_udp_script() {
    log "Creating UDP forwarding script..."
    
    # *** THE FIX: This script is now non-destructive. It only adds rules and does NOT save them,
    # preserving the base firewall rules (like SSH) that were saved during AMI creation.
    cat > /usr/local/bin/udp-forwarding-setup.sh << 'SCRIPT_EOF'
#!/bin/bash
# UDP Forwarding Setup Script for Untrusted Scrub Host
set -e

# Configuration - These will be overridden by exported environment variables from user-data
TRUSTED_SCRUB_IP="${TRUSTED_SCRUB_IP:-172.16.13.21}"
UDP_PORT="${UDP_PORT:-8090}"
SCRIPT_NAME="UDP Forwarding Setup"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ${SCRIPT_NAME}: $1"; }

setup_iptables_rules() {
    log "Appending iptables NAT rules for $TRUSTED_SCRUB_IP:$UDP_PORT..."
    # Use -I (insert) to add rules to the top to ensure they are processed before any potential DROP rules.
    iptables -t nat -I PREROUTING 1 -p udp --dport $UDP_PORT -j DNAT --to-destination $TRUSTED_SCRUB_IP:$UDP_PORT
    iptables -t nat -I POSTROUTING 1 -p udp -d $TRUSTED_SCRUB_IP --dport $UDP_PORT -j MASQUERADE
    iptables -I FORWARD 1 -p udp --sport $UDP_PORT -s $TRUSTED_SCRUB_IP -j ACCEPT
    iptables -I FORWARD 1 -p udp --dport $UDP_PORT -d $TRUSTED_SCRUB_IP -j ACCEPT
}

# This function is intentionally left simple. We do NOT save the rules here.
# The base rules are already persistent from the AMI build. These new rules
# only need to exist for the current life of the instance. If it reboots,
# user-data will run again and re-add them.
setup() {
    log "Starting UDP forwarding setup..."
    setup_iptables_rules
    log "UDP forwarding rules have been added to the current session."
}

status() {
    echo "--- UDP Forwarding Status ---";
    echo "Target: $TRUSTED_SCRUB_IP:$UDP_PORT";
    echo "IP Forwarding: $(cat /proc/sys/net/ipv4/ip_forward)";
    echo -e "\nNAT Rules:";
    iptables -t nat -L PREROUTING -n --line-numbers | grep "dpt:$UDP_PORT" || echo "  No DNAT rule found";
    echo -e "\nFORWARD Rules:";
    iptables -L FORWARD -n --line-numbers | grep "dpt:$UDP_PORT" || echo "  No FORWARD rule found";
}

case "$1" in
    setup|"") setup ;;
    status) status ;;
    *) echo "Usage: $0 {setup|status}" ;;
esac
SCRIPT_EOF
    
    chmod +x /usr/local/bin/udp-forwarding-setup.sh
    success "UDP forwarding script created"
}

# Configure system settings
configure_system() {
    log "Configuring system settings..."
    
    # Enable IP forwarding by default
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
    fi
    success "System configured"
}

# Create GPU-specific utilities and monitoring tools
create_gpu_utilities() {
    log "Creating GPU utilities and monitoring tools..."
    
    # GPU status script
    cat > /usr/local/bin/gpu-status.sh << 'EOF'
#!/bin/bash
echo "=== GPU Hardware Information ==="
lspci | grep -i nvidia || echo "No NVIDIA GPUs detected"

echo ""
echo "=== NVIDIA Driver Status ==="
if command -v nvidia-smi >/dev/null 2>&1; then
    nvidia-smi
else
    echo "nvidia-smi not available"
fi

echo ""
echo "=== Docker GPU Integration ==="
if docker run --rm --gpus all nvidia/cuda:11.0-base nvidia-smi 2>/dev/null; then
    echo "✅ Docker GPU integration working"
else
    echo "❌ Docker GPU integration not working"
fi
EOF
    
    chmod +x /usr/local/bin/gpu-status.sh
    success "GPU utilities created"
}

# Create general utility scripts and aliases
create_utilities() {
    log "Creating utility scripts..."
    
    # Create useful aliases for ubuntu user
    cat >> /home/ubuntu/.bashrc << 'EOF'

# Custom aliases for networking
alias ipt='sudo iptables -t nat -L -n -v'
alias iptf='sudo iptables -L FORWARD -n -v'
alias listen='sudo netstat -tulpn | grep LISTEN'
alias udp='sudo netstat -ulpn'
alias fw-setup='sudo /usr/local/bin/udp-forwarding-setup.sh'
alias fw-status='/usr/local/bin/udp-forwarding-setup.sh status'
EOF
    
    # Create Docker aliases
    cat >> /home/ubuntu/.bashrc << 'EOF'
alias dps='docker ps'
alias dimg='docker images'
alias dlog='docker logs'
alias dexec='docker exec -it'
EOF
    
    success "Utilities created"
}

# Clean up for AMI creation
cleanup() {
    log "Cleaning up system for AMI creation..."
    
    # Stop logging services to prevent writing to logs after cleanup
    service rsyslog stop || true
    
    # Clear apt cache and autoremove packages
    apt-get autoremove -y
    apt-get clean
    
    # Clear cloud-init cache and logs
    log "Cleaning cloud-init..."
    rm -rf /var/lib/cloud-init/instances/*
    rm -rf /var/lib/cloud-init/instance
    rm -rf /var/lib/cloud-init/data/*
    rm -rf /var/lib/cloud-init/sem/*
    find /var/log/ -name "cloud-init*.log" -exec rm -f {} \;
    
    # Clear shell history
    log "Clearing shell history..."
    unset HISTFILE
    history -c
    rm -f /root/.bash_history
    rm -f /home/ubuntu/.bash_history
    
    # *** THE FIX: This correctly removes the current host keys AND ensures the key-generation
    # service is properly configured to run on the next boot, fixing the SSH reboot issue.
    log "Reconfiguring OpenSSH Server to clear host keys and ensure regeneration..."
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure openssh-server

    # Clear the machine-id
    log "Clearing machine-id..."
    if [ -f /etc/machine-id ]; then
        truncate -s 0 /etc/machine-id
    fi
    
    # Clear temporary files and logs
    log "Clearing temporary files and logs..."
    rm -rf /tmp/*
    rm -rf /var/tmp/*
    find /var/log -type f -exec truncate --size=0 {} \;
    
    success "System cleaned and sanitized for AMI creation"
}


# Main execution
main() {
    log "Starting custom AMI setup for Ubuntu 24.04..."
    
    # *** IMPROVEMENT: Check if a build type was provided. Exit if not. ***
    if [ -z "$1" ]; then
        error "No build type specified. You must provide 'standard' or 'gpu' as an argument."
        echo "Usage: sudo bash $0 [standard|gpu]"
        exit 1
    fi
    
    # Set the build type from the first argument.
    BUILD_TYPE="$1"
    
    case "$BUILD_TYPE" in
        "gpu")
            log "Building GPU-enabled AMI..."
            update_system
            install_packages
            setup_firewall
            install_docker
            install_nvidia_gpu_support
            install_aws_cli
            create_udp_script
            create_gpu_utilities
            create_utilities
            configure_system
            cleanup
            success "GPU-enabled custom AMI setup completed!"
            ;;
        "standard")
            log "Building standard AMI..."
            update_system
            install_packages
            setup_firewall
            install_docker
            install_aws_cli
            create_udp_script
            create_utilities
            configure_system
            cleanup
            success "Standard custom AMI setup completed!"
            ;;
        *)
            error "Unknown build type: '$BUILD_TYPE'. Use 'standard' or 'gpu'."
            echo "Usage: sudo bash $0 [standard|gpu]"
            exit 1
            ;;
    esac
    
    echo ""
    echo "=== AMI Setup Complete ==="
    echo "The system has been cleaned and sanitized for a '$BUILD_TYPE' build."
    echo "You should now shut down this instance and create an AMI from it."
    echo "Run: sudo shutdown now"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use 'sudo bash $0 [standard|gpu]')"
    exit 1
fi

main "$@"
