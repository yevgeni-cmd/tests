################################################################################
# Main Configuration for a Unified, Multi-Environment Architecture
################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# --- Providers ---
provider "aws" {
  region  = var.primary_region
  profile = var.aws_profile
  alias   = "primary"
}

provider "aws" {
  region  = var.remote_region
  profile = var.aws_profile
  alias   = "remote"
}

data "aws_caller_identity" "current" {
  provider = aws.primary
}

################################################################################
# SECTION 1: UNTRUSTED ENVIRONMENT (IL)
################################################################################

module "untrusted_tgw" {
  source      = "./modules/tgw"
  providers   = { aws = aws.primary }
  name_prefix = "${var.project_name}-untrusted"
  description = "TGW for the Untrusted IL Environment"
  asn         = var.untrusted_asn
}

# --- Untrusted VPCs ---
module "untrusted_vpc_streaming_ingress" {
  source      = "./modules/vpc"
  providers   = { aws = aws.primary }
  name        = "${var.project_name}-untrusted-streaming-ingress"
  cidr        = var.untrusted_vpc_cidrs["streaming_ingress"]
  azs         = ["${var.primary_region}a"]
  tgw_id      = module.untrusted_tgw.tgw_id
  aws_region  = var.primary_region
  create_igw  = true
  subnets = {
    public = { cidr_suffix = 0, type = "public", name = "ec2" }
  }
}

module "untrusted_vpc_streaming_scrub" {
  source         = "./modules/vpc"
  providers      = { aws = aws.primary }
  name           = "${var.project_name}-untrusted-streaming-scrub"
  cidr           = var.untrusted_vpc_cidrs["streaming_scrub"]
  azs            = ["${var.primary_region}a"]
  tgw_id         = module.untrusted_tgw.tgw_id
  aws_region     = var.primary_region
  subnets = {
    app = { cidr_suffix = 0, type = "private", name = "app" }
  }
  manage_nacl          = true
  nacl_udp_ports       = var.srt_udp_ports
  nacl_ssh_source_cidr = var.untrusted_vpn_client_cidr
}

module "untrusted_vpc_iot" {
  source             = "./modules/vpc"
  providers          = { aws = aws.primary }
  name               = "${var.project_name}-untrusted-iot"
  cidr               = var.untrusted_vpc_cidrs["iot_management"]
  azs                = ["${var.primary_region}a"]
  tgw_id             = module.untrusted_tgw.tgw_id
  aws_region         = var.primary_region
  create_nat_gateway = true
  subnets = {
    public = { cidr_suffix = 0, type = "public", name = "nat" },
    app    = { cidr_suffix = 1, type = "private", name = "app" }
  }
}

module "untrusted_vpc_devops" {
  source             = "./modules/vpc"
  providers          = { aws = aws.primary }
  name               = "${var.project_name}-untrusted-devops"
  cidr               = var.untrusted_vpc_cidrs["devops"]
  azs                = ["${var.primary_region}a"]
  tgw_id             = module.untrusted_tgw.tgw_id
  aws_region         = var.primary_region
  create_nat_gateway = true
  subnets = {
    public    = { cidr_suffix = 0, type = "public", name = "nat" },
    app       = { cidr_suffix = 1, type = "private", name = "agent" },
    endpoints = { cidr_suffix = 2, type = "private", name = "endpoints" }
  }
  vpc_endpoints = ["ecr.api", "ecr.dkr", "s3"]
}

# --- Untrusted Security Groups ---
resource "aws_security_group" "untrusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-vpn-sg"
  description = "Allow inbound traffic from untrusted VPCs to the VPN endpoint"
  vpc_id      = module.untrusted_vpc_devops.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.untrusted_vpc_cidrs)
  }
}

# --- Untrusted Resources ---
module "untrusted_ingress_docker_host" {
  source              = "./modules/ec2_instance"
  providers           = { aws = aws.primary }
  instance_name       = "${var.project_name}-untrusted-ingress-host"
  instance_os         = var.instance_os
  instance_type       = var.default_instance_type
  key_name            = var.untrusted_ssh_key_name
  subnet_id           = module.untrusted_vpc_streaming_ingress.subnets["public"].id
  vpc_id              = module.untrusted_vpc_streaming_ingress.vpc_id
  associate_public_ip = true
  allowed_udp_ports   = var.srt_udp_ports
  allowed_ssh_cidrs   = [var.untrusted_vpn_client_cidr]
}

