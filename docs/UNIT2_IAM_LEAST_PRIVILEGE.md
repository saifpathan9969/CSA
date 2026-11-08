# Unit 2 – IAM & Least Privilege Enforcement
## Cloud Security & Architecture — Technical Implementation Notes

---

## Overview

This document covers the security design decisions, policy logic, and deployment instructions for the Unit 2 IAM project. All infrastructure is defined in `terraform/unit2_iam/` and is completely isolated from the Unit 1 deployments.

---

## Project Structure

```
terraform/unit2_iam/
├── main.tf          # Provider config + account password policy (CIS 1.5)
├── variables.tf     # Input variables (region, usernames, bucket name, etc.)
├── policies.tf      # All four custom IAM policy documents and resources
├── groups.tf        # IAM groups, users, memberships, login profiles
├── ec2_s3_role.tf   # Trust policy, IAM role, instance profile, EC2 instance
├── s3.tf            # KMS key, S3 bucket, bucket policy, access logs
└── outputs.tf       # All exported values
```

---

## Architecture Summary

### IAM Group Hierarchy

| Group | Attached Policies | Key Constraints |
|---|---|---|
| **Admins** | `AdministratorAccess` + `EnforceMFAPolicy` | All actions blocked without MFA token |
| **Developers** | `DeveloperLeastPrivilegePolicy` + `EnforceMFAPolicy` | EC2 (no terminate), S3 project bucket only, no IAM/billing/DB |
| **Auditors** | `SecurityAudit` (managed) + `AuditorCompliancePolicy` + `EnforceMFAPolicy` | Read-only; explicit deny on all write/mutate/start/stop actions |

**CIS Benchmark 1.16**: Policies are attached exclusively to groups, never directly to individual users.

---

## MFA Enforcement Policy Design

The `EnforceMFAPolicy` uses an `Explicit Deny` with a `BoolIfExists` condition. Explicit Deny always wins in AWS IAM policy evaluation — no Allow statement anywhere can override it.

### Bootstrap Problem & Solution

Without an exception, a new user with no MFA device configured would be immediately locked out and unable to set up their MFA device (circular dependency). The policy solves this with `NotAction` on the Deny statement, exempting only the six IAM actions needed to enroll a virtual MFA device:

```
iam:CreateVirtualMFADevice  → create the device in IAM
iam:EnableMFADevice         → bind the TOTP token to the user
iam:ListMFADevices          → check current status
iam:ResyncMFADevice         → fix clock drift on hardware tokens
iam:GetUser                 → read own user metadata
iam:ChangePassword          → set initial password on first login
```

All other API calls — EC2, S3, RDS, billing — are blocked until `aws:MultiFactorAuthPresent: true` is present in the session token.

---

## Developer Policy – Least Privilege Breakdown

Scoped by the minimum access needed for a backend engineer's day-to-day workflow:

### Allowed
- **EC2**: Describe, Start, Stop, Reboot (no Terminate, no VPC changes)
- **S3**: GetObject, PutObject, DeleteObject, ListBucket — **scoped to `csa-secure-audit-bucket-prod` ARN only**
- **CloudWatch Logs**: Create log groups/streams, put/get events

### Explicitly Denied (even if a future Allow were added)
- `ec2:TerminateInstances`, `ec2:DeleteVpc`, `ec2:DeleteSubnet`
- `s3:DeleteBucket`, `s3:DeleteBucketPolicy`, `s3:PutBucketAcl`
- All `iam:Create*`, `iam:Delete*`, `iam:Attach*`, `iam:PassRole`
- All `billing:*`, `aws-portal:*`
- All `rds:*`, `redshift:*`, `dynamodb:*`

---

## Credential-Free EC2→S3 Architecture

### Why Not Access Keys?

Static access keys (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) are the #1 source of AWS compromises:
- Written to `.bashrc`, Docker images, Git history
- No automatic expiry
- No MFA requirement
- Hard to rotate across all deployment targets

### IAM Role + Instance Profile Flow

```
1. EC2 instance boots with iam_instance_profile attached
2. AWS automatically delivers temporary STS credentials to:
   http://169.254.169.254/latest/meta-data/iam/security-credentials/EC2S3AccessRole
3. AWS SDK / CLI auto-refreshes every ~6 hours (before expiry)
4. No credentials on disk, in env vars, or in application config
5. On instance termination, credentials are automatically revoked
```

### IMDSv2 Enforcement

The instance is configured with `http_tokens = "required"` which forces IMDSv2. This prevents:
- **SSRF attacks** from stealing credentials via a web app vulnerability
- **Container escape** credential theft (hop limit = 1)

