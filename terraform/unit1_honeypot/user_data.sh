#!/bin/bash
# ─────────────────────────────────────────────────────────────
# Honeypot EC2 – User Data Bootstrap Script
# Configures verbose SSH logging, auditd, and fail2ban for
# empirical analysis of brute-force attack patterns.
# ─────────────────────────────────────────────────────────────

set -euo pipefail

echo ">>> [Honeypot] Starting bootstrap at $(date -u)"

# ── System Updates ───────────────────────────────────────────
yum update -y

# ── Install monitoring tools ────────────────────────────────
yum install -y \
  audit \
  httpd \
  jq \
  curl

# ── Configure SSH for verbose logging ───────────────────────
# Increase log verbosity to capture every authentication attempt
sed -i 's/^#LogLevel .*/LogLevel VERBOSE/' /etc/ssh/sshd_config
sed -i 's/^LogLevel .*/LogLevel VERBOSE/' /etc/ssh/sshd_config

# Ensure password authentication is ON (for brute-force observation)
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Disable root login (safety measure – attackers can try but cannot succeed)
sed -i 's/^#PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config

# Increase MaxAuthTries to observe more attempts per connection
sed -i 's/^#MaxAuthTries .*/MaxAuthTries 10/' /etc/ssh/sshd_config

systemctl restart sshd

# ── Configure auditd ────────────────────────────────────────
systemctl enable auditd
systemctl start auditd

# Audit SSH-related system calls
auditctl -w /var/log/secure -p wa -k ssh_logins
auditctl -w /etc/ssh/sshd_config -p wa -k sshd_config_changes

# ── Configure HTTP (simple web page for scanner bait) ───────
systemctl enable httpd
systemctl start httpd

cat > /var/www/html/index.html << 'WEBEOF'
<!DOCTYPE html>
<html>
<head><title>Welcome</title></head>
<body>
<h1>Cloud Application Server</h1>
<p>Version 2.1.4 - Internal Portal</p>
</body>
</html>
WEBEOF

# ── Create log analysis helper scripts ──────────────────────
mkdir -p /opt/honeypot

cat > /opt/honeypot/analyze_ssh.sh << 'SCRIPTEOF'
#!/bin/bash
# ── SSH Brute-Force Analysis Script ──
echo "============================================"
echo "  SSH BRUTE-FORCE ATTACK ANALYSIS REPORT"
echo "  Generated: $(date -u)"
echo "============================================"
echo ""

echo "── Total Failed SSH Attempts ─────────────"
grep -c "Failed password" /var/log/secure 2>/dev/null || echo "0"
echo ""

echo "── Top 20 Source IPs ─────────────────────"
grep "Failed password" /var/log/secure 2>/dev/null | \
  awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
  sort | uniq -c | sort -rn | head -20
echo ""

echo "── Top 20 Usernames Targeted ────────────"
grep "Failed password" /var/log/secure 2>/dev/null | \
  awk '{for(i=1;i<=NF;i++) if($i=="for") {if($(i+1)=="invalid") print $(i+3); else print $(i+1)}}' | \
  sort | uniq -c | sort -rn | head -20
echo ""

echo "── Attack Timeline (hourly) ─────────────"
grep "Failed password" /var/log/secure 2>/dev/null | \
  awk '{print $1, $2, substr($3,1,2)":00"}' | \
  sort | uniq -c | sort -rn | head -20
echo ""

echo "── Accepted Logins (should be ZERO) ─────"
grep "Accepted" /var/log/secure 2>/dev/null | head -10
echo ""
SCRIPTEOF

chmod +x /opt/honeypot/analyze_ssh.sh

echo ">>> [Honeypot] Bootstrap complete at $(date -u)"
