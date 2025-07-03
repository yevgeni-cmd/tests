#!/bin/bash

# ECR Auto-Login User Data Script
# To be included in existing user-data scripts

exec > >(tee /var/log/ecr-auto-login.log | logger -t ecr-login -s 2>/dev/console) 2>&1

echo "--- Setting up ECR Auto-Login at $(date) ---"

# Configuration
AWS_REGION="${aws_region}"
ECR_REGISTRY="${ecr_registry_url}"

# Function to perform ECR login
ecr_login() {
    echo "Attempting ECR login to $ECR_REGISTRY..."
    
    # Wait for AWS CLI and instance profile to be ready
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

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker service not available after waiting"
    exit 1
fi

# Perform initial ECR login
ecr_login

# Create ECR login script for future use
cat > /usr/local/bin/ecr-login.sh << 'EOF'
#!/bin/bash
AWS_REGION="${aws_region}"
ECR_REGISTRY="${ecr_registry_url}"

echo "$(date): Performing ECR login..."
if aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY; then
    echo "$(date): ECR login successful"
else
    echo "$(date): ECR login failed"
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

# Create systemd timer for periodic ECR login renewal (every 6 hours)
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