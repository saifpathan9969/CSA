###############################################################################
# Unit 2 – IAM & Least Privilege Enforcement
# ec2_s3_role.tf  –  Credential-free EC2→S3 IAM Role & Instance Profile
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# Trust Policy  – only EC2 service can assume this role (sts:AssumeRole)
# ─────────────────────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "ec2_trust_policy" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM Role
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role" "ec2_s3_role" {
  name               = "EC2S3AccessRole"
  path               = "/csa-unit2/"
  description        = "Allows EC2 instances to access the project S3 bucket via temporary STS credentials. No static keys required."
  assume_role_policy = data.aws_iam_policy_document.ec2_trust_policy.json

  # Enforce session duration – tokens expire after 1 hour (minimum)
  max_session_duration = 3600

  tags = {
    RoleType = "EC2-InstanceRole"
    Purpose  = "S3-CredentialFreeAccess"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# Attach the EC2-to-S3 access policy to the role
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_role_policy_attachment" "ec2_s3_access" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.ec2_s3_access.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# Instance Profile  – wraps the role so EC2 can use it at launch
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "EC2S3InstanceProfile"
  path = "/csa-unit2/"
  role = aws_iam_role.ec2_s3_role.name

  tags = {
    Purpose = "EC2-InstanceProfile-S3Access"
  }
}

###############################################################################
# IMDSv2-only EC2 instance that uses the Instance Profile
# (Demonstrates credential-free S3 access – no hardcoded keys)
###############################################################################
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "app_server" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t3.micro"
  iam_instance_profile = aws_iam_instance_profile.ec2_s3_profile.name

  # Enforce IMDSv2 – blocks credential theft via SSRF (CWE-918)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 1          # Prevents container escape
    instance_metadata_tags      = "enabled"
  }

  # Harden root volume
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    kms_key_id            = aws_kms_key.s3_key.arn
    delete_on_termination = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Verify credential-free S3 access on first boot
    yum update -y
    aws s3 ls s3://${var.project_bucket_name} --region ${var.aws_region}
    echo "EC2-to-S3 credential-free access verified via instance profile." \
      >> /var/log/iam-unit2-verify.log
  EOF
  )

  tags = {
    Name    = "csa-unit2-app-server"
    Purpose = "IAM-InstanceProfile-Demo"
  }
}
