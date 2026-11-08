const express = require('express');
const router  = express.Router();
const {
  S3Client,
  ListBucketsCommand,
  GetBucketEncryptionCommand,
  GetBucketPolicyCommand,
  GetPublicAccessBlockCommand,
  GetBucketVersioningCommand,
  GetBucketLoggingCommand,
  ListObjectsV2Command,
  PutObjectCommand,
  DeleteObjectCommand,
  GetBucketLocationCommand,
} = require('@aws-sdk/client-s3');

const client = new S3Client({ region: process.env.AWS_REGION || 'ap-southeast-2' });

function wrap(fn) {
  return async (req, res) => {
    try {
      res.json({ ok: true, data: await fn(req) });
    } catch (err) {
      console.error('[S3]', err.message);
      res.status(500).json({ ok: false, error: err.message, code: err.name });
    }
  };
}

// List all buckets with security posture
router.get('/buckets', wrap(async () => {
  const { Buckets } = await client.send(new ListBucketsCommand({}));

  const enriched = await Promise.all(Buckets.map(async b => {
    const checks = {};

    await Promise.allSettled([
      client.send(new GetBucketEncryptionCommand({ Bucket: b.Name }))
        .then(r => { checks.encryption = r.ServerSideEncryptionConfiguration?.Rules?.[0] || null; })
        .catch(() => { checks.encryption = null; }),

      client.send(new GetPublicAccessBlockCommand({ Bucket: b.Name }))
        .then(r => { checks.publicAccessBlock = r.PublicAccessBlockConfiguration; })
        .catch(() => { checks.publicAccessBlock = null; }),

      client.send(new GetBucketVersioningCommand({ Bucket: b.Name }))
        .then(r => { checks.versioning = r.Status || 'Disabled'; })
        .catch(() => { checks.versioning = 'Unknown'; }),

      client.send(new GetBucketLoggingCommand({ Bucket: b.Name }))
        .then(r => { checks.logging = r.LoggingEnabled || null; })
        .catch(() => { checks.logging = null; }),

      client.send(new GetBucketLocationCommand({ Bucket: b.Name }))
        .then(r => { checks.region = r.LocationConstraint || 'us-east-1'; })
        .catch(() => { checks.region = 'unknown'; }),
    ]);

    // Posture score
    let score = 0;
    if (checks.encryption) score++;
    if (checks.publicAccessBlock?.BlockPublicAcls &&
        checks.publicAccessBlock?.BlockPublicPolicy &&
        checks.publicAccessBlock?.IgnorePublicAcls &&
        checks.publicAccessBlock?.RestrictPublicBuckets) score++;
    if (checks.versioning === 'Enabled') score++;
    if (checks.logging) score++;

    checks.postureScore = score;
    checks.postureMax   = 4;

    return { ...b, ...checks };
  }));

  return enriched;
}));

// Bucket policy
router.get('/buckets/:name/policy', wrap(async (req) => {
  const { Policy } = await client.send(
    new GetBucketPolicyCommand({ Bucket: req.params.name })
  );
  return JSON.parse(Policy);
}));

// Objects
router.get('/buckets/:name/objects', wrap(async (req) => {
  const { Contents = [], KeyCount, IsTruncated } = await client.send(
    new ListObjectsV2Command({
      Bucket: req.params.name,
      MaxKeys: 100,
      Prefix: req.query.prefix || '',
    })
  );
  return { objects: Contents, count: KeyCount, truncated: IsTruncated };
}));

// Upload object
router.post('/buckets/:name/objects', wrap(async (req) => {
  const { key, body, contentType } = req.body;
  await client.send(new PutObjectCommand({
    Bucket: req.params.name,
    Key: key,
    Body: body,
    ContentType: contentType || 'text/plain',
    ServerSideEncryption: 'aws:kms',
  }));
  return { uploaded: key };
}));

// Delete object
router.delete('/buckets/:name/objects/:key', wrap(async (req) => {
  await client.send(new DeleteObjectCommand({
    Bucket: req.params.name,
    Key: decodeURIComponent(req.params.key),
  }));
  return { deleted: req.params.key };
}));

module.exports = router;
