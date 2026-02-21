##############################################
# Secrets Manager
##############################################

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}/db-password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}/jwt-secret"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

resource "aws_secretsmanager_secret" "ai_api_keys" {
  name                    = "${var.project_name}/ai-api-keys"
  recovery_window_in_days = 7
}

# Tailscale Auth Key (conditional)
resource "aws_secretsmanager_secret" "tailscale_auth_key" {
  count                   = var.enable_tailscale ? 1 : 0
  name                    = "${var.project_name}/tailscale-auth-key"
  recovery_window_in_days = 7
}
