# Azure DevOps Personal Access Token Secret
resource "aws_secretsmanager_secret" "ado_pat" {
  count       = var.enable_ado_agents ? 1 : 0
  name        = "${var.project_name}-ado-pat"
  description = "Azure DevOps Personal Access Token for self-hosted agents"
  
  tags = {
    Name        = "${var.project_name}-ado-pat"
    Purpose     = "ado-agent-authentication"
    Environment = "shared"
  }
}

# FIXED: Add secret version with placeholder - must be updated manually
resource "aws_secretsmanager_secret_version" "ado_pat" {
  count         = var.enable_ado_agents ? 1 : 0
  secret_id     = aws_secretsmanager_secret.ado_pat[0].id
  secret_string = "PLACEHOLDER_SET_YOUR_ADO_PAT_HERE"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# Deployment SSH Private Key Secret
resource "aws_secretsmanager_secret" "deployment_ssh_key" {
  count       = var.enable_auto_deployment ? 1 : 0
  name        = "${var.project_name}-deployment-ssh-key"
  description = "SSH private key for automated deployments from ADO agents"
  
  tags = {
    Name        = "${var.project_name}-deployment-ssh-key"
    Purpose     = "automated-deployment"
    Environment = "shared"
  }
}

# FIXED: Add secret version with placeholder - must be updated manually
resource "aws_secretsmanager_secret_version" "deployment_ssh_key" {
  count         = var.enable_auto_deployment ? 1 : 0
  secret_id     = aws_secretsmanager_secret.deployment_ssh_key[0].id
  secret_string = "PLACEHOLDER_SET_YOUR_SSH_PRIVATE_KEY_HERE"

  lifecycle {
    ignore_changes = [secret_string]
  }
}

# IAM policy for ADO agents to access secrets
resource "aws_iam_policy" "ado_agent_secrets" {
  count       = var.enable_ado_agents ? 1 : 0
  name        = "${var.project_name}-ado-agent-secrets-policy"
  description = "Policy for ADO agents to access required secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = compact([
          var.enable_ado_agents ? aws_secretsmanager_secret.ado_pat[0].arn : "",
          var.enable_auto_deployment ? aws_secretsmanager_secret.deployment_ssh_key[0].arn : ""
        ])
      }
    ]
  })
}

# FIXED: Output with clear instructions
output "ado_secrets" {
  description = "ADO-related secret information"
  value = var.enable_ado_agents ? {
    ado_pat_secret_name = aws_secretsmanager_secret.ado_pat[0].name
    deployment_ssh_secret_name = var.enable_auto_deployment ? aws_secretsmanager_secret.deployment_ssh_key[0].name : null
    setup_instructions = [
      "1. Update ADO PAT secret: aws secretsmanager update-secret --secret-id ${aws_secretsmanager_secret.ado_pat[0].name} --secret-string 'YOUR_ADO_PAT_HERE'",
      var.enable_auto_deployment ? "2. Update SSH key secret: aws secretsmanager update-secret --secret-id ${aws_secretsmanager_secret.deployment_ssh_key[0].name} --secret-string 'YOUR_SSH_PRIVATE_KEY_HERE'" : null,
      "3. Secrets must be updated before instances can successfully configure ADO agents"
    ]
    warning = "IMPORTANT: Secrets contain placeholder values and must be updated manually before deployment"
  } : null
  
  sensitive = false
}