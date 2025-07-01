################################################################################
# UNTRUSTED ENVIRONMENT (IL) - Infrastructure
################################################################################

module "untrusted_tgw" {
  source      = "./modules/tgw"
  providers   = { aws = aws.primary }
  name_prefix = "${var.project_name}-untrusted"
  description = "TGW for the Untrusted IL Environment"
  asn         = var.untrusted_asn
}

# --- Untrusted VPCs ---

# Streaming Ingress VPC
module "untrusted_vpc_streaming_ingress" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-untrusted-streaming-ingress"
  cidr       = var.untrusted_vpc_cidrs["streaming_ingress"]
  azs        = ["${var.primary_region}a"]
  aws_region = var.primary_region
  tgw_id     = module.untrusted_tgw.tgw_id

  # Enable IGW for public subnet
  create_igw = true

  public_subnet_names  = ["ec2"]
  private_subnet_names = ["tgw-attach", "endpoints"]
  vpc_endpoints        = ["ecr.api", "ecr.dkr", "s3"]
}

# Streaming Scrub VPC
module "untrusted_vpc_streaming_scrub" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-untrusted-streaming-scrub"
  cidr       = var.untrusted_vpc_cidrs["streaming_scrub"]
  azs        = ["${var.primary_region}a"]
  aws_region = var.primary_region
  tgw_id     = module.untrusted_tgw.tgw_id

  private_subnet_names = ["app", "endpoints", "tgw-attach"]
  vpc_endpoints        = ["ecr.api", "ecr.dkr"]
}

# IoT Management VPC
module "untrusted_vpc_iot" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-untrusted-iot"
  cidr       = var.untrusted_vpc_cidrs["iot_management"]
  azs        = ["${var.primary_region}a"]
  aws_region = var.primary_region
  tgw_id     = module.untrusted_tgw.tgw_id

  # Enable NAT Gateway for Lambda internet access
  create_nat_gateway = true
  create_igw         = true

  public_subnet_names  = ["nat"]
  private_subnet_names = ["lambda", "tgw-attach", "endpoints"]
  vpc_endpoints        = ["ecr.api", "ecr.dkr", "sqs"]
}

# DevOps VPC
module "untrusted_vpc_devops" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-untrusted-devops"
  cidr       = var.untrusted_vpc_cidrs["devops"]
  azs        = ["${var.primary_region}a"]
  aws_region = var.primary_region
  tgw_id     = module.untrusted_tgw.tgw_id

  # Enable IGW for agent subnet internet access
  create_igw = true

  public_subnet_names  = ["agent"]
  private_subnet_names = ["vpn", "tgw-attach", "endpoints"]
  vpc_endpoints        = ["ecr.api", "ecr.dkr"]
}

# --- Untrusted EC2 Instances ---

# Streaming Ingress Host
module "untrusted_ingress_host" {
  source              = "./modules/ec2_instance"
  providers           = { aws = aws.primary }
  instance_name       = "${var.project_name}-untrusted-ingress-host"
  key_name            = var.untrusted_ssh_key_name
  instance_os         = var.instance_os
  instance_type       = var.default_instance_type
  subnet_id           = module.untrusted_vpc_streaming_ingress.public_subnets_by_name["ec2"].id
  vpc_id              = module.untrusted_vpc_streaming_ingress.vpc_id
  associate_public_ip = true
}

# Streaming Scrub Host  
module "untrusted_scrub_host" {
  source        = "./modules/ec2_instance"
  providers     = { aws = aws.primary }
  instance_name = "${var.project_name}-untrusted-scrub-host"
  key_name      = var.untrusted_ssh_key_name
  instance_os   = var.instance_os
  instance_type = var.default_instance_type
  subnet_id     = module.untrusted_vpc_streaming_scrub.private_subnets_by_name["app"].id
  vpc_id        = module.untrusted_vpc_streaming_scrub.vpc_id
}

# DevOps Agent
module "untrusted_devops_agent" {
  source              = "./modules/ec2_instance"
  providers           = { aws = aws.primary }
  instance_name       = "${var.project_name}-untrusted-devops-agent"
  key_name            = var.untrusted_ssh_key_name
  instance_os         = var.instance_os
  instance_type       = var.default_instance_type
  subnet_id           = module.untrusted_vpc_devops.public_subnets_by_name["agent"].id
  vpc_id              = module.untrusted_vpc_devops.vpc_id
  associate_public_ip = true
}