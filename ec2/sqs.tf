##############################################
# SQS Queues
##############################################

resource "aws_sqs_queue" "analysis_dlq" {
  name                      = "${var.project_name}-analysis-dlq"
  message_retention_seconds = 1209600 # 14일

  tags = { Name = "${var.project_name}-analysis-dlq" }
}

resource "aws_sqs_queue" "analysis" {
  name                       = "${var.project_name}-analysis-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.analysis_dlq.arn
    maxReceiveCount     = 3
  })

  tags = { Name = "${var.project_name}-analysis-queue" }
}
