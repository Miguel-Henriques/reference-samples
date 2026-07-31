# Public entrypoint for all client traffic. The interior (LiteLLM) ALB stays
# behind this one; see docs/02-gateway-topology.md for the trade-offs.

resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "Inbound HTTP/HTTPS to the gateway (authorizer) ALB."
  vpc_id      = data.aws_vpc.litellm.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}

resource "aws_lb" "this" {
  name               = local.name
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnets.public.ids

  # Generous idle timeout for long completions and quiet SSE streams.
  idle_timeout = 300

  tags = local.tags

  lifecycle {
    precondition {
      condition     = local.tls_enabled || var.allow_plaintext_alb
      error_message = "Provide authorizer_acm_certificate_arn, or set allow_plaintext_alb = true (dev only)."
    }
  }
}

resource "aws_lb_target_group" "authorizer" {
  name        = local.name
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.litellm.id

  deregistration_delay = 30

  health_check {
    path                = "/healthz"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = local.tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = local.tls_enabled ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = local.tls_enabled ? [] : [1]
    content {
      type             = "forward"
      target_group_arn = aws_lb_target_group.authorizer.arn
    }
  }

  tags = local.tags
}

resource "aws_lb_listener" "https" {
  count = local.tls_enabled ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.authorizer.arn
  }

  tags = local.tags
}
