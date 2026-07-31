output "gateway_url" {
  description = "Public gateway URL clients call."
  value       = local.tls_enabled ? "https://${aws_lb.this.dns_name}" : "http://${aws_lb.this.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository for the authorizer image."
  value       = aws_ecr_repository.authorizer.repository_url
}

output "avp_policy_store_id" {
  description = "Verified Permissions policy store id."
  value       = aws_verifiedpermissions_policy_store.this.id
}

output "avp_namespace" {
  description = "Cedar namespace from the AVP schema (AVP_NAMESPACE)."
  value       = local.avp_namespace
}

output "ecs_service_name" {
  description = "Authorizer ECS service name (for force-new-deployment after image pushes)."
  value       = aws_ecs_service.authorizer.name
}
