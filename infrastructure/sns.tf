resource "aws_sns_topic" "duberton_fm_topic" {
  name = "duberton-fm-topic"
}

resource "aws_sns_topic_subscription" "duberton_fm_sns_sqs_sub" {
  topic_arn            = aws_sns_topic.duberton_fm_topic.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.duberton_fm_sqs.arn
  raw_message_delivery = true
}