Classic SSRF (IMDSv1): attacker crafts `http://169.254.169.254/...` request via your app → gets credentials.  
With IMDSv2: request requires a PUT-first token with a TTL — the SSRF can't complete the PUT/GET handshake.

---

## S3 Security Controls

| Control | Implementation |
|---|---|
| **Encryption at rest** | SSE-KMS with customer-managed key (`alias/csa-unit2-s3-key`) |
| **KMS key rotation** | Annual automatic rotation enabled |
| **TLS enforcement** | Bucket policy denies all requests where `aws:SecureTransport = false` |
| **Unencrypted upload block** | Bucket policy denies PutObject without `x-amz-server-side-encryption: aws:kms` |
| **Public access block** | All four public access block flags enabled |
| **Versioning** | Enabled for audit trail and accidental-delete recovery |
| **Access logging** | Logged to a separate `*-access-logs` bucket |

---

## CIS AWS Foundations Benchmark Alignment

| Control ID | Requirement | Implementation |
|---|---|---|
| 1.5 | Password policy (14+ chars, complexity, reuse prevention) | `aws_iam_account_password_policy` in `main.tf` |
| 1.10 | MFA for all IAM users | `EnforceMFAPolicy` attached to all three groups |
| 1.16 | Policies on groups/roles only, not users | All `aws_iam_group_policy_attachment` resources, zero `aws_iam_user_policy` |
| 2.1.1 | S3 bucket denies HTTP | `EnforceTLSRequestsOnly` statement in bucket policy |
| 2.1.2 | S3 server-side encryption enabled | SSE-KMS with CMK |
| 2.1.5 | S3 public access blocked | `aws_s3_bucket_public_access_block` all flags `true` |

---

## Deployment Instructions

### Prerequisites
- Terraform >= 1.5.0
- AWS CLI configured with an IAM user or role that has permissions to create IAM resources
- An AWS account in `ap-southeast-2`

### Steps

```bash
cd terraform/unit2_iam

# 1. Initialise providers
terraform init

# 2. Review what will be created
terraform plan -out=unit2.tfplan

# 3. Apply
terraform apply unit2.tfplan
```

### Customise user lists

Edit `variables.tf` or pass overrides at plan time:

```bash
terraform plan \
  -var='admin_usernames=["alice","bob"]' \
  -var='developer_usernames=["charlie","diana","eve"]' \
  -var='auditor_usernames=["frank"]' \
  -var='project_bucket_name=my-org-secure-bucket'
```

### Destroy

```bash
terraform destroy
```

> **Note**: `force_destroy = false` on the S3 buckets means Terraform will refuse to delete a non-empty bucket. Empty the bucket manually first or set `force_destroy = true` in a destroy-only override.

---

## Verification Commands

After deployment, verify each security control from the CLI:

```bash
# 1. Verify IAM groups exist
aws iam list-groups --path-prefix /csa-unit2/

# 2. Verify group memberships
aws iam get-group --group-name Admins
aws iam get-group --group-name Developers
aws iam get-group --group-name Auditors

# 3. Verify MFA policy is attached to all groups
aws iam list-attached-group-policies --group-name Admins
aws iam list-attached-group-policies --group-name Developers
aws iam list-attached-group-policies --group-name Auditors

# 4. Verify EC2 role and trust policy
aws iam get-role --role-name EC2S3AccessRole

# 5. Verify S3 bucket encryption
aws s3api get-bucket-encryption --bucket csa-secure-audit-bucket-prod

# 6. Verify S3 bucket policy (TLS enforcement)
aws s3api get-bucket-policy --bucket csa-secure-audit-bucket-prod

# 7. Verify public access block
aws s3api get-public-access-block --bucket csa-secure-audit-bucket-prod

# 8. From inside the EC2 instance – verify credential-free access
aws sts get-caller-identity
aws s3 ls s3://csa-secure-audit-bucket-prod
```

---

## Key Design Decisions

1. **`BoolIfExists` vs `Bool`** in the MFA condition: `Bool` would block service-to-service calls that don't support MFA tokens. `BoolIfExists` only applies the condition when the key is present in the request context — service roles are unaffected.

2. **Separate access log bucket**: S3 can't deliver access logs to the same bucket being logged (infinite loop). A dedicated `*-access-logs` bucket is required.

3. **`max_session_duration = 3600`** on the EC2 role: Reduces the blast radius of a compromised token to 1 hour maximum.

4. **`hop_limit = 1`** on IMDS: A token with hop limit 1 cannot be forwarded through a container or a proxy, preventing lateral movement within a multi-tenant host.
