# --------------------------------------------------------------------------------------------------
# routes.tf
#
# This file defines the VPC Peering and all TGW/IGW/NAT/Peering routes for the project.
# CORRECTED: Module names now match the project's naming convention.
# --------------------------------------------------------------------------------------------------

# --- VPC Peering for Untrusted → Trusted Scrub (One-way UDP) ---

resource "aws_vpc_peering_connection" "untrusted_to_trusted_scrub" {
  provider    = aws.primary
  # CORRECTED: Module names
  vpc_id      = module.untrusted_vpc_streaming_scrub.vpc_id
  peer_vpc_id = module.trusted_vpc_streaming_scrub.vpc_id
  auto_accept = true

  tags = {
    Name = "${var.project_name}-untrusted-to-trusted-scrub-peering"
  }
}

# Route from untrusted scrub to trusted scrub (for UDP streaming)
resource "aws_route" "untrusted_scrub_to_trusted_scrub" {
  provider                  = aws.primary
  # CORRECTED: Module name
  route_table_id            = module.untrusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block    = var.trusted_vpc_cidrs["streaming_scrub"]
  vpc_peering_connection_id = aws_vpc_peering_connection.untrusted_to_trusted_scrub.id
}

################################################################################
# Complete TGW Routes for All VPC Communication
################################################################################

# UNTRUSTED ENVIRONMENT - Complete Bidirectional Routing

# DevOps VPC → All Other Untrusted VPCs (for VPN client routing)
resource "aws_route" "untrusted_devops_private_to_ingress" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_devops.private_route_table_id
  destination_cidr_block = var.untrusted_vpc_cidrs["streaming_ingress"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id
  ]
}

resource "aws_route" "untrusted_devops_private_to_scrub" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_devops.private_route_table_id
  destination_cidr_block = var.untrusted_vpc_cidrs["streaming_scrub"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_scrub.tgw_attachment_id
  ]
}

resource "aws_route" "untrusted_devops_private_to_iot" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_devops.private_route_table_id
  destination_cidr_block = var.untrusted_vpc_cidrs["iot_management"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id
  ]
}

# DevOps PUBLIC subnet → Other Untrusted VPCs (for DevOps agent)
resource "aws_route" "untrusted_devops_public_to_ingress" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_devops.public_route_table_id
  destination_cidr_block = var.untrusted_vpc_cidrs["streaming_ingress"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id
  ]
}

resource "aws_route" "untrusted_devops_public_to_scrub" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_devops.public_route_table_id
  destination_cidr_block = var.untrusted_vpc_cidrs["streaming_scrub"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_scrub.tgw_attachment_id
  ]
}

resource "aws_route" "untrusted_devops_public_to_iot" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_devops.public_route_table_id
  destination_cidr_block = var.untrusted_vpc_cidrs["iot_management"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id
  ]
}

# Use for_each to handle multiple route tables in the ingress VPC
resource "aws_route" "untrusted_ingress_to_devops" {
  for_each = toset(module.untrusted_vpc_streaming_ingress.public_route_table_ids)

  provider               = aws.primary
  route_table_id         = each.value
  destination_cidr_block = var.untrusted_vpc_cidrs["devops"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id
  ]
}

resource "aws_route" "untrusted_ingress_private_to_devops" {
  for_each = toset(module.untrusted_vpc_streaming_ingress.private_route_table_ids)

  provider               = aws.primary
  route_table_id         = each.value
  destination_cidr_block = var.untrusted_vpc_cidrs["devops"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id
  ]
}

# Scrub VPC → DevOps VPC (for SSH return traffic)
resource "aws_route" "untrusted_scrub_to_devops" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block = var.untrusted_vpc_cidrs["devops"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_scrub.tgw_attachment_id
  ]
}

# TRUSTED ENVIRONMENT - Complete Bidirectional Routing

# DevOps VPC → All Other Trusted VPCs (for VPN client routing)
resource "aws_route" "trusted_devops_private_to_scrub" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.private_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["streaming_scrub"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming_scrub.tgw_attachment_id
  ]
}

resource "aws_route" "trusted_devops_private_to_streaming" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.private_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["streaming"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming.tgw_attachment_id
  ]
}

