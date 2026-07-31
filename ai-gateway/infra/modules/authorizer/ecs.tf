resource "aws_security_group" "tasks" {
  name        = "${local.name}-tasks"
  description = "Authorizer ECS tasks."
  vpc_id      = data.aws_vpc.litellm.id

  ingress {
    description     = "Gateway ALB to authorizer"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "All egress (LiteLLM ALB, AVP, OIDC discovery)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "authorizer" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_ecs_task_definition" "authorizer" {
  family                   = local.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "authorizer"
      image     = "${aws_ecr_repository.authorizer.repository_url}:${var.image_tag}"
      essential = true

      portMappings = [{ containerPort = 8080, protocol = "tcp" }]

      environment = concat(
        [
          { name = "PORT", value = "8080" },
          { name = "AWS_REGION", value = var.region },
          { name = "LITELLM_BASE_URL", value = var.litellm_base_url },
          { name = "OIDC_ISSUER_URL", value = var.oidc_issuer_url },
          { name = "OIDC_ROLE_CLAIM", value = var.oidc_role_claim },
          { name = "OIDC_TEAM_CLAIM", value = var.oidc_team_claim },
          { name = "AVP_POLICY_STORE_ID", value = aws_verifiedpermissions_policy_store.this.id },
          { name = "AVP_NAMESPACE", value = local.avp_namespace },
          { name = "VIRTUAL_KEY_DURATION", value = var.virtual_key_duration },
          { name = "KEY_CACHE_TTL_SECONDS", value = tostring(var.key_cache_ttl_seconds) },
          { name = "KEY_CLEANUP_GRACE_SECONDS", value = tostring(var.key_cleanup_grace_seconds) },
        ],
        var.oidc_jwks_url != "" ? [{ name = "OIDC_JWKS_URL", value = var.oidc_jwks_url }] : [],
        var.enable_redis_cache ? [
          {
            name  = "REDIS_URL"
            value = "rediss://${aws_elasticache_replication_group.authorizer[0].primary_endpoint_address}:6379"
          }
        ] : [],
        var.default_user_max_budget_usd != null ? [
          { name = "DEFAULT_USER_MAX_BUDGET_USD", value = tostring(var.default_user_max_budget_usd) }
        ] : [],
      )

      secrets = [
        { name = "LITELLM_MASTER_KEY", valueFrom = var.master_key_secret_arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.authorizer.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "authorizer"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "node -e \"fetch('http://localhost:8080/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }
    }
  ])

  tags = local.tags
}

resource "aws_ecs_service" "authorizer" {
  name            = local.name
  cluster         = data.aws_ecs_cluster.litellm.arn
  task_definition = aws_ecs_task_definition.authorizer.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.authorizer.arn
    container_name   = "authorizer"
    container_port   = 8080
  }

  health_check_grace_period_seconds = 30

  # The service is created before any image has been pushed to ECR; tasks
  # simply retry pulls until the first push lands.
  wait_for_steady_state = false

  tags = local.tags
}

# ---------- Autoscaling ----------

/**

FIXME: Autoscaling requires a lot of work because CPU utilization is not the best metric
for this type of workload - long-running connections with high throughput.

Instead, it would be better to plot:

- Concurrent active connections
- CPU
- Memory
- Node event-loop delay (p99)
- Errors (OOM, Health checks failures)

And then use connection count as scale measure target where the event loop delay consistently reaches ~50-100ms.

**/

resource "aws_appautoscaling_target" "authorizer" {
  service_namespace  = "ecs"
  resource_id        = "service/${var.litellm_ecs_cluster_name}/${aws_ecs_service.authorizer.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.desired_count
  max_capacity       = var.autoscaling_max_capacity
}

resource "aws_appautoscaling_policy" "authorizer_cpu" {
  name               = "${local.name}-cpu"
  service_namespace  = aws_appautoscaling_target.authorizer.service_namespace
  resource_id        = aws_appautoscaling_target.authorizer.resource_id
  scalable_dimension = aws_appautoscaling_target.authorizer.scalable_dimension
  policy_type        = "TargetTrackingScaling"

  target_tracking_scaling_policy_configuration {
    target_value = 70

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
