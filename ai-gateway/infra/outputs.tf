output "gateway_url" {
  description = "Public entrypoint clients call with their OIDC JWTs."
  value       = module.authorizer.gateway_url
}

output "authorizer_ecr_repository_url" {
  description = "Push the authorizer image here (see docs/MAINTAINERS.md)."
  value       = module.authorizer.ecr_repository_url
}

output "avp_policy_store_id" {
  description = "Amazon Verified Permissions policy store holding gateway authorization policies."
  value       = module.authorizer.avp_policy_store_id
}

output "litellm_admin_url" {
  description = "Interior LiteLLM ALB (management API + UI). Not for client traffic."
  value       = module.litellm.alb_url
}

output "litellm_master_key_secret_arn" {
  description = "Secrets Manager ARN of the LiteLLM master key."
  value       = module.litellm.master_key_secret_arn
}

output "litellm_migration_run_command" {
  description = "One-off command that runs LiteLLM database migrations."
  value       = module.litellm.migration_run_command
}

output "litellm_db_bootstrap_sql" {
  description = "SQL to run once as the Aurora master user (creates the IAM-authed app user)."
  value       = module.litellm.db_bootstrap_sql
}
