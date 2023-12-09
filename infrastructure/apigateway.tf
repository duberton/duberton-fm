data "aws_region" "current" {}

resource "aws_api_gateway_rest_api" "duberton_fm_rest_api" {
  name        = "duberton-fm"
  description = "duberton-fm API"
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
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sns:path//"
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
