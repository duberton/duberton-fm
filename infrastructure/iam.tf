resource "aws_iam_role" "api_gateway_role" {
  name = "api-gateway-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_policy" "api_gateway_policy" {
  name = "api-gateway-policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish"
      ],
      "Resource": "${aws_sns_topic.duberton_fm_topic.arn}"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "api_gateway_attachment" {
  policy_arn = aws_iam_policy.api_gateway_policy.arn
  role       = aws_iam_role.api_gateway_role.name
}

data "aws_iam_policy_document" "duberton_fm_sqs_queue_policy" {

  statement {
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "SQS:SendMessage",
    ]

    resources = [
      "*"
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [aws_sns_topic.duberton_fm_topic.arn]
    }
  }
}