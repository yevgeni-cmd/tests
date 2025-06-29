output "policy_arn" {
  description = "The ARN of the created IAM policy."
  value       = aws_iam_policy.this.arn
}
