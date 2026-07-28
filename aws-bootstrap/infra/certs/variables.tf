variable "domain_name" {
  description = "Domain name for the ACM certificate."
  type        = string

  validation {
    condition = (
      length(trimspace(var.domain_name)) > 0 &&
      !startswith(var.domain_name, "*.") &&
      !strcontains(var.domain_name, "://")
    )
    error_message = "Use a DNS name without a wildcard or URL scheme."
  }
}

variable "include_wildcard" {
  description = "Whether the certificate covers direct child names."
  type        = bool
  default     = true
}

variable "region" {
  description = "AWS region in which to issue the ACM certificate."
  type        = string
  default     = "us-east-1"
}

variable "tags" {
  description = "Additional tags to apply to supported resources."
  type        = map(string)
  default     = {}
}

variable "wait_for_certificate_validation" {
  description = "Whether Terraform waits for ACM validation to finish."
  type        = bool
  default     = false
}
