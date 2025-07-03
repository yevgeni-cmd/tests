#!/bin/bash

# =================================================================
# Azure DevOps Agent + ECR + Deployment Setup Script
# Sets up self-hosted ADO agent with deployment capabilities
# =================================================================

exec > >(tee /var/log/ado-agent-setup.log | logger -t ado-agent -s 2>/dev/console) 2>&1

echo "--- Starting ADO Agent setup at $$(date) ---"

# Configuration from Terraform
ADO_ORGANIZATION_URL="${ado_organization_url}"
ADO_AGENT_POOL="${ado_agent_pool_name}"
ADO_PAT_SECRET="${ado_pat_secret_name}"
DEPLOYMENT_SSH_SECRET="${deployment_ssh_key_secret_name}"
AWS_REGION="${aws_region}"
ECR_REGISTRY="${ecr_registry_url}"
ENABLE_AUTO_DEPLOYMENT="${enable_auto_deployment}"
ENVIRONMENT_TYPE="${environment_type}"  # trusted or untrusted

log() {
    echo "[$$(date +'%Y-%m-%d %H:%M:%S')] ADO Setup: $$1"
}

error() {
    echo "[$$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $$1" >&2
}

# --- PART 1: ECR Auto-Login Setup ---
log "Setting up ECR auto-login..."

# Wait for Docker to be available
for i in {1..60}; do
    if docker info >/dev/null 2>&1; then
        log "Docker service is ready"
        break
    fi
    log "Waiting for Docker (attempt $$i/60)..."
    sleep 5
done

# Wait for AWS credentials
for i in {1..30}; do
    if aws sts get-caller-identity >/dev/null 2>&1; then
        log "AWS credentials available"
        break
    fi
    log "Waiting for AWS credentials (attempt $$i/30)..."
    sleep 10
done

# Perform initial ECR login
if docker info >/dev/null 2>&1; then
    log "Performing initial ECR login..."
    if aws ecr get-login-password --region $$AWS_REGION | docker login --username AWS --password-stdin $$ECR_REGISTRY; then
        log "ECR login successful"
    else
        error "ECR login failed"
    fi
    
    # Create ECR login script
    cat > /usr/local/bin/ecr-login.sh << EOF
#!/bin/bash
AWS_REGION="$$AWS_REGION"
ECR_REGISTRY="$$ECR_REGISTRY"

if aws ecr get-login-password --region \$$AWS_REGION | docker login --username AWS --password-stdin \$$ECR_REGISTRY; then
    echo "\$$(date): ECR login successful"
else
    echo "\$$(date): ECR login failed"
    exit 1
fi
EOF
    chmod +x /usr/local/bin/ecr-login.sh
fi

