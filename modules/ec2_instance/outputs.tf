output "instance_id" { value = aws_instance.this.id }
output "public_ip" { value = aws_instance.this.public_ip }
output "private_ip" {
  description = "The private IP address of the instance."
  value       = aws_instance.this.private_ip
}

output "iam_role_arn" {
  description = "The ARN of the IAM role for the EC2 instance."
  value       = aws_iam_role.ec2_role.arn
}