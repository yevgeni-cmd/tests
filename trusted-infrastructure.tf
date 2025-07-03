################################################################################
# TRUSTED ENVIRONMENT (IL) - Infrastructure
################################################################################

module "trusted_tgw" {
  source      = "./modules/tgw"
  providers   = { aws = aws.primary }
  name_prefix = "${var.project_name}-trusted"
  description = "TGW for the Trusted IL Environment"
  asn         = var.trusted_asn
}

# --- Trusted VPCs ---

# Trusted DevOps VPC (4 subnets + IGW) - SINGLE AZ FOR CONSISTENCY
module "trusted_vpc_devops" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-trusted-devops"
  cidr       = var.trusted_vpc_cidrs["devops"]
  azs        = ["${var.primary_region}a"]  # SINGLE AZ FOR CONSISTENCY
  aws_region = var.primary_region
  tgw_id     = module.trusted_tgw.tgw_id

  # Enable IGW for agent subnet
  create_igw = true

  public_subnet_names  = ["agent"]
  private_subnet_names = ["vpn", "tgw-attach", "endpoints"]
  vpc_endpoints        = ["ecr.api", "ecr.dkr"]
}

# Trusted Streaming Scrub VPC (3 subnets, no IGW) - MATCH DEVOPS AZ
module "trusted_vpc_streaming_scrub" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-trusted-streaming-scrub"
  cidr       = var.trusted_vpc_cidrs["streaming_scrub"]
  azs        = ["${var.primary_region}a"]  # SAME AZ AS DEVOPS
  aws_region = var.primary_region
  tgw_id     = module.trusted_tgw.tgw_id

  private_subnet_names = ["app", "tgw-attach", "endpoints"]
  vpc_endpoints        = ["ecr.api", "ecr.dkr"]
}

# Trusted Streaming VPC (VOD Platform) - SINGLE AZ FOR CONSISTENCY
module "trusted_vpc_streaming" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-trusted-streaming-vod"
  cidr       = var.trusted_vpc_cidrs["streaming"]
  azs        = ["${var.primary_region}a"]  # SINGLE AZ
  aws_region = var.primary_region
  tgw_id     = module.trusted_tgw.tgw_id

  private_subnet_names = [
    "ecs-containers",   # ECS containers subnet
    "endpoints",        # VPC endpoints (ECR, S3, SQS)
    "tgw-attach",       # TGW attachments
    "algorithms",       # ALB + Algorithms
    "streaming-docker", # Docker host for streaming
  ]
  vpc_endpoints = ["ecr.api", "ecr.dkr", "s3", "sqs"]
}

# Trusted IoT Management VPC
module "trusted_vpc_iot" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-trusted-iot-management"
  cidr       = var.trusted_vpc_cidrs["iot_management"]
  azs        = ["${var.primary_region}a"]  # SINGLE AZ
  aws_region = var.primary_region
  tgw_id     = module.trusted_tgw.tgw_id

  private_subnet_names = ["ecs", "tgw-attach", "endpoints"]  # Based on architecture
  vpc_endpoints        = ["ecr.api", "ecr.dkr", "sqs", "rds"]
}

# Trusted Jacob API Gateway VPC
module "trusted_vpc_jacob" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-trusted-jacob-api-gw"
  cidr       = var.trusted_vpc_cidrs["jacob_api_gw"]
  azs        = ["${var.primary_region}a"]  # SINGLE AZ
  aws_region = var.primary_region
  tgw_id     = module.trusted_tgw.tgw_id

  private_subnet_names = ["api-gw", "tgw-attach", "endpoints"]  # Based on architecture
  vpc_endpoints        = ["s3", "sqs"]
}

# --- Trusted EC2 Instances ---

# Trusted Scrub Host (receives UDP from untrusted via peering)
module "trusted_scrub_host" {
  source            = "./modules/ec2_instance"
  providers         = { aws = aws.primary }
  instance_name     = "${var.project_name}-trusted-scrub-host"
  key_name          = var.trusted_ssh_key_name
  instance_os       = var.instance_os
  instance_type     = var.instance_types.trusted_scrub
  subnet_id         = module.trusted_vpc_streaming_scrub.private_subnets_by_name["app"].id
  vpc_id            = module.trusted_vpc_streaming_scrub.vpc_id
  enable_ecr_access = true
  enable_ec2_describe = true
  
  custom_ami_id = var.use_custom_amis ? var.custom_standard_ami_id : null
  
