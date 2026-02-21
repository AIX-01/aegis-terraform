##############################################
# Application Load Balancer
##############################################

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "${var.project_name}-alb" }
}

# ── Target Groups ────────────────────────────

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Fargate awsvpc 모드

  health_check {
    enabled             = true
    path                = "/actuator/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  # SSE 연결을 위한 긴 idle timeout
  deregistration_delay = 30

  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  tags = { Name = "${var.project_name}-backend-tg" }
}

# ── MediaMTX WHEP Target Group ──────────────

resource "aws_lb_target_group" "mediamtx_whep" {
  name        = "${var.project_name}-mtx-whep-tg"
  port        = 8889
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Fargate awsvpc

  health_check {
    enabled             = true
    path                = "/"
    port                = "9997"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-404"
  }

  deregistration_delay = 10

  tags = { Name = "${var.project_name}-mtx-whep-tg" }
}

# ── Listeners ────────────────────────────────

# HTTPS Listener (도메인 있을 때)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = var.domain_name != "" ? "HTTPS" : "HTTP"
  ssl_policy        = var.domain_name != "" ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null
  certificate_arn   = var.domain_name != "" ? aws_acm_certificate.alb[0].arn : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# HTTP → HTTPS Redirect
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.domain_name != "" ? "redirect" : "forward"

    # 도메인 있으면 HTTPS로 리다이렉트
    dynamic "redirect" {
      for_each = var.domain_name != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    # 도메인 없으면 직접 포워딩
    target_group_arn = var.domain_name != "" ? null : aws_lb_target_group.backend.arn
  }
}

# ── WHEP Streaming Rule ─────────────────────
# /stream/* → MediaMTX WHEP

resource "aws_lb_listener_rule" "mediamtx_whep" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mediamtx_whep.arn
  }

  condition {
    path_pattern {
      values = ["/stream/*"]
    }
  }
}
