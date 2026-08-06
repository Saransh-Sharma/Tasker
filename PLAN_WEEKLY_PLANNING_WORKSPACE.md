# This Week — weekly planning workspace, and the Plan-root glitch

Revision of the "Premium Weekly Planning Workspace and Plan-Tab Glitch Fix" plan.
Written after reading the shipping code and driving the app on device.

---

## Part 0 — The glitch (done, verified)

**The original plan's diagnosis was right; its trigger was wrong.**

`compactShell` rendered a root only when `visitedRoots.contains(destination)`, and
`visitedRoots` is written from `.onChange(of: router.selectedDestination)`. `onChange`
runs *after* the render pass that observed the new selection. So the first pass after
Plan is selected drew a Home already faded to `opacity(0)` and a Plan that did not exist
yet — no visible root at all — and the system's white window backing showed through for
as long as Plan's stores took to build.

The plan attributed this to the `.weeklyPlanner` CTA paths. It is not specific to those.
The path you actually hit is the Home "Now" context card, which calls plain
`router.select(candidate.destination)` with no route push at all
([LifeBoardFoundationGallery.swift:1442](LifeBoard/Foundation/Design/LifeBoardFoundationGallery.swift:1442)).
Every first-visit root change had the same blank frame; Plan is just the one with the
heaviest first build, so it is the one you can see.

**Consequence for the plan:** `AppRoute.weeklyPlannerOverdue` and `HomeContextCandidate.route`
are *feature* work for Part 2. They were never part of the fix, and bundling them made a
two-line correction look like a routing project.

**Shipped:**

- `LifeBoardRootRetention` in [LifeOSFoundationShell.swift](LifeBoard/Foundation/Navigation/LifeOSFoundationShell.swift) —
  a pure policy separating *what renders this pass* (`destination == selected || visited.contains`)
  from *what survives afterwards* (the visited set, with Eva still evicted on the way out).
- A warm `foundationCanvas` floor under the root stack, so any future gap reads as paper, not white.
- Five regression tests in `LifeOSFoundationContractTests`, including the property the bug
  violated: at every combination of selection and visited set, some root is on screen.
- Device-verified: Plan opens clean on first visit.

**Correction to the original plan's acceptance section:** it claims "The current baseline is
green: 20 targeted weekly-planning and overdue tests pass before implementation." The repo
baseline is *not* green — `LifeOSFoundationContractTests` alone has a pre-existing failure
(`testWellnessNormalizedEventIsSensitiveAndUsesCaptureDay`), and several more are documented
elsewhere. A green targeted subset is not evidence of repo health, and should not be used as
the gate.

---

## Part 1 — What is actually wrong with the feature

Two findings from the code and the device, either of which invalidates parts of the original plan.

### 1. The Week tab has days you cannot put work into. The planner has placement but no days.

The Week tab renders seven ~250pt day cards, each showing "9h 30m known capacity remains ·
0 due" and nothing else. You scroll a screen and a half to see your week, and there is no
affordance on any card to put anything on it. Its only real control is "Plan the week", which
opens `SunriseWeeklyPlannerView` — a four-step wizard (direction → outcomes → tasks → review).

And the wizard sorts tasks into `TaskPlanningBucket`: `today / thisWeek / nextWeek / later /
someday` ([TaskPlanningBucket.swift:3](LifeBoard/Domain/Models/TaskPlanningBucket.swift:3)).

The original plan assumes a seven-day ribbon throughout, lists "task bucket and day placement"
in one `PlanMutation` bullet, and never says which field a day placement is.

**Correction found while building.** A day-level primitive *does* exist — just not where the
wizard could see it. `PlanningTaskMetadata.planningDay`
([PlanningCoreModels.swift:84](LifeBoard/Foundation/PhaseIII/PlanningCoreModels.swift:84))
already carries it, with a doc comment that draws exactly the distinction that matters:

