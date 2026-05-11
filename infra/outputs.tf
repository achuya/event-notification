output "lambda_function_name" {
  description = "Lambda関数名"
  value       = aws_lambda_function.notification.function_name
}

output "sfn_arn" {
  description = "Step Functions ARN"
  value       = aws_sfn_state_machine.notification.arn
}