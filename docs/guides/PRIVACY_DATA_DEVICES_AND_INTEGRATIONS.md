# Privacy, Data, Devices, and Integrations

> Classification: Canonical user guide
> Audience: All users, support, privacy, security, and QA
> Capability status: Current workspace; backup/export gaps are not disguised
> Source authority: [System Surfaces](../product/SYSTEM_SURFACES_AND_CONTINUITY.md), persistence/runtime configuration, and [Feature Catalog](../product/FEATURE_CATALOG.md)
> Last verified: 2026-08-17

## Know where authority lives

LifeBoard’s local persistence is the immediate authority for LifeBoard-owned records. CloudKit continuity depends on configured containers, account, network, protected-data, and schema state. Home cards, widgets, Watch, Spotlight, notifications, Live Activities, and EVA overview cards are projections; they do not own a second copy of your task or habit.

External projections use versioned, atomic, redacted app-group envelopes with freshness. If a projection is stale, missing, locked, or incompatible, open LifeBoard and refresh rather than trusting old data.

## Privacy classes

- `privateSensitive`: Journal/media, health/care/biometric values, protected reflections, secure notes, embeddings/semantic chunks, and authentication state.
- `privateStandard`: tasks, plans, projects, habits, routines, goals, ordinary notes, and trackers unless their content is sensitive.

App lock, biometric protection, protected routes, and app-switcher shielding minimize disclosure. A locked deep link does not reveal content-derived titles or substitutes. Diagnostics should contain operation names/counts/timing, never private text.

## Permissions and integrations

- **Calendar:** selected events are read-only schedule context. LifeBoard writes only its own internal time blocks/planning metadata.
- **Health:** permission is domain-specific; manual fallback remains. Imported data retains source. Supported write-back uses an outbox and retry.
- **Reminders:** linked items retain external source identity; a missing external record is not silently replaced.
- **Notifications:** denial disables delivery, not the underlying Focus, routine, fasting, care, or planning feature.
- **Speech/camera/photos/files:** denial preserves text/manual capture and the draft.
- **EVA models:** Offline EVA uses an explicitly selected installed MLX model and keeps inference on device. Cloud EVA uses Luna only after Sign in with Apple, device trust, Apple 18+ eligibility, signed policy, credits, and explicit minimized category-aware consent. The provider does not switch silently during a request.

## Apple surfaces

Widgets include task, Focus Seed, Streak Resilience, Journal, Fasting, Nutrition, Wellness, Life Moments, Goals, and Routines plus Capture Control. Interactive actions call canonical commands and validate stable identity. Focus, Fasting, and Routine Live Activities are status/control projections.

Siri/App Intents can add tasks, ask/open EVA, start Focus, capture Journal/Notes, search/open Notes, log supported wellness metrics, start/end fasting, create countdowns, capture to Inbox, and act on stable widget items. Spotlight and deep links open typed destinations; missing items show a safe unavailable state.

The share extension accepts supported text/link/file/media payloads and opens a reviewable destination. Watch supports durable capture/audio outbox and timeline, meetings, and habit widgets/complications. When phone transfer fails, the outbox remains retryable.

iPad/Catalyst use adaptive columns, keyboard, pointer, and menus. Accessibility state—not screen size alone—can force a content-first stacked layout.

## Offline, stale, conflict, and recovery

Local safe actions continue offline. Remote barcode lookup, remote model work, CloudKit, and some integrations wait/retry and are labeled. Do not repeatedly submit a batch or extension action without checking its receipt/outbox; part may already have succeeded.

Use Settings → Recovery for bootstrap, migration, index, model, projection, or sync repair. Preserve canonical records while rebuilding derived indexes/projections. Conflict handling must retain provenance rather than silently choosing an unrelated version.

## Destructive actions and ownership

Before archive, delete, trash emptying, model removal, memory clearing, or data deletion, read scope and downstream effects. Archive usually retains history; permanent deletion may propagate to attachments, semantic indexes, projections, and evidence links. Use Undo where offered.

Portable full backup/restore, complete cross-domain export, retention controls, encryption/key recovery, and migration guarantees are strategic requirements in the [future blueprint](../product/LIFEOS_FUTURE_BLUEPRINT.md). Current documentation must not imply they exist where the runtime does not verify them.
