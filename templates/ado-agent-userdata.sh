# ... (inside ado-agent-userdata.sh)

        # Create deployment helper scripts
        cat > /home/adoagent/deployment-scripts/deploy-to-host.sh << 'EOF'
#!/bin/bash
# Deployment helper script for ADO pipelines
# Usage: ./deploy-to-host.sh <host-ip> <docker-image> [service-name]

set -e

HOST_IP="$1"
DOCKER_IMAGE="$2"
# CORRECTED LINE: Using $${3:-app} to escape the variable for Terraform
SERVICE_NAME="$${3:-app}"

if [ -z "$HOST_IP" ] || [ -z "$DOCKER_IMAGE" ]; then
    echo "Usage: $0 <host-ip> <docker-image> [service-name]"
    exit 1
fi

echo "Deploying $DOCKER_IMAGE to $HOST_IP..."

# ECR login on target host
# Note: Ensure AWS_REGION and ECR_REGISTRY are available on the target host's environment
ssh ubuntu@$HOST_IP "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY"

# Pull and run new image
ssh ubuntu@$HOST_IP "docker pull $DOCKER_IMAGE && docker stop $SERVICE_NAME || true && docker rm $SERVICE_NAME || true"
ssh ubuntu@$HOST_IP "docker run -d --name $SERVICE_NAME --restart unless-stopped $DOCKER_IMAGE"

echo "Deployment to $HOST_IP completed successfully"
EOF