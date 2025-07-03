################################################################################
# VPN Configuration - Separate Untrusted and Trusted VPNs
################################################################################

# FIXED: Pre-filter authorized networks to exclude the VPC where VPN is associated
locals {
  # For untrusted VPN (associated with devops VPC), exclude devops CIDR from routes
  untrusted_vpn_route_networks = {
    for k, v in var.untrusted_vpc_cidrs : k => v
    if k != "devops"  # Exclude devops VPC since VPN is associated with it
  }
  
  # For trusted VPN (associated with devops VPC), exclude devops CIDR from routes  
  trusted_vpn_route_networks = {
    for k, v in var.trusted_vpc_cidrs : k => v
    if k != "devops"  # Exclude devops VPC since VPN is associated with it
  }
}

# Untrusted VPN Configuration - UNTRUSTED ONLY (NO trusted zone access)
module "untrusted_vpn" {
  source                 = "./modules/client_vpn"
  providers              = { aws = aws.primary }
  name_prefix            = "${var.project_name}-untrusted"
  client_cidr_block      = var.untrusted_vpn_client_cidr
  server_certificate_arn = var.untrusted_vpn_server_cert_arn
  authentication_type    = var.vpn_authentication_type
  saml_provider_arn      = var.saml_identity_provider_arn
  target_vpc_subnet_id   = module.untrusted_vpc_devops.private_subnets_by_name["vpn"].id
  vpc_id                 = module.untrusted_vpc_devops.vpc_id
  
  # Authorization rules for ALL VPCs (including devops for connectivity)
  authorized_network_cidrs = var.untrusted_vpc_cidrs
  
  # Routes only for NON-associated VPCs (exclude devops to avoid duplicate)
  route_network_cidrs = local.untrusted_vpn_route_networks
  
  security_group_ids     = [aws_security_group.untrusted_vpn_sg.id]
}

# Untrusted VPN User Policy
module "untrusted_vpn_user_policy" {
  source             = "./modules/iam_policy"
  providers          = { aws = aws.primary }
  policy_name        = "${var.project_name}-untrusted-vpn-user-policy"
  policy_description = "Policy for users connecting to the Untrusted VPN."
}

# Trusted VPN Configuration - COMPLETELY SEPARATE from untrusted
module "trusted_vpn" {
  source                 = "./modules/client_vpn"
  providers              = { aws = aws.primary }
  name_prefix            = "${var.project_name}-trusted"
  client_cidr_block      = var.trusted_vpn_client_cidr    # 172.30.0.0/22 - DIFFERENT from untrusted
  server_certificate_arn = var.trusted_vpn_server_cert_arn
  authentication_type    = var.vpn_authentication_type
  saml_provider_arn      = var.saml_identity_provider_arn
  target_vpc_subnet_id   = module.trusted_vpc_devops.private_subnets_by_name["vpn"].id
  vpc_id                 = module.trusted_vpc_devops.vpc_id
  
  # Authorization rules for ALL VPCs (including devops for connectivity)
  authorized_network_cidrs = var.trusted_vpc_cidrs
  
  # Routes only for NON-associated VPCs (exclude devops to avoid duplicate)
  route_network_cidrs = local.trusted_vpn_route_networks
  
  security_group_ids     = [aws_security_group.trusted_vpn_sg.id]
}

# Trusted VPN User Policy
module "trusted_vpn_user_policy" {
  source             = "./modules/iam_policy"
  providers          = { aws = aws.primary }
  policy_name        = "${var.project_name}-trusted-vpn-user-policy"
  policy_description = "Policy for users connecting to the Trusted VPN."
}