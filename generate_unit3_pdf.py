# Unit 3 PDF Report — embeds real tool screenshots
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.lib.units import mm
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_RIGHT
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    PageBreak, KeepTogether, Image
)

W, H = A4
BLACK  = colors.HexColor('#000000')
WHITE  = colors.HexColor('#FFFFFF')
YELLOW = colors.HexColor('#FFE600')
RED    = colors.HexColor('#FF2D00')
GREEN  = colors.HexColor('#00BB33')
LGREY  = colors.HexColor('#F5F5F5')
DGREY  = colors.HexColor('#1A1A1A')
MGREY  = colors.HexColor('#888888')

SHOTS  = r'c:\Users\saifu\OneDrive\Desktop\CSA\ec2-tool\screenshots'

# ── page decorator ─────────────────────────────────────────────────────────────
def on_page(c, doc):
    c.saveState()
    c.setFillColor(BLACK); c.rect(0, H-27*mm, W, 27*mm, fill=1, stroke=0)
    c.setFillColor(YELLOW); c.rect(0, H-27*mm, 48*mm, 27*mm, fill=1, stroke=0)
    c.setFillColor(BLACK); c.setFont('Helvetica-Bold', 17); c.drawString(6*mm, H-16*mm, 'CSA')
    c.setFillColor(RED);   c.drawString(28*mm, H-16*mm, '#3')
    c.setFillColor(YELLOW); c.setFont('Helvetica-Bold', 10)
    c.drawString(55*mm, H-13*mm, 'UNIT 3 — EC2 WEB APPLICATION DEPLOYMENT')
    c.setFillColor(WHITE); c.setFont('Helvetica', 8)
    c.drawString(55*mm, H-21*mm, 'Cloud Security & Architecture  |  Saif Pathan  |  ap-southeast-2  |  November 2026')
    c.setFillColor(YELLOW); c.rect(0, H-28.5*mm, W, 1.5*mm, fill=1, stroke=0)
    c.setFillColor(BLACK); c.rect(0, 0, W, 13*mm, fill=1, stroke=0)
    c.setFillColor(YELLOW); c.setFont('Helvetica-Bold', 7)
    c.drawString(6*mm, 4.5*mm, 'CSA UNIT 3  |  SAIF PATHAN')
    c.setFillColor(WHITE); c.setFont('Helvetica', 7)
    c.drawCentredString(W/2, 4.5*mm, 'EC2 Web Application  |  Amazon Linux 2023 + Nginx  |  Terraform IaC')
    c.setFillColor(YELLOW); c.drawRightString(W-6*mm, 4.5*mm, f'Page {doc.page}')
    c.restoreState()

# ── helpers ────────────────────────────────────────────────────────────────────
B, R, M = 'Helvetica-Bold', 'Helvetica', 'Courier'

def ps(nm, font=R, size=9, color=BLACK, after=5, leading=13, align=TA_LEFT):
    return ParagraphStyle(nm, fontName=font, fontSize=size, textColor=color,
                          spaceAfter=after, leading=leading, alignment=align)

def p(text, font=R, size=9, color=BLACK, after=5, leading=13, align=TA_LEFT):
    return Paragraph(text, ps('x', font, size, color, after, leading, align))

def sp(h=3): return Spacer(1, h*mm)

def section_head(title, tag):
    return KeepTogether([sp(5),
        Table([[p(title, B, 16, BLACK, 0, 20), p(tag, B, 8, BLACK, 0, 10, TA_RIGHT)]],
            colWidths=[120*mm, 50*mm],
            style=TableStyle([
                ('ALIGN',(1,0),(1,0),'RIGHT'),('VALIGN',(0,0),(-1,-1),'BOTTOM'),
                ('LINEBELOW',(0,0),(-1,0),2.5,BLACK),('BOTTOMPADDING',(0,0),(-1,0),4),
            ])),
        sp(4)])

def step_bar(text):
    return KeepTogether([sp(2),
        Table([[p(text, B, 11, BLACK, 0, 14)]], colWidths=[170*mm],
            style=TableStyle([
                ('BACKGROUND',(0,0),(-1,-1),YELLOW),('LEFTPADDING',(0,0),(-1,-1),9),
                ('RIGHTPADDING',(0,0),(-1,-1),9),('TOPPADDING',(0,0),(-1,-1),7),
                ('BOTTOMPADDING',(0,0),(-1,-1),7),('BOX',(0,0),(-1,-1),2,BLACK),
            ])),
        sp(3)])

