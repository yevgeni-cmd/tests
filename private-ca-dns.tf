# Enhanced Terraform configuration for Private CA + Custom Domain Names
# Add this to a new file: private-ca-dns.tf

################################################################################
# AWS Private Certificate Authority (CA)
################################################################################

# Create Private CA
resource "aws_acmpca_certificate_authority" "internal_ca" {
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

# Get CA Certificate Signing Request
data "aws_acmpca_certificate_authority" "internal_ca" {
  provider = aws.primary
  arn      = aws_acmpca_certificate_authority.internal_ca.arn
}

# Issue Root Certificate for the CA
resource "aws_acmpca_certificate" "internal_ca_root" {
  provider                  = aws.primary
  certificate_authority_arn = aws_acmpca_certificate_authority.internal_ca.arn
  certificate_signing_request = aws_acmpca_certificate_authority.internal_ca.certificate_signing_request
  signing_algorithm         = "SHA256WITHRSA"
  template_arn             = "arn:aws:acm-pca:::template/RootCACertificate/V1"

  validity {
    type  = "YEARS"
    value = 10
  }
}

# Import Root Certificate to CA
resource "aws_acmpca_certificate_authority_certificate" "internal_ca_root" {
  provider                  = aws.primary
  certificate_authority_arn = aws_acmpca_certificate_authority.internal_ca.arn
  certificate              = aws_acmpca_certificate.internal_ca_root.certificate
  certificate_chain        = aws_acmpca_certificate.internal_ca_root.certificate_chain
}

################################################################################
# Request Certificates from Private CA
################################################################################

# Certificate for IoT services
resource "aws_acm_certificate" "iot_internal" {
  provider                  = aws.primary
  domain_name              = "iot.${var.internal_domain}"
  certificate_authority_arn = aws_acmpca_certificate_authority.internal_ca.arn
  
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
  provider                  = aws.primary
  domain_name              = "streaming.${var.internal_domain}"
  certificate_authority_arn = aws_acmpca_certificate_authority.internal_ca.arn
  
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
# Route53 Private Hosted Zones
################################################################################

# Private hosted zone for internal domain
resource "aws_route53_zone" "internal" {
  provider = aws.primary
  name     = var.internal_domain
  comment  = "Private hosted zone for ${var.project_name} internal services"

  vpc {
    vpc_id = module.trusted_vpc_devops.vpc_id
  }

  # Associate with all trusted VPCs
  dynamic "vpc" {
    for_each = {
      iot       = module.trusted_vpc_iot.vpc_id
      streaming = module.trusted_vpc_streaming.vpc_id
      jacob     = module.trusted_vpc_jacob.vpc_id
      scrub     = module.trusted_vpc_streaming_scrub.vpc_id
    }
    content {
      vpc_id = vpc.value
    }
  }

  tags = {
    Name        = "${var.project_name}-internal-zone"
    Environment = "shared"
    Purpose     = "Internal DNS resolution"
  }
}

# DNS Records for IoT services
resource "aws_route53_record" "iot_main" {
  provider = aws.primary
  zone_id  = aws_route53_zone.internal.zone_id
  name     = "iot.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.iot_application_load_balancer.alb_dns_name
    zone_id                = module.iot_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "iot_api" {
  provider = aws.primary
  zone_id  = aws_route53_zone.internal.zone_id
  name     = "api.iot.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.iot_application_load_balancer.alb_dns_name
    zone_id                = module.iot_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "iot_dashboard" {
  provider = aws.primary
  zone_id  = aws_route53_zone.internal.zone_id
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
  provider = aws.primary
  zone_id  = aws_route53_zone.internal.zone_id
  name     = "streaming.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.streaming_application_load_balancer.alb_dns_name
    zone_id                = module.streaming_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "streaming_api" {
  provider = aws.primary
  zone_id  = aws_route53_zone.internal.zone_id
  name     = "api.streaming.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.streaming_application_load_balancer.alb_dns_name
    zone_id                = module.streaming_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "streaming_player" {
  provider = aws.primary
  zone_id  = aws_route53_zone.internal.zone_id
  name     = "player.streaming.${var.internal_domain}"
  type     = "A"

  alias {
    name                   = module.streaming_application_load_balancer.alb_dns_name
    zone_id                = module.streaming_application_load_balancer.alb_zone_id
    evaluate_target_health = true
  }
}

################################################################################
# Output the CA certificate for client installation
################################################################################

output "internal_ca_certificate" {
  description = "Internal CA certificate for client installation"
  value       = aws_acmpca_certificate.internal_ca_root.certificate
  sensitive   = false
}

output "internal_domain_services" {
  description = "Available internal domain services"
  value = {
    iot_dashboard = "https://dashboard.iot.${var.internal_domain}/"
    iot_api      = "https://api.iot.${var.internal_domain}/api"
    streaming_player = "https://player.streaming.${var.internal_domain}/"
    streaming_api = "https://api.streaming.${var.internal_domain}/api"
    main_iot     = "https://iot.${var.internal_domain}/"
    main_streaming = "https://streaming.${var.internal_domain}/"
  }
}