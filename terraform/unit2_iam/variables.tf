###############################################################################
# Unit 2 – IAM & Least Privilege Enforcement
# variables.tf
###############################################################################

variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment (dev | staging | prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Project owner name"
  type        = string
  default     = "Saif Pathan"
}

variable "project_bucket_name" {
  description = "Name of the S3 bucket the Developer group and EC2 role will access"
  type        = string
  default     = "csa-secure-audit-bucket-prod"
}

variable "kms_key_deletion_window" {
  description = "KMS key scheduled deletion window in days (7–30)"
  type        = number
  default     = 30
}

# ── Sample user names ─────────────────────────────────────────────────────────
variable "admin_usernames" {
  description = "List of IAM usernames to place in the Admins group"
  type        = list(string)
  default     = ["admin-alice", "admin-bob"]
}

variable "developer_usernames" {
  description = "List of IAM usernames to place in the Developers group"
  type        = list(string)
  default     = ["dev-charlie", "dev-diana"]
}

variable "auditor_usernames" {
  description = "List of IAM usernames to place in the Auditors group"
  type        = list(string)
  default     = ["audit-eve"]
}
