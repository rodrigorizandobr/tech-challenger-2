terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Módulo S3 primeiro para criar o bucket
module "s3" {
  source = "./modules/s3"
  
  environment = var.environment
  bucket_name = var.bucket_name
}

# Módulo IAM em seguida
module "iam" {
  source = "./modules/iam"
  
  environment = var.environment
  bucket_name = module.s3.bucket_name
}

# Módulo Glue antes da Lambda
module "glue" {
  source = "./modules/glue"
  
  environment = var.environment
  glue_role_arn = module.iam.glue_role_arn
  bucket_name = module.s3.bucket_name
}

# Módulo Lambda por último
module "lambda" {
  source = "./modules/lambda"
  
  environment = var.environment
  lambda_role_arn = module.iam.lambda_role_arn
  bucket_name = module.s3.bucket_name
  glue_job_name = module.glue.glue_job_name
}

# Configurar a notificação do bucket após a criação da Lambda
resource "aws_s3_bucket_notification" "raw_bucket_notification" {
  bucket = module.s3.bucket_name

  lambda_function {
    lambda_function_arn = module.lambda.lambda_function_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = ".parquet"
  }

  depends_on = [
    module.lambda
  ]
} 