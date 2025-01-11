locals {
  s3_origin_id = "s3-web-${aws_s3_bucket.site-bucket.id}"
  s3_bucket_types = {
    content      = "public"
    www-redirect = "public"
    media        = "public"
    logs         = "private"
  }

  iam_role_types = toset([for key in keys(local.s3_bucket_types) : key])
}

#################################################################################################################
### ACM - Certificate ###########################################################################################
#################################################################################################################

# ACM Certificate
resource "aws_acm_certificate" "site" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"
}

################################################################################################################
### CloudFront Distribution ####################################################################################
################################################################################################################

resource "aws_cloudfront_distribution" "site" {
  depends_on = [aws_acm_certificate.site]
  origin {
    origin_id   = local.s3_origin_id
    domain_name = aws_s3_bucket_website_configuration.site-bucket-website.website_endpoint

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_100"
  aliases = [
    var.domain_name
  ]
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = aws_acm_certificate.site.arn
    ssl_support_method             = "sni-only"
    minimum_protocol_version       = "TLSv1.2_2021"
    cloudfront_default_certificate = false
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.site-logs.bucket_domain_name
    prefix          = "${var.domain_name}/cf/"
  }
}

#################################################################################################################
### IAM User ####################################################################################################
#################################################################################################################

resource "aws_iam_user" "publish" {
  name = module.blog__label__iam["content"].name
  depends_on = [aws_cloudfront_distribution.site]
  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

data "aws_iam_policy_document" "publish" {
  statement {
    sid    = "PublishPolicy0"
    effect = "Allow"
    actions = [
      "s3:List*",
      "s3:Get*",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = [
      aws_s3_bucket.site-bucket.arn,
      "${aws_s3_bucket.site-bucket.arn}/*"
    ]
  }
  statement {
    sid    = "PublishPolicy1"
    effect = "Allow"
    actions = [
      "cloudfront:CreateInvalidation"
    ]
    resources = [
      aws_cloudfront_distribution.site.arn
    ]
  }
}

resource "aws_iam_user_policy" "publish" {
  name   = "${module.blog__label__iam["content"].name}-policy"
  user   = aws_iam_user.publish.name
  policy = data.aws_iam_policy_document.publish.json
}

#################################################################################################################
### Route 53 ####################################################################################################
#################################################################################################################

resource "aws_route53_zone" "blog_hosted_zone" {
  comment       = "Managed by Terraform"
  force_destroy = false
  name          = var.domain_name
  tags = {
    "Name" = "hugo_blog"
  }
  tags_all = {
    "Name" = "hugo_blog"
  }
}

resource "aws_route53_record" "www" {
  zone_id    = aws_route53_zone.blog_hosted_zone.zone_id
  records    = [var.domain_name]
  name       = "www.${var.domain_name}"
  type       = "CNAME"
  ttl        = 300
  depends_on = [aws_route53_zone.blog_hosted_zone]
}

resource "aws_route53_record" "cloudfront_distribution" {
  health_check_id = null
  name            = var.domain_name
  set_identifier  = null
  type            = "A"
  zone_id         = aws_route53_zone.blog_hosted_zone.zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
  }
  depends_on = [aws_route53_zone.blog_hosted_zone]
}

#################################################################################################################
### S3 Buckets ##################################################################################################
#################################################################################################################

## Bucket
resource "aws_s3_bucket" "site-bucket" {
  bucket = module.blog__label__s3["content"].name
}

resource "aws_s3_bucket_versioning" "site-bucket-versioning" {
  bucket = aws_s3_bucket.site-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_website_configuration" "site-bucket-website" {
  bucket = aws_s3_bucket.site-bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_logging" "site-bucket-logging" {
  bucket        = aws_s3_bucket.site-bucket.id
  target_bucket = aws_s3_bucket.site-logs.bucket
  target_prefix = "${aws_s3_bucket.site-bucket.id}/s3/root"
}

resource "aws_s3_bucket_acl" "site-bucket-acl" {
  bucket = aws_s3_bucket.site-bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "site-bucket" {
  bucket                  = aws_s3_bucket.site-bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "site_bucket_policy" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site-bucket.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "site-bucket" {
  bucket = aws_s3_bucket.site-bucket.id
  policy = data.aws_iam_policy_document.site_bucket_policy.json
}

# Redirect www. S3 bucket

resource "aws_s3_bucket" "www-site-bucket" {
  bucket = module.blog__label__s3["www-redirect"].name
}

resource "aws_s3_bucket_versioning" "www-site-bucket-versioning" {
  bucket = aws_s3_bucket.www-site-bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_website_configuration" "www-site-bucket-website" {
  bucket = aws_s3_bucket.www-site-bucket.id

  redirect_all_requests_to {
    host_name = var.domain_name
  }
}

resource "aws_s3_bucket_logging" "www-site-bucket-logging" {
  bucket        = aws_s3_bucket.www-site-bucket.id
  target_bucket = aws_s3_bucket.site-logs.bucket
  target_prefix = "${var.domain_name}/s3/www"
}

resource "aws_s3_bucket_acl" "www-site-bucket-acl" {
  bucket = aws_s3_bucket.www-site-bucket.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "www-site-bucket" {
  bucket                  = aws_s3_bucket.www-site-bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "www_site_bucket_policy" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.www-site-bucket.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "www-site-bucket" {
  bucket = aws_s3_bucket.www-site-bucket.id
  policy = data.aws_iam_policy_document.www_site_bucket_policy.json
}

# Logs S3 bucket

resource "aws_s3_bucket" "site-logs" {
  bucket = module.blog__label__s3["logs"].name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site-logs" {
  bucket = aws_s3_bucket.site-logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "site-logs-versioning" {
  bucket = aws_s3_bucket.site-logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "site-logs-acl" {
  bucket = aws_s3_bucket.site-logs.id
  acl    = "log-delivery-write"

}

resource "aws_s3_bucket_public_access_block" "site-logs" {
  bucket                  = aws_s3_bucket.site-logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#################################################################################################################
### Sub-module ##################################################################################################
#################################################################################################################

module "utils" {
  source  = "cloudposse/utils/aws"
  version = "1.4.0"
}

module "blog__label__base" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  name       = "hugo"
  namespace  = "aws"
  stage      = "public"
  attributes = []
  tags = {
    Environment = "aws"
  }
  label_order = ["namespace", "stage", "name", "attributes"]
}

module "blog__label__s3" {
  for_each = local.s3_bucket_types
  source   = "cloudposse/label/null"
  version  = "0.25.0"
  context  = module.blog__label__base.context
  name     = "${var.app}-hugo-s3-${each.key}"
  tags = {
    Environment = "aws"
    BucketType  = each.value
  }
}

module "blog__label__iam" {
  for_each = local.iam_role_types

  source      = "cloudposse/label/null"
  version     = "0.25.0"
  context     = module.blog__label__base.context
  environment = "aws"
  name        = "${var.app}-hugo-iam-${each.key}"
}