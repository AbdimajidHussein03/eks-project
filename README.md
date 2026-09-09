# Amazon EKS Platform with Terraform, GitOps & CI/CD

A production-style Kubernetes platform built on **Amazon EKS**, provisioned with **Terraform** and deployed using **Helm and Argo CD**.

This project demonstrates an end-to-end DevOps workflow covering cloud infrastructure, Kubernetes, CI/CD, GitOps, container security, automated DNS/TLS, monitoring and workload security.

The **2048 web application** is containerised with Docker, stored in Amazon ECR and deployed to EKS through a GitOps workflow. The application is exposed securely over HTTPS through a custom domain.

---

## Architecture

<img width="1426" height="711" alt="EKS Architecture Diagram" src="https://github.com/user-attachments/assets/f7131000-1575-4d2f-939c-83a8a3cd99bc" />

The platform is split into three main layers:

- **Infrastructure:** Terraform provisions the AWS networking, IAM and EKS infrastructure.
- **CI/CD:** GitHub Actions scans, builds and publishes application images.
- **GitOps:** Argo CD continuously reconciles the application state stored in Git with the EKS cluster.

### Application Traffic Flow

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

**ExternalDNS** synchronises Kubernetes ingress information with Route 53, while **cert-manager + Let's Encrypt** automate TLS certificate management.

---

## Tech Stack

| Area | Technology | Purpose |
|---|---|---|
| Cloud | AWS | Hosts the infrastructure and Kubernetes platform |
| IaC | Terraform | Provisions AWS infrastructure using reusable modules |
| Kubernetes | Amazon EKS | Runs and orchestrates containerised workloads |
| Containers | Docker | Packages the 2048 application |
| Registry | Amazon ECR | Stores immutable application images |
| Packaging | Helm | Templates and packages Kubernetes resources |
| GitOps | Argo CD | Reconciles Git state with the EKS cluster |
| CI/CD | GitHub Actions | Automates infrastructure and application pipelines |
| Security | Trivy + Checkov | Scans container images and Terraform |
| Ingress | NGINX | Routes external traffic into Kubernetes |
| DNS | Route 53 + ExternalDNS | Automates application DNS |
| TLS | cert-manager + Let's Encrypt | Automates HTTPS certificates |
| Monitoring | Prometheus + Grafana | Collects and visualises cluster metrics |

---

## Repository Structure

```text
eks-project/
├── .github/
│   └── workflows/
│       ├── terraform.yaml          # Infrastructure pipeline
│       └── application.yaml        # Application CI pipeline
│
├── app/
│   ├── Dockerfile                  # 2048 NGINX image
│   └── ...                         # Application assets
│
├── helm/
│   └── eks-2048/
│       ├── Chart.yaml
│       ├── values.yaml             # Image tag, replicas and configuration
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           ├── networkpolicy.yaml
│           └── serviceaccount.yaml
│
├── k8s/
│   ├── clusterissuer.yaml
│   └── clusterissuer-production.yaml
│
├── scripts/
│   ├── bootstrap-cluster.sh        # Installs cluster platform components
│   └── destroy-cluster.sh          # Safe cluster teardown
│
└── terraform/
    ├── bootstrap/                  # Persistent S3 + ECR infrastructure
    ├── environments/
    │   └── prod/                   # Production EKS environment
    └── modules/                    # Reusable Terraform modules
```

---

# Infrastructure

Terraform is responsible for provisioning the AWS infrastructure required by the EKS platform.

### Networking

The environment includes:

- Multi-AZ VPC architecture
- Public and private subnets
- Internet Gateway for public connectivity
- NAT Gateway for private subnet egress
- Route tables
- Security groups
- EKS worker nodes running within private networking

This keeps the Kubernetes worker layer away from direct inbound internet access while still allowing workloads to reach external services when required.

### Amazon EKS

Terraform provisions:

- EKS cluster
- Managed node group
- Cluster and node IAM roles
- Security groups
- OIDC integration
- EKS managed add-ons

The following core EKS add-ons are explicitly managed:

- **VPC CNI** — pod networking
- **CoreDNS** — internal Kubernetes DNS
- **kube-proxy** — Kubernetes service networking

### Persistent Bootstrap Infrastructure

Some resources should survive when the EKS environment is destroyed.

For this reason, the project separates:

```text
Bootstrap Infrastructure
├── S3 → Terraform remote state
└── ECR → Container images

EKS Environment
├── Networking
├── IAM
├── EKS
└── Supporting infrastructure
```

This means the cluster can be destroyed and rebuilt without deleting Terraform state or previously built container images.

---

# Docker

The 2048 application is served using an **NGINX Alpine** container.

Rather than copying the entire repository into the image, the Dockerfile copies only the assets required at runtime.

This avoids unnecessary documentation, configuration and project files being included in the final image.

### Container Security

