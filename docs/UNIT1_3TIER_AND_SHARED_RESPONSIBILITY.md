# Unit 1 – 3-Tier Web Application Architecture & Shared Responsibility Matrix

## 📋 Overview

This document details the design and security rationale for a **production-grade 3-Tier Web Application Architecture** deployed on Amazon Web Services (AWS) using Terraform Infrastructure as Code (IaC). The architecture implements defense-in-depth principles with strict network segmentation, tier isolation, and the AWS Shared Responsibility Model.

---

## 🏗️ Architecture Design

### Tier 1 – Web / Presentation Tier (Public Subnets)
| Component | Details |
|-----------|---------|
| **Subnet Type** | Public (2x AZs: `us-east-1a`, `us-east-1b`) |
| **CIDR Blocks** | `10.0.1.0/24`, `10.0.2.0/24` |
| **Components** | Application Load Balancer (ALB), EC2 Web Servers |
| **Internet Access** | Direct (Internet Gateway) |
| **Security Group** | Inbound: HTTP/80, HTTPS/443 from `0.0.0.0/0`; Outbound: All |
| **Role** | Serves static content, TLS termination, routes requests to App tier |

### Tier 2 – Application / Logic Tier (Private Subnets)
| Component | Details |
|-----------|---------|
| **Subnet Type** | Private (2x AZs) |
| **CIDR Blocks** | `10.0.10.0/24`, `10.0.11.0/24` |
| **Components** | EC2 Application Servers (Java/Node.js on port 8080) |
| **Internet Access** | Outbound only via NAT Gateway (for patches/API calls) |
| **Security Group** | Inbound: Port 8080 from ALB SG **only**; Outbound: All |
| **Role** | Business logic, API processing, connects to DB tier |

### Tier 3 – Database / Data Tier (Isolated Subnets)
| Component | Details |
|-----------|---------|
| **Subnet Type** | Isolated / Private (2x AZs) |
| **CIDR Blocks** | `10.0.20.0/24`, `10.0.21.0/24` |
| **Components** | RDS MySQL 8.0 (Multi-AZ, Encrypted) |
| **Internet Access** | **NONE** – No route to Internet Gateway or NAT Gateway |
| **Security Group** | Inbound: MySQL/3306 from App SG **only**; Outbound: VPC only |
| **Role** | Persistent data storage, automated backups, encryption at rest |

---

## 🔒 Security Controls Summary

| Control | Implementation |
|---------|---------------|
| **Network Segmentation** | 3 subnet tiers with distinct route tables |
| **Least Privilege Network Access** | Security Groups reference SG IDs (not CIDRs) for tier-to-tier communication |
| **Encryption at Rest** | RDS `storage_encrypted = true` (AES-256) |
| **Encryption in Transit** | ALB HTTPS listener (TLS 1.2+), VPC internal traffic |
| **Instance Metadata Protection** | IMDSv2 enforced (`http_tokens = "required"`) |
| **Database Isolation** | No Internet route, no public accessibility |
| **Multi-AZ Redundancy** | ALB, App EC2, RDS all span 2 Availability Zones |
| **Automated Backups** | RDS backup retention: 7 days, daily window 03:00-04:00 UTC |

---

## 📊 AWS Shared Responsibility Matrix

The AWS Shared Responsibility Model divides security and compliance obligations between AWS (security **of** the cloud) and the Customer (security **in** the cloud). Below is the customized matrix for this specific 3-tier architecture:

### Physical & Infrastructure Security

| Security Domain | AWS Responsibility | Customer Responsibility |
|---|---|---|
| **Data Center Physical Security** | ✅ Facility access controls, surveillance, environmental controls, power redundancy | ❌ Not applicable |
| **Hardware & Server Infrastructure** | ✅ Server procurement, rack management, hardware lifecycle, disposal | ❌ Not applicable |
| **Global Network Backbone** | ✅ Fiber optic backbone, edge locations, redundant connectivity | ❌ Not applicable |
| **Hypervisor & Virtualization** | ✅ Xen/Nitro hypervisor security, guest isolation, side-channel mitigations | ❌ Not applicable |

### Network & Border Security

| Security Domain | AWS Responsibility | Customer Responsibility |
|---|---|---|
| **DDoS Protection (Infrastructure)** | ✅ AWS Shield Standard, network-layer DDoS mitigation | ✅ Enable AWS Shield Advanced for application-layer protection |
| **VPC Network Architecture** | ✅ VPC infrastructure, ENI, underlying SDN fabric | ✅ Design VPC CIDR, subnet segmentation (public/private/isolated) |
| **Internet Gateway / NAT Gateway** | ✅ Managed service availability, throughput, redundancy | ✅ Attach to correct subnets, configure route tables |
| **Security Groups & NACLs** | ✅ Enforcement engine, stateful/stateless packet filtering | ✅ Define rules: least-privilege ingress/egress per tier |
| **Route Tables** | ✅ Routing engine | ✅ Configure: public → IGW, app → NAT, DB → no Internet |
| **TLS/SSL Certificates** | ✅ ACM certificate issuance and renewal | ✅ Attach certificates to ALB, enforce TLS 1.2+ minimum |

### Compute & OS Security

