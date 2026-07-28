locals {
  domain_name = trimsuffix(lower(trimspace(var.domain_name)), ".")
}

resource "aws_acm_certificate" "this" {
  domain_name = local.domain_name
  subject_alternative_names = var.include_wildcard ? [
    "*.${local.domain_name}",
  ] : []
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "this" {
  count = var.wait_for_certificate_validation ? 1 : 0

  certificate_arn = aws_acm_certificate.this.arn
  validation_record_fqdns = [
    for option in aws_acm_certificate.this.domain_validation_options :
    option.resource_record_name
  ]
}
