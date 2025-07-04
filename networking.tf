################################################################################
# Network ACLs - All Environments
################################################################################

# --- Untrusted Streaming Ingress VPC NACL ---
resource "aws_network_acl" "untrusted_ingress_nacl" {
  provider   = aws.primary
  vpc_id     = module.untrusted_vpc_streaming_ingress.vpc_id
  subnet_ids = values(module.untrusted_vpc_streaming_ingress.public_subnets_by_name)[*].id

  # Inbound: Allow UDP 8890 from internet
  ingress {
    protocol   = "udp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 8890
    to_port    = 8890
  }

  # Inbound: Allow SSH from VPN clients
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = var.untrusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Inbound: Ephemeral ports for return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Allow UDP 50555 to untrusted scrub
  egress {
    protocol   = "udp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.untrusted_vpc_cidrs["streaming_scrub"]
    from_port  = 50555
    to_port    = 50555
  }

  # Outbound: Allow HTTPS for ECR/updates
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound: Ephemeral ports for return traffic
  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.project_name}-untrusted-ingress-nacl"
  }
}

# --- Untrusted Streaming Scrub VPC NACL ---
resource "aws_network_acl" "untrusted_scrub_nacl" {
  provider   = aws.primary
  vpc_id     = module.untrusted_vpc_streaming_scrub.vpc_id
  subnet_ids = values(module.untrusted_vpc_streaming_scrub.private_subnets_by_name)[*].id

  # Inbound: Allow UDP 50555 from ingress host
  ingress {
    protocol   = "udp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.untrusted_vpc_cidrs["streaming_ingress"]
    from_port  = 50555
    to_port    = 50555
  }

  # Inbound: Allow SSH from VPN clients
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = var.untrusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Inbound: Ephemeral ports for return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Allow UDP 50555 to trusted scrub
  egress {
    protocol   = "udp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.trusted_vpc_cidrs["streaming_scrub"]
    from_port  = 50555
    to_port    = 50555
  }

  # Outbound: Allow HTTPS for ECR/updates
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound: Ephemeral ports for return traffic
  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.project_name}-untrusted-scrub-nacl"
  }
}

# --- Untrusted DevOps VPC NACL ---
resource "aws_network_acl" "untrusted_devops_nacl" {
  provider   = aws.primary
  vpc_id     = module.untrusted_vpc_devops.vpc_id
  subnet_ids = values(module.untrusted_vpc_devops.public_subnets_by_name)[*].id

  # Inbound: Allow SSH from VPN clients
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.untrusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Inbound: Ephemeral ports for return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Allow HTTPS for ECR/updates
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound: Ephemeral ports for return traffic
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.project_name}-untrusted-devops-nacl"
  }
}

# --- Trusted Streaming Scrub VPC NACL ---
resource "aws_network_acl" "trusted_scrub_nacl" {
  provider   = aws.primary
  vpc_id     = module.trusted_vpc_streaming_scrub.vpc_id
  subnet_ids = values(module.trusted_vpc_streaming_scrub.private_subnets_by_name)[*].id

  # Inbound: Allow UDP 50555 from untrusted scrub
  ingress {
    protocol   = "udp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.untrusted_vpc_cidrs["streaming_scrub"]
    from_port  = 50555
    to_port    = 50555
  }

  # Inbound: Allow SSH from VPN clients
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = var.trusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Inbound: Ephemeral ports for return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Allow UDP 50555 to trusted streaming
  egress {
    protocol   = "udp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.trusted_vpc_cidrs["streaming"]
    from_port  = 50555
    to_port    = 50555
  }

  # Outbound: Allow HTTPS for ECR/updates
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound: Ephemeral ports for return traffic
  egress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.project_name}-trusted-scrub-nacl"
  }
}

# --- Trusted Streaming VPC NACL ---
resource "aws_network_acl" "trusted_streaming_nacl" {
  provider   = aws.primary
  vpc_id     = module.trusted_vpc_streaming.vpc_id
  subnet_ids = values(module.trusted_vpc_streaming.private_subnets_by_name)[*].id

  # Inbound: Allow UDP 50555 from trusted scrub
  ingress {
    protocol   = "udp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.trusted_vpc_cidrs["streaming_scrub"]
    from_port  = 50555
    to_port    = 50555
  }

  # Inbound: Allow SSH from VPN clients
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = var.trusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Inbound: Ephemeral ports for return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Allow HTTPS for ECR/updates
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound: Ephemeral ports for return traffic
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.project_name}-trusted-streaming-nacl"
  }
}

# --- Trusted DevOps VPC NACL ---
resource "aws_network_acl" "trusted_devops_nacl" {
  provider   = aws.primary
  vpc_id     = module.trusted_vpc_devops.vpc_id
  subnet_ids = values(module.trusted_vpc_devops.public_subnets_by_name)[*].id

  # Inbound: Allow SSH from VPN clients
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = var.trusted_vpn_client_cidr
    from_port  = 22
    to_port    = 22
  }

  # Inbound: Ephemeral ports for return traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  # Outbound: Allow HTTPS for ECR/updates
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  # Outbound: Ephemeral ports for return traffic
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "${var.project_name}-trusted-devops-nacl"
  }
}

resource "aws_vpc_peering_connection" "untrusted_to_trusted_scrub" {
  provider    = aws.primary
  vpc_id      = module.untrusted_vpc_streaming_scrub.vpc_id
  peer_vpc_id = module.trusted_vpc_streaming_scrub.vpc_id
  auto_accept = true

  tags = {
    Name = "${var.project_name}-untrusted-to-trusted-scrub"
  }
}

resource "aws_route" "untrusted_to_trusted" {
  provider                  = aws.primary
  route_table_id            = module.untrusted_vpc_streaming_scrub.private_route_table_ids[0]
  destination_cidr_block    = var.trusted_vpc_cidrs["streaming_scrub"]
  vpc_peering_connection_id = aws_vpc_peering_connection.untrusted_to_trusted_scrub.id
}
