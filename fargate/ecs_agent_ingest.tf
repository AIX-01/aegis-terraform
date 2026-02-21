##############################################
# ECS Service - Agent Ingestion
##############################################

resource "aws_ecs_task_definition" "agent_ingest" {
  family                   = "${var.project_name}-agent-ingest"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.agent_ingest_cpu
  memory                   = var.agent_ingest_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.agent_task.arn

  container_definitions = jsonencode([{
    name  = "agent-ingest"
    image = "${aws_ecr_repository.agent_ingest.repository_url}:latest"

    environment = [
      # SQS (윈도우 태스크 전송 대상)
      { name = "SQS_QUEUE_URL", value = aws_sqs_queue.analysis.url },
      { name = "AWS_REGION", value = var.aws_region },

      # Redis (카메라 동기화 Pub/Sub)
      { name = "REDIS_HOST", value = aws_elasticache_cluster.redis.cache_nodes[0].address },
      { name = "REDIS_PORT", value = "6379" },

      # S3 (프레임 임시 저장)
      { name = "S3_BUCKET", value = aws_s3_bucket.clips.id },

      # MediaMTX RTSP (Cloud Map)
      { name = "RTSP_HOST", value = "mediamtx.${var.service_discovery_namespace}" },

      # Qdrant (Cloud Map)
      { name = "QDRANT_HOST", value = "qdrant.${var.service_discovery_namespace}" },
      { name = "QDRANT_PORT", value = "6333" },
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.agent_ingest.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ingest"
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

resource "aws_ecs_service" "agent_ingest" {
  name            = "${var.project_name}-agent-ingest"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.agent_ingest.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.agent_ingest.id]
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
