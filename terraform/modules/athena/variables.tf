terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

variable "environment" {
  description = "Ambiente (dev, prod, etc)"
  type        = string
}

variable "glue_database_name" {
  description = "Nome do banco de dados Glue"
  type        = string
}

variable "bucket_name" {
  description = "Nome do bucket S3"
  type        = string
}

