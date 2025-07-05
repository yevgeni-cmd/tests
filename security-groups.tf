################################################################################
# Security Groups - All Environments
################################################################################

# --- Untrusted Environment Security Groups ---

# Security Group for Untrusted VPN Endpoint
resource "aws_security_group" "untrusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-vpn-sg"
  description = "Security group for Client VPN endpoint - UNTRUSTED ONLY"
  vpc_id      = module.untrusted_vpc_devops.vpc_id

  # This group is primarily for the endpoint itself.
  # The endpoint's rules are managed via authorization rules.
  tags = {
    Name = "${var.project_name}-untrusted-vpn-sg"
  }
}

# Security Group for Untrusted Streaming Ingress Host
resource "aws_security_group" "untrusted_ingress_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-ingress-sg"
  description = "Security group for Streaming Ingress EC2 instance"
  vpc_id      = module.untrusted_vpc_streaming_ingress.vpc_id

  # CRITICAL FIX: Ensure SSH is allowed from the untrusted VPN CIDR.
  ingress {
    description = "Allow SSH from Untrusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  dynamic "ingress" {
    for_each = toset(var.srt_udp_ports)
    content {
      description = "SRT UDP streaming port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-untrusted-ingress-sg"
  }
}

# Security Group for Untrusted Streaming Scrub Host
resource "aws_security_group" "untrusted_scrub_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-scrub-sg"
  description = "Security group for Streaming Scrub EC2 instance"
  vpc_id      = module.untrusted_vpc_streaming_scrub.vpc_id

  # CRITICAL FIX: Ensure SSH is allowed from the untrusted VPN CIDR.
  ingress {
    description = "Allow SSH from Untrusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  ingress {
    description = "Allow UDP from ingress host"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [var.untrusted_vpc_cidrs["streaming_ingress"]]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-untrusted-scrub-sg"
  }
}

# Security Group for Untrusted DevOps Agent
resource "aws_security_group" "untrusted_agent_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-agent-sg"
  description = "Security group for DevOps Agent EC2 instance"
  vpc_id      = module.untrusted_vpc_devops.vpc_id

  # CRITICAL FIX: Ensure SSH is allowed from the untrusted VPN CIDR.
  ingress {
    description = "Allow SSH from Untrusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-untrusted-agent-sg"
  }
}

# --- Trusted Environment Security Groups ---

# Security Group for Trusted VPN Endpoint
resource "aws_security_group" "trusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-vpn-sg"
  description = "Security group for Trusted Client VPN endpoint"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  tags = {
    Name = "${var.project_name}-trusted-vpn-sg"
  }
}

# Security Group for Trusted Scrub Host
resource "aws_security_group" "trusted_scrub_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-scrub-sg"
  description = "Security group for Trusted Scrub EC2 instance"
  vpc_id      = module.trusted_vpc_streaming_scrub.vpc_id

  # CRITICAL FIX: Ensure SSH is allowed from the trusted VPN CIDR.
  ingress {
    description = "Allow SSH from Trusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  ingress {
    description = "Allow UDP from untrusted scrub via peering"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [var.untrusted_vpc_cidrs["streaming_scrub"]]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-trusted-scrub-sg"
  }
}

# Security Group for Trusted Streaming Host
resource "aws_security_group" "trusted_streaming_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-streaming-sg"
  description = "Security group for Trusted Streaming Docker Host"
  vpc_id      = module.trusted_vpc_streaming.vpc_id

  # CRITICAL FIX: Ensure SSH is allowed from the trusted VPN CIDR.
  ingress {
    description = "Allow SSH from Trusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  ingress {
    description = "Allow UDP from trusted scrub"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [var.trusted_vpc_cidrs["streaming_scrub"]]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-trusted-streaming-sg"
  }
}

# Security Group for Trusted DevOps Agent
resource "aws_security_group" "trusted_agent_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-agent-sg"
  description = "Security group for Trusted DevOps Agent"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  # CRITICAL FIX: Ensure SSH is allowed from the trusted VPN CIDR.
  ingress {
    description = "Allow SSH from Trusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-trusted-agent-sg"
  }
}
