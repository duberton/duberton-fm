data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_api_gateway_rest_api" "duberton_fm_rest_api" {
  name        = "duberton-fm"
  description = "duberton-fm API"
  body        = data.template_file.tracks_openapi_file.rendered
}

data "template_file" "tracks_openapi_file" {
  template = templatefile("../openapi/duberton-fm.yaml", {
    aws_sns_path_uri     = "arn:aws:apigateway:${data.aws_region.current.name}:sns:path//"
    api_gateway_role_arn = aws_iam_role.api_gateway_role.arn
    aws_sns_topic_arn    = aws_sns_topic.duberton_fm_topic.arn
    cognito_user_pool_id = "arn:aws:cognito-idp:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:userpool/${aws_cognito_user_pool.user_pool.id}"

  })
}

resource "aws_api_gateway_deployment" "duberton_fm_rest_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.duberton_fm_rest_api.id

  triggers = {
    redeployment = sha1(file("../openapi/duberton-fm.yaml"))
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
