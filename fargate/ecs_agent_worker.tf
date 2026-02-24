##############################################
# ECS Service - Agent Worker + Auto Scaling
##############################################

resource "aws_ecs_task_definition" "agent_worker" {
  family                   = "${var.project_name}-agent-worker"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.agent_worker_cpu
  memory                   = var.agent_worker_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.agent_task.arn

  container_definitions = jsonencode([{
    name  = "agent-worker"
    image = "${aws_ecr_repository.agent.repository_url}:latest"

    command = ["python", "-m", "src.app", "--real-vlm", "--real-backend"]

    environment = [
      # Agent 모드 (worker: Consumer만 실행)
      { name = "AGENT_MODE", value = "worker" },

      # SQS (태스크 수신)
      { name = "SQS_QUEUE_URL", value = aws_sqs_queue.analysis.url },
      { name = "AWS_REGION", value = var.aws_region },

      # Redis
      { name = "REDIS_HOST", value = aws_elasticache_cluster.redis.cache_nodes[0].address },
      { name = "REDIS_PORT", value = "6379" },

      # S3 (클립 업로드)
      { name = "S3_BUCKET", value = aws_s3_bucket.clips.id },

      # Backend API (Cloud Map - VPC 내부 통신)
      { name = "BACKEND_URL", value = "http://backend.${var.service_discovery_namespace}:8080" },

      # Qdrant (Cloud Map)
      { name = "QDRANT_HOST", value = "qdrant.${var.service_discovery_namespace}" },
      { name = "QDRANT_PORT", value = "6333" },

      # VLM (RunPod)
      { name = "VLM_ENDPOINT", value = "https://w2b6m5sf8595cn-8000.proxy.runpod.net/v1" },
      { name = "VLM_API_KEY", value = "sk-IrR7Bwxtin0haWagUnPrBgq5PurnUz86" },
      { name = "VLM_MODEL_ID", value = "AIX-01/Qwen3-VL-2B-Instruct-unsloth-bnb-4bit-3000steps-r64-b8-merged-16bit" },

      # LangSmith
      { name = "LANGSMITH_TRACING", value = "true" },
      { name = "LANGSMITH_PROJECT", value = "${var.project_name}-prd" },
    ]

    secrets = [
      {
        name      = "OPENAI_API_KEY"
        valueFrom = "${aws_secretsmanager_secret.ai_api_keys.arn}:OPENAI_API_KEY::"
      },
      {
        name      = "LANGSMITH_API_KEY"
        valueFrom = "${aws_secretsmanager_secret.ai_api_keys.arn}:LANGSMITH_API_KEY::"
      },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.agent_worker.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "worker"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
  }])
}

resource "aws_ecs_service" "agent_worker" {
  name            = "${var.project_name}-agent-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.agent_worker.arn
  desired_count   = var.worker_min_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.agent_worker.id]
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}

# ── Auto Scaling ─────────────────────────────

resource "aws_appautoscaling_target" "worker" {
  max_capacity       = var.worker_max_count
  min_capacity       = var.worker_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.agent_worker.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# SQS 큐 깊이 기반 스케일링
resource "aws_appautoscaling_policy" "worker_sqs" {
  name               = "${var.project_name}-worker-sqs-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = var.worker_sqs_target_value
    scale_in_cooldown  = 300 # 5분
    scale_out_cooldown = 60  # 1분

    customized_metric_specification {
      metric_name = "ApproximateNumberOfMessagesVisible"
      namespace   = "AWS/SQS"
      statistic   = "Average"

      dimensions {
        name  = "QueueName"
        value = aws_sqs_queue.analysis.name
      }
    }
  }
}

# CPU 기반 스케일링 (보조)
resource "aws_appautoscaling_policy" "worker_cpu" {
  name               = "${var.project_name}-worker-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.worker.resource_id
  scalable_dimension = aws_appautoscaling_target.worker.scalable_dimension
  service_namespace  = aws_appautoscaling_target.worker.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
