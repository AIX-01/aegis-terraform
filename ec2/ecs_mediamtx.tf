##############################################
# ECS Service - MediaMTX (Streaming) [EC2]
# awsvpc mode for Cloud Map A record compatibility
##############################################

locals {
  mediamtx_container = {
    name      = "mediamtx"
    image     = "bluenviron/mediamtx:${var.mediamtx_image_tag}"
    essential = true

    portMappings = [
      { containerPort = 9997, protocol = "tcp" },
      { containerPort = 8554, protocol = "tcp" },
      { containerPort = 8889, protocol = "tcp" },
      { containerPort = 8890, protocol = "udp" },
      { containerPort = 8189, protocol = "udp" },
    ]

    environment = [
      { name = "MTX_WEBRTCADDITIONALHOSTS", value = aws_lb.nlb.dns_name },
      { name = "MTX_API", value = "yes" },
      { name = "MTX_APIADDRESS", value = ":9997" },
      { name = "MTX_RTSP", value = "yes" },
      { name = "MTX_RTSPADDRESS", value = ":8554" },
      { name = "MTX_WEBRTC", value = "yes" },
      { name = "MTX_WEBRTCADDRESS", value = ":8189" },
      { name = "MTX_SRT", value = "yes" },
      { name = "MTX_SRTADDRESS", value = ":8890" },
      { name = "MTX_HLS", value = "no" },
      { name = "MTX_WEBRTCHTTPADDRESS", value = ":8889" },
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
        valueFrom = aws_secretsmanager_secret.tailscale_auth_key[0].arn
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

  mediamtx_containers = var.enable_tailscale ? [
    local.mediamtx_container,
    local.tailscale_container,
  ] : [local.mediamtx_container]
}

resource "aws_ecs_task_definition" "mediamtx" {
  family                   = "${var.project_name}-mediamtx"
  requires_compatibilities = ["EC2"]
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

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 100
  }

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.mediamtx.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mediamtx_whep.arn
    container_name   = "mediamtx"
    container_port   = 8889
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.mediamtx_webrtc.arn
    container_name   = "mediamtx"
    container_port   = 8189
  }

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
