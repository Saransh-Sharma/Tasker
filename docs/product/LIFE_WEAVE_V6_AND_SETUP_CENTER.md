# Life Weave v6 and Setup Center Product Contract

**Classification:** Canonical product and UX contract
**Audience:** Product, design, engineering, QA, support
**Capability status:** Current workspace
**Source authority:** Life Weave lifecycle/state, commit coordinator, Setup Center, signed runtime configuration
**Last verified:** 2026-09-16
**Persistence:** Life Weave draft schema 9; refresh version 1

## Outcome

Life Weave creates the minimum useful LifeBoard system without requiring an account, network, permission, calendar, Health access, notifications, or an EVA model. That guarantee is unchanged by the Power-Up phase, because core completion is recorded before the phase begins. Setup Center remains the permanent surface for the same optional connections.

The first run is **four screens**, each asking one question:

1. **Welcome and intent** (`arrival`): a time-of-day greeting, "What do you want help with?", six short options with no subtitles, and one privacy line.
2. **Life areas** (`lifeAreas`): "What's on your plate?" Pick two to five tiles. **Pick order is the ranking** — the first pick carries ① and leads. The dock says what is missing ("Pick 2 more").
3. **First thing** (`firstCapture`): "What's on your mind?" The sentence is interpreted on a pause in typing and shown as a **Save as Task | Journal** choice. **Save** is the only action; **Skip** is always available. Nothing is written until Save.
4. **Ready** (`reveal`): a receipt of facts (the saved thing, the leading area, weekday hours with **Edit**), optional **Calendar / Apple Health / EVA** rows that open as sheets and return here, a one-line EVA notice with **What EVA can see**, and **Start my day**.

Usual hours and week start are defaults, edited from Ready — never asked. The optional "what gets in the way?" question is retired. `LifeWeaveStep` keeps all six cases so older drafts decode; `intent` resumes on Welcome and `dayShape` on Life areas.

Calendar, Apple Health, and EVA are not core steps or completion requirements. They are sheets over Ready and never take a progress position. Reminders remain contextual and are not part of first run.

## Content rules

App-wide voice and glossary: [DESIGN.md "Voice and copy"](../../DESIGN.md#voice-and-copy-2026-09-28). First run is stricter:

All first-run strings live in `LifeWeaveCopy` and go through `String(localized:)`. `LifeWeaveOnboardingTests` enforces:

- **One screen, one question.** The title is the question.
- **Budgets:** titles ≤ 6 words, options ≤ 4, support lines ≤ 10, buttons ≤ 3.
- **User words, not system words:** never "route", "module", "life map", "weave", "power up", "clearest path", "boundary".
- **The button names what happens,** and when disabled says what is missing.
- **Defaults over questions;** privacy in one sentence with detail one tap away, never repeated on a screen.
- **Delight is earned:** one signature moment per screen (first light on the welcome title, nodes blooming onto the map, the typed sentence landing on the receipt, checks drawing in on Ready), all opacity-only under Reduce Motion.

## Audience policy

| Audience | Presentation | Dismissal | Persistence |
|---|---|---|---|
| Fresh install | Starts v6 automatically | Core cannot be globally dismissed; First Capture can be skipped | Core completion version 6 |
| Interrupted v5/v6 | Migrates and resumes at the corresponding v6 owner stage | Same as fresh | Schema-9 draft and lifecycle phase |
| Previously completed workspace | Prefilled refresh invitation after Home settles | **Not now** suppresses this refresh version | `completedRefreshVersion` or `dismissedRefreshVersion` |
| Manual replay | Settings → Guided Setup | Always user initiated | New prefilled refresh; ignores dismissed marker |

Refresh is non-destructive. Selected starter areas move to the leading requested order; unmatched existing areas retain their relative order. Existing tasks, projects, habits, captures, and customized Home layouts are preserved. Working hours change only after that screen is explicitly confirmed. A new capture is written only after review and confirmation.

## Transaction and relaunch contract

The persisted lifecycle is `editing → committing → captureWritten → revealReady → finalized`.

- Canonical writes stop at `captureWritten`; this does not mark onboarding complete.
- `revealReady` is persisted before Reveal appears.
- **Start my day** invokes the idempotent finalizer, records any unopened connection as deferred, and dissolves into Home, where the first-action card is highlighted once and the Home tip waits for a later visit.
- A relaunch before finalization restores the exact draft or persisted Reveal.
- A relaunch after finalization delivers the stored destination without replaying writes.
- Stable record identifiers and phase receipts make retries duplicate-safe.

## Setup Center

Setup Center is reachable from:

- the Reveal secondary action;
- a dismissible **Finish personalizing** Home card until handled or dismissed;
- a permanent Settings row with live connector status.

Dismissing the center or Home card does not change a connector and never reopens onboarding.

### Calendar

Show a benefit primer, request access only after explicit action, then offer calendar selection. An empty selection means no calendars—not all calendars. Denied, restricted, unavailable, no-calendar, and partial-selection states remain distinguishable.

### Apple Health

Before the system sheet, list every supported read and write category being requested. Track these facts separately:

- whether the request sheet was presented;
- whether readable data is observable;
- write authorization per category.

HealthKit does not disclose read denial reliably. The app therefore says **Health access requested** after presentation and never infers “Reading is on” from the sheet appearing. Write status is shown per category or as an authorized count.

### Reminders and notifications

Setup Center shows status and routes to reminder creation. Notification authorization is deferred until the person enables an alert on the first reminder or routine that needs one.

### EVA

The normal entry is one standard Sign in with Apple button. Account exchange, 18+ eligibility, device attestation, configuration, and credit checks then progress compactly. Journal, Health, Life Moments, and Personal Memory are preselected but editable before one compare-and-swap confirmation. Cloud is the only provider presented here; Offline EVA is an advanced Settings path and an explicit recovery option.

## Analytics contract

Product events are first-party, content-free, enabled by default, and disableable in Settings. Allowed values are an enumerated event, timestamp, flow version, audience, normalized outcome/error, count, and duration bucket. Titles, captures, messages, memory text, Health data, journal content, and record identifiers are forbidden by both client type and server schema.

The signed runtime configuration independently controls fresh v6 presentation, existing-user refresh/version, and product-event transmission. Release/offline defaults keep all three enabled. Disabling presentation never rolls back or deletes committed records.

## Acceptance gates

- Terminate and relaunch at every stage and lifecycle boundary.
- Verify fresh, migrated, established-workspace refresh, Not now, and Settings replay paths.
- Confirm no core path requires permissions, account, network, credits, or local model.
- Confirm repeated commit/finalization creates no duplicates.
- Exercise VoiceOver, Dynamic Type, Reduce Motion, keyboard, denial/restricted states, and iPhone/iPad layouts.
- Verify every analytics payload against the content-free allowlist and immediate opt-out behavior.
