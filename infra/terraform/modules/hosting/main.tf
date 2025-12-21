terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# =============================================================================
# DNS & Certificates (Data Sources)
# =============================================================================
# Data source for existing Route53 hosted zone (optional if no domain aliases)
data "aws_route53_zone" "existing" {
  count        = length(var.domain_aliases) > 0 ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

# Data source for existing ACM certificate (must be in us-east-1 for CloudFront)
data "aws_acm_certificate" "existing" {
  count    = length(var.domain_aliases) > 0 ? 1 : 0
  domain   = var.domain_name
  most_recent = true
  statuses = ["ISSUED"]
  provider = aws.us_east_1
}

# =============================================================================
# S3 Website Hosting
# =============================================================================
# S3 Bucket for static website hosting
resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name = var.bucket_name
  })
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.sse_algorithm
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block (block all public access - CloudFront uses OAC)
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Lifecycle Configuration for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    id     = "cleanup-incomplete-multipart-uploads"
    status = "Enabled"

    filter {} # Apply to all objects

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Transition old versions to cheaper storage classes
  dynamic "rule" {
    for_each = var.enable_versioning ? [1] : []
    content {
      id     = "transition-old-versions"
      status = "Enabled"

      filter {} # Apply to all objects

      noncurrent_version_transition {
        noncurrent_days = 30
        storage_class   = "STANDARD_IA"
      }

      noncurrent_version_transition {
        noncurrent_days = 90
        storage_class   = "GLACIER"
      }

      noncurrent_version_expiration {
        noncurrent_days = 180
      }
    }
  }

  # Delete old delete markers
  dynamic "rule" {
    for_each = var.enable_versioning ? [1] : []
    content {
      id     = "delete-old-delete-markers"
      status = "Enabled"

      filter {} # Apply to all objects

      expiration {
        expired_object_delete_marker = true
      }
    }
  }
}

# ============================================================================
# WAFv2 Web ACL for CloudFront
# ============================================================================

resource "aws_wafv2_web_acl" "cloudfront" {
  count    = var.enable_waf ? 1 : 0
  provider = aws.us_east_1
  
  name        = "${var.project}-${var.environment}-cloudfront-waf"
  description = "WAF for CloudFront distribution - ${var.environment} environment"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # AWS Managed Rules - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  # Rate-based rule
  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "CloudFrontWAFMetric"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-cloudfront-waf"
  })
}

# CloudFront Origin Access Control (OAC) - newer and recommended over OAI
resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.bucket_name}-oac"
  description                       = "OAC for ${var.bucket_name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Lambda@Edge function to rewrite directory requests to index.html
resource "aws_lambda_function" "cloudfront_rewrite" {
  provider      = aws.us_east_1
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "${var.bucket_name}-cf-rewrite"
  role          = aws_iam_role.lambda_edge_role.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  publish       = true

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

# Archive the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "/tmp/lambda_rewrite.zip"

  source {
    content  = <<-EOT
def handler(event, context):
    request = event['Records'][0]['cf']['request']
    uri = request['uri']
    
    # If URI ends with /, append index.html
    if uri.endswith('/'):
        request['uri'] = uri + 'index.html'
    # If URI has no extension and doesn't end with /, append /index.html
    elif '.' not in uri.split('/')[-1]:
        request['uri'] = uri + '/index.html'
    
    return request
EOT
    filename = "index.py"
  }
}

# IAM role for Lambda@Edge
resource "aws_iam_role" "lambda_edge_role" {
  name = "${var.bucket_name}-lambda-edge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach basic Lambda policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_edge_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.bucket_name}"
  default_root_object = var.default_root_object
  price_class         = var.price_class

  aliases = var.domain_aliases

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.website.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.website.id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    # Use managed cache policy for best practices
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingOptimized

    # Lambda@Edge function to rewrite directory requests
    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.cloudfront_rewrite.qualified_arn
      include_body = false
    }

    # Security headers via response headers policy
    # response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # Custom error responses
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code         = custom_error_response.value.error_code
      response_code      = custom_error_response.value.response_code
      response_page_path = custom_error_response.value.response_page_path
    }
  }

  # Geographic restrictions (required block, but can be set to "none")
  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction_type != null ? var.geo_restriction_type : "none"
      locations        = var.geo_restriction_type != null ? var.geo_restriction_locations : []
    }
  }

  # SSL/TLS Certificate: use ACM when custom domains provided; otherwise default CF cert
  viewer_certificate {
    acm_certificate_arn            = length(var.domain_aliases) > 0 ? data.aws_acm_certificate.existing[0].arn : null
    cloudfront_default_certificate = length(var.domain_aliases) == 0 ? true : null
    ssl_support_method             = length(var.domain_aliases) > 0 ? "sni-only" : null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  # Logging (optional but recommended)
  dynamic "logging_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      bucket          = var.logging_bucket
      prefix          = var.logging_prefix
      include_cookies = false
    }
  }

  # WAF Web ACL (optional but recommended for security)
  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.cloudfront[0].arn : var.web_acl_id

  tags = merge(var.tags, {
    Name = "${var.bucket_name}-cloudfront"
  })
}

# S3 Bucket Policy for CloudFront OAC
resource "aws_s3_bucket_policy" "cloudfront_oac" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.website.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
          }
        }
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.website,
    aws_cloudfront_origin_access_control.website
  ]
}

# Route53 A Record for CloudFront
resource "aws_route53_record" "cloudfront_a" {
  for_each = toset(var.domain_aliases)

  zone_id = data.aws_route53_zone.existing[0].zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
