provider "aws" {
  region = "us-east-1"
}

module "dynamodb_table" {
  source = "terraform-aws-modules/dynamodb-table/aws"

  name      = "duberton-fm"
  hash_key  = "pk"
  range_key = "sk"

  attributes = [
    {
      name = "pk"
      type = "S"
    },
    {
      name = "sk"
      type = "S"
    }
  ]
}

resource "aws_api_gateway_rest_api" "duberton_fm_rest_api" {
  name        = "duberton-fm API"
  description = "duberton-fm"
}

resource "aws_api_gateway_resource" "duberton_fm_rest_api_create_resource" {
  rest_api_id = aws_api_gateway_rest_api.duberton_fm_rest_api.id
  parent_id   = aws_api_gateway_rest_api.duberton_fm_rest_api.root_resource_id
  path_part   = "create"
}

resource "aws_api_gateway_method" "duberton_fm_rest_api_create_method" {
  rest_api_id   = aws_api_gateway_rest_api.duberton_fm_rest_api.id
  authorization = "NONE"
  resource_id   = aws_api_gateway_resource.duberton_fm_rest_api_create_resource.id
  http_method   = "POST"
}

resource "aws_api_gateway_integration" "duberton_fm_rest_api_create_integration" {
  rest_api_id             = aws_api_gateway_rest_api.duberton_fm_rest_api.id
  resource_id             = aws_api_gateway_resource.duberton_fm_rest_api_create_resource.id
  http_method             = aws_api_gateway_method.duberton_fm_rest_api_create_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:us-east-1:sns:path//"
  credentials             = aws_iam_role.api_gateway_role.arn
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=Publish&TopicArn=$util.urlEncode('${aws_sns_topic.duberton_fm_topic.arn}')&Message=$util.urlEncode($input.body)"
  }
  # type                    = "AWS_PROXY"
  # uri                     = module.lambda.lambda_function_invoke_arn
}

resource "aws_api_gateway_integration_response" "duberton_fm_rest_api_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.duberton_fm_rest_api.id
  resource_id = aws_api_gateway_resource.duberton_fm_rest_api_create_resource.id
  http_method = aws_api_gateway_method.duberton_fm_rest_api_create_method.http_method
  status_code = "200"

  response_templates = {
    "application/json" = "{\"body\": \"successfully published\"}"
  }
  depends_on = [
    aws_api_gateway_integration.duberton_fm_rest_api_create_integration
  ]
}

resource "aws_api_gateway_method_response" "duberton_fm_rest_api_method_response" {
  rest_api_id = aws_api_gateway_rest_api.duberton_fm_rest_api.id
  resource_id = aws_api_gateway_resource.duberton_fm_rest_api_create_resource.id
  http_method = aws_api_gateway_method.duberton_fm_rest_api_create_method.http_method
  status_code = "200"
}

resource "aws_api_gateway_deployment" "duberton_fm_rest_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.duberton_fm_rest_api_create_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.duberton_fm_rest_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.duberton_fm_rest_api_create_integration,
      aws_api_gateway_rest_api.duberton_fm_rest_api
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "duberton_fm_rest_api_stage" {
  deployment_id = aws_api_gateway_deployment.duberton_fm_rest_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.duberton_fm_rest_api.id
  stage_name    = "default"
}

resource "aws_sns_topic" "duberton_fm_topic" {
  name = "duberton-fm-topic"
}

resource "aws_sqs_queue" "duberton_fm_sqs" {
  name   = "duberton-fm-sqs"
  policy = data.aws_iam_policy_document.duberton_fm_sqs_queue_policy.json
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.duberton_fm_sqs_dlq.arn
    maxReceiveCount     = 2
  })
}

resource "aws_sqs_queue" "duberton_fm_sqs_dlq" {
  name                      = "duberton-fm-sqs-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sns_topic_subscription" "duberton_fm_sns_sqs_sub" {
  topic_arn            = aws_sns_topic.duberton_fm_topic.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.duberton_fm_sqs.arn
  raw_message_delivery = true
}

module "lambda" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "duberton-fm-lambda"
  handler       = "main"
  runtime       = "go1.x"
  publish       = true

  source_path = "../lambda-track-processor/bin/main"

  attach_tracing_policy    = true
  attach_policy_statements = true

  policy_statements = {
    lambda = {
      effect = "Allow",
      actions = [
        "lambda:InvokeFunction",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "dynamodb:DeleteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "sqs:GetQueueAttributes",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ],
      resources = ["*"]
    }
  }

  # allowed_triggers = {
  #   AllowExecutionFromAPIGateway = {
  #     service    = "apigateway"
  #     principal  = "apigateway.amazonaws.com"
  #     source_arn = "${aws_api_gateway_rest_api.duberton_fm_rest_api.execution_arn}/*/*"
  #   }
  # }
}


resource "aws_lambda_event_source_mapping" "lambda_sqs_mapping" {
  event_source_arn = aws_sqs_queue.duberton_fm_sqs.arn
  function_name    = module.lambda.lambda_function_name
  enabled          = true
}


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

# Attach a policy to the IAM role allowing API Gateway to publish to SNS
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
    sid    = "example-sns-topic"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = [
      "SQS:SendMessage",
    ]

    resources = [
      "*",
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [aws_sns_topic.duberton_fm_topic.arn]
    }
  }
}
