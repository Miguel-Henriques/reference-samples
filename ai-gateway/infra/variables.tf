variable "region" {
  description = "AWS region for the whole stack."
  type        = string
}

variable "azs" {
  description = "Availability zones (at least 2) for the LiteLLM VPC."
  type        = list(string)
}

variable "tenant" {
  description = "Resource-name prefix (lower-kebab-case), e.g. your org or team name."
  type        = string
}

variable "env" {
  description = "Environment slug, e.g. dev, stage, prod."
  type        = string
}

# ---------- TLS ----------

variable "litellm_acm_certificate_arn" {
  description = "ACM certificate for the interior (LiteLLM) ALB. Empty = plaintext HTTP (dev only)."
  type        = string
  default     = ""
}

variable "authorizer_acm_certificate_arn" {
  description = "ACM certificate for the public gateway ALB. Empty = plaintext HTTP (dev only)."
  type        = string
  default     = ""
}

variable "allow_plaintext_alb" {
  description = "Allow HTTP-only ALBs when no ACM certificates are provided. Dev/trial use only."
  type        = bool
  default     = false
}

# ---------- LiteLLM core ----------

variable "proxy_config" {
  description = "LiteLLM config.yaml contents (model_list, guardrails, router settings...)."
  type        = any
  default     = {}
}

# ---------- Authorizer ----------

variable "oidc_issuer_url" {
  description = "External OIDC issuer whose JWTs the authorizer accepts."
  type        = string
}

variable "oidc_audience" {
  description = "Required audience (aud claim) on caller JWTs."
  type        = string
}

variable "oidc_jwks_url" {
  description = "Optional JWKS URL override. Empty = resolved via OIDC discovery."
  type        = string
  default     = ""
}

variable "oidc_team_claim" {
  description = "JWT claim carrying the caller's LiteLLM team id."
  type        = string
  default     = "team_id"
}

variable "authorizer_image_tag" {
  description = "Tag of the authorizer image in the module-managed ECR repository."
  type        = string
  default     = "latest"
}

variable "authorizer_cpu" {
  description = "Fargate CPU units for the authorizer task."
  type        = number
  default     = 512
}

variable "authorizer_memory" {
  description = "Fargate memory (MiB) for the authorizer task."
  type        = number
  default     = 1024
}

variable "authorizer_desired_count" {
  description = "Authorizer tasks to run."
  type        = number
  default     = 2
}

variable "authorizer_allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the public gateway ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "virtual_key_duration" {
  description = "Server-side lifetime of generated LiteLLM virtual keys (e.g. 30d, 12h)."
  type        = string
  default     = "30d"
}

variable "key_cache_ttl_seconds" {
  description = "Authorizer-side cache TTL for virtual keys. Must be shorter than virtual_key_duration."
  type        = number
  default     = 604800
}

variable "authorizer_enable_redis_cache" {
  description = "Provision an ElastiCache Redis as the authorizer's shared virtual-key cache."
  type        = bool
  default     = true
}

variable "default_user_max_budget_usd" {
  description = "Budget (USD) applied to users auto-created on first request. null = unlimited."
  type        = number
  default     = null
}
