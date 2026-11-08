const express = require('express');
const router  = express.Router();
const {
  KMSClient,
  ListKeysCommand,
  DescribeKeyCommand,
  ListAliasesCommand,
  GetKeyRotationStatusCommand,
  GetKeyPolicyCommand,
  EnableKeyRotationCommand,
  DisableKeyCommand,
  EnableKeyCommand,
} = require('@aws-sdk/client-kms');

const client = new KMSClient({ region: process.env.AWS_REGION || 'ap-southeast-2' });

function wrap(fn) {
  return async (req, res) => {
    try {
      res.json({ ok: true, data: await fn(req) });
    } catch (err) {
      console.error('[KMS]', err.message);
      res.status(500).json({ ok: false, error: err.message, code: err.name });
    }
  };
}

// List keys with full metadata
router.get('/keys', wrap(async () => {
  const { Keys = [] } = await client.send(new ListKeysCommand({}));
  const { Aliases = [] } = await client.send(new ListAliasesCommand({}));

  const aliasMap = {};
  Aliases.forEach(a => {
    if (a.TargetKeyId) aliasMap[a.TargetKeyId] = a.AliasName;
  });

  const detailed = await Promise.all(Keys.map(async k => {
    const results = {};
    await Promise.allSettled([
      client.send(new DescribeKeyCommand({ KeyId: k.KeyId }))
        .then(r => { results.meta = r.KeyMetadata; }),
      client.send(new GetKeyRotationStatusCommand({ KeyId: k.KeyId }))
        .then(r => { results.rotationEnabled = r.KeyRotationEnabled; })
        .catch(() => { results.rotationEnabled = null; }),
    ]);
    return {
      KeyId:   k.KeyId,
      KeyArn:  k.KeyArn,
      Alias:   aliasMap[k.KeyId] || null,
      ...results.meta,
      RotationEnabled: results.rotationEnabled,
    };
  }));

  // Filter out AWS-managed keys (optional: include them for visibility)
  return detailed;
}));

router.get('/keys/:id/policy', wrap(async (req) => {
  const { Policy } = await client.send(
    new GetKeyPolicyCommand({ KeyId: req.params.id, PolicyName: 'default' })
  );
  return JSON.parse(Policy);
}));

router.post('/keys/:id/enable-rotation', wrap(async (req) => {
  await client.send(new EnableKeyRotationCommand({ KeyId: req.params.id }));
  return { rotationEnabled: true, keyId: req.params.id };
}));

router.post('/keys/:id/enable', wrap(async (req) => {
  await client.send(new EnableKeyCommand({ KeyId: req.params.id }));
  return { enabled: req.params.id };
}));

router.post('/keys/:id/disable', wrap(async (req) => {
  await client.send(new DisableKeyCommand({ KeyId: req.params.id }));
  return { disabled: req.params.id };
}));

module.exports = router;