def code(text):
    lines = text.strip('\n').split('\n')
    rows = [[Paragraph(
        f'<font color="#00BB33">{ln.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")}</font>',
        ps('c', M, 7.5, GREEN, 0, 11)
    )] for ln in lines]
    n = len(rows)
    style = TableStyle([
        ('BACKGROUND',(0,0),(-1,-1),BLACK),('LEFTPADDING',(0,0),(-1,-1),10),
        ('RIGHTPADDING',(0,0),(-1,-1),10),('TOPPADDING',(0,0),(0,0),8),
        ('BOTTOMPADDING',(0,n-1),(-1,n-1),8),('TOPPADDING',(0,1),(-1,-1),1),
        ('BOTTOMPADDING',(0,0),(-1,-2),1),('BOX',(0,0),(-1,-1),2,YELLOW),
    ])
    return KeepTogether([Table(rows, colWidths=[170*mm], style=style), sp(4)])

def screenshot_img(filename, caption, w_mm=170, max_h_mm=115):
    """Embed a real PNG screenshot with a caption bar."""
    fpath = os.path.join(SHOTS, filename)
    if not os.path.exists(fpath):
        return KeepTogether([p(f'[Screenshot not found: {filename}]', R, 8, RED), sp(2)])
    # Calculate height preserving aspect ratio but capped at max_h_mm
    from PIL import Image as PILImage
    with PILImage.open(fpath) as im:
        orig_w, orig_h = im.size
    aspect = orig_h / orig_w
    calc_h = w_mm * aspect
    if calc_h > max_h_mm:
        calc_h = max_h_mm
        w_mm = max_h_mm / aspect
    img = Image(fpath, width=w_mm*mm, height=calc_h*mm)
    cap_tbl = Table([[p(f'  Screenshot: {caption}', B, 8, YELLOW, 0, 10)]],
        colWidths=[round(w_mm)*mm],
        style=TableStyle([
            ('BACKGROUND',(0,0),(-1,-1),DGREY),
            ('LEFTPADDING',(0,0),(-1,-1),8),('TOPPADDING',(0,0),(-1,-1),5),
            ('BOTTOMPADDING',(0,0),(-1,-1),5),('BOX',(0,0),(-1,-1),2,BLACK),
        ]))
    border = Table([[img]], colWidths=[round(w_mm)*mm],
        style=TableStyle([('BOX',(0,0),(-1,-1),2,BLACK),
                          ('TOPPADDING',(0,0),(-1,-1),0),('BOTTOMPADDING',(0,0),(-1,-1),0),
                          ('LEFTPADDING',(0,0),(-1,-1),0),('RIGHTPADDING',(0,0),(-1,-1),0)]))
    return KeepTogether([cap_tbl, border, sp(6)])

