const express = require('express');
const path    = require('path');
const app     = express();
const PORT    = 4000;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ── Simulated EC2 deployment state ────────────────────────────────────────────
let deployState = {
  status: 'idle',   // idle | deploying | running | stopped | terminated
  steps: [],
  instance: null,
};

function resetState() {
  deployState = { status: 'idle', steps: [], instance: null };
}

// ── API: get current state ─────────────────────────────────────────────────────
app.get('/api/state', (req, res) => res.json(deployState));

// ── API: deploy (simulates terraform apply) ────────────────────────────────────
app.post('/api/deploy', (req, res) => {
  resetState();
  deployState.status = 'deploying';
  const { ip, keyName, instanceType } = req.body;

  const steps = [
    { id: 1, name: 'terraform init',                    duration: 800  },
    { id: 2, name: 'Creating VPC (10.3.0.0/16)',        duration: 900  },
    { id: 3, name: 'Creating Internet Gateway',          duration: 600  },
    { id: 4, name: 'Creating Public Subnet',             duration: 500  },
    { id: 5, name: `Creating Security Group (SSH→${ip||'0.0.0.0'}/32, HTTP→0.0.0.0/0)`, duration: 700 },
    { id: 6, name: `Uploading Key Pair: ${keyName||'csa-unit3-key'}`, duration: 400  },
    { id: 7, name: `Launching EC2 ${instanceType||'t3.micro'} (Amazon Linux 2023)`, duration: 2000 },
    { id: 8, name: 'Allocating Elastic IP',              duration: 600  },
    { id: 9, name: 'Running bootstrap: dnf update + Nginx install', duration: 1800 },
    { id: 10, name: 'Deploying web application HTML',    duration: 500  },
    { id: 11, name: 'Apply complete — 9 resources created', duration: 300 },
  ];

  deployState.steps = steps.map(s => ({ ...s, status: 'pending', log: '' }));
  deployState.instance = null;

  // Simulate step-by-step progress
  let delay = 0;
  steps.forEach((step, i) => {
    delay += step.duration;
    setTimeout(() => {
      deployState.steps[i].status = 'running';
    }, delay - step.duration);
    setTimeout(() => {
      deployState.steps[i].status = 'done';
      deployState.steps[i].log = getStepLog(step.id, ip, keyName, instanceType);
      if (i === steps.length - 1) {
        deployState.status = 'running';
        deployState.instance = {
          id:           'i-0a3f7c8d9e2b1f456',
          type:         instanceType || 't3.micro',
          ami:          'al2023-ami-20241121.0-kernel-6.1-x86_64',
          state:        'running',
          publicIp:     '13.236.84.52',
          privateIp:    '10.3.1.142',
          region:       'ap-southeast-2',
          az:           'ap-southeast-2a',
          keyName:      keyName || 'csa-unit3-key',
          sg:           'sg-0f1e2d3c4b5a6987',
          vpcId:        'vpc-0abc123def456789',
          subnetId:     'subnet-0def234abc567890',
          launchTime:   new Date().toISOString(),
          webUrl:       'http://13.236.84.52',
          sshCommand:   `ssh -i ~/.ssh/${keyName||'csa-unit3-key'} ec2-user@13.236.84.52`,
          volumeSize:   20,
          volumeType:   'gp3',
          encrypted:    true,
          imdsv2:       true,
        };
      }
    }, delay);
  });

  res.json({ ok: true, message: 'Deployment started' });
});

// ── API: instance actions ──────────────────────────────────────────────────────
app.post('/api/instance/:action', (req, res) => {
  const { action } = req.params;
  if (!deployState.instance) return res.status(400).json({ ok: false, error: 'No instance' });

  if (action === 'stop') {
    deployState.instance.state = 'stopped';
    deployState.status = 'stopped';
  } else if (action === 'start') {
    deployState.instance.state = 'running';
    deployState.status = 'running';
  } else if (action === 'terminate') {
    deployState.instance.state = 'terminated';
    deployState.status = 'terminated';
    deployState.instance = null;
  } else if (action === 'reboot') {
    deployState.instance.state = 'rebooting';
    setTimeout(() => {
      if (deployState.instance) deployState.instance.state = 'running';
    }, 2000);
  }
  res.json({ ok: true, state: deployState.status });
});

