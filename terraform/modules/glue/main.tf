# Upload do script Python para o S3
resource "aws_s3_object" "glue_script" {
  bucket = var.bucket_name
  key    = "scripts/transform_bovespa.py"
  source = "${path.module}/scripts/transform_bovespa.py"
  etag   = filemd5("${path.module}/scripts/transform_bovespa.py")

  # Força a atualização do arquivo quando o conteúdo mudar
  force_destroy = true
}

# Banco de dados Glue
resource "aws_glue_catalog_database" "bovespa_db" {
  name = "bovespa_db_${var.environment}"
}

# IAM Role para o Glue
resource "aws_iam_role" "glue_role" {
  name = "glue-bovespa-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Política para o Glue
resource "aws_iam_role_policy" "glue_policy" {
  name = "glue-bovespa-policy-${var.environment}"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.bucket_arn,
          "${var.bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "glue:*",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListAllMyBuckets",
          "s3:GetBucketAcl",
          "ec2:DescribeVpcEndpoints",
          "ec2:DescribeRouteTables",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcAttribute",
          "iam:ListRolePolicies",
          "iam:GetRole",
          "iam:GetRolePolicy",
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:GetLogGroupFields",
          "logs:GetQueryResults"
        ]
        Resource = ["*"]
      }
    ]
  })
}

# CloudWatch Log Group para o Glue
resource "aws_cloudwatch_log_group" "glue_log_group" {
  name              = "/aws-glue/jobs/transform-bovespa-${var.environment}"
  retention_in_days = 14
}

# Job Glue
resource "aws_glue_job" "transform_bovespa" {
  name              = "transform-bovespa-${var.environment}"
  role_arn         = aws_iam_role.glue_role.arn
  glue_version     = "4.0"
  worker_type      = "G.1X"
  number_of_workers = 2

  command {
    script_location = "s3://${var.bucket_name}/scripts/transform_bovespa.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"                     = "python"
    "--continuous-log-logGroup"          = aws_cloudwatch_log_group.glue_log_group.name
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-metrics"                   = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"           = "s3://${var.bucket_name}/spark-logs/"
    "--enable-job-insights"             = "true"
    "--enable-glue-datacatalog"         = "true"
    "--bucket_name"                      = var.bucket_name
  }

  execution_property {
    max_concurrent_runs = 1
  }
}

# Trigger do Glue (será acionado pela Lambda via API)
resource "aws_glue_trigger" "on_demand" {
  name          = "transform-bovespa-trigger-${var.environment}"
  type          = "ON_DEMAND"
  workflow_name = "transform-bovespa-workflow-${var.environment}"

  actions {
    job_name = aws_glue_job.transform_bovespa.name
  }
}

# Workflow do Glue
resource "aws_glue_workflow" "bovespa" {
  name = "transform-bovespa-workflow-${var.environment}"
} 