module "untrusted_scrub_docker_host" {
  source                = "./modules/ec2_instance"
  providers             = { aws = aws.primary }
  instance_name         = "${var.project_name}-untrusted-scrub-host"
  instance_os           = var.instance_os
  instance_type         = var.default_instance_type
  key_name              = var.untrusted_ssh_key_name
  subnet_id             = module.untrusted_vpc_streaming_scrub.subnets["app"].id
  vpc_id                = module.untrusted_vpc_streaming_scrub.vpc_id
  allowed_ingress_cidrs = [module.untrusted_vpc_streaming_ingress.vpc_cidr]
  allowed_ssh_cidrs     = [var.untrusted_vpn_client_cidr]
  enable_ecr_access     = true
}

module "untrusted_devops_agent" {
  source            = "./modules/ec2_instance"
  providers         = { aws = aws.primary }
  instance_name     = "${var.project_name}-untrusted-devops-agent"
  instance_os       = var.instance_os
  instance_type     = var.default_instance_type
  key_name          = var.untrusted_ssh_key_name
  subnet_id         = module.untrusted_vpc_devops.subnets["app"].id
  vpc_id            = module.untrusted_vpc_devops.vpc_id
  allowed_ssh_cidrs = [var.untrusted_vpn_client_cidr]
  enable_ecr_access = true
}

module "untrusted_ecr" {
  source          = "./modules/ecr_repository"
  providers       = { aws = aws.primary }
  repository_name = "${var.project_name}/untrusted-devops-images"
}

module "untrusted_s3_ingress" {
  source      = "./modules/s3_bucket"
  providers   = { aws = aws.primary }
  bucket_name = "${var.project_name}-untrusted-ingress-data-${data.aws_caller_identity.current.account_id}"
}

module "untrusted_vpn" {
  source                   = "./modules/client_vpn"
  providers                = { aws = aws.primary }
  name_prefix              = "${var.project_name}-untrusted"
  client_cidr_block        = var.untrusted_vpn_client_cidr
  server_certificate_arn   = var.untrusted_vpn_server_cert_arn
  authentication_type      = var.vpn_authentication_type
  saml_provider_arn        = var.saml_identity_provider_arn
  target_vpc_subnet_id     = module.untrusted_vpc_devops.subnets["app"].id
  vpc_id                   = module.untrusted_vpc_devops.vpc_id
  association_network_cidr = module.untrusted_vpc_devops.vpc_cidr
  authorized_network_cidrs = { for k, v in var.untrusted_vpc_cidrs : k => v }
  security_group_ids       = [aws_security_group.untrusted_vpn_sg.id]
}

module "untrusted_vpn_user_policy" {
  source             = "./modules/iam_policy"
  providers          = { aws = aws.primary }
  policy_name        = "${var.project_name}-untrusted-vpn-user-policy"
  policy_description = "Policy for users connecting to the Untrusted VPN."
}

################################################################################
# SECTION 2: TRUSTED ENVIRONMENT (IL)
################################################################################

module "trusted_tgw" {
  source      = "./modules/tgw"
  providers   = { aws = aws.primary }
  name_prefix = "${var.project_name}-trusted"
  description = "TGW for the Trusted IL Environment"
  asn         = var.trusted_asn
}

# --- Trusted VPCs ---
module "trusted_vpc_streaming_scrub" {
  source      = "./modules/vpc"
  providers   = { aws = aws.primary }
  name        = "${var.project_name}-trusted-streaming-scrub"
  cidr        = var.trusted_vpc_cidrs["streaming_scrub"]
  azs         = ["${var.primary_region}a"]
  tgw_id      = module.trusted_tgw.tgw_id
  aws_region  = var.primary_region
  subnets = {
    app = { cidr_suffix = 0, type = "private", name = "app" }
  }
  manage_nacl          = true
  nacl_udp_ports       = var.srt_udp_ports
  nacl_ssh_source_cidr = var.trusted_vpn_client_cidr
}

module "trusted_vpc_streaming" {
  source      = "./modules/vpc"
  providers   = { aws = aws.primary }
  name        = "${var.project_name}-trusted-streaming-vod"
  cidr        = var.trusted_vpc_cidrs["streaming"]
  azs         = ["${var.primary_region}a"]
  tgw_id      = module.trusted_tgw.tgw_id
  aws_region  = var.primary_region
  subnets = {
    app = { cidr_suffix = 0, type = "private", name = "app" }
  }
}

module "trusted_vpc_iot" {
  source      = "./modules/vpc"
  providers   = { aws = aws.primary }
  name        = "${var.project_name}-trusted-iot-management"
  cidr        = var.trusted_vpc_cidrs["iot_management"]
  azs         = ["${var.primary_region}a"]
  tgw_id      = module.trusted_tgw.tgw_id
  aws_region  = var.primary_region
  subnets = {
    app = { cidr_suffix = 0, type = "private", name = "app" }
  }
}

