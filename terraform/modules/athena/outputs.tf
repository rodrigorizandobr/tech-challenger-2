output "database_name" {
  description = "Nome do banco de dados Athena"
  value       = aws_athena_database.bovespa_db.name
}

output "workgroup_name" {
  description = "Nome do workgroup Athena"
  value       = aws_athena_workgroup.bovespa.name
}

output "results_path" {
  description = "Caminho para resultados do Athena"
  value       = "s3://${var.bucket_name}/athena_results/"
}

output "named_queries" {
  description = "IDs das consultas salvas no Athena"
  value = {
    schema = aws_athena_named_query.schema.id
    volume_diario = aws_athena_named_query.volume_diario.id
    media_preco = aws_athena_named_query.media_preco.id
    negociacoes = aws_athena_named_query.negociacoes.id
  }
}

output "table_name" {
  description = "Nome da tabela criada no Athena"
  value       = "bovespa_composicao_ibov"
}