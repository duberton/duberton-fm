resource "aws_sqs_queue" "duberton_fm_sqs" {
  name   = "duberton-fm-sqs"
  policy = data.aws_iam_policy_document.duberton_fm_sqs_queue_policy.json
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.duberton_fm_sqs_dlq.arn
    maxReceiveCount     = 1
  })
}

resource "aws_sqs_queue" "duberton_fm_sqs_dlq" {
  name                      = "duberton-fm-sqs-dlq"
  message_retention_seconds = 1209600
}