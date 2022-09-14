resource "aws_cloudwatch_event_rule" "scope_change" {
  name        = "${var.site}-${local.component_name}-scope-change"
  description = "Capture each scope hash tag changes on secrets"

  event_pattern = <<EOF
{
  "source": ["aws.tag"],
  "detail-type": ["Tag Change on Resource"],
  "detail": {
    "changed-tag-keys": [ "scope_hash" ],
    "tags": {
      "site": [ "${var.site}" ]
    }
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "scope_change" {
  rule      = aws_cloudwatch_event_rule.scope_change.name
  target_id = aws_cloudwatch_event_rule.scope_change.name
  arn       = module.scope_change.lambda_function_arn
}

data "aws_iam_policy_document" "scope_change" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:RotateSecret"
    ]
    resources = [
      "arn:aws:secretsmanager:${local.aws_region_name}:${local.aws_account_id}:secret:*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      aws_lambda_function.commercetools_token_refresher.arn
    ]
  }

  dynamic "statement" {
    for_each = local.kms_secretsmanager == null ? [] : [1]

    content {
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ]

      resources = [
        local.kms_secretsmanager,
      ]
    }
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

      resources = [
        "*"
      ]
    }
  }
}

module "scope_change" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "2.17.0"

  function_name          = "${var.site}-${local.component_name}-scope-change"
  description            = "Rotate commercetools token when scope hash changes"
  handler                = "main.handle"
  runtime                = "python3.8"
  memory_size            = 128
  timeout                = 30
  vpc_subnet_ids         = local.subnet_ids
  vpc_security_group_ids = local.vpc_id != null ? [aws_security_group.lambda.0.id] : null

  cloudwatch_logs_kms_key_id = local.kms_cloudwatch
  kms_key_arn                = local.kms_lambda

  publish        = true
  create_package = true
  source_path    = "${path.module}/src/commercetools_scope_refresher"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.scope_change.json
  role_name          = "${var.site}-${local.component_name}-scope-change-mach"

  cloudwatch_logs_retention_in_days = 30
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.scope_change.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scope_change.arn
}

resource "aws_security_group" "lambda" {
  count       = local.vpc_id == null ? 0 : 1

  name        = "${var.site}-${local.component_name}-lambda"
  description = "Group for ${local.component_name} lambda"
  vpc_id      = local.vpc_id

  egress {
    description = "Traffic out to VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [local.ingres_subnet]
  }

  tags = var.tags
}
