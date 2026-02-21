##############################################
# Security Groups
##############################################

# ── ALB ──────────────────────────────────────

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
    description = "HTTP (redirect to HTTPS)"
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

# ── Backend (Spring Boot) ────────────────────

resource "aws_security_group" "backend" {
  name        = "${var.project_name}-backend-sg"
  description = "Backend - Allow traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-backend-sg" }
}

# ── Agent Ingestion ──────────────────────────

resource "aws_security_group" "agent_ingest" {
  name        = "${var.project_name}-agent-ingest-sg"
  description = "Agent Ingestion - RTSP ingest, outbound to SQS/S3"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-agent-ingest-sg" }
}

# ── Agent Worker ─────────────────────────────

resource "aws_security_group" "agent_worker" {
  name        = "${var.project_name}-agent-worker-sg"
  description = "Agent Worker - Outbound only (SQS, S3, Backend)"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-agent-worker-sg" }
}

# ── MediaMTX ─────────────────────────────────

resource "aws_security_group" "mediamtx" {
  name        = "${var.project_name}-mediamtx-sg"
  description = "MediaMTX - Streaming server"
  vpc_id      = aws_vpc.main.id

  # API port - Backend webhook access
  ingress {
    description     = "API from Backend"
    from_port       = 9997
    to_port         = 9997
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
  }

  # RTSP - Agent Ingest access
  ingress {
    description     = "RTSP from Agent Ingest"
    from_port       = 8554
    to_port         = 8554
    protocol        = "tcp"
    security_groups = [aws_security_group.agent_ingest.id]
  }

  # WHEP HTTP - ALB access for browser streaming
  ingress {
    description     = "WHEP from ALB"
    from_port       = 8889
    to_port         = 8889
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SRT ingest - VPC only (Tailscale or direct)
  ingress {
    description = "SRT from VPC"
    from_port   = 8890
    to_port     = 8890
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  # WebRTC UDP - Public (NLB forwards)
  ingress {
    description = "WebRTC UDP from NLB/Internet"
    from_port   = 8189
    to_port     = 8189
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # NLB health check on API port
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

# ── Qdrant ───────────────────────────────────

resource "aws_security_group" "qdrant" {
  name        = "${var.project_name}-qdrant-sg"
  description = "Qdrant - Vector DB, allow from agent services"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Qdrant HTTP API from Agents"
    from_port   = 6333
    to_port     = 6333
    protocol    = "tcp"
    security_groups = [
      aws_security_group.agent_ingest.id,
      aws_security_group.agent_worker.id,
    ]
  }

  ingress {
    description = "Qdrant gRPC from Agents"
    from_port   = 6334
    to_port     = 6334
    protocol    = "tcp"
    security_groups = [
      aws_security_group.agent_ingest.id,
      aws_security_group.agent_worker.id,
    ]
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

# ── RDS (PostgreSQL) ─────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "RDS - Allow PostgreSQL from backend only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Backend"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
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
  description = "Redis - Allow from backend and agent services"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Redis from Backend + Agents"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    security_groups = [
      aws_security_group.backend.id,
      aws_security_group.agent_ingest.id,
      aws_security_group.agent_worker.id,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-redis-sg" }
}
