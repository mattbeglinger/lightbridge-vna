# Lightbridge VNA

![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg) ![Status](https://img.shields.io/badge/Status-Development-orange) ![Terraform](https://img.shields.io/badge/IaC-Terraform-purple) ![Kubernetes](https://img.shields.io/badge/Orchestrator-Kubernetes-326ce5)

**Lightbridge** is a "Build in Public" project to replace legacy, monolithic VNAs with a modern, scalable, and cost-effective architecture.

It is a cloud-native Vendor Neutral Archive (VNA) built on Kubernetes. The project deploys an enterprise-grade DICOM engine (Orthanc) and Object Storage abstraction (MinIO) to AWS in minutes via Terraform.

> 📖 **Read the full architecture series on [Medium](#)** *(Add your link here)*

## ⚡ The Stack

* **Engine:** Orthanc (DICOMweb/REST)
* **Storage:** MinIO (S3/Blob Abstraction) with KES Encryption
* **Database:** PostgreSQL (CloudNativePG Operator)
* **Infrastructure:** Terraform & Kubernetes (EKS/AKS)
* **Security:** Keycloak (OIDC), Cert-Manager (TLS 1.3), Linkerd (mTLS)

## 🛠 Prerequisites

Before deploying Lightbridge, ensure you have the following installed:

* [Terraform](https://www.terraform.io/) (v1.0+)
* [Helm](https://helm.sh/) (v3.0+)
* [AWS CLI](https://aws.amazon.com/cli/) (configured with credentials)
* [kubectl](https://kubernetes.io/docs/tasks/tools/)

## 🚀 Quick Start

1.  **Clone the repository**
    ```bash
    git clone [https://github.com/yourusername/lightbridge.git](https://github.com/yourusername/lightbridge.git)
    cd lightbridge
    ```

2.  **Initialize Infrastructure**
    ```bash
    cd terraform
    terraform init
    terraform apply
    ```

3.  **Deploy the Helm Chart**
    ```bash
    # Update dependency lock files
    helm dependency build charts/lightbridge

    # Install the stack
    helm install lightbridge charts/lightbridge -n medical-imaging --create-namespace
    ```

## 📄 License

You are free to use, modify, and distribute this software for personal or commercial purposes. This license covers the Terraform code, Helm charts, documentation, and custom integration logic found in this repository.

**Lightbridge VNA** is released under the **Apache License 2.0**.

### Third-Party Components & Commercial Use

This project orchestrates several third-party open-source applications. While the automation code here is Apache 2.0, the applications themselves are subject to their own licenses:

| Component | License | Note |
| :--- | :--- | :--- |
| **Orthanc** | GPLv3 | Strong copyleft (General Public License) |
| **MinIO** | AGPLv3 | Network-protective copyleft (Affero General Public License) |
| **OHIF Viewer** | MIT | Permissive License |
| **PostgreSQL** | PostgreSQL | Permissive License |

> **⚠️ Note for Commercial Users:** If you plan to offer this stack as a commercial SaaS product, please review the **AGPLv3** implications regarding MinIO and the **GPLv3** implications regarding Orthanc. Lightbridge interacts with these services via standard APIs (HTTP/REST/DICOM), which generally maintains separation, but you are responsible for ensuring your deployment complies with their respective terms.

## ⚕️ Disclaimer

*This software is for educational and research purposes only. It is not FDA-cleared or CE-marked for clinical diagnosis or treatment.*
