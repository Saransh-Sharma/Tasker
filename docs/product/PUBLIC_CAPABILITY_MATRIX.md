# LifeBoard Public Capability Matrix

> Classification: Canonical public-claim authority
> Audience: Product, marketing, design, engineering, QA, support, privacy, and release teams
> Capability status: Current public surface with explicit qualifications
> Source authority: [Feature Catalog](./FEATURE_CATALOG.md), current runtime code, entitlements, and [completion evidence](../life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md)
> Last verified: 2026-08-13

This matrix is the release gate for claims on the LifeBoard website, App Store
creative, repository README, support material, and public product descriptions.
It describes what may be said, not merely what is intended. Runtime behavior and
fresh release evidence override this document when they disagree.

## Public position

**Product:** LifeBoard
**Category:** Life OS
**Assistant:** EVA
**Promise:** One place to run the life you actually have.
**Operating loop:** `orient → capture → organize → plan → focus or track → recover → reflect → adapt`

LifeBoard is a private, recovery-aware Life OS for people balancing work, home,
health, relationships, learning, creativity, and personal administration. “Private”
means local-first core workflows, optional Apple-operated iCloud continuity,
permission-scoped integrations, redacted external projections, and reviewable
assistant actions. It is not a claim of a proprietary account service or an
unverified encryption property.

## Status vocabulary

| Status | Public use |
|---|---|
| **Available** | May be presented as current, subject to the qualifications in this matrix. |
| **Qualified** | May be presented only with the stated platform, permission, model, device, or connectivity boundary nearby. |
| **Private preview** | Must not be presented as generally available. |
| **Future** | May appear only in explicitly future-facing material, never as current product behavior. |

## Capability register

