#!/bin/bash
# ============================================================
# Unit 3 – EC2 Web Server Bootstrap Script
# Installs Nginx and deploys the CSA Unit 3 web application
# ============================================================

set -euo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "[$(date)] Starting Unit 3 web server bootstrap..."

# 1. Update system packages
dnf update -y

# 2. Install Nginx
dnf install -y nginx

# 3. Enable and start Nginx
systemctl enable nginx
systemctl start nginx

# 4. Deploy the web application HTML
cat > /usr/share/nginx/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1.0"/>
  <title>CSA Unit 3 — EC2 Web Application</title>
  <style>
    *{box-sizing:border-box;margin:0;padding:0}
    :root{--blk:#000;--yel:#FFE600;--red:#FF2D00;--grn:#00FF41;--f:'Courier New',monospace}
    body{background:#0a0a0a;color:#fff;font-family:var(--f);min-height:100vh;display:flex;flex-direction:column}
    header{background:var(--blk);border-bottom:5px solid var(--yel);padding:0}
    .hi{display:flex;align-items:stretch}
    .hl{background:var(--yel);color:var(--blk);font-size:22px;font-weight:900;padding:14px 24px;border-right:4px solid #000;letter-spacing:-1px;text-transform:uppercase}
    .hl span{color:var(--red)}
    .ht{padding:14px 24px;font-size:10px;letter-spacing:3px;text-transform:uppercase;color:#888;display:flex;flex-direction:column;justify-content:center}
    .ht strong{color:var(--yel);font-size:15px;letter-spacing:1px}
    .sp{margin-left:auto;background:var(--grn);color:#000;font-size:10px;font-weight:900;padding:0 20px;display:flex;align-items:center;gap:6px;border-left:4px solid #000;letter-spacing:2px;text-transform:uppercase}
    .sp::before{content:'●';font-size:9px;animation:blink 1.2s step-end infinite}
    @keyframes blink{0%,100%{opacity:1}50%{opacity:0}}
    main{flex:1;max-width:1100px;margin:0 auto;padding:40px 24px;width:100%}
    .hero{border:4px solid var(--yel);box-shadow:8px 8px 0 var(--yel);padding:40px;margin-bottom:40px;background:#111;text-align:center}
    .hero h1{font-size:48px;font-weight:900;letter-spacing:-2px;text-transform:uppercase;line-height:1}
    .hero h1 span{color:var(--yel)}
    .hero p{color:#aaa;font-size:13px;letter-spacing:2px;margin-top:14px;text-transform:uppercase}
    .grid{display:grid;grid-template-columns:repeat(3,1fr);gap:20px;margin-bottom:40px}
    @media(max-width:700px){.grid{grid-template-columns:1fr}}
    .card{border:3px solid #333;padding:20px;background:#111;box-shadow:4px 4px 0 #333}
    .card-title{font-size:10px;letter-spacing:3px;text-transform:uppercase;color:#666;margin-bottom:8px}
    .card-val{font-size:28px;font-weight:900;color:var(--yel)}
    .card-sub{font-size:10px;color:#555;margin-top:4px;letter-spacing:1px}
    .section-title{font-size:20px;font-weight:900;text-transform:uppercase;letter-spacing:-1px;border-bottom:3px solid var(--yel);padding-bottom:8px;margin-bottom:20px;color:var(--yel)}
    .stack-list{list-style:none}
    .stack-list li{border:2px solid #222;padding:10px 14px;margin-bottom:8px;font-size:12px;display:flex;align-items:center;gap:10px;color:#ccc}
    .stack-list li::before{content:'▶';color:var(--red);font-size:9px}
    .stack-list li strong{color:#fff}
    .security-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:16px;margin-bottom:40px}
    @media(max-width:600px){.security-grid{grid-template-columns:1fr}}
    .sec-card{border-left:5px solid var(--grn);padding:14px;background:#0d0d0d;border:2px solid #222;border-left:5px solid var(--grn)}
    .sec-card h4{font-size:11px;letter-spacing:2px;text-transform:uppercase;color:var(--grn);margin-bottom:6px}
    .sec-card p{font-size:11px;color:#888;line-height:1.6}
    .terminal{background:#000;border:3px solid #333;padding:20px;font-size:11px;line-height:1.8;margin-bottom:40px;box-shadow:4px 4px 0 #333}
    .terminal .prompt{color:var(--grn)}
    .terminal .cmd{color:#fff}
    .terminal .out{color:#888}
    footer{background:#000;border-top:4px solid var(--yel);padding:14px 24px;font-size:9px;letter-spacing:2px;text-transform:uppercase;color:#555;display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px}
    footer span{color:var(--yel)}
    #ts{color:var(--grn)}
  </style>
</head>
<body>
<header>
  <div class="hi">
    <div class="hl">CSA<span>#</span>3</div>
    <div class="ht"><strong>EC2 Web Application</strong>Cloud Security &amp; Architecture — Unit 3</div>
    <div class="sp">LIVE ON EC2</div>
  </div>
</header>

<main>
  <div class="hero">
    <h1>Running on <span>AWS EC2</span></h1>
    <p>Amazon Linux 2023 &nbsp;|&nbsp; Nginx Web Server &nbsp;|&nbsp; ap-southeast-2 &nbsp;|&nbsp; Deployed via Terraform</p>
  </div>

  <div class="grid">
    <div class="card">
      <div class="card-title">Web Server</div>
      <div class="card-val">Nginx</div>
      <div class="card-sub">Latest stable via dnf</div>
    </div>
    <div class="card">
      <div class="card-title">Instance Type</div>
      <div class="card-val">t3.micro</div>
      <div class="card-sub">Free tier eligible</div>
    </div>
    <div class="card">
      <div class="card-title">Region</div>
      <div class="card-val">ap-southeast-2</div>
      <div class="card-sub">Sydney, Australia</div>
    </div>
  </div>

  <h2 class="section-title">Security Configuration</h2>
  <div class="security-grid">
    <div class="sec-card">
      <h4>SSH Access (Port 22)</h4>
      <p>Restricted to operator IP only via Security Group ingress rule. No public SSH exposure.</p>
    </div>
    <div class="sec-card">
      <h4>HTTP Access (Port 80)</h4>
      <p>Open to 0.0.0.0/0 for public web access. Nginx serves static content.</p>
    </div>
    <div class="sec-card">
      <h4>IMDSv2 Enforced</h4>
      <p>Instance metadata requires token-based requests. Blocks SSRF credential theft attacks.</p>
    </div>
    <div class="sec-card">
      <h4>Encrypted Root Volume</h4>
      <p>EBS root volume encrypted with AES-256 KMS. All data at rest is protected.</p>
    </div>
    <div class="sec-card">
      <h4>No Root Login</h4>
      <p>SSH key-based auth only. Password auth disabled in sshd_config by default on AL2023.</p>
    </div>
    <div class="sec-card">
      <h4>Elastic IP Assigned</h4>
      <p>Static public IP persists across instance stop/start cycles. No DNS changes needed.</p>
    </div>
  </div>

  <h2 class="section-title">Tech Stack</h2>
  <ul class="stack-list">
    <li><strong>OS:</strong> Amazon Linux 2023 (AL2023) — latest AMI</li>
    <li><strong>Web Server:</strong> Nginx — installed via dnf package manager</li>
    <li><strong>IaC:</strong> Terraform >= 1.5.0 with AWS Provider ~> 5.0</li>
    <li><strong>Networking:</strong> Custom VPC (10.3.0.0/16), Public Subnet, Internet Gateway</li>
    <li><strong>Security:</strong> Security Groups — SSH/22 (IP-locked), HTTP/80 (public)</li>
    <li><strong>Storage:</strong> gp3 EBS, 20 GB, KMS encrypted</li>
  </ul>

  <h2 class="section-title">Deployment Verification</h2>
  <div class="terminal">
    <div><span class="prompt">ubuntu@local:~$</span> <span class="cmd">ssh -i ~/.ssh/csa-unit3-key ec2-user@&lt;EC2_PUBLIC_IP&gt;</span></div>
    <div><span class="out">The authenticity of host can't be established. Are you sure? yes</span></div>
    <div><span class="out">Last login: Sun Nov 8 12:00:00 2026 from &lt;YOUR_IP&gt;</span></div>
    <div>&nbsp;</div>
    <div><span class="prompt">[ec2-user@ip-10-3-1-x ~]$</span> <span class="cmd">sudo systemctl status nginx</span></div>
    <div><span class="out">● nginx.service - The nginx HTTP and reverse proxy server</span></div>
    <div><span class="out">&nbsp;&nbsp;&nbsp;Active: <span style="color:#00FF41">active (running)</span> since Sun 2026-11-08</span></div>
    <div>&nbsp;</div>
    <div><span class="prompt">[ec2-user@ip-10-3-1-x ~]$</span> <span class="cmd">curl -s http://localhost | head -5</span></div>
    <div><span class="out">&lt;!DOCTYPE html&gt; ... CSA Unit 3 — EC2 Web Application</span></div>
  </div>
</main>

<footer>
  <div>CSA Unit 3 — EC2 Web Application &nbsp;|&nbsp; <span>Saif Pathan</span></div>
  <div>Served by <span>Nginx</span> on <span>Amazon EC2</span> &nbsp;|&nbsp; Region: <span>ap-southeast-2</span></div>
  <div id="ts"></div>
</footer>
<script>
  document.getElementById('ts').textContent = new Date().toLocaleString('en-AU',{hour12:false});
</script>
</body>
</html>
HTMLEOF

# 5. Set correct permissions
chown -R nginx:nginx /usr/share/nginx/html
chmod 644 /usr/share/nginx/html/index.html

# 6. Configure Nginx security headers
cat > /etc/nginx/conf.d/security.conf << 'NGINXEOF'
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
server_tokens off;
NGINXEOF

# 7. Reload Nginx to apply security headers
systemctl reload nginx

echo "[$(date)] Unit 3 web server bootstrap complete."
echo "[$(date)] Nginx is running and serving the CSA Unit 3 web application."
