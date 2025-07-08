# Enhanced outputs for ADO pipeline integration
output "deployment_targets" {
  description = "Deployment targets for ADO pipelines"
  value = {
    untrusted = {
      ingress_host = {
        private_ip   = module.untrusted_ingress_host.private_ip
        public_ip    = aws_eip.untrusted_ingress.public_ip  # Use EIP instead
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
    UNTRUSTED_INGRESS_PUBLIC_IP = aws_eip.untrusted_ingress.public_ip  # Use EIP instead
    
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
    ingress_public  = aws_eip.untrusted_ingress.public_ip  # Use EIP instead
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
  value       = aws_eip.untrusted_ingress.public_ip  # Use EIP instead
}

# VPC Peering Connection
output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection between untrusted and trusted scrub"
  value       = aws_vpc_peering_connection.untrusted_to_trusted_scrub.id
}
#-----------------------------
#neeeeeew
#------------------------------
# IoT Infrastructure Outputs
output "iot_infrastructure" {
  description = "IoT infrastructure deployment information"
  value = {
    rds_endpoint = module.iot_rds_database.db_instance_endpoint
    alb_dns_name = module.iot_application_load_balancer.alb_dns_name
    ecs_cluster_name = module.iot_ecs_cluster.cluster_name
    sqs_queue_url = module.jacob_sqs_queues.queue_url
    
    # Service URLs for VPN clients
    api_url = "http://${module.iot_application_load_balancer.alb_dns_name}/api"
    dashboard_url = "http://${module.iot_application_load_balancer.alb_dns_name}/"
    
    # Database connection info (for applications)
    database_secret_arn = module.iot_rds_database.master_user_secret_arn
  }
}

# Jacob SQS Queue Information
output "jacob_messaging" {
  description = "Jacob messaging configuration"
  value = {
    message_queue_url = module.jacob_sqs_queues.queue_url
    response_queue_url = module.jacob_response_sqs_queue.queue_url
    queue_region = var.primary_region
    
    # For application configuration
    sqs_queues = {
      messages = {
        name = module.jacob_sqs_queues.queue_name
        arn = module.jacob_sqs_queues.queue_arn
        url = module.jacob_sqs_queues.queue_url
      }
      responses = {
        name = module.jacob_response_sqs_queue.queue_name
        arn = module.jacob_response_sqs_queue.queue_arn
        url = module.jacob_response_sqs_queue.queue_url
      }
    }
  }
}

# Enhanced deployment targets that extend existing ones
output "iot_deployment_targets" {
  description = "IoT services deployment targets for CI/CD"
  value = {
    iot_services = {
      api_service = {
        cluster_name = module.iot_ecs_cluster.cluster_name
        service_name = aws_ecs_service.iot_api.name
        task_definition = aws_ecs_task_definition.iot_api.family
        environment = var.environment_tags.trusted
        alb_endpoint = module.iot_application_load_balancer.alb_dns_name
        target_group_arn = module.iot_application_load_balancer.target_group_arns["iot_api"]
      }
      dashboard_service = {
        cluster_name = module.iot_ecs_cluster.cluster_name
        service_name = aws_ecs_service.iot_dashboard.name
        task_definition = aws_ecs_task_definition.iot_dashboard.family
        environment = var.environment_tags.trusted
        alb_endpoint = module.iot_application_load_balancer.alb_dns_name
        target_group_arn = module.iot_application_load_balancer.target_group_arns["iot_dashboard"]
      }
    }
    database = {
      endpoint = module.iot_rds_database.db_instance_endpoint
      port = module.iot_rds_database.db_instance_port
      secret_arn = module.iot_rds_database.master_user_secret_arn
    }
    messaging = {
      jacob_queue_url = module.jacob_sqs_queues.queue_url
      response_queue_url = module.jacob_response_sqs_queue.queue_url
    }
  }
}

# ECS Cluster Information
output "iot_ecs_cluster_info" {
  description = "ECS cluster information for deployment"
  value = {
    cluster_arn = module.iot_ecs_cluster.cluster_arn
    cluster_name = module.iot_ecs_cluster.cluster_name
    execution_role_arn = module.iot_ecs_cluster.execution_role_arn
    task_role_arn = module.iot_ecs_cluster.task_role_arn
    log_group_name = module.iot_ecs_cluster.log_group_name
  }
}

# Load Balancer Information
output "iot_alb_info" {
  description = "Application Load Balancer information"
  value = {
    alb_arn = module.iot_application_load_balancer.alb_arn
    alb_dns_name = module.iot_application_load_balancer.alb_dns_name
    alb_zone_id = module.iot_application_load_balancer.alb_zone_id
    target_groups = module.iot_application_load_balancer.target_group_arns
  }
}



# Streaming Infrastructure Outputs
output "streaming_infrastructure" {
  description = "Streaming infrastructure deployment information"
  value = {
    # Database and cluster info
    rds_endpoint = module.streaming_rds_database.db_instance_endpoint
    alb_dns_name = module.streaming_application_load_balancer.alb_dns_name
    ecs_cluster_name = module.streaming_ecs_cluster.cluster_name
    
    # Queue URLs for application configuration
    video_queue_url = module.streaming_video_queue.queue_url
    transcoding_queue_url = module.streaming_transcoding_queue.queue_url
    analytics_queue_url = module.streaming_analytics_queue.queue_url
    
    # Service URLs for VPN clients
    streaming_api_url = "http://${module.streaming_application_load_balancer.alb_dns_name}/api"
    streaming_control_url = "http://${module.streaming_application_load_balancer.alb_dns_name}/control"
    streaming_player_url = "http://${module.streaming_application_load_balancer.alb_dns_name}/player"
    
    # RTMP and HLS endpoints
    rtmp_endpoint = "rtmp://${module.streaming_application_load_balancer.alb_dns_name}/live"
    hls_endpoint = "http://${module.streaming_application_load_balancer.alb_dns_name}/hls"
    dash_endpoint = "http://${module.streaming_application_load_balancer.alb_dns_name}/dash"
    
    # Database connection info
    database_secret_arn = module.streaming_rds_database.master_user_secret_arn
  }
}

# Enhanced deployment targets with streaming services
output "streaming_deployment_targets" {
  description = "Streaming service deployment targets for CI/CD"
  value = {
    streaming_services = {
      api_service = {
        cluster_name = module.streaming_ecs_cluster.cluster_name
        service_name = aws_ecs_service.streaming_api.name
        task_definition = aws_ecs_task_definition.streaming_api.family
        environment = var.environment_tags.trusted
        alb_endpoint = module.streaming_application_load_balancer.alb_dns_name
        container_port = 8080
      }
      
      control_service = {
        cluster_name = module.streaming_ecs_cluster.cluster_name
        service_name = aws_ecs_service.streaming_control.name
        task_definition = aws_ecs_task_definition.streaming_control.family
        environment = var.environment_tags.trusted
        alb_endpoint = module.streaming_application_load_balancer.alb_dns_name
        container_port = 3000
      }
      
      player_service = {
        cluster_name = module.streaming_ecs_cluster.cluster_name
        service_name = aws_ecs_service.streaming_player.name
        task_definition = aws_ecs_task_definition.streaming_player.family
        environment = var.environment_tags.trusted
        alb_endpoint = module.streaming_application_load_balancer.alb_dns_name
        container_port = 8090
        rtmp_port = 1935
      }
    }
  }
}

# Streaming Queue Information
output "streaming_messaging" {
  description = "Streaming queue configuration for applications"
  value = {
    # Queue URLs
    video_processing_queue_url = module.streaming_video_queue.queue_url
    transcoding_results_queue_url = module.streaming_transcoding_queue.queue_url
    analytics_events_queue_url = module.streaming_analytics_queue.queue_url
    
    # Queue details for application configuration
    queues = {
      video_processing = {
        name = module.streaming_video_queue.queue_name
        arn = module.streaming_video_queue.queue_arn
        url = module.streaming_video_queue.queue_url
        dlq_arn = module.streaming_video_queue.dlq_arn
      }
      transcoding_results = {
        name = module.streaming_transcoding_queue.queue_name
        arn = module.streaming_transcoding_queue.queue_arn
        url = module.streaming_transcoding_queue.queue_url
        dlq_arn = module.streaming_transcoding_queue.dlq_arn
      }
      analytics_events = {
        name = module.streaming_analytics_queue.queue_name
        arn = module.streaming_analytics_queue.queue_arn
        url = module.streaming_analytics_queue.queue_url
        dlq_arn = module.streaming_analytics_queue.dlq_arn
      }
    }
    
    region = var.primary_region
  }
}

# Streaming Performance Metrics
output "streaming_monitoring" {
  description = "Streaming infrastructure monitoring endpoints"
  value = {
    # CloudWatch log groups
    ecs_log_group = module.streaming_ecs_cluster.log_group_name
    alb_log_group = module.streaming_application_load_balancer.alb_arn
    
    # Auto-scaling targets
    auto_scaling_targets = {
      streaming_api = aws_appautoscaling_target.streaming_api.resource_id
      streaming_control = aws_appautoscaling_target.streaming_control.resource_id
      streaming_player = aws_appautoscaling_target.streaming_player.resource_id
    }
    
    # Key metrics to monitor
    key_metrics = [
      "ECS CPU/Memory utilization",
      "ALB request count and latency", 
      "SQS queue depth and processing time",
      "RDS connections and performance"
    ]
  }
}

# Complete infrastructure summary including both IoT and Streaming
output "complete_infrastructure_summary" {
  description = "Complete infrastructure deployment summary"
  value = {
    # IoT Management Platform
    iot_platform = {
      api_endpoint = "http://${module.iot_application_load_balancer.alb_dns_name}/api"
      dashboard_endpoint = "http://${module.iot_application_load_balancer.alb_dns_name}/"
      database_endpoint = module.iot_rds_database.db_instance_endpoint
      message_queue = module.jacob_sqs_queues.queue_url
    }
    
    # Video Streaming Platform  
    streaming_platform = {
      api_endpoint = "http://${module.streaming_application_load_balancer.alb_dns_name}/api"
      control_endpoint = "http://${module.streaming_application_load_balancer.alb_dns_name}/control"
      player_endpoint = "http://${module.streaming_application_load_balancer.alb_dns_name}/player"
      rtmp_endpoint = "rtmp://${module.streaming_application_load_balancer.alb_dns_name}/live"
      database_endpoint = module.streaming_rds_database.db_instance_endpoint
    }
    
    # Network Access
    vpn_access = {
      trusted_vpn_client_cidr = var.trusted_vpn_client_cidr
      untrusted_vpn_client_cidr = var.untrusted_vpn_client_cidr
    }
    
    # Infrastructure Status
    deployment_status = "Complete - IoT Management + Video Streaming Platform Ready"
  }
}