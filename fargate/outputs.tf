##############################################
# Outputs
##############################################

# ── Network ──────────────────────────────────

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

# ── ALB ──────────────────────────────────────

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

# ── RDS ──────────────────────────────────────

output "rds_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.postgres.endpoint
}

# ── ElastiCache ──────────────────────────────

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

# ── SQS ──────────────────────────────────────

output "sqs_queue_url" {
  description = "SQS analysis queue URL"
  value       = aws_sqs_queue.analysis.url
}

# ── ECR ──────────────────────────────────────

output "ecr_backend_url" {
  description = "ECR backend repository URL"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_agent_url" {
  description = "ECR agent repository URL (single image, AGENT_MODE로 ingest/worker 분기)"
  value       = aws_ecr_repository.agent.repository_url
}

# ── CloudFront ───────────────────────────────

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

# ── S3 ───────────────────────────────────────

output "s3_clips_bucket" {
  description = "S3 clips bucket name"
  value       = aws_s3_bucket.clips.id
}

output "s3_frontend_bucket" {
  description = "S3 frontend bucket name"
  value       = aws_s3_bucket.frontend.id
}

# ── NLB ────────────────────────────────────

output "nlb_dns_name" {
  description = "NLB DNS name (WebRTC UDP)"
  value       = aws_lb.nlb.dns_name
}

# ── EFS ────────────────────────────────────

output "efs_id" {
  description = "EFS file system ID (Qdrant storage)"
  value       = aws_efs_file_system.qdrant.id
}

# ── Service Discovery ─────────────────────

output "service_discovery_namespace" {
  description = "Cloud Map namespace"
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "service_discovery_namespace_id" {
  description = "Cloud Map namespace ID"
  value       = aws_service_discovery_private_dns_namespace.main.id
}

# ── GitHub Actions ─────────────────────────

output "github_actions_role_arn" {
  description = "GitHub Actions OIDC role ARN"
  value       = aws_iam_role.github_actions.arn
}
