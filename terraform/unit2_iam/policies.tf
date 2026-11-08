###############################################################################
# Unit 2 – IAM & Least Privilege Enforcement
# policies.tf  –  Custom IAM policy documents & aws_iam_policy resources
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# 1. MFA Enforcement Policy  (attached to ALL three groups)
#    CIS Benchmark 1.10 – MFA enabled for all IAM users
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "enforce_mfa" {
  # Allow users to manage only their OWN MFA device & password  (bootstrap)
  statement {
    sid    = "AllowSelfServiceMFASetup"
    effect = "Allow"
    actions = [
      "iam:ListVirtualMFADevices",
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
      "iam:DeleteVirtualMFADevice",
      "iam:GetUser",
      "iam:ListMFADevices",
      "iam:ChangePassword",
    ]
    resources = [
      "arn:aws:iam::*:mfa/$${aws:username}",
      "arn:aws:iam::*:user/$${aws:username}",
    ]
  }

  # Deny EVERYTHING else when MFA is not present
  statement {
    sid    = "DenyAllExceptMFASetupWithoutMFA"
    effect = "Deny"
    not_actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ListMFADevices",
      "iam:ResyncMFADevice",
      "iam:GetUser",
      "iam:ChangePassword",
    ]
    resources = ["*"]
    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "enforce_mfa" {
  name        = "EnforceMFAPolicy"
  path        = "/csa-unit2/"
  description = "Denies all API actions unless the session was authenticated with MFA. Allows self-service MFA bootstrap."
  policy      = data.aws_iam_policy_document.enforce_mfa.json

  tags = {
    PolicyType = "MFA-Enforcement"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Developer Least-Privilege Policy
#    Scoped to: EC2 (no terminate), S3 (project bucket only), CloudWatch Logs
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "developer_least_privilege" {
  # EC2 – Read + lifecycle control; hard block on destructive actions
  statement {
    sid    = "EC2InstanceOperations"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeImages",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:RebootInstances",
    ]
    resources = ["*"]
  }

  # Explicit Deny on EC2 destructive operations
  statement {
    sid    = "DenyEC2DestructiveActions"
    effect = "Deny"
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteVpc",
      "ec2:DeleteSubnet",
      "ec2:DeleteSecurityGroup",
    ]
    resources = ["*"]
  }

  # S3 – Read/Write on the single project bucket only
  statement {
    sid    = "S3ProjectBucketReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.project_bucket_name}",
      "arn:aws:s3:::${var.project_bucket_name}/*",
    ]
  }

  # S3 – Allow listing buckets so the SDK can resolve bucket regions
  statement {
    sid       = "S3ListAllBuckets"
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  # Deny bucket deletion and cross-bucket access
  statement {
    sid    = "DenyS3BucketDeletion"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketAcl",
    ]
    resources = ["*"]
  }

  # CloudWatch Logs – Write application logs and read project log groups
  statement {
    sid    = "CloudWatchLogsAccess"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }

  # Explicit Deny on IAM, Billing, and database management
  statement {
    sid    = "DenyIAMAndBilling"
    effect = "Deny"
    actions = [
      "iam:Create*",
      "iam:Delete*",
      "iam:Attach*",
      "iam:Detach*",
      "iam:Put*",
      "iam:Update*",
      "iam:PassRole",
      "aws-portal:*",
      "billing:*",
      "rds:*",
      "redshift:*",
      "dynamodb:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "developer_least_privilege" {
  name        = "DeveloperLeastPrivilegePolicy"
  path        = "/csa-unit2/"
  description = "Scoped developer access: EC2 lifecycle (no terminate), S3 project bucket, CloudWatch Logs. All IAM/billing/DB access denied."
  policy      = data.aws_iam_policy_document.developer_least_privilege.json

  tags = {
    PolicyType = "Developer-LeastPrivilege"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Auditor Compliance Policy
#    Read-only across audit services; explicit deny on all mutating actions
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "auditor_compliance" {
  # Read-only access to audit and compliance services
  statement {
    sid    = "AuditReadOnlyAccess"
    effect = "Allow"
    actions = [
      # CloudTrail
      "cloudtrail:GetTrail",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:ListTrails",
      "cloudtrail:LookupEvents",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetEventSelectors",
      # AWS Config
      "config:DescribeConfigRules",
      "config:DescribeConfigurationRecorders",
      "config:GetComplianceDetailsByConfigRule",
      "config:GetComplianceSummaryByConfigRule",
      "config:ListDiscoveredResources",
      # GuardDuty
      "guardduty:GetDetector",
      "guardduty:ListDetectors",
      "guardduty:ListFindings",
      "guardduty:GetFindings",
      # IAM read-only
      "iam:GenerateCredentialReport",
      "iam:GetCredentialReport",
      "iam:GetAccountPasswordPolicy",
      "iam:GetAccountSummary",
      "iam:ListUsers",
      "iam:ListGroups",
      "iam:ListRoles",
      "iam:ListPolicies",
      "iam:ListAttachedGroupPolicies",
      "iam:ListGroupPolicies",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
      # KMS metadata only (no decrypt)
      "kms:ListKeys",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListAliases",
      # S3 metadata
      "s3:GetBucketPolicy",
      "s3:GetBucketAcl",
      "s3:GetBucketLogging",
      "s3:GetBucketVersioning",
      "s3:GetEncryptionConfiguration",
      "s3:ListAllMyBuckets",
      # EC2 describe
      "ec2:Describe*",
      # CloudWatch metrics (read)
      "cloudwatch:GetMetricData",
      "cloudwatch:ListMetrics",
      "cloudwatch:DescribeAlarms",
      # Access Analyzer
      "access-analyzer:ListAnalyzers",
      "access-analyzer:ListFindings",
      "access-analyzer:GetFinding",
    ]
    resources = ["*"]
  }

  # Hard deny on ALL mutating actions across every service
  statement {
    sid    = "DenyAllMutatingActions"
    effect = "Deny"
    actions = [
      "*:Create*",
      "*:Delete*",
      "*:Update*",
      "*:Modify*",
      "*:Put*",
      "*:Set*",
      "*:Attach*",
      "*:Detach*",
      "*:Associate*",
      "*:Disassociate*",
      "*:Run*",
      "*:Start*",
      "*:Stop*",
      "*:Terminate*",
      "*:Reboot*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "auditor_compliance" {
  name        = "AuditorCompliancePolicy"
  path        = "/csa-unit2/"
  description = "Read-only compliance access to CloudTrail, AWS Config, GuardDuty, IAM, KMS, S3 metadata. Explicit deny on all write/mutate actions."
  policy      = data.aws_iam_policy_document.auditor_compliance.json

  tags = {
    PolicyType = "Auditor-ReadOnly"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# 4. EC2-to-S3 Role Policy  (used in ec2_s3_role.tf)
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "ec2_s3_access" {
  statement {
    sid    = "S3BucketReadWrite"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.project_bucket_name}",
      "arn:aws:s3:::${var.project_bucket_name}/*",
    ]
  }

  # Allow EC2 to write its own logs via CloudWatch
  statement {
    sid    = "CloudWatchLogsWrite"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }

  # Allow EC2 metadata describe (required for IMDSv2)
  statement {
    sid    = "EC2DescribeSelf"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ec2_s3_access" {
  name        = "EC2S3AccessPolicy"
  path        = "/csa-unit2/"
  description = "Grants EC2 instance role access to the project S3 bucket and CloudWatch Logs. No static credentials required."
  policy      = data.aws_iam_policy_document.ec2_s3_access.json

  tags = {
    PolicyType = "EC2-InstanceRole"
  }
}
