# modules/sqs_queue/outputs.tf
output "queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  description = "URL of the SQS queue"
  value       = aws_sqs_queue.this.url
}

output "queue_name" {
  description = "Name of the SQS queue"
  value       = aws_sqs_queue.this.name
}

output "dlq_arn" {
  description = "ARN of the dead letter queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].arn : null
}

output "dlq_url" {
  description = "URL of the dead letter queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].url : null
}

output "dlq_name" {
  description = "Name of the dead letter queue"
  value       = var.enable_dlq ? aws_sqs_queue.dlq[0].name : null
}