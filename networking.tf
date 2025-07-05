################################################################################
# Networking - VPC Peering, TGW Routes, and NACLs
################################################################################

# FIX: This locals block aggregates the individual VPC modules into single maps.
# This allows us to loop over them to create routes efficiently and fixes the
# "Reference to undeclared module" error.
locals {
  all_untrusted_vpcs = {
    devops            = module.untrusted_vpc_devops
    streaming_ingress = module.untrusted_vpc_streaming_ingress
    streaming_scrub   = module.untrusted_vpc_streaming_scrub
    # iot               = module.untrusted_vpc_iot
  }
  all_trusted_vpcs = {
    devops          = module.trusted_vpc_devops
    streaming_scrub = module.trusted_vpc_streaming_scrub
    streaming       = module.trusted_vpc_streaming
    iot             = module.trusted_vpc_iot
    jacob           = module.trusted_vpc_jacob
  }
}

# --- VPC Peering for Untrusted → Trusted Scrub (One-way UDP) ---
resource "aws_vpc_peering_connection" "untrusted_to_trusted_scrub" {
  provider    = aws.primary
  vpc_id      = module.untrusted_vpc_streaming_scrub.vpc_id
  peer_vpc_id = module.trusted_vpc_streaming_scrub.vpc_id
  auto_accept = true
  tags        = { Name = "${var.project_name}-untrusted-to-trusted-scrub-peering" }
}

# Route from untrusted scrub to trusted scrub for UDP streaming.
resource "aws_route" "untrusted_scrub_to_trusted_scrub" {
  provider                  = aws.primary
  route_table_id            = module.untrusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block    = var.trusted_vpc_cidrs["streaming_scrub"]
  vpc_peering_connection_id = aws_vpc_peering_connection.untrusted_to_trusted_scrub.id
}

# --- TGW Route Table Customizations ---

# FIX: Loop through all untrusted VPCs (using the new local map) and add routes
# for inter-VPC and VPN client traffic.
resource "aws_route" "untrusted_vpcs_to_tgw" {
  provider   = aws.primary
  for_each   = local.all_untrusted_vpcs

  route_table_id         = each.value.private_route_table_id
  # This summary route ensures all untrusted VPCs can talk to each other.
  destination_cidr_block = "172.17.0.0/16" # Summary CIDR for all untrusted VPCs
  transit_gateway_id     = module.untrusted_tgw.tgw_id
}

resource "aws_route" "untrusted_vpcs_to_vpn_clients" {
  provider   = aws.primary
  for_each   = local.all_untrusted_vpcs

  route_table_id         = each.value.private_route_table_id
  # CRITICAL FIX: This route allows hosts to send return traffic back to the VPN clients.
  destination_cidr_block = var.untrusted_vpn_client_cidr
  transit_gateway_id     = module.untrusted_tgw.tgw_id
}


# FIX: Loop through all trusted VPCs (using the new local map) and add routes
# for inter-VPC and VPN client traffic.
resource "aws_route" "trusted_vpcs_to_tgw" {
  provider   = aws.primary
  for_each   = local.all_trusted_vpcs

  route_table_id         = each.value.private_route_table_id
  # This summary route ensures all trusted VPCs can talk to each other.
  destination_cidr_block = "172.16.0.0/16" # Summary CIDR for all trusted VPCs
  transit_gateway_id     = module.trusted_tgw.tgw_id
}

resource "aws_route" "trusted_vpcs_to_vpn_clients" {
  provider   = aws.primary
  for_each   = local.all_trusted_vpcs

  route_table_id         = each.value.private_route_table_id
  # CRITICAL FIX: This route allows hosts to send return traffic back to the VPN clients.
  destination_cidr_block = var.trusted_vpn_client_cidr
  transit_gateway_id     = module.trusted_tgw.tgw_id
}
