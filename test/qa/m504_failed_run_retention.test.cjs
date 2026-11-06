'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {cleanup,eligibleFailure,newerSuccessfulEvidence, RETENTION_MS} = require('../../scripts/qa/m504_failed_run_retention.cjs');
const nowMs = Date.parse('2026-11-06T18:20:00Z');
const repository = 'MahmoudMAnwar/waffra-app';
function run(overrides={}) {
  return {
    id:101, workflow_id:11, name:'Flutter UI tests',
    status:'completed',conclusion:'failure',event:'pull_request',
    head_branch:'feature/fixed-pr', head_sha:'aaa',
    head_repository:{full_name:repository},
    pull_requests:[{number:501}],
    created_at:new Date(nowMs - 10 * 86400000).toISOString(),
    ...overrides,
  };
}
function newer(overrides={}) {
  return run({id:102,status:'completed',conclusion:'success',head_sha:'bbb',
    created_at:new Date(nowMs-8*86400000).toISOString(),...overrides});
}
function api({failed=[run()],successful=[newer()],pr={state:'closed',merged_at:'2026-11-01',base:{ref:'main'},head:{repo:{full_name:repository}}},artifacts=0}={}) {
  const deleted=[];const calls={};
  const actions={
    listWorkflowRunsForRepo:async()=>({data:{workflow_runs:failed}}),
    listWorkflowRuns:async()=>({data:{workflow_runs:successful}}),
    listWorkflowRunArtifacts:async()=>({data:{total_count:artifacts}}),
    getWorkflowRun:async({run_id})=>({data:failed.find(r=>r.id===run_id)}),
    deleteWorkflowRun:async({run_id})=>{deleted.push(run_id);},
  };
  return {github:{rest:{actions,pulls:{get:async()=>({data:pr})}}},deleted,calls};
}
const context={repo:{owner:'MahmoudMAnwar',repo:'waffra-app'},ref:'refs/heads/main',eventName:'schedule',runId:999};
const core={info:()=>{},summary:{addHeading(){return this;},addRaw(){return this;},async write(){}}};

test('never delete main, successful, active, recent, fork, or production workflows',()=>{
  const protectedRuns=[
    run({head_branch:'main'}),run({conclusion:'success'}),run({status:'in_progress'}),
    run({created_at:new Date(nowMs-RETENTION_MS+1000).toISOString()}),
    run({head_repository:{full_name:'other/repo'}}),run({name:'Build Android APK'}),
    run({event:'push'}),run({pull_requests:[]}),run({name:'M174 Main SQLCipher'}),
  ];
  for(const candidate of protectedRuns) assert.equal(eligibleFailure(candidate,nowMs,repository,999),false);
});
test('newer success must match workflow, branch, same PR, repo, time',()=>{
  assert.equal(newerSuccessfulEvidence(run(),[newer()]),true);
  for (const mismatch of [
    {workflow_id:33},{head_branch:'feature/other'},
    {pull_requests:[{number:502}]},{head_repository:{full_name:'other/repo'}},
    {created_at:new Date(nowMs-11*86400000).toISOString()},
    {conclusion:'failure'},
  ]) assert.equal(newerSuccessfulEvidence(run(),[newer(mismatch)]),false);
});
test('manual preview does not delete even if eligible and artifact-free', async()=>{
  const a=api();const x=await cleanup({github:a.github,context:{...context,eventName:'workflow_dispatch'},core,dryRun:true,nowMs});
  assert.equal(x.previewed,1);assert.equal(x.deleted,0);assert.deepEqual(a.deleted,[]);
});
test('scheduled cleanup deletes only redundant artifact-free failed run',async()=>{
  const a=api();const x=await cleanup({github:a.github,context,core,dryRun:false,nowMs});
  assert.equal(x.deleted,1);assert.deepEqual(a.deleted,[101]);
});
test('preserve open PR, unmerged PR, artifacts, and no newer same-PR success',async()=>{
  for(const opts of [
    {pr:{state:'open',merged_at:null,base:{ref:'main'},head:{repo:{full_name:repository}}}},
    {pr:{state:'closed',merged_at:null,base:{ref:'main'},head:{repo:{full_name:repository}}}},
    {artifacts:1},{successful:[newer({pull_requests:[{number:502}]})]},
  ]){
    const a=api(opts);const x=await cleanup({github:a.github,context,core,dryRun:false,nowMs});
    assert.equal(x.deleted,0);assert.deepEqual(a.deleted,[]);
  }
});
test('fail closed for untrusted branch/manual run and missing artifact evidence',async()=>{
  const a=api({artifacts:undefined});
  await assert.rejects(cleanup({github:a.github,context:{...context,ref:'refs/heads/suspicious'},core,dryRun:false,nowMs}));
  const b=api({artifacts:null});const x=await cleanup({github:b.github,context,core,dryRun:false,nowMs});
  assert.equal(x.deleted,0);
});
