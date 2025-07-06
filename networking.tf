################################################################################
# Complete Networking - VPC Peering, TGW Routes, and NACLs
# Aligned with AWS Client VPN NAT behavior and security groups
################################################################################

# --- VPC Peering for Untrusted → Trusted Scrub (One-way UDP) ---

resource "aws_vpc_peering_connection" "untrusted_to_trusted_scrub" {
  provider    = aws.primary
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
  route_table_id            = module.untrusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block    = var.trusted_vpc_cidrs["streaming_scrub"]
  vpc_peering_connection_id = aws_vpc_peering_connection.untrusted_to_trusted_scrub.id
}

################################################################################
# FIXED: Complete TGW Routes for All VPC Communication
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

# FIXED: Return Routes from Other VPCs to DevOps VPC

# Ingress VPC → DevOps VPC (for SSH return traffic)
resource "aws_route" "untrusted_ingress_public_to_devops" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_streaming_ingress.public_route_table_id
  destination_cidr_block = var.untrusted_vpc_cidrs["devops"]
  transit_gateway_id     = module.untrusted_tgw.tgw_id

  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id
  ]
}

resource "aws_route" "untrusted_ingress_private_to_devops" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_streaming_ingress.private_route_table_id
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

################################################################################
# Network ACLs - Aligned with VPN Subnet Access
################################################################################

# Custom NACL for Untrusted Streaming Scrub App Subnet
resource "aws_network_acl" "scrub_app_nacl" {
  provider   = aws.primary
  vpc_id     = module.untrusted_vpc_streaming_scrub.vpc_id
  subnet_ids = [module.untrusted_vpc_streaming_scrub.private_subnets_by_name["app"].id]

  # Allow SSH from VPN clients (not VPN subnet)
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.untrusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Allow UDP streaming from ingress VPC
  dynamic "ingress" {
    for_each = { for i, port in var.srt_udp_ports : i => port }
    content {
      rule_no    = 200 + ingress.key
      protocol   = "udp"
      action     = "allow"
      cidr_block = var.untrusted_vpc_cidrs["streaming_ingress"]
      from_port  = ingress.value
      to_port    = ingress.value
    }
  }

  # Allow HTTPS for ECR access
  ingress {
    rule_no    = 300
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow all return traffic (like before - safer for internet connectivity)
  ingress {
    rule_no    = 400
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow SSH outbound
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Allow UDP streaming outbound to trusted zone
  dynamic "egress" {
    for_each = { for i, port in var.srt_udp_ports : i => port }
    content {
      rule_no    = 200 + egress.key
      protocol   = "udp"
      action     = "allow"
      cidr_block = var.trusted_cidr_block  # Trusted zone CIDR
      from_port  = egress.value
      to_port    = egress.value
    }
  }

  # Allow HTTPS outbound for ECR
  egress {
    rule_no    = 300
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow ephemeral ports outbound
  egress {
    rule_no    = 400
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow SSH inbound from VPN subnet
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = module.untrusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
    from_port  = 22
    to_port    = 22
  }

  tags = {
    Name = "${var.project_name}-scrub-app-nacl"
  }
}

# Custom NACL for Trusted Scrub App Subnet
resource "aws_network_acl" "trusted_scrub_app_nacl" {
  provider   = aws.primary
  vpc_id     = module.trusted_vpc_streaming_scrub.vpc_id
  subnet_ids = [module.trusted_vpc_streaming_scrub.private_subnets_by_name["app"].id]

  # Allow SSH from trusted VPN clients (not VPN subnet)
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.trusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Allow UDP streaming from untrusted scrub (via peering)
  dynamic "ingress" {
    for_each = { for i, port in var.srt_udp_ports : i => port }
    content {
      rule_no    = 200 + ingress.key
      protocol   = "udp"
      action     = "allow"
      cidr_block = var.untrusted_vpc_cidrs["streaming_scrub"]
      from_port  = ingress.value
      to_port    = ingress.value
    }
  }

  # Allow HTTPS for ECR access
  ingress {
    rule_no    = 300
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow all return traffic (like before - safer for internet connectivity)
  ingress {
    rule_no    = 400
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow SSH outbound
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Allow UDP streaming outbound to trusted streaming host
  dynamic "egress" {
    for_each = { for i, port in var.srt_udp_ports : i => port }
    content {
      rule_no    = 200 + egress.key
      protocol   = "udp"
      action     = "allow"
      cidr_block = var.trusted_vpc_cidrs["streaming"]
      from_port  = egress.value
      to_port    = egress.value
    }
  }

  # Allow HTTPS outbound for ECR
  egress {
    rule_no    = 300
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow ephemeral ports outbound
  egress {
    rule_no    = 400
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.project_name}-trusted-scrub-app-nacl"
  }
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






