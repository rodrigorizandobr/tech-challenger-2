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
  bucket_name = var.bucket_name
}

module "glue" {
  source = "./modules/glue"
  environment = var.environment
  bucket_name = module.s3.bucket_name
  bucket_arn = module.s3.bucket_arn
}

module "lambda" {
  source = "./modules/lambda"
  environment = var.environment
  bucket_name = module.s3.bucket_name
  bucket_arn = module.s3.bucket_arn
  glue_workflow_name = module.glue.glue_workflow_name
  glue_workflow_arn = module.glue.glue_workflow_arn
}

module "eventbridge" {
  source = "./modules/eventbridge"
  environment = var.environment
  lambda_function_arn = module.lambda.crawler_function_arn
}

module "athena" {
  source = "./modules/athena"
  environment = var.environment
  glue_database_name = module.glue.glue_database_name
  bucket_name = module.s3.bucket_name
}
