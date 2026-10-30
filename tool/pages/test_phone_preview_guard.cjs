const {test} = require('node:test');
const assert = require('node:assert/strict');
const {automaticSource, trustedPublisher} = require('./phone_preview_guard.cjs');

const repository = 'didymusbenson/Doubling-Season';
const sha = 'a'.repeat(40);
function fixture() {
  const run = {id: 123, run_attempt: 1, repository: {full_name: repository},
    head_repository: {full_name: repository}, head_branch: 'feature/phone-mode',
    name: 'Tablet app validation', status: 'completed', conclusion: 'success',
    path: '.github/workflows/tablet-build.yml', event: 'pull_request', head_sha: sha};
  const state = {event: structuredClone(run), run, latest: structuredClone(run), head: sha, calls: []};
  const api = async (method, args, data) => {state.calls.push([method, args]); return {data};};
  state.github = {rest: {actions: {
    getWorkflowRun: args => api('run', args, state.run),
    listWorkflowRuns: args => api('latest', args, {workflow_runs: state.latest ? [state.latest] : []}),
  }, repos: {getBranch: args => api('head', args, {commit: {sha: state.head}})}}};
  state.check = () => automaticSource({github: state.github,
    context: {eventName: state.eventName || 'workflow_run', repo: {owner: 'didymusbenson', repo: 'Doubling-Season'},
      payload: {workflow_run: state.event}}, core: {info: () => {}}});
  return state;
}

test('accepts only exact latest successful owned branch SHA', async () => {
  const f = fixture();
  assert.equal(await f.check(), sha);
  assert.equal(f.calls[1][1].workflow_id, 'tablet-build.yml');
  assert.equal(f.calls[1][1].branch, 'feature/phone-mode');
  assert.equal(f.calls[2][1].branch, 'feature/phone-mode');
});
for (const [name, change] of Object.entries({
  failure: f => f.event.conclusion = 'failure',
  cancelled: f => f.event.conclusion = 'cancelled',
  pending: f => f.event.status = 'in_progress',
  unrelatedBranch: f => f.event.head_branch = 'feature/phone-mode-other',
  unrelatedWorkflow: f => f.event.name = 'Other checks',
  fork: f => f.event.head_repository.full_name = 'outsider/Doubling-Season',
  wrongRepository: f => f.event.repository.full_name = 'outsider/Doubling-Season',
  malformedSHA: f => f.event.head_sha = 'main',
  wrongEvent: f => f.eventName = 'push',
  wrongPath: f => f.run.path = '.github/workflows/other.yml',
  untrustedSourceEvent: f => f.run.event = 'pull_request_target',
  apiFailure: f => f.run.conclusion = 'failure',
  apiFork: f => f.run.head_repository.full_name = 'outsider/Doubling-Season',
  apiWrongBranch: f => f.run.head_branch = 'main',
  changedSHA: f => f.run.head_sha = 'b'.repeat(40),
  rerunInProgress: f => f.run.run_attempt = 2,
  newerValidation: f => f.latest.id = 124,
  newerAttempt: f => f.latest.run_attempt = 2,
  noValidation: f => f.latest = null,
  staleHead: f => f.head = 'b'.repeat(40),
})) {
  test(`skips ${name}`, async () => {
    const f = fixture(); change(f);
    assert.equal(await f.check(), '');
  });
}
test('recheck refuses a branch advanced during build', async () => {
  const f = fixture();
  assert.equal(await f.check(), sha);
  f.head = 'b'.repeat(40);
  assert.equal(await f.check(), '');
});
test('API errors fail closed instead of authorizing publication', async () => {
  const f = fixture();
  f.github.rest.repos.getBranch = async () => {throw new Error('unavailable');};
  await assert.rejects(f.check(), /unavailable/);
});
test('retains successful main manual and automatic publisher artifacts only', () => {
  const run = {...fixture().run, path: '.github/workflows/deploy.yml', head_branch: 'main'};
  for (const event of ['workflow_dispatch', 'workflow_run']) {
    assert.equal(trustedPublisher({...run, event}, repository), true);
    for (const patch of [{conclusion: 'failure'}, {status: 'in_progress'},
      {head_branch: 'feature/phone-mode'}, {path: '.github/workflows/other.yml'},
      {head_repository: {full_name: 'outsider/Doubling-Season'}}]) {
      assert.equal(trustedPublisher({...run, event, ...patch}, repository), false);
    }
  }
  assert.equal(trustedPublisher({...run, event: 'push'}, repository), false);
});