> the earliest day work may begin, distinct from `planningDay` (when you intend to do it) and
> `dueDate` (when it must be finished)

`PlanStore.plannedTasks(on:)` reads it, and `updateTask(planningDay:)` already writes it
through the receipt path. The gap was never the model. It was that the weekly *wizard* used a
different vocabulary (`TaskPlanningBucket`) from the Plan module beside it, and neither
surface bridged them.

**Decision: day placement writes `planningDay`, never `dueDate`.**

- An earlier draft of this plan said to write `dueDate`, on the reasoning that dragging to a
  day *is* scheduling in Todoist. That was wrong here, and would have been a real defect:
  moving a task to Thursday in order to *work* on it would silently rewrite a genuine
  deadline, and the user would find out when something shipped late. The codebase had already
  made the right distinction; the plan just had not read it.
- No new attribute, no `plannedRank`, and **no Core Data model version** — `pinOrder` already
  exists on the same metadata for intra-day rank.
- Rejected: `WeeklyTaskPlacement` as a separate persisted entity. It buys reversibility we get
  more cheaply from Undo, at the price of a second scheduling system.
- The one thing placement must also do is clear `unscheduledDisposition` when it is not
  `.inbox`. Pulling something out of Someday onto Wednesday without that leaves it placed and
  still invisible in every list that filters Someday out.

### 2. The staged draft / commit / crash-recovery subsystem should not be built

The original plan specifies `WeeklyPlanningDraft`, versioned atomic JSON in the app group,
autosave on every edit and on scene deactivation, reconciliation of deleted tasks and changed
calendar events on restore, `CommitWeeklyPlanningRequest`/`Result`, a `CommitWeeklyPlanningUseCase`
with forward/undo batches, staged failure compensation, and a "Commit N changes" control.

Three reasons to cut all of it:

- **It contradicts itself.** The same plan says new tasks "persist immediately to canonical
  Inbox … their weekly placement remains staged until commit." So after a crash, the task
  exists and its placement does not. The user cannot predict what is saved. Mixed commit
  semantics are worse than either pure model.
- **No competitor does this.** Todoist applies a drag the moment you drop it. TickTick applies
  each Plan-Your-Day decision immediately. Sunsama's weekly ritual writes as you go. The batch
  commit is not a premium touch; it is a transaction the user has to hold in their head.
- **It is roughly 40% of the implementation cost** and blocks everything behind it.

**Decision:** every placement, decision and creation applies immediately, with a durable Undo
receipt — the existing `PlanningMutationReceipt` path already carries this. The weekly ritual
ends with a *summary*, not a Save: "Your week: 14 placed, 3 let go, 22h of room left."

If a review-before-real step is genuinely wanted later, it belongs as an explicit "propose"
mode, not as the default semantics of every tap.

### 3. It designs the ribbon but not the backlog you actually have

You said you have *many* tasks overdue. The plan's only response is a test case: "Test weekly
planning with zero, one, twenty, and 100+ overdue tasks." Testing 100 overdue is not designing
for 100 overdue. Placing 100 items into a seven-day ribbon one `+` at a time is a punishment,
and the existing one-by-one Rescue deck is worse at that volume, not better.

The two competitors solve this from opposite ends and we need both: Todoist gives you
multi-select and one Reschedule; TickTick's "Plan Your Day" walks overdue items one at a time.

**Decision:** the overdue entry point opens on a bulk decision, not on the ribbon (Part 2).

### 4. The plan proposes exactly the thing Sunsama deliberately refuses to build

Sunsama's weekly flow does not let you fill in tasks for every day of the week in advance —
their stated reason is that it "often leads to feeling crushed if you fall behind early in the
week." The original plan's seven-day ribbon with per-day placement is precisely that, and it
does not acknowledge the risk.

