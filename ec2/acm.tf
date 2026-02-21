##############################################
# ACM Certificates
##############################################

resource "aws_acm_certificate" "alb" {
  count             = var.domain_name != "" ? 1 : 0
  domain_name       = "api.${var.domain_name}"
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-alb-cert" }
}

resource "aws_acm_certificate" "cloudfront" {
  count             = var.domain_name != "" ? 1 : 0
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle { create_before_destroy = true }
  tags = { Name = "${var.project_name}-cf-cert" }
}
