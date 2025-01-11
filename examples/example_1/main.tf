module "hugo_blog" {
  source = "./modules/blog"

  domain_name = var.domain_name
  providers = {
    aws           = aws.ca_central_1
    aws.us_east_1 = aws.us_east_1
  }
  app = var.app
}

variable "domain_name" {
  description = "The domain name for the site"
  type        = string
  validation {
    condition     = length(var.domain_name) > 0
    error_message = "Domain name must not be empty"
  }
}

variable "app" {
  description = "The name of the application"
  type        = string
}

variable "aws_account_id" {
  description = "Account ID of the primary AWS account"
  type        = string
  validation {
    condition     = can(regex("^\\d{12,}$", var.aws_account_id))
    error_message = "Account ID must contain 13 digits"
  }
}

# Default region
provider "aws" {
  alias  = "ca_central_1"
  region = "ca-central-1"
  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/terraform"
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::${var.aws_account_id}:role/terraform"
  }
}