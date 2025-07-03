terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  create_public_rt      = length(var.public_subnet_names) > 0 && (var.create_igw || var.create_nat_gateway)
  has_tgw_attach_subnet = contains(var.private_subnet_names, "tgw-attach")

  # Enhanced CIDR calculation with multi-AZ support
  private_subnet_cidrs = {
    for i, name in var.private_subnet_names :
    name => cidrsubnet(var.cidr, 3, i)
  }

  public_subnet_cidrs = {
    for i, name in var.public_subnet_names :
    name => cidrsubnet(var.cidr, 3, i + length(var.private_subnet_names))
  }

  # AZ distribution logic - distribute subnets across available AZs
  private_subnet_azs = {
    for i, name in var.private_subnet_names :
    name => var.azs[i % length(var.azs)]
  }

  public_subnet_azs = {
    for i, name in var.public_subnet_names :
    name => var.azs[i % length(var.azs)]
  }
}

# ------------------ VPC & Core ------------------
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

resource "aws_internet_gateway" "this" {
  count  = var.create_igw || var.create_nat_gateway ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = { Name = "igw-${var.name}" }
}

resource "aws_eip" "nat" {
  count      = var.create_nat_gateway ? 1 : 0
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
  tags       = { Name = "eip-nat-${var.name}" }
}

# ------------------ Subnets ------------------
resource "aws_subnet" "public" {
  count = length(var.public_subnet_names)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[var.public_subnet_names[count.index]]
  availability_zone       = local.public_subnet_azs[var.public_subnet_names[count.index]]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name}-${var.public_subnet_names[count.index]}"
    Type = "public"
    AZ   = local.public_subnet_azs[var.public_subnet_names[count.index]]
  }
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_names)

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnet_cidrs[var.private_subnet_names[count.index]]
  availability_zone = local.private_subnet_azs[var.private_subnet_names[count.index]]

  tags = {
    Name = "${var.name}-${var.private_subnet_names[count.index]}"
    Type = "private"
    AZ   = local.private_subnet_azs[var.private_subnet_names[count.index]]
  }
}

# ------------------ Route Tables ------------------

# Public Route Table - for agent subnet (needs internet access)
resource "aws_route_table" "public" {
  count  = local.create_public_rt ? 1 : 0
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = { Name = "rt-${var.name}-public" }
}

# Private Route Table - for VPN, TGW-attach, and endpoints subnets
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_names) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  # Only add NAT gateway route if NAT gateway is created
  dynamic "route" {
    for_each = var.create_nat_gateway ? ["nat"] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat[0].id
    }
  }

  tags = { Name = "rt-${var.name}-private" }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = local.create_public_rt ? length(var.public_subnet_names) : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_names)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# ------------------ NAT Gateway ------------------
resource "aws_nat_gateway" "nat" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = length(aws_subnet.public) > 0 ? aws_subnet.public[0].id : null
  depends_on    = [aws_route_table_association.public]
  tags          = { Name = "nat-${var.name}" }
}

# ------------------ VPC Endpoints ------------------

# Separate S3 endpoints (Gateway type) from other endpoints (Interface type)
locals {
  gateway_endpoints   = [for endpoint in var.vpc_endpoints : endpoint if contains(["s3", "dynamodb"], endpoint)]
  interface_endpoints = [for endpoint in var.vpc_endpoints : endpoint if !contains(["s3", "dynamodb"], endpoint)]
}

# Data source for Gateway endpoints (S3, DynamoDB)
data "aws_vpc_endpoint_service" "gateway" {
  for_each = toset(local.gateway_endpoints)
  service  = each.value
  filter {
    name   = "service-type"
    values = ["Gateway"]
  }
}

# Data source for Interface endpoints (ECR, SQS, etc.)
data "aws_vpc_endpoint_service" "interface" {
  for_each = toset(local.interface_endpoints)
  service  = each.value
  filter {
    name   = "service-type"
    values = ["Interface"]
  }
}

resource "aws_security_group" "vpc_endpoints" {
  count       = length(local.interface_endpoints) > 0 ? 1 : 0
  name        = "${var.name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-vpc-endpoints-sg"
  }
}

# Create Gateway VPC endpoints (S3, DynamoDB)
resource "aws_vpc_endpoint" "gateway" {
  for_each = toset(local.gateway_endpoints)

  vpc_id            = aws_vpc.this.id
  service_name      = data.aws_vpc_endpoint_service.gateway[each.value].service_name
  vpc_endpoint_type = "Gateway"
  route_table_ids   = compact([
    length(aws_route_table.public) > 0 ? aws_route_table.public[0].id : null,
    length(aws_route_table.private) > 0 ? aws_route_table.private[0].id : null
  ])

  tags = {
    Name = "${var.name}-${each.value}-gateway-endpoint"
  }

  depends_on = [aws_route_table.public, aws_route_table.private]
}

# Create Interface VPC endpoints (ECR, SQS, etc.)
resource "aws_vpc_endpoint" "interface" {
  for_each = toset(local.interface_endpoints)

  vpc_id              = aws_vpc.this.id
  service_name        = data.aws_vpc_endpoint_service.interface[each.value].service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [for s in aws_subnet.private : s.id if endswith(s.tags.Name, "-endpoints")]
  security_group_ids  = length(aws_security_group.vpc_endpoints) > 0 ? [aws_security_group.vpc_endpoints[0].id] : []
  private_dns_enabled = true

  tags = {
    Name = "${var.name}-${each.value}-interface-endpoint"
  }

  depends_on = [
    aws_vpc.this,
    aws_subnet.private, 
    aws_security_group.vpc_endpoints,
    aws_route_table.private
  ]

  lifecycle {
    precondition {
      condition = aws_vpc.this.enable_dns_support == true && aws_vpc.this.enable_dns_hostnames == true
      error_message = "VPC must have DNS support and DNS hostnames enabled for Private DNS to work on VPC endpoints."
    }
  }
}

# Optional: Create Route53 private hosted zone for custom DNS resolution
resource "aws_route53_zone" "vpc_endpoints" {
  count = length(local.interface_endpoints) > 0 && var.create_custom_dns ? 1 : 0
  name  = "${var.aws_region}.amazonaws.com"

  vpc {
    vpc_id = aws_vpc.this.id
  }

  tags = {
    Name = "${var.name}-vpc-endpoints-zone"
  }
}

# Create DNS records for each VPC endpoint
resource "aws_route53_record" "vpc_endpoint_dns" {
  for_each = var.create_custom_dns ? toset(local.interface_endpoints) : []

  zone_id = aws_route53_zone.vpc_endpoints[0].zone_id
  name    = "${each.value}.${var.aws_region}.amazonaws.com"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.interface[each.value].dns_entry[0].dns_name
    zone_id                = aws_vpc_endpoint.interface[each.value].dns_entry[0].hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_vpc_endpoint.interface]
}

# ------------------ TGW Attachment (optional) ------------------
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count              = local.has_tgw_attach_subnet ? 1 : 0
  subnet_ids         = [for s in aws_subnet.private : s.id if endswith(s.tags.Name, "-tgw-attach")]
  transit_gateway_id = var.tgw_id
  vpc_id             = aws_vpc.this.id
  tags               = { Name = "tgw-attach-${var.name}" }

  lifecycle {
    precondition {
      condition     = var.tgw_id != null && var.tgw_id != ""
      error_message = "You defined a 'tgw-attach' subnet but var.tgw_id is empty."
    }
  }
}