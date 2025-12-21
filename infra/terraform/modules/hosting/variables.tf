# =============================================================================
# Common Variables
# =============================================================================

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

# =============================================================================
# Domain & DNS
# =============================================================================

variable "domain_name" {
  description = "Root domain name (e.g., example.com). Optional when no domain aliases are set."
  type        = string
  default     = null
}

# =============================================================================
# S3 Website Hosting
# =============================================================================

variable "bucket_name" {
  description = "Name of the S3 bucket for static website hosting"
  type        = string
}

variable "enable_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm (AES256 or aws:kms)"
  type        = string
  default     = "AES256"
}

# =============================================================================
# Web Application Firewall (WAF)
# =============================================================================

variable "enable_waf" {
  description = "Enable WAF for CloudFront"
  type        = bool
  default     = false
}

variable "waf_rate_limit" {
  description = "WAF rate limit (requests in a 5-minute period)"
  type        = number
  default     = 1000
}

# If WAF is managed outside this module, provide an existing Web ACL ID
variable "web_acl_id" {
  description = "WAF Web ACL ID for CloudFront (optional - used if enable_waf is false)"
  type        = string
  default     = null
}

# =============================================================================
# CloudFront Distribution
# =============================================================================

variable "default_root_object" {
  description = "Default root object for CloudFront (e.g., index.html)"
  type        = string
  default     = "index.html"
}

variable "price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100" # Cost optimization: only US, Canada, Europe
}

variable "domain_aliases" {
  description = "List of domain aliases for CloudFront (e.g., [example.com, www.example.com])"
  type        = list(string)
  default     = []
}

variable "custom_error_responses" {
  description = "Custom error responses for CloudFront"
  type = list(object({
    error_code         = number
    response_code      = number
    response_page_path = string
  }))
  default = [
    {
      error_code         = 404
      response_code      = 404
      response_page_path = "/index.html" # SPA fallback
    },
    {
      error_code         = 403
      response_code      = 404
      response_page_path = "/index.html"
    }
  ]
}

variable "geo_restriction_type" {
  description = "Geo restriction type (whitelist, blacklist, none)"
  type        = string
  default     = null
}

variable "geo_restriction_locations" {
  description = "List of country codes for geo restrictions"
  type        = list(string)
  default     = []
}

# =============================================================================
# Logging
# =============================================================================

variable "enable_logging" {
  description = "Enable CloudFront access logging"
  type        = bool
  default     = false
}

variable "logging_bucket" {
  description = "S3 bucket for CloudFront logs"
  type        = string
  default     = null
}

variable "logging_prefix" {
  description = "Prefix for CloudFront log files"
  type        = string
  default     = "cloudfront-logs/"
}