**Decision:** keep per-day placement — it is what you asked for and it is Todoist's model —
but make the week *asymmetric*. Today and the next two days are concrete lanes; the rest of
the week defaults to a single soft "Later this week" lane you can open. Falling behind on
Tuesday then costs you two days of re-planning, not seven.

### 5. What the original plan gets right and this one keeps

- EventKit attendee status is read-only, so LifeBoard must never claim to change an RSVP.
  A private Attend/Skip override plus "Respond in Calendar" is the correct shape.
- Warnings are informative, never blocking.
- The accessibility set: VoiceOver day summaries, custom move actions, keyboard day
  navigation, non-color overload indicators, and drag alternatives.
- Reusing the existing bounded shaders rather than inventing new ones.

---

## Part 2 — The design: "This week"

One surface. It replaces both the seven dead day cards and the four-step wizard.

### Layout (iPhone)

The ribbon sits in the **middle** of the screen, not the top. It is the day selector, the drop
target, and the load gauge — so it must be under the thumb, and so must the tray rows that
feed it. A top ribbon puts the two halves of every interaction at opposite ends of the phone.

```
┌────────────────────────────────┐
│ This week      Aug 4–10   ⌄    │  header: "12 to place · 3 overdue"
│ ▸ What matters this week       │  collapsed intention + outcomes
├────────────────────────────────┤
│  Wednesday 6                   │
│  ─────────────────────────     │
│  ▪ 10:00 Standup      In ✓     │  meetings first: the day's fixed shape
│  ▪ 14:00 Design review  ⋯      │
│  ○ Draft update                │  placed tasks
│  ○ Email launch notes          │
│  + Add to Wednesday            │  persistent inline composer
├════════════════════════════════┤
│  S  M  T (W) T  F  S           │  ← the ribbon. sticky. drop target.
│  ▁  ▃  ▅  ▇  ▂  ▁  ▁           │    load bars, today ringed
├────────────────────────────────┤
│ Overdue 9 · Inbox 4 · Anytime  │  source tray (draggable sheet)
│  ○ Ship pricing page      +    │
│  ○ Call the studio        +    │
│  ○ Renew domain           +    │
└────────────────────────────────┘
```

On iPad the ribbon becomes seven persistent columns with the tray as a fixed left pane —
the Todoist calendar-plus-Plan-sidebar arrangement, which is what that layout is good at.

### The interaction that makes it fast

Tapping `+` on a tray row places it on the selected day. The row flies into the ribbon chip
on a short arc, the chip's load bar grows, and the row leaves the tray. That is the whole
gesture — `triageSettle` fires on the chip, not the row.

You can go `+ + + +` down the tray as fast as you can tap, and change target day with one
chip tap between placements. No dialogs, no confirmation, no mode. Both thumbs stay in the
lower half of the screen. This is Todoist's throughput inside Sunsama's ritual, and it is
the reason drag-and-drop is *not* in the first slice: `+` already gets you there, and drag
costs the most in accessibility and gesture conflict.

Everything else is a variation on it:
- **Multi-select** — long-press a tray row to enter selection, then one chip tap places all.
- **Swipe a row** — Today / Tomorrow / Someday, the three moves that need no target choice.
- **Drag** — for people who want it (Slice 4), never the only way to do anything.
- **"Move to…"** — a VoiceOver custom action and a context-menu item, always present.

### Opening on overdue

The overdue CTA does not open the ribbon. It opens on the backlog:

> **9 tasks have been waiting.**
> The oldest is from 24 June.
> [ Spread across this week ]  [ Let them go to Someday ]  [ I'll place them myself ]

- *Spread across this week* fills days in order, respecting each day's remaining room, and
  stops when the week is full rather than overfilling it. One receipt, one Undo.
- *Let them go to Someday* is the bankruptcy move. It is offered plainly and without
  scolding, because at 100+ overdue it is the correct answer and every app that hides it
  makes people abandon the list instead.
- *I'll place them myself* drops into the workspace with the tray pinned to Overdue,
  oldest first.

The existing one-by-one deck survives as "Rescue sprint" in the Overdue tray's overflow —
it is genuinely nice at 5–15 items and genuinely cruel at 100.

### Capacity, felt rather than counted

Each ribbon chip carries a 3pt load bar filling against that day's known free time. Over
capacity, the bar overshoots into a warm amber cap — never red, never blocking, and always
paired with text for non-color access ("fuller than it looks"). The number stays available
in the day lane header; the bar is what you actually plan against.

### Meetings

Each meeting row in the day lane shows its real RSVP as a quiet text badge (Accepted /
Tentative / No reply / Declined) and *one* LifeBoard control: **In my week** or **Skipping**.

Defaults are derived, never asked:
- accepted + busy → In
- declined, cancelled, or free → not a decision at all; excluded and not shown
- tentative or no-reply + busy → In, marked undecided, reserving time conservatively

Choosing *Skipping* releases those minutes into the day's load bar **immediately**. That
visible payoff is the entire reason the control exists; without it "skip" is bookkeeping.
Pending invitations get "Respond in Calendar", which opens the EventKit detail surface —
LifeBoard never claims to have changed the invitation.

### Week intention

Collapsed at the top: one focus line, up to three outcomes, habits, minimum-viable-week.
Available, never a gate. The wizard's four steps become one optional disclosure.

---

## Part 3 — Delivery slices

Each slice ships on its own and is useful on its own. The wizard stays reachable until Slice 5.

| # | Scope | State |
|---|---|---|
| **1** | Ribbon + selected-day lane + tray with `+` placement + inline composer. Placement writes `planningDay`. Immediate apply with Undo. Target of "Plan the week". | **Built** |
| **2** | Overdue entry: briefing, bulk spread, Someday bankruptcy, multi-select, swipe moves. `AppRoute.weeklyPlanningWorkspace(.overdue)`, `HomeContextCandidate.route`, Home routes via `router.navigate`. | **Built** |
| **3** | Capacity bars against free windows; meeting Attend/Skip. `CalendarCommitment` extended with occurrence identity, participant status, event state (backward-compatible decoding). Decisions persist per week+occurrence. | **Built** |
| **4** | Drag & drop onto ribbon chips, into the day lane, and onto a row to reorder. Intra-day rank on `pinOrder`. Best-fit time-boxing into a free window. Keyboard/VoiceOver equivalents for every drag. | **Built** |
| **5** | Intention and outcomes folded into one disclosure, reusing `WeeklyPlannerViewModel`. `.weeklyPlanner` now renders the workspace; the wizard is unreachable. Natural-language dates in the composer. | **Built** |

**Persistence note.** The original plan opens with a new
`TaskModelV3_WeeklyPlanningWorkspace` model version and a CloudKit
`WeeklyMeetingDecisionRecord` before anything ships. Neither was needed. `planningDay` and
`pinOrder` already exist, so **no schema change was made at all**. Meeting decisions are
opinions about one week's calendar — worthless once the week passes, and they must never leave
the device — so they live in `WeeklyMeetingDecisionStore` as JSON keyed by
`weekStart + occurrenceKey`, pruned to eight weeks. The shape promotes to a record cleanly if
cross-device sync is ever wanted. A model version is a one-way door; it should not be opened
for data whose whole nature is temporary.

### Two decisions worth recording

**A typed day means placement, not a deadline.** `TaskCaptureParser` returns a recognised date
phrase as `dueDate`, which is right in a capture sheet. In a field that says "Add to Thursday",
a user typing "Friday" is saying where to put it. `WeeklyComposerPlacement` therefore routes
the parsed date to `planningDay` and never writes `dueDate` — the same rule as every other
placement in this surface. A date already past is ignored rather than honoured, so a typo is
not the one path around the refusal to place work in the past.

**Time-boxing is best-fit, not first-fit.** Packing the earliest gap leaves an unusable scatter
of fragments behind it. Choosing the *tightest* window that still fits keeps the long
uninterrupted stretches intact, which are the only windows deep work can go in.

### What is still open

- **`SunriseWeeklyPlannerView` and `WeeklyPlannerViewModel`'s step machinery still exist on
  disk.** `.weeklyPlanner` now renders the workspace, and the wizard's route host is deleted,
  so nothing in the product can reach it. The files are not deleted because
  `WeeklyOperatingLayerViewModelTests` (~700 lines) covers the weekly-plan persistence path
  through that view model, and the workspace reuses the same model for its intention section.
  Deleting the view is safe; deleting the *step* API would delete that coverage without
  replacing it. Do it as its own change, with the tests rewritten against the section.
- **Habits in the intention section.** Focus statement, outcomes and minimum-viable-week are
  in; the habit picker is not. `WeeklyPlannerViewModel` already exposes `availableHabits` and
  `selectedHabitIDs`, so it is a view addition, not a model one.

---

## Part 4 — Verification

Carried over from the original plan, minus the commit-machinery tests that no longer have a
subject, plus what the new model needs.

**Routing (done):** selected root always rendered including initial restoration, rapid
Home↔Plan changes, reduce-motion, and Eva eviction. iPhone UI regression tapping Plan from
Home with a large overdue seed, with no empty-root interval.

**Covered by `WeeklyPlanningWorkspaceTests` (56 tests, passing):** load fractions including
the no-working-hours case; every load state having words as well as a colour; the concrete
window following today rather than the week start; past days listed but refusing placement;
spread filling earliest-first, respecting work already on a day, stopping at capacity rather
than overfilling, costing unestimated tasks, falling back to a count cap when capacity is
unknown, and the 120-item case; meeting defaults for accepted/tentative/pending/declined/
cancelled/free/no-attendees; stale overrides on cancelled events being ignored; skip
releasing capacity; recurring-occurrence keys differing across weeks but not across times on
one day; `CalendarCommitment` decoding without the three new fields; decision-store
round-trip, clearing, persistence and pruning; briefing copy carrying no judgement; and
route round-trip through restoration with the wizard route still decoding; reorder including
the three no-op fumbles and unranked work sorting after arranged work; best-fit time-boxing,
its refusal when nothing fits, and its refusal of a window whose remaining portion is too
short; and composer resolution for a typed day, a past date, a duration, a date-only line, and
end-to-end through the real `TaskCaptureParser`.

**Verified on device:** Plan opens clean on first visit; "Plan the week" opens the workspace;
`+` places a task and updates the tray count, header count, day summary and chip load bar in
one pass; selecting a different chip retargets the lane and the composer; the composer creates,
clears, stays focused, and moves capacity by the assumed 30 minutes; placements survive a
relaunch; "Later this week" expands to the full seven days; the intention disclosure renders
focus, outcomes and minimum-viable-week; and "Call the studio friday for 45 min" typed into
*Today's* composer lands on Friday with a 45m estimate and Friday's capacity dropping from
9h 30m to 8h 45m.

**Still to verify:** light/dark and all semantic dayparts; iPad side-by-side layout; accessibility
sizes; reduced motion and reduced transparency; VoiceOver and Switch Control over the ribbon and
the "Move to…" actions; a real 100+ overdue seed end to end; real EventKit events across
accepted/tentative/declined/recurring/moved, and denied or stale calendar access.

**Gate:** compare against the *actual* pre-existing failure set. On this tree the full
`LifeBoardTests` run is 2143 tests with 2 failures —
`LifeBoardEvidenceContractTests.testSensitiveDomainsStayOffInsights` and
`LifeOSFoundationContractTests.testWellnessNormalizedEventIsSensitiveAndUsesCaptureDay` —
both in uncommitted HealthSync/Wellness work and neither touching any file in this change.
Do not treat a green targeted subset as a green baseline.
