terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.primary]
    }
  }
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  provider               = aws.primary
  description            = "${var.name_prefix}-client-vpn" # Using name_prefix for consistency
  server_certificate_arn = var.server_certificate_arn
  client_cidr_block      = var.client_cidr_block
  security_group_ids     = var.security_group_ids
  vpc_id                 = var.vpc_id
  dns_servers            = length(var.dns_servers) > 0 ? var.dns_servers : null
  split_tunnel           = true

  dynamic "authentication_options" {
    for_each = var.authentication_type == "saml" ? ["saml"] : []
    content {
      type                           = "federated-authentication"
      saml_provider_arn              = var.saml_provider_arn
      self_service_saml_provider_arn = var.saml_provider_arn
    }
  }

  dynamic "authentication_options" {
    for_each = var.authentication_type == "certificate" ? ["cert"] : []
    content {
      type                       = "certificate-authentication"
      root_certificate_chain_arn = var.server_certificate_arn
    }
  }

  connection_log_options {
    enabled = false
  }

  tags = {
    Name = "${var.name_prefix}-client-vpn"
  }
}

resource "aws_ec2_client_vpn_network_association" "this" {
  provider               = aws.primary
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = var.target_vpc_subnet_id
}

resource "aws_ec2_client_vpn_authorization_rule" "this" {
  provider               = aws.primary
  for_each               = var.authorized_network_cidrs
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = each.value
  description            = "Allow access to ${each.key}"
  authorize_all_groups   = true

  depends_on = [aws_ec2_client_vpn_network_association.this]
}

resource "aws_ec2_client_vpn_route" "this" {
  provider = aws.primary
  # FIX: Changed the for_each to iterate over 'var.route_network_cidrs'.
  # This variable contains the pre-filtered list of routes from the root module.
  for_each               = var.route_network_cidrs
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = each.value
  target_vpc_subnet_id   = var.target_vpc_subnet_id
  description            = "Route to ${each.key}"

  timeouts {
    create = "10m"
    delete = "10m"
  }

  depends_on = [
    aws_ec2_client_vpn_network_association.this,
    aws_ec2_client_vpn_authorization_rule.this
  ]
}

resource "aws_ec2_client_vpn_route" "dns_resolver" {
  provider               = aws.primary
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  destination_cidr_block = "169.254.169.253/32"
  target_vpc_subnet_id   = var.target_vpc_subnet_id
  description            = "Route to AWS DNS resolver"

  depends_on = [
    aws_ec2_client_vpn_network_association.this
  ]
}