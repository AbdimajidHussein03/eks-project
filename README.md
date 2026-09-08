# Amazon EKS Platform with Terraform, GitOps & CI/CD

A production-style Kubernetes platform built on **Amazon EKS**, provisioned with **Terraform** and deployed using **Helm and Argo CD**.

The project demonstrates an end-to-end DevOps workflow including infrastructure as code, CI/CD, container security scanning, GitOps, automated DNS/TLS and Kubernetes monitoring.

The application deployed is the **2048 web application**, exposed through a custom domain over HTTPS.

---

## Architecture

<img width="1426" height="711" alt="Screenshot 2026-09-08 230519" src="https://github.com/user-attachments/assets/f7131000-1575-4d2f-939c-83a8a3cd99bc" />


### Application Traffic

```text
User
  ↓
Route 53
  ↓
AWS Load Balancer
  ↓
NGINX Ingress Controller
  ↓
Kubernetes Service
  ↓
2048 Pods
```

**ExternalDNS** automatically manages the Route 53 DNS record, while **cert-manager and Let's Encrypt** provide TLS certificates for HTTPS.

---

## Tech Stack

| Area | Technologies |
|---|---|
| Cloud | AWS |
| Infrastructure as Code | Terraform |
| Containers | Docker, Amazon ECR |
| Kubernetes | Amazon EKS |
| Deployment | Helm, Argo CD |
| CI/CD | GitHub Actions |
| Security | Trivy, Checkov |
| Networking | NGINX Ingress, Route 53, ExternalDNS |
| TLS | cert-manager, Let's Encrypt |
| Monitoring | Prometheus, Grafana |

---

## Infrastructure

Terraform provisions the AWS infrastructure required for the platform, including:

- Multi-AZ VPC networking
- Public and private subnets
- EKS cluster and managed node group
- IAM roles and security groups
- EKS managed add-ons: VPC CNI, CoreDNS and kube-proxy

Long-lived resources are separated from the main EKS environment. **Amazon S3** stores Terraform state and **Amazon ECR** stores application images, allowing the cluster to be destroyed and rebuilt without removing them.

---

## CI/CD & GitOps

Two GitHub Actions pipelines automate the platform.

### Infrastructure Pipeline

The Terraform pipeline authenticates to AWS using **GitHub OIDC** and manages the EKS infrastructure without storing long-lived AWS credentials.

![Terraform Pipeline](docs/images/terraform-pipeline.png)

### Application Pipeline

Application delivery follows this workflow:

```text
Code Push
   ↓
Checkov Scan
   ↓
Docker Build
   ↓
Trivy Scan
   ↓
Push Image to ECR
   ↓
Update Helm Image Tag
   ↓
Argo CD
   ↓
Amazon EKS
```

Images are tagged using the **Git commit SHA**, providing traceability between source code and the version running in Kubernetes.

![Application Pipeline](docs/images/application-pipeline.png)

---

## GitOps with Argo CD

The application uses **Argo CD** rather than having GitHub Actions deploy directly to Kubernetes.

GitHub Actions builds and scans the image, pushes it to ECR and updates the image tag in the Helm values file. Argo CD detects the Git change and synchronises the desired state to EKS.

This keeps **Git as the source of truth** for application deployment.

![Argo CD](docs/images/argocd.png)

---

## Security

Security is integrated into both CI/CD and Kubernetes.

- **Checkov** scans Terraform configuration.
- **Trivy** blocks container images containing HIGH or CRITICAL vulnerabilities.
- Container privilege escalation is disabled.
- A dedicated Kubernetes ServiceAccount is used.
- Automatic ServiceAccount token mounting is disabled.
- NetworkPolicy restricts direct access to the application pods.
- CPU and memory requests/limits are configured.
- Readiness and liveness probes monitor application health.

During development, Trivy detected vulnerabilities in the base container image. Instead of disabling the security gate, the image was patched before deployment.

---

## Monitoring

**Prometheus and Grafana** provide visibility into the EKS cluster and application workloads.

Metrics include pod, node, namespace, CPU and memory information.

### Prometheus

![Prometheus](docs/images/prometheus.png)

### Grafana

![Grafana](docs/images/grafana.png)

---

## Application

The final 2048 application is deployed to EKS and exposed through:

`https://eks.abdimajidcloud.com`

<img width="1886" height="1058" alt="Screenshot 2026-09-06 211617" src="https://github.com/user-attachments/assets/3b9fa61d-2dcd-460a-ad7a-81cf7841de15" />


---

## Repository Structure

```text
eks-project/
├── .github/workflows/     # CI/CD pipelines
├── app/                   # 2048 application + Dockerfile
├── helm/eks-2048/         # Helm chart
├── k8s/                   # ClusterIssuer configuration
├── scripts/               # Cluster bootstrap/destroy scripts
└── terraform/
    ├── bootstrap/         # Long-lived infrastructure
    ├── environments/prod/ # Production environment
    └── modules/           # Reusable Terraform modules
```

---

## Key Engineering Decisions

**GitOps over direct deployment**  
GitHub Actions handles CI while Argo CD owns application deployment to Kubernetes.

**Immutable image tags**  
Images use Git commit SHAs instead of `latest`, making deployments traceable.

**Persistent ECR and Terraform state**  
ECR and S3 are managed separately from the disposable EKS environment.

**Security gates**  
Trivy and Checkov are integrated into CI/CD rather than treating security as a separate manual process.

---

## What I Learned

This project strengthened my understanding of:

- Building AWS infrastructure with Terraform
- Operating applications on Amazon EKS
- Kubernetes networking and workload security
- Helm-based application packaging
- GitOps with Argo CD
- CI/CD with GitHub Actions and AWS OIDC
- Container and infrastructure security scanning
- Automated DNS and TLS
- Kubernetes monitoring with Prometheus and Grafana
- Troubleshooting IAM, networking, DNS, TLS and deployment issues

---

## Author

**Abdimajid Hussein**

DevOps / Platform Engineer | London, UK

[LinkedIn](https://www.linkedin.com/in/abdimajidhussein03/) · [GitHub](https://github.com/AbdimajidHussein03)
