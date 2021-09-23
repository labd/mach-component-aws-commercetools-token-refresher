resource "aws_cloudwatch_event_rule" "scope_change" {
  name        = "capture-tag-scope-hash-changes"
  description = "Capture each scope hash tag changes on secrets"

  event_pattern = <<EOF
{
  "source": ["aws.tag"],
  "detail-type": ["Tag Change on Resource"],
  "resources": "arn:aws:secretsmanager:${local.aws_region_name}:${local.aws_account_id}:secret:"
  "detail": {
    "changed-tag-keys": [ "scope_hash" ]
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
      "arn:aws:lambda:${local.aws_region_name}:${local.aws_account_id}:function:${aws_lambda_function.commercetools_token_refresher.function_name}"
    ]
  }
}

module "scope_change" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "2.17.0"

  function_name = "${var.site}-${local.component_name}-scope-change"
  description   = "tag s3 files based on there timestamp"
  handler       = "main.handler"
  runtime       = "python3.8"
  memory_size   = 128
  timeout       = 30

  publish        = true
  create_package = true
  source_path    = "${path.module}/src/commercetools_scope_refresher"

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.scope_change.json

  cloudwatch_logs_retention_in_days = 30
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.scope_change.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scope_change.arn
}
