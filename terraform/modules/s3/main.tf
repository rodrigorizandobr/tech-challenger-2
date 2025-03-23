resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "bovespa_data" {
  bucket = var.bucket_name
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

# Política para permitir acesso do Lambda e Glue
resource "aws_s3_bucket_policy" "allow_access" {
  bucket = aws_s3_bucket.bovespa_data.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowLambdaAccess"
        Effect    = "Allow"
        Principal = {
          Service = ["lambda.amazonaws.com", "glue.amazonaws.com"]
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