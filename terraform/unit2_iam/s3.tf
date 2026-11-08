###############################################################################
# Unit 2 – IAM & Least Privilege Enforcement
# s3.tf  –  Hardened S3 bucket (KMS encryption + TLS enforcement)
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# KMS Customer Managed Key for S3 encryption
# CIS Benchmark 2.1.2 – Server-side encryption enabled
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_kms_key" "s3_key" {
  description              = "KMS key for CSA Unit 2 S3 bucket encryption"
  deletion_window_in_days  = var.kms_key_deletion_window
  enable_key_rotation      = true # CIS Benchmark – annual key rotation
  multi_region             = false

  tags = {
    Purpose = "S3-Encryption"
  }
}

resource "aws_kms_alias" "s3_key" {
  name          = "alias/csa-unit2-s3-key"
  target_key_id = aws_kms_key.s3_key.key_id
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 Bucket
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "project_bucket" {
  bucket        = var.project_bucket_name
  force_destroy = false # Prevent accidental data loss

  tags = {
    Purpose     = "SecureAuditStorage"
    Encrypted   = "true"
    TLSEnforced = "true"
  }
}

# Block ALL public access (CIS Benchmark 2.1.5)
resource "aws_s3_bucket_public_access_block" "project_bucket" {
  bucket = aws_s3_bucket.project_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for audit trail
resource "aws_s3_bucket_versioning" "project_bucket" {
  bucket = aws_s3_bucket.project_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# AES-256 via KMS (CIS Benchmark 2.1.2)
resource "aws_s3_bucket_server_side_encryption_configuration" "project_bucket" {
  bucket = aws_s3_bucket.project_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
    bucket_key_enabled = true # Reduces KMS API call costs
  }
}

# Enable access logging for audit trail
resource "aws_s3_bucket_logging" "project_bucket" {
  bucket        = aws_s3_bucket.project_bucket.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "s3-access-logs/"
}

# ─────────────────────────────────────────────────────────────────────────────
# Separate bucket for S3 access logs (cannot log to itself)
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.project_bucket_name}-access-logs"
  force_destroy = false

  tags = {
    Purpose = "S3AccessLogs"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 Bucket Policy – Enforce TLS / Deny HTTP
# CIS Benchmark 2.1.1 – Deny non-SSL requests
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "project_bucket_policy" {
  # Deny any non-TLS request to the bucket
  statement {
    sid       = "EnforceTLSRequestsOnly"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [
      aws_s3_bucket.project_bucket.arn,
      "${aws_s3_bucket.project_bucket.arn}/*",
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  # Deny unencrypted uploads (must use SSE-KMS)
  statement {
    sid     = "DenyUnencryptedObjectUploads"
    effect  = "Deny"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.project_bucket.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  # Allow the EC2 role full read/write access
  statement {
    sid     = "AllowEC2RoleAccess"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.project_bucket.arn,
      "${aws_s3_bucket.project_bucket.arn}/*",
    ]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.ec2_s3_role.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "project_bucket" {
  bucket = aws_s3_bucket.project_bucket.id
  policy = data.aws_iam_policy_document.project_bucket_policy.json

  # Public access block must be applied before the policy
  depends_on = [aws_s3_bucket_public_access_block.project_bucket]
}
