output "terraform_dev_role_arn" {
  description = "ARN of the TerraformDevRole"
  value       = aws_iam_role.terraform_dev.arn
}

output "terraform_prod_role_arn" {
  description = "ARN of the TerraformProdRole"
  value       = aws_iam_role.terraform_prod.arn
}

output "cicd_runner_role_arn" {
  description = "ARN of the CICDRunnerRole"
  value       = aws_iam_role.cicd_runner.arn
}