################################################################################
# CORRECTED: Security Groups for AWS Client VPN NAT Behavior
################################################################################

# --- Untrusted Environment ---

# Security Group for Untrusted VPN Endpoint
resource "aws_security_group" "untrusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-vpn-sg"
  description = "Security group for Client VPN endpoint - UNTRUSTED ONLY"
  vpc_id      = module.untrusted_vpc_devops.vpc_id

  # AWS Client VPN handles connections internally - no ingress rules needed
  egress {
    description = "All outbound traffic for VPN routing"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-untrusted-vpn-sg" }
}

# Security Group for Untrusted Streaming Ingress Host
resource "aws_security_group" "untrusted_ingress_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-ingress-sg"
  description = "Security group for Streaming Ingress EC2 instance"
  vpc_id      = module.untrusted_vpc_streaming_ingress.vpc_id

  # SSH from VPN clients (not VPN subnet)
  ingress {
    description = "SSH from Untrusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]  # 172.31.0.0/22
  }

  # UDP streaming ports from internet
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

  # Allow all outbound traffic (internet access)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-untrusted-ingress-sg" }
}

# Security Group for Untrusted Streaming Scrub Host
resource "aws_security_group" "untrusted_scrub_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-scrub-sg"
  description = "Security group for Streaming Scrub EC2 instance"
  vpc_id      = module.untrusted_vpc_streaming_scrub.vpc_id

  # SSH from VPN clients (not VPN subnet)
  ingress {
    description = "SSH from Untrusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]  # 172.31.0.0/22
  }

  # UDP from ingress host
  ingress {
    description = "UDP from ingress host"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [var.untrusted_vpc_cidrs["streaming_ingress"]]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-untrusted-scrub-sg" }
}

# Security Group for Untrusted DevOps Agent
resource "aws_security_group" "untrusted_agent_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-agent-sg"
  description = "Security group for DevOps Agent EC2 instance - CI/CD only"
  vpc_id      = module.untrusted_vpc_devops.vpc_id

  # SSH from VPN clients (not VPN subnet)
  ingress {
    description = "SSH from Untrusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]  # 172.31.0.0/22
  }

  # Allow all outbound traffic (internet access for CI/CD)
  egress {
    description = "All outbound traffic for CI/CD"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-untrusted-agent-sg" }
}

# --- Trusted Environment ---

# Security Group for Trusted VPN Endpoint
resource "aws_security_group" "trusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-vpn-sg"
  description = "Security group for Trusted Client VPN endpoint"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  # AWS Client VPN handles connections internally - no ingress rules needed
  egress {
    description = "All outbound traffic for VPN routing"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-trusted-vpn-sg" }
}

# Security Group for Trusted Scrub Host
resource "aws_security_group" "trusted_scrub_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-scrub-sg"
  description = "Security group for Trusted Scrub EC2 instance"
  vpc_id      = module.trusted_vpc_streaming_scrub.vpc_id

  # SSH from VPN clients (not VPN subnet)
  ingress {
    description = "SSH from Trusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]  # 172.30.0.0/22
  }

  # UDP from untrusted scrub via peering
  ingress {
    description = "UDP from untrusted scrub via peering"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [var.untrusted_vpc_cidrs["streaming_scrub"]]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-trusted-scrub-sg" }
}

# Security Group for Trusted Streaming Host
resource "aws_security_group" "trusted_streaming_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-streaming-sg"
  description = "Security group for Trusted Streaming Docker Host"
  vpc_id      = module.trusted_vpc_streaming.vpc_id

  # SSH from VPN clients (not VPN subnet)
  ingress {
    description = "SSH from Trusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]  # 172.30.0.0/22
  }

  # UDP from trusted scrub
  ingress {
    description = "UDP from trusted scrub"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [var.trusted_vpc_cidrs["streaming_scrub"]]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-trusted-streaming-sg" }
}

# Security Group for Trusted DevOps Agent
resource "aws_security_group" "trusted_agent_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-agent-sg"
  description = "Security group for Trusted DevOps Agent - CI/CD only"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  # SSH from VPN clients (not VPN subnet)
  ingress {
    description = "SSH from Trusted VPN Clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]  # 172.30.0.0/22
  }

  # Allow all outbound traffic (internet access for CI/CD)
  egress {
    description = "All outbound traffic for CI/CD"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-trusted-agent-sg" }
}