##############################################
# ECS Service - Agent Ingestion [EC2 Launch Type]
##############################################

resource "aws_ecs_task_definition" "agent_ingest" {
  family                   = "${var.project_name}-agent-ingest"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = var.agent_ingest_cpu
  memory                   = var.agent_ingest_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.agent_task.arn

  container_definitions = jsonencode([{
    name  = "agent-ingest"
    image = "${aws_ecr_repository.agent.repository_url}:latest"

    environment = [
      # Agent 모드 (ingest: Producer만 실행)
      { name = "AGENT_MODE", value = "ingest" },

      { name = "SQS_QUEUE_URL", value = aws_sqs_queue.analysis.url },
      { name = "AWS_REGION", value = var.aws_region },
      { name = "REDIS_HOST", value = aws_elasticache_cluster.redis.cache_nodes[0].address },
      { name = "REDIS_PORT", value = "6379" },
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

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 100
  }

  ordered_placement_strategy {
    type  = "spread"
    field = "instanceId"
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
