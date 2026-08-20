# Life Weave v6 and Setup Center Product Contract

**Classification:** Canonical product and UX contract
**Audience:** Product, design, engineering, QA, support
**Capability status:** Current workspace
**Source authority:** Life Weave lifecycle/state, commit coordinator, Setup Center, signed runtime configuration
**Last verified:** 2026-08-20
**Persistence:** Life Weave draft schema 9; refresh version 1

## Outcome

Life Weave creates the minimum useful LifeBoard system without requiring an account, network, permission, calendar, Health access, notifications, or an EVA model. Setup Center is a separate post-onboarding surface for optional personalization.

The canonical core has six stages:

1. **Arrival:** promise, privacy line, and one primary action.
2. **Intent:** desired change and optional friction signals.
3. **Life areas:** select two to five and choose the leading area.
4. **Day shape:** choose a preset or explicitly edit working hours.
5. **First Capture:** optionally interpret and confirm one real Task or Journal entry; Skip is always available.
6. **Reveal:** read the deterministic result and explicitly choose **Start my day** or **Personalize more**.

Calendar, Apple Health, Reminders, and EVA are not steps, progress items, restoration destinations, or completion requirements.

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
- Both Reveal exits invoke the same idempotent finalizer.
- **Start my day** finalizes and opens Home.
- **Personalize more** finalizes, opens Home, then routes to Setup Center.
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
