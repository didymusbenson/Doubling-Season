// Temporary, main-owned publisher policy. Never load this module from phone source.
const PHONE_BRANCH = 'feature/phone-mode';
const VALIDATION_PATH = '.github/workflows/tablet-build.yml';
const PUBLISHER_PATH = '.github/workflows/deploy.yml';

function owned(run, repository) {
  return run?.repository?.full_name === repository &&
    run?.head_repository?.full_name === repository;
}

function trustedPublisher(run, repository) {
  return owned(run, repository) && run.status === 'completed' &&
    run.conclusion === 'success' && run.head_branch === 'main' &&
    ['workflow_dispatch', 'workflow_run'].includes(run.event) &&
    run.path === PUBLISHER_PATH;
}

async function automaticSource({github, context, core}) {
  const skip = reason => { core.info(`Phone preview skipped: ${reason}`); return ''; };
  const event = context.payload.workflow_run;
  const {owner, repo} = context.repo;
  const repository = `${owner}/${repo}`;
  if (context.eventName !== 'workflow_run' || !event ||
      !owned(event, repository) || event.head_branch !== PHONE_BRANCH ||
      event.name !== 'Tablet app validation' || event.status !== 'completed' ||
      event.conclusion !== 'success' || !/^[a-f0-9]{40}$/.test(event.head_sha)) {
    return skip('not a successful owned phone validation');
  }
  const run = (await github.rest.actions.getWorkflowRun({owner, repo, run_id: event.id})).data;
  if (!owned(run, repository) || run.path !== VALIDATION_PATH ||
      run.name !== event.name || run.head_branch !== PHONE_BRANCH ||
      !['pull_request', 'workflow_dispatch'].includes(run.event) ||
      run.status !== 'completed' || run.conclusion !== 'success' ||
      run.head_sha !== event.head_sha || run.run_attempt !== event.run_attempt) {
    return skip('validation provenance or attempt changed');
  }
  const latest = (await github.rest.actions.listWorkflowRuns({owner, repo,
    workflow_id: 'tablet-build.yml', branch: PHONE_BRANCH, per_page: 1})).data.workflow_runs[0];
  if (!latest || latest.id !== run.id || latest.run_attempt !== run.run_attempt) {
    return skip('a newer validation supersedes this completion');
  }
  const head = (await github.rest.repos.getBranch({owner, repo, branch: PHONE_BRANCH})).data.commit.sha;
  if (head !== run.head_sha) return skip('branch moved beyond the validated commit');
  return run.head_sha;
}

module.exports = {automaticSource, trustedPublisher};
