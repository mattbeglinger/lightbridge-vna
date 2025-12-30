# ==============================================================================
# LIGHTBRIDGE VNA - MASTER MAKEFILE
# ==============================================================================

TF_DIR := infrastructure
CHART_DIR := charts/lightbridge

.PHONY: help init infra-aws infra-azure infra-security infra-camel infra-all charts apps-aws get-aws-url apps-azure clean

help:
	@echo "Lightbridge VNA Automation"
	@echo "--------------------------------"
	@echo "1. Infrastructure:"
	@echo "   make infra-aws       - Deploy AWS (Primary Site)"
	@echo "   make infra-azure     - Deploy Azure (Secondary Site)"
	@echo "   make infra-security  - Install Cert-Manager (Required for TLS)"
	@echo "   make infra-camel     - Install Camel K Operator (Required for HL7)"
	@echo "   make infra-all       - Deploy ALL Infrastructure layers"
	@echo ""
	@echo "2. Applications:"
	@echo "   make charts          - Download Helm dependencies"
	@echo "   make apps-aws        - Deploy VNA Stack to AWS"
	@echo "   make get-aws-url     - Get the Replication URL"
	@echo "   make apps-azure      - Deploy VNA Stack to Azure"
	@echo ""
	@echo "3. Cleanup:"
	@echo "   make clean           - Destroy Everything"

# ==============================================================================
# Infrastructure (Terraform & System Operators)
# ==============================================================================

init:
	cd $(TF_DIR) && terraform init

infra-aws: init
	cd $(TF_DIR) && terraform apply -target=module.primary_site_aws -auto-approve

infra-azure: init
	cd $(TF_DIR) && terraform apply -target=module.secondary_site_azure -auto-approve

# Security Layer: Cert-Manager for TLS Certificates
infra-security:
	@echo "Installing Cert-Manager..."
	helm repo add jetstack https://charts.jetstack.io
	helm repo update
	helm upgrade --install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--version v1.13.3 \
		--set installCRDs=true
	@echo "Cert-Manager Ready."

# Integration Layer: Apache Camel K for HL7/Interoperability
infra-camel:
	@echo "Installing Camel K Operator..."
	helm repo add camel-k https://apache.github.io/camel-k/charts/
	helm repo update
	helm upgrade --install camel-k camel-k/camel-k \
		--namespace camel-k --create-namespace \
		--version 2.2.0 \
		--set platform.build.registry.address=docker.io \
		--set platform.build.registry.insecure=true
	@echo "Camel K Operator Ready."

# Install CloudNativePG (The Database Operator)
infra-cnpg:
	@echo "Installing CloudNativePG Operator..."
	helm repo add cnpg https://cloudnative-pg.io/charts
	helm repo update
	helm upgrade --install cnpg cnpg/cloudnative-pg \
		--namespace cnpg-system --create-namespace \
		--version 0.19.0
	@echo "CloudNativePG Ready."

# Master Command
infra-all: infra-aws infra-azure infra-security infra-camel infra-cnpg

clean:
	cd $(TF_DIR) && terraform destroy -auto-approve

# ==============================================================================
#  Applications
# ==============================================================================

charts:
	helm dependency build $(CHART_DIR)

apps-aws: charts
	@echo "Switching to AWS and Deploying Primary Stack..."
	aws eks update-kubeconfig --region us-east-1 --name lightbridge-east-cluster
	helm upgrade --install lightbridge ./$(CHART_DIR) \
		-f $(CHART_DIR)/values-primary.yaml \
		--create-namespace --namespace lightbridge

get-aws-url:
	@echo "=========================================================="
	@echo "AWS Load Balancer URL (Copy this to values-secondary.yaml):"
	@kubectl get svc lightbridge-minio-console -n lightbridge --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'
	@echo ""
	@echo "=========================================================="

apps-azure: charts
	@echo "Switching to Azure and Deploying Secondary Stack..."
	az aks get-credentials --resource-group lightbridge-rg-west --name lightbridge-west-cluster --overwrite-existing
	helm upgrade --install lightbridge ./$(CHART_DIR) \
		-f $(CHART_DIR)/values-secondary.yaml \
		--create-namespace --namespace lightbridge

