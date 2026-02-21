##############################################
# Variables
##############################################

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "aegis"
}

# ── VPC ──────────────────────────────────────

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  type    = list(string)
  default = ["ap-northeast-2a", "ap-northeast-2c"]
}

# ── RDS ──────────────────────────────────────

variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "aegis"
}

variable "db_username" {
  type    = string
  default = "aegis_admin"
}

# ── ElastiCache ──────────────────────────────

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

# ── EC2 Instances ────────────────────────────

variable "ec2_instance_type" {
  description = "EC2 instance type for ECS container instances"
  type        = string
  default     = "t3.medium"
}

variable "ec2_ami_id" {
  description = "ECS-optimized AMI ID (leave empty for latest)"
  type        = string
  default     = ""
}

variable "ec2_key_name" {
  description = "SSH key pair name (optional, for debugging)"
  type        = string
  default     = ""
}

variable "ec2_min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 2
}

variable "ec2_max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 6
}

variable "ec2_desired_capacity" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 2
}

# ── ECS Task Sizes ───────────────────────────

variable "backend_cpu" {
  type    = number
  default = 512
}

variable "backend_memory" {
  type    = number
  default = 1024
}

variable "agent_ingest_cpu" {
  type    = number
  default = 512
}

variable "agent_ingest_memory" {
  type    = number
  default = 1024
}

variable "agent_worker_cpu" {
  type    = number
  default = 1024
}

variable "agent_worker_memory" {
  type    = number
  default = 2048
}

variable "worker_min_count" {
  type    = number
  default = 1
}

variable "worker_max_count" {
  type    = number
  default = 8
}

variable "worker_sqs_target_value" {
  type    = number
  default = 5
}

# ── MediaMTX ─────────────────────────────────

variable "mediamtx_cpu" {
  type    = number
  default = 512
}

variable "mediamtx_memory" {
  type    = number
  default = 1024
}

variable "mediamtx_image_tag" {
  type    = string
  default = "latest-ffmpeg"
}

# ── Qdrant ───────────────────────────────────

variable "qdrant_cpu" {
  type    = number
  default = 512
}

variable "qdrant_memory" {
  type    = number
  default = 1024
}

variable "qdrant_image_tag" {
  type    = string
  default = "latest"
}

# ── EFS ──────────────────────────────────────

variable "efs_performance_mode" {
  type    = string
  default = "generalPurpose"
}

variable "efs_throughput_mode" {
  type    = string
  default = "elastic"
}

# ── Tailscale VPN ────────────────────────────

variable "enable_tailscale" {
  type    = bool
  default = false
}

variable "tailscale_hostname" {
  type    = string
  default = "aegis-mediamtx"
}

variable "camera_rtsp_url" {
  type    = string
  default = ""
}

# ── Service Discovery ────────────────────────

variable "service_discovery_namespace" {
  type    = string
  default = "aegis.local"
}

# ── GitHub OIDC ──────────────────────────────

variable "github_org" {
  type    = string
  default = ""
}

variable "github_repos" {
  type    = list(string)
  default = ["aegis-backend", "aegis-ai-agent", "aegis-frontend"]
}

# ── Domain ───────────────────────────────────

variable "domain_name" {
  type    = string
  default = ""
}
