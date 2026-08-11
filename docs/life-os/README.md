# LifeOS Implementation and Verification Hub

> Classification: Canonical implementation and verification index
> Audience: Product, design, engineering, QA, privacy, and release teams
> Capability status: Current workspace with dated evidence boundaries
> Source authority: Current runtime/persistence and the completion ledger
> Last verified: 2026-08-11

This package explains how the current LifeOS source fits together and what has actually been verified. User behavior belongs in the [Product Handbook](../product/README.md), day-to-day operation in the [User Manual](../guides/README.md), and unimplemented direction in the [Future Blueprint](../product/LIFEOS_FUTURE_BLUEPRINT.md).

## Current references

- [Unified Completion Status](./LIFEBOARD_UNIFIED_COMPLETION_STATUS.md): sole active implementation/evidence ledger.
- [Unified Implementation Guide](./LIFEBOARD_UNIFIED_IMPLEMENTATION_GUIDE.md): architecture, persistence ownership, rollback, privacy, failure, and extension rules.
- [Manual Test Playbook](./manual-testing.md): end-to-end user scenarios and device-only evidence.
- [Current Architecture](../architecture/LIFEBOARD_V2_ARCHITECTURE_GUIDE.md): package/module/runtime boundaries.
- [Feature Catalog](../product/FEATURE_CATALOG.md): exhaustive current capability and route coverage.
- [DESIGN.md](../../DESIGN.md): normative visual, motion, and accessibility contract.

Historical phase documents, Daily Loop handoffs, completion audits, and the former roadmap were removed after their live decisions and open gates were consolidated into these references.

## Current implementation shape

LifeBoard has one five-root shell, typed navigation, one Universal Capture router, canonical domain repositories, Adaptive Home projections, Plan/This Week/Focus, Track domains, protected Journal/Knowledge, Insights, EVA proposal/receipt boundaries, and redacted system surfaces. Retained promoted flags are data-preserving rollback boundaries; they must never create alternative stores.

The root package manifest declares nine products: Contracts, Tokens, UI, Domain, Persistence, Calendar, Transcription, KnowledgeFeature, and JournalFeature. The app target still owns substantial feature composition; extracted boundaries are only those declared by the manifest.

## Non-negotiable invariants

- Root or feature projections never become a second source of truth.
- Managed objects do not cross repository, actor, route, extension, or Watch boundaries.
- Fixed external calendar events are read-only context.
- Journal, health, biometrics, secure notes, semantic chunks, and protected reflection are `privateSensitive`.
- External surfaces receive versioned, atomic, redacted projections and stable commands.
- EVA may explain and propose; consequential mutations require explicit review and canonical validation.
- One applied batch has one receipt and one supported Undo path.
- Empty, zero, unavailable, denied, locked, stale, partial, and error states remain distinct.
- Feature rollback hides presentation without deleting canonical records.

## Verification policy

Run the baseline-aware suite, repository guardrails, relevant package/app/extension builds, documentation guardrail, and `git diff --check`. Record exact commands, date, environment, counts, failures, and skips in the status ledger. A historical pass is not fresh evidence for an uncommitted workspace.

Signed-device notifications, haptics, biometrics, protected-data transitions, Health, EventKit delivery, microphone/camera, Live Activities, App Groups, CloudKit accounts, Watch pairing, accessibility hardware, and performance remain external gates unless they were actually observed in the current run.
