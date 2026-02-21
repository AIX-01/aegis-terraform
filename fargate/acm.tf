##############################################
# ACM Certificates
##############################################

# ALB용 인증서 (ap-northeast-2)
resource "aws_acm_certificate" "alb" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = "api.${var.domain_name}"
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-alb-cert" }
}

# CloudFront용 인증서 (반드시 us-east-1)
resource "aws_acm_certificate" "cloudfront" {
  count             = var.domain_name != "" ? 1 : 0
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-cf-cert" }
}
