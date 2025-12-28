variable "aws_profile" {
  description = "The AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "azure_subscription_id" {
  description = "Your Azure Subscription ID"
  type        = string
}

variable "azure_tenant_id" {
  description = "Your Azure Tenant ID"
  type        = string
}

variable "cluster_name_prefix" {
  description = "A prefix to add to all resources"
  type        = string
  default     = "lightbridge"
}