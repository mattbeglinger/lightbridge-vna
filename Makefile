# ==============================================================================
# LIGHTBRIDGE VNA - SINGLE CLOUD MVP MAKEFILE
# ==============================================================================

TF_DIR := infrastructure
CHART_DIR := charts/lightbridge
CLUSTER_NAME := lightbridge
REGION := us-east-1

.PHONY: help init infra-deploy infra-security infra-camel infra-cnpg infra-all \
        charts apps-deploy get-url clean chaos-test

help:
	@echo "Lightbridge VNA Automation (AWS MVP)"
	@echo "--------------------------------"
	@echo "1. Infrastructure:"
	@echo "   make infra-deploy    - Provision AWS EKS Cluster"
	@echo "   make infra-security  - Install Cert-Manager (TLS)"
	@echo "   make infra-camel     - Install Camel K Operator (Integration)"
	@echo "   make infra-cnpg      - Install CloudNativePG Operator (Database)"
	@echo "   make infra-all       - Provision Infrastructure & Install ALL Operators"
	@echo ""
	@echo "2. Applications:"
	@echo "   make charts          - Download Helm dependencies"
	@echo "   make apps-deploy     - Deploy VNA Stack (MinIO, Orthanc, Keycloak, OHIF)"
	@echo "   make get-url         - Get the Public Load Balancer URL"
	@echo ""
	@echo "3. Validation:"
	@echo "   make chaos-test      - Simulate a Pod Crash (High Availability Test)"
	@echo ""
	@echo "4. Cleanup:"
	@echo "   make clean           - Destroy Everything"

# ==============================================================================
# Infrastructure (Terraform)
# ==============================================================================

init:
	cd $(TF_DIR) && terraform init

infra-deploy: init
	@echo "Provisioning AWS Infrastructure..."
	cd $(TF_DIR) && terraform apply -auto-approve

# ==============================================================================
# System Operators
# ==============================================================================

infra-security:
	@echo "Installing Cert-Manager..."
	aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)
	helm repo add jetstack https://charts.jetstack.io
	helm repo update
	helm upgrade --install cert-manager jetstack/cert-manager \
		--namespace cert-manager --create-namespace \
		--version v1.13.3 \
		--set installCRDs=true

infra-camel:
	@echo "Installing Camel K Operator..."
	helm repo add camel-k https://apache.github.io/camel-k/charts/
	helm repo update
	helm upgrade --install camel-k camel-k/camel-k \
		--namespace camel-k --create-namespace \
		--version 2.2.0 \
		--set platform.build.registry.address=docker.io \
		--set platform.build.registry.insecure=true

infra-cnpg:
	@echo "Installing CloudNativePG Operator..."
	helm repo add cnpg https://cloudnative-pg.io/charts
	helm repo update
	helm upgrade --install cnpg cnpg/cloudnative-pg \
		--namespace cnpg-system --create-namespace \
		--version 0.19.0

# The "One Command" Setup
infra-all: infra-deploy infra-security infra-camel infra-cnpg

# ==============================================================================
# Applications (Helm)
# ==============================================================================

charts:
	@echo "Adding required Helm repositories..."
	helm repo add minio https://charts.min.io/
	helm repo add bitnami https://charts.bitnami.com/bitnami
	helm repo update
	@echo "Building Chart dependencies..."
	helm dependency build $(CHART_DIR)

apps-deploy: charts
	@echo "Deploying Lightbridge VNA Stack..."
	aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)
	# We use values.yaml now instead of values-primary.yaml
	helm upgrade --install lightbridge ./$(CHART_DIR) \
		-f $(CHART_DIR)/values.yaml \
		--create-namespace --namespace lightbridge
	@echo ""
	@echo "⚠️  NOTE: It takes 5-10 minutes for the AWS Load Balancer to provision."
	@echo "   Run 'make get-url' periodically to check status."

get-url:
	@echo "=========================================================="
	@echo "VNA Public Address:"
	@kubectl get svc lightbridge-minio-console -n lightbridge --output jsonpath='{.status.loadBalancer.ingress[0].hostname}'
	@echo ""
	@echo "=========================================================="

# ==============================================================================
# High Availability Verification (Chaos Test)
# ==============================================================================

chaos-test:
	@echo "🔥 EXECUTION: CHAOS TEST (Killing Orthanc)"
	@echo "Currently running pods:"
	@kubectl get pods -n lightbridge -l app.kubernetes.io/name=lightbridge-orthanc
	@echo ""
	@echo "🔫 Deleting Orthanc Pod to simulate crash..."
	@kubectl delete pod -n lightbridge -l app.kubernetes.io/name=lightbridge-orthanc --wait=false
	@echo "✅ Pod deleted."
	@echo ""
	@echo "👀 Watching Kubernetes Auto-Healing (Ctrl+C to stop)..."
	@kubectl get pods -n lightbridge -l app.kubernetes.io/name=lightbridge-orthanc -w

# ==============================================================================
# Cleanup
# ==============================================================================

clean:
	@echo "🧨 DESTROYING INFRASTRUCTURE..."
	cd $(TF_DIR) && terraform destroy -auto-approve