terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_caller_identity" "current" {}

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
  count  = var.create_nat_gateway ? 1 : 0
  domain = "vpc"
  tags   = { Name = "eip-nat-${var.name}" }
}

resource "aws_subnet" "this" {
  for_each = var.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr, 3, each.value.cidr_suffix)
  availability_zone       = each.value.az != null ? each.value.az : element(var.azs, each.value.cidr_suffix % length(var.azs))
  map_public_ip_on_launch = each.value.type == "public" ? true : false
  
  tags = {
    Name = "${var.name}-${each.value.name}"
  }
}

# --- Corrected Route Table Associations to break dependency cycles ---
resource "aws_route_table_association" "public" {
  for_each = { for k, v in var.subnets : k => v if v.type == "public" }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table_association" "private" {
  for_each = { for k, v in var.subnets : k => v if v.type == "private" }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.private[0].id
}

resource "aws_nat_gateway" "nat" {
  count         = var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.this["public"].id
  depends_on    = [aws_route_table_association.public]
  tags          = { Name = "nat-${var.name}" }
}

resource "aws_route_table" "public" {
  count  = length([for s in var.subnets : s if s.type == "public"]) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id
  
  dynamic "route" {
    for_each = var.create_igw || var.create_nat_gateway ? ["igw"] : []
    content {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.this[0].id
    }
  }

  dynamic "route" {
    for_each = var.tgw_routes
    content {
      cidr_block         = each.value
      transit_gateway_id = var.tgw_id
    }
  }
  
  tags = { Name = "rt-${var.name}-public" }
}

resource "aws_route_table" "private" {
  count  = length([for s in var.subnets : s if s.type == "private"]) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id
  
  dynamic "route" {
    for_each = var.create_nat_gateway ? ["nat"] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat[0].id
    }
  }

  dynamic "route" {
    for_each = var.tgw_routes
    content {
      cidr_block         = each.value
      transit_gateway_id = var.tgw_id
    }
  }

  tags = { Name = "rt-${var.name}-private" }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count              = var.tgw_id != null && contains(keys(var.subnets), "tgw") ? 1 : 0
  subnet_ids         = [aws_subnet.this["tgw"].id]
  transit_gateway_id = var.tgw_id
  vpc_id             = aws_vpc.this.id
  tags               = { Name = "tgw-attach-${var.name}" }
}

data "aws_iam_policy_document" "vpc_endpoint_policy" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["*"]
    resources = ["*"]
  }
}

resource "aws_vpc_endpoint" "this" {
  for_each = toset(var.vpc_endpoints)

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = each.key == "s3" ? "Gateway" : "Interface"
  subnet_ids          = each.key == "s3" ? null : [aws_subnet.this["endpoints"].id]
  route_table_ids     = each.key == "s3" && length(aws_route_table.private) > 0 ? [aws_route_table.private[0].id] : null
  private_dns_enabled = each.key == "s3" ? null : true
  policy              = data.aws_iam_policy_document.vpc_endpoint_policy.json
  
  tags = { Name = "vpce-${var.name}-${replace(each.key, ".", "-")}" }
}

resource "aws_network_acl" "this" {
  count      = var.manage_nacl ? 1 : 0
  vpc_id     = aws_vpc.this.id
  subnet_ids = [for s in aws_subnet.this : s.id if contains(keys(var.subnets), "app")]

  dynamic "ingress" {
    for_each = toset(var.nacl_udp_ports)
    content {
      protocol   = "17"
      rule_no    = 100 + ingress.key
      action     = "allow"
      cidr_block = "0.0.0.0/0"
      from_port  = ingress.value
      to_port    = ingress.value
    }
  }
  
  ingress {
    protocol   = "6"
    rule_no    = 200
    action     = "allow"
    cidr_block = var.nacl_ssh_source_cidr
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "6"
    rule_no    = 210
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = { Name = "${var.name}-nacl" }
}
