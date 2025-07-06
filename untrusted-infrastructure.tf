################################################################################
# UNTRUSTED ENVIRONMENT - Infrastructure
################################################################################

module "untrusted_tgw" {
  source      = "./modules/tgw"
  providers   = { aws = aws.primary }
  name_prefix = "${var.project_name}-untrusted"
  description = "TGW for the Untrusted Environment"
  asn         = var.untrusted_asn
}

# --- Untrusted VPCs ---

module "untrusted_vpc_streaming_ingress" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-untrusted-streaming-ingress"
  cidr       = var.untrusted_vpc_cidrs["streaming_ingress"]
  azs        = ["${var.primary_region}a"]
  aws_region = var.primary_region
  tgw_id     = module.untrusted_tgw.tgw_id
  create_igw = true
  public_subnet_names  = ["ec2"]
  private_subnet_names = ["tgw-attach", "endpoints"]
  vpc_endpoints        = ["ecr.api", "ecr.dkr", "s3"]
}

module "untrusted_vpc_streaming_scrub" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-untrusted-streaming-scrub"
  cidr       = var.untrusted_vpc_cidrs["streaming_scrub"]
  azs        = ["${var.primary_region}a"]
  aws_region = var.primary_region
  tgw_id     = module.untrusted_tgw.tgw_id
  private_subnet_names = ["app", "tgw-attach", "endpoints"]
  vpc_endpoints        = ["ecr.api", "ecr.dkr", "s3"]
}

module "untrusted_vpc_devops" {
  source     = "./modules/vpc"
  providers  = { aws = aws.primary }
  name       = "${var.project_name}-untrusted-devops"
  cidr       = var.untrusted_vpc_cidrs["devops"]
  azs        = ["${var.primary_region}a"]
  aws_region = var.primary_region
  tgw_id     = module.untrusted_tgw.tgw_id
  create_igw = true
  public_subnet_names  = ["agent"]
  private_subnet_names = ["vpn", "tgw-attach", "endpoints"]
  vpc_endpoints        = ["ecr.api", "ecr.dkr"]
}

# --- Untrusted EC2 Instances ---

module "untrusted_ingress_host" {
  source              = "./modules/ec2_instance"
  providers           = { aws = aws.primary }
  instance_name       = "${var.project_name}-untrusted-ingress-host"
  key_name            = var.untrusted_ssh_key_name
  instance_os         = var.instance_os
  instance_type       = var.instance_types.untrusted_ingress
  subnet_id           = module.untrusted_vpc_streaming_ingress.public_subnets_by_name["ec2"].id
  vpc_id              = module.untrusted_vpc_streaming_ingress.vpc_id
  associate_public_ip = true
  enable_ecr_access   = true
  custom_ami_id       = var.use_custom_amis ? var.custom_standard_ami_id : null
  allowed_ssh_cidrs   = [var.untrusted_vpn_client_cidr]
  devops_vpc_cidr     = var.untrusted_vpc_cidrs["devops"]  # ADDED: DevOps VPC access
  allowed_udp_ports   = var.srt_udp_ports
  allowed_udp_cidrs   = ["0.0.0.0/0"]
  allowed_egress_udp_ports = [var.peering_udp_port]
  allowed_egress_udp_cidrs = [var.untrusted_vpc_cidrs["streaming_scrub"]]
  user_data = templatefile("${path.module}/templates/ecr-auto-login-userdata.sh", {
    aws_region       = var.primary_region
    ecr_registry_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.primary_region}.amazonaws.com"
  })
}

