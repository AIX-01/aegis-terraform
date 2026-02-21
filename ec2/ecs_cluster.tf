##############################################
# ECS Cluster (EC2 Launch Type)
# Fargate 버전과 차이: Capacity Provider 사용
##############################################

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.project_name}-cluster" }
}

# ── Capacity Provider (EC2 고유) ─────────────
# ASG와 연결하여 ECS가 자동으로 EC2 인스턴스 수를 관리

resource "aws_ecs_capacity_provider" "ec2" {
  name = "${var.project_name}-ec2-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 80 # EC2 인스턴스 리소스 80% 활용 목표
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 100
    base              = 1
  }
}

# ── CloudWatch Log Groups ────────────────────

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "agent_ingest" {
  name              = "/ecs/${var.project_name}-agent-ingest"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "agent_worker" {
  name              = "/ecs/${var.project_name}-agent-worker"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "mediamtx" {
  name              = "/ecs/${var.project_name}-mediamtx"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_group" "qdrant" {
  name              = "/ecs/${var.project_name}-qdrant"
  retention_in_days = 30
}
