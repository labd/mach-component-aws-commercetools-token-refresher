locals {
  commercetools_secret = {
    client_id     = commercetools_api_client.main.id
    client_secret = commercetools_api_client.main.secret
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
  rotation_lambda_arn = replace(
    data.aws_lambda_function.commercetools_token_refresher.arn,
    ":$LATEST",
    "",
  )

  rotation_rules {
    automatically_after_days = 1
  }

  tags = {
    lambda           = var.name
    sm_client_arn    = aws_secretsmanager_secret.commercetools_client.arn
    sm_client_scopes = join(" ", var.scopes)
  }
}