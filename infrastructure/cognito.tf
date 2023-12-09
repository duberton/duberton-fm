resource "aws_cognito_user_pool" "user_pool" {
  name = "duberton-fm-user-pool"
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name                                 = "duberton-fm-app-client"
  user_pool_id                         = aws_cognito_user_pool.user_pool.id
  generate_secret                      = true
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["client_credentials"]
  allowed_oauth_scopes                 = ["https://dubertonfm.com/write"]
  supported_identity_providers         = ["COGNITO"]
  refresh_token_validity               = 1

}

resource "aws_cognito_resource_server" "resource_server" {
  identifier = "https://dubertonfm.com"
  name       = "duberton"

  scope {
    scope_name        = "write"
    scope_description = "write"
  }

  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "dubertonfm"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}
