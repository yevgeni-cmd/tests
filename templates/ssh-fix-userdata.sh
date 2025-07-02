#!/bin/bash

# =================================================================
# SSH Fix User-Data Script
# Ensures SSH is properly configured on custom AMI instances
# =================================================================

exec > >(tee /var/log/ssh-fix-userdata.log | logger -t ssh-fix -s 2>/dev/console) 2>&1

echo "--- Starting SSH fix user-data script at $(date) ---"

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

# Check SSH configuration
echo "Checking SSH configuration..."
grep -E "^PermitRootLogin|^PasswordAuthentication|^PubkeyAuthentication" /etc/ssh/sshd_config || true

# Ensure SSH is configured properly
echo "Ensuring SSH allows key authentication..."
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/PubkeyAuthentication no/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service to apply any changes
echo "Restarting SSH service..."
systemctl restart ssh || systemctl restart sshd

# Verify SSH is listening
echo "Verifying SSH is listening on port 22..."
netstat -tlnp | grep :22 || ss -tlnp | grep :22

# Check ubuntu user exists and has proper home directory
echo "Checking ubuntu user configuration..."
id ubuntu || echo "Ubuntu user not found!"
ls -la /home/ubuntu/.ssh/ || echo "SSH directory not found for ubuntu user"

# Set proper permissions on SSH directory
if [ -d /home/ubuntu/.ssh ]; then
    chown -R ubuntu:ubuntu /home/ubuntu/.ssh
    chmod 700 /home/ubuntu/.ssh
    chmod 600 /home/ubuntu/.ssh/* 2>/dev/null || true
fi

# Log final status
echo "--- SSH fix user-data script completed at $(date) ---"
systemctl status ssh || systemctl status sshd