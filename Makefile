# ==============================================================================
# LIGHTBRIDGE VNA - MASTER MAKEFILE
# ==============================================================================

TF_DIR := infrastructure
CHART_DIR := charts/lightbridge

.PHONY: help init infra-all infra-aws infra-azure infra-security infra-camel infra-cnpg \
        charts apps-aws get-aws-url apps-azure clean \
        disaster-start disaster-failover disaster-verify disaster-restore-aws disaster-heal disaster-failback

help:
	@echo "Lightbridge VNA Automation"
	@echo "--------------------------------"
	@echo "1. Infrastructure (Part 4 & 5):"
	@echo "   make infra-aws       - Deploy AWS Infrastructure (Primary)"
	@echo "   make infra-azure     - Deploy Azure Infrastructure (Secondary)"
	@echo "   make infra-security  - Install Cert-Manager"
	@echo "   make infra-camel     - Install Camel K Operator"
	@echo "   make infra-cnpg      - Install CloudNativePG Operator"
	@echo "   make infra-all       - Deploy ALL Infrastructure & Operators"
	@echo ""
	@echo "2. Applications (Part 5 & 8):"
	@echo "   make charts          - Download Helm dependencies"
	@echo "   make apps-aws        - Deploy VNA Stack to AWS (Primary)"
	@echo "   make get-aws-url     - Get the Replication URL"
	@echo "   make apps-azure      - Deploy VNA Stack to Azure (Secondary)"
	@echo ""
	@echo "3. Fire Drill (Part 7):"
	@echo "   make disaster-start       - Simulate Total AWS Failure"
	@echo "   make disaster-failover    - Promote Azure to Primary (Read/Write)"
	@echo "   make disaster-verify      - Verify Business Continuity on Azure"
	@echo "   make disaster-restore-aws - Bring AWS Infrastructure Back Online"
	@echo "   make disaster-heal        - Rewind DB & Sync Storage (The 'Time Travel' Fix)"
	@echo "   make disaster-failback    - Return AWS to Primary Role"
	@echo ""
	@echo "4. Cleanup:"
	@echo "   make clean           - Destroy Everything"

# ==============================================================================
# Infrastructure (Terraform)
# ==============================================================================

init:
	cd $(TF_DIR) && terraform init

infra-aws: init
	cd $(TF_DIR) && terraform apply -target=module.primary_site_aws -auto-approve

infra-azure: init
	cd $(TF_DIR) && terraform apply -target=module.secondary_site_azure -auto-approve

# ==============================================================================
# System Operators
# ==============================================================================

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

# Integration Layer: Apache Camel K for HL7/FHIR
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

# Database Layer: CloudNativePG for PostgreSQL Replication
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
# Applications (Helm)
# ==============================================================================

charts:
	helm dependency build $(CHART_DIR)

apps-aws: charts
	@echo "Switching to AWS and Deploying Primary Stack..."
	aws eks update-kubeconfig --region us-east-1 --name lightbridge-east-cluster
	helm upgrade --install lightbridge ./$(CHART_DIR) \
		-f $(CHART_DIR)/values-primary.yaml \
		--create-namespace --namespace lightbridge
	@echo "⚠️  NOTE: It may take 5-10 minutes for the AWS Load Balancer to provision."
	@echo "   Run 'kubectl get ingress -n lightbridge' to monitor the Address field."

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

# 2b. Verify Disaster Recovery (Business Continuity)
disaster-verify:
	@echo "🚑  Verifying Business Continuity on Azure..."
	az aks get-credentials --resource-group lightbridge-rg-west --name lightbridge-west-cluster --overwrite-existing
	@# Fetch dynamic Azure IP
	$(eval AZURE_IP := $(shell kubectl get svc lightbridge-integration -n lightbridge -o jsonpath='{.status.loadBalancer.ingress[0].ip}'))
	@echo "Attempting to retrieve Patient Record from Azure (Secondary)..."
	@curl -s --insecure -X GET https://$(AZURE_IP)/fhir/r4/Patient/test-patient-001 \
		| grep "Sterling" && echo "✅ SUCCESS: Patient Data Retrieved!" || echo "❌ FAILURE: Data Not Found."
	@echo ""
	@echo "⚠️  SPLIT-BRAIN WARNING: Any data written to Azure now is NOT in AWS."

# 3. The Resurrection (AWS Returns)
disaster-restore-aws:
	@echo "🏗️  AWS Data Center Power Restored..."
	aws eks update-kubeconfig --region us-east-1 --name lightbridge-east-cluster
	# We bring the pods back up, BUT the DB will likely fail to connect initially due to split brain
	helm upgrade --install lightbridge ./$(CHART_DIR) \
		-f $(CHART_DIR)/values-primary.yaml \
		--create-namespace --namespace lightbridge
	@echo "⚠️  AWS Infrastructure Online. Database is currently diverged (Split Brain)."

# 4. The Healing (Rewind DB + Sync Storage)
disaster-heal:
	@echo "====================================================================="
	@echo "☣️  DANGER: SPLIT-BRAIN RESOLUTION PROTOCOL"
	@echo "====================================================================="
	@echo "This command will:"
	@echo "1. ERASE recent transactions on AWS (pg_rewind) to match Azure."
	@echo "2. OVERWRITE files in AWS MinIO with files from Azure."
	@echo "This is a destructive action for the 'Old Primary' (AWS)."
	@echo ""
	@read -p "Type 'yes' to proceed with healing: " confirm; \
	if [ "$$confirm" != "yes" ]; then \
		echo "❌ Healing Aborted."; exit 1; \
	fi
	@echo "💊 STARTING SYSTEM HEALING PROTOCOL..."
	
	# Step A: Database Healing (CloudNativePG)
	@echo "1. Rewinding AWS Database (pg_rewind)..."
	aws eks update-kubeconfig --region us-east-1 --name lightbridge-east-cluster
	# Fetch Azure IP dynamically
	$(eval AZURE_IP := $(shell az aks get-credentials -n lightbridge-west-cluster -g lightbridge-rg-west > /dev/null && kubectl get svc lightbridge-db-rw -n lightbridge -o jsonpath='{.status.loadBalancer.ingress[0].ip}'))
	@echo "   Syncing DB from Azure Leader: $(AZURE_IP)"
	kubectl cnpg follow lightbridge-db -n lightbridge --server http://$(AZURE_IP)

	# Step B: Storage Healing (MinIO Reverse Sync)
	@echo "2. Resyncing MinIO Storage (Azure -> AWS)..."
	# We execute 'mc mirror' inside the AWS MinIO pod to pull from Azure
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
	# Need AWS IP for the follow command
	aws eks update-kubeconfig --region us-east-1 --name lightbridge-east-cluster
	$(eval AWS_IP := $(shell kubectl get svc lightbridge-db-rw -n lightbridge -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'))
	
	@echo "Configuring Azure to follow AWS Leader: $(AWS_IP)"
	az aks get-credentials --resource-group lightbridge-rg-west --name lightbridge-west-cluster
	kubectl cnpg follow lightbridge-db -n lightbridge --server http://$(AWS_IP)
	@echo "✅ System Normalized. Primary: AWS | Secondary: Azure."
