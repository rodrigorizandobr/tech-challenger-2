variable "environment" {
  description = "Ambiente (dev, prod, etc)"
  type        = string
}

variable "bucket_name" {
  description = "Nome do bucket S3"
  type        = string
}

variable "bucket_arn" {
  description = "ARN do bucket S3"
  type        = string
}

variable "glue_workflow_name" {
  description = "Nome do workflow Glue"
  type        = string
}

variable "glue_workflow_arn" {
  description = "ARN do workflow Glue"
  type        = string
} 