module "trusted_vpc_jacob" {
  source      = "./modules/vpc"
  providers   = { aws = aws.primary }
  name        = "${var.project_name}-trusted-jacob-api-gw"
  cidr        = var.trusted_vpc_cidrs["jacob_api_gw"]
  azs         = ["${var.primary_region}a"]
  tgw_id      = module.trusted_tgw.tgw_id
  aws_region  = var.primary_region
  subnets = {
    app = { cidr_suffix = 0, type = "private", name = "app" }
  }
}

module "trusted_vpc_devops" {
  source             = "./modules/vpc"
  providers          = { aws = aws.primary }
  name               = "${var.project_name}-trusted-devops"
  cidr               = var.trusted_vpc_cidrs["devops"]
  azs                = ["${var.primary_region}a"]
  tgw_id             = module.trusted_tgw.tgw_id
  aws_region         = var.primary_region
  create_nat_gateway = true
  subnets = {
    public    = { cidr_suffix = 0, type = "public", name = "nat" },
    app       = { cidr_suffix = 1, type = "private", name = "agent" },
    endpoints = { cidr_suffix = 2, type = "private", name = "endpoints" }
  }
  vpc_endpoints = ["ecr.api", "ecr.dkr"]
}

# --- Trusted Security Groups ---
resource "aws_security_group" "trusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-vpn-sg"
  description = "Allow inbound traffic from specific trusted VPCs to the VPN endpoint"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      var.trusted_vpc_cidrs["devops"],
      var.trusted_vpc_cidrs["streaming_scrub"]
    ]
  }
}

# --- Trusted Resources ---
module "trusted_scrub_docker_host" {
  source                = "./modules/ec2_instance"
  providers             = { aws = aws.primary }
  instance_name         = "${var.project_name}-trusted-scrub-host"
  instance_os           = var.instance_os
  instance_type         = var.default_instance_type
  key_name              = var.trusted_ssh_key_name
  subnet_id             = module.trusted_vpc_streaming_scrub.subnets["app"].id
  vpc_id                = module.trusted_vpc_streaming_scrub.vpc_id
  allowed_ingress_cidrs = [module.untrusted_vpc_streaming_scrub.vpc_cidr]
  allowed_ssh_cidrs     = [var.trusted_vpn_client_cidr]
  enable_ecr_access     = true
}

module "trusted_streaming_docker_host" {
  source            = "./modules/ec2_instance"
  providers         = { aws = aws.primary }
  instance_name     = "${var.project_name}-trusted-streaming-host"
  instance_os       = var.instance_os
  instance_type     = var.default_instance_type
  key_name          = var.trusted_ssh_key_name
  subnet_id         = module.trusted_vpc_streaming.subnets["app"].id
  vpc_id            = module.trusted_vpc_streaming.vpc_id
  allowed_ssh_cidrs = [var.trusted_vpn_client_cidr]
  enable_ecr_access = true
}

module "trusted_ado_agent" {
  source            = "./modules/ec2_instance"
  providers         = { aws = aws.primary }
  instance_name     = "${var.project_name}-trusted-ado-agent"
  instance_os       = var.instance_os
  instance_type     = var.default_instance_type
  key_name          = var.trusted_ssh_key_name
  subnet_id         = module.trusted_vpc_devops.subnets["app"].id
  vpc_id            = module.trusted_vpc_devops.vpc_id
  allowed_ssh_cidrs = [var.trusted_vpn_client_cidr]
  enable_ecr_access = true
}

module "trusted_ecr_devops" {
  source          = "./modules/ecr_repository"
  providers       = { aws = aws.primary }
  repository_name = "${var.project_name}/trusted-devops-images"
}
module "trusted_ecr_streaming" {
  source          = "./modules/ecr_repository"
  providers       = { aws = aws.primary }
  repository_name = "${var.project_name}/trusted-streaming-images"
}
module "trusted_ecr_iot" {
  source          = "./modules/ecr_repository"
  providers       = { aws = aws.primary }
  repository_name = "${var.project_name}/trusted-iot-images"
}

module "trusted_s3_streaming" {
  source      = "./modules/s3_bucket"
  providers   = { aws = aws.primary }
  bucket_name = "${var.project_name}-trusted-streaming-data-${data.aws_caller_identity.current.account_id}"
}

