const express = require('express');
const router  = express.Router();
const { STSClient, GetCallerIdentityCommand } = require('@aws-sdk/client-sts');

const client = new STSClient({ region: process.env.AWS_REGION || 'ap-southeast-2' });

router.get('/whoami', async (req, res) => {
  try {
    const data = await client.send(new GetCallerIdentityCommand({}));
    res.json({ ok: true, data });
  } catch (err) {
    res.status(500).json({ ok: false, error: err.message, code: err.name });
  }
});

module.exports = router;
