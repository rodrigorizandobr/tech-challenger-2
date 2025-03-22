variable "environment" {
  description = "Ambiente de implantação (dev, prod)"
  type        = string
}

variable "aws_region" {
  description = "Região da AWS"
  type        = string
}

variable "bucket_name" {
  description = "Nome do bucket S3"
  type        = string
} 