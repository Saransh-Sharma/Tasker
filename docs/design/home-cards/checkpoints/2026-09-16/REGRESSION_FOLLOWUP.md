# Artwork regression follow-up — 16 September 2026

## Status

- [x] Freeze current sources and preserve concurrent changes.
- [x] Create an isolated artwork-removal control with a recorded transformation.
- [x] Recheck watch platform availability.
- [ ] Finish seven-method current rerun: first attempt stopped before tests because disk filled.
- [ ] Run the same methods against the isolated control.
- [ ] Classify supported outcomes without expanding the failure baseline.

Current rerun uses iPhone 17 Pro `A3ABF0F1-98A9-4D82-A075-9F9C560D66D3`, iOS 26.5, and `build/DerivedData/HomeCardRegressionFollowup`. The separate comparison tree is `/tmp/lifeboard-artwork-control-20260916`.

## Comparison design

The [snapshot manifest](regression-followup/snapshot-manifest.json) records 2,594 copied files and HEAD `30afaec8`. The [control transformation](regression-followup/control-transform.json) identifies exactly which artwork-only implementation files are restored and which artwork-added source/assets are removed. Other concurrent application, onboarding, EVA, localization, project, and test edits are retained. Documentation-only artwork output directories are omitted from the copy because they are not build inputs for these seven tests.

The control preserves all mixed project changes except lines naming the removed artwork Swift files. In particular it preserves the `XCLocalSwiftPackageReference "."` display comment. Its origin cannot be established from the mixed dirty diff alone; a persistent widget source-contract failure in this control does not by itself establish that this comment change predates the artwork work.

## First execution attempt

The current seven-method `xcodebuild test` exited **73** before any selected test ran. The log reports `No space left on device` during MLX compilation and cannot save a complete xcresult. This is an environment failure, not a test result. The attempted result path is `build/test-results/HomeCardRegressionFollowup-current-20260916.xcresult`; it must not be used as passing/failing test evidence.

A concurrent watch build attempt exited **74** during package checkout for the same storage error. Both newly created derived-data directories were removed after their processes exited, restoring approximately 1.2 GiB of free space. Existing shared build outputs, source changes, the comparison snapshot, and result artifacts were preserved. Reuse of already-built dependencies must be coordinated before another test build.

[Relevant source hashes](regression-followup/relevant-source-comparison.json) establish source identity only. All seven original failures remain unclassified until a valid comparison test run completes.

## Platform gate

The fresh [watch destinations probe](regression-followup/watch-destinations.log) still reports watchOS 26.5 is not installed and offers no eligible destination. SDK presence alone does not establish an available watch build platform. The gate remains blocked; no all-target membership success is claimed.

## Evidence

- [Discovered schemes](regression-followup/schemes.json)
- [Current build/test log](regression-followup/current-xcodebuild.log)
- [Installed SDKs](regression-followup/installed-sdks.log)
- [Simulator runtimes](regression-followup/simulator-runtimes.json)

No shared validation document, application source, test source, or baseline is changed by this follow-up.