resource "aws_route" "trusted_devops_private_to_iot" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.private_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["iot_management"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_iot.tgw_attachment_id
  ]
}

resource "aws_route" "trusted_devops_private_to_jacob" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.private_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["jacob_api_gw"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_jacob.tgw_attachment_id
  ]
}

# DevOps PUBLIC subnet → Other Trusted VPCs (for DevOps agent)
resource "aws_route" "trusted_devops_public_to_scrub" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.public_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["streaming_scrub"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming_scrub.tgw_attachment_id
  ]
}

resource "aws_route" "trusted_devops_public_to_streaming" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.public_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["streaming"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming.tgw_attachment_id
  ]
}

resource "aws_route" "trusted_devops_public_to_iot" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.public_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["iot_management"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_iot.tgw_attachment_id
  ]
}

resource "aws_route" "trusted_devops_public_to_jacob" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.public_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["jacob_api_gw"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_jacob.tgw_attachment_id
  ]
}

# FIXED: Return Routes from Other Trusted VPCs to DevOps VPC

# Scrub VPC → DevOps VPC (for SSH return traffic)
resource "aws_route" "trusted_scrub_to_devops" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["devops"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming_scrub.tgw_attachment_id
  ]
}

# Streaming VPC → DevOps VPC (for SSH return traffic)
resource "aws_route" "trusted_streaming_to_devops" {
  provider               = aws.primary
  # CORRECTED: Module name
  route_table_id         = module.trusted_vpc_streaming.private_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["devops"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming.tgw_attachment_id
  ]
}

# IoT VPC → DevOps VPC (for SSH return traffic)
resource "aws_route" "trusted_iot_to_devops" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_iot.private_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["devops"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_iot.tgw_attachment_id
  ]
}

# Jacob VPC → DevOps VPC (for SSH return traffic)
resource "aws_route" "trusted_jacob_to_devops" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_jacob.private_route_table_id
  destination_cidr_block = var.trusted_vpc_cidrs["devops"]
  transit_gateway_id     = module.trusted_tgw.tgw_id

  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_jacob.tgw_attachment_id
  ]
}


# --- Add return routes in spoke VPCs for untrusted VPN pool
resource "aws_route" "untrusted_spoke_return_path" {
  for_each = toset(
    concat(
      module.untrusted_vpc_streaming_ingress.private_route_table_ids,
      module.untrusted_vpc_streaming_scrub.private_route_table_ids,
      module.untrusted_vpc_devops.private_route_table_ids
    )
  )

  route_table_id         = each.value
  destination_cidr_block = var.untrusted_vpn_client_cidr
  transit_gateway_id     = module.untrusted_tgw.tgw_id
}

# --- Add return routes in spoke VPCs for trusted VPN pool
resource "aws_route" "trusted_spoke_return_path" {
  for_each = toset(
    concat(
      module.trusted_vpc_streaming_scrub.private_route_table_ids,
      module.trusted_vpc_streaming.private_route_table_ids,
      module.trusted_vpc_jacob.private_route_table_ids,
      module.trusted_vpc_devops.private_route_table_ids
    )
  )

  route_table_id         = each.value
  destination_cidr_block = var.trusted_vpn_client_cidr
  transit_gateway_id     = module.trusted_tgw.tgw_id
}

# Basic IGW routes for public subnets
resource "aws_route" "untrusted_devops_public_igw" {
  count                  = module.untrusted_vpc_devops.internet_gateway_id != null ? 1 : 0
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_devops.public_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.untrusted_vpc_devops.internet_gateway_id
}

resource "aws_route" "untrusted_ingress_public_igw" {
  count                  = module.untrusted_vpc_streaming_ingress.internet_gateway_id != null ? 1 : 0
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_streaming_ingress.public_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.untrusted_vpc_streaming_ingress.internet_gateway_id
}

resource "aws_route" "trusted_devops_public_igw" {
  count                  = module.trusted_vpc_devops.internet_gateway_id != null ? 1 : 0
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.public_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.trusted_vpc_devops.internet_gateway_id
}

# NAT routes only if NAT gateway exists
resource "aws_route" "trusted_devops_private_nat" {
  count                  = module.trusted_vpc_devops.nat_gateway_id != null ? 1 : 0
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.trusted_vpc_devops.nat_gateway_id
}
