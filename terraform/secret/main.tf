locals {
  commercetools_secret = {
    client_id     = commercetools_api_client.main.id
    client_secret = commercetools_api_client.main.secret
    client_scopes = var.scopes
  }
}

data "aws_lambda_function" "commercetools_token_refresher" {
  function_name = "${var.site}-commercetools_token_refresher"
}

resource "aws_secretsmanager_secret" "commercetools_client" {
  name = "${var.name}/commercetools-client"
}

resource "aws_secretsmanager_secret_version" "commercetools_client" {
  secret_id     = aws_secretsmanager_secret.commercetools_client.id
  secret_string = jsonencode(local.commercetools_secret)
}

resource "aws_secretsmanager_secret" "ct_access_token" {
  name = "${var.name}/ct-access-token"

  tags = {
    lambda        = var.name
    sm_client_arn = aws_secretsmanager_secret.commercetools_client.arn
    scope_hash    = sha256(join(":::", var.scopes))
    site          = var.site
  }
}

resource "aws_secretsmanager_secret_rotation" "ct_access_token_rotation" {
  secret_id = aws_secretsmanager_secret.ct_access_token.id
  rotation_lambda_arn = replace(
    data.aws_lambda_function.commercetools_token_refresher.arn,
    ":$LATEST",
    "",
  )

  rotation_rules {
    automatically_after_days = 1
  }
}
