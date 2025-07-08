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
        ])
      }
    ]
  })
}