- **Minimal base image:** NGINX Alpine keeps the runtime lightweight.
- **Restricted COPY:** Only application runtime assets are included.
- **Image patching:** Alpine packages are upgraded during the build.
- **Immutable tagging:** Images are tagged using the Git commit SHA.
- **Trivy scanning:** HIGH and CRITICAL vulnerabilities block the application pipeline.

A multi-stage build was considered, but the application contains static HTML/CSS/JavaScript with no compilation stage. Adding a separate builder image would therefore provide little benefit compared with restricting the runtime files copied into NGINX.

---

# CI/CD

The project contains **two GitHub Actions pipelines**, separating infrastructure management from application delivery.

## Pipeline 1 — Terraform Infrastructure

The infrastructure pipeline manages the AWS/EKS environment using Terraform.

GitHub Actions authenticates to AWS using **OIDC**, avoiding long-lived AWS access keys inside the repository.

```text
GitHub
   ↓
GitHub Actions
   ↓
OIDC
   ↓
AWS IAM Role
   ↓
Terraform
   ↓
AWS / EKS
```

This provides short-lived AWS credentials to the pipeline when required.

### Successful Infrastructure Pipeline

<img width="230" height="52" alt="Terraform Pipeline" src="https://github.com/user-attachments/assets/6e737d3b-f77b-4618-9b16-c9a1e99e6444" />

---

## Pipeline 2 — Application CI

Application changes trigger the second pipeline.

```text
Checkout
   ↓
Checkov
   ↓
AWS OIDC Authentication
   ↓
Docker Build
   ↓
Trivy
   ↓
Push to ECR
   ↓
Update Helm Image Tag
   ↓
Commit Desired State to Git
```

### Security Scanning

**Checkov** scans the Terraform configuration for infrastructure misconfigurations.

**Trivy** scans the built container image and acts as a security gate for HIGH and CRITICAL vulnerabilities.

### Immutable Image Tags

Images are tagged using:

```text
${{ github.sha }}
```

rather than `latest`.

This creates a direct relationship between:

```text
Git Commit
    ↕
Docker Image
    ↕
Helm values.yaml
    ↕
Running Kubernetes Deployment
```

making deployments easier to trace and reason about.

### Successful Application Pipeline

<img width="240" height="52" alt="Application Pipeline" src="https://github.com/user-attachments/assets/4bbd285a-30ac-4600-8baf-22542e270ea8" />

---

# GitOps with Argo CD

The application deployment follows a **GitOps model**.

GitHub Actions does **not** directly run `kubectl` to deploy the 2048 application.

Instead:

1. GitHub Actions builds the application image.
2. Trivy scans the image.
3. The image is pushed to ECR.
4. GitHub Actions updates the image SHA in `helm/eks-2048/values.yaml`.
5. The change is committed back to Git.
6. Argo CD detects the new desired state.
7. Argo CD renders the Helm chart and synchronises EKS.

```text
Git
 ↓
Helm Desired State
 ↓
Argo CD
 ↓
Amazon EKS
```

Argo CD uses:

- **Automated sync**
- **Self-healing**
- **Pruning**

This keeps **Git as the source of truth** for the application.

### Argo CD — Synced & Healthy

<img width="1862" height="1062" alt="Argo CD" src="https://github.com/user-attachments/assets/bb9d2aaa-6d81-4e4d-b24b-e4941379693b" />

---

# Kubernetes

The 2048 application is packaged using a custom **Helm chart**.

The chart manages:

- Deployment
- Service
- Ingress
- ServiceAccount
- NetworkPolicy
- Resource requests and limits
- Readiness probe
- Liveness probe

### Resource Management

Each application pod defines CPU and memory requests and limits.

Requests help Kubernetes schedule workloads appropriately, while limits prevent a single application container from consuming excessive node resources.

### Health Probes

**Readiness probes** determine whether a pod is ready to receive traffic from the Service.

**Liveness probes** allow Kubernetes to restart a container if the application becomes unhealthy.

---

# DNS & HTTPS

DNS and certificate management are automated inside the platform.

## ExternalDNS

ExternalDNS watches Kubernetes resources and synchronises the required records with **Amazon Route 53**.

This means DNS does not need to be manually updated whenever the ingress load balancer changes.

## cert-manager

cert-manager integrates with **Let's Encrypt** to automate TLS certificate creation and renewal.

The final application is therefore available over HTTPS at:

```text
https://eks.abdimajidcloud.com
```

---

# Security

Security is implemented across the infrastructure, CI/CD and Kubernetes layers.

### CI/CD Security

- GitHub OIDC instead of static AWS credentials
- Checkov Terraform scanning
- Trivy container vulnerability scanning
- HIGH/CRITICAL vulnerabilities gate the container pipeline
- Immutable SHA-based container tags

### Kubernetes Security

- Dedicated application ServiceAccount
- Automatic ServiceAccount token mounting disabled
- Container privilege escalation disabled
- NetworkPolicy restricts application ingress
- Resource requests and limits
- Readiness and liveness probes