  # UPDATE: Combined user-data with ECR auto-login
  user_data = templatefile("${path.module}/templates/ecr-auto-login-userdata.sh", {
    trusted_scrub_vpc_cidr = var.trusted_vpc_cidrs["streaming_scrub"]
    aws_region            = var.primary_region
    ecr_registry_url      = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.primary_region}.amazonaws.com"
  })
  
  allowed_ssh_cidrs = [
    var.trusted_vpn_client_cidr,
    var.trusted_vpc_cidrs["devops"]
  ]
  
  allowed_ingress_cidrs = [
    var.untrusted_vpc_cidrs["streaming_scrub"]
  ]
}

# Trusted Streaming Docker Host (in VPC Streaming VOD)
module "trusted_streaming_host" {
  source            = "./modules/ec2_instance"
  providers         = { aws = aws.primary }
  instance_name     = "${var.project_name}-trusted-streaming-host"
  key_name          = var.trusted_ssh_key_name
  instance_os       = var.instance_os
  # Smart instance type selection: GPU if enabled, otherwise use configured type
  instance_type     = var.use_gpu_for_streaming ? var.gpu_instance_type : var.instance_types.trusted_streaming
  subnet_id         = module.trusted_vpc_streaming.private_subnets_by_name["streaming-docker"].id
  vpc_id            = module.trusted_vpc_streaming.vpc_id
  enable_ecr_access = true
  
  # Smart AMI selection: GPU AMI if using GPU and available, otherwise standard AMI
  custom_ami_id = var.use_custom_amis ? (
    var.use_gpu_for_streaming && var.custom_gpu_ami_id != null ? 
    var.custom_gpu_ami_id : 
    var.custom_standard_ami_id
  ) : null
  
  user_data = templatefile("${path.module}/templates/ecr-auto-login-userdata.sh", {
    aws_region       = var.primary_region
    ecr_registry_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.primary_region}.amazonaws.com"
  })
  
  allowed_ssh_cidrs = [
    var.trusted_vpn_client_cidr,
    var.trusted_vpc_cidrs["devops"]
  ]
  
  allowed_ingress_cidrs = [
    var.trusted_vpc_cidrs["streaming_scrub"]
  ]
}


# Trusted DevOps Host
module "trusted_devops_host" {
  source        = "./modules/ec2_instance"
  providers     = { aws = aws.primary }
  instance_name = "${var.project_name}-trusted-devops-host"
  key_name      = var.trusted_ssh_key_name
  instance_os   = var.instance_os
  instance_type = var.instance_types.trusted_devops
  subnet_id     = module.trusted_vpc_devops.public_subnets_by_name["agent"].id
  vpc_id        = module.trusted_vpc_devops.vpc_id
  enable_ecr_access = true
  
  custom_ami_id = var.use_custom_amis ? var.custom_standard_ami_id : null
  
  # ADO Agent + ECR user data
  user_data = templatefile("${path.module}/templates/ecr-auto-login-userdata.sh", {
    aws_region                    = var.primary_region
    ecr_registry_url             = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.primary_region}.amazonaws.com"
    ado_organization_url         = var.ado_organization_url
    ado_agent_pool_name          = var.ado_agent_pool_name
    ado_pat_secret_name          = var.enable_ado_agents ? aws_secretsmanager_secret.ado_pat[0].name : ""
    deployment_ssh_key_secret_name = var.enable_auto_deployment ? aws_secretsmanager_secret.deployment_ssh_key[0].name : ""
    enable_auto_deployment       = var.enable_auto_deployment
    environment_type             = "trusted"
    associate_public_ip = true
  })
  
  allowed_ssh_cidrs = [
    var.trusted_vpn_client_cidr,
    var.trusted_vpc_cidrs["devops"]
  ]
}


# Add inline policy for ADO secrets access to trusted DevOps host
resource "aws_iam_role_policy" "trusted_devops_ado_secrets" {
  count = var.enable_ado_agents ? 1 : 0
  name  = "ado-secrets-access"
  role  = "${var.project_name}-trusted-devops-host-role"  # Standard role name pattern from EC2 module

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = compact([
          var.enable_ado_agents ? aws_secretsmanager_secret.ado_pat[0].arn : "",
          var.enable_auto_deployment ? aws_secretsmanager_secret.deployment_ssh_key[0].arn : ""
        ])
      }
    ]
  })

  depends_on = [module.trusted_devops_host]
}