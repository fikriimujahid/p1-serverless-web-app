variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "cognito_tier" {
  description = "Cognito User Pool Tier (LITE or PLUS)"
  type        = string
  default     = "LITE"
}

variable "password_min_length" {
  description = "Minimum password length"
  type        = number
  default     = 12
}

variable "enable_mfa" {
  description = "Enable MFA"
  type        = bool
  default     = false
}

variable "enable_advanced_security" {
  description = "Enable Advanced Security Features (Audit/Enforced)"
  type        = bool
  default     = false
}

variable "callback_urls" {
  description = "List of allowed callback URLs"
  type        = list(string)
  default     = ["http://localhost:3000/api/auth/callback/cognito"]
}

variable "logout_urls" {
  description = "List of allowed logout URLs"
  type        = list(string)
  default     = ["http://localhost:3000"]
}