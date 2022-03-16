data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  component_name     = "commercetools_token_refresher"
  aws_account_id     = data.aws_caller_identity.current.account_id
  aws_region_name    = data.aws_region.current.name
  vpc                = lookup(var.variables, "vpc", {})
  vpc_id             = lookup(local.vpc, "id", null)
  subnet_ids         = lookup(local.vpc, "subnet_ids", null)
  ingres_subnet      = lookup(local.vpc, "ingress_subnet", "0.0.0.0/0")
  kms_keys           = lookup(var.variables, "kms_keys", {})
  kms_cloudwatch     = lookup(local.kms_keys, "cloudwatch", null)
  kms_lambda         = lookup(local.kms_keys, "lambda", null)
  kms_secretsmanager = lookup(local.kms_keys, "secretsmanager", null)
}
