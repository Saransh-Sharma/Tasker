# LifeBoard

**Classification:** Current product overview
**Audience:** Users, product, design, engineering, QA, and support
**Capability status:** Current workspace; individual features may still require device or release validation
**Source authority:** [Product handbook](docs/product/README.md) and [completion status](docs/life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md)
**Last verified:** 2026-08-11

> Life is not a list. Run it like a system.

LifeBoard is a local-first LifeOS for organizing the responsibilities, routines,
health signals, knowledge, and decisions that make up a real life. It helps a
person decide what matters now, place work into time, act with less friction,
recover when the plan breaks, and learn from evidence without turning life into
a scorecard.

LifeBoard runs one operating loop:

`orient → capture → organize → plan → focus or track → recover → reflect → adapt`

The app is built for iPhone and iPad, includes Mac Catalyst, widgets, Live
Activities, App Intents and Shortcuts, Spotlight and notification routes, a
share extension, and a Watch companion with complications and durable capture.

## The five roots

| Root | Question | What it owns |
|---|---|---|
| **Home** | What matters now? | Daily orientation, Focus Now, signals, tasks, habits, timeline, Daily Loop, and recovery |
| **Plan** | When and in what order? | Inbox, Day, Week, Backlog, capacity, scheduling, Focus, weekly planning, and review |
| **Track** | What am I sustaining or learning? | Habits, routines, goals, trackers, care, wellness, nutrition, fasting, and Life Moments |
| **Insights** | What changed, and what supports that conclusion? | Trends, evidence, health insights, weekly review, and explainable reflection |
| **EVA** | Help me understand or change this safely | Local-first conversation, day overview, task breakdown, proposals, Apply, receipts, and Undo |

Journal, Notes and Knowledge, Focus, Settings, projects, tasks, habits, health,
and other record details are typed destinations reached from those roots. They
do not create competing global systems.

## Run every part of life

LifeBoard's onboarding and Life Management model can organize:

- **Work & Career:** deliverables, meetings, follow-ups, deep work, projects, and professional maintenance.
- **Life Admin:** home, errands, appointments, documents, bills, and recurring responsibilities.
- **Health & Self:** habits, movement, sleep, nutrition, hydration, body metrics, workouts, medication events, fasting, and recovery.
- **Relationships:** meaningful dates, commitments, shared plans, and intentional follow-up.
- **Learning & Growth:** reading, courses, skills, practice, and knowledge capture.
- **Creativity & Fun:** ideas, creative projects, recreation, and protected unstructured time.
- **Money:** current tasks, projects, habits, goals, and reminders related to personal finance; the broader financial LifeOS is defined as future direction, not shipped account aggregation or advice.

The organizing hierarchy is deliberately simple:

`life area → project or goal → task, habit, or routine → day/week placement → evidence and review`

## A day in LifeBoard

1. **Commit.** Home carries forward relevant work and asks for one intentional starting point.
2. **Act.** Focus Now, the timeline, tasks, habits, routines, and quick tracking keep the next decision visible.
3. **Repair.** Replan, Minimum Viable Day, EVA, and Overdue Rescue help when time, energy, or commitments change.
4. **Close.** The end-of-day ritual reconciles unfinished work, captures one line of reflection, and names tomorrow's first thing.
5. **Rest.** A closed day stops asking for more.

Every consequential action uses the canonical data path. A proposal is not a
mutation; successful reversible changes produce a receipt and expose Undo.

## Capture once, route correctly

The persistent Life Thread composer accepts typing or live on-device dictation.
It resolves deterministic commands first, parses task language, uses bounded
semantic classification where available, and falls back to EVA when the intent
is conversational or uncertain.

Universal Capture supports tasks, habits, journal entries, notes, tracker
entries, mood and energy, hydration, medication events, routine runs, and time
blocks. Classification never silently saves a record: the appropriate native
editor remains the review and commit boundary.

## Plan work around reality

Plan includes Inbox, Day, Week, and Backlog lenses. A day can be viewed as a
timeline or agenda and combines working hours, fixed read-only calendar
commitments, LifeBoard time blocks, task estimates, and open capacity.

The current **This Week** workspace replaces the retired weekly wizard. It
places work directly on days from Overdue, Inbox, and Anytime lanes, shows
capacity as both shape and text, keeps later days soft until needed, and writes
each accepted placement immediately through the receipt-backed planning path.

Focus sessions support scoped or unscoped work, duration setup, pause and
resume, interruption reasons, outcomes, reflections, notifications, startup
repair, and a Live Activity.

## Track systems, not perfection

Track provides:

- habit schedules, quantity/count outcomes, Board history, streaks, resilience, recovery, corrections, pause, and archive;
- quiet multi-habit tracking;
- goals with typed progress samples and links to tasks, habits, routines, and trackers;
- routines with ordered or branching task, habit, check-in, timer, instruction, and choice steps;
- generic trackers, hydration, mood and energy, medication events, history, and correction;
- wellness records, Apple Health connection, nutrition, fasting, and Life Moments.

Missing evidence is not failure, and an explicit zero is not missing. Health and
care language remains descriptive and non-clinical.

## Health and Apple Health

LifeBoard can read activity, walking distance, active/resting energy, hydration,
nutrition, body measurements, resting heart rate, workouts, and sleep from
Apple Health when authorized. Hydration, nutrition, body measurements, and
user-authored workouts support write-back; activity, energy, sleep, and fasting
remain read-only or local-canonical as appropriate.

Manual recording remains available when Health access is denied or unavailable.
Protected, stale, partial, duplicate, and retry states remain distinct.

## Journal, knowledge, and reflection

Journal supports private day-based capture, mood and energy, text, audio,
on-device transcription, document scanning, files and photos, protected routes,
search, semantic evidence, and weekly reflection.

Notes and Knowledge support spaces, folders, tags, smart collections, templates,
TextKit editing, links, attachments, indexed search, secure notes, biometric
unlock, trash and restoration, batch actions, and EVA-assisted work.

## EVA: a Chief of Staff, not an autopilot

EVA uses local model routing and deterministic fallbacks to answer questions,
summarize the day, retrieve relevant task context, break down work, and prepare
reviewable proposals. Model output is bounded by schemas and canonical action
pipelines.

Meaningful changes follow:

`request → explanation or proposal → Apply / Edit / Not Now → receipt → Undo`

The user can stop, continue, or retry generation. Remote context, where enabled,
requires account opt-in and category-specific grants; it never expands widget,
Watch, notification, Spotlight, or lock-screen disclosure.

## Private and accessible by design

- Core workflows are local-first; optional CloudKit and external integrations do not become alternate sources of truth.
- Journal, health, biometrics, semantic derivatives, and protected reflections use the sensitive-data contract.
- Widgets, Watch, notifications, and Spotlight receive small versioned, redacted projections instead of direct persistence access.
- VoiceOver, Dynamic Type, Reduce Motion, Reduce Transparency, Increase Contrast, keyboard/pointer access, low-power policy, and thermal pressure are functional modes.

## Documentation

- [LifeBoard LifeOS Product Handbook](docs/product/README.md)
- [Current Feature Catalog](docs/product/FEATURE_CATALOG.md)
- [User Operating Guides](docs/guides/README.md)
- [Future LifeOS Blueprint](docs/product/LIFEOS_FUTURE_BLUEPRINT.md)
- [Product Requirements](PRODUCT_REQUIREMENTS_DOCUMENT.md)
- [Current Architecture](docs/architecture/LIFEBOARD_V2_ARCHITECTURE_GUIDE.md)
- [Design Contract](DESIGN.md)
- [Implementation and Release Status](docs/life-os/LIFEBOARD_UNIFIED_COMPLETION_STATUS.md)

## Build and verify

Requirements:

- macOS with Xcode 26.5 and iOS 26 simulator support;
- Swift 6 from the selected Xcode toolchain;
- Node.js 20.19+ or 22.12+ for the marketing site.

All Swift packages used by the current workspace are in this repository; no
sibling feature-package checkout is required.

```sh
xcodebuild -workspace LifeBoard.xcworkspace \
  -scheme LifeBoard \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build

LIFEBOARD_TEST_DESTINATION='platform=iOS Simulator,name=LifeBoard Test iPhone,OS=26.5' \
  bash scripts/run-baseline-aware-tests.sh

bash scripts/check-documentation-current.sh
```

For the React marketing site:

```sh
npm install
npm run dev
npm run build
```

## Repository map

| Path | Responsibility |
|---|---|
| `LifeBoard/` | iOS application, features, composition, persistence, and local assistant |
| `Packages/` | Shared contracts, tokens, UI, domain, calendar, transcription, and extracted features |
| `LifeBoardWidgets/`, `LifeBoardWatch/`, `LifeBoardWatchWidgets/` | Privacy-safe system and wearable surfaces |
| `LifeBoardShareExtension/` | Share-sheet capture |
| `LifeBoardTests/`, `LifeBoardUITests/` | Unit, integration, accessibility, performance, and seeded journeys |
| `docs/` | Current product, user, design, architecture, status, evidence, research, and legal documentation |
| `src/` | React marketing site |

The goal is not a perfect day. It is a life that can keep moving when the day is
not perfect.