# --- PART 2: ADO Agent Installation ---
if [ "$$ADO_ORGANIZATION_URL" != "" ] && [ "$$ADO_PAT_SECRET" != "" ]; then
    log "Installing Azure DevOps agent..."
    
    # Create agent user
    useradd -m -s /bin/bash adoagent
    usermod -aG docker adoagent
    usermod -aG sudo adoagent
    
    # Allow agent user to sudo without password for deployments
    echo "adoagent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/adoagent
    
    # Create agent directory
    sudo -u adoagent mkdir -p /home/adoagent/agent
    cd /home/adoagent/agent
    
    # Download and extract agent
    log "Downloading ADO agent..."
    AGENT_VERSION=$$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')
    wget -q "https://vstsagentpackage.azureedge.net/agent/$$AGENT_VERSION/vsts-agent-linux-x64-$$AGENT_VERSION.tar.gz"
    sudo -u adoagent tar zxf "vsts-agent-linux-x64-$$AGENT_VERSION.tar.gz"
    rm "vsts-agent-linux-x64-$$AGENT_VERSION.tar.gz"
    
    # Install dependencies
    sudo -u adoagent ./bin/installdependencies.sh
    
    # Get PAT from AWS Secrets Manager
    log "Retrieving ADO PAT from Secrets Manager..."
    ADO_PAT=$$(aws secretsmanager get-secret-value --region $$AWS_REGION --secret-id "$$ADO_PAT_SECRET" --query SecretString --output text)
    
    if [ -n "$$ADO_PAT" ]; then
        log "Configuring ADO agent..."
        
        # Configure agent
        sudo -u adoagent ./config.sh \
            --unattended \
            --url "$$ADO_ORGANIZATION_URL" \
            --auth pat \
            --token "$$ADO_PAT" \
            --pool "$$ADO_AGENT_POOL" \
            --agent "$$(hostname)-$$ENVIRONMENT_TYPE" \
            --acceptTeeEula \
            --work /home/adoagent/agent/_work
        
        # Install as service
        sudo ./svc.sh install adoagent
        sudo ./svc.sh start
        
        log "ADO agent installed and started successfully"
    else
        error "Failed to retrieve ADO PAT from Secrets Manager"
    fi
    
    # --- PART 3: Deployment Tools Setup ---
    if [ "$$ENABLE_AUTO_DEPLOYMENT" = "true" ]; then
        log "Setting up deployment capabilities..."
        
        # Install additional deployment tools
        apt-get update
        apt-get install -y \
            ansible \
            kubectl \
            helm \
            rsync \
            sshpass
        
        # Install Terraform for infrastructure deployments
        wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list
        apt-get update
        apt-get install -y terraform
        
        # Setup deployment SSH key if provided
        if [ "$$DEPLOYMENT_SSH_SECRET" != "" ]; then
            log "Setting up deployment SSH key..."
            
            # Get SSH key from Secrets Manager
            DEPLOYMENT_SSH_KEY=$$(aws secretsmanager get-secret-value --region $$AWS_REGION --secret-id "$$DEPLOYMENT_SSH_SECRET" --query SecretString --output text)
            
            if [ -n "$$DEPLOYMENT_SSH_KEY" ]; then
                # Setup SSH key for agent user
                sudo -u adoagent mkdir -p /home/adoagent/.ssh
                echo "$$DEPLOYMENT_SSH_KEY" | sudo -u adoagent tee /home/adoagent/.ssh/id_rsa
                sudo -u adoagent chmod 600 /home/adoagent/.ssh/id_rsa
                sudo -u adoagent ssh-keygen -y -f /home/adoagent/.ssh/id_rsa | sudo -u adoagent tee /home/adoagent/.ssh/id_rsa.pub
                
                # Create SSH config for deployment targets
                cat > /home/adoagent/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
                sudo chown adoagent:adoagent /home/adoagent/.ssh/config
                sudo chmod 600 /home/adoagent/.ssh/config
                
                log "Deployment SSH key configured successfully"
            else
                error "Failed to retrieve deployment SSH key from Secrets Manager"
            fi
        fi
        
        # Create deployment scripts directory
        sudo -u adoagent mkdir -p /home/adoagent/deployment-scripts
        
        # Create deployment helper scripts
        cat > /home/adoagent/deployment-scripts/deploy-to-host.sh << 'EOF'
#!/bin/bash
# Deployment helper script for ADO pipelines
# Usage: ./deploy-to-host.sh <host-ip> <docker-image> [service-name]

set -e

HOST_IP="$1"
DOCKER_IMAGE="$2"
SERVICE_NAME="${$${3:-app}}"

if [ -z "$HOST_IP" ] || [ -z "$DOCKER_IMAGE" ]; then
    echo "Usage: $0 <host-ip> <docker-image> [service-name]"
    exit 1
fi

echo "Deploying $DOCKER_IMAGE to $HOST_IP..."

# ECR login on target host
ssh ubuntu@$HOST_IP "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

# Pull and run new image
ssh ubuntu@$HOST_IP "docker pull $DOCKER_IMAGE && docker stop $SERVICE_NAME || true && docker rm $SERVICE_NAME || true"
ssh ubuntu@$HOST_IP "docker run -d --name $SERVICE_NAME --restart unless-stopped $DOCKER_IMAGE"

echo "Deployment to $HOST_IP completed successfully"
EOF
        
        sudo chown adoagent:adoagent /home/adoagent/deployment-scripts/deploy-to-host.sh
        sudo chmod +x /home/adoagent/deployment-scripts/deploy-to-host.sh
        
        log "Deployment tools configured successfully"
    fi
    
    # Create useful aliases for agent user
    cat >> /home/adoagent/.bashrc << 'EOF'
# ADO Agent aliases
alias docker-login='aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY'
alias agent-status='sudo systemctl status vsts.agent.*'
alias agent-logs='sudo journalctl -u vsts.agent.* -f'
alias tf='terraform'
alias k='kubectl'
EOF
    
else
    log "ADO agent configuration skipped (missing organization URL or PAT secret)"
fi

# --- PART 4: Create System Services ---
# Create ECR login timer service
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

# Enable services
systemctl daemon-reload
systemctl enable ecr-login.timer
systemctl start ecr-login.timer

log "ADO Agent and deployment setup completed successfully"

# Create completion marker
echo "ado-agent setup completed at $$(date)" > /tmp/ado-agent-completed

exit 0