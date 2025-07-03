#!/bin/bash

# =================================================================
# Combined User-Data Script for Untrusted Scrub Host
# 1. Fixes SSH configuration for custom AMI
# 2. Sets up ALL traffic forwarding to trusted scrub host
# =================================================================

exec > >(tee /var/log/user-data-all.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "--- Starting combined user-data script at $(date) ---"

# --- PART 1: SSH Fix ---
echo "=== PART 1: SSH Configuration Fix ==="

# Wait for cloud-init to complete with timeout
echo "Waiting for cloud-init to complete..."
timeout 300 cloud-init status --wait || {
    echo "WARNING: cloud-init wait timed out after 5 minutes, continuing anyway..."
    echo "Cloud-init status:"
    cloud-init status || echo "Could not get cloud-init status"
}
echo "Cloud-init wait completed or timed out, proceeding..."

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

# --- PART 2: ALL Traffic Forwarding Setup ---
echo "=== PART 2: ALL Traffic Forwarding Setup ==="

# Configuration (Passed from Terraform)
TRUSTED_SCRUB_VPC_CIDR="${trusted_scrub_vpc_cidr}"
AWS_REGION="${aws_region}"
TRUSTED_HOST_TAG_NAME="*trusted-scrub-host*"

echo "Configuration:"
echo "  AWS_REGION: $AWS_REGION"
echo "  TRUSTED_HOST_TAG_NAME: $TRUSTED_HOST_TAG_NAME"
echo "  TRUSTED_SCRUB_VPC_CIDR: $TRUSTED_SCRUB_VPC_CIDR"

# Dynamic IP Discovery Function
discover_trusted_scrub_ip() {
    local max_retries=5
    local retry_delay=15
    local attempt=1
    local trusted_ip=""

    echo "Attempting to discover trusted scrub host IP using AWS CLI..."

    while [ $attempt -le $max_retries ]; do
        echo "Attempt #$attempt of $max_retries..."
        
        # Query AWS for the private IP of the running instance with the specified tag
        trusted_ip=$(aws ec2 describe-instances \
            --region "$AWS_REGION" \
            --filters "Name=tag:Name,Values=$TRUSTED_HOST_TAG_NAME" "Name=instance-state-name,Values=running" \
            --query 'Reservations[].Instances[?PrivateIpAddress!=null].PrivateIpAddress' \
            --output text)

        if [[ -n "$trusted_ip" ]] && [[ "$trusted_ip" != "None" ]]; then
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
    echo "CRITICAL: ALL traffic forwarding cannot be configured. Continuing without it."
else
    echo "Setting up ALL traffic forwarding to -> $TRUSTED_SCRUB_IP"

    # Setup ALL traffic forwarding using iptables
    setup_all_traffic_forwarding() {
        echo "=== Setting up ALL traffic forwarding via iptables ==="
        
        # Enable IP forwarding
        echo "Enabling IP forwarding..."
        echo 1 > /proc/sys/net/ipv4/ip_forward
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        
        # Get the local network interface
        LOCAL_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
        echo "Local interface: $LOCAL_INTERFACE"
        
        # Clear existing forwarding rules (be careful not to break SSH)
        echo "Setting up iptables rules for traffic forwarding..."
        
        # PREROUTING: Redirect all incoming traffic (except SSH) to trusted scrub
        iptables -t nat -A PREROUTING -p tcp ! --dport 22 -j DNAT --to-destination $TRUSTED_SCRUB_IP
        iptables -t nat -A PREROUTING -p udp -j DNAT --to-destination $TRUSTED_SCRUB_IP
        iptables -t nat -A PREROUTING -p icmp -j DNAT --to-destination $TRUSTED_SCRUB_IP
        
        # POSTROUTING: SNAT for outgoing traffic to trusted scrub
        iptables -t nat -A POSTROUTING -d $TRUSTED_SCRUB_IP -j MASQUERADE
        
        # FORWARD: Allow forwarding between interfaces
        iptables -A FORWARD -j ACCEPT
        
        # Allow established and related connections
        iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
        
        echo "iptables rules configured for ALL traffic forwarding."
        
        # Save iptables rules to persist across reboots
        echo "Saving iptables rules..."
        if command -v iptables-save > /dev/null; then
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || iptables-save > /etc/iptables.rules 2>/dev/null || true
        fi
        
        # Install iptables-persistent if available
        if command -v apt-get > /dev/null; then
            echo "Installing iptables-persistent..."
            DEBIAN_FRONTEND=noninteractive apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
        fi
        
        echo "ALL traffic forwarding setup completed."
    }
    
    # Alternative: Check if custom forwarding script exists from AMI
    if [ -f /usr/local/bin/all-traffic-forwarding-setup.sh ]; then
        echo "Found custom forwarding script from AMI, using it..."
        export TRUSTED_SCRUB_IP
        /usr/local/bin/all-traffic-forwarding-setup.sh setup
        echo "SUCCESS: Custom ALL traffic forwarding setup script completed."
    else
        echo "No custom script found, using built-in iptables setup..."
        setup_all_traffic_forwarding
    fi
    
    # Show forwarding status
    echo "--- ALL Traffic Forwarding Configuration Summary ---"
    echo "Forwarding ALL traffic (except SSH on port 22) to: $TRUSTED_SCRUB_IP"
    echo ""
    echo "Current iptables NAT rules:"
    iptables -t nat -L -n --line-numbers
    echo ""
    echo "Current iptables FORWARD rules:"
    iptables -L FORWARD -n --line-numbers
    echo ""
    echo "IP forwarding status:"
    cat /proc/sys/net/ipv4/ip_forward
fi

echo "--- Combined user-data script finished at $(date) ---"

# Final status check
echo "=== Final System Status ==="
echo "SSH Service:"
systemctl status ssh || systemctl status sshd
echo ""
echo "Network interfaces:"
ip addr show
echo ""
echo "SSH listening:"
netstat -tlnp | grep :22 || ss -tlnp | grep :22
echo ""
echo "IP forwarding enabled:"
cat /proc/sys/net/ipv4/ip_forward

exit 0