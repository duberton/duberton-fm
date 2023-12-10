module "lambda_processor" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "duberton-fm-lambda-processor"
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
  event_source_arn        = aws_sqs_queue.duberton_fm_sqs.arn
  function_name           = module.lambda_processor.lambda_function_name
  enabled                 = true
  function_response_types = ["ReportBatchItemFailures"]
}

module "lambda_query" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "duberton-fm-lambda-query"
  handler       = "main"
  runtime       = "go1.x"
  publish       = true

  source_path = "../lambda-track-query/bin/main"

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

  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      principal  = "apigateway.amazonaws.com"
      source_arn = "${aws_api_gateway_rest_api.duberton_fm_rest_api.execution_arn}/*/*"
    }
  }
}