################################################################################
# Networking - VPC Peering, Routes, and NACLs
################################################################################

# --- VPC Peering for Untrusted → Trusted Scrub (One-way UDP) ---

# VPC Peering Connection
resource "aws_vpc_peering_connection" "untrusted_to_trusted_scrub" {
  provider    = aws.primary
  vpc_id      = module.untrusted_vpc_streaming_scrub.vpc_id
  peer_vpc_id = module.trusted_vpc_streaming_scrub.vpc_id
  auto_accept = true

  tags = {
    Name = "${var.project_name}-untrusted-to-trusted-scrub-peering"
  }

  # FIXED: Added explicit dependencies
  depends_on = [
    module.untrusted_vpc_streaming_scrub,
    module.trusted_vpc_streaming_scrub
  ]
}

# Route from untrusted scrub to trusted scrub (for UDP streaming)
resource "aws_route" "untrusted_scrub_to_trusted_scrub" {
  provider                  = aws.primary
  route_table_id            = module.untrusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block    = var.trusted_vpc_cidrs["streaming_scrub"]
  vpc_peering_connection_id = aws_vpc_peering_connection.untrusted_to_trusted_scrub.id

  depends_on = [
    aws_vpc_peering_connection.untrusted_to_trusted_scrub,
    module.untrusted_vpc_streaming_scrub
  ]
}

# Route from trusted scrub back to untrusted scrub (for return traffic)
resource "aws_route" "trusted_scrub_to_untrusted_scrub" {
  provider                  = aws.primary
  route_table_id            = module.trusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block    = var.untrusted_vpc_cidrs["streaming_scrub"]
  vpc_peering_connection_id = aws_vpc_peering_connection.untrusted_to_trusted_scrub.id

  depends_on = [
    aws_vpc_peering_connection.untrusted_to_trusted_scrub,
    module.trusted_vpc_streaming_scrub
  ]
}

# --- Custom Network ACLs ---

