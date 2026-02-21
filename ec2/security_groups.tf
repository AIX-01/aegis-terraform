##############################################
# Security Groups
##############################################

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "ALB - Allow HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-alb-sg" }
}

# ── EC2 Container Instances ──────────────────

resource "aws_security_group" "ecs_instances" {
  name        = "${var.project_name}-ecs-instances-sg"
  description = "ECS EC2 instances - Allow from ALB + internal"
  vpc_id      = aws_vpc.main.id

  # ALB에서 동적 포트로 들어오는 트래픽 (bridge 모드)
  ingress {
    description     = "Dynamic ports from ALB"
    from_port       = 32768
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # 인스턴스 간 통신 (같은 SG 내)
  ingress {
    description = "Internal communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # WebRTC UDP for MediaMTX (NLB forwards)
  ingress {
    description = "WebRTC UDP from NLB/Internet"
    from_port   = 8189
    to_port     = 8189
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SRT ingest for MediaMTX (VPC only)
  ingress {
    description = "SRT from VPC"
    from_port   = 8890
    to_port     = 8890
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-ecs-instances-sg" }
}

# ── MediaMTX (awsvpc mode even on EC2) ───────

resource "aws_security_group" "mediamtx" {
  name        = "${var.project_name}-mediamtx-sg"
  description = "MediaMTX - Streaming server (awsvpc)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "API from ECS instances"
    from_port       = 9997
    to_port         = 9997
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
  }

  ingress {
    description     = "RTSP from ECS instances"
    from_port       = 8554
    to_port         = 8554
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
  }

  ingress {
    description     = "WHEP from ALB"
    from_port       = 8889
    to_port         = 8889
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SRT from VPC"
    from_port   = 8890
    to_port     = 8890
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "WebRTC UDP from NLB/Internet"
    from_port   = 8189
    to_port     = 8189
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NLB health check (TCP)"
    from_port   = 9997
    to_port     = 9997
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-mediamtx-sg" }
}

# ── Qdrant (awsvpc mode even on EC2) ─────────

resource "aws_security_group" "qdrant" {
  name        = "${var.project_name}-qdrant-sg"
  description = "Qdrant - Vector DB (awsvpc)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Qdrant HTTP from ECS instances"
    from_port       = 6333
    to_port         = 6333
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
  }

  ingress {
    description     = "Qdrant gRPC from ECS instances"
    from_port       = 6334
    to_port         = 6334
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-qdrant-sg" }
}

# ── EFS (for Qdrant storage) ─────────────────

resource "aws_security_group" "efs" {
  name        = "${var.project_name}-efs-sg"
  description = "EFS - Allow NFS from Qdrant"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from Qdrant"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.qdrant.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-efs-sg" }
}

# ── RDS ──────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS - Allow from ECS instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

# ── ElastiCache (Redis) ─────────────────────

resource "aws_security_group" "redis" {
  name        = "${var.project_name}-redis-sg"
  description = "Redis - Allow from ECS instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from ECS"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_instances.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-redis-sg" }
}
