# lightbridge-vna

Lightbridge is a "Build in Public" project to replace legacy, monolithic VNAs with a modern, scalable, and cost-effective architecture. It's a cloud-native, multi-cloud Vendor Neutral Archive (VNA) built on Kubernetes. The project deploys an enterprise-grade DICOM engine (Orthanc), Object Storage abstraction (MinIO), and Zero-Footprint Viewer (OHIF) to AWS or Azure in minutes via Terraform.

**The Stack:**
* **Engine:** Orthanc (DICOMweb/REST)
* **Storage:** MinIO (S3/Blob Abstraction)
* **Viewer:** OHIF (React-based)
* **Infrastructure:** Terraform & Kubernetes (EKS/AKS)
* **Security:** Keycloak (OIDC) & TLS 1.3

[Read the full architecture series on Medium]([Your-Medium-Link-Here](https://medium.com/@matt-beglinger/rebuilding-the-medical-imaging-stack-from-scratch-6a907fa8580d))

## 📄 License

**Lightbridge VNA** is released under the **[Apache License 2.0](LICENSE)**.

You are free to use, modify, and distribute this software for personal or commercial purposes. This license covers the Terraform code, Helm charts, documentation, and custom integration logic found in this repository.

### Third-Party Components
This project orchestrates several third-party open-source applications. While the automation code here is Apache 2.0, the applications themselves are subject to their own licenses:

* **[Orthanc](https://www.orthanc-server.com/):** GPLv3 (General Public License)
* **[MinIO](https://min.io/):** AGPLv3 (Affero General Public License)
* **[OHIF Viewer](https://ohif.org/):** MIT License
* **[PostgreSQL](https://www.postgresql.org/about/licence/):** PostgreSQL License

> **Note for Commercial Users:** If you plan to offer this stack as a commercial SaaS product, please review the **AGPLv3** implications regarding MinIO and the **GPLv3** implications regarding Orthanc. Lightbridge interacts with these services via standard APIs (HTTP/REST/DICOM), which generally maintains separation, but you are responsible for ensuring your deployment complies with their respective terms.
