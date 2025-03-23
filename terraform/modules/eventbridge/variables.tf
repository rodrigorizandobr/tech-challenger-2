variable "environment" {
  description = "Ambiente (dev, prod, etc)"
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN da função Lambda do crawler"
  type        = string
} 