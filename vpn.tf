################################################################################
# VPN Configuration - Trusted and Untrusted
################################################################################

module "trusted_vpn" {
  source                 = "./modules/client_vpn"
  providers              = { aws = aws.primary }
  project_name           = var.project_name
  name_prefix            = "${var.project_name}-trusted"
  vpc_id                 = module.trusted_vpc_streaming.vpc_id
  server_certificate_arn = var.trusted_vpn_server_cert_arn
  client_cidr_block      = var.trusted_vpn_client_cidr
  security_group_ids     = [aws_security_group.trusted_vpn_sg.id]
  target_vpc_subnet_id   = module.trusted_vpc_streaming.private_subnets_by_name["vpn"]
  authentication_type    = var.vpn_authentication_type
  saml_provider_arn      = var.saml_identity_provider_arn
  dns_servers            = []
  authorized_network_cidrs = {
    "streaming"       = var.trusted_vpc_cidrs["streaming"]
    "streaming_scrub" = var.trusted_vpc_cidrs["streaming_scrub"]
    "devops"          = var.trusted_vpc_cidrs["devops"]
  }
}

module "untrusted_vpn" {
  source                 = "./modules/client_vpn"
  providers              = { aws = aws.primary }
  project_name           = var.project_name
  name_prefix            = "${var.project_name}-untrusted"
  vpc_id                 = module.untrusted_vpc_streaming_ingress.vpc_id
  server_certificate_arn = var.untrusted_vpn_server_cert_arn
  client_cidr_block      = var.untrusted_vpn_client_cidr
  security_group_ids     = [aws_security_group.untrusted_vpn_sg.id]
  target_vpc_subnet_id   = module.untrusted_vpc_streaming_ingress.private_subnets_by_name["vpn"]
  authentication_type    = var.vpn_authentication_type
  saml_provider_arn      = var.saml_identity_provider_arn
  dns_servers            = []
  authorized_network_cidrs = {
    "streaming_ingress" = var.untrusted_vpc_cidrs["streaming_ingress"]
    "streaming_scrub"   = var.untrusted_vpc_cidrs["streaming_scrub"]
    "devops"            = var.untrusted_vpc_cidrs["devops"]
  }
}