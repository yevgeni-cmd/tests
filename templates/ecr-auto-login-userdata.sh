#!/bin/bash

# ECR Auto-Login User Data Script for a non-root user
exec > >(tee /var/log/ecr-auto-login.log | logger -t ecr-login -s 2>/dev/console) 2>&1

echo "--- Setting up ECR Auto-Login for a specific user at $(date) ---"

# --- Configuration ---
# These variables should be replaced by your infrastructure tool (e.g., Terraform, CloudFormation)
AWS_REGION="${aws_region}"
ECR_REGISTRY="${ecr_registry_url}"

# Specify the user who needs to pull Docker images.
# This is typically 'ubuntu' on Ubuntu AMIs or 'ec2-user' on Amazon Linux 2.
TARGET_USER="ubuntu"
TARGET_USER_HOME="/home/$TARGET_USER"

# --- Function to perform ECR login for the TARGET_USER ---
ecr_login() {
    echo "Attempting ECR login to $ECR_REGISTRY for user $TARGET_USER..."

    # Wait for AWS CLI to be ready
    for i in {1..60}; do
        if aws sts get-caller-identity --region $AWS_REGION >/dev/null 2>&1; then
            echo "AWS credentials are now available."
            break
        fi
        echo "Waiting for AWS credentials (attempt $i/60)..."
        sleep 10
    done

    # Ensure the target user's .docker directory exists and has correct ownership
    echo "Configuring Docker directory for user $TARGET_USER at $TARGET_USER_HOME/.docker"
    mkdir -p "$TARGET_USER_HOME/.docker"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_USER_HOME/.docker"

    # Perform ECR login with retry
    for attempt in {1..3}; do
        echo "ECR login attempt $attempt/3 for user $TARGET_USER..."
        # The 'aws' command runs as root to get the password from the instance profile.
        # The 'docker login' command is then run as the TARGET_USER via 'sudo -u'.
        if aws ecr get-login-password --region $AWS_REGION | sudo -u "$TARGET_USER" docker login --username AWS --password-stdin $ECR_REGISTRY; then
            echo "SUCCESS: ECR login for user $TARGET_USER completed."
            return 0
        else
            echo "ECR login attempt $attempt failed. Retrying in 15 seconds..."
            sleep 15
        fi
    done

    echo "ERROR: ECR login failed for user $TARGET_USER after 3 attempts."
    return 1
}

# --- Wait for Docker and add user to the docker group ---
echo "Waiting for Docker service to become active..."
for i in {1..120}; do
    if systemctl is-active --quiet docker && docker info >/dev/null 2>&1; then
        echo "Docker service is ready."
        break
    fi
    if [ $i -eq 1 ]; then
        echo "Ensuring Docker service is started and enabled."
        systemctl start docker
        systemctl enable docker
    fi
    echo "Waiting for Docker to initialize (attempt $i/120)..."
    sleep 5
done

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker service failed to start. Aborting."
    exit 1
fi

# Add the target user to the 'docker' group to allow them to run Docker commands without sudo
echo "Adding user '$TARGET_USER' to the 'docker' group..."
if id "$TARGET_USER" &>/dev/null; then
    usermod -aG docker "$TARGET_USER"
    echo "User '$TARGET_USER' has been added to the 'docker' group."
else
    echo "WARNING: User '$TARGET_USER' not found. Skipping docker group addition."
fi


# --- Perform initial ECR login ---
if ecr_login; then
    echo "Initial ECR login was successful."
else
    echo "Initial ECR login failed. The systemd timer will retry."
fi

# --- Create persistent ECR login script for systemd timer ---
# Note: We use << EOF (without quotes) to allow variable substitution for region and registry.
# Shell variables like $(date) and $attempt are escaped with '\' to be interpreted when the script runs.
echo "Creating renewal script at /usr/local/bin/ecr-login.sh"
cat > /usr/local/bin/ecr-login.sh << EOF
#!/bin/bash
AWS_REGION="${aws_region}"
ECR_REGISTRY="${ecr_registry_url}"
TARGET_USER="ubuntu" # The user to perform the login for
TARGET_USER_HOME="/home/\$TARGET_USER"

echo "\$(date): Running scheduled ECR credential renewal for user \$TARGET_USER..."

# Ensure the user's Docker config directory exists and is owned by them
mkdir -p "\$TARGET_USER_HOME/.docker"
chown -R "\$TARGET_USER:\$TARGET_USER" "\$TARGET_USER_HOME/.docker"

# Perform login with retry
for attempt in {1..3}; do
    if aws ecr get-login-password --region \$AWS_REGION | sudo -u \$TARGET_USER docker login --username AWS --password-stdin \$ECR_REGISTRY; then
        echo "\$(date): ECR login renewal for \$TARGET_USER was successful."
        exit 0
    else
        echo "\$(date): ECR login renewal attempt \$attempt failed."
        if [ \$attempt -lt 3 ]; then
            sleep 10
        fi
    fi
done

echo "\$(date): ECR login renewal for \$TARGET_USER failed after 3 attempts."
exit 1
EOF

chmod +x /usr/local/bin/ecr-login.sh

# --- Create systemd service and timer to refresh login credentials ---
echo "Setting up systemd service and timer for ECR auto-login..."

# The systemd service runs the script. It runs as root because the script
# needs permission to use 'aws' with the instance role and 'sudo'.
cat > /etc/systemd/system/ecr-login.service << 'EOF'
[Unit]
Description=ECR Login Credential Renewal Service
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ecr-login.sh
User=root
RemainAfterExit=yes
EOF

# The systemd timer triggers the service periodically.
cat > /etc/systemd/system/ecr-login.timer << 'EOF'
[Unit]
Description=Timer to periodically renew ECR login credentials
Requires=ecr-login.service

[Timer]
OnBootSec=10min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
EOF

# --- Enable and start the timer ---
systemctl daemon-reload
systemctl enable --now ecr-login.timer

# --- Verify timer status ---
if systemctl is-active --quiet ecr-login.timer; then
    echo "ECR auto-login timer is active and running."
    systemctl status ecr-login.timer --no-pager
else
    echo "WARNING: ECR auto-login timer failed to start."
fi

echo "--- ECR auto-login setup completed at $(date) ---"