| Public ID | Capability and permitted claim | Status | Platforms and qualifications | Feature Catalog authority | Release evidence | Website use | Screenshot IDs |
|---|---|---|---|---|---|---|---|
| `life.home.orientation` | Adaptive Home orients the day with Focus Now, signals, tasks, habits, timeline, Daily Loop, and recovery entry points. | Available | iPhone and iPad; visible modules depend on enabled areas and available records. | [Adaptive Home](./FEATURE_CATALOG.md#adaptive-home) | Completion status and seeded Home UI journey | `/`, `/features/home/` | `home-command-center`, `recovery-overdue-rescue` |
| `life.structure` | Life areas connect projects, goals, tasks, habits, and routines across seven practical life domains. | Available | Starter areas are editable; Money is organization only, not account aggregation or advice. | [Life Management](./FEATURE_CATALOG.md#life-management-areas-projects-sections-and-tags) | Source and onboarding UI coverage | `/`, `/features/home/`, `/features/` | `home-command-center` |
| `life.capture` | Universal Capture routes typed or dictated input to a reviewable native editor before saving. | Qualified | Speech requires microphone and speech permissions and supported on-device services. Classification never silently commits. | [Universal Capture](./FEATURE_CATALOG.md#universal-capture) | Input routing tests and UI identifiers | `/features/home/`, `/features/journal/` | `universal-capture-review` |
| `life.plan.day` | Day planning combines LifeBoard work, estimates, time blocks, working hours, and read-only calendar context to show capacity. | Qualified | Calendar access is optional and read-only. External events remain calendar-owned. | [Plan lenses](./FEATURE_CATALOG.md#plan-lenses-and-schedule-capacity) | Planning tests and seeded route capture | `/`, `/features/plan/` | `plan-day-capacity`, `plan-week-workspace` |
| `life.plan.focus` | Focus supports timed sessions, pause/resume, interruption reasons, outcomes, reflection, notifications, and a Live Activity. | Qualified | Live Activities and notification behavior require supported devices and user permission. | [Focus sessions](./FEATURE_CATALOG.md#focus-sessions) | Focus runtime and UI tests | `/features/plan/`, `/features/everywhere/` | `focus-active-session` |
| `life.plan.recovery` | Overdue Rescue, Day Repair, Minimum Viable Day, and Day Close help users replan without rewriting true deadlines or treating misses as failure. | Available | Recommendations remain user-reviewed; exact surfaces depend on current day state. | [Inbox and task recovery](./FEATURE_CATALOG.md#inbox-and-task-recovery) | Seeded rescue and Daily Loop UI journeys | `/`, `/features/home/`, `/features/plan/` | `recovery-overdue-rescue`, `recovery-day-close` |
| `life.track.habits` | Habit Board preserves mixed history, scheduled misses, explicit outcomes, correction, pause, archive, streaks, and resilience. | Available | Missing evidence and explicit zero remain distinct. | [Habits](./FEATURE_CATALOG.md#habits-and-quiet-tracking) | Habit runtime and UI tests | `/features/track/` | `track-habit-board`, `track-goals-routines` |
| `life.track.goals-routines` | Goals, milestones, routines, trackers, and care records connect repeated practice to larger outcomes. | Available | User-authored records; no diagnosis or adherence judgment. | [Goals](./FEATURE_CATALOG.md#goals-and-progress-evidence), [Routines](./FEATURE_CATALOG.md#routines-and-runs) | Track route/source coverage | `/features/track/` | `track-goals-routines`, `track-overview` |
| `life.health` | LifeBoard reads supported Health data and can write supported user-authored hydration, nutrition, body measurement, and workout records. | Qualified | Apple Health, permission, data availability, and supported record type required. Activity, energy, sleep, and fasting are not marketed as write-back. | [Health connection](./FEATURE_CATALOG.md#health-connection-and-synchronization) | Health adapter tests; signed-device evidence remains required where listed | `/features/track/`, `/privacy/` | `track-wellness`, `track-nutrition`, `track-fasting` |
| `life.journal` | Journal supports text, mood and energy, audio, on-device transcription, scans, files, photos, search, protected routes, and reflection. | Qualified | Media features require the relevant permission; transcription depends on supported device services. Protected content requires configured authentication. | [Journal](./FEATURE_CATALOG.md#journal-and-durable-media) | Journal route/source coverage | `/features/journal/` | `journal-day` |
| `life.knowledge` | Notes and Knowledge support spaces, folders, tags, templates, links, attachments, indexed search, secure notes, trash, and restoration. | Qualified | Biometric protection requires device enrollment and permission. Search availability reflects indexing state. | [Notes and Knowledge](./FEATURE_CATALOG.md#notes-and-knowledge) | Notes/Knowledge tests and route coverage | `/features/journal/` | `knowledge-notes` |
| `life.insights` | Insights presents trends and reviews with source, timeframe, freshness, and limitations; XP, levels, badges, and achievements provide optional progress feedback. | Available | Evidence can be partial or stale; the product does not imply causation, diagnosis, or moral judgment. | [Insights](./FEATURE_CATALOG.md#insights-and-evidence-disclosure) | Insight evidence tests and seeded capture | `/`, `/features/insights/` | `insights-evidence` |
| `life.eva` | EVA can retrieve relevant context, explain, break down work, and prepare proposals that expose Apply, Edit, Not Now, receipts, and Undo. | Qualified | Model and feature availability depend on supported hardware, downloaded models, user controls, and sometimes connectivity. No silent consequential mutation. | [EVA assistant](./FEATURE_CATALOG.md#eva-assistant) | Assistant policy tests and seeded conversation | `/`, `/features/eva/`, `/privacy/` | `eva-proposal-review` |
| `life.continuity.icloud` | Eligible records can continue privately through the user’s iCloud/CloudKit account while local work remains available offline. | Qualified | iCloud sign-in, entitlement, connectivity, storage, and service availability apply. Do not claim complete backup, export, or proprietary account recovery. | [Persistence and sync](./FEATURE_CATALOG.md#persistence-sync-and-offline-continuity) | Sync coordinator tests; device validation where listed | `/features/everywhere/`, `/privacy/`, `/support/` | `home-command-center`, `plan-week-ipad` |
| `life.continuity.surfaces` | Widgets, Live Activities, Siri, Spotlight, notifications, Share Extension, Watch, iPad, and supported Mac continuity provide focused entry points and redacted projections. | Qualified | Availability varies by device, OS, enabled target, permission, and configured data. Mac continuity is Catalyst support, not a separate web service. | [System surfaces](./FEATURE_CATALOG.md#reminders-widgets-live-activities-siri-spotlight-and-notifications), [platforms](./FEATURE_CATALOG.md#share-extension-watch-ipad-and-catalyst) | Target builds, extension tests, and manual device ledger | `/features/everywhere/` | `plan-week-ipad` |

## Screenshot register

The required marketing scene identifiers are stable even when an image is
recaptured: `home-command-center`, `universal-capture-review`, `plan-day-capacity`,
`plan-week-workspace`, `focus-active-session`, `track-habit-board`,
`track-overview`, `track-goals-routines`, `track-wellness`, `track-nutrition`,
`track-fasting`, `track-life-moment`, `journal-day`, `knowledge-notes`,
`insights-evidence`, `eva-proposal-review`, `recovery-overdue-rescue`, and
`plan-week-ipad`.

Only files marked `approved` in the screenshot manifest may be published. If a
capture fails content, privacy, stability, or size validation, the previously
approved file remains authoritative. Never simulate Watch, widget, or Mac
screens when a verified capture environment is unavailable.

## Claims that remain out of bounds

- a LifeBoard-hosted account service, recovery phrase, or proprietary cloud;
- unverified end-to-end encryption language;
- calendar event editing, autonomous scheduling, or assistant changes without review;
- guaranteed sync, restoration, backup, or export completeness;
- diagnosis, treatment, medical conclusions, financial advice, or financial account aggregation;
- collaboration, family sharing, employer monitoring, or other blueprint capabilities;
- universal availability when a capability requires permission, hardware, a downloaded model, connectivity, or signed-device validation.

## Release use checklist

- [ ] Every marketed capability has a row above and uses its stable public ID.
- [ ] Qualifications appear near the claim, not only in legal text.
- [ ] Every screenshot is synthetic, populated, manifest-approved, and free of fixture language.
- [ ] App Store CTAs use `https://apps.apple.com/app/id1574046107`.
- [ ] Support uses `support@getlifeboard.app` and no personal contact details.
- [ ] Future direction remains isolated from current public behavior.
