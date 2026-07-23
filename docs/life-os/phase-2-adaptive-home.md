# Phase II — Unified Adaptive Home

> **Classification: Implementation handoff.** Current Home product/UX behavior is canonical in [Adaptive Home](../product/HOME.md); completion status is owned by the [remaining execution ledger](../todos/LIFEBOARD_5_REMAINING_EXECUTION_LEDGER.md).

## Outcome

Phase II is implemented as an additive, independently promotable set of product trains. It replaces the internal Home experience with one adaptive dashboard while keeping the legacy Home available as a rollback path.

The implementation includes:

- One persisted layout shared by Smart, Work, Personal, and Low Energy modes.
- Semantic widget sizing, transactional customization, gallery, reset, hide/show, reorder, and configuration contracts.
- Auto plus expiring manual Morning/Afternoon/Evening/Night selection.
- Orientation, Focus Now, life snapshot, contextual care, capacity, capture, timeline, progress, and reflection widgets.
- Screenshot-calibrated atmospheric composition and clay surfaces with static/ambient/enhanced policy backends.
- Track overview, generic trackers, mood/energy, medication state, neutral fasting, and HealthKit steps/active-energy reads.
- Journal mood art and interaction identity, text/photo/protected audio, optional transcription, voice search, library, filters, starring, deterministic insights, weekly reflection, and privacy-safe Spotlight metadata.
- Structured Notes spaces, nested folders, block editor, tags, favorites, pinning, links/backlinks, file attachments, search, and a derived 150-node graph.
- Universal capture routing to task, habit, tracker, Journal, and Note providers when their train is enabled.

## Runtime architecture

### Home

- `AdaptiveHomeStore` owns loaded layout, edit draft, mode context, and widget state.
- `HomeProjectionAdapter` snapshots the existing Home/task/habit/calendar state before it reaches SwiftUI.
- `DefaultDashboardWidgetRegistry` defines singleton rules, supported sizes, categories, defaults, and mode adapters.
- `DeterministicSmartHomePolicy` resolves Focus Now without network, HealthKit, CloudKit, media, or Eva dependencies.
- `HomeLayoutDraft` makes edit sessions transactional: Done persists; Cancel discards.
- `CoreDataDashboardLayoutRepository` stores value envelopes and preserves unknown widget kinds.
- `DaypartOverrideController` calculates the next natural boundary and safely recalculates after clock, DST, or time-zone changes.

The default narrative order is locked:

1. Orientation and daypart environment.
2. Focus Now / One small thing.
3. Mood, energy, and essential life snapshot.
4. Contextual habits and medication.
5. Schedule, available window, and capacity.
6. Quick capture.
7. Compact timeline/day shape.
8. Progress and reflection.

### Track, Journal, and Notes

- `LifeBoardPhaseIIRepository` is the actor-safe value contract for all new domains.
- `CoreDataLifeBoardPhaseIIRepository` performs background-context reads/writes and relationship mapping.
- `LifeBoardHealthService` queries same-day steps and active energy directly from HealthKit and does not duplicate raw samples.
- `LifeBoardTrackStore`, `LifeBoardJournalStore`, and `LifeBoardKnowledgeStore` keep feature state focused rather than extending a global app store.
- Journal audio uses complete file protection and device-local paths. Only metadata and an optional user-approved transcription enter private sync records.
- Knowledge graph positions are derived and local; manual synced node coordinates are intentionally absent.

## Persistence and migration chain

The current version is `TaskModelV3_KnowledgeNotes`.

```text
TaskModelV3_TaskIcons
  → TaskModelV3_LifeOSFoundation
  → TaskModelV3_AdaptiveHome
  → TaskModelV3_Trackers
  → TaskModelV3_Journal
  → TaskModelV3_KnowledgeNotes
```

Additive ownership:

