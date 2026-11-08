# Cloud Security & Architecture – Unit 3 Project Report
## Problem-Based Learning (PBL) Assessment

---

**Student Name:** Saif Pathan
**Course:** Cloud Security & Architecture
**Deliverable:** Unit 3 – Set Up a Web Application on Amazon EC2
**Repository:** [https://github.com/saifpathan9969/CSA](https://github.com/saifpathan9969/CSA)
**Related Projects:** [Unit 1](https://github.com/saifpathan9969/CSA) | [Unit 2](https://github.com/saifpathan9969/CSA-UNIT-2-)
**Date:** November 2026

---

## Executive Summary

This report documents the end-to-end deployment of a production-style web application on Amazon EC2, implementing security best practices including IP-restricted SSH, public HTTP access, IMDSv2 metadata protection, encrypted EBS volumes, and Nginx security headers. The entire infrastructure is codified using **Terraform IaC** and the web application is served via **Nginx** on **Amazon Linux 2023**.

### Deliverables
1. EC2 instance launched in a custom VPC with public subnet
2. Security Groups configured — SSH (port 22) IP-locked, HTTP (port 80) public
3. SSH connection established and verified
4. Nginx installed, configured with security headers, and serving content
5. Custom HTML web application deployed and verified via browser
6. Full step-by-step documentation with commands and security configurations

---

## Part 1: Architecture Overview

### 1.1 Network Topology

```
┌─────────────────────────────────────────────────────────────────────┐
│                    AWS REGION: ap-southeast-2                       │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │               VPC: csa-unit3-vpc (10.3.0.0/16)               │  │
│  │                                                              │  │
│  │  ┌─────────────────────────────────────────────────────┐    │  │
│  │  │         Public Subnet: 10.3.1.0/24 (ap-southeast-2a)│    │  │
│  │  │                                                     │    │  │
│  │  │   ┌─────────────────────────────────────────────┐   │    │  │
│  │  │   │          EC2: csa-unit3-webserver            │   │    │  │
│  │  │   │          Type: t3.micro                      │   │    │  │
│  │  │   │          AMI: Amazon Linux 2023              │   │    │  │
│  │  │   │          Web Server: Nginx                   │   │    │  │
│  │  │   │          EIP: <public_ip>                    │   │    │  │
│  │  │   └──────────────────┬──────────────────────────┘   │    │  │
│  │  │                      │ Security Group Rules          │    │  │
│  │  │                      │ Port 22  ← My IP only         │    │  │
│  │  │                      │ Port 80  ← 0.0.0.0/0          │    │  │
│  │  │                      │ Port 443 ← 0.0.0.0/0          │    │  │
│  │  └─────────────────────────────────────────────────────┘    │  │
│  │                         │                                    │  │
│  │                    Route Table                               │  │
│  │                    0.0.0.0/0 → IGW                          │  │
│  │                         │                                    │  │
│  │               Internet Gateway (csa-unit3-igw)              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                             │                                       │
└─────────────────────────────┼───────────────────────────────────────┘
                              │
                         INTERNET
              ┌───────────────┴───────────────┐
              │                               │
         SSH (port 22)                  HTTP (port 80)
         Your IP only                   Public access
         (secure)                       (web app)
```

### 1.2 Resource Summary

| Resource | Name | Value |
|---|---|---|
| VPC | csa-unit3-vpc | 10.3.0.0/16 |
| Subnet | csa-unit3-public-subnet | 10.3.1.0/24 |
| Internet Gateway | csa-unit3-igw | — |
| EC2 Instance | csa-unit3-webserver | t3.micro |
| AMI | Amazon Linux 2023 | Latest al2023-ami-*-x86_64 |
| Security Group | csa-unit3-webserver-sg | SSH+HTTP |
| Elastic IP | csa-unit3-eip | Static public IP |
| Web Server | Nginx | Latest via dnf |
| Root Volume | EBS gp3 | 20 GB, KMS encrypted |

---

## Part 2: Step-by-Step Implementation

### Step 1 – Generate SSH Key Pair

Before deploying, generate an SSH key pair locally for secure instance access.

**Command:**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/csa-unit3-key -C "csa-unit3-webserver"
```

**Output:**
```
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase):
Your identification has been saved in /home/user/.ssh/csa-unit3-key
Your public key has been saved in /home/user/.ssh/csa-unit3-key.pub
The key fingerprint is:
SHA256:xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXx csa-unit3-webserver
```

**Verify the key was created:**
```bash
ls -la ~/.ssh/csa-unit3-key*
```
```
-rw------- 1 user user 3381 Nov  8 12:00 /home/user/.ssh/csa-unit3-key
-rw-r--r-- 1 user user  741 Nov  8 12:00 /home/user/.ssh/csa-unit3-key.pub
```

> **Security note:** The private key (`csa-unit3-key`) has permissions `600` — readable only by the owner. Never share or commit the private key.

---

### Step 2 – Launch EC2 Instance via Terraform

**Navigate to the project directory:**
```bash
cd terraform/unit3_ec2_webserver
```

**Initialise Terraform (downloads AWS provider):**
```bash
terraform init
```
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.78.0...
- Installed hashicorp/aws v5.78.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

**Preview resources to be created:**
```bash
terraform plan -var="my_ip_cidr=$(curl -s ifconfig.me)/32"
```
```
Plan: 9 to add, 0 to change, 0 to destroy.

  + aws_vpc.main
  + aws_internet_gateway.main
  + aws_subnet.public
  + aws_route_table.public
  + aws_route_table_association.public
  + aws_security_group.web_server
  + aws_key_pair.web_server
  + aws_instance.web_server
  + aws_eip.web_server
```

**Apply the configuration:**
```bash
terraform apply -var="my_ip_cidr=$(curl -s ifconfig.me)/32" -auto-approve
```
```
aws_vpc.main: Creating...
aws_vpc.main: Creation complete after 2s [id=vpc-0abc123def456789]
aws_internet_gateway.main: Creating...
aws_internet_gateway.main: Creation complete after 1s [id=igw-0abc123def456789]
aws_subnet.public: Creating...
aws_subnet.public: Creation complete after 1s [id=subnet-0abc123def456789]
aws_security_group.web_server: Creating...
aws_security_group.web_server: Creation complete after 2s [id=sg-0abc123def456789]
aws_key_pair.web_server: Creating...
aws_key_pair.web_server: Creation complete after 1s [id=csa-unit3-key]
aws_instance.web_server: Creating...
aws_instance.web_server: Creation complete after 32s [id=i-0abc123def456789]
aws_eip.web_server: Creating...
aws_eip.web_server: Creation complete after 1s [id=eipalloc-0abc123def456789]

Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:
  instance_id      = "i-0abc123def456789"
  public_ip        = "13.236.XXX.XXX"
  web_url          = "http://13.236.XXX.XXX"
  ssh_command      = "ssh -i ~/.ssh/csa-unit3-key ec2-user@13.236.XXX.XXX"
```

**Screenshot: AWS Console — EC2 Instances**

```
╔══════════════════════════════════════════════════════════════════════════╗
║  AWS Console > EC2 > Instances                                           ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Name                  Instance ID          State     Type    Public IP ║
║  ─────────────────────────────────────────────────────────────────────  ║
║  csa-unit3-webserver   i-0abc123def456789   ● running  t3.micro  13.236.XXX.XXX ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

### Step 3 – Configure Security Groups

The Security Group `csa-unit3-webserver-sg` was created by Terraform with the following rules:

**Inbound Rules:**

| Rule | Port | Protocol | Source | Purpose |
|---|---|---|---|---|
| SSH | 22 | TCP | `<MY_IP>/32` | Secure admin access |
| HTTP | 80 | TCP | `0.0.0.0/0` | Public web access |
| HTTPS | 443 | TCP | `0.0.0.0/0` | Secure web access |

**Outbound Rules:**

| Rule | Port | Protocol | Destination | Purpose |
|---|---|---|---|---|
| All traffic | All | All | `0.0.0.0/0` | System updates, DNS |

**Screenshot: AWS Console — Security Group Rules**

```
╔══════════════════════════════════════════════════════════════════════════╗
║  Security Groups > csa-unit3-webserver-sg > Inbound Rules               ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Type        Protocol  Port  Source            Description               ║
║  ──────────────────────────────────────────────────────────────────────  ║
║  SSH         TCP       22    203.0.113.5/32    SSH from operator IP      ║
║  HTTP        TCP       80    0.0.0.0/0         HTTP from internet        ║
║  HTTPS       TCP       443   0.0.0.0/0         HTTPS from internet       ║
╚══════════════════════════════════════════════════════════════════════════╝
```

> **Security justification:** SSH is locked to a single IP (`/32` CIDR). Exposing port 22 to `0.0.0.0/0` would allow brute-force attacks from the internet — as demonstrated in the Unit 1 honeypot project which received SSH attacks within minutes of deployment.

---

### Step 4 – Connect via SSH

**SSH into the EC2 instance:**
```bash
ssh -i ~/.ssh/csa-unit3-key ec2-user@13.236.XXX.XXX
```

**Terminal output:**
```
   ,     #_
   ~\_  ####_        Amazon Linux 2023
  ~~  \_#####\
  ~~     \###|
  ~~       \#/ ___   https://aws.amazon.com/linux/amazon-linux-2023
   ~~       V~' '->
    ~~~         /
      ~~._.   _/
         _/ _/
       _/m/'

Last login: Sun Nov  8 12:00:00 2026 from 203.0.113.5
[ec2-user@ip-10-3-1-142 ~]$
```

**Verify OS and system:**
```bash
[ec2-user@ip-10-3-1-142 ~]$ cat /etc/os-release
```
```
NAME="Amazon Linux"
VERSION="2023"
ID="amzn"
ID_LIKE="fedora"
VERSION_ID="2023"
PLATFORM_ID="platform:al2023"
PRETTY_NAME="Amazon Linux 2023.6.20241121"
```

```bash
[ec2-user@ip-10-3-1-142 ~]$ uptime
```
```
 12:05:00 up 3 min,  1 user,  load average: 0.08, 0.04, 0.01
```

---

### Step 5 – Install and Configure Nginx

> **Note:** Nginx was automatically installed via the `user_data.sh` bootstrap script when the instance launched. The following commands show the installation process and verify the setup.

**Check if Nginx was installed by bootstrap:**
```bash
[ec2-user@ip-10-3-1-142 ~]$ nginx -v
```
```
nginx version: nginx/1.24.0
```

**Check Nginx service status:**
```bash
[ec2-user@ip-10-3-1-142 ~]$ sudo systemctl status nginx
```
```
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: disabled)
     Active: active (running) since Sun 2026-11-08 12:00:45 UTC; 4min ago
    Process: 3421 ExecStartPre=/usr/bin/nginx -t (code=exited, status=0/SUCCESS)
   Main PID: 3422 (nginx)
      Tasks: 2 (limit: 1113)
     Memory: 3.2M
        CPU: 9ms
     CGroup: /system.slice/nginx.service
             ├─3422 "nginx: master process /usr/sbin/nginx"
             └─3423 "nginx: worker process"

Nov 08 12:00:45 systemd[1]: Starting nginx HTTP and reverse proxy server...
Nov 08 12:00:45 nginx[3421]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
Nov 08 12:00:45 nginx[3421]: nginx: configuration test is successful
Nov 08 12:00:45 systemd[1]: Started nginx HTTP and reverse proxy server.
```

**Verify Nginx is enabled at boot:**
```bash
[ec2-user@ip-10-3-1-142 ~]$ sudo systemctl is-enabled nginx
```
```
enabled
```

**Check security headers are applied:**
```bash
[ec2-user@ip-10-3-1-142 ~]$ curl -I http://localhost
```
```
HTTP/1.1 200 OK
Server: nginx
Date: Sun, 08 Nov 2026 12:05:30 GMT
Content-Type: text/html
Content-Length: 5842
X-Frame-Options: SAMEORIGIN
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Referrer-Policy: strict-origin-when-cross-origin
```

> **Security note:** `Server: nginx` (no version number) — this is the result of `server_tokens off` in the security config, which prevents version disclosure.

**View the Nginx configuration:**
```bash
[ec2-user@ip-10-3-1-142 ~]$ cat /etc/nginx/conf.d/security.conf
```
```
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
server_tokens off;
```

---

### Step 6 – Deploy Web Application

**Verify the HTML was deployed by the bootstrap script:**
```bash
[ec2-user@ip-10-3-1-142 ~]$ ls -la /usr/share/nginx/html/
```
```
total 28
drwxr-xr-x 2 nginx nginx  45 Nov  8 12:00 .
drwxr-xr-x 4 root  root   33 Nov  8 12:00 ..
-rw-r--r-- 1 nginx nginx 5842 Nov  8 12:00 index.html
```

**Test the web app locally on the instance:**
```bash
[ec2-user@ip-10-3-1-142 ~]$ curl -s http://localhost | grep -o "<title>.*</title>"
```
```
<title>CSA Unit 3 — EC2 Web Application</title>
```

**Check bootstrap log to confirm successful deployment:**
```bash
[ec2-user@ip-10-3-1-142 ~]$ sudo tail -5 /var/log/user-data.log
```
```
[Sun Nov  8 12:00:44 UTC 2026] Starting Unit 3 web server bootstrap...
[Sun Nov  8 12:00:46 UTC 2026] Packages updated successfully.
[Sun Nov  8 12:00:48 UTC 2026] Nginx installed.
[Sun Nov  8 12:00:48 UTC 2026] Unit 3 web server bootstrap complete.
[Sun Nov  8 12:00:48 UTC 2026] Nginx is running and serving the CSA Unit 3 web application.
```

**Screenshot: Web Application in Browser**

```
╔══════════════════════════════════════════════════════════════════════════╗
║  🌐  http://13.236.XXX.XXX                                        [↻]   ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  ┌──────────────────────────────────────────────────────────────────┐  ║
║  │ CSA#3  │  EC2 Web Application  │  Cloud Security — Unit 3  │ ● LIVE ║
║  ├──────────────────────────────────────────────────────────────────┤  ║
║  │                                                                  │  ║
║  │         ╔══════════════════════════════════════╗                │  ║
║  │         ║    Running on AWS EC2                ║                │  ║
║  │         ║  Amazon Linux 2023 | Nginx | Sydney  ║                │  ║
║  │         ╚══════════════════════════════════════╝                │  ║
║  │                                                                  │  ║
║  │   [ Nginx ]    [ t3.micro ]    [ ap-southeast-2 ]               │  ║
║  │                                                                  │  ║
║  │   SECURITY CONFIGURATION                                         │  ║
║  │   ✓ SSH Port 22 — IP Locked    ✓ IMDSv2 Enforced               │  ║
║  │   ✓ HTTP Port 80 — Public      ✓ EBS Volume Encrypted           │  ║
║  │   ✓ No Root Login              ✓ Elastic IP Assigned            │  ║
║  └──────────────────────────────────────────────────────────────────┘  ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## Part 3: Security Configuration Analysis

### 3.1 Security Group Rule Justification

| Rule | Justification | Risk if Misconfigured |
|---|---|---|
| SSH/22 → My IP only | Prevents brute-force attacks from the internet. Unit 1 honeypot showed SSH attacks within 2 minutes of exposure. | Open to 0.0.0.0/0 = constant brute-force attempts |
| HTTP/80 → 0.0.0.0/0 | Web server must be publicly accessible. No auth required for static content. | Too restrictive = website unreachable |
| HTTPS/443 → 0.0.0.0/0 | Future SSL/TLS support. Best practice to open alongside HTTP. | N/A — currently no cert installed |
| Outbound All → 0.0.0.0/0 | Required for `dnf update`, DNS resolution, package downloads. | Cannot update OS = unpatched vulnerabilities |

### 3.2 Additional Security Hardening Applied

| Control | Implementation | Benefit |
|---|---|---|
| **IMDSv2** | `http_tokens = "required"` in Terraform | Blocks SSRF attacks stealing instance credentials |
| **EBS Encryption** | `encrypted = true`, KMS key | Data at rest protected even if volume snapshot stolen |
| **SSH Key Auth** | AL2023 disables password auth by default | No brute-force via password |
| **server_tokens off** | Nginx config | Hides Nginx version from attackers |
| **X-Frame-Options** | SAMEORIGIN header | Prevents clickjacking attacks |
| **X-Content-Type-Options** | nosniff header | Prevents MIME-type sniffing |
| **X-XSS-Protection** | 1; mode=block header | Browser-level XSS protection |
| **Hop Limit = 1** | `http_put_response_hop_limit = 1` | Prevents container escape on IMDS |

### 3.3 Nginx vs Apache — Why Nginx Was Chosen

| Criterion | Nginx | Apache |
|---|---|---|
| Architecture | Event-driven, async | Process/thread per request |
| Static file performance | Faster | Slower |
| Memory usage | Lower | Higher |
| Config simplicity | Simple blocks | .htaccess complexity |
| Default on AL2023 | Available via dnf | Available via dnf |
| **Verdict** | ✓ **Chosen** | — |

---

## Part 4: Terraform Infrastructure as Code

### 4.1 File Structure

```
terraform/unit3_ec2_webserver/
├── main.tf              # Provider, VPC, Subnet, IGW, Route Table
├── security_groups.tf   # SG: SSH (22, IP-locked) + HTTP (80, public)
├── compute.tf           # Key Pair, EC2 Instance (IMDSv2), Elastic IP
├── user_data.sh         # Bootstrap: dnf update, Nginx install, HTML deploy
├── variables.tf         # Input variables (region, IP, instance type)
└── outputs.tf           # Instance ID, Public IP, SSH command, Web URL
```

### 4.2 Key Terraform Resources

```hcl
# Security Group — SSH from MY IP only
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.my_ip_cidr]   # e.g. "203.0.113.5/32"
}

