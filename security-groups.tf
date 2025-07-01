################################################################################
# Security Groups - All Environments
################################################################################

# Security Group for Untrusted VPN - UNTRUSTED ONLY (NO trusted access)
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
    cidr_blocks = values(var.untrusted_vpc_cidrs) # ONLY 172.17.x.x ranges
  }

  # Allow ONLY untrusted VPN client traffic
  ingress {
    description = "Allow ONLY untrusted VPN clients"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.untrusted_vpn_client_cidr] # ONLY 172.31.0.0/22
  }

  # Outbound ONLY to untrusted VPCs - NO trusted zone access
  egress {
    description = "Allow outbound ONLY to untrusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.untrusted_vpc_cidrs) # ONLY 172.17.x.x ranges
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

  # SSH access from VPN clients
  ingress {
    description = "SSH from VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  # SSH access from untrusted devops VPC
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

  # SSH access from VPN clients
  ingress {
    description = "SSH from VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  # SSH access from untrusted devops VPC
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

  # Allow all outbound traffic (includes UDP to trusted scrub via peering)
  egress {
    description = "All outbound traffic including UDP to trusted scrub"
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

  # SSH access from VPN clients
  ingress {
    description = "SSH from VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpn_client_cidr]
  }

  # SSH access from untrusted devops VPC (for internal communication)
  ingress {
    description = "SSH from untrusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.untrusted_vpc_cidrs["devops"]]
  }

  # Allow all outbound traffic to internet (includes ECR access)
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

# Security Group for Trusted VPN - COMPLETELY SEPARATE from untrusted
resource "aws_security_group" "trusted_vpn_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-vpn-sg"
  description = "Security group for Trusted Client VPN endpoint - NO untrusted access"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  # Allow inbound traffic ONLY from trusted VPCs - NO untrusted access
  ingress {
    description = "Allow access ONLY from trusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.trusted_vpc_cidrs) # ONLY 172.16.x.x ranges
  }

  # Allow ONLY trusted VPN client traffic - NO untrusted VPN clients
  ingress {
    description = "Allow ONLY trusted VPN clients"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.trusted_vpn_client_cidr] # ONLY 172.30.0.0/22
  }

  # Outbound - ONLY to trusted environment
  egress {
    description = "Allow outbound ONLY to trusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.trusted_vpc_cidrs) # ONLY 172.16.x.x ranges
  }

  tags = {
    Name = "${var.project_name}-trusted-vpn-sg"
  }
}

# Security Group for Trusted Scrub Host - ONLY receives UDP via peering
resource "aws_security_group" "trusted_scrub_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-scrub-sg"
  description = "Security group for Trusted Scrub EC2 instance - NO direct untrusted access"
  vpc_id      = module.trusted_vpc_streaming_scrub.vpc_id

  # SSH access ONLY from trusted VPN clients - NO untrusted VPN access
  ingress {
    description = "SSH ONLY from trusted VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr] # ONLY 172.30.0.0/22
  }

  # SSH access from trusted devops VPC
  ingress {
    description = "SSH from trusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpc_cidrs["devops"]]
  }

  # UDP streaming ONLY from untrusted scrub host via VPC peering (ONLY allowed connection)
  dynamic "ingress" {
    for_each = var.srt_udp_ports
    content {
      description = "SRT UDP from untrusted scrub via VPC peering ONLY"
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = [var.untrusted_vpc_cidrs["streaming_scrub"]]
    }
  }

  # Outbound - ONLY to trusted environment + peering return traffic
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

  # Allow all outbound to trusted VPCs only (no internet access)
  egress {
    description = "Outbound to trusted VPCs"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  tags = {
    Name = "${var.project_name}-trusted-streaming-sg"
  }
}

# Security Group for Trusted DevOps Agent - STRICTLY trusted environment
resource "aws_security_group" "trusted_agent_sg" {
  provider    = aws.primary
  name        = "${var.project_name}-trusted-agent-sg"
  description = "Security group for Trusted DevOps Agent - NO untrusted access"
  vpc_id      = module.trusted_vpc_devops.vpc_id

  # SSH access ONLY from trusted VPN clients
  ingress {
    description = "SSH ONLY from trusted VPN clients"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr] # ONLY 172.30.0.0/22
  }

  # SSH access from trusted devops VPC (for internal communication)
  ingress {
    description = "SSH from trusted devops VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpc_cidrs["devops"]]
  }

  # Outbound for internet access (ECR, package updates, etc.)
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

# --- Security Group Attachments ---

# Attach custom security groups to EC2 instances
data "aws_instance" "ingress" {
  provider    = aws.primary
  instance_id = module.untrusted_ingress_host.instance_id
  depends_on  = [module.untrusted_ingress_host]
}

resource "aws_network_interface_sg_attachment" "ingress_sg_attachment" {
  provider             = aws.primary
  security_group_id    = aws_security_group.untrusted_ingress_sg.id
  network_interface_id = data.aws_instance.ingress.network_interface_id
}

data "aws_instance" "scrub" {
  provider    = aws.primary
  instance_id = module.untrusted_scrub_host.instance_id
  depends_on  = [module.untrusted_scrub_host]
}

resource "aws_network_interface_sg_attachment" "scrub_sg_attachment" {
  provider             = aws.primary
  security_group_id    = aws_security_group.untrusted_scrub_sg.id
  network_interface_id = data.aws_instance.scrub.network_interface_id
}

data "aws_instance" "agent" {
  provider    = aws.primary
  instance_id = module.untrusted_devops_agent.instance_id
  depends_on  = [module.untrusted_devops_agent]
}

resource "aws_network_interface_sg_attachment" "agent_sg_attachment" {
  provider             = aws.primary
  security_group_id    = aws_security_group.untrusted_agent_sg.id
  network_interface_id = data.aws_instance.agent.network_interface_id
}

data "aws_instance" "trusted_scrub" {
  provider    = aws.primary
  instance_id = module.trusted_scrub_host.instance_id
  depends_on  = [module.trusted_scrub_host]
}

resource "aws_network_interface_sg_attachment" "trusted_scrub_sg_attachment" {
  provider             = aws.primary
  security_group_id    = aws_security_group.trusted_scrub_sg.id
  network_interface_id = data.aws_instance.trusted_scrub.network_interface_id
}

data "aws_instance" "trusted_agent" {
  provider    = aws.primary
  instance_id = module.trusted_devops_agent.instance_id
  depends_on  = [module.trusted_devops_agent]
}

resource "aws_network_interface_sg_attachment" "trusted_agent_sg_attachment" {
  provider             = aws.primary
  security_group_id    = aws_security_group.trusted_agent_sg.id
  network_interface_id = data.aws_instance.trusted_agent.network_interface_id
}

# Security group attachments for trusted streaming instance
data "aws_instance" "trusted_streaming" {
  provider    = aws.primary
  instance_id = module.trusted_streaming_host.instance_id
  depends_on  = [module.trusted_streaming_host]
}

resource "aws_network_interface_sg_attachment" "trusted_streaming_sg_attachment" {
  provider             = aws.primary
  security_group_id    = aws_security_group.trusted_streaming_sg.id
  network_interface_id = data.aws_instance.trusted_streaming.network_interface_id
}

# --- Additional Security Group Rules for Instance Module Security Groups ---
# These fix the SSH access issues by adding rules to the instance module created security groups

# Get the instance module security group IDs using data sources
data "aws_security_groups" "trusted_scrub_host_sg" {
  provider = aws.primary
  filter {
    name   = "group-name"
    values = ["${var.project_name}-trusted-scrub-host-sg"]
  }
}

data "aws_security_groups" "trusted_streaming_host_sg" {
  provider = aws.primary
  filter {
    name   = "group-name"
    values = ["${var.project_name}-trusted-streaming-host-sg"]
  }
}

# Add SSH rules to trusted scrub host security group (from instance module)
resource "aws_security_group_rule" "trusted_scrub_host_ssh_vpn" {
  provider          = aws.primary
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.trusted_vpn_client_cidr]
  security_group_id = data.aws_security_groups.trusted_scrub_host_sg.ids[0]
  description       = "SSH from trusted VPN clients"
}

resource "aws_security_group_rule" "trusted_scrub_host_ssh_devops" {
  provider          = aws.primary
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.trusted_vpc_cidrs["devops"]]
  security_group_id = data.aws_security_groups.trusted_scrub_host_sg.ids[0]
  description       = "SSH from trusted devops VPC"
}

# Add SSH rules to trusted streaming host security group (from instance module)
resource "aws_security_group_rule" "trusted_streaming_host_ssh_vpn" {
  provider          = aws.primary
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.trusted_vpn_client_cidr]
  security_group_id = data.aws_security_groups.trusted_streaming_host_sg.ids[0]
  description       = "SSH from trusted VPN clients"
}

resource "aws_security_group_rule" "trusted_streaming_host_ssh_devops" {
  provider          = aws.primary
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.trusted_vpc_cidrs["devops"]]
  security_group_id = data.aws_security_groups.trusted_streaming_host_sg.ids[0]
  description       = "SSH from trusted devops VPC"
}