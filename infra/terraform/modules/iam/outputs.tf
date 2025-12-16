output "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "cognito_service_role_arn" {
  description = "ARN of Cognito service role"
  value       = aws_iam_role.cognito_service_role.arn
}