| Version | Additions |
|---|---|
| LifeOSFoundation | Dashboard layouts and placements |
| AdaptiveHome | Shared-layout compatibility/migration evolution |
| Trackers | Tracker definitions/entries, mood-energy, medications/schedules/events, fasting sessions |
| Journal | Journal days, blocks, media metadata; local derived index and drafts |
| KnowledgeNotes | Spaces, folders, notes, blocks, tags, tag links, note links, attachments; local graph positions |

CloudSync holds user-authored private records. LocalOnly holds drafts, derivatives, indexes, caches, graph positions, and other rebuildable/device-specific data. Existing per-mode layouts are preserved as dormant compatibility data during shared-layout migration.

## Privacy boundaries

- HealthKit read permission is requested contextually from a Health-backed surface.
- Missing or denied Health data renders a neutral setup/unavailable state, never a fabricated zero.
- Medication status never infers a missed dose; an elapsed unresolved window remains `Unresolved` and is excluded from adherence.
- Fasting is a neutral user-defined timer without metabolic claims, recommendations, or plan catalogs.
- Journal excerpts on Home remain opt-in.
- Notes expose title/location by default; excerpts are per-widget opt-in.
- Sensitive values must remain redacted from notifications, widgets, Spotlight bodies, App Intents responses, lock-screen surfaces, and app-switcher snapshots.
- Spotlight Journal records contain only safe date/mood metadata, not entry prose or audio.

Apple platform behavior follows the official [HealthKit privacy guidance](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) and [HealthKit Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/healthkit).

## Design implementation

- Morning and afternoon authored values match the approved screenshots; evening and night extend the same warm-paper system.
- The dashboard uses broad celestial shapes, shallow tactile cards, embedded metric wells, and one floating action hierarchy.
- Functional text uses system typography; the brand display face is reserved for selective hero moments.
- Calm, Balanced, and Playful change depth/motion only—not content, meaning, or semantic colors.
- Rendering policy yields to Reduce Motion, Reduce Transparency, Low Power Mode, thermal pressure, accessibility, inactive scenes, and unsupported hardware.
- Namespaced Journal mood assets live under `LifeBoardJournal/Moods`; there is no external app runtime dependency or user-data import.

## Test and review status

Completed locally:

- [x] Build all app sources for generic iOS Simulator.
- [x] Launch Adaptive Home with no Debug launch arguments.
- [x] Migrate every bundled source model to Knowledge Notes with stable IDs intact.
- [x] Round-trip shared layout and unknown widgets.
- [x] Round-trip Tracker, Journal, and Note values against the compiled current model.
- [x] Validate daypart boundaries, manual expiry, restoration, deep-link fallback, and capture arbitration.
- [x] Validate authored palette values and WCAG functional-surface contrast.
- [x] Validate static rendering policy under accessibility/energy constraints.
- [x] Validate Journal assets, deterministic insights, evidence IDs, and medication adherence semantics.
- [x] Run dependency/foundation and token-law guards.

External/manual release gates:

- [ ] Signed real-device migration with production-style data and iCloud reconciliation.
- [ ] Full iPad split-view and Catalyst keyboard/window review.
- [ ] Widget and Watch compatibility on installed production entitlements.
- [ ] HealthKit permission transitions on physical hardware.
- [ ] Audio interruption, route-change, transcription-unavailable, storage-pressure, and protected-file tests.
- [ ] Founder two-second orientation/next-action suite at standard and accessibility sizes.
- [ ] Target-user usability validation; the founder proxy is not user evidence.
- [ ] Matched-device launch, mode-switch, capture, hitch, memory, energy, and thermal reports.

## Rollback behavior

- Debug: pass `-LIFEBOARD_DISABLE_ADAPTIVE_HOME_V2` or the relevant train-specific disable argument.
- Release: do not promote the staged flag.
- Disabling UI never rolls back or deletes an additive schema.
- Legacy Home remains available for one promoted release window.
- Unknown layouts and unavailable providers remain preserved rather than rewritten.
