# Replace the trusted-infrastructure.tf file with this updated version

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

# Trusted Scrub Host (receives UDP from untrusted via peering) - STANDARD AMI
module "trusted_scrub_host" {
  source        = "./modules/ec2_instance"
  providers     = { aws = aws.primary }
  instance_name = "${var.project_name}-trusted-scrub-host"
  key_name      = var.trusted_ssh_key_name
  instance_os   = var.instance_os
  instance_type = var.default_instance_type
  subnet_id     = module.trusted_vpc_streaming_scrub.private_subnets_by_name["app"].id
  vpc_id        = module.trusted_vpc_streaming_scrub.vpc_id
  # Use standard AMI (not GPU AMI)
  custom_ami_id = var.trusted_custom_ami_id != null ? var.trusted_custom_ami_id : var.custom_ami_id
}

# Trusted DevOps Agent (in public subnet with internet access) - STANDARD AMI
module "trusted_devops_agent" {
  source              = "./modules/ec2_instance"
  providers           = { aws = aws.primary }
  instance_name       = "${var.project_name}-trusted-devops-agent"
  key_name            = var.trusted_ssh_key_name
  instance_os         = var.instance_os
  instance_type       = var.default_instance_type
  subnet_id           = module.trusted_vpc_devops.public_subnets_by_name["agent"].id
  vpc_id              = module.trusted_vpc_devops.vpc_id
  associate_public_ip = true
  # Use standard AMI (not GPU AMI)
  custom_ami_id       = var.trusted_custom_ami_id != null ? var.trusted_custom_ami_id : var.custom_ami_id
}

# Trusted Streaming Docker Host (in VPC Streaming VOD) - GPU AMI WHEN ENABLED
module "trusted_streaming_host" {
  source        = "./modules/ec2_instance"
  providers     = { aws = aws.primary }
  instance_name = "${var.project_name}-trusted-streaming-host"
  key_name      = var.trusted_ssh_key_name
  instance_os   = var.instance_os
  instance_type = var.streaming_host_use_gpu ? var.gpu_instance_type : var.default_instance_type
  subnet_id     = module.trusted_vpc_streaming.private_subnets_by_name["streaming-docker"].id
  vpc_id        = module.trusted_vpc_streaming.vpc_id
  
  # SELECTIVE AMI LOGIC: GPU AMI only if GPU enabled AND gpu_ami_id provided
  custom_ami_id = var.streaming_host_use_gpu && var.gpu_custom_ami_id != null ? (
    var.gpu_custom_ami_id
  ) : (
    var.trusted_custom_ami_id != null ? var.trusted_custom_ami_id : var.custom_ami_id
  )
  
  # GPU optimization user data only when using GPU
  user_data = var.streaming_host_use_gpu ? base64encode(templatefile("${path.module}/user-data/gpu-optimization-userdata.sh", {
    aws_region = var.primary_region
  })) : null
}