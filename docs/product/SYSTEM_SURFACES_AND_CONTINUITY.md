# System Surfaces and Continuity

**Classification:** Canonical feature contract
**Surfaces:** Widgets, Live Activities, App Intents, Spotlight, notifications, deep links, Watch, Watch widgets, and Catalyst

## Promise and user jobs

System surfaces let intent and current state appear where useful without exposing the app’s private stores or creating a second mutation path.

Users need to:

- glance at safe current context;
- capture or start a supported action quickly;
- continue inside the correct LifeBoard root/detail;
- control a Focus or Fasting session through canonical commands;
- capture from Watch when the phone is unavailable;
- trust that locked or sensitive content will not appear in previews.

## Projection architecture

External surfaces consume a versioned, atomic, redacted app-group envelope with backup recovery and schema/domain validation. They never open the main app database directly.

Each projection declares:

- schema version and domain;
- freshness timestamp;
- privacy classification;
- stable route/action identity;
- content-safe display fields;
- supported fallback when stale, missing, locked, or incompatible.

Writers publish after canonical mutations through the shared refresher. Readers reject unsupported or malformed envelopes and fall back safely.

## Surface contracts

### Widgets

Widgets are glanceable and display-only unless an explicit App Intent invokes a canonical action. They show freshness and privacy-safe summaries. Stale or unavailable data is labeled; private Journal/health content is not substituted with revealing counts or titles.

### Live Activities

Focus and other supported live sessions use bounded, versioned payloads. Commands are idempotent and resolve the exact active session. Ended or stale activities explain that state and route into the app when more context is needed.

### App Intents and shortcuts

Intents validate identity, authorization, and current state before mutation. A response distinguishes applied, no-op/idempotent, stale, denied, and failed outcomes. Intents do not bypass the canonical repositories.

### Spotlight

Spotlight attributes are content-free for protected Journal routes. Search results route to stable typed destinations and defer authentication. Deleted or unavailable identities produce a safe explanatory result.

### Notifications and deep links

Notification actions translate to typed routes or canonical mutations. Routing selects the correct root before appending the leaf. Completion/snooze actions preserve their dedicated mutation handlers. Duplicate delivery and app launch races are idempotent.

### Watch

Watch supports privacy-aware snapshots and durable capture. Mood, dictated text, audio, recent status, queue count, and retry surfaces use a file-protected outbox. Audio remains until a durable phone receipt arrives. Phone import deduplicates, acknowledges, quarantines malformed/unsupported items, and exposes user-visible recovery.

## State matrix

| State | Required behavior |
|---|---|
| Fresh projection | Show the bounded supported summary/action |
| Stale projection | Display freshness and route to app for current state |
| Missing envelope | Neutral unavailable state, never cached private fallback |
| Schema mismatch | Reject safely and request republish/update |
| Locked/protected | Redacted placeholder and authenticated app route |
| Offline | Queue supported local action/capture or explain retry |
| Duplicate delivery | Idempotent no-op with stable receipt |
| Partial Watch transfer | Retain durable source and expose queue/retry |
| Malformed capture | Quarantine without content loss; explain recovery |
| Deleted target | Do not substitute another record |

## UI/UX contract

- Widgets prioritize one current value or action; avoid miniature app screens.
- Complications and Watch widgets use short labels and high-contrast symbols.
- Notifications state the action and consequence without exposing protected context.
- Live Activities prioritize session identity, elapsed/remaining state, and one or two canonical controls.
- Error/stale surfaces remain calm and actionable; they do not repeatedly notify.

## Accessibility and privacy

- Widget/Watch labels include the value, unit/state, freshness, and action result where relevant.
- Color and progress rings have text equivalents.
- System previews respect lock-screen and app privacy settings.
- Journal text/media/prompts/embeddings and sensitive health values remain excluded unless a separately approved redacted projection explicitly permits a safe aggregate.

## Implementation and evidence

Primary anchors include the shared snapshot envelope, system-surface refresher, WidgetKit/Watch targets, App Intents, Focus/Fasting coordinators, Spotlight indexers, notification route translators, app router, and Watch capture/import services.

The primary rollout flag is `lifeOSSystemSurfacesV2Enabled`; domain projections also respect their owning feature flag and explicit per-surface authorization. Disabling the surface flag stops projection/presentation without deleting canonical app data or durable recovery state.

Recorded evidence covers target compilation, schema validation, backup-aware reads, redaction contracts, intent routing, Watch dedup/quarantine models, and synthetic termination/offline/order/protection cases. The fresh complete-suite run still reports widget snapshot and notification-route regressions. Physical termination and protection transitions, paired-device acknowledgement loss, production App Group behavior, notification delivery, and stale-widget matrices remain device gates.
