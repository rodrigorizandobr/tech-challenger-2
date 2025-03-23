output "schedule_rule_arn" {
  description = "ARN da regra de agendamento do EventBridge"
  value       = aws_cloudwatch_event_rule.crawler_schedule.arn
}

output "schedule_rule_name" {
  description = "Nome da regra de agendamento do EventBridge"
  value       = aws_cloudwatch_event_rule.crawler_schedule.name
} 