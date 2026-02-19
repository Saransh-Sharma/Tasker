# CloudKit Two-Device Smoke Runbook

## Scope
- Container: `iCloud.TaskerCloudKitV2`
- Devices: two physical iOS devices signed into the same Apple ID
- Build: release-candidate commit under evaluation

## CI Tie-In

This runbook is required by:
- `.github/workflows/cloudkit-smoke.yml` (checks runbook existence)
- `scripts/validate_cloudkit_smoke_evidence.sh` (checks evidence format/content)
- `docs/release-gate-v2-efgh.md` (release block criteria)

## Preconditions
1. Both devices run the same build and can open the app.
2. CloudKit account is available and iCloud Drive is enabled.
3. Local app state is clean on both devices before starting.
4. `V2FeatureFlags.v2Enabled == true` and kill-switch defaults are unchanged.

## Test Matrix
1. Create on Device A, observe on Device B.
2. Update on Device B, observe on Device A.
3. Delete on Device A, observe tombstone-aware remove on Device B.
4. Conflict: edit same task on both devices while offline, reconnect, verify deterministic resolution.
5. Offline reconnect: queue multiple changes offline on Device B, reconnect, verify convergence.

## Scenario Steps

### 1) Create Propagation
1. Device A creates task `CK-SMOKE-01`.
2. Record creation timestamp.
3. Device B refreshes and confirms task appears with identical ID/title/priority.

### 2) Update Propagation
1. Device B updates `CK-SMOKE-01` title and due date.
2. Device A refreshes and confirms updated values and no duplicate rows.

### 3) Delete Propagation
1. Device A deletes `CK-SMOKE-01`.
2. Device B refreshes and confirms task no longer appears.
3. Confirm no local reappearance after one additional sync cycle.

### 4) Offline Conflict
1. Pick existing task `CK-SMOKE-02`.
2. Put both devices offline.
3. Device A updates `title`; Device B updates `notes`.
4. Reconnect both devices.
5. Verify converged state is deterministic and stable across repeated refreshes.

### 5) Offline Burst Replay
1. Device B offline: create 3 tasks, edit 2, delete 1.
2. Reconnect Device B.
3. Verify Device A converges to same final set with no duplicates.

## Expected Outcomes
1. No duplicate tasks for the same logical entity.
2. Deletes replicate without resurrection unless a newer update exists by policy.
3. Conflict outcomes remain stable after repeated refresh/relaunch.
4. App remains responsive and no fatal bootstrap path is triggered.

## Failure Triage

| Symptom | First Checks | Escalation Path |
| --- | --- | --- |
| Task duplicates | inspect both device timelines and IDs in evidence | log as sync mapping conflict; attach timeline and screenshots |
| Delete resurrection | verify additional sync cycle and conflict scenario history | escalate as tombstone/merge-policy regression |
| Conflict non-determinism | repeat refresh/relaunch and compare final state snapshots | escalate with exact concurrent edit timeline |
| Missing propagation | verify same build/Apple ID/container and network state | rerun scenario once; escalate with environment metadata |

## Evidence Requirements

Save evidence markdown under `docs/cloudkit-smoke-evidence/`.

Required content (validated by `scripts/validate_cloudkit_smoke_evidence.sh`):
1. build SHA
2. date
3. device metadata (model + iOS)
4. `## Test Matrix` with PASS/FAIL
5. `## Device A Timeline`
6. `## Device B Timeline`
7. `## Result` with overall PASS/FAIL
8. no placeholder tokens (`PENDING`, `REPLACE_WITH_*`)

Canonical pointer:
- `docs/cloudkit-smoke-evidence/latest.md`

## Expected Artifacts Checklist

| Artifact | Required Path |
| --- | --- |
| Smoke evidence markdown | `docs/cloudkit-smoke-evidence/latest.md` |
| Workflow run artifact upload | `cloudkit-smoke-evidence` artifact from workflow |
| Release gate cross-reference | `docs/release-gate-v2-efgh.md` |
