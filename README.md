# Terraform AWS Hugo
This repository contains a Terraform module that creates an S3 bucket, CloudFront distribution, and Route 53 record for a Hugo website.

## !! Warning !!
Creating the resources in this module will incur costs. Make sure to destroy the resources after you are done using them.

## Requirements

* Terraform 5.82.2 +
* AWS account

## Brief Overview

The following module creates a basic infrastructure required to host a Hugo website on AWS.
To deploy a website create a new deployment target in Hugo configuration file following this [guide](https://gohugo.io/hosting-and-deployment/hugo-deploy/).

For a template website repository, see [hugo-blog](https://github.com/vlkyrylenko/hugo-blog).

This module creates the following resources:
- S3 bucket for storing the website files
- S3 bucket for storing the logs
- S3 bucket for www redirects
- CloudFront distribution for serving the website
- Route 53 record for the website
- ACM certificate for the website
- IAM user and policy

## Inputs

- `domain_name` - The domain name of the website.
- `app` - The name of the application. Used in resource names.
- `providers` - The providers to use for the resources.

## Outputs

- `acm_verify_values` - The ACM certificate verification values.
- `s3_bucket_url` - The URL of the S3 bucket. Required for creating a deployment target.
- `s3_redirect_endpoint` - The URL of the S3 bucket for www redirects.
- `cf_website_endpoint` - The URL of the CloudFront distribution. Useful for troubleshooting purposes.
- `cf_distribution_id` - The ID of the CloudFront distribution. Required for creating a deployment target.

## Important Notes

1. The ACM certificate verification values must be added to the DNS records of the domain before the certificate can be issued. Otherwise, the CloudFront distribution will not be able to use the certificate.
2. The CloudFront distribution can take up to 15 minutes to deploy. The website will not be accessible until the distribution is deployed.
3. The Route 53 record will not be created if the domain is not hosted in the same AWS account as the resources. In this case, the Route 53 record must be created manually.
4. ACM certificates are only available in the us-east-1 region. The `providers` input must include a provider for the us-east-1 region.

## Example

See the example directory for a complete example of how to use this module.

```hcl
module "hugo_blog" {
  source  = "vlkyrylenko/hugo/aws"
  version = "1.0.0"

  domain_name = "example.com"
  providers = {
    aws           = aws.ca_central_1
    aws.us_east_1 = aws.us_east_1
  }
  app = "app-name"
}
```