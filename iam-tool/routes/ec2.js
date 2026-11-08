const express = require('express');
const router  = express.Router();
const {
  EC2Client,
  DescribeInstancesCommand,
  DescribeInstanceStatusCommand,
  StartInstancesCommand,
  StopInstancesCommand,
  RebootInstancesCommand,
  DescribeIamInstanceProfileAssociationsCommand,
} = require('@aws-sdk/client-ec2');

const client = new EC2Client({ region: process.env.AWS_REGION || 'ap-southeast-2' });

function wrap(fn) {
  return async (req, res) => {
    try {
      res.json({ ok: true, data: await fn(req) });
    } catch (err) {
      console.error('[EC2]', err.message);
      res.status(500).json({ ok: false, error: err.message, code: err.name });
    }
  };
}

// List instances with IAM profile info
router.get('/instances', wrap(async () => {
  const { Reservations = [] } = await client.send(new DescribeInstancesCommand({}));
  const instances = Reservations.flatMap(r => r.Instances.map(i => ({
    InstanceId:      i.InstanceId,
    InstanceType:    i.InstanceType,
    State:           i.State,
    PublicIpAddress: i.PublicIpAddress  || null,
    PrivateIpAddress:i.PrivateIpAddress || null,
    LaunchTime:      i.LaunchTime,
    Tags:            i.Tags || [],
    IamInstanceProfile: i.IamInstanceProfile || null,
    MetadataOptions: i.MetadataOptions || null,
    Platform:        i.Platform || 'linux',
    Name: (i.Tags || []).find(t => t.Key === 'Name')?.Value || i.InstanceId,
  })));
  return instances;
}));

// Instance status
router.get('/instances/:id/status', wrap(async (req) => {
  const { InstanceStatuses = [] } = await client.send(
    new DescribeInstanceStatusCommand({
      InstanceIds: [req.params.id],
      IncludeAllInstances: true,
    })
  );
  return InstanceStatuses[0] || { InstanceId: req.params.id, InstanceState: { Name: 'unknown' } };
}));

// Start
router.post('/instances/:id/start', wrap(async (req) => {
  const { StartingInstances } = await client.send(
    new StartInstancesCommand({ InstanceIds: [req.params.id] })
  );
  return StartingInstances[0];
}));

// Stop
router.post('/instances/:id/stop', wrap(async (req) => {
  const { StoppingInstances } = await client.send(
    new StopInstancesCommand({ InstanceIds: [req.params.id] })
  );
  return StoppingInstances[0];
}));

// Reboot
router.post('/instances/:id/reboot', wrap(async (req) => {
  await client.send(new RebootInstancesCommand({ InstanceIds: [req.params.id] }));
  return { rebooted: req.params.id };
}));

// IAM profile associations
router.get('/iam-associations', wrap(async () => {
  const { IamInstanceProfileAssociations = [] } = await client.send(
    new DescribeIamInstanceProfileAssociationsCommand({})
  );
  return IamInstanceProfileAssociations;
}));

module.exports = router;