module "untrusted_scrub_host" {
  source            = "./modules/ec2_instance"
  providers         = { aws = aws.primary }
  instance_name     = "${var.project_name}-untrusted-scrub-host"
  key_name          = var.untrusted_ssh_key_name
  instance_os       = var.instance_os
  instance_type     = var.instance_types.untrusted_scrub
  subnet_id         = module.untrusted_vpc_streaming_scrub.private_subnets_by_name["app"].id
  vpc_id            = module.untrusted_vpc_streaming_scrub.vpc_id
  enable_ecr_access = true
  enable_ec2_describe = true
  custom_ami_id     = var.use_custom_amis ? var.custom_standard_ami_id : null
  allowed_ssh_cidrs = [var.untrusted_vpn_client_cidr]
  devops_vpc_cidr   = var.untrusted_vpc_cidrs["devops"]  # ADDED: DevOps VPC access
  allowed_udp_ports = [var.peering_udp_port]
  allowed_udp_cidrs = [var.untrusted_vpc_cidrs["streaming_ingress"]]
  allowed_egress_udp_ports = [var.peering_udp_port]
  allowed_egress_udp_cidrs = [var.trusted_vpc_cidrs["streaming_scrub"]]
  user_data = templatefile("${path.module}/templates/combined-scrub-userdata.sh", {
    trusted_scrub_vpc_cidr = var.trusted_vpc_cidrs["streaming_scrub"]
    aws_region            = var.primary_region
    trusted_host_tag_name = "${var.project_name}-trusted-scrub-host"
  })
}

module "untrusted_devops_host" {
  source            = "./modules/ec2_instance"
  providers         = { aws = aws.primary }
  instance_name     = "${var.project_name}-untrusted-devops-host"
  key_name          = var.untrusted_ssh_key_name
  instance_os       = var.instance_os
  instance_type     = var.instance_types.untrusted_devops
  subnet_id         = module.untrusted_vpc_devops.public_subnets_by_name["agent"].id
  vpc_id            = module.untrusted_vpc_devops.vpc_id
  enable_ecr_access = true
  associate_public_ip = true
  custom_ami_id     = var.use_custom_amis ? var.custom_standard_ami_id : null
  allowed_ssh_cidrs = [var.untrusted_vpn_client_cidr]
  devops_vpc_cidr   = var.untrusted_vpc_cidrs["devops"]  # ADDED: DevOps VPC access

  # user_data = var.enable_ado_agents ? templatefile("${path.module}/templates/ado-agent-userdata.sh", {
  #   aws_region                    = var.primary_region
  #   ecr_registry_url             = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.primary_region}.amazonaws.com"
  #   ado_organization_url         = var.ado_organization_url
  #   ado_agent_pool_name          = var.ado_agent_pool_name
  #   ado_pat_secret_name          = var.enable_ado_agents ? aws_secretsmanager_secret.ado_pat[0].name : ""
  #   deployment_ssh_key_secret_name = var.enable_auto_deployment ? aws_secretsmanager_secret.deployment_ssh_key[0].name : ""
  #   enable_auto_deployment       = var.enable_auto_deployment
  #   environment_type             = "untrusted"
  # }) : templatefile("${path.module}/templates/ecr-auto-login-userdata.sh", {
  #   aws_region       = var.primary_region
  #   ecr_registry_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.primary_region}.amazonaws.com"
  # })
}




resource "aws_iam_role_policy" "untrusted_devops_ecr_access" {
  name = "untrusted-devops-ecr-access"
  role = "${var.project_name}-untrusted-devops-host-role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          "arn:aws:ecr:${var.primary_region}:${data.aws_caller_identity.current.account_id}:repository/poc/untrusted-devops-images"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })

  depends_on = [module.untrusted_devops_host]
}

resource "aws_iam_role_policy" "untrusted_devops_ado_secrets" {
  count = var.enable_ado_agents ? 1 : 0
  name  = "ado-secrets-access"
  role  = "${var.project_name}-untrusted-devops-host-role"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = compact([
          var.enable_ado_agents ? aws_secretsmanager_secret.ado_pat[0].arn : "",
          var.enable_auto_deployment ? aws_secretsmanager_secret.deployment_ssh_key[0].arn : ""
        ])
      }
    ]
  })
  depends_on = [module.untrusted_devops_host, aws_secretsmanager_secret.ado_pat, aws_secretsmanager_secret.deployment_ssh_key]
}

data "aws_iam_role" "untrusted_devops_host_role" {
  count = var.enable_ado_agents ? 1 : 0
  name  = "${var.project_name}-untrusted-devops-host-role"
  depends_on = [module.untrusted_devops_host]
}