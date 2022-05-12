locals {
  s3_bucket = "public-mach-components-${local.aws_region_name}"

  lambda_environment_variables = merge(
    {
      COMPONENT_VERSION = var.component_version
      SITE              = var.site
      SERVERLESS_ALIAS  = var.site
      // abuse SERVERLESS_ALIAS to push site as the 'alias' tag.
      ENVIRONMENT = var.environment

      SENTRY_DSN         = var.sentry_dsn
      SENTRY_ENVIRONMENT = var.environment
      SENTRY_RELEASE     = "commercetools_token_refresher@${var.component_version}"

      OAUTHLIB_RELAX_TOKEN_SCOPE = "true"
      API_URL                    = var.ct_api_url
      AUTH_URL                   = var.ct_auth_url
    }
  )
}

resource "aws_lambda_function" "commercetools_token_refresher" {
  function_name = local.lambda_name
  role          = aws_iam_role.lambda.arn
  handler       = "handler.handle"

  runtime     = "python3.8"
  timeout     = 30
  memory_size = 128

  s3_bucket = local.s3_bucket
  s3_key    = "commercetools_token_refresher-${var.component_version}.zip"

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = local.lambda_environment_variables
  }

  dynamic "vpc_config" {
    for_each           = local.vpc_id == null ? []: [1]

    content {
      subnet_ids         = local.subnet_ids
      security_group_ids = [aws_security_group.lambda.0.id]
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_log_group,
    aws_iam_role_policy.lambda_policy,
  ]
}

resource "aws_lambda_permission" "rotate_secrets_manager" {
  statement_id   = "AllowSecretsManagerRotation"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.commercetools_token_refresher.function_name
  principal      = "secretsmanager.amazonaws.com"
  source_account = local.aws_account_id
}
