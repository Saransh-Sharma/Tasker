# LifeBoard: what to improve, refine, and build next

> **Classification:** Dated research snapshot. Recommendations, not current capability; current behavior is defined only by the [Feature Catalog](../../product/FEATURE_CATALOG.md).
> **Audience:** Product owner, design, and engineering
> **Capability status:** Snapshot. File paths, line numbers and competitor facts are as of the dates below and will drift.
> **Source authority:** Code at `ce572e9e7`, the living docs, six code audits, and competitor research as of 2026-09-30
> **Last verified:** 2026-10-06

## How this was built

- **Docs read:** the PRD, feature catalog, completion ledger, milestone log, the 2026-09 platform audit, the design contract, the Eva roadmaps, the user guides, and the April Structured AI teardown.
- **Code audits:** Track, Health, Journal, Insights and Onboarding; Eva, the backend and business; and the planning core in two parts (Focus, Daily Loop, Weekly and system surfaces; Capture, Tasks, Home and Plan).
- **Competitor research:** about 60 apps across planning, tracking and reflection, AI, the iOS 27 platform, and pricing.
- **Checking:** every high-stakes claim was re-checked in code. Two audit claims were wrong and are corrected below. Anything not re-checked is marked *per audit*.

**Working assumptions:** growth and depth for current users before new surfaces; people with overloaded days or executive-function friction as the first audience; pricing, calendar write-back, default modules and Apple's cloud model treated as open questions; one person plus AI agents as capacity.

**Decisions this respects:** ship every feature; one Cloud Eva consent screen with categories pre-checked; personas stay; XXXL layout deferred; Mac stays Catalyst; external calendar events are never edited.

## Verdict

**Already best in class. Protect these.**
- **Receipts and Undo on every change, including AI changes.** The top complaints about AI planners are Structured's AI adding tasks with no edit step and Motion reshuffling silently.
- **Recovery as a daily loop** (Rescue, Repair, Minimum Viable Day, Close, Rest). Structured charges for its Replan feature, and Tiimo users complain that unfinished tasks vanish. If LifeBoard ever charges, keep recovery free.
- **Separate When and Deadline**, as Things does. Plan respects it, but Home, search and Eva reschedule paths still overwrite the deadline (Improve 3a).
- **How Insights reasons.** Usual-range bands, correlations described with confidence words, and "try it for a week → did it help?" experiments. This is ahead of Exist and Bearable.
- **Versioned, branching routines** with frozen run snapshots. This is structurally ahead of Routinery and Tiimo.
- **Private by default**, with on-device dictation and a distinctive warm design.

**What's holding it back**
1. **No revenue and no data on how the launch is going.** The app is free with no in-app purchases. Analytics is jammed (confirmed in code; whether the deployed server matches is unchecked), and there's no crash reporting.
2. **It missed the iOS 27 launch window.** iOS 27 shipped Sep 14 with Siri AI and App Schemas. Within about two weeks, Things, OmniFocus, Fantastical, Todoist, TickTick, Structured and Tiimo all shipped Siri support. LifeBoard is still on the iOS 26 SDK, with no App Schemas and no Spotlight entity indexing.
3. **Many modules are shallower than they look.**
   - Nutrition has no food database.
   - "3 times a week" habits aren't modelled as weekly.
   - Track's Today view shows no habits.
   - Four review screens don't connect to each other.
   - The XP engine is hidden in the app, yet the capability matrix says "Available".
   - New users see empty module cards before they see their day.
4. **Key surfaces have never run on a real device:** Live Activities, interactive widgets, Control Center controls, the Watch, two-device sync, and Cloud Eva end to end.

**The move.** Be the calm planner for days that don't go to plan. Lead with the Daily Loop and an assistant that never changes anything without a receipt. Treat health, nutrition and medication as integrations that read Apple Health, rather than competing with specialists like MacroFactor or Medisafe.

## Top 15, in order