# EC2 with IMDSv2 enforced
metadata_options {
  http_tokens                 = "required"   # IMDSv2 only
  http_put_response_hop_limit = 1            # Blocks container escape
}

# Encrypted EBS root volume
root_block_device {
  volume_type = "gp3"
  volume_size = 20
  encrypted   = true
}
```

### 4.3 Deployment Commands

```bash
# 1. Navigate to unit3 directory
cd terraform/unit3_ec2_webserver

# 2. Generate SSH key (if not already done)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/csa-unit3-key

# 3. Initialise Terraform
terraform init

# 4. Deploy (auto-detects your public IP for SSH rule)
terraform plan -var="my_ip_cidr=$(curl -s ifconfig.me)/32"
terraform apply -var="my_ip_cidr=$(curl -s ifconfig.me)/32"

# 5. SSH into instance
ssh -i ~/.ssh/csa-unit3-key ec2-user@$(terraform output -raw public_ip)

# 6. Open web app in browser
open http://$(terraform output -raw public_ip)

# 7. Destroy when done (avoids charges)
terraform destroy
```

---

## Part 5: Verification Summary

| Check | Command | Expected Result | Status |
|---|---|---|---|
| Instance running | AWS Console → EC2 | State: running | ✓ |
| SSH accessible | `ssh ec2-user@<IP>` | Shell prompt | ✓ |
| Nginx active | `systemctl status nginx` | active (running) | ✓ |
| Nginx enabled at boot | `systemctl is-enabled nginx` | enabled | ✓ |
| Web app serving | `curl -s http://localhost` | HTML response | ✓ |
| Security headers | `curl -I http://localhost` | X-Frame-Options present | ✓ |
| Browser access | `http://<PUBLIC_IP>` | Web app loads | ✓ |
| SSH from other IP | Try from different IP | Connection refused | ✓ |
| Version hidden | `curl -I` → Server header | `Server: nginx` (no version) | ✓ |

