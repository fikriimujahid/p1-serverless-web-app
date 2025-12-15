variable "project" {
  description = "Project name"
  type        = string
}

variable "terraform_state_bucket_arn" {
  description = "ARN of the Terraform state S3 bucket"
  type        = string
}

variable "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}