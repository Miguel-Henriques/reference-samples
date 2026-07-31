variable "region" {
  description = "AWS region (passed to the container for SDK calls)."
  type        = string
}

variable "litellm_stack_name" {
  description = "LiteLLM module naming root (<tenant>-litellm-<env>); used to discover its VPC, subnets, ALB, and cluster."
  type        = string
}

variable "litellm_base_url" {
  description = "URL of the interior LiteLLM ALB, scheme included."
  type        = string
}

variable "litellm_ecs_cluster_name" {
  description = "Name of the ECS cluster created by the LiteLLM module; the authorizer service joins it."
  type        = string
}

variable "master_key_secret_arn" {
  description = "Secrets Manager ARN of LITELLM_MASTER_KEY; injected into the authorizer for /key management calls."
  type        = string
}

# ---------- Public ALB ----------

variable "acm_certificate_arn" {
  description = "ACM certificate for the public gateway ALB. Empty = plaintext HTTP (dev only)."
  type        = string
  default     = ""
}

variable "allow_plaintext_alb" {
  description = "Allow an HTTP-only public ALB when no certificate is provided."
  type        = bool
  default     = false
}

variable "allowed_ingress_cidrs" {
  description = "CIDRs allowed to reach the public gateway ALB."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ---------- Service sizing ----------

variable "image_tag" {
  description = "Authorizer image tag in the module-managed ECR repository."
  type        = string
  default     = "latest"
}

variable "cpu" {
  description = "Fargate CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate memory (MiB)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of authorizer tasks."
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Upper bound for CPU-target autoscaling."
  type        = number
  default     = 3
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the authorizer."
  type        = number
  default     = 30
}

# ---------- OIDC ----------

variable "oidc_issuer_url" {
  description = "External OIDC issuer whose JWTs the authorizer accepts."
  type        = string
}

variable "oidc_jwks_url" {
  description = "Optional JWKS URL override; empty = OIDC discovery."
  type        = string
  default     = ""
}

variable "oidc_role_claim" {
  description = "JWT claim carrying the caller's authorization role."
  type        = string
  default     = "role"
}

variable "oidc_team_claim" {
  description = "JWT claim carrying the caller's LiteLLM team id."
  type        = string
  default     = "team_id"
}

# ---------- Key cache (Redis) ----------

variable "enable_redis_cache" {
  description = "Provision a small ElastiCache Redis as the shared virtual-key cache."
  type        = bool
  default     = true
}

variable "redis_node_type" {
  description = "ElastiCache node type for the key cache."
  type        = string
  default     = "cache.t4g.micro"
}

# ---------- Virtual keys ----------

variable "virtual_key_duration" {
  description = "Server-side lifetime of generated virtual keys."
  type        = string
  default     = "30d"
}

variable "key_cache_ttl_seconds" {
  description = "Authorizer-side virtual key cache TTL (seconds). Must be shorter than virtual_key_duration."
  type        = number
  default     = 28800 # 8 hours
}

variable "key_cleanup_grace_seconds" {
  description = "Stale authorizer-issued keys younger than this survive the rotation cleanup."
  type        = number
  default     = 300 # 5 minutes
}

variable "default_user_max_budget_usd" {
  description = "Budget applied to auto-created users. null = unlimited."
  type        = number
  default     = null
}
