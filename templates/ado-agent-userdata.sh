#!/bin/bash

# =================================================================
# Azure DevOps Agent Setup Script
# Installs and configures ADO self-hosted agent with ECR access
# =================================================================

exec > >(tee /var/log/ado-agent-setup.log | logger -t ado-setup -s 2>/dev/console) 2>&1

echo "--- Starting ADO Agent Setup at $$(date) ---"

# Configuration from Terraform
AWS_REGION="${aws_region}"
ECR_REGISTRY="${ecr_registry_url}"
ADO_ORGANIZATION_URL="${ado_organization_url}"
ADO_AGENT_POOL="${ado_agent_pool_name}"
ADO_PAT_SECRET="${ado_pat_secret_name}"
ENVIRONMENT_TYPE="${environment_type}"

echo "Configuration:"
echo "  AWS_REGION: $$AWS_REGION"
echo "  ECR_REGISTRY: $$ECR_REGISTRY"
echo "  ADO_ORGANIZATION: $$ADO_ORGANIZATION_URL"
echo "  AGENT_POOL: $$ADO_AGENT_POOL"
echo "  ENVIRONMENT: $$ENVIRONMENT_TYPE"

# Wait for system to be ready
echo "Waiting for system initialization..."
sleep 30

# Verify Docker and AWS CLI (already installed via custom AMI)
echo "=== Verifying Prerequisites ==="
docker --version || { echo "ERROR: Docker not found in custom AMI"; exit 1; }
aws --version || { echo "ERROR: AWS CLI not found in custom AMI"; exit 1; }

# Ensure Docker service is running
systemctl start docker
systemctl enable docker

# Install additional packages needed for ADO agent
echo "=== Installing Additional Packages ==="
apt-get update -y
apt-get install -y jq curl wget

# Create ADO agent user
echo "=== Creating ADO Agent User ==="
useradd -m -s /bin/bash adoagent
usermod -aG docker adoagent

# Give adoagent sudo access for service management
echo "adoagent ALL=(ALL) NOPASSWD: /home/adoagent/agent/svc.sh" > /etc/sudoers.d/adoagent
chmod 440 /etc/sudoers.d/adoagent

# Create agent directory
mkdir -p /home/adoagent/agent
chown -R adoagent:adoagent /home/adoagent
chmod 755 /home/adoagent/agent  # Allow others to access for service installation

# Wait for AWS credentials to be available
echo "=== Waiting for AWS Credentials ==="
for i in {1..30}; do
    if aws sts get-caller-identity >/dev/null 2>&1; then
        echo "AWS credentials are available"
        break
    fi
    echo "Waiting for AWS credentials (attempt $$i/30)..."
    sleep 10
done

# Get ADO PAT from Secrets Manager
echo "=== Retrieving ADO PAT ==="
ADO_PAT=""
for i in {1..10}; do
    echo "Attempting to retrieve ADO PAT (attempt $$i/10)..."
    ADO_PAT=$$(aws secretsmanager get-secret-value --secret-id "$$ADO_PAT_SECRET" --query SecretString --output text 2>/dev/null)
    if [ -n "$$ADO_PAT" ] && [ "$$ADO_PAT" != "PLACEHOLDER_SET_YOUR_ADO_PAT_HERE" ]; then
        echo "ADO PAT retrieved successfully"
        break
    fi
    echo "PAT not ready, waiting 30 seconds..."
    sleep 30
done

if [ -z "$$ADO_PAT" ] || [ "$$ADO_PAT" = "PLACEHOLDER_SET_YOUR_ADO_PAT_HERE" ]; then
    echo "ERROR: Could not retrieve valid ADO PAT from Secrets Manager"
    echo "Please update the secret: aws secretsmanager update-secret --secret-id $$ADO_PAT_SECRET --secret-string 'YOUR_PAT_HERE'"
    exit 1
fi

# Download and extract ADO agent
echo "=== Downloading ADO Agent ==="
cd /home/adoagent/agent

