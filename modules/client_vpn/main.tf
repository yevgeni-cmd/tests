terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Get the VPC CIDR to exclude from manual route creation
data "aws_vpc" "associated" {
  id = var.vpc_id
}

# Filter out the associated VPC CIDR from authorized networks to avoid duplicate routes
locals {
  # AWS automatically creates a route for the associated VPC's CIDR
  # We need to exclude it from our manual route creation
  filtered_authorized_networks = {
    for k, v in var.authorized_network_cidrs : k => v
    if v != data.aws_vpc.associated.cidr_block
  }
}

resource "aws_ec2_client_vpn_endpoint" "this" {
  description            = "${var.name_prefix}-client-vpn"
  server_certificate_arn = var.server_certificate_arn
  client_cidr_block      = var.client_cidr_block
  security_group_ids     = var.security_group_ids
  vpc_id                 = var.vpc_id
  dns_servers            = var.dns_servers

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

  split_tunnel = true

  tags = {
    Name = "${var.name_prefix}-client-vpn"
  }
}

resource "aws_ec2_client_vpn_network_association" "this" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  subnet_id              = var.target_vpc_subnet_id
}

resource "aws_ec2_client_vpn_authorization_rule" "this" {
  for_each               = var.authorized_network_cidrs
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.this.id
  target_network_cidr    = each.value
  description            = "Allow access to ${each.key}"
  authorize_all_groups   = true

  depends_on = [aws_ec2_client_vpn_network_association.this]
}

resource "aws_ec2_client_vpn_route" "this" {
  for_each               = local.filtered_authorized_networks
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