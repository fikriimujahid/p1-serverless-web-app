variable "project" {
  description = "Project name"
  type        = string
  default     = "notesapp"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "terraform_locks_table" {
  description = "DynamoDB table for Terraform locks"
  type        = string
}