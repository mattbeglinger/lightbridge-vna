# Lightbridge VNA - Control Plane
# Usage: 
#   make infra-aws   (Builds the AWS Datacenter)
#   make infra-azure (Builds the Azure Datacenter)
#   make secret      (Creates necessary passwords in the cluster)
#   make apps        (Installs Orthanc, Postgres, MinIO)
#   make clean       (Destroys everything)

.PHONY: help infra-aws infra-azure secret apps clean

help:
	@echo "Lightbridge VNA Control Commands:"
	@echo "  make infra-aws    - Provision AWS Infrastructure (Terraform)"
	@echo "  make infra-azure  - Provision Azure Infrastructure (Terraform)"
	@echo "  make secret       - Create MinIO/DB secrets (Run before 'make apps')"
	@echo "  make apps         - Deploy Applications to current K8s context"
	@echo "  make clean        - Destroy all infrastructure"

# Infrastructure Commands
infra-aws:
	cd infrastructure && terraform init && terraform apply -target=module.primary_site_aws

infra-azure:
	cd infrastructure && terraform init && terraform apply -target=module.secondary_site_azure

# Secret Management (Run this AFTER infra, BEFORE apps)
secret:
	@echo "🔐 Creating MinIO Secrets..."
	-kubectl create namespace lightbridge
	kubectl create secret generic minio-secrets \
	  --namespace lightbridge \
	  --from-literal=accessKey=admin \
	  --from-literal=secretKey=super-secure-password-CHANGE-ME \
	  --dry-run=client -o yaml | kubectl apply -f -

# Application Deployment
apps:
	@echo "🚀 Installing Controllers..."
	helm repo add cnpg https://cloudnative-pg.io/charts
	helm repo add jetstack https://charts.jetstack.io
	helm repo update
	-helm upgrade --install cnpg cnpg/cloudnative-pg -n cnpg-system --create-namespace
	-helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace --set installCRDs=true
	
	@echo "🏥 Deploying Lightbridge Stack..."
	-kubectl create namespace lightbridge
	kubectl apply -f k8s/storage/minio-values.yaml -n lightbridge
	kubectl apply -f k8s/database/postgres-cluster.yaml -n lightbridge
	kubectl apply -f k8s/app/orthanc-deployment.yaml -n lightbridge
	kubectl apply -f k8s/viewer/ohif-config.yaml -n lightbridge
	kubectl apply -f k8s/viewer/ohif-deployment.yaml -n lightbridge
	kubectl apply -f k8s/network/ingress.yaml -n lightbridge
	@echo "✅ Deployment Complete."

# Safety First
clean:
	@echo "⚠️  WARNING: This will destroy the entire VNA."
	@read -p "Are you sure? [y/N] " ans && [ $${ans:-N} = y ]
	cd infrastructure && terraform destroy
