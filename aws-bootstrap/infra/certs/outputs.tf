output "certificate_arn" {
  description = "ARN of the regional ACM certificate."
  value       = aws_acm_certificate.this.arn
}

output "certificate_domain_names" {
  description = "Domain names covered by the ACM certificate."
  value = concat(
    [aws_acm_certificate.this.domain_name],
    tolist(aws_acm_certificate.this.subject_alternative_names),
  )
}

output "certificate_status" {
  description = "Current ACM certificate status."
  value       = aws_acm_certificate.this.status
}

output "dns_validation_records" {
  description = "CNAME records to create in Cloudflare DNS."
  value = distinct([
    for option in aws_acm_certificate.this.domain_validation_options : {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  ])
}

output "validated_certificate_arn" {
  description = "Validated certificate ARN when validation waiting is enabled."
  value = try(
    aws_acm_certificate_validation.this[0].certificate_arn,
    null,
  )
}
