# Shared virtual-key cache. Without it each authorizer instance keeps only an
# in-memory cache, so every restart/deploy re-mints keys (harmless — the
# rotation cleanup collects the leftovers — but noisier). Purely a cache:
# losing it costs one /key/generate per active caller, never correctness.

resource "aws_security_group" "redis" {
  count = var.enable_redis_cache ? 1 : 0

  name        = "${local.name}-redis"
  description = "Authorizer key cache - authorizer tasks only."
  vpc_id      = data.aws_vpc.litellm.id

  ingress {
    description     = "Redis from authorizer tasks"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.tasks.id]
  }

  tags = local.tags
}

resource "aws_elasticache_subnet_group" "authorizer" {
  count = var.enable_redis_cache ? 1 : 0

  name       = "${local.name}-cache"
  subnet_ids = data.aws_subnets.private.ids

  tags = local.tags
}

resource "aws_elasticache_replication_group" "authorizer" {
  count = var.enable_redis_cache ? 1 : 0

  replication_group_id = "${local.name}-cache"
  description          = "Authorizer virtual-key cache."

  engine             = "redis"
  node_type          = var.redis_node_type
  port               = 6379
  num_cache_clusters = 1

  # Cached values are live credentials: encrypt in transit and at rest.
  # Network access is limited to the authorizer task SG above.
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true

  automatic_failover_enabled = false
  subnet_group_name          = aws_elasticache_subnet_group.authorizer[0].name
  security_group_ids         = [aws_security_group.redis[0].id]

  tags = local.tags
}
