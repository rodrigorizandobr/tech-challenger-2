output "crawler_function_arn" {
  description = "ARN da função Lambda do crawler"
  value       = aws_lambda_function.crawler.arn
}

output "crawler_function_name" {
  description = "Nome da função Lambda do crawler"
  value       = aws_lambda_function.crawler.function_name
} 