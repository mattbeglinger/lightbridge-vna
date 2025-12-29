# ==============================================================================
# LIGHTBRIDGE VNA - MASTER MAKEFILE
# ==============================================================================

# Variables
TF_DIR := infrastructure
CHART_DIR := charts/lightbridge

.PHONY: help init infra-aws infra-azure clean charts apps-aws get-aws-url apps-azure apps

# Default target: Print help
help:
	@echo "Lightbridge VNA Management"
	@echo "--------------------------------"
	@echo "Infrastructure:"
	@echo "  make init         - Initialize Terraform"
	@echo "  make infra-aws    - Deploy AWS Infrastructure (Primary)"
	@echo "  make infra-azure  - Deploy Azure Infrastructure (Secondary)"
	@echo "  make clean        - Destroy ALL Infrastructure"
	@echo ""
	@echo "Software:"
	@echo "  make charts       - Download Helm dependencies (MinIO/Postgres)"
	@echo "  make apps-aws     - Deploy App Stack to AWS (Primary)"
	@echo "  make get-aws-url  - Get the AWS Load Balancer URL for Replication"
	@echo "  make apps-azure   - Deploy App Stack to Azure (Secondary)"
	@echo "  make apps         - Deploy everything (Requires manual config update in middle)"

# ==============================================================================
# Infrastructure (Terraform)
# ==============================================================================

init:
	cd $(TF_DIR) && terraform init

# Deploy only the AWS module (Primary)
infra-aws: init
	cd $(TF_DIR) && terraform apply -target=module.primary_site_aws

# Deploy only the Azure module (Secondary)
infra-azure: init
	cd $(TF_DIR) && terraform apply -target=module.secondary_site_azure

# Destroy everything (Careful!)
clean:
	cd $(TF_DIR) && terraform destroy -auto-approve

# ==============================================================================
# Software Layer (Helm)
# ==============================================================================

# 1. Download dependencies (MinIO, Postgres) locally into the charts folder
charts:
	helm dependency build $(CHART_DIR)

# 2. Deploy to AWS (Primary Site)
# Switches context to AWS, then installs the Primary configuration
apps-aws: charts
	@echo "Switching context to AWS..."
	aws eks update-kubeconfig --region us-east-1 --name lightbridge-east-cluster
	@echo "Deploying Primary Stack..."
	helm upgrade --install lightbridge ./$(CHART_DIR) \
		-f $(CHART_DIR)/values-primary.yaml \
		--create-namespace --namespace lightbridge

# 3. Helper: Get the AWS Load Balancer URL
# Run this AFTER apps-aws to get the address you need for Azure config
get-aws-url:
	@echo "Fetching AWS MinIO Load Balancer URL..."
	@kubectl get svc lightbridge-minio-console -n lightbridge --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'
	@echo ""
	@echo "^^ Copy this URL into charts/lightbridge/values-secondary.yaml ^^"

# 4. Deploy to Azure (Secondary Site)
# Switches context to Azure, then installs the Secondary configuration
apps-azure: charts
	@echo "Switching context to Azure..."
	az aks get-credentials --resource-group lightbridge-rg-west --name lightbridge-west-cluster --overwrite-existing
	@echo "Deploying Secondary Stack..."
	helm upgrade --install lightbridge ./$(CHART_DIR) \
		-f $(CHART_DIR)/values-secondary.yaml \
		--create-namespace --namespace lightbridge

# Master command (Optional usage)
apps: apps-aws apps-azure
