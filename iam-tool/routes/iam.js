const express = require('express');
const router  = express.Router();
const {
  IAMClient,
  ListGroupsCommand,
  GetGroupCommand,
  ListAttachedGroupPoliciesCommand,
  ListUsersCommand,
  GetUserCommand,
  ListMFADevicesCommand,
  ListGroupsForUserCommand,
  CreateGroupCommand,
  DeleteGroupCommand,
  CreateUserCommand,
  DeleteUserCommand,
  AddUserToGroupCommand,
  RemoveUserFromGroupCommand,
  AttachGroupPolicyCommand,
  DetachGroupPolicyCommand,
  ListPoliciesCommand,
  GetPolicyCommand,
  GetPolicyVersionCommand,
  GenerateCredentialReportCommand,
  GetCredentialReportCommand,
  GetAccountSummaryCommand,
  GetAccountPasswordPolicyCommand,
  UpdateAccountPasswordPolicyCommand,
  CreateLoginProfileCommand,
  ListRolesCommand,
  GetRoleCommand,
  ListAttachedRolePoliciesCommand,
  ListInstanceProfilesCommand,
} = require('@aws-sdk/client-iam');

const client = new IAMClient({
  region: process.env.AWS_REGION || 'ap-southeast-2',
});

// ── helpers ──────────────────────────────────────────────────────────────────
function wrap(fn) {
  return async (req, res) => {
    try {
      const result = await fn(req);
      res.json({ ok: true, data: result });
    } catch (err) {
      console.error('[IAM]', err.message);
      res.status(500).json({ ok: false, error: err.message, code: err.name });
    }
  };
}

// ── GROUPS ───────────────────────────────────────────────────────────────────
router.get('/groups', wrap(async () => {
  const { Groups } = await client.send(new ListGroupsCommand({}));
  const detailed = await Promise.all(Groups.map(async g => {
    const { Users } = await client.send(new GetGroupCommand({ GroupName: g.GroupName }));
    const { AttachedPolicies } = await client.send(
      new ListAttachedGroupPoliciesCommand({ GroupName: g.GroupName })
    );
    return { ...g, Users, AttachedPolicies };
  }));
  return detailed;
}));

router.post('/groups', wrap(async (req) => {
  const { GroupName, Path } = req.body;
  const { Group } = await client.send(new CreateGroupCommand({ GroupName, Path: Path || '/' }));
  return Group;
}));

router.delete('/groups/:name', wrap(async (req) => {
  await client.send(new DeleteGroupCommand({ GroupName: req.params.name }));
  return { deleted: req.params.name };
}));

router.get('/groups/:name/policies', wrap(async (req) => {
  const { AttachedPolicies } = await client.send(
    new ListAttachedGroupPoliciesCommand({ GroupName: req.params.name })
  );
  return AttachedPolicies;
}));

router.post('/groups/:name/attach-policy', wrap(async (req) => {
  const { PolicyArn } = req.body;
  await client.send(new AttachGroupPolicyCommand({ GroupName: req.params.name, PolicyArn }));
  return { attached: PolicyArn };
}));

router.post('/groups/:name/detach-policy', wrap(async (req) => {
  const { PolicyArn } = req.body;
  await client.send(new DetachGroupPolicyCommand({ GroupName: req.params.name, PolicyArn }));
  return { detached: PolicyArn };
}));

// ── USERS ────────────────────────────────────────────────────────────────────
router.get('/users', wrap(async () => {
  const { Users } = await client.send(new ListUsersCommand({}));
  const detailed = await Promise.all(Users.map(async u => {
    const [mfaRes, groupRes] = await Promise.all([
      client.send(new ListMFADevicesCommand({ UserName: u.UserName })),
      client.send(new ListGroupsForUserCommand({ UserName: u.UserName })),
    ]);
    return {
      ...u,
      MFADevices: mfaRes.MFADevices,
      MFAEnabled: mfaRes.MFADevices.length > 0,
      Groups: groupRes.Groups,
    };
  }));
  return detailed;
}));

router.post('/users', wrap(async (req) => {
  const { UserName, Path, Tags } = req.body;
  const { User } = await client.send(new CreateUserCommand({ UserName, Path: Path || '/', Tags }));
  return User;
}));

