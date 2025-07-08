terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_ami" "selected" {
  count       = var.custom_ami_id != null ? 0 : 1
  most_recent = true
  owners      = [var.ami_owners[var.instance_os]]

  filter {
    name   = "name"
    values = [var.ami_filters[var.instance_os]]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = var.custom_ami_id != null ? var.custom_ami_id : data.aws_ami.selected[0].id
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.instance_name}-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_policy" {
  count      = var.enable_ecr_access ? 1 : 0
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy" "ec2_describe_policy" {
  count = var.enable_ec2_describe ? 1 : 0
  name  = "${var.instance_name}-ec2-describe-policy"
  role  = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.instance_name}-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "this" {
  name   = "${var.instance_name}-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {
    for_each = toset(var.allowed_udp_ports)
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "udp"
      cidr_blocks = var.allowed_udp_cidrs
    }
  }

  # FIXED: SSH access from VPN clients AND DevOps VPC (for VPN NAT)
  dynamic "ingress" {
    for_each = toset(var.allowed_ssh_cidrs)
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # FIXED: Add DevOps VPC access for VPN NAT traffic
  dynamic "ingress" {
    for_each = var.devops_vpc_cidr != null ? ["devops"] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.devops_vpc_cidr]
      description = "SSH from DevOps VPC (VPN NAT)"
    }
  }

  # FIXED: Full internet access for DevOps and management hosts
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Full internet access"
  }

  dynamic "egress" {
    for_each = toset(var.allowed_egress_udp_ports)
    content {
      from_port   = egress.value
      to_port     = egress.value
      protocol    = "udp"
      cidr_blocks = var.allowed_egress_udp_cidrs
      description = "UDP egress to specific CIDRs"
    }
  }

  tags = { Name = "${var.instance_name}-sg" }
}

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = var.associate_public_ip
  user_data                   = var.user_data

  tags = { Name = var.instance_name }

  # FIXED: Only ignore the configurable attribute, not computed ones
  lifecycle {
    ignore_changes = [
      associate_public_ip_address
    ]
  }
}

### DEBUG 
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}