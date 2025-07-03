#!/bin/bash

# =================================================================
# Combined User-Data Script for Trusted Scrub Host
# 1. Fixes SSH configuration for custom AMI
# 2. Sets up ALL traffic forwarding to trusted scrub host
# 3. Sets up ECR auto-login
# =================================================================

exec > >(tee /var/log/user-data-all.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "--- Starting combined user-data script at $(date) ---"

# --- PART 1: SSH Fix ---
echo "=== PART 1: SSH Configuration Fix ==="

# Wait for cloud-init to complete with timeout
echo "Waiting for cloud-init to complete (max 5 minutes)..."
timeout 300 cloud-init status --wait || {
    echo "WARNING: cloud-init wait timed out after 5 minutes, continuing anyway..."
    echo "Cloud-init status:"
    cloud-init status || echo "Could not get cloud-init status"
}
echo "Cloud-init wait completed or timed out, proceeding with setup..."

# Ensure system is ready
echo "Waiting for system to be fully ready..."
sleep 30

# Ensure SSH service is running
echo "Checking SSH service status..."
systemctl status ssh || systemctl status sshd

# Start SSH if not running
if ! systemctl is-active --quiet ssh && ! systemctl is-active --quiet sshd; then
    echo "SSH service not running, starting it..."
    systemctl start ssh || systemctl start sshd
    systemctl enable ssh || systemctl enable sshd
fi

# Ensure SSH is configured properly
echo "Ensuring SSH allows key authentication..."
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service to apply any changes
echo "Restarting SSH service..."
systemctl restart ssh || systemctl restart sshd

# Set proper permissions on SSH directory
if [ -d /home/ubuntu/.ssh ]; then
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    chmod 700 /home/ubuntu/.ssh
    chmod 600 /home/ubuntu/.ssh/* 2>/dev/null || true
fi

echo "SSH configuration completed."

# --- PART 2: Traffic Forwarding Setup ---
echo "=== PART 2: Traffic Forwarding Setup ==="

# Configuration (Passed from Terraform)
TRUSTED_SCRUB_VPC_CIDR="${trusted_scrub_vpc_cidr}"
AWS_REGION="${aws_region}"
TRUSTED_HOST_TAG_NAME="*trusted-scrub-host*"

echo "Configuration:"
echo "  AWS_REGION: $AWS_REGION"
echo "  TRUSTED_HOST_TAG_NAME: $TRUSTED_HOST_TAG_NAME"
echo "  TRUSTED_SCRUB_VPC_CIDR: $TRUSTED_SCRUB_VPC_CIDR"

# Wait for AWS CLI to be available
echo "Waiting for AWS CLI to be available..."
for i in {1..30}; do
    if command -v aws >/dev/null 2>&1; then
        echo "AWS CLI is available"
        break
    fi
    echo "Attempt $i/30: AWS CLI not yet available, waiting..."
    sleep 10
done

# Dynamic IP Discovery Function
discover_trusted_scrub_ip() {
    local max_retries=10
    local retry_delay=30
    local attempt=1
    local trusted_ip=""

    echo "Attempting to discover trusted scrub host IP using AWS CLI..."

    while [ $attempt -le $max_retries ]; do
        echo "Attempt #$attempt of $max_retries..."
        
        trusted_ip=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=$TRUSTED_HOST_TAG_NAME" "Name=instance-state-name,Values=running" \
            --query 'Reservations[].Instances[?PrivateIpAddress!=null].PrivateIpAddress' \
            --output text 2>/dev/null)

        if [[ -n "$trusted_ip" ]] && [[ "$trusted_ip" != "None" ]] && [[ "$trusted_ip" != "" ]]; then
            echo "SUCCESS: Discovered trusted scrub IP: $trusted_ip"
            echo "$trusted_ip"
            return 0
        fi

        echo "WARN: Could not find trusted scrub IP on attempt $attempt. Retrying in $retry_delay seconds..."
        sleep $retry_delay
        ((attempt++))
    done

    echo "ERROR: Failed to discover trusted scrub IP after $max_retries attempts."
    return 1
}

# Discover the trusted scrub IP
TRUSTED_SCRUB_IP=$(discover_trusted_scrub_ip)
if [ -z "$TRUSTED_SCRUB_IP" ]; then
    echo "CRITICAL: Traffic forwarding cannot be configured. Trusted scrub IP not found."
else
    echo "Setting up traffic forwarding to -> $TRUSTED_SCRUB_IP"

    # Setup traffic forwarding
    echo "Enabling IP forwarding..."
    echo 1 > /proc/sys/net/ipv4/ip_forward
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    
    # Clear and set up iptables rules
    iptables -t nat -F PREROUTING 2>/dev/null || true
    iptables -t nat -F POSTROUTING 2>/dev/null || true
    iptables -F FORWARD 2>/dev/null || true
    
    # Set policies
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Add forwarding rules
    iptables -t nat -A PREROUTING -p tcp ! --dport 22 -j DNAT --to-destination $TRUSTED_SCRUB_IP
    iptables -t nat -A PREROUTING -p udp -j DNAT --to-destination $TRUSTED_SCRUB_IP
    iptables -t nat -A PREROUTING -p icmp -j DNAT --to-destination $TRUSTED_SCRUB_IP
    iptables -t nat -A POSTROUTING -d $TRUSTED_SCRUB_IP -j MASQUERADE
    iptables -A FORWARD -j ACCEPT
    
    echo "Traffic forwarding setup completed successfully."
fi

# --- PART 3: ECR Auto-Login Setup ---
echo "=== PART 3: ECR Auto-Login Setup ==="

ECR_REGISTRY="${ecr_registry_url}"

# Wait for Docker to be available
echo "Waiting for Docker service..."
for i in {1..60}; do
    if docker info >/dev/null 2>&1; then
        echo "Docker service is ready"
        break
    fi
    echo "Waiting for Docker (attempt $i/60)..."
    sleep 5
done

# Function to perform ECR login
ecr_login() {
    echo "Attempting ECR login to $ECR_REGISTRY..."
    
    # Wait for AWS credentials
    for i in {1..30}; do
        if aws sts get-caller-identity >/dev/null 2>&1; then
            echo "AWS credentials available"
            break
        fi
        echo "Waiting for AWS credentials (attempt $i/30)..."
        sleep 10
    done
    
    # Perform ECR login
    if aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY; then
        echo "SUCCESS: ECR login completed"
        return 0
    else
        echo "ERROR: ECR login failed"
        return 1
    fi
}

# Perform initial ECR login
if docker info >/dev/null 2>&1; then
    ecr_login
    
    # Create ECR login script for future use
    cat > /usr/local/bin/ecr-login.sh << EOF
#!/bin/bash
AWS_REGION="$AWS_REGION"
ECR_REGISTRY="$ECR_REGISTRY"

echo "\$(date): Performing ECR login..."
if aws ecr get-login-password --region \$AWS_REGION | docker login --username AWS --password-stdin \$ECR_REGISTRY; then
    echo "\$(date): ECR login successful"
else
    echo "\$(date): ECR login failed"
    exit 1
fi
EOF
    
    chmod +x /usr/local/bin/ecr-login.sh
    
    # Create systemd service for ECR login
    cat > /etc/systemd/system/ecr-login.service << 'EOF'
[Unit]
Description=ECR Login Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ecr-login.sh
User=root

[Install]
WantedBy=multi-user.target
EOF

    # Create systemd timer for periodic ECR login renewal
    cat > /etc/systemd/system/ecr-login.timer << 'EOF'
[Unit]
Description=ECR Login Timer
Requires=ecr-login.service

[Timer]
OnBootSec=30min
OnUnitActiveSec=6h

[Install]
WantedBy=timers.target
EOF

    # Enable and start the timer
    systemctl daemon-reload
    systemctl enable ecr-login.timer
    systemctl start ecr-login.timer
    
    echo "ECR auto-login setup completed successfully"
else
    echo "WARNING: Docker not available, skipping ECR auto-login setup"
fi

echo "--- Combined user-data script finished at $(date) ---"

# Create completion marker
echo "user-data script completed at $(date)" > /tmp/user-data-completed

exit 0