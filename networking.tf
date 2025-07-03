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

  # FIXED: SRT ports from untrusted scrub via VPC peering (ONE-WAY)
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

  # FIXED: Static MediaMTX port from untrusted scrub via VPC peering (ONE-WAY)
  ingress {
    rule_no    = 220
    protocol   = "udp"
    action     = "allow"
    cidr_block = var.untrusted_vpc_cidrs["streaming_scrub"]
    from_port  = var.peering_udp_port
    to_port    = var.peering_udp_port
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

  # EGRESS rules - Only to trusted streaming (NO back to untrusted)
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # FIXED: SRT UDP outbound to trusted streaming host ONLY
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

  # FIXED: Static MediaMTX port outbound to trusted streaming ONLY
  egress {
    rule_no    = 220
    protocol   = "udp"
    action     = "allow"
    cidr_block = var.trusted_vpc_cidrs["streaming"]
    from_port  = var.peering_udp_port
    to_port    = var.peering_udp_port
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

  # REMOVED: No return traffic to untrusted (security requirement)

  tags = {
    Name = "${var.project_name}-trusted-scrub-app-nacl"
  }

  depends_on = [module.trusted_vpc_streaming_scrub]
}

# ADDED: Network ACL for Untrusted Scrub (ONE-WAY peering only)
resource "aws_network_acl" "untrusted_scrub_app_nacl" {
  provider   = aws.primary
  vpc_id     = module.untrusted_vpc_streaming_scrub.vpc_id
  subnet_ids = [module.untrusted_vpc_streaming_scrub.private_subnets_by_name["app"].id]

  # Allow SSH inbound from untrusted VPN clients
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.untrusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Allow SSH inbound from untrusted devops VPC
  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = var.untrusted_vpc_cidrs["devops"]
    from_port  = 22
    to_port    = 22
  }

  # SRT UDP from untrusted ingress
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

  # REMOVED: No return traffic from trusted (ONE-WAY only)

  # Allow HTTPS for ECR access
  ingress {
    rule_no    = 400
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Allow ephemeral ports for return traffic
  ingress {
    rule_no    = 500
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # EGRESS rules - Forward to trusted scrub ONLY (ONE-WAY)
  egress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  # Forward traffic to trusted scrub via VPC peering (ONE-WAY)
  dynamic "egress" {
    for_each = { for i, port in var.srt_udp_ports : i => port }
    content {
      rule_no    = 200 + egress.key
      protocol   = "udp"
      action     = "allow"
      cidr_block = var.trusted_vpc_cidrs["streaming_scrub"]
      from_port  = egress.value
      to_port    = egress.value
    }
  }

  # Forward MediaMTX traffic to trusted scrub (ONE-WAY)
  egress {
    rule_no    = 220
    protocol   = "udp"
    action     = "allow"
    cidr_block = var.trusted_vpc_cidrs["streaming_scrub"]
    from_port  = var.peering_udp_port
    to_port    = var.peering_udp_port
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
    Name = "${var.project_name}-untrusted-scrub-app-nacl"
  }

  depends_on = [module.untrusted_vpc_streaming_scrub]
}