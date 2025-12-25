terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
}

# ---------------------------------------------------------
# Primary Site (AWS - East Coast)
# ---------------------------------------------------------
module "primary_site_aws" {
  source = "./modules/aws-k8s"

  environment_name = "lightbridge-east"
  region           = "us-east-1"
  node_count       = 3
  
  # Security: Enable KMS for Envelope Encryption
  enable_kms = true
  kms_alias  = "alias/lightbridge-key-east"
  
  # Networking: Allow traffic from Azure for Replication
  allow_traffic_from_cidrs = ["20.0.0.0/16"] 
}

# ---------------------------------------------------------
# Secondary Site (Azure - West Coast)
# ---------------------------------------------------------
module "secondary_site_azure" {
  source = "./modules/azure-k8s"

  environment_name = "lightbridge-west"
  region           = "westus2"
  node_count       = 2 
  
  # Security: Enable Key Vault
  enable_key_vault = true
  key_vault_name   = "lightbridge-kv-west"
  
  # Networking: Allow traffic from AWS for Replication
  allow_traffic_from_cidrs = ["10.0.0.0/16"] 
}