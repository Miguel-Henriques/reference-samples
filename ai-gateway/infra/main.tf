resource "random_password" "ui_password" {
  length      = 32
  special     = false
  min_lower   = 4
  min_upper   = 4
  min_numeric = 4
}

module "litellm" {
  source  = "BerriAI/litellm/aws"
  version = "~> 1.89"

  region = var.region
  azs    = var.azs
  tenant = var.tenant
  env    = var.env

  acm_certificate_arn = var.litellm_acm_certificate_arn
  allow_plaintext_alb = var.allow_plaintext_alb
  proxy_config        = var.proxy_config
  # stored under the following name format: <tenant>-litellm-<env>-ui-password
  ui_password = random_password.ui_password.result
}

module "authorizer" {
  source = "./modules/authorizer"

  # The authorizer discovers the LiteLLM VPC/subnets/ALB via tag-based data
  # sources, so it must never be planned before the core module exists. On a
  # first deployment, apply the core alone first:
  #   terraform apply -target=module.litellm
  depends_on = [module.litellm]

  region             = var.region
  litellm_stack_name = "${var.tenant}-litellm-${var.env}"

  # Interior ALB URL (scheme follows the LiteLLM ACM configuration).
  litellm_base_url         = module.litellm.alb_url
  litellm_ecs_cluster_name = module.litellm.ecs_cluster
  master_key_secret_arn    = module.litellm.master_key_secret_arn

  acm_certificate_arn   = var.authorizer_acm_certificate_arn
  allow_plaintext_alb   = var.allow_plaintext_alb
  allowed_ingress_cidrs = var.authorizer_allowed_ingress_cidrs

  image_tag     = var.authorizer_image_tag
  cpu           = var.authorizer_cpu
  memory        = var.authorizer_memory
  desired_count = var.authorizer_desired_count

  oidc_issuer_url = var.oidc_issuer_url
  oidc_audience   = var.oidc_audience
  oidc_jwks_url   = var.oidc_jwks_url
  oidc_team_claim = var.oidc_team_claim

  virtual_key_duration        = var.virtual_key_duration
  key_cache_ttl_seconds       = var.key_cache_ttl_seconds
  default_user_max_budget_usd = var.default_user_max_budget_usd

  enable_redis_cache = var.authorizer_enable_redis_cache
}