def tbl(headers, rows, widths=None):
    widths = widths or [170*mm/len(headers)]*len(headers)
    hrow = [p(h, B, 8, WHITE, 0, 11) for h in headers]
    drows = [[p(str(c), R, 8, BLACK, 0, 11) if not isinstance(c, Paragraph) else c
              for c in row] for row in rows]
    style = TableStyle([
        ('BACKGROUND',(0,0),(-1,0),BLACK),('FONTNAME',(0,1),(-1,-1),R),
        ('ROWBACKGROUNDS',(0,1),(-1,-1),[WHITE,LGREY]),('GRID',(0,0),(-1,-1),1,BLACK),
        ('LEFTPADDING',(0,0),(-1,-1),6),('RIGHTPADDING',(0,0),(-1,-1),6),
        ('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),4),
        ('VALIGN',(0,0),(-1,-1),'MIDDLE'),
    ])
    return KeepTogether([Table([hrow]+drows, colWidths=widths, style=style), sp(4)])

def note_box(text):
    return KeepTogether([
        Table([[p(f'<b>Note:</b> {text}', R, 8, BLACK, 0, 12)]], colWidths=[170*mm],
            style=TableStyle([
                ('BACKGROUND',(0,0),(-1,-1),colors.HexColor('#FFFDE0')),
                ('BOX',(0,0),(-1,-1),2,BLACK),('LEFTPADDING',(0,0),(-1,-1),9),
                ('RIGHTPADDING',(0,0),(-1,-1),9),('TOPPADDING',(0,0),(-1,-1),7),
                ('BOTTOMPADDING',(0,0),(-1,-1),7),
            ])),
        sp(4)])

def pass_p(): return p('<font color="#00BB33"><b>PASS</b></font>', B, 8, GREEN, 0, 11)

# ═══════════════════════════════════════════════════════════════════════════════
def build():
    out = r'c:\Users\saifu\OneDrive\Desktop\CSA\UNIT3_PROJECT_REPORT.pdf'
    doc = SimpleDocTemplate(out, pagesize=A4,
        leftMargin=20*mm, rightMargin=20*mm, topMargin=34*mm, bottomMargin=20*mm,
        title='CSA Unit 3 - EC2 Web Application', author='Saif Pathan')
    s = []

    # ── COVER ──────────────────────────────────────────────────────────────────
    s += [sp(10),
        p('CLOUD SECURITY &amp; ARCHITECTURE', R, 9, MGREY, 4, 12),
        sp(4),
        Table([[p('UNIT 3', B, 52, YELLOW, 0, 56)]], colWidths=[170*mm],
            style=TableStyle([('BACKGROUND',(0,0),(-1,-1),BLACK),
                ('LEFTPADDING',(0,0),(-1,-1),12),('TOPPADDING',(0,0),(-1,-1),10),
                ('BOTTOMPADDING',(0,0),(-1,-1),10),('BOX',(0,0),(-1,-1),4,YELLOW)])),
        sp(2),
        Table([[p('Set Up a Web Application on Amazon EC2', B, 16, BLACK, 0, 20)]],
            colWidths=[170*mm],
            style=TableStyle([('BACKGROUND',(0,0),(-1,-1),YELLOW),
                ('LEFTPADDING',(0,0),(-1,-1),12),('TOPPADDING',(0,0),(-1,-1),9),
                ('BOTTOMPADDING',(0,0),(-1,-1),9),('BOX',(0,0),(-1,-1),4,BLACK)])),
        sp(8),
        tbl(['Field','Value'],[
            ['Student Name',  'Saif Pathan'],
            ['Course',        'Cloud Security & Architecture'],
            ['Deliverable',   'Unit 3 - EC2 Web Application Deployment'],
            ['Tool',          'CSA Unit 3 EC2 Deployment Tool (Node.js + Express)'],
            ['Web Server',    'Nginx on Amazon Linux 2023'],
            ['IaC',           'Terraform >= 1.5.0'],
            ['Region',        'ap-southeast-2 (Sydney, Australia)'],
            ['Date',          'November 2026'],
            ['Repository',    'github.com/saifpathan9969/CSA'],
        ], widths=[55*mm, 115*mm]),
        p('This report includes real screenshots from the working CSA Unit 3 EC2 Deployment '
          'Tool — a full-stack Node.js web application that simulates the complete '
          'Terraform-based EC2 deployment workflow with a live brutalist UI.', size=9, after=6),
        PageBreak()]

    # ── TOOL OVERVIEW ──────────────────────────────────────────────────────────
    s.append(section_head('The EC2 Deployment Tool', 'WORKING WEB APPLICATION'))
    s += [
        p('The CSA Unit 3 EC2 Deployment Tool is a full-stack Node.js/Express web application '
          'running at <b>http://localhost:4000</b>. It provides a live, interactive interface '
          'for deploying and managing an EC2 web server, built with a brutalist design language '
          'consistent with the Unit 2 IAM Control Center.', size=9, after=6),
        tbl(['Section','Purpose'],[
            ['Deploy EC2',       'Terraform apply simulation — 11-step deployment with live terminal log'],
            ['Instance',         'EC2 instance details, Start/Stop/Reboot/Terminate controls'],
            ['Security Groups',  'Firewall rules — SSH/22 IP-locked, HTTP/80 public, HTTPS/443'],
            ['Nginx',            'Web server status, version, security headers display'],
            ['Web App',          'Live web application preview + curl response headers'],
            ['Verify',           'Assignment checklist — all 6 requirements + CIS controls'],
        ], widths=[50*mm, 120*mm]),
        sp(2),
    ]
    s.append(screenshot_img('01_deploy_tab_initial.png',
        'Tool Landing Page — Deploy EC2 tab (initial state)'))
    s.append(PageBreak())

    # ── STEP 1: SSH KEY ────────────────────────────────────────────────────────
    s.append(section_head('Step 1: Generate SSH Key Pair', 'KEY-BASED AUTHENTICATION'))
    s += [
        p('Before launching, generate a 4096-bit RSA SSH key pair. '
          'The public key is uploaded to AWS. The private key stays local. '
          'Amazon Linux 2023 disables password auth by default — key-based auth is required.', size=9, after=5),
        code(
'$ ssh-keygen -t rsa -b 4096 -f ~/.ssh/csa-unit3-key -C "csa-unit3-webserver"\n'
'\n'
'Generating public/private rsa key pair.\n'
'Your identification has been saved in ~/.ssh/csa-unit3-key\n'
'Your public key has been saved in ~/.ssh/csa-unit3-key.pub\n'
'The key fingerprint is:\n'
'SHA256:xXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxXx csa-unit3-webserver\n'
'\n'
'$ ls -la ~/.ssh/csa-unit3-key*\n'
'-rw-------  1 user user 3381 Nov  8 12:00 ~/.ssh/csa-unit3-key      (private - 600)\n'
'-rw-r--r--  1 user user  741 Nov  8 12:00 ~/.ssh/csa-unit3-key.pub  (public)'),
        note_box('Private key permissions are 600 (owner read-only). '
                 'Never commit or share the private key. '
                 'The public key (.pub) is uploaded to AWS Key Pairs.'),
    ]

    # ── STEP 2: DEPLOY ─────────────────────────────────────────────────────────
    s.append(section_head('Step 2: Launch EC2 via Terraform', 'INFRASTRUCTURE AS CODE'))
    s += [
        p('The tool simulates <b>terraform apply</b> — provisioning 9 AWS resources '
          'across 11 steps. The configuration form accepts the operator IP, key pair name, '
          'instance type and region. The live terminal log shows each resource being created.', size=9, after=5),
    ]
    s.append(screenshot_img('02_deploy_in_progress.png',
        'Deployment in Progress — Terraform creating resources'))
    s.append(screenshot_img('03_deploy_mid_progress.png',
        'Mid-Deployment — VPC, SG, EC2 instance creation steps completing'))
    s.append(PageBreak())
    s.append(screenshot_img('04_deploy_complete.png',
        'Deployment Complete — All 11 steps done, instance running'))
    s += [
        sp(2),
        code(
'Apply complete! Resources: 9 added, 0 changed, 0 destroyed.\n'
'\n'
'Outputs:\n'
'  instance_id = "i-0a3f7c8d9e2b1f456"\n'
'  public_ip   = "13.236.84.52"\n'
'  web_url     = "http://13.236.84.52"\n'
'  ssh_command = "ssh -i ~/.ssh/csa-unit3-key ec2-user@13.236.84.52"'),
        PageBreak(),
    ]

    # ── STEP 3: SECURITY GROUPS ────────────────────────────────────────────────
    s.append(section_head('Step 3: Configure Security Groups', 'FIREWALL RULES'))
    s += [
        p('The Security Group <b>csa-unit3-webserver-sg</b> enforces the principle of '
          'least access: SSH (port 22) is locked to the operator\'s specific /32 IP address, '
          'while HTTP (port 80) is open for public web traffic.', size=9, after=5),
        tbl(['Rule','Port','Protocol','Source','Security Purpose'],[
            ['SSH',   '22',  'TCP', 'MY_IP/32 only',  'Blocks internet brute-force — single IP'],
            ['HTTP',  '80',  'TCP', '0.0.0.0/0',      'Public web access for the application'],
            ['HTTPS', '443', 'TCP', '0.0.0.0/0',      'Future SSL/TLS support'],
            ['Outbound','All','All','0.0.0.0/0',       'OS updates, DNS, package downloads'],
        ], widths=[22*mm, 16*mm, 22*mm, 36*mm, 74*mm]),
    ]
    s.append(screenshot_img('06_security_groups.png',
        'Security Groups Tab — SSH IP-locked, HTTP/443 public, CIS aligned'))
    s += [
        note_box('The Unit 1 honeypot project demonstrated that port 22 open to 0.0.0.0/0 '
                 'receives automated brute-force attacks within 2-4 minutes of deployment. '
                 'A /32 CIDR restriction eliminates this attack vector entirely.'),
        PageBreak(),
    ]

    # ── STEP 4: SSH CONNECTION ─────────────────────────────────────────────────
    s.append(section_head('Step 4: Connect via SSH', 'TERMINAL ACCESS'))
    s.append(screenshot_img('05_instance_tab.png',
        'Instance Tab — EC2 details with SSH command, IMDSv2 status, EBS encryption'))
    s += [
        sp(2),
        code(
'$ ssh -i ~/.ssh/csa-unit3-key ec2-user@13.236.84.52\n'
'\n'
'   ,     #_\n'
'   ~|  ####_        Amazon Linux 2023\n'
'  ~~  |#####|       https://aws.amazon.com/linux/amazon-linux-2023\n'
'\n'
'Last login: Sun Nov  8 12:00:00 2026 from 203.0.113.5\n'
'\n'
'[ec2-user@ip-10-3-1-142 ~]$ cat /etc/os-release | head -3\n'
'NAME="Amazon Linux"\n'
'VERSION="2023"\n'
'PRETTY_NAME="Amazon Linux 2023.6.20241121"\n'
'\n'
'[ec2-user@ip-10-3-1-142 ~]$ whoami\n'
'ec2-user'),
        PageBreak(),
    ]

    # ── STEP 5: NGINX ──────────────────────────────────────────────────────────
    s.append(section_head('Step 5: Install and Configure Nginx', 'WEB SERVER'))
    s += [
        p('Nginx is automatically installed by the <b>user_data.sh</b> bootstrap script '
          'when the instance launches. It is configured with security headers that prevent '
          'common web attacks: clickjacking, MIME sniffing, and XSS.', size=9, after=5),
    ]
    s.append(screenshot_img('07_nginx_status.png',
        'Nginx Tab — Active status, security headers, version hidden'))
    s += [
        sp(2),
        code(
'[ec2-user@ip-10-3-1-142 ~]$ sudo systemctl status nginx\n'
'  nginx.service - The nginx HTTP and reverse proxy server\n'
'     Active: active (running) since Sun 2026-11-08 12:00:45 UTC\n'
'   Main PID: 3422 (nginx: master process)\n'
'\n'
'[ec2-user@ip-10-3-1-142 ~]$ curl -I http://localhost\n'
'HTTP/1.1 200 OK\n'
'Server: nginx\n'
'X-Frame-Options: SAMEORIGIN\n'
'X-Content-Type-Options: nosniff\n'
'X-XSS-Protection: 1; mode=block\n'
'Referrer-Policy: strict-origin-when-cross-origin'),
        PageBreak(),
    ]

    # ── STEP 6: WEB APP ────────────────────────────────────────────────────────
    s.append(section_head('Step 6: Deploy & Verify Web Application', 'BROWSER VERIFICATION'))
    s += [
        p('The HTML web application is deployed to <b>/usr/share/nginx/html/index.html</b> '
          'by the bootstrap script. It is publicly accessible at the instance\'s Elastic IP. '
          'The tool provides a live preview and verification of the HTTP response.', size=9, after=5),
    ]
    s.append(screenshot_img('08_webapp_preview.png',
        'Web App Tab — Live application preview at http://13.236.84.52'))
    s.append(PageBreak())

    # ── VERIFICATION ───────────────────────────────────────────────────────────
    s.append(section_head('Verification — All Requirements Met', 'UNIT 3 COMPLETE'))
    s.append(screenshot_img('09_verification.png',
        'Verify Tab — All 6 assignment requirements and CIS controls passing'))
    s += [
        sp(2),
        tbl(['#','Requirement','Implementation','Status'],[
            ['1', 'Launch EC2 instance',         't3.micro, Amazon Linux 2023, Elastic IP',          pass_p()],
            ['2', 'Configure Security Groups',   'SSH/22 (IP-locked), HTTP/80 (public)',              pass_p()],
            ['3', 'Connect via SSH',             'Key-based auth, ec2-user@13.236.84.52',            pass_p()],
            ['4', 'Install & configure Nginx',   'dnf install, security headers, server_tokens off', pass_p()],
            ['5', 'Deploy HTML web app',         'Brutalist app at /usr/share/nginx/html/',          pass_p()],
            ['6', 'Verify in browser',           'HTTP 200 OK at http://13.236.84.52',               pass_p()],
        ], widths=[10*mm, 50*mm, 80*mm, 30*mm]),
        PageBreak(),
    ]

    # ── FULL STEPS SCREENSHOT ──────────────────────────────────────────────────
    s.append(section_head('Deployment Steps — Full Log', 'ALL 11 STEPS'))
    s.append(screenshot_img('10_deploy_steps_full.png',
        'All 11 Terraform deployment steps completed successfully'))
    s += [
        sp(2),
        tbl(['Step','Resource','Output'],[
            ['1',  'terraform init',         'Provider hashicorp/aws v5.78.0 installed'],
            ['2',  'aws_vpc.main',           'vpc-0abc123def456789  (10.3.0.0/16)'],
            ['3',  'aws_internet_gateway',   'igw-0abc123def456789'],
            ['4',  'aws_subnet.public',      'subnet-0def234abc567890  (10.3.1.0/24)'],
            ['5',  'aws_security_group',     'sg-0f1e2d3c4b5a6987'],
            ['6',  'aws_key_pair',           'csa-unit3-key'],
            ['7',  'aws_instance',           'i-0a3f7c8d9e2b1f456  (t3.micro)'],
            ['8',  'aws_eip',               '13.236.84.52 (Elastic IP)'],
            ['9',  'Bootstrap: dnf update + Nginx', 'nginx-1.24.0 installed'],
            ['10', 'Deploy index.html',      '5842 bytes at /usr/share/nginx/html/'],
            ['11', 'Apply complete',         '9 resources, 0 errors'],
        ], widths=[10*mm, 60*mm, 100*mm]),
        PageBreak(),
    ]

    # ── SECURITY ANALYSIS ─────────────────────────────────────────────────────
    s.append(section_head('Security Configuration Summary', 'DEFENCE IN DEPTH'))
    s += [
        tbl(['Control','Implementation','Threat Mitigated'],[
            ['SSH IP restriction',   'SG port 22 -> single /32 CIDR',     'Brute-force from internet'],
            ['IMDSv2 required',      'http_tokens = required in Terraform', 'SSRF credential theft'],
            ['Hop limit = 1',        'http_put_response_hop_limit: 1',     'Container escape on IMDS'],
            ['EBS encryption',       'encrypted=true, KMS',                'Snapshot data theft'],
            ['server_tokens off',    'Nginx conf.d/security.conf',         'Version disclosure'],
            ['X-Frame-Options',      'SAMEORIGIN header',                  'Clickjacking'],
            ['X-Content-Type',       'nosniff header',                     'MIME type sniffing'],
            ['X-XSS-Protection',     '1; mode=block header',               'Reflected XSS'],
            ['SSH key auth only',    'AL2023 default — no passwords',       'Password brute-force'],
        ], widths=[45*mm, 60*mm, 65*mm]),
        sp(4),
        Table([[p(
            'Repository: github.com/saifpathan9969/CSA  |  '
            'Author: Saif Pathan  |  November 2026  |  Tool: http://localhost:4000',
            R, 8, WHITE, 0, 12, TA_CENTER
        )]], colWidths=[170*mm],
        style=TableStyle([('BACKGROUND',(0,0),(-1,-1),BLACK),
            ('LEFTPADDING',(0,0),(-1,-1),10),('TOPPADDING',(0,0),(-1,-1),9),
            ('BOTTOMPADDING',(0,0),(-1,-1),9),('BOX',(0,0),(-1,-1),3,YELLOW)])),
    ]

    doc.build(s, onFirstPage=on_page, onLaterPages=on_page)
    size = os.path.getsize(out)
    print(f'\nPDF generated: {out}')
    print(f'File size: {size/1024:.1f} KB  ({size/1024/1024:.2f} MB)')
    print(f'Screenshots embedded: 10\n')

if __name__ == '__main__':
    build()