module "trusted_vpn" {
  source                   = "./modules/client_vpn"
  providers                = { aws = aws.primary }
  name_prefix              = "${var.project_name}-trusted"
  client_cidr_block        = var.trusted_vpn_client_cidr
  server_certificate_arn   = var.trusted_vpn_server_cert_arn
  authentication_type      = var.vpn_authentication_type
  saml_provider_arn        = var.saml_identity_provider_arn
  target_vpc_subnet_id     = module.trusted_vpc_devops.subnets["app"].id
  vpc_id                   = module.trusted_vpc_devops.vpc_id
  association_network_cidr = module.trusted_vpc_devops.vpc_cidr
  authorized_network_cidrs = {
    devops = var.trusted_vpc_cidrs["devops"],
    scrub  = var.trusted_vpc_cidrs["streaming_scrub"]
  }
  security_group_ids       = [aws_security_group.trusted_vpn_sg.id]
}

module "trusted_vpn_user_policy" {
  source             = "./modules/iam_policy"
  providers          = { aws = aws.primary }
  policy_name        = "${var.project_name}-trusted-vpn-user-policy"
  policy_description = "Policy for users connecting to the Trusted VPN."
}

################################################################################
# SECTION 3: REMOTE UNTRUSTED ENVIRONMENT (EU)
################################################################################

module "remote_iot_tgw" {
  source      = "./modules/tgw"
  providers   = { aws = aws.remote }
  name_prefix = "${var.project_name}-remote-iot"
  description = "TGW for Remote EU IoT VPC"
  asn         = var.remote_asn
}

module "remote_vpc_iot" {
  source      = "./modules/vpc"
  providers   = { aws = aws.remote }
  name        = "${var.project_name}-remote-iot-core"
  cidr        = var.remote_vpc_cidrs["iot_core"]
  azs         = ["${var.remote_region}a"]
  tgw_id      = module.remote_iot_tgw.tgw_id
  aws_region  = var.remote_region
  subnets = {
    app = { cidr_suffix = 0, type = "private", name = "app" }
  }
}

################################################################################
# SECTION 4: CONNECTIVITY
################################################################################

# --- Intra-Region VPC Peering (Untrusted Scrub <-> Trusted Scrub) ---
resource "aws_vpc_peering_connection" "untrusted_scrub_to_trusted_scrub" {
  provider    = aws.primary
  vpc_id      = module.untrusted_vpc_streaming_scrub.vpc_id
  peer_vpc_id = module.trusted_vpc_streaming_scrub.vpc_id
  auto_accept = true
  tags        = { Name = "${var.project_name}-untrusted-to-trusted-scrub-peering" }
}

resource "aws_route" "untrusted_scrub_to_trusted_scrub_route" {
  provider                  = aws.primary
  route_table_id            = module.untrusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block    = module.trusted_vpc_streaming_scrub.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.untrusted_scrub_to_trusted_scrub.id
}

resource "aws_route" "trusted_scrub_to_untrusted_scrub_route" {
  provider                  = aws.primary
  route_table_id            = module.trusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block    = module.untrusted_vpc_streaming_scrub.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.untrusted_scrub_to_trusted_scrub.id
}

# --- Cross-Region TGW Peering (Untrusted IL <-> Untrusted EU) ---
resource "aws_ec2_transit_gateway_peering_attachment" "untrusted_il_to_eu" {
  provider                = aws.primary
  peer_transit_gateway_id = module.remote_iot_tgw.tgw_id
  transit_gateway_id      = module.untrusted_tgw.tgw_id
  peer_region             = var.remote_region
  peer_account_id         = data.aws_caller_identity.current.account_id
  tags                    = { Name = "${var.project_name}-untrusted-il-to-eu-tgw-peering" }
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "eu_accepts_il" {
  provider                      = aws.remote
  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.untrusted_il_to_eu.id
  tags                          = { Name = "${var.project_name}-eu-tgw-peering-accepter" }
}

# --- Routing for Cross-Region TGW Peering ---
resource "aws_ec2_transit_gateway_route" "untrusted_il_to_eu_route" {
  provider                       = aws.primary
  destination_cidr_block         = var.remote_vpc_cidrs["iot_core"]
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.untrusted_il_to_eu.id
  transit_gateway_route_table_id = module.untrusted_tgw.association_default_route_table_id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.eu_accepts_il]
}

resource "aws_ec2_transit_gateway_route" "untrusted_eu_to_il_route" {
  provider                       = aws.remote
  for_each                       = var.untrusted_il_summary_routes
  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.untrusted_il_to_eu.id
  transit_gateway_route_table_id = module.remote_iot_tgw.association_default_route_table_id
  depends_on                     = [aws_ec2_transit_gateway_peering_attachment_accepter.eu_accepts_il]
}
