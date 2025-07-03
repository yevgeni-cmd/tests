################################################################################
# Security Groups - SSH Access Fixed for VPN Clients
################################################################################

# Security Group for Untrusted VPN
resource "aws_security_group" "untrusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-vpn-sg"
  description = "Security group for Client VPN endpoint - UNTRUSTED ONLY"
  vpc_id      = module.untrusted_vpc_devops.vpc_id

  # SSH access from VPN clients
  ingress {
    description = "SSH from VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  # HTTPS for management
  ingress {
    description = "HTTPS for management"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  # SRT UDP ports
  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = [var.untrusted_vpn_client_cidr]
    }
  }

  # Outbound - Allow SSH to ALL untrusted VPCs
  egress {
    description = "SSH to untrusted VPCs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = values(var.untrusted_vpc_cidrs)
  }

  # Outbound - HTTPS
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - DNS
  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-untrusted-vpn-sg"
  }
}

# Security Group for Streaming Ingress Host - FIXED SSH ACCESS
resource "aws_security_group" "untrusted_ingress_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-ingress-sg"
  description = "Security group for Streaming Ingress EC2 instance"
  vpc_id      = module.untrusted_vpc_streaming_ingress.vpc_id

  # FIXED: SSH from VPN clients directly
  ingress {
    description = "SSH from VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  # SSH from untrusted devops VPC
  ingress {
    description = "SSH from untrusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpc_cidrs["devops"]]
  }

  # UDP streaming ports from internet
  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP streaming port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Outbound - SSH to untrusted scrub
  egress {
    description = "SSH to untrusted scrub"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpc_cidrs["streaming_scrub"]]
  }

  # Outbound - SRT UDP to scrub
  dynamic "egress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP to scrub host"
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "udp"
      cidr_blocks = [var.untrusted_vpc_cidrs["streaming_scrub"]]
    }
  }

  # Outbound - HTTPS for updates/ECR
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - DNS
  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-untrusted-ingress-sg"
  }
}

# Security Group for Streaming Scrub Host - FIXED SSH ACCESS
resource "aws_security_group" "untrusted_scrub_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-scrub-sg"
  description = "Security group for Streaming Scrub EC2 instance"
  vpc_id      = module.untrusted_vpc_streaming_scrub.vpc_id

  # FIXED: SSH from VPN clients directly
  ingress {
    description = "SSH from VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  # SSH from untrusted devops VPC
  ingress {
    description = "SSH from untrusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpc_cidrs["devops"]]
  }

  # UDP streaming from ingress host
  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP from ingress host"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = [var.untrusted_vpc_cidrs["streaming_ingress"]]
    }
  }

  # Outbound - SSH to trusted scrub (via peering)
  egress {
    description = "SSH to trusted scrub"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpc_cidrs["streaming_scrub"]]
  }

  # Outbound - SRT UDP to trusted scrub
  dynamic "egress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP to trusted scrub"
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "udp"
      cidr_blocks = [var.trusted_vpc_cidrs["streaming_scrub"]]
    }
  }

  # Outbound - HTTPS for updates/ECR
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - DNS
  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-untrusted-scrub-sg"
  }
}

# Security Group for Untrusted DevOps Host - WORKING (Reference)
resource "aws_security_group" "untrusted_agent_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-agent-sg"
  description = "Security group for DevOps Host EC2 instance"
  vpc_id      = module.untrusted_vpc_devops.vpc_id

  # SSH from VPN clients
  ingress {
    description = "SSH from VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  # SSH from untrusted devops VPC
  ingress {
    description = "SSH from untrusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpc_cidrs["devops"]]
  }

  # Outbound - SSH to untrusted VPCs
  egress {
    description = "SSH to untrusted VPCs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = values(var.untrusted_vpc_cidrs)
  }

  # Outbound - HTTPS for updates/ECR/ADO
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - DNS
  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-untrusted-agent-sg"
  }
}

# Security Group for Trusted VPN
resource "aws_security_group" "trusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-vpn-sg"
  description = "Security group for Trusted Client VPN endpoint"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  # SSH access from VPN clients
  ingress {
    description = "SSH from VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # HTTPS for management
  ingress {
    description = "HTTPS for management"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # SRT UDP ports
  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP port ${ingress.value}"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = [var.trusted_vpn_client_cidr]
    }
  }

  # MediaMTX port
  ingress {
    description = "MediaMTX port 50555"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # Outbound - SSH to ALL trusted VPCs
  egress {
    description = "SSH to trusted VPCs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  # Outbound - HTTPS
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - DNS
  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-trusted-vpn-sg"
  }
}

