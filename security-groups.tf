################################################################################
# Security Groups - Trusted & Untrusted (VPN-aware + Internet + Isolation)
################################################################################

# --- Untrusted VPN SG ---
resource "aws_security_group" "untrusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-vpn-sg"
  description = "Client VPN endpoint - Untrusted"
  vpc_id      = module.untrusted_vpc_devops.vpc_id

  ingress {
    description = "Allow from all untrusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.untrusted_vpc_cidrs)
  }

  ingress {
    description = "Allow ONLY untrusted VPN clients"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  egress {
    description = "Outbound to untrusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.untrusted_vpc_cidrs)
  }

  tags = { Name = "${var.project_name}-untrusted-vpn-sg" }
}

# --- Trusted VPN SG ---
resource "aws_security_group" "trusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-vpn-sg"
  description = "Client VPN endpoint - Trusted"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  ingress {
    description = "Allow from all trusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  ingress {
    description = "Allow ONLY trusted VPN clients"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  egress {
    description = "Outbound to trusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  tags = { Name = "${var.project_name}-trusted-vpn-sg" }
}

# --- DevOps Agent SGs ---
resource "aws_security_group" "untrusted_agent_sg" {
  provider = aws.primary
  name     = "${var.project_name}-untrusted-agent-sg"
  description = "Untrusted DevOps Agent"
  vpc_id   = module.untrusted_vpc_devops.vpc_id

  ingress {
    description = "SSH from VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  egress {
    description = "Internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-untrusted-agent-sg" }
}

resource "aws_security_group" "trusted_agent_sg" {
  provider = aws.primary
  name     = "${var.project_name}-trusted-agent-sg"
  description = "Trusted DevOps Agent"
  vpc_id   = module.trusted_vpc_devops.vpc_id

  ingress {
    description = "SSH from VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  egress {
    description = "Internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-trusted-agent-sg" }
}

# --- Ingress & Scrub Hosts ---
resource "aws_security_group" "untrusted_ingress_sg" {
  provider = aws.primary
  name     = "${var.project_name}-untrusted-ingress-sg"
  description = "Untrusted Ingress EC2"
  vpc_id   = module.untrusted_vpc_streaming_ingress.vpc_id

  ingress {
    description = "SSH from DevOps NAT"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpc_cidrs["devops"]]
  }

  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "UDP Port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-untrusted-ingress-sg" }
}

resource "aws_security_group" "untrusted_scrub_sg" {
  provider = aws.primary
  name     = "${var.project_name}-untrusted-scrub-sg"
  description = "Untrusted Scrub EC2"
  vpc_id   = module.untrusted_vpc_streaming_scrub.vpc_id

  ingress {
    description = "SSH from VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "UDP from Ingress"
      from_port   = var.peering_udp_port
      to_port     = var.peering_udp_port
      protocol    = "udp"
      cidr_blocks = [var.untrusted_vpc_cidrs["streaming_ingress"]]
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-untrusted-scrub-sg" }
}

resource "aws_security_group" "trusted_scrub_sg" {
  provider = aws.primary
  name     = "${var.project_name}-trusted-scrub-sg"
  description = "Trusted Scrub EC2"
  vpc_id   = module.trusted_vpc_streaming_scrub.vpc_id

  ingress {
    description = "SSH from VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "UDP from Untrusted Scrub"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = [var.untrusted_vpc_cidrs["streaming_scrub"]]
    }
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-trusted-scrub-sg" }
}

resource "aws_security_group" "trusted_streaming_sg" {
  provider = aws.primary
  name     = "${var.project_name}-trusted-streaming-sg"
  description = "Trusted Streaming EC2"
  vpc_id   = module.trusted_vpc_streaming.vpc_id

  ingress {
    description = "SSH from VPN"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  egress {
    description = "Outbound to trusted"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  tags = { Name = "${var.project_name}-trusted-streaming-sg" }
}
