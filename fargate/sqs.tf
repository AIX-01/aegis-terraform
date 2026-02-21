##############################################
# SQS Queues
##############################################

# ── Dead Letter Queue ────────────────────────

resource "aws_sqs_queue" "analysis_dlq" {
  name                      = "${var.project_name}-analysis-dlq"
  message_retention_seconds = 1209600 # 14일

  tags = { Name = "${var.project_name}-analysis-dlq" }
}

# ── Analysis Queue (Main) ────────────────────

resource "aws_sqs_queue" "analysis" {
  name                       = "${var.project_name}-analysis-queue"
  visibility_timeout_seconds = 300 # 5분 (VLM + LangGraph 분석 시간 고려)
  message_retention_seconds  = 86400 # 1일
  receive_wait_time_seconds  = 20 # Long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.analysis_dlq.arn
    maxReceiveCount     = 3 # 3번 실패시 DLQ로 이동
  })

  tags = { Name = "${var.project_name}-analysis-queue" }
}
