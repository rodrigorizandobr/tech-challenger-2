module "b3_pipeline" {
  source = "../.."
  
  environment = var.environment
  aws_region = var.aws_region
  bucket_name = var.bucket_name
} 