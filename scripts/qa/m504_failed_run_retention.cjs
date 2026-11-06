'use strict';

// M504: conservative, audited cleanup of redundant FAILED PR run records.
// It never handles main/push/successful/active, artifact-bearing or unmerged PR runs.
const DAY_MS = 24 * 60 * 60 * 1000;
const RETENTION_MS = 7 * DAY_MS;
const MAX_DELETE = 20;
const MAX_PAGES = 8;
const PER_PAGE = 100;
const REPOSITORY = 'MahmoudMAnwar/waffra-app';

// Protect production evidence regardless of event or branch.
const RELEASE_CRITICAL = /\b(?:main|apk|aab|release|publish|deployment|deploy|production|sqlcipher|signing|signed|security|migration|backup|physical|restore|cutover|m103|m147|m160|m174|m340|m449)\b/i;

function associatedPr(run) {
  const links = run.pull_requests;
  if (!Array.isArray(links) || links.length !== 1) return null;
  const id = links[0]?.number;
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

function eligibleFailure(run, nowMs, repository, currentRunId) {
  if (!run || run.status !== 'completed' || run.conclusion !== 'failure') return false;
  if (run.event !== 'pull_request' || run.head_branch === 'main' || !run.head_branch) return false;
  if (run.head_repository?.full_name !== repository) return false; // no forks or unknown source
  if (run.id === currentRunId || !Number.isSafeInteger(run.id) || run.id < 1) return false;
  if (!Number.isSafeInteger(run.workflow_id) || run.workflow_id < 1) return false;
  if (RELEASE_CRITICAL.test(run.name || '')) return false;
  const timestamp = Date.parse(run.created_at || '');
  if (!Number.isFinite(timestamp) || timestamp >= nowMs - RETENTION_MS || timestamp > nowMs) return false;
  return associatedPr(run) !== null;
}

function newerSuccessfulEvidence(failure, successes) {
  const number = associatedPr(failure);
  const failureTime = Date.parse(failure.created_at || '');
  return number !== null && Number.isFinite(failureTime) && successes.some(run =>
    run.status === 'completed' && run.conclusion === 'success' &&
    run.workflow_id === failure.workflow_id &&
    run.head_branch === failure.head_branch &&
    run.event === 'pull_request' &&
    run.head_repository?.full_name === failure.head_repository?.full_name &&
    (run.pull_requests || []).some(pr => pr.number === number) &&
    Date.parse(run.created_at || '') > failureTime
  );
}

async function cleanup({ github, context, core, dryRun, nowMs = Date.now() }) {
  const { owner, repo } = context.repo;
  if (`${owner}/${repo}` !== REPOSITORY || context.ref !== 'refs/heads/main' ||
      !['schedule', 'workflow_dispatch'].includes(context.eventName)) {
    throw new Error('M504 is only permitted for trusted main schedule/manual runs in Waffra');
  }
  const cutoffDay = new Date(nowMs - RETENTION_MS).toISOString().slice(0, 10);
  const prCache = new Map();
  const successCache = new Map();
  const seen = new Set();
  const counts = {
    scanned: 0, eligible: 0, newerPass: 0,
    withArtifacts: 0, protected: 0, deleted: 0, previewed: 0,
  };
  const reference = `${owner}/${repo}`;

  for (let page = 1; page <= MAX_PAGES; page++) {
    const response = await github.rest.actions.listWorkflowRunsForRepo({
      owner, repo, status: 'failure', event: 'pull_request',
      created: `..${cutoffDay}`, page, per_page: PER_PAGE,
    });
    const runs = response.data.workflow_runs || [];
    for (const run of runs) {
      counts.scanned++;
      if (seen.has(run.id) || !eligibleFailure(run, nowMs, reference, context.runId)) {
        counts.protected++;
        continue;
      }
      seen.add(run.id);
      const prNumber = associatedPr(run);
      if (!prCache.has(prNumber)) {
        const pr = await github.rest.pulls.get({owner, repo, pull_number: prNumber});
        prCache.set(prNumber, pr.data);
      }
      const pr = prCache.get(prNumber);
      if (pr.state !== 'closed' || !pr.merged_at || pr.base?.ref !== 'main' ||
          pr.head?.repo?.full_name !== reference) {
        counts.protected++;
        continue;
      }
      counts.eligible++;
      const key = `${run.workflow_id}:${run.head_branch}`;
      if (!successCache.has(key)) {
        // Two bounded pages only. Missing successful evidence means preserve.
        const found = [];
        for (let successPage = 1; successPage <= 2; successPage++) {
          const ok = await github.rest.actions.listWorkflowRuns({
            owner, repo, workflow_id: run.workflow_id,
            branch: run.head_branch, event: 'pull_request', status: 'success',
            page: successPage, per_page: PER_PAGE,
          });
          const batch = ok.data.workflow_runs || [];
          found.push(...batch);
          if (batch.length < PER_PAGE) break;
        }
        successCache.set(key, found);
      }
      if (!newerSuccessfulEvidence(run, successCache.get(key))) continue;
      counts.newerPass++;
      const artifacts = await github.rest.actions.listWorkflowRunArtifacts({
        owner, repo, run_id: run.id, per_page: 1,
      });
      // Missing/unknown artifact data is NOT proof of zero artifacts.
      if (!Number.isInteger(artifacts.data.total_count) || artifacts.data.total_count !== 0) {
        counts.withArtifacts++;
        continue;
      }
      // Recheck immediately before deletion to protect unexpected state changes.
      const current = await github.rest.actions.getWorkflowRun({
        owner, repo, run_id: run.id,
      });
      if (!eligibleFailure(current.data, nowMs, reference, context.runId) ||
          current.data.head_sha !== run.head_sha ||
          associatedPr(current.data) !== prNumber) {
        counts.protected++;
        continue;
      }
      const label = `run ${run.id} (${run.name}) from merged PR #${prNumber}`;
      if (dryRun) {
        counts.previewed++;
        core.info(`M504 DRY RUN: would delete ${label}`);
      } else {
        await github.rest.actions.deleteWorkflowRun({owner, repo, run_id: run.id});
        counts.deleted++;
        core.info(`M504 deleted ${label}`);
      }
      if (counts.deleted + counts.previewed >= MAX_DELETE) break;
    }
    if (runs.length < PER_PAGE || counts.deleted + counts.previewed >= MAX_DELETE) break;
  }
  const mode = dryRun ? 'DRY RUN (no deletions)' : 'AUTOMATIC WEEKLY CLEANUP';
  core.info(`M504 ${mode}: ${JSON.stringify(counts)}`);
  await core.summary.addHeading(`M504 failed PR run retention — ${mode}`)
    .addRaw(`7-day retention; merged PR + newer passing same workflow required. ` +
      `Main/release/security/artifact runs preserved. ` +
      `Scanned ${counts.scanned}; candidates with newer pass ${counts.newerPass}; ` +
      `artifact-bearing preserved ${counts.withArtifacts}; ` +
      `deleted ${counts.deleted}; previewed ${counts.previewed}.`)
    .write();
  return counts;
}

module.exports = {cleanup, associatedPr, eligibleFailure, newerSuccessfulEvidence,
  RETENTION_MS, MAX_DELETE, RELEASE_CRITICAL};