# ==============================================================================
# The Doomsday Scenario (Active-Passive Failover)
# ==============================================================================

# 1. The Meteor Strike (AWS Goes Dark)
disaster-start:
	@echo "☄️  METEOR STRIKE CONFIRMED ON US-EAST-1..."
	@echo "Scaling AWS Primary Site to 0..."
	aws eks update-kubeconfig --region us-east-1 --name lightbridge-east-cluster
	kubectl scale deployment --all --replicas=0 -n lightbridge
	@echo "❌ AWS Site is DOWN. Initiating Failover Protocol."

# 2. The Failover (Promote Azure to Primary)
disaster-failover:
	@echo "🚨 PROMOTING AZURE TO PRIMARY (READ/WRITE)..."
	az aks get-credentials --resource-group lightbridge-rg-west --name lightbridge-west-cluster --overwrite-existing
	@echo "Patching Azure DB to exit 'Replica' mode..."
	# This CNPG command promotes the cluster
	kubectl cnpg promote lightbridge-db -n lightbridge
	@echo "✅ Azure is now the Primary Writer. Hospital is Online."

# 3. The Resurrection (AWS Returns)
disaster-restore-aws:
	@echo "🏗️  AWS Data Center Power Restored..."
	aws eks update-kubeconfig --region us-east-1 --name lightbridge-east-cluster
	# We bring the pods back up, BUT the DB will likely fail to connect initially due to split brain
	helm upgrade --install lightbridge ./$(CHART_DIR) \
		-f $(CHART_DIR)/values-primary.yaml \
		--create-namespace --namespace lightbridge
	@echo "⚠️  AWS Infrastructure Online. Database is currently diverged (Split Brain)."

# 4. The Healing (Rewind AWS to match Azure)
disaster-heal:
	@echo "💊 STARTING SYSTEM HEALING PROTOCOL..."

	# Step A: Database Healing (CloudNativePG)
	@echo "1. Rewinding AWS Database (pg_rewind)..."
	aws eks update-kubeconfig --region us-east-1 --name lightbridge-east-cluster
	# Note: For simplicity in the makefile, we'll fetch the Azure IP below
	$(eval AZURE_IP := $(shell az aks get-credentials -n lightbridge-west-cluster -g lightbridge-rg-west > /dev/null && kubectl get svc lightbridge-db-rw -n lightbridge -o jsonpath='{.status.loadBalancer.ingress[0].ip}'))
	@echo "   Syncing DB from Azure Leader: $(AZURE_IP)"
	kubectl cnpg follow lightbridge-db -n lightbridge --server http://$(AZURE_IP)

	# Step B: Storage Healing (MinIO Reverse Sync)
	@echo "2. Resyncing MinIO Storage (Azure -> AWS)..."
	# We execute the 'mc mirror' command inside the AWS MinIO pod
	# This commands says: "Copy any missing files from 'secondary' (Azure) to 'local' (AWS)"
	@kubectl exec -n lightbridge -it svc/lightbridge-minio-console -- /bin/sh -c "\
		mc alias set secondary http://$(AZURE_IP):9000 admin SuperSecretPassword123! && \
		mc mirror --overwrite secondary/orthanc-data local/orthanc-data"
	
	@echo "✅ HEALING COMPLETE. AWS is now a perfect clone of Azure."

# 5. The Failback (Return to Normal)
disaster-failback:
	@echo "🔄 EXECUTING GRACEFUL FAILBACK TO AWS..."
	# Step 1: Promote AWS back to Primary
	kubectl cnpg promote lightbridge-db -n lightbridge
	# Step 2: Demote Azure back to Replica
	az aks get-credentials --resource-group lightbridge-rg-west --name lightbridge-west-cluster
	kubectl cnpg follow lightbridge-db -n lightbridge --server http://REPLACE_WITH_AWS_LB_IP
	@echo "✅ System Normalized. Primary: AWS | Secondary: Azure."