router.delete('/users/:name', wrap(async (req) => {
  await client.send(new DeleteUserCommand({ UserName: req.params.name }));
  return { deleted: req.params.name };
}));

router.post('/users/:name/add-to-group', wrap(async (req) => {
  const { GroupName } = req.body;
  await client.send(new AddUserToGroupCommand({ UserName: req.params.name, GroupName }));
  return { added: req.params.name, group: GroupName };
}));

router.post('/users/:name/remove-from-group', wrap(async (req) => {
  const { GroupName } = req.body;
  await client.send(new RemoveUserFromGroupCommand({ UserName: req.params.name, GroupName }));
  return { removed: req.params.name, group: GroupName };
}));

router.post('/users/:name/create-login', wrap(async (req) => {
  const { Password, PasswordResetRequired } = req.body;
  await client.send(new CreateLoginProfileCommand({
    UserName: req.params.name,
    Password,
    PasswordResetRequired: PasswordResetRequired !== false,
  }));
  return { created: req.params.name };
}));

router.get('/users/:name/mfa', wrap(async (req) => {
  const { MFADevices } = await client.send(
    new ListMFADevicesCommand({ UserName: req.params.name })
  );
  return { UserName: req.params.name, MFADevices, MFAEnabled: MFADevices.length > 0 };
}));

// ── POLICIES ─────────────────────────────────────────────────────────────────
router.get('/policies', wrap(async (req) => {
  const scope = req.query.scope || 'Local';
  const { Policies } = await client.send(new ListPoliciesCommand({ Scope: scope }));
  return Policies;
}));

router.get('/policies/:arn', wrap(async (req) => {
  const arn = decodeURIComponent(req.params.arn);
  const { Policy } = await client.send(new GetPolicyCommand({ PolicyArn: arn }));
  const { PolicyVersion } = await client.send(new GetPolicyVersionCommand({
    PolicyArn: arn,
    VersionId: Policy.DefaultVersionId,
  }));
  return {
    ...Policy,
    Document: JSON.parse(decodeURIComponent(PolicyVersion.Document)),
  };
}));

// ── ROLES ────────────────────────────────────────────────────────────────────
router.get('/roles', wrap(async () => {
  const { Roles } = await client.send(new ListRolesCommand({}));
  return Roles;
}));

router.get('/roles/:name', wrap(async (req) => {
  const { Role } = await client.send(new GetRoleCommand({ RoleName: req.params.name }));
  const { AttachedPolicies } = await client.send(
    new ListAttachedRolePoliciesCommand({ RoleName: req.params.name })
  );
  return { ...Role, AttachedPolicies };
}));

router.get('/instance-profiles', wrap(async () => {
  const { InstanceProfiles } = await client.send(new ListInstanceProfilesCommand({}));
  return InstanceProfiles;
}));

// ── ACCOUNT ──────────────────────────────────────────────────────────────────
router.get('/account-summary', wrap(async () => {
  const { SummaryMap } = await client.send(new GetAccountSummaryCommand({}));
  return SummaryMap;
}));

router.get('/password-policy', wrap(async () => {
  const { PasswordPolicy } = await client.send(new GetAccountPasswordPolicyCommand({}));
  return PasswordPolicy;
}));

router.put('/password-policy', wrap(async (req) => {
  await client.send(new UpdateAccountPasswordPolicyCommand(req.body));
  return { updated: true };
}));

// ── CREDENTIAL REPORT ────────────────────────────────────────────────────────
router.get('/credential-report', wrap(async () => {
  // Generate first (may take a few seconds on first call)
  try {
    await client.send(new GenerateCredentialReportCommand({}));
  } catch (_) { /* already generated */ }

  await new Promise(r => setTimeout(r, 2000));

  const { Content } = await client.send(new GetCredentialReportCommand({}));
  const csv = Buffer.from(Content).toString('utf-8');
  const lines = csv.trim().split('\n');
  const headers = lines[0].split(',');
  const rows = lines.slice(1).map(line => {
    const vals = line.split(',');
    return Object.fromEntries(headers.map((h, i) => [h, vals[i]]));
  });
  return rows;
}));

module.exports = router;
