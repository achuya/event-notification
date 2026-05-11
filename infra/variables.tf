variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL"
  type        = string
  sensitive   = true
}