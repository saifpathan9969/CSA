const express = require('express');
const router  = express.Router();
const {
  CloudTrailClient,
  LookupEventsCommand,
  DescribeTrailsCommand,
  GetTrailStatusCommand,
} = require('@aws-sdk/client-cloudtrail');

const client = new CloudTrailClient({ region: process.env.AWS_REGION || 'ap-southeast-2' });

function wrap(fn) {
  return async (req, res) => {
    try {
      res.json({ ok: true, data: await fn(req) });
    } catch (err) {
      console.error('[Audit]', err.message);
      res.status(500).json({ ok: false, error: err.message, code: err.name });
    }
  };
}

// Recent IAM events
router.get('/events', wrap(async (req) => {
  const hours = parseInt(req.query.hours || '24', 10);
  const startTime = new Date(Date.now() - hours * 60 * 60 * 1000);

  const { Events = [] } = await client.send(new LookupEventsCommand({
    StartTime: startTime,
    EndTime:   new Date(),
    MaxResults: 50,
    LookupAttributes: req.query.service
      ? [{ AttributeKey: 'EventSource', AttributeValue: `${req.query.service}.amazonaws.com` }]
      : [],
  }));

  return Events.map(e => ({
    EventId:     e.EventId,
    EventName:   e.EventName,
    EventSource: e.EventSource,
    EventTime:   e.EventTime,
    Username:    e.Username,
    Resources:   e.Resources || [],
    ReadOnly:    e.ReadOnly,
  }));
}));

// CloudTrail trails status
router.get('/trails', wrap(async () => {
  const { trailList = [] } = await client.send(new DescribeTrailsCommand({ includeShadowTrails: false }));

  const detailed = await Promise.all(trailList.map(async t => {
    const status = await client.send(new GetTrailStatusCommand({ Name: t.TrailARN }))
      .catch(() => ({}));
    return { ...t, Status: status };
  }));
  return detailed;
}));

module.exports = router;
