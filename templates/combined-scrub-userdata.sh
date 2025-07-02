#!/bin/bash

# =================================================================
# Combined User-Data Script for Untrusted Scrub Host
# 1. Fixes SSH configuration for custom AMI
# 2. Sets up UDP forwarding to trusted scrub host
# =================================================================

exec > >(tee /var/log/user-data-all.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "--- Starting combined user-data script at $(date) ---"

# --- PART 1: SSH Fix ---
echo "=== PART 1: SSH Configuration Fix ==="

# Wait for cloud-init to complete
echo "Waiting for cloud-init to complete..."
cloud-init status --wait
echo "Cloud-init finished."

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

# --- PART 2: UDP Forwarding Setup ---
echo "=== PART 2: UDP Forwarding Setup ==="

# Configuration (Passed from Terraform)
TRUSTED_SCRUB_VPC_CIDR="${trusted_scrub_vpc_cidr}"
UDP_PORT="${udp_port}"
AWS_REGION="${aws_region}"
TRUSTED_HOST_TAG_NAME="*trusted-scrub-host*"

echo "Configuration:"
echo "  UDP_PORT: $UDP_PORT"
echo "  AWS_REGION: $AWS_REGION"
echo "  TRUSTED_HOST_TAG_NAME: $TRUSTED_HOST_TAG_NAME"

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
    echo "CRITICAL: UDP forwarding cannot be configured. Continuing without it."
else
    # Export the variables for the UDP forwarding script
    export TRUSTED_SCRUB_IP
    export UDP_PORT

    echo "Setting up UDP forwarding to -> $TRUSTED_SCRUB_IP:$UDP_PORT"

    # Check if the setup script from the AMI exists and run it
    if [ -f /usr/local/bin/udp-forwarding-setup.sh ]; then
        /usr/local/bin/udp-forwarding-setup.sh setup
        echo "SUCCESS: UDP forwarding setup script completed."
        
        # Show status
        echo "--- UDP Forwarding Configuration Summary ---"
        /usr/local/bin/udp-forwarding-setup.sh status
    else
        echo "WARNING: The setup script '/usr/local/bin/udp-forwarding-setup.sh' was not found in the AMI."
    fi
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

exit 0