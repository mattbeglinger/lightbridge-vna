terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ==============================================================================
# The Lightbridge VNA Infrastructure (AWS Only)
# ==============================================================================
module "lightbridge_stack" {
  source = "./modules/aws-k8s"

  environment_name = var.cluster_name_prefix
  region           = var.aws_region
  
  # Standard Node Count for High Availability (across 3 Availability Zones)
  node_count = 3
  
  # Security: Enable KMS for Encryption at Rest (EBS Volumes)
  enable_kms = true
  kms_alias  = "alias/${var.cluster_name_prefix}-key"
  allow_traffic_from_cidrs = ["0.0.0.0/0"]
}

# Output the Cluster Name so the Makefile can find it
output "cluster_name" {
  value = module.lightbridge_stack.cluster_name
}

output "region" {
  value = var.aws_region
}