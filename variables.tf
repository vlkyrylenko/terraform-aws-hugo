variable "domain_name" {
  type        = string
  description = "The domain name for the site"
  validation {
    condition     = length(var.domain_name) > 0
    error_message = "Domain name must not be empty"
  }
}

variable "app" {
  type        = string
  description = "The name of the application"
}