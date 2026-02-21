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

resource "aws_lb_target_group" "backend" {
  name        = "${var.project_name}-backend-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance" # EC2 버전: instance (Fargate는 ip)

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

  deregistration_delay = 30

  tags = { Name = "${var.project_name}-backend-tg" }
}

# ── MediaMTX WHEP Target Group ──────────────

resource "aws_lb_target_group" "mediamtx_whep" {
  name        = "${var.project_name}-mtx-whep-tg"
  port        = 8889
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # awsvpc mode on EC2 for MediaMTX

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

resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.domain_name != "" ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.domain_name != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    target_group_arn = var.domain_name != "" ? null : aws_lb_target_group.backend.arn
  }
}

# ── WHEP Streaming Rule ─────────────────────

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
