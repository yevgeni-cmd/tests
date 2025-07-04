# Enhanced outputs for ADO pipeline integration
output "deployment_targets" {
  description = "Deployment targets for ADO pipelines"
  value = {
    untrusted = {
      ingress_host = {
        private_ip = module.untrusted_ingress_host.private_ip
        public_ip  = module.untrusted_ingress_host.public_ip
        image_repo = "poc/untrusted-devops-images"
        service_name = "media-server"
        environment = "untrusted"
      }
      # Note: Scrub host not included as it only forwards traffic
    }
    trusted = {
      scrub_host = {
        private_ip = module.trusted_scrub_host.private_ip
        image_repo = "poc/trusted-streaming-images"
        service_name = "stream-processor"
        environment = "trusted"
      }
      streaming_host = {
        private_ip = module.trusted_streaming_host.private_ip
        image_repo = "poc/trusted-streaming-images"
        service_name = "gpu-processor"
        environment = "trusted"
      }
    }
    devops_agents = {
      trusted = {
        private_ip = module.trusted_devops_host.private_ip
        public_ip = module.trusted_devops_host.public_ip
        environment = "trusted"
      }
      untrusted = {
        private_ip = module.untrusted_devops_host.private_ip
        public_ip = module.untrusted_devops_host.public_ip
        environment = "untrusted"
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
      untrusted_devops = "${var.project_name}/untrusted-devops-images"
      trusted_devops = "${var.project_name}/trusted-devops-images"
      trusted_streaming = "${var.project_name}/trusted-streaming-images"
      trusted_iot = "${var.project_name}/trusted-iot-services"
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
    
    # Image repositories
    UNTRUSTED_IMAGE_REPO = "${var.project_name}/untrusted-devops-images"
    TRUSTED_IMAGE_REPO = "${var.project_name}/trusted-streaming-images"
  })
}

# Manual setup instructions
output "ado_setup_instructions" {
  description = "Instructions for setting up ADO pipeline variables"
  value = [
    "1. Copy the JSON from 'ado_pipeline_variables' output",
    "2. In ADO, go to Pipelines → Library → Variable Groups",
    "3. Create variable group: '${var.project_name}-deployment-vars'",
    "4. Add each key-value pair from the JSON as pipeline variables",
    "5. Link this variable group to your pipeline",
    "6. Use variables in pipeline: $(ECR_REGISTRY), $(TRUSTED_SCRUB_IP), etc."
  ]
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