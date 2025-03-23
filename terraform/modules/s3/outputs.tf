output "bucket_name" {
  description = "Nome do bucket S3 criado"
  value       = aws_s3_bucket.bovespa_data.id
}

output "bucket_arn" {
  description = "ARN do bucket S3"
  value       = aws_s3_bucket.bovespa_data.arn
} 