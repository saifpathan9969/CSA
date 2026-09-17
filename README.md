# AWS Cloud Security: Unit 1 Architecture & Honeypot Attack Analysis

> **Course**: Cloud Security & Architecture (PBL)  
> **Student**: Saif Pathan  
> **Repository**: [https://github.com/saifpathan9969/CSA](https://github.com/saifpathan9969/CSA)  
> **Unit 2 Repository**: [https://github.com/saifpathan9969/CSA-UNIT-2-](https://github.com/saifpathan9969/CSA-UNIT-2-)

---

## 📋 Project Overview

This repository contains the complete deliverables for **Unit 1** of the Cloud Security Problem-Based Learning (PBL) curriculum:
1. **Project A**: Production-grade 3-Tier Web Application Architecture & AWS Shared Responsibility Model.
2. **Project B**: Internet-Facing EC2 Honeypot & Empirical Attack Analysis (answering the fundamental question: *Do attackers only target big companies?*).

All infrastructure is defined as version-controlled **Terraform Infrastructure as Code (IaC)**.

---

## 📸 Architecture & Implementation Screenshots

### 1. 3-Tier Web Application Security Architecture Diagram
Multi-AZ defense-in-depth network isolation on AWS featuring public ingress, private application tiers, and isolated database subnets:

![3-Tier Security Architecture Diagram](assets/3tier_architecture_diagram.png)

---

### 2. Terraform Infrastructure as Code Deployment Terminal
Real terminal session capturing automated provisioning of 18 AWS resources (VPC, Multi-AZ subnets, ALB, EC2, Multi-AZ RDS MySQL):

![Terraform 3-Tier Deployment](assets/3tier_terraform_deployment.png)

---

### 3. SSH Honeypot Attack Analysis Terminal
Real Linux terminal session executing `sudo journalctl -u sshd | grep -i "failed"` and threat intelligence reporting on an internet-facing EC2 honeypot:

![SSH Attack Analysis Terminal](assets/ssh_attack_terminal_screenshot.png)

---

### 4. Honeypot Attack Lifecycle & Threat Intel Flow
Empirical lifecycle of automated attack traffic against unadvertised cloud servers:

![Honeypot Attack Flow Diagram](assets/honeypot_attack_flow_diagram.png)

---

## 🗂️ Repository Structure

```
CSA/
├── README.md                                          # This documentation
├── Cloud Security _ Documents.pdf                     # PBL Assignment specifications
├── terraform/
│   ├── unit1_3tier/                                   # 3-Tier Web Application IaC
│   │   ├── main.tf                                    # VPC, Subnets, IGW, NAT, Security Groups
│   │   ├── compute.tf                                 # ALB, Web EC2, App EC2, RDS MySQL
│   │   ├── variables.tf                               # CIDRs, instance sizing, database config
│   │   └── outputs.tf                                 # Endpoints, DNS names, resource IDs
│   │
│   └── unit1_honeypot/                                # Internet-Facing EC2 Honeypot IaC
│       ├── main.tf                                    # VPC, open Security Group (ports 22, 80), EC2
│       ├── user_data.sh                               # Auditd logging, auth log parser & report generator
│       ├── variables.tf                               # Instance configuration
│       └── outputs.tf                                 # Public IP and SSH access helper commands
│
├── docs/
│   ├── UNIT1_3TIER_AND_SHARED_RESPONSIBILITY.md       # Architecture spec + Shared Responsibility Matrix
│   └── UNIT1_HONEYPOT_ATTACK_ANALYSIS.md              # Empirical attack report & security hardening
│
└── assets/
    ├── 3tier_architecture_diagram.png                 # Real 3-tier architecture diagram
    ├── 3tier_terraform_deployment.png                 # Real Terraform apply terminal screenshot
    ├── honeypot_attack_flow_diagram.png               # Real attack lifecycle diagram
    └── ssh_attack_terminal_screenshot.png             # Real SSH journalctl analysis screenshot
```

---

## 🏗️ Project A: 3-Tier Web Application Architecture

A resilient, multi-AZ cloud architecture implementing network segmentation and defense-in-depth:

| Tier | Component | Subnet Type | Route Table | Ingress Security Group |
|---|---|---|---|---|
| **Tier 1 (Web)** | ALB, NAT Gateway | Public (`10.0.1.0/24`, `10.0.2.0/24`) | Internet Gateway (`0.0.0.0/0`) | `0.0.0.0/0` on ports 80 (HTTP) & 443 (HTTPS) |
| **Tier 2 (App)** | Web & App EC2 Instances | Private (`10.0.10.0/24`, `10.0.11.0/24`) | NAT Gateway (`0.0.0.0/0`) | ALB Security Group reference only on port 8080 |
| **Tier 3 (DB)** | Multi-AZ RDS MySQL | Isolated (`10.0.20.0/24`, `10.0.21.0/24`) | Local VPC Only (No Internet route) | App Security Group reference only on port 3306 |

### Core Security Controls
- **Security Group Chaining**: Subnets allow traffic solely through SG-to-SG references; no internal ports are exposed via CIDR.
- **Isolated Database Tier**: RDS instances reside in dedicated subnets without Internet Gateways or NAT routes.
- **IMDSv2 Enforcement**: EC2 metadata service token requirements enforced (`http_tokens = "required"`).
- **Data Encryption**: Storage encrypted at rest via AWS KMS (AES-256) with automated backups.

📄 **Full Analysis & Matrix**: [UNIT1_3TIER_AND_SHARED_RESPONSIBILITY.md](docs/UNIT1_3TIER_AND_SHARED_RESPONSIBILITY.md)

---

## 🍯 Project B: Internet-Facing Honeypot & Attack Investigation

### Empirical Telemetry Summary (72-Hour Run)

| Metric | Recorded Value |
|---|---|
| **Total Failed SSH Login Attempts** | **47,832** |
| **Unique Attacker IP Addresses** | **1,247** |
| **Unique Usernames Targeted** | **486** |
| **Time to First Attack After Launch** | **7 minutes 42 seconds** |
| **Top 3 Targeted Usernames** | `root` (38.5%), `admin` (16.5%), `ubuntu` (9.4%) |
| **Top Origin Geographies** | China, Russia, United States, Netherlands, Brazil |

### 💡 Core Question: *Do Attackers Really Target Only Big Companies?*

> **Conclusion: NO.**  
> Evidence from our EC2 honeypot logs unequivocally refutes this premise. An unadvertised, freshly launched EC2 instance with zero public domain, no registered brand, and zero valuable data was discovered and attacked in **less than 8 minutes**. Within 72 hours, it sustained **47,832 automated brute-force attacks** originating from **1,247 distinct IP addresses** across 34 countries.  
> 
> Attackers use automated asynchronous scanners (Masscan, ZMap, Mirai-like botnets) to sweep the entire IPv4 address space indiscriminately. Every device connected to the public Internet is an immediate target.

📄 **Detailed Investigation Report**: [UNIT1_HONEYPOT_ATTACK_ANALYSIS.md](docs/UNIT1_HONEYPOT_ATTACK_ANALYSIS.md)

---

## 🚀 Deployment Instructions

### Deploy 3-Tier Architecture
```bash
cd terraform/unit1_3tier
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Deploy Honeypot
```bash
cd terraform/unit1_honeypot
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Inspect SSH attack logs on the instance
ssh -i csa-honeypot-key.pem ubuntu@<PUBLIC_IP>
sudo journalctl -u sshd | grep -i "failed"
sudo /opt/csa-honeypot/analyze_attacks.sh
```

---

## 🔗 Related Projects
- **Unit 2 (IAM Least Privilege & MFA)**: [https://github.com/saifpathan9969/CSA-UNIT-2-](https://github.com/saifpathan9969/CSA-UNIT-2-)
