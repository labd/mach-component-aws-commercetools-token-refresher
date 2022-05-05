resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = local.lambda_name
  retention_in_days = "30"
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${aws_lambda_function.commercetools_token_refresher.function_name}_errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Average call duration of Lambda exceeds threshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.commercetools_token_refresher.function_name
  }
}
