variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente (dev, prod, etc)"
  type        = string
  default     = "dev"
}

# Nome fixo do bucket, sem sufixo aleatório
variable "bucket_name_prefix" {
  description = "Prefixo do nome do bucket S3 para armazenar os dados"
  type        = string
  default     = "bovespa-pipeline"
}

# Variáveis locais para uso interno
locals {
  project_name = "bovespa-pipeline"
  owner       = "fiap-pos-tech"
  
  # Nome fixo do bucket
  bucket_name = "${var.bucket_name_prefix}-${var.environment}"
  
  # Tags comuns para todos os recursos
  common_tags = {
    Project     = local.project_name
    Owner       = local.owner
    Environment = var.environment
    ManagedBy   = "terraform"
  }
} 