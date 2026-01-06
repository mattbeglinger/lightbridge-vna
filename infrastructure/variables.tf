variable "aws_region" {
  description = "AWS Region to deploy to (e.g., us-east-1)"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI Profile to use for authentication"
  type        = string
  default     = "default"
}

variable "cluster_name_prefix" {
  description = "Prefix for all resources (e.g., lightbridge)"
  type        = string
  default     = "lightbridge"
}