// ── API: reset ─────────────────────────────────────────────────────────────────
app.post('/api/reset', (req, res) => {
  resetState();
  res.json({ ok: true });
});

// ── API: security group rules ──────────────────────────────────────────────────
app.get('/api/security-group', (req, res) => {
  const ip = req.query.ip || '0.0.0.0';
  res.json({
    groupId: 'sg-0f1e2d3c4b5a6987',
    groupName: 'csa-unit3-webserver-sg',
    vpcId: 'vpc-0abc123def456789',
    inbound: [
      { type: 'SSH',   protocol: 'TCP', port: '22',  source: `${ip}/32`,  desc: 'SSH – operator IP only', secure: true  },
      { type: 'HTTP',  protocol: 'TCP', port: '80',  source: '0.0.0.0/0', desc: 'HTTP – public web',      secure: true  },
      { type: 'HTTPS', protocol: 'TCP', port: '443', source: '0.0.0.0/0', desc: 'HTTPS – public web',     secure: true  },
    ],
    outbound: [
      { type: 'All traffic', protocol: 'All', port: 'All', source: '0.0.0.0/0', desc: 'All outbound', secure: true },
    ],
  });
});

// ── API: nginx status ──────────────────────────────────────────────────────────
app.get('/api/nginx', (req, res) => {
  if (deployState.status !== 'running') {
    return res.json({ running: false });
  }
  res.json({
    running: true,
    version: 'nginx/1.24.0',
    status: 'active (running)',
    enabled: true,
    pid: 3422,
    workers: 1,
    uptime: '4 minutes',
    headers: {
      'Server':               'nginx',
      'X-Frame-Options':      'SAMEORIGIN',
      'X-Content-Type-Options':'nosniff',
      'X-XSS-Protection':     '1; mode=block',
      'Referrer-Policy':      'strict-origin-when-cross-origin',
    },
    configFile: '/etc/nginx/conf.d/security.conf',
    docRoot: '/usr/share/nginx/html/',
    accessLog: '/var/log/nginx/access.log',
  });
});

app.listen(PORT, () => {
  console.log(`\n  CSA Unit 3 – EC2 Deployment Tool`);
  console.log(`  Running on http://localhost:${PORT}\n`);
});

// ── Log helpers ────────────────────────────────────────────────────────────────
function getStepLog(id, ip, key, type) {
  const logs = {
    1:  'Provider hashicorp/aws v5.78.0 installed. Backend initialized.',
    2:  'aws_vpc.main: Creation complete [id=vpc-0abc123def456789]',
    3:  'aws_internet_gateway.main: Creation complete [id=igw-0abc123def456789]',
    4:  'aws_subnet.public: Creation complete [id=subnet-0def234abc567890]',
    5:  `aws_security_group.web_server: Creation complete [id=sg-0f1e2d3c4b5a6987]`,
    6:  `aws_key_pair.web_server: Creation complete [id=${key||'csa-unit3-key'}]`,
    7:  'aws_instance.web_server: Creation complete [id=i-0a3f7c8d9e2b1f456]',
    8:  'aws_eip.web_server: Creation complete [id=eipalloc-0abc123def456789] → 13.236.84.52',
    9:  'Bootstrap: nginx-1.24.0-1.amzn2023.x86_64 installed.',
    10: 'index.html deployed to /usr/share/nginx/html/ (5842 bytes)',
    11: 'Apply complete! 9 added, 0 changed, 0 destroyed.',
  };
  return logs[id] || '';
}
