##############################################
# ECR Repositories
##############################################

resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}/backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "${var.project_name}-ecr-backend" }
}

resource "aws_ecr_repository" "agent_ingest" {
  name                 = "${var.project_name}/agent-ingest"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "${var.project_name}-ecr-agent-ingest" }
}

resource "aws_ecr_repository" "agent_worker" {
  name                 = "${var.project_name}/agent-worker"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "${var.project_name}-ecr-agent-worker" }
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [{ rulePriority = 1, description = "Keep last 10", selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }, action = { type = "expire" } }]
  })
}

resource "aws_ecr_lifecycle_policy" "agent_ingest" {
  repository = aws_ecr_repository.agent_ingest.name
  policy = jsonencode({
    rules = [{ rulePriority = 1, description = "Keep last 10", selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }, action = { type = "expire" } }]
  })
}

resource "aws_ecr_lifecycle_policy" "agent_worker" {
  repository = aws_ecr_repository.agent_worker.name
  policy = jsonencode({
    rules = [{ rulePriority = 1, description = "Keep last 10", selection = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }, action = { type = "expire" } }]
  })
}
