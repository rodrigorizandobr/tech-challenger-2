output "glue_job_name" {
  description = "Nome do job Glue"
  value       = aws_glue_job.transform_bovespa.name
}

output "glue_job_arn" {
  description = "ARN do job Glue"
  value       = aws_glue_job.transform_bovespa.arn
}

output "glue_database_name" {
  description = "Nome do banco de dados Glue"
  value       = aws_glue_catalog_database.bovespa_db.name
}

output "glue_workflow_name" {
  description = "Nome do workflow Glue"
  value       = aws_glue_workflow.bovespa.name
}

output "glue_workflow_arn" {
  description = "ARN do workflow Glue"
  value       = aws_glue_workflow.bovespa.arn
} 