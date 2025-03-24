resource "aws_s3_bucket" "bovespa_data" {
  bucket = var.bucket_name
  
  # Impedir que o bucket seja excluído acidentalmente
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.bovespa_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Criar estrutura de pastas no bucket
resource "aws_s3_object" "raw_folder" {
  bucket = aws_s3_bucket.bovespa_data.id
  key    = "raw/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "refined_folder" {
  bucket = aws_s3_bucket.bovespa_data.id
  key    = "refined/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "scripts_folder" {
  bucket = aws_s3_bucket.bovespa_data.id
  key    = "scripts/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "athena_results_folder" {
  bucket = aws_s3_bucket.bovespa_data.id
  key    = "athena_results/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "spark_logs_folder" {
  bucket = aws_s3_bucket.bovespa_data.id
  key    = "spark-logs/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "temp_folder" {
  bucket = aws_s3_bucket.bovespa_data.id
  key    = "temp/"
  content_type = "application/x-directory"
}

# Adicionar uma pasta para cada ano/mês atual (para facilitar organização)
locals {
  current_year = formatdate("YYYY", timestamp())
  current_month = formatdate("MM", timestamp())
  current_day = formatdate("DD", timestamp())
}

resource "aws_s3_object" "raw_year_folder" {
  bucket = aws_s3_bucket.bovespa_data.id
  key    = "raw/${local.current_year}/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "raw_month_folder" {
  bucket = aws_s3_bucket.bovespa_data.id
  key    = "raw/${local.current_year}/${local.current_month}/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "raw_day_folder" {
  bucket = aws_s3_bucket.bovespa_data.id
  key    = "raw/${local.current_year}/${local.current_month}/${local.current_day}/"
  content_type = "application/x-directory"
}

# Política para permitir acesso do Lambda
resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.bovespa_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowLambdaAccess"
        Effect    = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com"]
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.bovespa_data.arn,
          "${aws_s3_bucket.bovespa_data.arn}/*"
        ]
      }
    ]
  })
} 