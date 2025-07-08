# --------------------------------------------------------------------------------------------------
# nacl.tf
#
# This file defines the production Network ACLs for the streaming pipeline.
# SECURE VERSION: Only allows specific ports needed for the data flow.
# Port 50555 is used consistently for inter-VPC peering communication.
# FIXED: All NACLs now have complete HTTPS rules for ECR access, no duplicates.
# --------------------------------------------------------------------------------------------------

# ==================================================================================================
# 1. Untrusted Streaming Ingress Subnet NACL
# Purpose: Allows the initial SRT UDP stream in from anywhere and forwards it to the untrusted scrub host.
# ==================================================================================================
resource "aws_network_acl" "untrusted_ingress" {
  vpc_id = module.untrusted_vpc_streaming_ingress.vpc_id
  tags = {
    Name        = "${var.project_name}-nacl-untrusted-ingress"
    Environment = var.environment_tags.untrusted
    Project     = var.project_name
  }
}

# --- Inbound Rules ---
resource "aws_network_acl_rule" "untrusted_ingress_inbound_srt" {
  network_acl_id = aws_network_acl.untrusted_ingress.id
  rule_number    = 100
  egress         = false
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = var.srt_udp_ports[0]
  to_port        = var.srt_udp_ports[0]
}

resource "aws_network_acl_rule" "untrusted_ingress_inbound_ssh" {
  network_acl_id = aws_network_acl.untrusted_ingress.id
  rule_number    = 120
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = module.untrusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "untrusted_ingress_inbound_https" {
  network_acl_id = aws_network_acl.untrusted_ingress.id
  rule_number    = 125
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "untrusted_ingress_inbound_ephemeral" {
  network_acl_id = aws_network_acl.untrusted_ingress.id
  rule_number    = 130
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# --- Outbound Rules ---
resource "aws_network_acl_rule" "untrusted_ingress_outbound_to_scrub" {
  network_acl_id = aws_network_acl.untrusted_ingress.id
  rule_number    = 100
  egress         = true
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = var.untrusted_vpc_cidrs["streaming_scrub"]
  from_port      = var.peering_udp_port  # Port 50555
  to_port        = var.peering_udp_port
}

resource "aws_network_acl_rule" "untrusted_ingress_outbound_ephemeral" {
  network_acl_id = aws_network_acl.untrusted_ingress.id
  rule_number    = 110
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = module.untrusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "untrusted_ingress_outbound_https" {
  network_acl_id = aws_network_acl.untrusted_ingress.id
  rule_number    = 120
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# ==================================================================================================
# 2. Untrusted Scrub Subnet NACL
# Purpose: Receives from ingress and forwards (via peering) to the trusted scrub host.
# ==================================================================================================
resource "aws_network_acl" "untrusted_scrub" {
  vpc_id = module.untrusted_vpc_streaming_scrub.vpc_id
  tags = {
    Name        = "${var.project_name}-nacl-untrusted-scrub"
    Environment = var.environment_tags.untrusted
    Project     = var.project_name
  }
}

# --- Inbound Rules ---
resource "aws_network_acl_rule" "untrusted_scrub_inbound_from_ingress" {
  network_acl_id = aws_network_acl.untrusted_scrub.id
  rule_number    = 100
  egress         = false
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = var.untrusted_vpc_cidrs["streaming_ingress"]
  from_port      = var.peering_udp_port  # Port 50555
  to_port        = var.peering_udp_port
}

resource "aws_network_acl_rule" "untrusted_scrub_inbound_ssh" {
  network_acl_id = aws_network_acl.untrusted_scrub.id
  rule_number    = 120
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = module.untrusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "untrusted_scrub_inbound_https" {
  network_acl_id = aws_network_acl.untrusted_scrub.id
  rule_number    = 130
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "untrusted_scrub_inbound_ephemeral" {
  network_acl_id = aws_network_acl.untrusted_scrub.id
  rule_number    = 140
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# --- Outbound Rules ---
resource "aws_network_acl_rule" "untrusted_scrub_outbound_to_trusted_scrub" {
  network_acl_id = aws_network_acl.untrusted_scrub.id
  rule_number    = 100
  egress         = true
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = var.trusted_vpc_cidrs["streaming_scrub"]
  from_port      = var.peering_udp_port  # Port 50555
  to_port        = var.peering_udp_port
}

resource "aws_network_acl_rule" "untrusted_scrub_outbound_ephemeral" {
  network_acl_id = aws_network_acl.untrusted_scrub.id
  rule_number    = 110
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = module.untrusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "untrusted_scrub_outbound_https" {
  network_acl_id = aws_network_acl.untrusted_scrub.id
  rule_number    = 120
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# ==================================================================================================
# 3. Trusted Scrub Subnet NACL
# Purpose: Receives from untrusted scrub and forwards to the trusted stream host.
# ==================================================================================================
resource "aws_network_acl" "trusted_scrub" {
  vpc_id = module.trusted_vpc_streaming_scrub.vpc_id
  tags = {
    Name        = "${var.project_name}-nacl-trusted-scrub"
    Environment = var.environment_tags.trusted
    Project     = var.project_name
  }
}

# --- Inbound Rules ---
resource "aws_network_acl_rule" "trusted_scrub_inbound_from_untrusted_scrub" {
  network_acl_id = aws_network_acl.trusted_scrub.id
  rule_number    = 100
  egress         = false
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = var.untrusted_vpc_cidrs["streaming_scrub"]
  from_port      = var.peering_udp_port  # Port 50555
  to_port        = var.peering_udp_port
}

resource "aws_network_acl_rule" "trusted_scrub_inbound_ssh" {
  network_acl_id = aws_network_acl.trusted_scrub.id
  rule_number    = 120
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = module.trusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "trusted_scrub_inbound_https" {
  network_acl_id = aws_network_acl.trusted_scrub.id
  rule_number    = 130
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "trusted_scrub_inbound_ephemeral" {
  network_acl_id = aws_network_acl.trusted_scrub.id
  rule_number    = 140
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# --- Outbound Rules ---
resource "aws_network_acl_rule" "trusted_scrub_outbound_to_stream_host" {
  network_acl_id = aws_network_acl.trusted_scrub.id
  rule_number    = 100
  egress         = true
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = var.trusted_vpc_cidrs["streaming"]
  from_port      = var.peering_udp_port  # Port 50555
  to_port        = var.peering_udp_port
}

resource "aws_network_acl_rule" "trusted_scrub_outbound_ephemeral" {
  network_acl_id = aws_network_acl.trusted_scrub.id
  rule_number    = 110
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = module.trusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "trusted_scrub_outbound_https" {
  network_acl_id = aws_network_acl.trusted_scrub.id
  rule_number    = 120
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# ==================================================================================================
# 4. Trusted Stream Host (VOD) Subnet NACL
# Purpose: Receives the final stream and allows two-way access for VPN clients.
# ==================================================================================================
resource "aws_network_acl" "trusted_stream_vod" {
  vpc_id = module.trusted_vpc_streaming.vpc_id
  tags = {
    Name        = "${var.project_name}-nacl-trusted-stream-vod"
    Environment = var.environment_tags.trusted
    Project     = var.project_name
  }
}

# --- Inbound Rules for VOD Subnet ---
resource "aws_network_acl_rule" "trusted_vod_inbound_from_scrub" {
  network_acl_id = aws_network_acl.trusted_stream_vod.id
  rule_number    = 100
  egress         = false
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = var.trusted_vpc_cidrs["streaming_scrub"]
  from_port      = var.peering_udp_port  # Port 50555
  to_port        = var.peering_udp_port
}

resource "aws_network_acl_rule" "trusted_vod_inbound_from_vpn" {
  network_acl_id = aws_network_acl.trusted_stream_vod.id
  rule_number    = 110
  egress         = false
  protocol       = "17" # UDP
  rule_action    = "allow"
  cidr_block     = module.trusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
  from_port      = var.srt_udp_ports[0]
  to_port        = var.srt_udp_ports[0]
}

resource "aws_network_acl_rule" "trusted_vod_inbound_ssh" {
  network_acl_id = aws_network_acl.trusted_stream_vod.id
  rule_number    = 120
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = module.trusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "trusted_vod_inbound_https" {
  network_acl_id = aws_network_acl.trusted_stream_vod.id
  rule_number    = 130
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "trusted_vod_inbound_ephemeral" {
  network_acl_id = aws_network_acl.trusted_stream_vod.id
  rule_number    = 140
  egress         = false
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# --- Outbound Rules for VOD Subnet ---
resource "aws_network_acl_rule" "trusted_vod_outbound_to_vpn_ephemeral" {
  network_acl_id = aws_network_acl.trusted_stream_vod.id
  rule_number    = 100
  egress         = true
  protocol       = "-1" # All protocols
  rule_action    = "allow"
  cidr_block     = module.trusted_vpc_devops.private_subnets_by_name["vpn"].cidr_block
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "trusted_vod_outbound_https" {
  network_acl_id = aws_network_acl.trusted_stream_vod.id
  rule_number    = 110
  egress         = true
  protocol       = "6" # TCP
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# ==================================================================================================
# NACL Associations
# ==================================================================================================
resource "aws_network_acl_association" "untrusted_ingress" {
  network_acl_id = aws_network_acl.untrusted_ingress.id
  subnet_id      = module.untrusted_vpc_streaming_ingress.public_subnets_by_name["ec2"].id
}

resource "aws_network_acl_association" "untrusted_scrub" {
  network_acl_id = aws_network_acl.untrusted_scrub.id
  subnet_id      = module.untrusted_vpc_streaming_scrub.private_subnets_by_name["app"].id
}

resource "aws_network_acl_association" "trusted_scrub" {
  network_acl_id = aws_network_acl.trusted_scrub.id
  subnet_id      = module.trusted_vpc_streaming_scrub.private_subnets_by_name["app"].id
}

resource "aws_network_acl_association" "trusted_stream_vod" {
  network_acl_id = aws_network_acl.trusted_stream_vod.id
  subnet_id      = module.trusted_vpc_streaming.private_subnets_by_name["streaming-docker"].id
}