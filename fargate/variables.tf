##############################################
# Variables
##############################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "aegis"
}

# ── VPC ──────────────────────────────────────

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

# ── RDS ──────────────────────────────────────

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "aegis"
}

variable "db_username" {
  description = "Database master username"
  type        = string
  default     = "aegis_admin"
}

# ── ElastiCache ──────────────────────────────

variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

# ── ECS ──────────────────────────────────────

variable "backend_cpu" {
  description = "Backend task CPU units"
  type        = number
  default     = 512
}

variable "backend_memory" {
  description = "Backend task memory (MB)"
  type        = number
  default     = 1024
}

variable "agent_ingest_cpu" {
  description = "Agent ingestion task CPU units"
  type        = number
  default     = 512
}

variable "agent_ingest_memory" {
  description = "Agent ingestion task memory (MB)"
  type        = number
  default     = 1024
}

variable "agent_worker_cpu" {
  description = "Agent worker task CPU units"
  type        = number
  default     = 1024
}

variable "agent_worker_memory" {
  description = "Agent worker task memory (MB)"
  type        = number
  default     = 2048
}

variable "worker_min_count" {
  description = "Minimum number of worker tasks"
  type        = number
  default     = 1
}

variable "worker_max_count" {
  description = "Maximum number of worker tasks"
  type        = number
  default     = 8
}

variable "worker_sqs_target_value" {
  description = "Target SQS messages per worker task for auto-scaling"
  type        = number
  default     = 5
}

# ── MediaMTX ─────────────────────────────────

variable "mediamtx_cpu" {
  description = "MediaMTX task CPU units"
  type        = number
  default     = 512
}

variable "mediamtx_memory" {
  description = "MediaMTX task memory (MB)"
  type        = number
  default     = 1024
}

variable "mediamtx_image_tag" {
  description = "MediaMTX Docker image tag"
  type        = string
  default     = "latest-ffmpeg"
}

# ── Qdrant ───────────────────────────────────

variable "qdrant_cpu" {
  description = "Qdrant task CPU units"
  type        = number
  default     = 512
}

variable "qdrant_memory" {
  description = "Qdrant task memory (MB)"
  type        = number
  default     = 1024
}

variable "qdrant_image_tag" {
  description = "Qdrant Docker image tag"
  type        = string
  default     = "latest"
}

# ── EFS ──────────────────────────────────────

variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "elastic"
}

# ── Tailscale VPN ────────────────────────────

variable "enable_tailscale" {
  description = "Enable Tailscale sidecar for MediaMTX (camera VPN)"
  type        = bool
  default     = false
}

variable "tailscale_hostname" {
  description = "Tailscale hostname for MediaMTX"
  type        = string
  default     = "aegis-mediamtx"
}

variable "camera_rtsp_url" {
  description = "Camera RTSP URL (used by agent ingest)"
  type        = string
  default     = ""
}

# ── Service Discovery ────────────────────────

variable "service_discovery_namespace" {
  description = "Cloud Map private DNS namespace"
  type        = string
  default     = "aegis.local"
}

# ── GitHub OIDC ──────────────────────────────

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = ""
}

variable "github_repos" {
  description = "List of GitHub repo names allowed to assume the deploy role"
  type        = list(string)
  default     = ["aegis-backend", "aegis-ai-agent", "aegis-frontend"]
}

# ── Domain ───────────────────────────────────

variable "domain_name" {
  description = "Domain name (optional, set empty to skip Route53/ACM)"
  type        = string
  default     = ""
}
