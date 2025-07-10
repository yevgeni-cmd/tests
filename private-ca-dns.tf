# private-ca-dns.tf - PROPERLY ALIGNED VERSION
################################################################################
# AWS Private Certificate Authority (CA) - CONDITIONAL CREATION
################################################################################

# Create Private CA - ONLY when enable_private_ca = true
resource "aws_acmpca_certificate_authority" "internal_ca" {
  count    = var.enable_private_ca ? 1 : 0
  provider = aws.primary
  
  certificate_authority_configuration {
    key_algorithm     = "RSA_2048"
    signing_algorithm = "SHA256WITHRSA"

    subject {
      country                = "IL"
      organization           = var.organization_name
      organizational_unit    = "IT Security"
      common_name           = "${var.project_name} Internal Root CA"
      locality              = "Tel Aviv"
      state                 = "Israel"
    }
  }

  enabled                         = true
  permanent_deletion_time_in_days = 7
  type                           = "ROOT"

  tags = {
    Name        = "${var.project_name}-internal-ca"
    Environment = "shared"
    Purpose     = "Internal certificate authority"
  }
}

# Issue Root Certificate for the CA - CONDITIONAL
resource "aws_acmpca_certificate" "internal_ca_root" {
  count                     = var.enable_private_ca ? 1 : 0
  provider                  = aws.primary
  certificate_authority_arn = aws_acmpca_certificate_authority.internal_ca[0].arn
  certificate_signing_request = aws_acmpca_certificate_authority.internal_ca[0].certificate_signing_request
  signing_algorithm         = "SHA256WITHRSA"
  template_arn             = "arn:aws:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = var.ca_validity_years
  }
}

# Import Root Certificate to CA - CONDITIONAL
resource "aws_acmpca_certificate_authority_certificate" "internal_ca_root" {
  count                     = var.enable_private_ca ? 1 : 0
  provider                  = aws.primary
  certificate_authority_arn = aws_acmpca_certificate_authority.internal_ca[0].arn
  certificate              = aws_acmpca_certificate.internal_ca_root[0].certificate
  certificate_chain        = aws_acmpca_certificate.internal_ca_root[0].certificate_chain
}

################################################################################
# Request Certificates from Private CA - CONDITIONAL
################################################################################

# Certificate for IoT services
resource "aws_acm_certificate" "iot_internal" {
  count                     = var.enable_private_ca ? 1 : 0
  provider                  = aws.primary
  domain_name              = "iot.${var.internal_domain}"
  certificate_authority_arn = aws_acmpca_certificate_authority.internal_ca[0].arn
  
  subject_alternative_names = [
    "*.iot.${var.internal_domain}",
    "api.iot.${var.internal_domain}",
    "dashboard.iot.${var.internal_domain}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-iot-certificate"
    Environment = var.environment_tags.trusted
    Purpose     = "IoT services SSL certificate"
  }

  depends_on = [aws_acmpca_certificate_authority_certificate.internal_ca_root]
}

# Certificate for Streaming services
resource "aws_acm_certificate" "streaming_internal" {
  count                     = var.enable_private_ca ? 1 : 0
  provider                  = aws.primary
  domain_name              = "streaming.${var.internal_domain}"
  certificate_authority_arn = aws_acmpca_certificate_authority.internal_ca[0].arn
  
  subject_alternative_names = [
    "*.streaming.${var.internal_domain}",
    "api.streaming.${var.internal_domain}",
    "player.streaming.${var.internal_domain}",
    "admin.streaming.${var.internal_domain}"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-streaming-certificate"
    Environment = var.environment_tags.trusted
    Purpose     = "Streaming services SSL certificate"
  }

  depends_on = [aws_acmpca_certificate_authority_certificate.internal_ca_root]
}

################################################################################
# Route53 Private DNS - CONDITIONAL
################################################################################

# Private hosted zone for internal domain
resource "aws_route53_zone" "internal" {
  count    = var.enable_private_ca ? 1 : 0
  provider = aws.primary
  name     = var.internal_domain
  comment  = "Private hosted zone for ${var.project_name} internal services"

  vpc {
    vpc_id = module.trusted_vpc_devops.vpc_id
  }

  tags = {
    Name        = "${var.project_name}-internal-zone"
    Environment = "shared"
    Purpose     = "Internal DNS resolution"
  }
}

# Route53 Resolver Endpoint for DNS forwarding
resource "aws_route53_resolver_endpoint" "inbound" {
  count     = var.enable_private_ca ? 1 : 0
  provider  = aws.primary
  name      = "${var.project_name}-resolver-inbound"
  direction = "INBOUND"

  security_group_ids = [aws_security_group.resolver[0].id]

  # Use IoT ALB subnets which are guaranteed to be in different AZs
  ip_address {
    subnet_id = module.trusted_vpc_iot.private_subnets_by_name["alb-az-a"].id
  }

  ip_address {
    subnet_id = module.trusted_vpc_iot.private_subnets_by_name["alb-az-b"].id
  }

  tags = {
    Name = "${var.project_name}-resolver-inbound"
  }
}

