################################################################################
# Security Groups - All Environments (Cleaned)
################################################################################

# Security Group for Untrusted VPN
resource "aws_security_group" "untrusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-vpn-sg"
  description = "Security group for Client VPN endpoint - UNTRUSTED ONLY"
  vpc_id      = module.untrusted_vpc_devops.vpc_id

  # Allow inbound traffic ONLY from untrusted VPCs
  ingress {
    description = "Allow access ONLY from untrusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.untrusted_vpc_cidrs)
  }

  # Allow ONLY untrusted VPN client traffic
  ingress {
    description = "Allow ONLY untrusted VPN clients"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  # Outbound ONLY to untrusted VPCs
  egress {
    description = "Allow outbound ONLY to untrusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.untrusted_vpc_cidrs)
  }

  # Internet access for management
  egress {
    description = "Internet access for management"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-untrusted-vpn-sg"
  }
}

# Security Group for Streaming Ingress Host
resource "aws_security_group" "untrusted_ingress_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-ingress-sg"
  description = "Security group for Streaming Ingress EC2 instance"
  vpc_id      = module.untrusted_vpc_streaming_ingress.vpc_id

  # SSH from VPN clients and untrusted VPCs
  ingress {
    description = "SSH from VPN clients and untrusted VPCs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = concat([var.untrusted_vpn_client_cidr], values(var.untrusted_vpc_cidrs))
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

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-untrusted-ingress-sg"
  }
}

# Security Group for Streaming Scrub Host
resource "aws_security_group" "untrusted_scrub_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-untrusted-scrub-sg"
  description = "Security group for Streaming Scrub EC2 instance"
  vpc_id      = module.untrusted_vpc_streaming_scrub.vpc_id

  # SSH from VPN clients and untrusted VPCs
  ingress {
    description = "SSH from VPN clients and untrusted VPCs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = concat([var.untrusted_vpn_client_cidr], values(var.untrusted_vpc_cidrs))
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

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
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

  # SSH from VPN clients and untrusted VPCs
  ingress {
    description = "SSH from VPN clients and untrusted VPCs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = concat([var.untrusted_vpn_client_cidr], values(var.untrusted_vpc_cidrs))
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

  # Allow inbound traffic ONLY from trusted VPCs
  ingress {
    description = "Allow access ONLY from trusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  # Allow ONLY trusted VPN client traffic
  ingress {
    description = "Allow ONLY trusted VPN clients"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # Outbound - ONLY to trusted environment
  egress {
    description = "Allow outbound ONLY to trusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  # Internet access
  egress {
    description = "Internet access"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  # SSH access from trusted VPN clients
  ingress {
    description = "SSH from trusted VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # SSH access from trusted devops VPC
  ingress {
    description = "SSH from trusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpc_cidrs["devops"]]
  }

  # UDP streaming from untrusted scrub via VPC peering
  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP from untrusted scrub via VPC peering"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = [var.untrusted_vpc_cidrs["streaming_scrub"]]
    }
  }

  # Outbound to trusted environment + peering return traffic
  egress {
    description = "Outbound to trusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  # Allow return traffic via peering
  egress {
    description = "Return traffic via VPC peering"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.untrusted_vpc_cidrs["streaming_scrub"]]
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

  # SSH access from trusted VPN clients
  ingress {
    description = "SSH from trusted VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # SSH access from trusted devops VPC
  ingress {
    description = "SSH from trusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpc_cidrs["devops"]]
  }

  # Allow outbound to trusted VPCs and internet
  egress {
    description = "All outbound traffic"
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

  # SSH access from trusted VPN clients
  ingress {
    description = "SSH from trusted VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  # SSH access from trusted devops VPC
  ingress {
    description = "SSH from trusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpc_cidrs["devops"]]
  }

  # Outbound for internet access
  egress {
    description = "Internet access for CI/CD operations"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-trusted-agent-sg"
  }
}