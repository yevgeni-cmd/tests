#!/bin/bash

# ECR Auto-Login User Data Script - adoagent-aware
# This script sets up a systemd timer to refresh ECR credentials
# specifically for the Azure DevOps agent user.

exec > >(tee /var/log/ecr-auto-login.log | logger -t ecr-login -s 2>/dev/console) 2>&1

echo "--- Setting up ECR Auto-Login for ADO Agent ---"

# --- Configuration ---
# The user that the Azure DevOps agent runs as.
ADO_AGENT_USER="adoagent"
# These values should be replaced by your userdata templating engine (e.g., Terraform)
AWS_REGION="${aws_region}"
ECR_REGISTRY="${ecr_registry_url}"


# --- Script Body ---

# Wait for Docker to be available
echo "Waiting for Docker service to become active..."
for i in {1..60}; do
    if systemctl is-active --quiet docker && docker info >/dev/null 2>&1; then
        echo "✅ Docker service is ready."
        break
    fi
    sleep 5
done
if ! systemctl is-active --quiet docker; then
    echo "❌ ERROR: Docker service did not start in time."
    exit 1
fi

# Create the login script that will be called by the timer
cat > /usr/local/bin/ecr-login-for-ado.sh << EOF
#!/bin/bash
# This script performs the actual login for the specified user.

set -e

ADO_AGENT_USER="$ADO_AGENT_USER"
AWS_REGION="$AWS_REGION"
ECR_REGISTRY="$ECR_REGISTRY"

echo "[\$(date)]--- Starting ECR login for user: \$ADO_AGENT_USER ---"

# Ensure the ADO agent user exists before proceeding
if ! id "\$ADO_AGENT_USER" &>/dev/null; then
    echo "[\$(date)] ❌ ERROR: User '\$ADO_AGENT_USER' does not exist. Cannot perform login."
    exit 1
fi

# THE CORE FIX: Execute the docker login command as the adoagent user.
# This ensures credentials are stored in /home/adoagent/.docker/config.json
echo "[\$(date)] Getting ECR password and logging in as \$ADO_AGENT_USER..."
sudo -u "\$ADO_AGENT_USER" bash -c "aws ecr get-login-password --region \$AWS_REGION | docker login --username AWS --password-stdin \$ECR_REGISTRY"

echo "[\$(date)] ✅ ECR login successful for user: \$ADO_AGENT_USER"
exit 0
EOF

# Make the script executable
chmod +x /usr/local/bin/ecr-login-for-ado.sh

# Create systemd service to run the login script
# This service runs as root, but the script itself switches to the adoagent user.
cat > /etc/systemd/system/ecr-login-ado.service << 'EOF'
[Unit]
Description=ECR Login Service for ADO Agent
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ecr-login-for-ado.sh

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer to run the service every 6 hours
cat > /etc/systemd/system/ecr-login-ado.timer << 'EOF'
[Unit]
Description=Timer to periodically refresh ECR credentials for ADO Agent

[Timer]
OnBootSec=5min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Reload systemd, enable the timer, and perform an initial run
echo "Reloading systemd and starting the timer..."
systemctl daemon-reload
systemctl enable ecr-login-ado.timer
systemctl start ecr-login-ado.timer

# Perform an immediate login so the agent is ready right away
echo "Performing initial login..."
/usr/local/bin/ecr-login-for-ado.sh

echo "--- ECR auto-login setup complete. ---"
