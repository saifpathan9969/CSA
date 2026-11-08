require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');

const iamRoutes = require('./routes/iam');
const s3Routes  = require('./routes/s3');
const stsRoutes = require('./routes/sts');
const ec2Routes = require('./routes/ec2');
const kmsRoutes = require('./routes/kms');
const auditRoutes = require('./routes/audit');

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Static frontend
app.use(express.static(path.join(__dirname, 'public')));

// API routes
app.use('/api/iam',   iamRoutes);
app.use('/api/s3',    s3Routes);
app.use('/api/sts',   stsRoutes);
app.use('/api/ec2',   ec2Routes);
app.use('/api/kms',   kmsRoutes);
app.use('/api/audit', auditRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', region: process.env.AWS_REGION, ts: new Date().toISOString() });
});

// Catch-all → frontend
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`\n  ██████╗███████╗ █████╗     ██╗ █████╗ ███╗   ███╗`);
  console.log(`  ██╔════╝██╔════╝██╔══██╗    ██║██╔══██╗████╗ ████║`);
  console.log(`  ██║     ███████╗███████║    ██║███████║██╔████╔██║`);
  console.log(`  ██║     ╚════██║██╔══██║    ██║██╔══██║██║╚██╔╝██║`);
  console.log(`  ╚██████╗███████║██║  ██║    ██║██║  ██║██║ ╚═╝ ██║`);
  console.log(`   ╚═════╝╚══════╝╚═╝  ╚═╝    ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝`);
  console.log(`\n  IAM Control Center running on http://localhost:${PORT}`);
  console.log(`  Region: ${process.env.AWS_REGION}  Profile: ${process.env.AWS_PROFILE || 'default'}\n`);
});
