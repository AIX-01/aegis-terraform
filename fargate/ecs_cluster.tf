##############################################
# ECS Cluster & CloudWatch Log Groups
##############################################

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.project_name}-cluster" }
}

# ── CloudWatch Log Groups ────────────────────

resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/${var.project_name}-backend"
  retention_in_days = 30
  tags              = { Name = "${var.project_name}-backend-logs" }
}

resource "aws_cloudwatch_log_group" "agent_ingest" {
  name              = "/ecs/${var.project_name}-agent-ingest"
  retention_in_days = 30
  tags              = { Name = "${var.project_name}-agent-ingest-logs" }
}

resource "aws_cloudwatch_log_group" "agent_worker" {
  name              = "/ecs/${var.project_name}-agent-worker"
  retention_in_days = 30
  tags              = { Name = "${var.project_name}-agent-worker-logs" }
}

resource "aws_cloudwatch_log_group" "mediamtx" {
  name              = "/ecs/${var.project_name}-mediamtx"
  retention_in_days = 30
  tags              = { Name = "${var.project_name}-mediamtx-logs" }
}

resource "aws_cloudwatch_log_group" "qdrant" {
  name              = "/ecs/${var.project_name}-qdrant"
  retention_in_days = 30
  tags              = { Name = "${var.project_name}-qdrant-logs" }
}