# Use Microsoft's official ADO agent download URL
# Get latest version from API, but use Microsoft download URL
LATEST_VERSION=$$(curl -s https://api.github.com/repos/Microsoft/azure-pipelines-agent/releases/latest | jq -r '.tag_name' | sed 's/v//' 2>/dev/null)
if [ -z "$$LATEST_VERSION" ] || [ "$$LATEST_VERSION" = "null" ]; then
    echo "Failed to get latest version, using known working version 4.258.1"
    LATEST_VERSION="4.258.1"
fi

echo "Downloading ADO agent version: $$LATEST_VERSION"

# Use Microsoft's official download URL
DOWNLOAD_URL="https://download.agent.dev.azure.com/agent/$${LATEST_VERSION}/vsts-agent-linux-x64-$${LATEST_VERSION}.tar.gz"
echo "Download URL: $$DOWNLOAD_URL"

curl -L "$$DOWNLOAD_URL" -o agent.tar.gz

if [ ! -f agent.tar.gz ]; then
    echo "ERROR: Failed to download ADO agent from Microsoft"
    exit 1
fi

# Verify the download is a valid archive
if ! file agent.tar.gz | grep -q "gzip compressed"; then
    echo "ERROR: Downloaded file is not a valid gzip archive"
    echo "File type: $$(file agent.tar.gz)"
    exit 1
fi

if [ ! -f agent.tar.gz ]; then
    echo "ERROR: Failed to download ADO agent"
    exit 1
fi

tar xzf agent.tar.gz
rm agent.tar.gz

# Set permissions
chown -R adoagent:adoagent /home/adoagent/agent

# Configure agent
echo "=== Configuring ADO Agent ==="
AGENT_NAME="$${ENVIRONMENT_TYPE}-devops-agent-$$(hostname -s)"

# Run agent configuration as adoagent user
sudo -u adoagent bash << EOF
cd /home/adoagent/agent
./config.sh \\
    --unattended \\
    --url "$$ADO_ORGANIZATION_URL" \\
    --auth pat \\
    --token "$$ADO_PAT" \\
    --pool "$$ADO_AGENT_POOL" \\
    --agent "$$AGENT_NAME" \\
    --work /home/adoagent/agent/_work \\
    --addcapability "environment_type=$$ENVIRONMENT_TYPE" \\
    --addcapability "aws_region=$$AWS_REGION" \\
    --addcapability "ecr_registry=$$ECR_REGISTRY" \\
    --acceptTeeEula
EOF

if [ $$? -ne 0 ]; then
    echo "ERROR: Agent configuration failed"
    exit 1
fi

# Install agent as service
echo "=== Installing ADO Agent Service ==="
# Run service installation as root to avoid permission issues
sudo -i bash << 'ROOT_INSTALL'
cd /home/adoagent/agent
./svc.sh install adoagent
./svc.sh start
ROOT_INSTALL

# Verify service is running
sleep 5
systemctl status vsts.agent.* --no-pager || echo "Service status check failed"

# Setup ECR auto-login (use existing ECR login from custom AMI)
echo "=== Setting up ECR Auto-Login ==="
sudo -u adoagent bash << EOF
# Test ECR login using existing setup
if aws ecr get-login-password --region $$AWS_REGION | docker login --username AWS --password-stdin $$ECR_REGISTRY; then
    echo "ECR login successful using custom AMI setup"
else
    echo "WARNING: ECR login failed"
fi
EOF

# ECR login should already be configured via custom AMI ECR auto-login setup

# Final verification
echo "=== Final Verification ==="
echo "ADO Agent Status:"
systemctl status vsts.agent.* --no-pager

echo "Docker Status:"
docker --version
sudo -u adoagent docker ps

echo "AWS CLI Status:"
aws --version
aws sts get-caller-identity

echo "Agent Configuration:"
cat /home/adoagent/agent/.agent

echo "--- ADO Agent Setup Completed at $$(date) ---"