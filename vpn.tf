################################################################################
# VPN Configuration - Separate Untrusted and Trusted VPNs
################################################################################

# Untrusted VPN Configuration - UNTRUSTED ONLY (NO trusted zone access)
module "untrusted_vpn" {
  source                   = "./modules/client_vpn"
  providers                = { aws = aws.primary }
  name_prefix              = "${var.project_name}-untrusted"
  client_cidr_block        = var.untrusted_vpn_client_cidr
  server_certificate_arn   = var.untrusted_vpn_server_cert_arn
  authentication_type      = var.vpn_authentication_type
  saml_provider_arn        = var.saml_identity_provider_arn
  target_vpc_subnet_id     = module.untrusted_vpc_devops.private_subnets_by_name["vpn"].id
  vpc_id                   = module.untrusted_vpc_devops.vpc_id
  association_network_cidr = module.untrusted_vpc_devops.vpc_cidr
  authorized_network_cidrs = { 
    # Include ALL untrusted VPCs (including devops)
    for k, v in var.untrusted_vpc_cidrs : k => v 
  }
  security_group_ids       = [aws_security_group.untrusted_vpn_sg.id]
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
  source                   = "./modules/client_vpn"
  providers                = { aws = aws.primary }
  name_prefix              = "${var.project_name}-trusted"
  client_cidr_block        = var.trusted_vpn_client_cidr    # 172.30.0.0/22 - DIFFERENT from untrusted
  server_certificate_arn   = var.trusted_vpn_server_cert_arn
  authentication_type      = var.vpn_authentication_type
  saml_provider_arn        = var.saml_identity_provider_arn
  target_vpc_subnet_id     = module.trusted_vpc_devops.private_subnets_by_name["vpn"].id
  vpc_id                   = module.trusted_vpc_devops.vpc_id
  association_network_cidr = module.trusted_vpc_devops.vpc_cidr
  authorized_network_cidrs = { 
    # Include ALL trusted VPCs (including devops)
    for k, v in var.trusted_vpc_cidrs : k => v 
  }
  security_group_ids       = [aws_security_group.trusted_vpn_sg.id]
}

# Trusted VPN User Policy
module "trusted_vpn_user_policy" {
  source             = "./modules/iam_policy"
  providers          = { aws = aws.primary }
  policy_name        = "${var.project_name}-trusted-vpn-user-policy"
  policy_description = "Policy for users connecting to the Trusted VPN."
}