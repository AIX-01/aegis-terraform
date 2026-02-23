##############################################
# Outputs
##############################################

output "vpc_id" {
  value = aws_vpc.main.id
}

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "sqs_queue_url" {
  value = aws_sqs_queue.analysis.url
}

output "ecr_backend_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecr_agent_url" {
  description = "ECR agent repository URL (single image, AGENT_MODE로 ingest/worker 분기)"
  value       = aws_ecr_repository.agent.repository_url
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

output "asg_name" {
  description = "EC2 Auto Scaling Group name"
  value       = aws_autoscaling_group.ecs.name
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
