###############################################################################
# Unit 2 – IAM & Least Privilege Enforcement
# groups.tf  –  IAM Groups, Users, Memberships, and Policy Attachments
###############################################################################

# ─────────────────────────────────────────────────────────────────────────────
# IAM GROUPS
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_group" "admins" {
  name = "Admins"
  path = "/csa-unit2/"
}

resource "aws_iam_group" "developers" {
  name = "Developers"
  path = "/csa-unit2/"
}

resource "aws_iam_group" "auditors" {
  name = "Auditors"
  path = "/csa-unit2/"
}

# ─────────────────────────────────────────────────────────────────────────────
# POLICY ATTACHMENTS – Admins
#   • AWS Managed: AdministratorAccess
#   • Custom:      EnforceMFAPolicy
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_group_policy_attachment" "admins_administrator_access" {
  group      = aws_iam_group.admins.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_group_policy_attachment" "admins_enforce_mfa" {
  group      = aws_iam_group.admins.name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# POLICY ATTACHMENTS – Developers
#   • Custom: DeveloperLeastPrivilegePolicy
#   • Custom: EnforceMFAPolicy
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_group_policy_attachment" "developers_least_privilege" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.developer_least_privilege.arn
}

resource "aws_iam_group_policy_attachment" "developers_enforce_mfa" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# POLICY ATTACHMENTS – Auditors
#   • AWS Managed: SecurityAudit
#   • Custom:      AuditorCompliancePolicy
#   • Custom:      EnforceMFAPolicy
# ─────────────────────────────────────────────────────────────────────────────
resource "aws_iam_group_policy_attachment" "auditors_security_audit" {
  group      = aws_iam_group.auditors.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}

resource "aws_iam_group_policy_attachment" "auditors_compliance" {
  group      = aws_iam_group.auditors.name
  policy_arn = aws_iam_policy.auditor_compliance.arn
}

resource "aws_iam_group_policy_attachment" "auditors_enforce_mfa" {
  group      = aws_iam_group.auditors.name
  policy_arn = aws_iam_policy.enforce_mfa.arn
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM USERS  (CIS 1.16 – policies attached to groups, never directly to users)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_user" "admins" {
  for_each = toset(var.admin_usernames)

  name          = each.key
  path          = "/csa-unit2/"
  force_destroy = true # Allow Terraform destroy even if keys/passwords exist

  tags = {
    Role = "Admin"
  }
}

resource "aws_iam_user" "developers" {
  for_each = toset(var.developer_usernames)

  name          = each.key
  path          = "/csa-unit2/"
  force_destroy = true

  tags = {
    Role = "Developer"
  }
}

resource "aws_iam_user" "auditors" {
  for_each = toset(var.auditor_usernames)

  name          = each.key
  path          = "/csa-unit2/"
  force_destroy = true

  tags = {
    Role = "Auditor"
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# GROUP MEMBERSHIPS
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_group_membership" "admins" {
  name  = "admins-group-membership"
  group = aws_iam_group.admins.name
  users = [for u in aws_iam_user.admins : u.name]
}

resource "aws_iam_group_membership" "developers" {
  name  = "developers-group-membership"
  group = aws_iam_group.developers.name
  users = [for u in aws_iam_user.developers : u.name]
}

resource "aws_iam_group_membership" "auditors" {
  name  = "auditors-group-membership"
  group = aws_iam_group.auditors.name
  users = [for u in aws_iam_user.auditors : u.name]
}

# ─────────────────────────────────────────────────────────────────────────────
# CONSOLE LOGIN PROFILES  (force password change on first login)
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_user_login_profile" "admins" {
  for_each = aws_iam_user.admins

  user                    = each.value.name
  password_reset_required = true

  lifecycle {
    ignore_changes = [password_length, password_reset_required, pgp_key]
  }
}

resource "aws_iam_user_login_profile" "developers" {
  for_each = aws_iam_user.developers

  user                    = each.value.name
  password_reset_required = true

  lifecycle {
    ignore_changes = [password_length, password_reset_required, pgp_key]
  }
}

resource "aws_iam_user_login_profile" "auditors" {
  for_each = aws_iam_user.auditors

  user                    = each.value.name
  password_reset_required = true

  lifecycle {
    ignore_changes = [password_length, password_reset_required, pgp_key]
  }
}
