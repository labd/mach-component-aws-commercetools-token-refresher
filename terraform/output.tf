output "component_version" {
  value      = var.component_version
  depends_on = [aws_lambda_function.commercetools_token_refresher]
}
