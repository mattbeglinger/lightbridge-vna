# Lightbridge VNA

![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg) ![Status](https://img.shields.io/badge/Status-Development-orange) ![Terraform](https://img.shields.io/badge/IaC-Terraform-purple) ![Kubernetes](https://img.shields.io/badge/Orchestrator-Kubernetes-326ce5)

**Lightbridge** is a "Build in Public" project to replace legacy, monolithic VNAs with a modern, scalable, and cost-effective architecture.

It is a cloud-native Vendor Neutral Archive (VNA) built on Kubernetes. The project deploys an enterprise-grade DICOM engine (Orthanc) and Object Storage abstraction (MinIO) to AWS in minutes via Terraform.

## The Stack

* **Engine:** Orthanc (DICOMweb/REST)
* **Storage:** MinIO (S3/Blob Abstraction) with KES Encryption
* **Database:** PostgreSQL (CloudNativePG Operator)
* **Integration:** Apache Camel K (HL7v2 / FHIR R4)
* **Viewer:** OHIF (Web-based Radiology Viewer)
* **Infrastructure:** Terraform & Kubernetes (EKS)
* **Security:** Keycloak (OIDC), Cert-Manager (TLS 1.3), Linkerd (mTLS)

## Prerequisites

* [Terraform](https://www.terraform.io/) (v1.0+)
* [Helm](https://helm.sh/) (v3.0+)
* [AWS CLI](https://aws.amazon.com/cli/) (configured with credentials)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Quick Start

1.  **Clone the repository**
    ```bash
    git clone https://github.com/mattbeglinger/lightbridge-vna.git
    cd lightbridge-vna
    ```

2.  **Provision infrastructure and install operators**
    ```bash
    cp infrastructure/terraform.tfvars.example infrastructure/terraform.tfvars
    # Edit terraform.tfvars with your AWS region/profile
    make infra-all
    ```

3.  **Create required secrets**
    ```bash
    kubectl create namespace lightbridge

    kubectl create secret generic lightbridge-minio-creds \
      --from-literal=rootUser=admin \
      --from-literal=rootPassword=<YOUR_STRONG_PASSWORD> \
      -n lightbridge

    kubectl create secret generic lightbridge-keycloak-admin \
      --from-literal=admin-password=<YOUR_STRONG_PASSWORD> \
      -n lightbridge

    kubectl create secret generic lightbridge-s3-creds \
      --from-literal=access-key=admin \
      --from-literal=secret-key=<YOUR_STRONG_PASSWORD> \
      -n lightbridge
    ```

4.  **Deploy the VNA stack**
    ```bash
    make apps-deploy
    ```

5.  **Get the public URL**
    ```bash
    make get-url
    ```

## Project Structure

```
lightbridge-vna/
├── infrastructure/          # Terraform IaC (AWS EKS, VPC, KMS)
│   ├── main.tf
│   ├── variables.tf
│   └── modules/aws-k8s/    # EKS cluster module
├── charts/lightbridge/      # Helm chart (primary deployment method)
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/           # K8s resource definitions
├── k8s/                     # Standalone K8s manifests (reference)
└── Makefile                 # Automation commands
```

## License

**Lightbridge VNA** is released under the **Apache License 2.0**.

You are free to use, modify, and distribute this software for personal or commercial purposes. This license covers the Terraform code, Helm charts, documentation, and custom integration logic found in this repository.

### Third-Party Components & Commercial Use

This project orchestrates several third-party open-source applications. While the automation code here is Apache 2.0, the applications themselves are subject to their own licenses:

| Component | License | Note |
| :--- | :--- | :--- |
| **Orthanc** | GPLv3 | Strong copyleft (General Public License) |
| **MinIO** | AGPLv3 | Network-protective copyleft (Affero General Public License) |
| **PostgreSQL** | PostgreSQL | Permissive License |
| **OHIF Viewer** | MIT | Permissive License |
| **Keycloak** | Apache 2.0 | Permissive License |
| **Apache Camel** | Apache 2.0 | Permissive License |

> **Note for Commercial Users:** If you plan to offer this stack as a commercial SaaS product, please review the **AGPLv3** implications regarding MinIO and the **GPLv3** implications regarding Orthanc. Lightbridge interacts with these services via standard APIs (HTTP/REST/DICOM), which generally maintains separation, but you are responsible for ensuring your deployment complies with their respective terms.

## Disclaimer

*This software is for educational and research purposes only. It is not FDA-cleared or CE-marked for clinical diagnosis or treatment.*
