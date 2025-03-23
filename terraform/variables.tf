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

variable "bucket_name" {
  description = "Nome do bucket S3 para armazenar os dados"
  type        = string
  default     = "bovespa-pipeline-data-dev"
}

# Variáveis locais para uso interno
locals {
  project_name = "bovespa-pipeline"
  owner       = "fiap-pos-tech"
  
  # Tags comuns para todos os recursos
  common_tags = {
    Project     = local.project_name
    Owner       = local.owner
    Environment = var.environment
    ManagedBy   = "terraform"
  }
} 