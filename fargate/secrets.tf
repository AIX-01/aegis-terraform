##############################################
# Secrets Manager
##############################################

# DB 비밀번호 자동 생성
resource "random_password" "db_password" {
  length  = 24
  special = true
  # RDS 허용 특수문자만 사용
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}/db-password"
  recovery_window_in_days = 7
  tags                    = { Name = "${var.project_name}-db-password" }
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# JWT Secret
resource "random_password" "jwt_secret" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}/jwt-secret"
  recovery_window_in_days = 7
  tags                    = { Name = "${var.project_name}-jwt-secret" }
}

resource "aws_secretsmanager_secret_version" "jwt_secret" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = random_password.jwt_secret.result
}

# AI API Keys (수동으로 값 설정 필요)
resource "aws_secretsmanager_secret" "ai_api_keys" {
  name                    = "${var.project_name}/ai-api-keys"
  recovery_window_in_days = 7
  tags                    = { Name = "${var.project_name}-ai-api-keys" }
}

# Tailscale Auth Key (conditional)
resource "aws_secretsmanager_secret" "tailscale_auth_key" {
  count                   = var.enable_tailscale ? 1 : 0
  name                    = "${var.project_name}/tailscale-auth-key"
  recovery_window_in_days = 7
  tags                    = { Name = "${var.project_name}-tailscale-auth-key" }
}
