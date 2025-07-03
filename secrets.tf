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

# Output secret names for reference
output "ado_secrets" {
  description = "ADO-related secret information"
  value = var.enable_ado_agents ? {
    ado_pat_secret_name = aws_secretsmanager_secret.ado_pat[0].name
    deployment_ssh_secret_name = var.enable_auto_deployment ? aws_secretsmanager_secret.deployment_ssh_key[0].name : null
    setup_instructions = "Store your ADO PAT in secret: ${aws_secretsmanager_secret.ado_pat[0].name}"
  } : null
}
