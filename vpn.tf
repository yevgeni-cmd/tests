# This file configures the Client VPN endpoints for both trusted and untrusted environments.

# This locals block intelligently filters the VPC CIDRs to be used for VPN routes.
# It excludes the "devops" VPC from the routes because the VPN endpoint is already
# associated with that VPC, which prevents routing conflicts.
locals {
  # For untrusted VPN (associated with devops VPC), create routes for all other untrusted VPCs.
  untrusted_vpn_route_networks = {
    for k, v in var.untrusted_vpc_cidrs : k => v
    if k != "devops" # Exclude devops VPC since VPN is associated with it
  }

  # For trusted VPN (associated with devops VPC), create routes for all other trusted VPCs.
  trusted_vpn_route_networks = {
    for k, v in var.trusted_vpc_cidrs : k => v
    if k != "devops" # Exclude devops VPC since VPN is associated with it
  }
}

################################################################################
# Untrusted VPN Configuration
################################################################################

module "untrusted_vpn" {
  source                 = "./modules/client_vpn"
  
  # FIX: Explicitly pass the 'primary' provider configuration to the module.
  # The module expects a provider with the local name 'aws.primary'.
  providers = {
    aws.primary = aws.primary
  }

  name_prefix            = "${var.project_name}-untrusted"
  client_cidr_block      = var.untrusted_vpn_client_cidr
  server_certificate_arn = var.untrusted_vpn_server_cert_arn
  authentication_type    = var.vpn_authentication_type
  saml_provider_arn      = var.saml_identity_provider_arn

  target_vpc_subnet_id   = module.untrusted_vpc_devops.private_subnets_by_name["vpn"].id
  vpc_id                 = module.untrusted_vpc_devops.vpc_id

  authorized_network_cidrs = var.untrusted_vpc_cidrs
  route_network_cidrs      = local.untrusted_vpn_route_networks
  security_group_ids       = [aws_security_group.untrusted_vpn_sg.id]
}

# This module creates the IAM policy for users of the Untrusted VPN.
module "untrusted_vpn_user_policy" {
  source               = "./modules/iam_policy"
  providers            = { aws = aws.primary }

  policy_name          = "${var.project_name}-untrusted-vpn-user-policy"
  policy_description   = "Policy for users connecting to the Untrusted VPN."
}


################################################################################
# Trusted VPN Configuration
################################################################################

module "trusted_vpn" {
  source                 = "./modules/client_vpn"
  providers = {
    aws.primary = aws.primary
  }

  name_prefix            = "${var.project_name}-trusted"
  client_cidr_block      = var.trusted_vpn_client_cidr
  server_certificate_arn = var.trusted_vpn_server_cert_arn
  authentication_type    = var.vpn_authentication_type
  saml_provider_arn      = var.saml_identity_provider_arn

  target_vpc_subnet_id   = module.trusted_vpc_devops.private_subnets_by_name["vpn"].id
  vpc_id                 = module.trusted_vpc_devops.vpc_id

  authorized_network_cidrs = var.trusted_vpc_cidrs
  route_network_cidrs      = local.trusted_vpn_route_networks
  security_group_ids       = [aws_security_group.trusted_vpn_sg.id]
  dns_servers              = ["169.254.169.253", "8.8.8.8"]

}

# This module creates the IAM policy for users of the Trusted VPN.
module "trusted_vpn_user_policy" {
  source               = "./modules/iam_policy"
  providers            = { aws = aws.primary }

  policy_name          = "${var.project_name}-trusted-vpn-user-policy"
  policy_description   = "Policy for users connecting to the Trusted VPN."
}