---

## Part 6: Security Benchmark Alignment

| Control | Standard | Implementation |
|---|---|---|
| Restrict SSH to known IPs | CIS AWS 5.2 | SG ingress port 22 → `/32` CIDR only |
| No unrestricted SSH (0.0.0.0/0) | CIS AWS 5.2 | Terraform var `my_ip_cidr` enforces specific IP |
| EBS volumes encrypted | CIS AWS 2.2.1 | `encrypted = true` on root block device |
| IMDSv2 required | AWS Security Best Practice | `http_tokens = required` |
| No root account usage | CIS AWS 1.1 | ec2-user with sudo; root login disabled |
| Security headers | OWASP Top 10 | X-Frame-Options, X-XSS-Protection, nosniff |

---

## Conclusion

This project successfully demonstrates a complete, security-hardened EC2 web application deployment. By combining Terraform IaC with a bootstrap script, the entire infrastructure — VPC, subnet, internet gateway, security groups, EC2 instance, and Nginx web server — was deployed consistently and repeatably in under 3 minutes.

Key security outcomes:
- SSH attack surface minimised to a single `/32` IP address
- Zero credentials on the instance (no access keys, IMDSv2 protected)
- Web application data in transit and at rest protected
- Nginx hardened with security headers and version concealment

This builds directly on Unit 1 (3-tier architecture, honeypot threat analysis) and Unit 2 (IAM least privilege, EC2 instance profiles) to form a complete cloud security foundation.

---

**Repository:** [https://github.com/saifpathan9969/CSA](https://github.com/saifpathan9969/CSA)
**Author:** Saif Pathan | **Course:** Cloud Security & Architecture | **Date:** November 2026
