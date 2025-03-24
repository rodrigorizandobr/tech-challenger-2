# Preparar o pacote Lambda com dependências
resource "null_resource" "lambda_dependencies" {
  triggers = {
    source_code_hash = filesha256("${path.module}/src/crawler.js")
    package_json_hash = filesha256("${path.module}/src/package.json")
  }

  provisioner "local-exec" {
    command = "cd ${path.module} && bash scripts/prepare_lambda.sh"
  }
}

# Calcular o hash do arquivo ZIP
data "archive_file" "lambda_zip" {
  depends_on = [null_resource.lambda_dependencies]
  type        = "zip"
  source_file = "${path.module}/crawler.zip"
  output_path = "${path.module}/crawler_hash.zip"
}

# Upload do arquivo ZIP para o S3
resource "aws_s3_object" "lambda_code" {
  depends_on = [null_resource.lambda_dependencies]
  bucket = var.bucket_name
  key    = "scripts/crawler.zip"
  source = "${path.module}/crawler.zip"
  source_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_lambda_function" "crawler" {
  s3_bucket        = var.bucket_name
  s3_key           = aws_s3_object.lambda_code.key
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  function_name    = "b3-crawler-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "crawler.handler"
  runtime         = "nodejs18.x"
  timeout         = 600  # 10 minutos
  memory_size     = 3008 # Valor máximo permitido

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
      # Adicionar variáveis para melhorar logs e debug
      LOG_LEVEL = "DEBUG"
      NODE_OPTIONS = "--enable-source-maps"
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name = "b3-crawler-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "b3-crawler-policy-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# CloudWatch Log Group para a função Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/b3-crawler-${var.environment}"
  retention_in_days = 14

  lifecycle {
    create_before_destroy = true
    prevent_destroy      = false
    ignore_changes      = [name, retention_in_days]
  }
} 