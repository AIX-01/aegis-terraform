##############################################
# ECS Service - MediaMTX (Streaming Server)
##############################################

locals {
  # Base MediaMTX container
  mediamtx_container = {
    name      = "mediamtx"
    image     = "bluenviron/mediamtx:${var.mediamtx_image_tag}"
    essential = true

    portMappings = [
      { containerPort = 9997, protocol = "tcp" },  # API
      { containerPort = 8554, protocol = "tcp" },  # RTSP
      { containerPort = 8889, protocol = "tcp" },  # WHEP (HTTP)
      { containerPort = 8890, protocol = "udp" },  # SRT
      { containerPort = 8189, protocol = "udp" },  # WebRTC
    ]

    environment = [
      # WebRTC ICE: NLB public DNS for browser connectivity
      { name = "MTX_WEBRTCADDITIONALHOSTS", value = aws_lb.nlb.dns_name },

      # Paths configuration via API
      { name = "MTX_API", value = "yes" },
      { name = "MTX_APIADDRESS", value = ":9997" },

      # Protocol settings
      { name = "MTX_RTSP", value = "yes" },
      { name = "MTX_RTSPADDRESS", value = ":8554" },
      { name = "MTX_WEBRTC", value = "yes" },
      { name = "MTX_WEBRTCADDRESS", value = ":8189" },
      { name = "MTX_SRT", value = "yes" },
      { name = "MTX_SRTADDRESS", value = ":8890" },
      { name = "MTX_HLS", value = "no" },
      { name = "MTX_RTMP", value = "no" },

      # WHEP (WebRTC HTTP)
      { name = "MTX_WEBRTCHTTPADDRESS", value = ":8889" },

      # Auth: delegate to Backend
      { name = "MTX_AUTHMETHOD", value = "http" },
      { name = "MTX_AUTHHTTPADDRESS", value = "http://backend.${var.service_discovery_namespace}:8080/internal/mediamtx/auth" },

      # Hooks: notify Backend on stream start/stop
      { name = "MTX_PATHDEFAULTS_RUNONREADY", value = "wget -q -O - --header='Content-Type: application/json' --post-data='{}' http://backend.${var.service_discovery_namespace}:8080/internal/mediamtx/sync" },
      { name = "MTX_PATHDEFAULTS_RUNONREADYRESTART", value = "no" },
      { name = "MTX_PATHDEFAULTS_RUNONNOTREADY", value = "wget -q -O - --header='Content-Type: application/json' --post-data='{}' http://backend.${var.service_discovery_namespace}:8080/internal/mediamtx/sync" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.mediamtx.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "mediamtx"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "wget -qO- http://localhost:9997/v3/paths/list || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 15
    }
  }

  # Tailscale sidecar container (conditional)
  tailscale_container = {
    name      = "tailscale"
    image     = "tailscale/tailscale:latest"
    essential = false

    environment = [
      { name = "TS_HOSTNAME", value = var.tailscale_hostname },
      { name = "TS_STATE_DIR", value = "/var/lib/tailscale" },
      { name = "TS_USERSPACE", value = "false" },
    ]

    secrets = [
      {
        name      = "TS_AUTHKEY"
        valueFrom = try(aws_secretsmanager_secret.tailscale_auth_key[0].arn, "")
      },
    ]

    linuxParameters = {
      capabilities = {
        add = ["NET_ADMIN", "NET_RAW"]
      }
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.mediamtx.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "tailscale"
      }
    }
  }

  mediamtx_containers = concat(
    [local.mediamtx_container],
    var.enable_tailscale ? [local.tailscale_container] : []
  )
}

resource "aws_ecs_task_definition" "mediamtx" {
  family                   = "${var.project_name}-mediamtx"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.mediamtx_cpu
  memory                   = var.mediamtx_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.mediamtx_task.arn

  container_definitions = jsonencode(local.mediamtx_containers)
}

resource "aws_ecs_service" "mediamtx" {
  name            = "${var.project_name}-mediamtx"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mediamtx.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.mediamtx.id]
    assign_public_ip = false
  }

  # ALB: WHEP HTTP streaming
  load_balancer {
    target_group_arn = aws_lb_target_group.mediamtx_whep.arn
    container_name   = "mediamtx"
    container_port   = 8889
  }

  # NLB: WebRTC UDP
  load_balancer {
    target_group_arn = aws_lb_target_group.mediamtx_webrtc.arn
    container_name   = "mediamtx"
    container_port   = 8189
  }

  # NLB: SRT ingest (only when Tailscale disabled)
  dynamic "load_balancer" {
    for_each = var.enable_tailscale ? [] : [1]
    content {
      target_group_arn = aws_lb_target_group.mediamtx_srt[0].arn
      container_name   = "mediamtx"
      container_port   = 8890
    }
  }

  # Cloud Map service discovery
  service_registries {
    registry_arn = aws_service_discovery_service.mediamtx.arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.mediamtx_webrtc,
    aws_lb_listener.https,
  ]
}
