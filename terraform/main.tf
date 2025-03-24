# Configuração do provider AWS
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Módulos
module "s3" {
  source = "./modules/s3"
  environment = var.environment
  bucket_name = local.bucket_name
}

module "lambda" {
  source = "./modules/lambda"
  environment = var.environment
  bucket_name = module.s3.bucket_name
  bucket_arn = module.s3.bucket_arn
}

module "eventbridge" {
  source = "./modules/eventbridge"
  environment = var.environment
  lambda_function_arn = module.lambda.crawler_function_arn
}

# Outputs para informar valores importantes após aplicação
output "bucket_name" {
  description = "Nome do bucket S3 criado para o pipeline"
  value = module.s3.bucket_name
}

output "lambda_function_name" {
  description = "Nome da função Lambda do crawler"
  value = module.lambda.crawler_function_name
}