| # | What | Kind | Size | Why now |
|---|---|---|---|---|
| 1 | Unjam analytics; add retention and crash signals | Improve | S | You can't learn anything from the launch without it |
| 2 | One privacy text, reviewed by counsel | Improve | S | The two texts disagree, and App Review 5.1.2 now covers third-party AI |
| 3 | Fix deadline and habit correctness | Improve | M | Rescheduling from Home, search or Eva overwrites the deadline, breaking the When-vs-Deadline promise; the default Count habit is wrong; habit links dead-end |
| 4 | File the Apple paperwork that takes weeks | Admin | S | Small Business Program, Apple's cloud model entitlement, Screen Time entitlement (reported 10–20+ days) |
| 5 | Shrink the download and refresh the store page | Improve | S | 226 MB listed against the 200 MB cellular prompt (confirm the thinned size); ~26 MB of unused art; rating reset |
| 6 | Siri and Spotlight on iOS 27 (App Schemas) | Build | M–L | Competitors already shipped; Siri AI finds apps through their intents |
| 7 | LifeBoard Plus subscription (StoreKit 2) | Build | M | No revenue, and cloud cost is limited only by one global spending cap |
| 8 | Trial Eva on Apple's cloud model | Build | M | Free for small developers, the strongest privacy story, and no accounts or credits |
| 9 | Brain-dump and photo capture | Refine | M | Todoist Ramble, Tiimo and Structured set the bar; LifeBoard captures one item at a time |
| 10 | Now → Next countdown | Refine | M | The feature Tiimo users praise most for time blindness |
| 11 | Recovery refinements | Refine | M | Show how long tasks have been rolling over, a "park it" option, a skipped Close folded into the next morning, projected finish time |
| 12 | Habits and mood connected to Apple Health, plus reminder buttons | Refine | M | Confirm-to-complete chip and State of Mind both ways. Habit, medication, tracker, fasting and focus reminders have no buttons today; only task reminders do |
| 13 | Morning brief (Day Compass) | Build | M | `DailyBriefService` is built but never shown |
| 14 | Proposals drawn on the Plan timeline, plus an Eva activity log | Build | M | Answers the main reason people distrust AI planners |
| 15 | Focus Shield (app blocking via Screen Time) | Build | L | The biggest Focus gap; gated by the entitlement in #4, so file early |

## Improve — confirmed defects

**1. Analytics is jammed** (verified in code; check what's actually deployed before assuming it's live)
- **Batch size:** the app sends its whole pending queue (cap 200) in one request (`LifeBoard/Services/ProductTelemetry.swift:89,163-165`). The server accepts at most 32 (`Services/EVACloud/src/routes/product-events.ts:40`). Failed batches are kept and retried, so once more than 32 events queue up, nothing gets through again.
- **Event names:** the app sends 8 events the server's list doesn't include (`product-events.ts:7-21`): `connectionInvitationDeclined`, `connectionInvitationShown`, `evaActivationAndSendCompleted`, `evaActivationAutoResumed`, `evaInlineActivationShown`, `evaReadinessHydrated`, `evaSetupCenterCTAShown`, `healthDataFirstObserved`. A single unknown name rejects the whole batch.
- **Fix:**
  - Send in chunks of 32 or fewer.
  - Generate the allow-list from one shared source (the repo already shares Swift/TypeScript contracts) and add a test that the two can't drift.
- **Then add the missing signals:**
  - Retention signals that carry no personal content: active on day 1/7/30, first plan, first Close, first Rescue, first applied proposal.
  - Crash reporting. MetricKit already collects crash data locally; upload aggregated reports, or rely on Xcode Organizer.

