# LifeBoard 5.0 Product Handbook

**Classification:** Canonical product, feature, and interaction reference

**Audience:** Product, design, engineering, QA, and support

**Active status authority:** [LifeBoard Unified Completion Status](../life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md)
**Visual authority:** [DESIGN.md](../../DESIGN.md) and the [Product UI/UX Guide](../design/LIFEBOARD_PRODUCT_UI_UX_GUIDE.md)

## Product promise

LifeBoard helps a person understand the shape of their day, choose what matters, carry out work without losing context, recover when plans break, and reflect without turning life into a scorecard. It combines tasks, plans, routines, calendar reality, tracking, private reflection, and local assistance into one coherent operating loop.

The primary loop is:

`orient on Home → capture or choose → plan → focus or track → recover interruptions → reflect → adapt`

Every feature must strengthen this loop. A new surface must not create a parallel task system, silent mutation path, competing daily dashboard, or duplicate source of truth.

## Information architecture

LifeBoard has five persistent roots. Each root owns an independent typed navigation stack, so switching roots preserves context and reselecting the active root returns to its root.

| Root | User question | Primary responsibility |
|---|---|---|
| Home | “What matters now?” | Orientation, current focus, signals, timeline, recovery, and cross-domain summaries |
| Plan | “When and in what order?” | Day, Week, Backlog, capacity, scheduling, focus, repair, and review |
| Track | “What am I sustaining or learning?” | Habits, routines, goals, care, wellness, nutrition, fasting, and life moments |
| Insights | “What patterns are supported by my evidence?” | Trends, reflection, explainable observations, and saved insights |
| EVA | “Help me understand or change this safely.” | Local conversation, context, proposals, review, Apply/Edit/Not Now, receipts, and Undo |

Journal, Notes, Knowledge, Focus, Settings, and entity details are typed destinations reached from these roots or Universal Capture. They are not additional global roots.

## Handbook chapters

- [Adaptive Home and daily orientation](./HOME.md)
- [Universal Input and Speech](./UNIVERSAL_INPUT.md)
- [Plan, Focus, repair, and review](./PLAN_AND_FOCUS.md)
- [Track, habits, care, and wellness](./TRACK_AND_WELLNESS.md)
- [Journal, Notes, Knowledge, and reflection](./JOURNAL_NOTES_AND_REFLECTION.md)
- [Insights and EVA](./INSIGHTS_AND_EVA.md)
- [Onboarding, Settings, permissions, and recovery](./ONBOARDING_SETTINGS_AND_RECOVERY.md)
- [Widgets, Watch, notifications, and continuity](./SYSTEM_SURFACES_AND_CONTINUITY.md)

Calendar/timeline and Habits retain specialized packages:

- [Calendar and timeline](../calendar/README.md)
- [Habit streaks and recovery](../habits/README.md)

## Shared interaction contract

### Universal Capture

Universal Capture is a single arbitration layer for Task, Habit, Journal, Note, Tracker Entry, Mood + Energy, Hydration, Medication Event, and Routine Run where enabled. Requests from the shell, widgets, intents, Spotlight, share extension, or deep links are deduplicated and queued; drafts survive presentation changes when the underlying workflow supports recovery.

The persistent composer is the natural-language entry to that router. Typed or SpeechAnalyzer-dictated input resolves through deterministic commands, structured task/capture parsing, Apple Foundation Models, an installed on-device MLX fallback, and finally Eva conversation. It can open Journal, Note, Task capture, Meetings, Day Plan, Weekly Planner, Day Rescue, or Overdue Rescue. Classification never saves a record or performs a consequential mutation; see the [Universal Input and Speech contract](./UNIVERSAL_INPUT.md).

### Navigation

- Cross-root navigation selects the destination root before appending its typed leaf.
- A leaf route must resolve the requested stable identity. It must not substitute a different task, session, entry, or record when the requested item is missing.
- Protected Journal routes defer until authentication succeeds and reveal no content while locked.
- Back, dismissal, and root reselection must not silently discard a recoverable draft.

### Mutations and trust

- User actions and assistant proposals use canonical repositories/use cases.
- EVA presents meaningful changes as a preview or diff with Apply, Edit, and Not Now.
- A successful consequential action produces a receipt; reversible actions expose Undo for the supported lifetime.
- Destructive actions require explicit confirmation and describe what will be deleted, retained, or archived.
- Loading, failure, or cancellation never appears as success.

## Shared UI-state vocabulary

| State | Meaning | Required behavior |
|---|---|---|
| Populated | Authoritative content exists | Show the primary decision first and secondary context below |
| Empty | The query succeeded with no records | Explain the value of the surface and offer one relevant next action |
| Loading | Authoritative state has not arrived | Preserve final geometry and announce progress without blocking unrelated navigation |
| Stale | Cached content is visible but may be outdated | Label freshness and allow refresh; do not present stale content as current |
| Denied | A permission was declined or restricted | Explain the lost capability and provide a settings/retry path where possible |
| Offline | Local work is available but a remote dependency is not | Keep local actions available and identify what will retry later |
| Locked | Protected content exists but is unavailable | Show a privacy-safe unlock surface with no content-derived preview |
| Error | A read or mutation failed | Place the error near the affected work, preserve input, and offer recovery |
| Destructive | Data or continuity can be lost | Require confirmation, scope the consequence, and provide Undo when supported |

An explicit zero is a valid value and must never be rendered as missing or unavailable.

## Responsive and accessibility contract

- Compact iPhone uses the floating five-root dock and measured composer/capture clearance.
- Accessibility Dynamic Type collapses to content-first layouts, stacks controls, and hides decoration before truncating meaning.
- Regular and wide iPad use split navigation, adaptive 8/12-column Home layout, and a seven-day Week presentation where supported.
- Catalyst uses adaptive columns, keyboard commands, pointer states, and native menus rather than stretching phone chrome.
- VoiceOver order follows visual meaning: title and current state, primary action, supporting evidence, then secondary controls.
- Reduce Motion, Reduce Transparency, Increase Contrast, grayscale, Low Power Mode, thermal pressure, and inactive-scene policy are functional modes, not optional polish.

## Privacy classes

- `privateSensitive`: Journal content and media, health/biometric values, protected reflections, embeddings, semantic chunks, and authentication state.
- `privateStandard`: Personal tasks, plans, habits, routines, goals, notes, and ordinary tracker records.
- External surfaces receive explicit, versioned, redacted projections. They never read app persistence directly.
- Diagnostics use typed operation names, counts, and timing. They do not include private content.

## Rollout and rollback

Feature availability is read from `V2FeatureFlags`. Retained flags default on in
Debug and Release and are disable-only rollback paths; they do not delete
canonical records, reverse migrations, or create alternate stores. Adaptive Home
is canonical: its fallback, flag, promoted default, and disable argument have
been removed. Every retained flag-off test must verify that data created while
enabled returns intact when the flag is re-enabled.

## Documentation authority

- This handbook defines intended product and UX behavior.
- Architecture documents define runtime boundaries.
- `DESIGN.md` defines normative visual tokens and global design rules.
- The Unified Completion Status ledger decides current implementation and
  evidence status.
- Audits and evidence manifests describe what was observed at a point in time.
- Historical TODOs preserve implementation history and do not override current contracts.
