resource "aws_cloudwatch_event_rule" "crawler_schedule" {
  name                = "b3-crawler-schedule-${var.environment}"
  description         = "Agenda para executar o crawler da B3 a cada minuto"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.crawler_schedule.name
  target_id = "B3CrawlerLambda"
  arn       = var.lambda_function_arn
}

# Permissão para o EventBridge invocar a função Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.crawler_schedule.arn
} 