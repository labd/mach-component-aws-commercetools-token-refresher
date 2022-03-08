data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "commercetools_token_refresher-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# execution role
data "aws_iam_policy_document" "lambda_policy" {
  # Secrets manager
  statement {
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:UpdateSecretVersionStage"
    ]

    resources = [
      "arn:aws:secretsmanager:${local.aws_region_name}:${local.aws_account_id}:secret:*/ct-access-token-*",
    ]

    condition {
      test     = "ArnEquals"
      variable = "secretsmanager:resource/AllowRotationLambdaArn"
      values   = [aws_lambda_function.commercetools_token_refresher.arn]
    }
  }

  # Secrets manager containing commercetools client key
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
    ]

    resources = [
      "arn:aws:secretsmanager:${local.aws_region_name}:${local.aws_account_id}:secret:*/commercetools-client-*",
    ]
  }

  # Logging
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = flatten([for _, v in ["%v:*", "%v:*:*"] : format(v, aws_cloudwatch_log_group.lambda_log_group.arn)])
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_policy.json

}

