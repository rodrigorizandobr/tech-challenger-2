resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Comentando o bucket de resultados do Athena para usar o bucket principal
# # Bucket para resultados do Athena
# # Este bucket é necessário para armazenar os resultados das consultas Athena
# # Ele não é usado para armazenar dados da aplicação, apenas resultados intermediários
# resource "aws_s3_bucket" "athena_results" {
#   bucket = "athena-results-bovespa-${var.environment}-${random_id.bucket_suffix.hex}"
#   
#   tags = {
#     Name        = "Bucket para resultados do Athena"
#     Environment = var.environment
#     Project     = "bovespa-pipeline"
#   }
# }

# Workgroup do Athena
resource "aws_athena_workgroup" "bovespa" {
  name = "bovespa-workgroup-${var.environment}"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${var.bucket_name}/athena_results/"
    }
  }

  lifecycle {
    ignore_changes = [
      name
    ]
  }
}

# Consultas salvas no Athena
resource "aws_athena_named_query" "schema" {
  name        = "bovespa-schema-${var.environment}"
  workgroup   = aws_athena_workgroup.bovespa.name
  database    = var.glue_database_name
  description = "Visualizar schema da tabela"
  query      = "DESCRIBE ${var.glue_database_name}.bovespa_refined;"
}

resource "aws_athena_named_query" "volume_diario" {
  name        = "bovespa-volume-diario-${var.environment}"
  workgroup   = aws_athena_workgroup.bovespa.name
  database    = var.glue_database_name
  description = "Volume total negociado por dia"
  query      = <<EOF
SELECT data_pregao, 
       SUM(volume_total) as volume_total_dia
FROM ${var.glue_database_name}.bovespa_refined
GROUP BY data_pregao
ORDER BY data_pregao DESC
LIMIT 10;
EOF
}

resource "aws_athena_named_query" "media_preco" {
  name        = "bovespa-media-preco-${var.environment}"
  workgroup   = aws_athena_workgroup.bovespa.name
  database    = var.glue_database_name
  description = "Média de preço por ticker"
  query      = <<EOF
SELECT ticker, 
       AVG(preco_medio_abertura) as preco_medio
FROM ${var.glue_database_name}.bovespa_refined
GROUP BY ticker
ORDER BY preco_medio DESC
LIMIT 10;
EOF
}

resource "aws_athena_named_query" "negociacoes" {
  name        = "bovespa-negociacoes-${var.environment}"
  workgroup   = aws_athena_workgroup.bovespa.name
  database    = var.glue_database_name
  description = "Número de negociações por ticker e dia"
  query      = <<EOF
SELECT ticker, 
       data_pregao, 
       numero_negociacoes
FROM ${var.glue_database_name}.bovespa_refined
ORDER BY numero_negociacoes DESC
LIMIT 10;
EOF
}

resource "aws_athena_database" "bovespa_db" {
  name   = "bovespa_db_${var.environment}"
  bucket = var.bucket_name
  force_destroy = false
  
  lifecycle {
    ignore_changes = [
      name,
      bucket
    ]
    prevent_destroy = true
  }
}

# Recurso de consulta Athena para criar a tabela
resource "null_resource" "create_table" {
  depends_on = [aws_athena_database.bovespa_db, aws_athena_workgroup.bovespa]

  # Usar triggers para garantir execução apenas quando necessário
  triggers = {
    bucket_name = var.bucket_name
    schema_hash = sha256(<<EOF
    ticker STRING,
    data_pregao STRING,
    preco_abertura DOUBLE,
    preco_maximo DOUBLE,
    preco_minimo DOUBLE,
    preco_fechamento DOUBLE,
    preco_medio_abertura DOUBLE,
    volume_total DOUBLE,
    numero_negociacoes BIGINT
    EOF
    )
  }

  provisioner "local-exec" {
    command = <<EOF
aws athena start-query-execution \
  --query-string "CREATE EXTERNAL TABLE IF NOT EXISTS ${aws_athena_database.bovespa_db.name}.bovespa_composicao_ibov (
    ticker STRING,
    data_pregao STRING,
    preco_abertura DOUBLE,
    preco_maximo DOUBLE,
    preco_minimo DOUBLE,
    preco_fechamento DOUBLE,
    preco_medio_abertura DOUBLE,
    volume_total DOUBLE,
    numero_negociacoes BIGINT
  )
  PARTITIONED BY (year STRING, month STRING, day STRING)
  STORED AS PARQUET
  LOCATION 's3://${var.bucket_name}/refined/'
  TBLPROPERTIES ('parquet.compression'='SNAPPY');" \
  --work-group "${aws_athena_workgroup.bovespa.name}" \
  --query-execution-context Database=${aws_athena_database.bovespa_db.name}
EOF
  }
}

# Recurso para reparar as partições
resource "null_resource" "repair_partitions" {
  depends_on = [null_resource.create_table]

  # Usar triggers para garantir execução apenas quando necessário
  triggers = {
    create_table_triggers = join(",", [for k, v in null_resource.create_table.triggers : "${k}=${v}"])
    refined_path = "s3://${var.bucket_name}/refined/"
  }

  provisioner "local-exec" {
    command = <<EOF
aws athena start-query-execution \
  --query-string "MSCK REPAIR TABLE ${aws_athena_database.bovespa_db.name}.bovespa_composicao_ibov;" \
  --work-group "${aws_athena_workgroup.bovespa.name}" \
  --query-execution-context Database=${aws_athena_database.bovespa_db.name}
EOF
  }
}