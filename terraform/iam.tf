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
  name               = "commercetools_token_refresher-lambda-role-mach"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}


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

  # KMS manager
  dynamic "statement" {
    for_each = local.kms_secretsmanager == null ? [] : [1]

    content {
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]

      resources = [
        local.kms_secretsmanager,
      ]
    }
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

  dynamic "statement" {
    for_each = local.vpc_id == null ? [] : [1]
    content {
      effect = "Allow"

      actions = [
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
      ]

      # TODO: we could scope back subnet to deployed vpc subnets.
      resources = [
        "*"
        # "arn:aws:ec2:${local.aws_region_name}:${local.aws_account_id}:network-interface/*",
        # "arn:aws:ec2:${local.aws_region_name}:${local.aws_account_id}:security-group/*",
        # "arn:aws:ec2:${local.aws_region_name}:${local.aws_account_id}:subnet/*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "lambda_policy" {
  name   = "lambda-policy-mach"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}
