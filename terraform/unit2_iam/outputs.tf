###############################################################################
# Unit 2 – IAM & Least Privilege Enforcement
# outputs.tf
###############################################################################

# ── Groups ────────────────────────────────────────────────────────────────────
output "iam_group_admins_arn" {
  description = "ARN of the Admins IAM group"
  value       = aws_iam_group.admins.arn
}

output "iam_group_developers_arn" {
  description = "ARN of the Developers IAM group"
  value       = aws_iam_group.developers.arn
}

output "iam_group_auditors_arn" {
  description = "ARN of the Auditors IAM group"
  value       = aws_iam_group.auditors.arn
}

# ── Policies ──────────────────────────────────────────────────────────────────
output "enforce_mfa_policy_arn" {
  description = "ARN of the MFA enforcement policy"
  value       = aws_iam_policy.enforce_mfa.arn
}

output "developer_policy_arn" {
  description = "ARN of the Developer least-privilege policy"
  value       = aws_iam_policy.developer_least_privilege.arn
}

output "auditor_policy_arn" {
  description = "ARN of the Auditor compliance policy"
  value       = aws_iam_policy.auditor_compliance.arn
}

output "ec2_s3_access_policy_arn" {
  description = "ARN of the EC2-to-S3 access policy"
  value       = aws_iam_policy.ec2_s3_access.arn
}

# ── EC2 Role & Profile ────────────────────────────────────────────────────────
output "ec2_s3_role_arn" {
  description = "ARN of the EC2-to-S3 IAM role"
  value       = aws_iam_role.ec2_s3_role.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_s3_profile.name
}

output "app_server_instance_id" {
  description = "Instance ID of the demo EC2 app server"
  value       = aws_instance.app_server.id
}

# ── S3 & KMS ──────────────────────────────────────────────────────────────────
output "project_bucket_arn" {
  description = "ARN of the hardened S3 project bucket"
  value       = aws_s3_bucket.project_bucket.arn
}

output "project_bucket_name" {
  description = "Name of the hardened S3 project bucket"
  value       = aws_s3_bucket.project_bucket.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for S3 encryption"
  value       = aws_kms_key.s3_key.arn
}

output "kms_key_id" {
  description = "ID of the KMS key"
  value       = aws_kms_key.s3_key.key_id
}

# ── Users ─────────────────────────────────────────────────────────────────────
output "admin_user_arns" {
  description = "ARNs of created admin users"
  value       = { for k, v in aws_iam_user.admins : k => v.arn }
}

output "developer_user_arns" {
  description = "ARNs of created developer users"
  value       = { for k, v in aws_iam_user.developers : k => v.arn }
}

output "auditor_user_arns" {
  description = "ARNs of created auditor users"
  value       = { for k, v in aws_iam_user.auditors : k => v.arn }
}
