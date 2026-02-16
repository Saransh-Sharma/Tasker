# fn-3.4 Balanced dependency and asset pruning with verification

## Description
TBD

## Acceptance
- [ ] TBD

## Done summary
Completed balanced dependency and asset pruning with verification.

Dependency changes:
- Removed pods: Timepiece, EasyPeasy, BEMCheckBox, TinyConstraints.
- Ran `pod install` after each removal (all succeeded).
- Removed SPM product linkage for MLXFast from Tasker target.

Package/linkage remediation during verification:
- Fixed Lottie package linkage after regression by restoring project package reference and ensuring Tasker packageProductDependencies remained valid.

Asset changes:
- Deleted 17 candidate unused imagesets from Assets.xcassets.

Verification results:
- Project graph integrity: no missing refs, no duplicate frameworks, zero on-disk Swift files missing from project refs.
- `taskerctl doctor` passes.
- Build smoke gates after each dependency/asset phase showed no new early dependency errors; long MLX compile stage remains baseline constraint.
- `taskerctl test` starts but did not complete within practical window in this environment; run was terminated after prolonged compile stage.
## Evidence
- Commits:
- Tests:
- PRs: