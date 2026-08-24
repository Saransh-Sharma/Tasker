# EVA Decision Loops implementation

**Classification:** Canonical implementation and product contract  
**Status:** Implemented and enabled by default in Debug and Release; Cloud publication pending  
**Last verified:** 25 August 2026  
**Scope:** Make It Fit Today, Friction Detective, and Weekly Reset with EVA

## Product arc

The three rituals form one learning loop:

1. **Make It Fit Today** turns an overloaded day into an explicit, realistic commitment.
2. **Friction Detective** helps the user name why selected work repeatedly slips and try one changed condition.
3. **Weekly Reset with EVA** closes the week without judgment and prepares a capacity-aware starting shape for the next one.

They are native planning and reflection surfaces, not chat transcripts. Deterministic LifeBoard repositories establish facts; EVA may explain or propose but cannot override capacity, record identity, consent, or mutation authority.

## Shared contract

- Each ritual has explicit evidence, choice, preview, apply, receipt, degraded, and recoverable-failure states.
- `EvaRitualDraftReference` persists only ritual kind, record identifiers, reference date, phase, user choices, and optional action-run identity. Restored flows refetch canonical records.
- The shared ritual shell presents one factual orientation line, one main decision area, an expandable evidence drawer, a persistent action, and a receipt.
- Evidence is labeled as **Observed**, **Possible explanation**, **Chosen by you**, or **Will change**.
- Local services remain authoritative. Cloud EVA is optional and no new cloud route was introduced.
- Journal text is not admitted by these rituals automatically. Friction custom prose is stored in a linked `ReflectionNote`; the structured `FrictionFinding` contains no sensitive free text and is local-only.
- Each successful mutation has a deterministic inverse. Partial and stale applications fail explicitly rather than implying success.

The independent presentation gates are:

| Feature | Runtime flag | Default |
|---|---|---|
| Make It Fit Today | `feature.eva.make_it_fit_today_v1` / signed `evaMakeItFitTodayV1Enabled` | On |
| Friction Detective | `feature.eva.friction_detective_v1` / signed `evaFrictionDetectiveV1Enabled` | On |
| Weekly Reset | `feature.eva.weekly_reset_v1` / signed `evaWeeklyResetV1Enabled` | On |

Both gates must be true. A stored or launch-argument local override and the signed remote control can independently suppress a surface. Turning either off removes the presentation only; canonical reviews, action receipts, and local findings remain readable and deletable. Legacy signed documents without these three keys decode them as enabled so an older compatible policy does not unexpectedly hide local rituals.

## Make It Fit Today

### Experience

The ritual opens from Plan's day-capacity surface. It first states usable time, known planned work, overload, and estimate uncertainty. Fixed calendar commitments are shown as immovable; flexible task slips can remain today, move to tomorrow, or return to Later, Someday, or Inbox. One focus-ranked anchor is protected unless the user explicitly chooses another.

Tasks without estimates remain in an unknown-size state and never count as free work. The preview lists every destination change and confirms that deadlines and external calendar events are untouched. Apply uses one batch receipt, reports partial failure precisely, and supports Undo.

### Authority

- `CommitmentRealismEngine` wraps the canonical `CapacityBudgetService`; it does not define another capacity formula.
- The local budget decides whether the day is overloaded. The model's `isOvercommitted` field is advisory only.
- `DailyBriefOutput` now preserves fixed commitments, next move, tradeoff, evidence task identifiers, and the model's overload advisory.
- Confirmation revalidates tasks and the day snapshot. A stale preview is rebuilt before any write.

## Friction Detective

### Experience

Task Detail exposes Friction Detective manually and highlights it after three distinct friction events. The first screen shows only verifiable history. If dated receipts are unavailable, the ritual says “Replanned N times” rather than inventing a timeline.

EVA may offer up to three explicitly tentative explanations. Only the user's selected reason is durable. The user then chooses one experiment: clarify the next action, split or reduce the work, change its planning window, return it to Later/Someday, or record a dependency. The receipt says, “We changed the conditions, not your score,” offers Undo, and schedules a seven-day review for Weekly Reset without creating a notification.

### Authority and persistence

- `FrictionEvidenceIndex` uses unique action receipts when available and otherwise `max(deferredCount, replanCount)`, preventing one defer from being counted twice.
- `FrictionFinding` stores evidence references, the user-confirmed reason, intervention, counters, optional linked note ID, optional action-run ID, review date, and outcome.
- The `TaskModelV3_EvaDecisionLoops` migration adds `FrictionFinding` to the `LocalOnly` configuration with repository, write-closed adapter, bootstrap validation, and deletion support.
- Undo restores the original task or removes the created split step, then removes the finding and its optional linked reflection note.
- Findings are not part of cloud context by default. EVA hypotheses are never saved as memory.

## Weekly Reset with EVA

### Experience

The reset replaces the legacy review presentation when its flag is enabled and unfolds in three chapters:

1. **What held** — completed or advanced work and user-authored wins.
2. **What created drag** — unfinished outcomes, carry-over, over-capacity days, and unresolved friction findings.
3. **Shape next week** — one intention, up to three outcomes, a minimum viable week, and a protected commitment.

Sparse weeks use prompts instead of empty charts. The user may open the canonical weekly planning workspace to edit the proposal.

### Two independent commits

1. **Finish review** saves reflection, outcome status, lessons, and recorded task dispositions using `WeeklyReviewMutationMode.recordOnly`.
2. **Apply next-week proposal** refetches the affected tasks, shows the diff, applies the plan, and provides Undo.

A proposal failure cannot erase a completed review. Dispositions now have distinct semantics:

| Choice | Destination |
|---|---|
| Carry forward | Next-week planning intake |
| Move later | Later |
| Release from the plan | Someday |

The persisted legacy `.drop` value remains decodable but is displayed as Release and maps to Someday. Archive and delete remain separate destructive actions outside Weekly Reset.

## Accessibility and motion

The ritual shell and feature controls use semantic text labels, non-color state descriptions, Dynamic Type-compatible scrolling, minimum touch targets, VoiceOver evidence/diff descriptions, and restrained haptics. Reduce Motion replaces the signature ribbon/knot transitions with state changes and crossfades. No ritual uses streak loss, failure scoring, laziness, or productivity-grade language.

## Verification baseline

Verified on the iOS 26.5 simulator on 25 August 2026:

- Focused Debug feature-flag and decision-loop tests pass, and the complete Release simulator app build succeeds.
- EVA decision-loop tests pass for unknown estimates, distinct friction counting, sparse-history uncertainty, Carry/Later/Release semantics, IDs-only restoration, and local Friction Finding persistence.
- The Core Data migration chain preserves oldest-version data and can infer mappings to the current model.
- The current model is `TaskModelV3_EvaDecisionLoops`; `FrictionFinding` is reachable through the `LocalOnly` store.

Worker type-check, all 71 Worker tests, all 18 shared-contract checks, versioned-policy schema tests, and Release compilation pass. Simulator qualification is not physical-device production qualification. The production policy is prepared for 100%, but publication is blocked until the dedicated DeviceCheck secrets exist in both Cloudflare environments and staging smoke passes.

## Rollout

1. Keep all three local ritual presentations on by default while preserving their independent local and signed kill switches.
2. After DeviceCheck provisioning and staging verification, publish the requested 100% production cloud policy and immediately verify rollback, privacy, auth, accounting, schema, and authority signals.
3. Collect content-free phase, proposal-shape, latency, apply/reject/undo, stale-preview, and failure-code telemetry.
4. Review the production-enabled, not-graduated release after seven days; graduate each ritual independently only when its outcome and trust measures support it.
5. Permit governed overload or repeated-friction suggestions only after manual behavior is reliable, under the existing confidence, quiet-hour, dormancy, and two-per-day limits.