### Network Isolation

A NetworkPolicy restricts access to the 2048 workload so application traffic is expected through the ingress layer rather than arbitrary direct pod access.

The policy is enforced through the EKS VPC CNI networking layer.

---

# Monitoring & Observability

The cluster uses the **kube-prometheus-stack**, providing Prometheus and Grafana.

## Prometheus

Prometheus collects Kubernetes and workload metrics including:

- Pod health
- Node metrics
- CPU utilisation
- Memory utilisation
- Namespace metrics

<img width="1913" height="867" alt="Prometheus" src="https://github.com/user-attachments/assets/92150f3a-aa1c-4c98-9eca-2aa6e1728530" />

## Grafana

Grafana provides dashboards for visualising the metrics collected by Prometheus.

The dashboards were used to inspect cluster resources and the running 2048 workload.

<img width="1852" height="960" alt="Grafana" src="https://github.com/user-attachments/assets/d9fe1b3f-bdfe-433f-93e4-d95fb0a58f02" />

---

# Application

The completed platform serves the 2048 application at:

```text
https://eks.abdimajidcloud.com
```

<img width="1886" height="1058" alt="2048 Application" src="https://github.com/user-attachments/assets/3b9fa61d-2dcd-460a-ad7a-81cf7841de15" />

---

# Challenges & Troubleshooting

A significant part of the project involved debugging real integration issues across AWS, Kubernetes and CI/CD.

### Trivy Blocking the Pipeline

The application pipeline initially failed because Trivy detected HIGH-severity vulnerabilities in packages within the NGINX Alpine base image.

Instead of disabling the security gate, the image was patched and rebuilt until it passed the required vulnerability threshold.

**Lesson:** security scanning should influence the build rather than simply exist as a checkbox.

### Kubernetes Network Security

Applying an overly restrictive container capability configuration caused NGINX startup operations to fail with permission errors.

The security context was adjusted rather than blindly keeping a configuration that prevented the application from running.

NetworkPolicy enforcement was then tested by attempting direct pod access while confirming that traffic through NGINX continued to work.

**Lesson:** security controls need to be validated against real application behaviour.

### ExternalDNS & Stale DNS

During cluster rebuilds, stale Route 53 records pointed toward an old AWS load balancer.

ExternalDNS ownership and synchronisation were corrected so DNS records could follow the current infrastructure and stale records could be cleaned up during teardown.

**Lesson:** resources created indirectly by Kubernetes need lifecycle handling just as much as Terraform-managed resources.

### Terraform Resource Dependencies

IAM resources required by the EKS cluster and IAM resources depending on the EKS OIDC issuer could not simply be merged into one Terraform module without creating a dependency cycle.

The IAM structure was reorganised while keeping the required dependency boundaries.

**Lesson:** Terraform module organisation should follow dependency relationships, not just resource categories.

---

# Key Engineering Decisions

### GitOps instead of direct CI deployment

GitHub Actions handles **CI**, while Argo CD owns **CD** into Kubernetes.

This prevents the application pipeline from requiring direct Kubernetes deployment access and keeps Git as the desired-state source.

### Immutable deployments

Git commit SHAs are used as image tags rather than `latest`, improving deployment traceability.

### Persistent ECR and Terraform state

S3 and ECR are managed separately from the disposable EKS environment so they survive cluster rebuilds.

### Security gates remain active

When Trivy identified vulnerabilities, the container was fixed rather than weakening the pipeline.

### Explicit EKS add-on management

VPC CNI, CoreDNS and kube-proxy are managed through Terraform so important cluster components are represented in infrastructure as code.

---

# What I Learned

This project strengthened my practical understanding of:

- AWS VPC networking for Kubernetes
- Amazon EKS and managed node groups
- Terraform modules and dependency management
- Terraform remote state
- Kubernetes Deployments, Services, Ingress and Pods
- Kubernetes networking and NetworkPolicy
- Helm chart development
- GitOps with Argo CD
- GitHub Actions CI/CD
- AWS OIDC authentication
- Docker image security
- Trivy and Checkov
- Route 53 and ExternalDNS
- cert-manager and Let's Encrypt
- Prometheus and Grafana
- Debugging IAM, DNS, TLS, networking and CI/CD failures

---

# Project Outcome

The final project demonstrates a complete application delivery path:

```text
Terraform
    ↓
AWS / EKS Infrastructure
    ↓
GitHub Actions
    ↓
Security Scanning
    ↓
Docker / ECR
    ↓
Helm Desired State
    ↓
Argo CD
    ↓
Amazon EKS
    ↓
NGINX / Route 53 / HTTPS
    ↓
2048 Application
    ↓
Prometheus & Grafana
```

The result is a reproducible EKS platform with **Infrastructure as Code, automated CI, GitOps delivery, workload security, DNS/TLS automation and observability**.

---

## Author

**Abdimajid Hussein**

DevOps / Platform Engineer | London, UK