# Security Group for Trusted Scrub Host - FIXED SSH ACCESS
resource "aws_security_group" "trusted_scrub_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-scrub-sg"
  description = "Security group for Trusted Scrub EC2 instance"
  vpc_id      = module.trusted_vpc_streaming_scrub.vpc_id

  # FIXED: SSH from VPN clients directly
  ingress {
    description = "SSH from trusted VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # SSH from trusted devops VPC
  ingress {
    description = "SSH from trusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpc_cidrs["devops"]]
  }

  # UDP streaming from untrusted scrub via VPC peering (ONE-WAY)
  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP from untrusted scrub via VPC peering (ONE-WAY)"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = [var.untrusted_vpc_cidrs["streaming_scrub"]]
    }
  }

  # Outbound - SSH to trusted VPCs
  egress {
    description = "SSH to trusted VPCs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  # Outbound - SRT UDP to trusted streaming
  dynamic "egress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP to trusted streaming"
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "udp"
      cidr_blocks = [var.trusted_vpc_cidrs["streaming"]]
    }
  }

  # Outbound - MediaMTX to trusted streaming
  egress {
    description = "MediaMTX to trusted streaming"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [var.trusted_vpc_cidrs["streaming"]]
  }

  # Outbound - HTTPS for updates/ECR
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - DNS
  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-trusted-scrub-sg"
  }
}

# Security Group for Trusted Streaming Host - FIXED SSH ACCESS
resource "aws_security_group" "trusted_streaming_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-streaming-sg"
  description = "Security group for Trusted Streaming Docker Host"
  vpc_id      = module.trusted_vpc_streaming.vpc_id

  # FIXED: SSH from VPN clients directly
  ingress {
    description = "SSH from trusted VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # SSH from trusted devops VPC
  ingress {
    description = "SSH from trusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpc_cidrs["devops"]]
  }

  # SRT UDP from trusted scrub
  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP from trusted scrub"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = [var.trusted_vpc_cidrs["streaming_scrub"]]
    }
  }

  # MediaMTX from trusted scrub
  ingress {
    description = "MediaMTX from trusted scrub"
    from_port   = var.peering_udp_port
    to_port     = var.peering_udp_port
    protocol    = "udp"
    cidr_blocks = [var.trusted_vpc_cidrs["streaming_scrub"]]
  }

  # Outbound - SSH to trusted VPCs
  egress {
    description = "SSH to trusted VPCs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  # Outbound - HTTPS for updates/ECR
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - DNS
  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-trusted-streaming-sg"
  }
}

# Security Group for Trusted DevOps Host - WORKING (Reference)
resource "aws_security_group" "trusted_agent_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-agent-sg"
  description = "Security group for Trusted DevOps Host"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  # SSH from trusted VPN clients
  ingress {
    description = "SSH from trusted VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # SSH from trusted devops VPC
  ingress {
    description = "SSH from trusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpc_cidrs["devops"]]
  }

  # Outbound - SSH to trusted VPCs
  egress {
    description = "SSH to trusted VPCs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  # Outbound - HTTPS for updates/ECR/ADO
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound - DNS
  egress {
    description = "DNS outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-trusted-agent-sg"
  }
}

# Security Group Rules for MediaMTX communication
resource "aws_security_group_rule" "trusted_scrub_port_50555_ingress" {
  provider          = aws.primary
  type              = "ingress"
  from_port         = var.peering_udp_port
  to_port           = var.peering_udp_port
  protocol          = "udp"
  cidr_blocks       = [var.trusted_vpc_cidrs["streaming"]]
  security_group_id = aws_security_group.trusted_scrub_sg.id
  description       = "UDP port ${var.peering_udp_port} from trusted streaming VPC"
}

resource "aws_security_group_rule" "trusted_streaming_port_50555_egress" {
  provider          = aws.primary
  type              = "egress"
  from_port         = var.peering_udp_port
  to_port           = var.peering_udp_port
  protocol          = "udp"
  cidr_blocks       = [var.trusted_vpc_cidrs["streaming_scrub"]]
  security_group_id = aws_security_group.trusted_streaming_sg.id
  description       = "UDP port ${var.peering_udp_port} to trusted scrub VPC"
}