# Custom NACL for Untrusted Streaming Scrub App Subnet
resource "aws_network_acl" "scrub_app_nacl" {
  provider   = aws.primary
  vpc_id     = module.untrusted_vpc_streaming_scrub.vpc_id
  subnet_ids = [module.untrusted_vpc_streaming_scrub.private_subnets_by_name["app"].id]

  # Allow SSH inbound from VPN clients
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.untrusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
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

  # Allow UDP streaming inbound from ingress VPC
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

  # Allow ephemeral ports for return traffic
  ingress {
    rule_no    = 400
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow UDP ephemeral ports
  ingress {
    rule_no    = 500
    protocol   = "udp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow SSH outbound to anywhere
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Allow UDP streaming outbound to trusted zone (via TGW)
  dynamic "egress" {
    for_each = { for i, port in var.srt_udp_ports : i => port }
    content {
      rule_no    = 200 + egress.key
      protocol   = "udp"
      action     = "allow"
      cidr_block = "172.16.0.0/16"  # Trusted zone CIDR
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
    Name = "${var.project_name}-scrub-app-nacl"
  }

  depends_on = [module.untrusted_vpc_streaming_scrub]
}

# Custom NACL for Trusted Scrub App Subnet - MATCHING UNTRUSTED
resource "aws_network_acl" "trusted_scrub_app_nacl" {
  provider   = aws.primary
  vpc_id     = module.trusted_vpc_streaming_scrub.vpc_id
  subnet_ids = [module.trusted_vpc_streaming_scrub.private_subnets_by_name["app"].id]

  # Allow SSH inbound from trusted VPN clients
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.trusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Allow SSH inbound from trusted VPN subnet
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = module.trusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
    from_port  = 22
    to_port    = 22
  }

  # Allow UDP streaming inbound from untrusted scrub (via peering)
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

  # Allow ephemeral ports for return traffic
  ingress {
    rule_no    = 400
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow UDP ephemeral ports
  ingress {
    rule_no    = 500
    protocol   = "udp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Allow SSH outbound to anywhere
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

  depends_on = [module.trusted_vpc_streaming_scrub]
}

# --- Route Table Customizations ---

# CRITICAL: Routes for inter-VPC communication via TGW
# DevOps VPC needs to reach other untrusted VPCs for VPN traffic routing
resource "aws_route" "devops_to_other_untrusted_vpcs" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_devops.private_route_table_id
  destination_cidr_block = "172.19.0.0/16"
  transit_gateway_id     = module.untrusted_tgw.tgw_id
  
  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id,
    module.untrusted_vpc_streaming_scrub.tgw_attachment_id,
    module.untrusted_vpc_iot.tgw_attachment_id
  ]

  # FIXED: Added timeout for route creation
  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Add TGW route to PUBLIC subnet for untrusted devops agent
resource "aws_route" "untrusted_devops_public_to_vpcs" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_devops.public_route_table_id
  destination_cidr_block = "172.19.0.0/16"
  transit_gateway_id     = module.untrusted_tgw.tgw_id
  
  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id,
    module.untrusted_vpc_streaming_scrub.tgw_attachment_id,
    module.untrusted_vpc_iot.tgw_attachment_id
  ]

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Ingress VPC needs route back to DevOps VPC (for SSH return traffic)
resource "aws_route" "ingress_to_untrusted_vpcs" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_streaming_ingress.public_route_table_id
  destination_cidr_block = "172.19.0.0/16"
  transit_gateway_id     = module.untrusted_tgw.tgw_id
  
  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_scrub.tgw_attachment_id,
    module.untrusted_vpc_iot.tgw_attachment_id
  ]

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Scrub VPC needs route back to DevOps VPC (for SSH return traffic)  
resource "aws_route" "scrub_to_untrusted_vpcs" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block = "172.19.0.0/16"
  transit_gateway_id     = module.untrusted_tgw.tgw_id
  
  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_streaming_scrub.tgw_attachment_id,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id,
    module.untrusted_vpc_iot.tgw_attachment_id
  ]

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# IoT VPC needs route back to DevOps VPC (for SSH return traffic)
resource "aws_route" "iot_to_untrusted_vpcs" {
  provider               = aws.primary
  route_table_id         = module.untrusted_vpc_iot.private_route_table_id
  destination_cidr_block = "172.19.0.0/16"
  transit_gateway_id     = module.untrusted_tgw.tgw_id
  
  depends_on = [
    module.untrusted_tgw,
    module.untrusted_vpc_iot.tgw_attachment_id,
    module.untrusted_vpc_devops.tgw_attachment_id,
    module.untrusted_vpc_streaming_ingress.tgw_attachment_id,
    module.untrusted_vpc_streaming_scrub.tgw_attachment_id
  ]

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Routes for trusted VPCs to communicate via TGW
resource "aws_route" "trusted_devops_to_other_vpcs" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.private_route_table_id
  destination_cidr_block = "172.16.0.0/16"
  transit_gateway_id     = module.trusted_tgw.tgw_id
  
  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming_scrub.tgw_attachment_id,
    module.trusted_vpc_streaming.tgw_attachment_id,
    module.trusted_vpc_iot.tgw_attachment_id,
    module.trusted_vpc_jacob.tgw_attachment_id
  ]

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

# Add TGW route to PUBLIC subnet for trusted devops agent
resource "aws_route" "trusted_devops_public_to_vpcs" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_devops.public_route_table_id
  destination_cidr_block = "172.16.0.0/16"
  transit_gateway_id     = module.trusted_tgw.tgw_id
  
  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming_scrub.tgw_attachment_id,
    module.trusted_vpc_streaming.tgw_attachment_id,
    module.trusted_vpc_iot.tgw_attachment_id,
    module.trusted_vpc_jacob.tgw_attachment_id
  ]

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

resource "aws_route" "trusted_scrub_to_other_vpcs" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_streaming_scrub.private_route_table_id
  destination_cidr_block = "172.16.0.0/16"
  transit_gateway_id     = module.trusted_tgw.tgw_id
  
  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_streaming_scrub.tgw_attachment_id,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming.tgw_attachment_id,
    module.trusted_vpc_iot.tgw_attachment_id,
    module.trusted_vpc_jacob.tgw_attachment_id
  ]

  timeouts {
    create = "5m"
    delete = "5m"
  }
}

resource "aws_route" "trusted_streaming_to_other_vpcs" {
  provider               = aws.primary
  route_table_id         = module.trusted_vpc_streaming.private_route_table_id
  destination_cidr_block = "172.16.0.0/16"
  transit_gateway_id     = module.trusted_tgw.tgw_id
  
  depends_on = [
    module.trusted_tgw,
    module.trusted_vpc_streaming.tgw_attachment_id,
    module.trusted_vpc_devops.tgw_attachment_id,
    module.trusted_vpc_streaming_scrub.tgw_attachment_id,
    module.trusted_vpc_iot.tgw_attachment_id,
    module.trusted_vpc_jacob.tgw_attachment_id
  ]

  timeouts {
    create = "5m"
    delete = "5m"
  }
}