**2. Two privacy texts disagree** (verified)
- **The two texts:**
  - `public/privacy/index.html` is a draft dated 2026-09-28. It names Cloudflare and OpenAI, its own comment says the Settings row links to it, and it is marked "must be reviewed by counsel".
  - `src/App.tsx:457` (the website's `PrivacyContent`) says "explicit account opt-in" and names no provider.
- **They will collide:** the site build copies `public/` into its output, so both texts claim `/privacy/`. The last local build (`dist/`, Aug 24) predates both.
- **Fix:** make one text canonical, get counsel review, redeploy.
- **The audit also got this wrong:** it said no privacy text names OpenAI. The static draft does; it just isn't served.
- **Correction to the audit:** Cloud Eva does *not* contact the service before consent. `hasConfirmedCloudConsent` requires an explicit user choice (`LifeBoard/Features/Onboarding/LifeWeave/LifeWeaveEvaActivation.swift:227`). The stale part is `docs/eva/RISK_REGISTER.md` R19, which still says sensitive categories are off by default; you chose pre-checked. Fix the doc, not the code.

**3a. Rescheduling outside Plan overwrites the deadline** (verified)
- **What happens:** `RescheduleTaskDefinitionUseCase.execute(newDate:)` passes the new date as `deadlineDate` to `TaskScheduleNormalizer.normalize` and writes it to `dueDate` (`LifeBoard/Features/Tasks/Domain/RescheduleTaskDefinitionUseCase.swift:57-69`).
- **Who calls it:** Home task actions (`HomeViewModel+TaskActions.swift:134-140`), Home search (`HomeSearchViewModel.swift:332`), the navigation adapter (`HomeNavigationEventAdapter.swift:434`), `AddTaskViewModel.swift:773` and the use-case coordinator. *Per audit*, Eva and bulk actions do too.
- **Why it matters:** PRD line 85 says moving work to a day must never rewrite its deadline. Plan's own surfaces were already fixed to respect that; these paths weren't.
- **Fix:** route these "move to a day" actions through the same planned-day mutation Plan uses. Keep a separate, explicit "change deadline" action.
- **Related, *per audit*:**
  - The parser has no deadline token: "by Friday" means the same as "Friday" (`TaskCaptureParser.swift:308,401`).
  - The main task editor's "Deadline" chip writes the due date, but no deadline countdown is shown anywhere.

**3b. Habit correctness**
- **Weekly and monthly count targets have no amount target** (verified). `HabitAmountRule.target` returns nil unless the period is a day (`LifeBoard/Features/Habits/Domain/HabitRuntimeUseCases+Amount.swift:36-37`). Yet the editor's default Count target is `.quota(count: 3, period: .week)` (`AddHabitSheetView.swift:869`).
  - *Per audit*, these habits then act like daily check-ins and break their streaks.
  - **Fix:** confirm with a test, then model weekly quotas properly, as Streaks and Habitify do.
- **The habit link screen is a dead end** (verified). The `.habitDetail` route shows a read-only card whose only button switches to the Track tab (`LifeBoard/Foundation/Navigation/FoundationHabitAndTrackerRoutes.swift:7-28`).
  - *Per audit*, reminders, widgets, deep links and Eva all land there.
  - **Fix:** route it to the real `HabitDetailScreen`.
- ***Per audit*, also worth fixing:**
  - Reminders still fire after the habit is done.
  - Every-N-days habits get no reminder.
  - The "Minimum version" and streak-display settings are saved but never read.
  - Three separate streak calculations can disagree.
  - Vacations only protect Track's grade.
  - **Fix:** merge everything into one streak service.

**4. Download size and the store page**
- **Unused art:** about 26 MB of `TaskCard01–06` images are used only by `LifeBoard/Features/Eva/UI/SunriseEvaSheets.swift:1521`, which the platform audit already lists as dead UI (verified). Delete both, along with the rest of that list.
- **Large live art:** `AmbientSurfaces` (44 MB) and `HomeCardScenes` (44 MB) are PNG. Try HEIC or lossy compression, or deliver scene packs on demand with Background Assets.
- **Check the real size:** look at App Store Connect's App File Sizes report. The cellular prompt uses the thinned download size, which may already be under 200 MB. Peers are bigger (Todoist 389 MB, Structured 291 MB, Tiimo 250 MB), so size only matters at the prompt.
- **Store page:**
  - The screenshots probably still show the old dark design. The local screenshot files and an open audit item suggest it; confirm on the live listing, then re-shoot.
  - The rating was reset. Ask for a rating only after earned moments (a third applied proposal that wasn't undone, a finished Weekly Reset, the first run of closed days), at most 3 times a year, and don't reset again.

**5. Smaller confirmed items**
- **Daily brief:** `DailyBriefService` is referenced only by tests. Wire it up (see #13) or delete it.
- **Nutrition lookup:** `openFoodFacts` is just an enum case (`LifeBoard/Features/Nutrition/Domain/NutritionModels.swift:84`) with no lookup behind it. *Per audit*, barcode scans only match foods already in the library. See *Stop / decide*.
- **Cloud Eva spending cap:**
  - **How it works:** production allows $150 a day (`Services/EVACloud/wrangler.toml:148`, `DAILY_BUDGET_MICRO_USD = 150000000`). Once that is spent, `GlobalBudgetDO` refuses every user.
  - **What to keep:** the cap is sensible cost protection.
  - **What to design:** what happens when it's hit. Fall back per user to offline or deterministic answers, say so honestly, and alert yourself at 50% and 80%.
- **Is Cloud Eva actually live?** The docs disagree. `EVA_ROADMAP_STATUS` says it is shut while secrets are missing; the Sep 16 ledger says it is live at 100%. `npm run config:verify:production` settles it.

## Refine — existing features vs. best in class

> The "Today" facts in these rows come from the code audits (*per audit* unless marked verified). Re-read the cited file before building.

| Feature | Best-in-class mechanic | Refinement for LifeBoard |
|---|---|---|
| Capture | **Todoist Ramble:** speak freely, tasks appear as live cards, correct them by voice, add them all at once | **Today:** one entry becomes one task (`LifeThreadComposerIntent.swift:118-131`), and Eva's quick-capture lane caps at 3 items, none of them tasks. Typed text with a date or a starter word saves in 2 taps, but short phrases add an "Ask Eva or save as task?" step. **Brain-dump mode:** dictation or a pasted list turns into several chips. Your parser fills in the fields; AI only splits the items. The visible chips are the review step, so this stays within the PRD's rule that classification never saves silently. One commit, one receipt, one Undo for the batch. Add a capture control for the Lock Screen and Action button. **Parser gaps:** monthly and yearly repeats, and "by <date>" as a deadline |
| Capture | **Tiimo** "snap notes to tasks"; **Structured** accepts several images | Photo or screenshot → on-device text recognition → chips, behind the same commit step. A VisionKit document scanner already exists in Knowledge (`LifeBoardDocumentScanner.swift`) to build on; three VisionKit imports elsewhere are unused |
| Home | **Tiimo** Now & Next with a visual countdown; **Things** Today shows only what's scheduled or due | **Today:** Now shows only "Next: X" with a start time, and "N min left" appears only for something already in progress. The fixed order for choosing Now lets a meeting hours away beat must-do work, and task priority is ignored (`HomeLifeOSProjectionStore+FocusHero.swift:44,69-132`). **Refine:** a Now → Next card with a remaining-time ring and a heads-up before each transition, on Home, the Live Activity, a widget and the Watch. Let must-do and high-priority work beat distant events. For new users, lead with the day and hide cards with nothing to say (for example "No routines are due") |
| Plan | **Structured** Energy Monitor; **Sunsama** projected finish vs. shutdown time; **Tiimo** reshuffle when you're running late | **Today:** capacity is time only, with energy used only to rank Focus (`PlanningCoreModels.swift:250-274`). There's no projected finish and no day-wide shift. Rollover counters already exist (`Models_Task.swift:46-47`), but "Moved N times" appears only in an unused overlay and an Eva-only screen. **Refine:** an energy band next to the time-overload band, a "finish ≈ 7:40 pm" line, "Shift rest of day +15 min" with a receipt, and the rollover count shown on Plan and Home rows |
| Recovery | **Sunsama** rollover count and auto-archive; **Structured** Replan "push to inbox"; **Akiflow** turns a skipped shutdown into the next morning's first step | **Today:** a skipped Close is lost. The morning shows leftovers read-only and pre-selects at most 3 tasks. Mornings that keep being skipped auto-confirm with nothing selected (by policy, `DayCloseStore.swift:202-210`). **Refine:** make Close's "What's left" sort step 1 of the next Commit; add a badge showing how many days a task has rolled over and a "Park" (Someday/Inbox) swipe in Rescue; leave recurring items out of Rescue by default; after 3+ rollovers, have Friction Detective offer split, shrink or drop |
| Close and Commit | **Sunsama** shows the calendar while you plan and shut down | Close and the morning review can't show the day's meetings: the calendar isn't read there, by design, so they say "unavailable" (`DayCloseStore.swift:166-170`). Read the same calendar data Plan already uses. Also, user-set ritual times move only the notifications; Home's morning and evening windows stay fixed at 05:00–11:00 and from 18:00 (`DayCompassEngine.swift:4-6`). Make Home follow the user's ritual times |
| Tasks | **Things** asks "just this one, or change the rule?"; **Todoist** 7-day deadline countdown; **OmniFocus** review interval per project | **Today:** each repeat is its own row, so editing one occurrence works implicitly, but there's no "this one or all future" choice and delete removes the whole series. There are three task editors with different fields: the add sheet, `TaskRouteView` (no energy, context, evening or bucket), and `TaskDetailScreen`, reachable only from Eva. "Someday" means two things: a bucket, and "no date". **Refine:** one editor with progressive fields, a this-one-or-all prompt, a single meaning for Someday plus a Tonight option, a deadline countdown chip, and a review interval per project that feeds Weekly Reset |
| Weekly | **Sunsama** weekly objectives plus a chart of time spent on them | **Outcomes already exist:** you set them in the This Week workspace's intention sheet and review them in Weekly Reset. **Refine:** have the morning Commit draw from them, and show hours by outcome or area. **Merge the four review screens into one weekly flow:** in Release, Weekly Reset silently replaces Plan's weekly review route; Journal's weekly reflection isn't linked; Insights' monthly review only counts things |
| Habits | **Streaks** completes habits from Health data; **Gentler Streak** pause days; **Duolingo** streak freezes (raised daily active users); **Atoms** "never miss twice" | A confirm-to-complete chip ("Health shows 8,214 steps — mark *Walk* done?"); pause and vacation respected by every streak; weekly-cadence streaks; a gentle "never miss twice" nudge; a year-grid view |
| Mood | **Apple State of Mind** (HealthKit); **How We Feel** two-axis meter | One mood record (*per audit*, there are two storage paths today), written to and read from State of Mind, with reasons mapped to its associations |
| Journal | **Day One** uses Journaling Suggestions; **Apple Journal** on iOS 27 adds AI prompts and streak modes | The Journaling Suggestions picker, on-device follow-up prompts grounded in the day, a daily journaling reminder, and full export |
| Insights | **Exist:** needs 3 weeks of data, shows a confidence rating, uses plain language | Require 21 days or label results "early signal"; guard against false positives (for example "held in 3 of 4 weeks"); phrase results as "Days with X: mood +0.6"; add mood, custom trackers, water and individual habits to the analysis (*per audit*, it covers 7 data series today) |
| Routines | **Routinery** reads each step aloud and auto-advances; **Tiimo** estimates step times | Spoken step guidance, an estimated finish time ("Done by 7:42"), and planned vs. actual step times |
| Focus | **Tiimo** visual countdown with music; **Llama Life** counts down a whole list | 4–6 ambient sound loops and a "Run my list" countdown. Add break and round state plus skip-break and add-time to the Live Activity, which today has only Pause/Resume and End. App blocking is under *Build next* |
| System surfaces | **Opal** starts a session from a small widget in two taps; **Todoist** offers capture from widgets and the Lock Screen | Make controls act in place: the Capture control opens the app even though an in-place capture intent exists, and Start Focus also opens the app. Add buttons to reminders: tasks have Complete and Snooze, but habit, medication, tracker, fasting and focus reminders have none (`LocalNotificationService.swift:188` is the only place a category is set). Let the Watch complete tasks and run Focus. Let Share accept images and files, which the feature catalog already claims; today it takes text and links only |
| Fasting / water | **Zero** fasting protocols; **WaterMinder** tracks caffeine | Protocol presets such as 16:8; drink presets with a hydration factor and caffeine, written to Health |
| Eva | **Notion** logs every agent run and makes it reversible; **Temporal** offers Suggest / Auto / Off | An activity log; an autonomy setting per ritual (Suggest by default, Auto only for low-risk additions like breaks); a label on every answer saying where it ran (on-device, Apple cloud, OpenAI) |

## Build next — new capabilities, ranked

**A. Siri and Spotlight on iOS 27.** This needs Xcode 27; only 26.5 is installed, and there's 86 GiB free.
- **Schemas to adopt:**
  - `@AppIntent(schema: .reminders.createReminder / .updateReminder / …)` for tasks, with lists mapped to projects or areas.
  - `.notes` for Knowledge.
  - `.system.searchInApp` and `.open`.
  - The journaling schema, which works in Shortcuts only, not Siri.
  - SiriKit's task intents are deprecated in iOS 27.
- **Missing intents.** Today there are 27 intent types and 10 App Shortcuts, but no task entity, so Siri can't complete a task. There are also no intents for starting or closing the day or for pausing or stopping Focus. Add those first.
- **Spotlight and on-screen awareness:**
  - Make tasks, habits, notes and projects `IndexedEntity`.
  - Add View Annotations on Home rows, the Plan canvas and Backlog, so Siri can act on what's on screen ("move this to tomorrow").
- **Rules for Siri changes:**
  - Map Siri's single date to When, and ask for a Deadline as a follow-up. Things ran into this exact problem.
  - Turn multi-item Siri changes into an Eva proposal.
  - Post a receipt with Undo for every Siri change.
  - Cover the integration with AppIntentsTesting.
- **Widgets:**
  - An extra-large "Today" widget (`systemExtraLargePortrait`).
  - Polish for the Liquid Glass accented rendering mode.
  - Landscape and StandBy layouts for Live Activities.
  - Free up App Shortcut slots by merging shortcuts into parameterized ones (the cap is 10).
  - There's no design opt-out risk: `UIDesignRequiresCompatibility` isn't set, so the app already uses Liquid Glass.
- **Reality check:** Siri AI is in beta and waitlisted, English-only until October, absent on EU iPhones, and needs an iPhone 15 Pro or later. Widgets and controls stay the main paths.

**B. LifeBoard Plus (StoreKit 2)**
- **Tiers:**
  - **Free forever:** capture, tasks, Plan, habits, journal, the whole recovery loop, and Eva running on-device or on Apple's cloud model.
  - **Plus:** OpenAI-backed Eva beyond a fair-use limit (never show credits), advanced Insights (experiments, long-range trends), Focus Shield, larger offline models, and premium atmospheres and widgets.
- **Price:**
  - **Anchors:** Structured about $28–30/yr (price-tested), TickTick $49.99/yr, Todoist $59.99/yr, Tiimo $54–79.99/yr (sources conflict).
  - **Suggestion:** about $4.99/mo or $39.99/yr.
- **Trial:** 7 days on the annual plan, A/B tested against 14. RevenueCat's data shows longer trials convert better, but AI apps flatten beyond 16 days.
- **Paywall:**
  - **Placement:** a soft paywall on onboarding's Ready screen, and again after the first applied proposal.
  - **No dark patterns:** Cal AI was pulled from the App Store in April for a deceptive paywall.
- **Implementation:**
  - Use `SubscriptionStoreView`. The Worker already depends on Apple's App Store Server library for server-side checks.
  - This ships as an update to existing users (bundle `com.saransh1337.To-Do-List`). Offer them goodwill, such as a free month or a lifetime offer for early users.

**C. Trial Eva on Apple's cloud model, then decide**
- **What it is:** iOS 27's `PrivateCloudComputeLanguageModel` runs on Apple's Private Cloud Compute.
  - 32K context and tool calling.
  - Free for members of the Small Business Program with fewer than 2M first-time downloads. Enrolling also drops Apple's commission to 15%.
  - Each user has a daily limit; Apple doesn't publish the number and shows its own upgrade sheet.
- **Why this isn't a reversal:** Apple's on-device model was removed during the cloud migration, with no reason documented. The removed model was the small on-device one with a 4K context, which is a different proposition from this one.
- **The trial:**
  - Add it behind the existing provider setup using the `LanguageModel` protocol and a Dynamic Profile. Order: on-device first, then Apple's cloud, then OpenAI only for devices or regions that aren't eligible.
  - Run the 123-case router test set and the 13-case privacy test set, and compare against Luna.
- **If it passes:**
  - Make it the default on eligible devices. Those users then need no account, no credits, and no DeviceCheck setup.
  - **Constraints:**
    - It needs an iPhone 15 Pro or later on iOS 27.
    - The per-user daily limit applies.
    - EU availability is unclear.
    - Apple's privacy guarantees don't extend to third-party models.
- **Bonus:** the same framework adds on-device image input plus `OCRTool` and `BarcodeReaderTool`, which power photo capture and label scanning without a server.

**D. Morning brief (Day Compass)**
- Connect `DailyBriefService` as an opt-in brief the user schedules: a notification plus a widget at a chosen time, auto-paused after it's ignored a few times. ChatGPT retired its pushed Pulse feed in favor of scheduled tasks the user controls.
- **Content:** today's fixed calendar, what fits, what doesn't, one tradeoff, and one tap into a reviewable plan.

**E. Proposals drawn on the Plan timeline, plus an activity log.** Today this is deferred behind the `evaTimelineInlineDiff` flag. Show ghost, moved and removed blocks on the canvas before Apply.

**F. Focus Shield (Screen Time)**
- Use FamilyControls individual authorization with ManagedSettings to shield distracting apps during Focus presets and time blocks.
- Default to a soft mode in the style of one sec: a pause before the app opens. A PNAS study measured 57% fewer opens. Hard mode is opt-in and always has an emergency exit.
- The distribution entitlement is requested per app and per extension. Apple publishes no turnaround; reports say 10–20+ days. File now.

**G. Habits from Health, and AlarmKit**
- Link a habit to a Health metric. A chip asks before completing, which keeps your "never complete silently" principle.
- Use AlarmKit for opt-in hard-start time blocks, fasting end and routine timers. Its alarms break through Silent mode and Focus.

**H. Multi-device for sensitive records, plus portability**
- **Sensitive records:**
  - **Today:** Health, mood, water, medication, fasting and focus records stay on one device by design (the privacy page says so), so Insights on a Mac or iPad lacks them.
  - **Option:** sync them through Core Data and CloudKit with encrypted attributes (`allowsCloudEncryption`, end-to-end encrypted with the user's iCloud keys), behind an opt-in toggle.
- **Portability:**
  - Whole-app export and delete-all (an open launch item).
  - Then importers from Todoist, Things and TickTick (CSV) to lower switching cost.

**I. Localization**
- **Today:** English only, with 1,137 strings (*per audit*).
- **First languages:** Siri AI's October languages: Spanish, French, Portuguese, Japanese and Korean.
- **Why:** Apple weighs localization when featuring apps.

## Stop / decide

- **Nutrition:** there's no food database.
  - **Read from Health:** nutrition data comes in from Apple Health, which MacroFactor, Cronometer, Foodnoms and MyFitnessPal all write to.
  - **Keep:** quick-add and templates.
  - **Stop building:** storage for recipes, groceries and meal templates.
  - **The barcode button:** implement a real lookup or remove it.
- **Medication:** read Apple Health Medications into the timeline. Third-party apps could read medications starting with iOS 26 (*per research*). Keep care events for non-drug care, and don't build interaction checking.
- **Health scores** (readiness, HRV, recovery): don't build them. Show the raw context instead.
- **Gamification:** the engine (1,517 lines, *per audit*) is hidden in the app, yet `PUBLIC_CAPABILITY_MATRIX` says "Available". Either show tasteful milestones (7/30/60 repetitions), or retire the engine and fix the claim. Avoid currencies and leaderboards either way.
- **Knowledge/Notes:** it's rich, but you can only reach it via Track › Areas. Either promote it (a Home card, a capture destination) or keep it as a quiet module.
- **Home default:** show the day first. Show module cards only when they have something to say.
- **Dead code:** delete the rest of the platform audit's dead-UI list, plus the dead code the audit found: recipe storage, `XPBadge`, `RoutineRouteView`, the unused `StarterWorkspaceCatalog` suggestions, and the legacy `TrackRootView`/`TrackStore`.
- **Docs that claim more than the code.** The PRD's own acceptance rule is that every claim must be verifiable, so fix the docs or build the feature:
  - The Share extension "image or file flows": it takes text and links only.
  - XP, levels and badges listed as "Available": they're hidden.
  - Nutrition's "bundled foods, recipes, meal templates, barcode and remote lookup": there's no lookup, and recipes are storage only.
  - The risk register's consent default (R19).

## Decisions the research would challenge (flagged once, not reopened)

- **Persona names:** the personas named "Elon" and "Steve" carry a likeness risk beyond the App Store 5.2 risk you already accepted.
- **Name collisions:** "Eva — Calendar & Daily Planner" is a free iOS AI planner in the same category, and theLIFEBOARD.app is a weekly planner. Options: let users name the assistant per persona, drop "Eva" from App Store keywords, and get a trademark clearance. This isn't legal advice.
- **External calendars read-only:** the planner feature people ask for most is seeing their blocks in their work calendar (Sunsama, Structured). An opt-in, one-way copy of LifeBoard's *own* blocks into a dedicated "LifeBoard" calendar wouldn't edit anyone else's events.

## Appendix — competitor pricing (US, Sep 2026)

| Category | App | Price |
|---|---|---|
| Planning | Tiimo | $54–79.99/yr |
| Planning | Structured | ~$28–30/yr; lifetime $99.99 |
| Planning | Todoist Pro | $59.99/yr |
| Planning | TickTick | $49.99/yr |
| Planning | Things | $9.99 iPhone, $19.99 iPad, $49.99 Mac, one-time |
| Planning | Sunsama | $204/yr |
| Planning | Akiflow | $19/mo billed yearly |
| Planning | Motion | $19/mo billed yearly, plus credits |
| Habits | Streaks | $5.99 one-time |
| Habits | HabitKit | $11.99/yr |
| Habits | (Not Boring) Habits | $14.99/yr |
| Habits | Finch | ~$69.99/yr |
| Journal and mood | Day One | $49.99 / $74.99/yr |
| Journal and mood | Rosebud | $107.99/yr; free plan ended Sep 30 |
| Journal and mood | Daylio | $35.99/yr |
| Journal and mood | Bearable | $34.99/yr |
| Health and focus | MacroFactor | $71.99/yr |
| Health and focus | Zero | $69.99/yr |
| Health and focus | Opal | $99.99/yr |
| Health and focus | one sec | $19.99/yr |

**The pattern:** capture and a basic list are free. AI, calendar sync, recurrence, advanced views and hard blocking are paid.

## Execution status (2026-10-06)

**Done in the first slice**
1. **Analytics, app side (#1).**
   - `ProductTelemetry` now sends at most 32 events per request.
   - It holds back the 8 names the server doesn't accept yet and fits every field to the server's schema.
   - It drops a batch the server permanently rejects (`schema_invalid`) instead of retrying it forever, and cleans queues saved by earlier builds.
   - Contract tests in `LifeBoardTests/ProductTelemetryContractTests.swift` read the server's route file, so the two can't drift silently. All 6 pass on the iOS 26.5 simulator (2026-10-06).
   - Adding the 8 names on the server needs a Worker deploy by the owner.
2. **Habit links (#3b).**
   - `.habitDetail` now opens the full `HabitDetailScreen`. When it's pushed, it hides the sheet's Close button through the `habitDetailShowsCloseButton` environment value; the shell's navigation bar supplies Back.
   - Covered by the UI test `testFoundationHomeHabitCardOpensTheFullHabitScreen`, which passed twice on the iOS 26.5 simulator.
   - The sheet path (Close still shown by default) couldn't be confirmed by the existing `HabitBoardUITests`, because they don't pass at the base commit either:
     - `testHabitDetailDayTapKeepsCalendarGridMounted` fails the base launch check.
     - `testHabitBoardRowTapOpensHabitDetail` is skipped because no Board row appears.
     - The launch flag those tests rely on, `-LIFEBOARD_TEST_PRESENT_HABIT_BOARD`, has no handler in the app.
3. **Unused art (#5).** Deleted the six `TaskCard0x` image sets (26 MB). The asset catalog went from 141 MB to 115 MB.

**Gates after the slice**
- **Pass:** token-law, premium UI, launch contracts, accessibility-identifier snapshot (982), localization keys (1,137), file size, platform parity, keyboard exits, no-print, documentation.
- **Red, and already red at the base commit:**
  - directory shrapnel (`DesignSystem/HomeCards`, `Eva/Views/Chat/Conversation`).
  - The SwiftLint baseline, where the debt fell below the recorded counts and was never ratcheted (font 19→17, shadow 32→23, UIColor 19→13). None of those rules match code this slice touched.

**Split out: these need a decision or a larger change**
- **Rescheduling overwrites the deadline (#3a).**
  - Home's Tasks card lists tasks by due date (`AddTaskSheetView.swift:293-296`). So if rescheduling alone stopped writing the deadline, "Move to tomorrow" on Home would leave the task on today's list.
  - A real fix moves Home to the effective planned day as well, and checks which callers actually mean "deadline".
- **Weekly and monthly habit quotas (#3b).**
  - No runtime code evaluates a weekly window. The `.week` period is stored and shown, but the habit runs as a daily one.
  - Proper support touches occurrence evaluation, three streak calculators, the Board, Home, widgets and reminders.
  - An interim option is to stop offering week and month in the editor, which is a product decision.
- **`SunriseEvaSheets.swift`.** Three of its types are still exercised by tests in `LifeBoardTests/LifeBoardTests.swift`. That file had unrelated uncommitted changes, so it was left alone. Delete the file and those three test classes together.
- **Privacy text (#2): done 2026-10-07, at the owner's go-ahead.** Counsel review is still owed.
  - `PrivacyContent` in `src/App.tsx` is now the one text. `https://getlifeboard.app/privacy/` serves it, and the in-app Privacy Policy row opens it.
  - It names Cloudflare and OpenAI, says Cloud Eva stays off until you agree, and lists the records that never leave the device. That list was checked against the code: each category is written to the `LocalOnly` store.
  - It adds Reminders access, which the draft left out.
  - The never-served `public/privacy/index.html` was removed.
  - Site build, type-check, lint and `check:marketing` pass.
  - `public/support/index.html` has the same pattern (overwritten by the React page at build) and was left alone.

## Sources (selected)

- **iOS 27 and Apple platform:**
  - [App schema domains](https://developer.apple.com/documentation/appintents/app-schema-domains)
  - [WWDC26: App Schemas](https://developer.apple.com/videos/play/wwdc2026/240/)
  - [WWDC26: Advanced App Intents](https://developer.apple.com/videos/play/wwdc2026/343/)
  - [WWDC26: Foundation Models](https://developer.apple.com/videos/play/wwdc2026/241/)
  - [WWDC26: Private Cloud Compute model](https://developer.apple.com/videos/play/wwdc2026/319/)
  - [WWDC26 Apple Intelligence guide](https://developer.apple.com/wwdc26/guides/apple-intelligence/)
  - [What's new in iOS](https://developer.apple.com/ios/whats-new/)
  - [Requesting the Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
  - [Small Business Program](https://developer.apple.com/app-store/small-business-program/)
- **Planning:**
  - [Tiimo, App of the Year 2025](https://www.tiimoapp.com/resource-hub/tiimo-winner-2025-app-store-awards)
  - [Things 3.24](https://9to5mac.com/2026/09/14/things-3-24-update-arrives-with-os-27-support-siri-ai-integration-new-widget-size/)
  - [Todoist Ramble](https://www.todoist.com/help/articles/use-ramble-to-add-tasks-by-voice-P1Raq7vVF)
  - [Structured Replan](https://help.structured.app/en/articles/4526850)
  - [Structured Energy Monitor](https://help.structured.app/en/articles/998530)
  - [Sunsama daily planning](https://help.sunsama.com/docs/daily-planning)
  - [Sunsama rollover](https://help.sunsama.com/docs/task-rollover-and-recurring-tasks-the-basics)
  - [Akiflow rituals](https://product.akiflow.com/help/articles/0805246-rituals)
  - [one sec PNAS study](https://www.pnas.org/doi/10.1073/pnas.2213114120)
- **Tracking and reflection:**
  - [Streaks](https://streaksapp.com/)
  - [Duolingo streak research](https://blog.duolingo.com/how-duolingo-streak-builds-habit)
  - [HealthKit State of Mind (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10109/)
  - [Day One Journaling Suggestions](https://dayoneapp.com/guides/day-one-ios/journaling-suggestions/)
  - [Journal in iOS 27](https://9to5mac.com/2026/06/11/heres-everything-new-for-journal-in-ios-27/)
  - [Exist correlations](https://kb.exist.io/article/37-what-are-correlations)
  - [MacroFactor AI logging](https://macrofactor.com/ai-food-logging/)
  - [Rosebud free plan change](https://help.rosebud.app/account/changes-to-the-free-plan)
- **AI and business:**
  - [RevenueCat State of Subscription Apps](https://www.revenuecat.com/state-of-subscription-apps)
  - [RevenueCat trial length](https://www.revenuecat.com/blog/growth/free-trial-length)
  - [AI feature costs and margins](https://www.revenuecat.com/blog/growth/ai-feature-cost-subscription-app-margins)
  - [Apple: getting featured](https://developer.apple.com/app-store/getting-featured/)
  - [HIG: ratings and reviews](https://developer.apple.com/design/human-interface-guidelines/ratings-and-reviews)
  - [Notion agents](https://www.notion.com/product/agents)
  - [ChatGPT Pulse retirement](https://www.digit.in/news/general/openai-is-retiring-chatgpt-pulse-and-replacing-it-with-scheduled-tasks-here-is-why.html)
- **Listings checked:**
  - [LifeBoard on the App Store](https://apps.apple.com/us/app/lifeboard-daily-ai-planner/id1574046107)
  - ["Eva — Calendar & Daily Planner"](https://evacalendar.app/)
  - [theLIFEBOARD.app](https://thelifeboard.app/)