# Security Group for Route53 Resolver
resource "aws_security_group" "resolver" {
  count       = var.enable_private_ca ? 1 : 0
  provider    = aws.primary
  name        = "${var.project_name}-resolver-sg"
  description = "Security group for Route53 Resolver"
  vpc_id      = module.trusted_vpc_iot.vpc_id

  # Allow DNS TCP traffic from all trusted VPCs
  ingress {
    description = "DNS TCP from trusted VPCs"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  # Allow DNS UDP traffic from all trusted VPCs
  ingress {
    description = "DNS UDP from trusted VPCs"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = values(var.trusted_vpc_cidrs)
  }

  # Allow VPN client DNS queries
  ingress {
    description = "DNS from VPN clients"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  ingress {
    description = "DNS from VPN clients"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.trusted_vpn_client_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-resolver-sg"
  }
}

# The private hosted zone automatically handles DNS for associated VPCs

# Associate private zone with all trusted VPCs
resource "aws_route53_zone_association" "trusted_vpcs" {
  for_each = var.enable_private_ca ? {
    iot       = module.trusted_vpc_iot.vpc_id
    streaming = module.trusted_vpc_streaming.vpc_id
    jacob     = module.trusted_vpc_jacob.vpc_id
    scrub     = module.trusted_vpc_streaming_scrub.vpc_id
  } : {}

  provider = aws.primary
  zone_id  = aws_route53_zone.internal[0].zone_id
  vpc_id   = each.value
}

################################################################################
# DNS Records for Services
################################################################################

# DNS Records for IoT services
resource "aws_route53_record" "iot_main" {
  count    = var.enable_private_ca ? 1 : 0
  provider = aws.primary
  zone_id  = aws_route53_zone.internal[0].zone_id
  name     = "iot.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.iot_application_load_balancer.alb_dns_name
    zone_id                = module.iot_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "iot_api" {
  count    = var.enable_private_ca ? 1 : 0
  provider = aws.primary
  zone_id  = aws_route53_zone.internal[0].zone_id
  name     = "api.iot.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.iot_application_load_balancer.alb_dns_name
    zone_id                = module.iot_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "iot_dashboard" {
  count    = var.enable_private_ca ? 1 : 0
  provider = aws.primary
  zone_id  = aws_route53_zone.internal[0].zone_id
  name     = "dashboard.iot.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.iot_application_load_balancer.alb_dns_name
    zone_id                = module.iot_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

# DNS Records for Streaming services
resource "aws_route53_record" "streaming_main" {
  count    = var.enable_private_ca ? 1 : 0
  provider = aws.primary
  zone_id  = aws_route53_zone.internal[0].zone_id
  name     = "streaming.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.streaming_application_load_balancer.alb_dns_name
    zone_id                = module.streaming_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "streaming_api" {
  count    = var.enable_private_ca ? 1 : 0
  provider = aws.primary
  zone_id  = aws_route53_zone.internal[0].zone_id
  name     = "api.streaming.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.streaming_application_load_balancer.alb_dns_name
    zone_id                = module.streaming_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "streaming_player" {
  count    = var.enable_private_ca ? 1 : 0
  provider = aws.primary
  zone_id  = aws_route53_zone.internal[0].zone_id
  name     = "player.streaming.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.streaming_application_load_balancer.alb_dns_name
    zone_id                = module.streaming_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

################################################################################
# Outputs
################################################################################

output "internal_ca_certificate" {
  description = "Internal CA certificate for client installation"
  value       = var.enable_private_ca ? aws_acmpca_certificate.internal_ca_root[0].certificate : null
  sensitive   = false
}

output "internal_ca_certificate_chain" {
  description = "Internal CA certificate chain"
  value       = var.enable_private_ca ? aws_acmpca_certificate.internal_ca_root[0].certificate_chain : null
  sensitive   = false
}

output "internal_domain_services" {
  description = "Available internal domain services"
  value = var.enable_private_ca ? {
    iot_dashboard    = "https://dashboard.iot.${var.internal_domain}/"
    iot_api         = "https://api.iot.${var.internal_domain}/api"
    streaming_player = "https://player.streaming.${var.internal_domain}/"
    streaming_api   = "https://api.streaming.${var.internal_domain}/api"
    main_iot        = "https://iot.${var.internal_domain}/"
    main_streaming  = "https://streaming.${var.internal_domain}/"
  } : {}
}

output "dns_setup_instructions" {
  description = "Instructions for DNS setup and certificate installation"
  value = var.enable_private_ca ? [
    "=== DNS Setup Instructions ===",
    "1. Install the CA certificate on client machines:",
    "   terraform output internal_ca_certificate > sky-ca.crt",
    "   # Install sky-ca.crt in your OS trusted root store",
    "",
    "2. Test DNS resolution (from VPN connected machine):",
    "   nslookup iot.${var.internal_domain}",
    "   nslookup streaming.${var.internal_domain}",
    "",
    "3. Access services via HTTPS:",
    "   curl -v https://iot.${var.internal_domain}/",
    "   curl -v https://streaming.${var.internal_domain}/",
    "",
    "4. If HTTPS doesn't work immediately, try HTTP:",
    "   curl -v http://iot.${var.internal_domain}/",
    "   curl -v http://streaming.${var.internal_domain}/",
    "",
    "Note: DNS resolution works automatically within VPCs via Route53 private zones"
  ] : [
    "=== HTTP-Only Mode ===",
    "Private CA is disabled. Services available via ALB DNS names only:",
    "1. Get ALB DNS names: terraform output iot_infrastructure",
    "2. Access via HTTP: curl -v http://<alb-dns-name>/"
  ]
}