| Security Domain | AWS Responsibility | Customer Responsibility |
|---|---|---|
| **EC2 Host-Level Security** | ✅ Nitro system, host OS hardening, firmware patches | ✅ Guest OS patching (Amazon Linux 2/2023 `yum update -y`) |
| **AMI Security** | ✅ AWS-published AMI base security | ✅ Harden AMI, remove unnecessary packages, CIS benchmarks |
| **SSH Key Management** | ❌ Not applicable (customer-managed) | ✅ Rotate key pairs, disable password auth in production, use SSM |
| **Instance Metadata (IMDS)** | ✅ IMDS service availability | ✅ Enforce IMDSv2 (`http_tokens = "required"`) to prevent SSRF |
| **Auto Scaling & Health Checks** | ✅ ASG infrastructure, launch template engine | ✅ Configure health check endpoints, scaling policies |

### Application & Middleware Security

| Security Domain | AWS Responsibility | Customer Responsibility |
|---|---|---|
| **Application Code Security** | ❌ Not applicable | ✅ Secure coding, OWASP Top 10, input validation, SAST/DAST |
| **Dependency Management** | ❌ Not applicable | ✅ Vulnerability scanning (Snyk, Dependabot), patch libraries |
| **WAF (Web Application Firewall)** | ✅ AWS WAF infrastructure and rule engine | ✅ Define WAF rules (SQL injection, XSS, rate limiting) |
| **ALB Configuration** | ✅ ALB managed service, TLS offloading engine | ✅ Configure listeners, target groups, health checks, access logs |
| **Container/Runtime Security** | ❌ Not applicable | ✅ If using containers: scan images, least-privilege runtime |

### Data Protection

| Security Domain | AWS Responsibility | Customer Responsibility |
|---|---|---|
| **Encryption at Rest (RDS)** | ✅ AES-256 encryption engine via KMS integration | ✅ Enable `storage_encrypted = true`, manage KMS key policy |
| **Encryption in Transit** | ✅ TLS infrastructure in VPC internal network | ✅ Enforce TLS 1.2+ on ALB, use SSL for RDS connections |
| **Backup & Recovery** | ✅ RDS automated backup infrastructure, snapshot storage | ✅ Configure retention period (7 days), backup window, test restores |
| **Data Classification** | ❌ Not applicable | ✅ Classify data (PII, PHI, financial), apply appropriate controls |
| **S3 Bucket Security** | ✅ S3 infrastructure, durability (11 nines) | ✅ Block public access, enable versioning, bucket policies |

### Identity & Access Management

| Security Domain | AWS Responsibility | Customer Responsibility |
|---|---|---|
| **IAM Service** | ✅ IAM infrastructure, authentication engine, MFA service | ✅ Create groups, enforce MFA, least privilege policies |
| **Root Account Security** | ✅ Root account authentication mechanism | ✅ Enable MFA on root, do NOT use root for daily operations |
| **Service-Linked Roles** | ✅ AWS-managed roles for managed services | ✅ Assign EC2 instance profiles (not hardcoded keys) |
| **Credential Rotation** | ❌ Not applicable | ✅ Rotate access keys every 90 days, use STS temporary credentials |

### Logging, Monitoring & Compliance

| Security Domain | AWS Responsibility | Customer Responsibility |
|---|---|---|
| **CloudTrail** | ✅ API logging infrastructure | ✅ Enable multi-region trails, log to encrypted S3, configure alerts |
| **CloudWatch** | ✅ Monitoring infrastructure | ✅ Create dashboards, alarms for security events, log agent config |
| **VPC Flow Logs** | ✅ Flow log capture infrastructure | ✅ Enable flow logs on VPC, analyze for anomalous traffic patterns |
| **Compliance Certifications** | ✅ SOC 1/2/3, ISO 27001, PCI DSS Level 1, HIPAA BAA | ✅ Implement customer-side controls required by compliance frameworks |
| **AWS Config** | ✅ Config rule evaluation engine | ✅ Define config rules, remediation actions, compliance baselines |

---

## 🔄 Data Flow

```
Internet Users
      │
      ▼
┌──────────────────────────────┐
│    Application Load Balancer  │  ← Public Subnets (10.0.1.0/24, 10.0.2.0/24)
│    (HTTP/80, HTTPS/443)       │  ← Security Group: web-alb-sg
└──────────┬───────────────────┘
           │ Port 8080 (SG-to-SG reference)
           ▼
┌──────────────────────────────┐
│    Application Servers (EC2)  │  ← Private Subnets (10.0.10.0/24, 10.0.11.0/24)
│    (Java/Node.js on :8080)    │  ← Security Group: app-sg
│    Outbound: NAT Gateway      │
└──────────┬───────────────────┘
           │ Port 3306 (SG-to-SG reference)
           ▼
┌──────────────────────────────┐
│    RDS MySQL (Multi-AZ)       │  ← Isolated Subnets (10.0.20.0/24, 10.0.21.0/24)
│    Encrypted at Rest (AES-256)│  ← Security Group: db-sg
│    NO Internet Access          │  ← No route to IGW or NAT
└──────────────────────────────┘
```

---

## 📁 Terraform Files

| File | Purpose |
|------|---------|
| `main.tf` | VPC, subnets (public/private/isolated), IGW, NAT GW, route tables, security groups |
| `compute.tf` | ALB, web-tier EC2, app-tier EC2, RDS MySQL Multi-AZ |
| `variables.tf` | Configurable parameters (region, CIDRs, instance types, DB credentials) |
| `outputs.tf` | VPC ID, ALB DNS, instance IPs, RDS endpoint |

---

## 🚀 Deployment

```bash
cd terraform/unit1_3tier
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

> **Note**: Override sensitive variables via environment:
> ```bash
> export TF_VAR_db_password="YourSecurePassword123!"
> export TF_VAR_key_name="your-key-pair-name"
> ```
