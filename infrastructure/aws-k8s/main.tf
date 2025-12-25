variable "region" {}
variable "environment_name" {}
variable "node_count" {}
variable "enable_kms" { default = false }
variable "kms_alias" { default = "" }
variable "allow_traffic_from_cidrs" { type = list(string) }

# 1. The Network (VPC)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${var.environment_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
}

# 2. The Control Plane (EKS)
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.0.0"

  cluster_name    = "${var.environment_name}-cluster"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    main = {
      min_size     = 1
      max_size     = var.node_count
      desired_size = var.node_count
      instance_types = ["t3.medium"]
    }
  }
}

# 3. Security (KMS)
resource "aws_kms_key" "main" {
  count       = var.enable_kms ? 1 : 0
  description = "Encryption key for ${var.environment_name}"
}

resource "aws_kms_alias" "main" {
  count         = var.enable_kms ? 1 : 0
  name          = var.kms_alias
  target_key_id = aws_kms_key.main[0].key_id
}

# 4. Networking (Security Group for Replication)
resource "aws_security_group_rule" "replication_ingress" {
  type              = "ingress"
  from_port         = 9000
  to_port           = 9000
  protocol          = "tcp"
  cidr_blocks       = var.allow_traffic_from_cidrs
  security_group_id = module.eks.node_security_group_id
}