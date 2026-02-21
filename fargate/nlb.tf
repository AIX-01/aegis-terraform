##############################################
# Network Load Balancer (MediaMTX WebRTC)
##############################################

resource "aws_lb" "nlb" {
  name               = "${var.project_name}-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public[*].id

  enable_cross_zone_load_balancing = true

  tags = { Name = "${var.project_name}-nlb" }
}

# ── WebRTC UDP Target Group ──────────────────

resource "aws_lb_target_group" "mediamtx_webrtc" {
  name        = "${var.project_name}-mtx-webrtc-tg"
  port        = 8189
  protocol    = "UDP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Fargate awsvpc

  # UDP doesn't support direct health checks, use TCP on API port
  health_check {
    enabled             = true
    port                = "9997"
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "${var.project_name}-mtx-webrtc-tg" }
}

# ── UDP Listener: WebRTC ─────────────────────

resource "aws_lb_listener" "mediamtx_webrtc" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 8189
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mediamtx_webrtc.arn
  }
}

# ── SRT Target Group (conditional: only when Tailscale disabled) ──

resource "aws_lb_target_group" "mediamtx_srt" {
  count = var.enable_tailscale ? 0 : 1

  name        = "${var.project_name}-mtx-srt-tg"
  port        = 8890
  protocol    = "UDP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    port                = "9997"
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = { Name = "${var.project_name}-mtx-srt-tg" }
}

resource "aws_lb_listener" "mediamtx_srt" {
  count = var.enable_tailscale ? 0 : 1

  load_balancer_arn = aws_lb.nlb.arn
  port              = 8890
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.mediamtx_srt[0].arn
  }
}
