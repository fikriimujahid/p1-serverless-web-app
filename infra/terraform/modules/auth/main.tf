resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-${var.environment}-user-pool"

  # Cost optimization: Use LITE tier if acceptable, but PLUS is needed for advanced security
  user_pool_tier = var.cognito_tier

  # User Attributes
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  # Security: Case sensitivity
  username_configuration {
    case_sensitive = false
  }

  # Password Policy (NIST guidelines recommendation is length > complexity, but AWS defaults are safer)
  password_policy {
    minimum_length                   = var.password_min_length
    require_lowercase               = true
    require_numbers                 = true
    require_symbols                 = true
    require_uppercase               = true
    temporary_password_validity_days = 7
  }

  # MFA Configuration
  mfa_configuration = var.enable_mfa ? "OPTIONAL" : "OFF"
  dynamic "software_token_mfa_configuration" {
    for_each = var.enable_mfa ? [1] : []
    content {
      enabled = true
    }
  }

  # Account Recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Schema Attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    
    string_attribute_constraints {
      min_length = 5
      max_length = 2048
    }
  }

  # Advanced Security
  dynamic "user_pool_add_ons" {
    for_each = var.enable_advanced_security ? [1] : []
    content {
      advanced_security_mode = "ENFORCED"
    }
  }

  # Device Tracking - Useful for production security
  device_configuration {
    challenge_required_on_new_device      = true
    device_only_remembered_on_user_prompt = true
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
    # In production, you should set this to DEVELOPER and use SES
    # source_arn = aws_ses_email_identity.example.arn
  }

  deletion_protection = "ACTIVE" # Safety for production

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-user-pool"
  })
}

resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project}-${var.environment}-web-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Security: No secret for web/SPA clients
  generate_secret = false
  
  # Auth Flows
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH" # Included for easier testing/development, but SRP is preferred
  ]

  # Token Validity
  access_token_validity  = 60  # minutes
  id_token_validity      = 60  # minutes
  refresh_token_validity = 30  # days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Security: Prevent user enumeration
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  # OAuth Settings
  allowed_oauth_flows                  = ["code"] # Authorization Code Grant is best for security
  allowed_oauth_scopes                 = ["email", "openid", "profile"]
  allowed_oauth_flows_user_pool_client = true

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls
}