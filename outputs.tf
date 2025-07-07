# Enhanced outputs for ADO pipeline integration
output "deployment_targets" {
  description = "Deployment targets for ADO pipelines"
  value = {
    untrusted = {
      ingress_host = {
        private_ip   = module.untrusted_ingress_host.private_ip
        public_ip    = module.untrusted_ingress_host.public_ip
        image_repo   = aws_ecr_repository.untrusted_devops.name
        service_name = "media-server"
        environment  = var.environment_tags.untrusted
      }
    }
    trusted = {
      scrub_host = {
        private_ip   = module.trusted_scrub_host.private_ip
        image_repo   = aws_ecr_repository.trusted_devops.name
        service_name = "stream-processor"
        environment  = var.environment_tags.trusted
      }
      streaming_host = {
        private_ip   = module.trusted_streaming_host.private_ip
        image_repo   = aws_ecr_repository.trusted_devops.name
        service_name = "gpu-processor"
        environment  = var.environment_tags.trusted
      }
    }
    devops_agents = {
      trusted = {
        private_ip  = module.trusted_devops_host.private_ip
        public_ip   = module.trusted_devops_host.public_ip
        environment = var.environment_tags.trusted
      }
      untrusted = {
        private_ip  = module.untrusted_devops_host.private_ip
        public_ip   = module.untrusted_devops_host.public_ip
        environment = var.environment_tags.untrusted
      }
    }
  }
}

# ECR configuration for pipelines
output "ecr_configuration" {
  description = "ECR configuration for pipelines"
  value = {
    registry_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.primary_region}.amazonaws.com"
    region = var.primary_region
    repositories = {
      untrusted_devops = aws_ecr_repository.untrusted_devops.name
      trusted_devops   = aws_ecr_repository.trusted_devops.name
    }
  }
}

# ADO pipeline variables (JSON format for easy consumption)
output "ado_pipeline_variables" {
  description = "Variables for ADO pipeline in JSON format"
  value = jsonencode({
    ECR_REGISTRY = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.primary_region}.amazonaws.com"
    AWS_REGION = var.primary_region
    PROJECT_NAME = var.project_name
    
    # Deployment targets
    UNTRUSTED_INGRESS_IP = module.untrusted_ingress_host.private_ip
    UNTRUSTED_INGRESS_PUBLIC_IP = module.untrusted_ingress_host.public_ip
    
    TRUSTED_SCRUB_IP = module.trusted_scrub_host.private_ip
    TRUSTED_STREAMING_IP = module.trusted_streaming_host.private_ip
    
    # Agent IPs for deployment
    TRUSTED_DEVOPS_AGENT_IP = module.trusted_devops_host.private_ip
    UNTRUSTED_DEVOPS_AGENT_IP = module.untrusted_devops_host.private_ip
    
    # Simplified image repositories - both environments use their respective devops repo
    UNTRUSTED_IMAGE_REPO = aws_ecr_repository.untrusted_devops.name
    TRUSTED_IMAGE_REPO = aws_ecr_repository.trusted_devops.name
  })
}

# Automated setup instructions for your existing script
output "ado_setup_instructions" {
  description = "Instructions for setting up ADO pipeline variables using your script"
  value = [
    "=== Automated Setup (Recommended) ===",
    "1. Export Terraform output to JSON:",
    "   terraform output -json > terraform-output.json",
    "",
    "2. Run your automated setup script:",
    "   ./templates/setup-ado-variables.sh terraform-output.json",
    "",
    "3. Configure the script with your ADO details:",
    "   export ADO_ORGANIZATION='https://dev.azure.com/cloudburstnet'",
    "   export ADO_PROJECT='your-project-name'",
    "   export VARIABLE_GROUP_NAME='${var.project_name}-deployment-vars'",
    "",
    "=== Manual Setup (Alternative) ===",
    "1. Copy the JSON from 'ado_pipeline_variables' output above",
    "2. In ADO, go to Pipelines → Library → Variable Groups", 
    "3. Create variable group: '${var.project_name}-deployment-vars'",
    "4. Add each key-value pair from the JSON as pipeline variables",
    "5. Link this variable group to your pipeline",
    "",
    "=== Usage in Pipelines ===",
    "Use variables like: $(ECR_REGISTRY), $(TRUSTED_SCRUB_IP), $(PROJECT_NAME)"
  ]
}

# ADO secrets information (without SSH key references)
output "ado_secrets" {
  description = "ADO-related secret information"
  value = var.enable_ado_agents ? {
    ado_pat_secret_name = aws_secretsmanager_secret.ado_pat[0].name
    setup_instructions = [
      "Update ADO PAT secret:",
      "aws secretsmanager update-secret --secret-id ${aws_secretsmanager_secret.ado_pat[0].name} --secret-string 'YOUR_ADO_PAT_HERE'",
      "",
      "Secrets must be updated before ADO agents can configure successfully"
    ]
    warning = "IMPORTANT: ADO PAT secret contains placeholder value and must be updated manually before deployment"
  } : null
  
  sensitive = false
}

# Untrusted Environment IPs (keeping for compatibility)
output "untrusted_instance_ips" {
  description = "IP addresses for untrusted instances"
  value = {
    ingress_public  = module.untrusted_ingress_host.public_ip
    ingress_private = module.untrusted_ingress_host.private_ip
    scrub_private   = module.untrusted_scrub_host.private_ip
    devops_public   = module.untrusted_devops_host.public_ip 
    devops_private  = module.untrusted_devops_host.private_ip
  }
}

# Trusted Environment IPs (keeping for compatibility)
output "trusted_instance_ips" {
  description = "IP addresses for trusted instances"
  value = {
    scrub_private     = module.trusted_scrub_host.private_ip
    streaming_private = module.trusted_streaming_host.private_ip
    devops_public     = module.trusted_devops_host.public_ip
    devops_private    = module.trusted_devops_host.private_ip
  }
}

# Elastic IP for Untrusted Ingress
output "untrusted_ingress_elastic_ip" {
  description = "Static Elastic IP for untrusted ingress host"
  value       = module.untrusted_ingress_host.public_ip
}

# VPC Peering Connection
output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection between untrusted and trusted scrub"
  value       = aws_vpc_peering_connection.untrusted_to_trusted_scrub.id
}