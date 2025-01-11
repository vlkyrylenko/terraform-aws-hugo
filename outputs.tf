output "acm_verify_value" {
  value       = element(aws_acm_certificate.site.domain_validation_options[*].resource_record_value, 0)
  description = "ACM domain verification record value"
}

output "s3_bucket_url" {
  value       = "s3://${aws_s3_bucket.site-bucket.bucket}?region=${aws_s3_bucket.site-bucket.region}"
  description = "S3 site bucket URL"
}

output "s3_redirect_endpoint" {
  value       = aws_s3_bucket_website_configuration.site-bucket-website.website_endpoint
  description = "S3 www redirect endpoint"
}

output "cf_website_endpoint" {
  value       = aws_cloudfront_distribution.site.domain_name
  description = "CloudFront website endpoint"
}

output "cf_distribution_id" {
  value       = aws_cloudfront_distribution.site.id
  description = "CloudFront distribution ID"
}