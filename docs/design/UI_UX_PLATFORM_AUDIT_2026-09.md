# iPhone · iPad · Mac platform audit and remediation (2026-09)

> Classification: Platform audit and remediation record
> Audience: Product, design, engineering, and QA
> Capability status: Current workspace
> Source authority: LifeBoard shell, design-system and feature sources, their unit and UI tests, and the repository gates
> Last verified: 2026-09-28

Scope: every root, the major pushed screens and sheets, and the shared design-system primitives, judged on iPhone, iPad (Split View, Stage Manager) and Mac Catalyst ("Scaled to match iPad").

Decisions taken with the product owner:
- Mac stays Catalyst in iPad-scaled mode.
- iPad and Mac keep the DESIGN.md top five-root switcher.
- iPad and Mac keep the per-class typography scale-up.
- The Mac window minimum is 760 × 600.
- The privacy shield covers Journal only, and on the Mac only when the app leaves the screen.
- Dead UI is deleted.
- Largest-text-size (XXXL) layout work stays deferred (MILESTONE_ONE_TODO:156).

## Grades before this pass

| Area | iPhone | iPad | Mac |
|---|---|---|---|
| Home | A- | D | D- |
| Plan / Weekly | B | C- | D |
| Journal / Focus / Day loop | B | D | D- |
| Track / Habits | B- | D | D- |
| Eva / Settings / Onboarding | A- | C- | D+ |

iPhone was solid. iPad and Mac were running the phone app, stretched.

## Root causes (systemic)

1. **The layout class was never set.** `\.lifeboardLayoutClass` defaults to `.phone`. `FoundationShell`, Eva and Settings were hosted without injecting it, so about 79 `layoutClass.isPad` branches and every `ScreenScaffold` readable-width cap were dead on iPad and Mac.
2. **Root dashboards had no width cap.** `.ambient` had no readable width, so Home, Plan, Track and Insights ran edge to edge, with phone cards stretched to ~1300 pt.
3. **Two shell trees behind an `if`.** Resizing a Split View pane or a Mac window across the breakpoint rebuilt every root, discarding Eva's unsent draft and open thread.
4. **No Mac or keyboard chrome.** There was no menu bar, no Esc, no window minimum, ⌘N was bound twice, and the only root shortcuts were hidden and existed only in the expanded shell.
5. **Full-screen covers everywhere.** A mood dial or a ritual took over a 13-inch display or a whole Mac window.
6. **Gesture-only actions.** Some actions could only be reached by swipe, long-press or hold (medication undo, weekly multi-select, completing a habit ring, the mood dial), and several targets were 22–34 pt.
7. **Whole-app privacy shield on focus loss.** It went up on every scene deactivation, so on the Mac every click into another app blanked LifeBoard.
8. **Unsigned Catalyst builds crashed at launch.** CloudKit traps when the iCloud entitlement is missing, and nothing checked for it.

## What changed

### P0 fixes
- **Capture sheet.** The floating ✕ sat on the New Task "Done" button, so tapping Done discarded the capture. Each capture host now has exactly one close control (`FoundationCaptureHosts.swift`).
- **Routine runner.** It could not be dismissed without ending the routine. It now has Minimize and a Resume banner, and the minimized state is persisted across stores (`TrackFoundationStore.swift`, `LifeBoardTrackFoundationViews.swift`).
- **Weekly wide board.** The per-column "Add" focused a field that was off screen. The board now carries its own composer; rows get a context menu, hover and VoiceOver move actions; tray search and tray-row menus are present side by side (`WeeklyPlanningWorkspaceView.swift`).
- **Catalyst CloudKit crash.** Mirroring is now gated on the runtime entitlement (`PersistenceBootstrapContracts.swift`, `PersistentStoreBootstrapService.swift`).

### Foundation
- **Width-driven layout class.** `LayoutResolver.classify(width:horizontalSizeClass:platform:)`: under 600 pt, or a compact iPad, is `.phone`. `LiveLayoutEnvironment` injects it at the shell, UIKit hosts, onboarding and every `PresentationScaffold`, and updates only when a breakpoint is crossed (`Packages/LifeBoardTokens`).
- **One shell tree.** `FoundationShellChromePolicy` chooses dock or switcher, and only values change; the device-idiom check is gone. The dock is capped at 560 and the switcher's composer at 720 (`FoundationShell.swift`, `FoundationShellLayout.swift`).
- **Width caps.** `.ambient` is capped at 1080. `lifeboardReadableContent` now defaults to 680. `AppRoute.readableWidthOverride` keeps Weekly and Settings uncapped and Notes at 1080.
- **Eva history.** It is now a single `ChatView` with history in a form sheet; the nested split view and the branch are gone. `.inspector` was tried and rejected because it drops the shell's custom environment, which put the composer on the dock.
- **No more `UIScreen.main` sizing.** Plan's canvas and drawer and `HighlightingTextView` measure their own geometry.

### Presentations
- **`lifeboardCover`** (`Packages/LifeBoardUI/.../LifeBoardPresentation.swift`) is full screen on iPhone and a page or form sheet at pad widths, with the style latched when it opens. The mood dial, Eva rituals, Make It Fit, Friction Detective and the routine runner use it.
- **Gate.** `premium-ui-guardrails.sh` now bans raw `.fullScreenCover(`.

### Mac and keyboard
- **Menu bar** (`AppCommands.swift`, `AppDelegate.buildMenu`):
  - File ▸ New ⌘N, retitled by context: Task, Journal Entry, Note, Chat.
  - Go ▸ ⌘1–5.
  - Settings… ⌘,.
  - Handled by `ApplicationHostController` through the router; disabled while onboarding covers the app.
  - Every menu anchor is guarded, because the iPad menu differs from the Mac's.
- **Esc and Return.**
  - `ComposerScaffold`: cancel on Esc, confirm on ⌘Return, and ⌘Return commits from the commit bar.
  - Focus: Space pauses and resumes; Esc closes.
  - Home customize: Esc and Return.
  - Eva history: Esc.
- **Window.** 760 × 600 minimum; the title bar carries no title or toolbar.
- **Privacy shield.** `JournalPrivacyShieldPolicy` covers the window only while Journal content is visible, which journal screens report through `JournalContentVisibility`. On the Mac it covers only when the app enters the background.
- **Haptics.** Raw `UI…FeedbackGenerator` calls now go through `Haptic` intents.

### Pointer and hit targets
- **Shared helpers.** `minimumHitTarget()` and `hoverableCard()` (`Packages/LifeBoardUI/.../PointerInteraction.swift`).
- **Home habit card.** Hover effect, plus "Mark done" / "Check in" / "Finish" in its menu.
- **Habit ring.** Keyboard focus: Return steps, ⌥Return completes, ↑/↓ adjust; plus hover.
- **Plan task card.** Its "…" actions are also a context menu.
- **Medication corrections.** Undo in a context menu and as a VoiceOver action.
- **Home day-loop snooze.** A VoiceOver action.
- **Mood dial.** Arrow keys.
- **Weekly ritual rows.** A context menu.
- **Carousels.** Scroll indicators are shown.
- **44 pt targets.** Weekly controls, habit swatches, the date chips, and the Life Management disclosure.
- **Gate.** `scripts/check-platform-parity.sh` is a per-file ratchet on swipe actions outside a `List`, raw haptic generators, and cancel buttons without a shortcut; it is wired into `ios.yml`.

### Per-screen
- **Home**
  - Habits Today becomes a grid at pad widths.
  - Keep-steady ring slots are fixed at 140.
  - Time columns scale with Dynamic Type.
  - The reason sheet uses `[.medium, .large]`.
  - Overdue Rescue's content cap is 480.
- **Plan**
  - Week shows seven flexible columns once they fit (7 × 120), and scrolls with a visible indicator below that.
  - Canvas resize handles take at most a quarter of the block and stay clear of the "…" menu.
  - The fixed 176 pt chrome clearance is replaced by the shell's measured `lifeBoardShellBottomClearance`.
- **Track, Habits, Nutrition**
  - Habit board cells may grow to 110 pt at 900 pt and wider.
  - Nutrition goals accept a typed number.
  - The hydration orb scales with Dynamic Type.
- **Journal, Focus**
  - Mood dial fonts use Dynamic Type styles.
  - The Focus dial is 440 at pad widths, and its close button is an ✕.
  - Entity routes (Focus history) are centred.
- **Eva, Settings**
  - The composer is capped at 760 at pad widths, and the duplicate header "+" is removed (closes MILESTONE_ONE_TODO:140).
  - The Settings split follows the live layout class, with a 320–390 pt sidebar.

### Dead UI
- `HomeiPadShell.swift` (776 lines) is deleted.
- The iPad UI tests in `NavigationTests.swift` used to wait on its identifiers and always skipped. They now drive the live root switcher (`testIPadRootSwitcherReachesEveryRoot`).

## Verification
- **Unit tests:** 2,692 passed in the full `LifeBoardTests` run. Three calendar-integration tests failed only under full-suite load; all 87 calendar tests pass in isolation.
- **New tests:**
  - layout resolver by width
  - chrome policy
  - presentation policy
  - menu key-equivalent and action uniqueness
  - contextual ⌘N
  - privacy shield policy
  - routine runner minimize
  - CloudKit entitlement gate
- **Gates pass:** token-law, premium UI (with the new cover rule), keyboard exits, platform parity.
- **Captures** (light, morning) before and after on iPhone 17, iPad Air 11 portrait, iPad mini and iPad Pro 13. iPhone roots are unchanged apart from atmosphere noise (~1% pixel difference).
- **Mac:** the unsigned Catalyst build launches without CloudKit override flags.

## Second pass (2026-09-25): the open items

- **Overdue Rescue**
  - At iPad and Mac widths the deck is a page sheet. The choice is latched when it opens, so a resize can't rebuild the deck mid-session.
  - Keys: Esc closes, → keeps, ← moves, E edits.
- **Plan Week**
  - In the seven-column layout each day shows up to five of its tasks, plus "+N more".
  - Titles open the task, can be dragged to another day, and move with ←/→.
  - The separate "Redistribute work" list hides only in that layout.
- **Habit board.** Day and Graph lenses are an adaptive two-column grid at pad widths.
- **Health hub.** Two columns at pad widths.
- **Nutrition chart.** Calories are a separate figure; the chart plots grams only.
- **Fasting.** "Edit times…" opens an editor with two date pickers. It goes through the same correction and undo path as the ±15-minute items.
- **Automatic Health syncs** no longer buzz.
- **Knowledge**
  - The nested split view is gone. At pad widths (≥700 pt of its own width) it shows the library and the open note side by side; phone widths keep the sheet, now page-sized.
  - Graph pan and zoom build on the previous gesture instead of snapping back, and zoom is clamped to 0.5–3.
  - Glass is limited to the batch bar and the editor's command bar.
  - The editor is 680 pt wide.
- **Insights.** Charts are taller at pad widths and laid out two to a row. They scrub by pointer, click or touch, with a rule and value label (`InsightsScrubbableChart`).
- **Journal day card.** Its menus are also right-click and long-press menus.
- **Esc sweep.** 63 cancel buttons across the app got `.keyboardShortcut(.cancelAction)`. `scripts/platform-parity-baseline.tsv` is down from 51 rows to 2 after the dead-UI deletion and removing the inert swipe actions on the weekly planner rows (their moves stay in the ellipsis menu, the context menu and the accessibility actions).
- **Dead UI removed.** `FocusZone` (and its two test files), `SearchFaceView` and `HomeQuickFilterDropdown`. The `ifLet` helper `FocusZone` also held now lives with its only caller.
- **Multi-window**
  - `UIApplicationSupportsMultipleScenes` is on.
  - The first window keeps `FoundationCoordinator.shared`, the one that widgets, intents and restoration address.
  - Each further window gets `FoundationCoordinator(secondaryWindowFor:sharing:)`: its own router, capture queue and restoration suite, with preferences shared.
  - File ▸ New Window is ⌥⌘N.
  - Menu commands are received by `AppDelegate` (the end of the responder chain, so they fire with nothing focused) and forwarded to the key window's scene.
  - App-wide navigation events (deep links, widget commands, notification routes) act only in the key window's scene; with one window nothing changes.
- **Tests**
  - `HardwareKeyboardUITests`: ⌘1–5, ⌘N then Esc, ⌘N on Eva. It skips on the iOS simulator, where XCUITest's key presses never reach UIKit main-menu commands (the menu builds, but `canPerformAction` is never asked), so run it against the Mac Catalyst destination. Checked by hand on the Mac instead:
    - ⌘2 opens Plan.
    - ⌘N opens the New Task form sheet.
    - The second window has its own navigation (one window on Plan while the other stays on Home).
    - With multiple windows on, the system had put its own File ▸ New Window on ⌘N; that item is now removed, so ⌘N is New Task and ⌥⌘N is New Window.
  - The iPad `NavigationTests` rotation and switcher tests pass on iPad Pro 13 (`testIPadSupportsAllOrientations`, `testIPadRootSwitcherReachesEveryRoot`). The UI test base previously failed every iPad launch because it only knew the dock's identifiers.

## Third pass (2026-09-25): the rest of the dead UI
- **Row types moved out.** `TaskRowDisplayModel`, `TaskRowMetadataPolicy` and `TaskRowStatusChip` now live in `TaskAgendaPresentationModelBuilder.swift`, their only live consumer.
- **18 files deleted**, with their pbxproj entries:
  - `LifeBoardDesign/HomeScreen.swift`
  - `DaySwipeOverlay`
  - `HomeChipRail`
  - `TaskListView`, `TaskRowView`, `TaskSectionView`
  - 12 `LifeBoardDesign/Components` files:
    - `AssistantPromptCard`, `ChipRailSeparator`, `ClayFilterChip`, `CurrentTimeBubble`
    - `CurrentTimeRail`, `DateHeroHeader`, `DayCompassCard`, `HabitCell`
    - `MeetingFlockCard`, `PermissionCard`, `SunriseSectionHeader`, `TimelineItem`
  - `LBDelight.swift` stays, because `lbAnimatedSheen` is live.
- **Tests.** Unit tests that exercised only those views were removed (`HomeChipRailBuilderTests`, and the matching functions in `SunriseHeaderAssetTests`, `HomeSunriseLayoutMetricsTests`, `HomeTaskSectionBuilderTests` and `HomeTaskSurfaceStyleTests`).
- **Identifier snapshot.** 971 → 938, with a changelog entry. Several UI tests still wait on the removed identifiers (`home.taskRow.*`, `home.sunrise.filter.*`, `home.focus.*`), but the live Home never rendered them. Those tests were already failing and should be rewritten against the live Home or deleted.
- **File-size baseline.** Rows for deleted files were pruned.
- **Verification**
  - The clean iOS simulator build and the unsigned Catalyst build both succeed, and the string catalog is unchanged.
  - `LifeBoardTests`: 2,636 tests, 2,631 passed, 0 failed, 5 skipped. The drop from 2,675 is exactly the 39 removed test functions.
  - Gates pass: token-law, premium UI, keyboard exits, platform parity, accessibility identifiers, localization keys.

## Fourth pass (2026-09-25): Esc, the file-size gate, and the UI tests

### Esc while a field is focused
- **The fix.** A hidden main-menu command (`AppCommandMenu.escapeMenu()`, `UIKeyCommand.inputEscape`, `wantsPriorityOverSystemBehavior`) runs before the focused text field can take the key. It is received by `AppDelegate` and answered by `SheetEscapeRouter` (`LifeBoardUI/SheetEscape.swift`).
- **Registration.** A sheet registers its own cancel action with `.escapeCancels(perform:)`, the same closure as its Cancel button, so unsaved changes still ask first. Registered today:
  - `ComposerScaffold`
  - `AddTaskSheetView`
  - the capture module host
  - the time-block capture
- **Guards:**
  - The router acts only when the registered sheet is the topmost presented controller of the key window: an alert, a confirmation dialog or a nested sheet in front keeps Esc, and so does a sheet in another window.
  - An input method that is composing text keeps Esc.
  - When nothing is ours, the command reports itself disabled, so the key continues to the focused view.
- **Other sheets.** A sheet that has not registered falls back: the first Esc ends editing, and the second reaches its `.cancelAction` button.
- **Tests.** `SheetEscapeRouterTests` covers the command's priority, the cases above, and the no-sheet case against real UIKit presentations.
- **Not verified on the Mac.** An end-to-end keystroke check did not happen. The background automation tool delivers Esc as an accessibility cancel action, not a key, so the physical-key path needs a hand check: ⌘N, click into the title, press Esc.

### File-size gate: green, by extraction
- **The split.** All 87 files over their rows (most were already over at HEAD) were brought under by pure code motion:
  - declarations moved into `<File>+<Topic>.swift` siblings or into same-file `extension` blocks;
  - bodies unchanged;
  - `private` relaxed only where a move crossed a file, each case checked for name collisions.
- **New files:**
  - 83 app-target files, registered in the Xcode project by mirroring their original's target membership.
  - 15 files needed no registration because they sit in SwiftPM target directories: `Packages/*`, `LifeBoard/Persistence`, `LifeBoard/Features/Knowledge`.
- **Baseline.** Rows were lowered to the new counts (78), and the 12 rows whose files now meet the defaults were dropped.
- **Path-keyed tests and gates were extended to the new siblings** so their guarantees still cover the moved code:
  - `runtimeFiles` / `RUNTIME_FILES`
  - `XPRewardPreviewCopyRegressionTests`
  - the pipeline no-semaphore test
  - `HomeCardIsolationTests`
  - the flag-source test
  - the Journal habit-deep-link check

### UI tests off dead identifiers
- **Repointed** to identifiers the live app renders. The Task* suites now go through `HomePage`, which uses:
  - `home.task.<uuid>` for rows;
  - `home.taskCheckbox.<uuid>` for completion;
  - `home.tasks.undoCompletion` to undo;
  - the task screen's `task.editor.*` actions to delete.
- **Deleted where the product no longer has the screen:**
  - Home search and quick-filter chrome
  - the old focus strip and Focus Now
  - the daily-summary modal
  - Home score and streak labels
  - quiet tracking
  - the analytics chart tabs
  - the Home habit grid
  - the v5 onboarding
  - the always-skipped task breakdown

  Nine files went, plus the dead page-object members and about 280 dead constants.
- **Four production identifiers added** so XCUITest can reach controls the app already draws: `home.taskCheckbox.*` and `task.editor.actions/delete/delete.confirm`. The snapshot went 938 → 942.
- **Page objects:**
  - `AddTaskPage` now decides that the sheet has closed from the sheet's own controls. Its any-text-field fallback used to find Home's composer and type into it.
  - `SettingsPage` reaches Life Management through the "Plan & Organize" category.
- **`AddTaskSheetView`'s root** is now an accessibility container, so `addTask.view` is reachable.
- **Product fixes the rerun exposed:**
  - **Home cards told VoiceOver "Pinned by you" for every control inside them.** The card's ownership value sat on a view that isn't an accessibility element, so SwiftUI stamped it onto each child; the task checkbox read "Pinned by you" instead of "Not complete". Each card is now `.accessibilityElement(children: .contain)` (`AdaptiveHomeSections`).
  - **The task screen's actions menu had no title.** On iPhone it folds into the navigation bar's overflow menu, where it was listed as a second, meaningless "More". Its label is now `Label("Task actions", systemImage:)`; the toolbar still shows only the icon.
- **A UI-test launch flag, `-LIFEBOARD_TEST_NEW_TASKS_DUE_TODAY`** (honoured only with `-UI_TESTING`). Add Task schedules but never sets a deadline, and Home's Tasks card lists due tasks, so the Completion, Creation, Deletion and EdgeCase suites opt in. TaskEditingTests does not, because it tests the Deadline chip.
- **Page-object timing.** `waitForExistence` and predicate expectations check on a one-second poll, and a `for … where` scroll loop re-queried on every step. The page objects now check `exists` first and poll manually, which took "Task Creation Flow" from 11.4 s to 3.5 s against its 5 s budget.
- **Changed on purpose:**
  - `taskCompletionTime` rose from 0.3 s to 0.5 s. The block now times only the completion tap, which XCUITest ends when the app is idle again, so the removal animation is included (measured 0.38 s). The 0.3 s limit dated from an in-place checkbox.
  - `EdgeCaseTests.testOverdueTaskIndicator` is removed. It set a past deadline in Add Task, which the sheet cannot do, and its check only printed; the seeded Overdue Rescue suites cover overdue tasks.
- **Results (iPhone simulator, `-testPlan ReleaseQualification`):**
  - NavigationTests: 11 passed, 2 skipped.
  - TaskCompletion, TaskCreation, TaskDeletion, TaskEditing and EdgeCase: 31 of 33 passed on the last full run. The remaining two are EdgeCase tests whose Add button sat under the floating composer; that fix is in, with its rerun recorded below.

### Other gates this work touched
- **documentation-current:** this document has its metadata, and the living-document count is 47.
- **SwiftLint baseline:** lowered 21 → 19 (font) and 35 → 32 (shadow). The dead UI carried five violations.
- **Directory shrapnel:**
  - `Focus/UI` is no longer a candidate: a 48-line section was folded into `FocusSurface`.
  - The `Components` row was recorded after the dead-component deletion.
  - The `Chat/Chrome` row was dropped because its average is now above 150.

## Still open (TODO)
- [ ] Press Esc by hand on the Mac with a focused title field (⌘N, click the title, Esc); the automated check could not send a physical key in the background.
- [ ] Register more text-entry sheets with `.escapeCancels` (Journal composer, Knowledge note editor, habit add); until then they use the two-Esc fallback.
- [ ] `frozen-contracts.json` is stale at HEAD in five contracts. The Core Data model version `TaskModelV3_HabitProgress`, the focus-start deep link and new raw values were all added without re-freezing. This work adds one AppRouter literal (`lifeboard.window.\(sceneIdentifier)`). Re-freezing persisted names needs a migration review.
- [ ] Directory shrapnel, pre-existing:
  - `DesignSystem/HomeCards`: 20 files averaging 66 lines, failing at HEAD.
  - `Eva/Views/Chat/Conversation`: 25 files, one over; uncommitted `EvaProposalCardSessions.swift`.
- [ ] `check-module-boundaries` aborts at HEAD on a stale tracked `LifeBoard.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
- [ ] Run the rest of the suites the cleanup touched (HabitBoard, HomeReplanDay, OverdueRescue*, HomeCalendarModule, ChatPlanApplyUndo, AppearanceAudit, AppStoreScreenshot, Settings, ProjectManagement, ThemeAndAppearance, AddTaskSuggestionFlow, PerformanceTests).
- [ ] XXXL layout work (deferred by MILESTONE_ONE_TODO:156).

## Pre-launch polish pass (2026-09-28)

A deep UI/UX audit of the iPhone launch path found about 290 issues. They were worked through as the iteration plan in `~/.claude/plans/do-a-deep-audit-flickering-hartmanis.md`.

Product-owner decisions:
- Ship every feature.
- Cloud Eva needs one explicit consent screen with every category pre-checked.
- The personas stay as they are; this is an accepted App Store 5.2 risk.

The rules this pass enforces are DESIGN.md "Launch contracts". `scripts/launch-contract-guardrails.sh` ratchets the mechanical ones and runs in `ios.yml`.

Its baseline started from:

| Rule | Start of this pass | Locked in |
|---|---|---|
| Raw enum names in copy | 52 | 11 |
| Legacy haptic calls | 145 | 8 |
| Inline animation curves | 157 | 45 |
| "EVA" in copy | 217 | 26 |
| Fixed-height sheet detents | 1 | 0 |

A parallel copy-rewrite session added its own voice rules to the same gate.

### Launch blockers fixed
- **Consent.** Cloud Eva no longer contacts the service before consent: `EvaCloudAccessCoordinator.hasConfirmedCloudConsent` / `confirmCloudConsent`, and the shared `EvaCloudConsentSheet`.
- **Privacy copy.** Contradictory privacy copy was rewritten.
- **Info.plist.** Added `NSFaceIDUsageDescription`, and made the microphone and speech strings accurate.
- **Settings › Help & About.** Now has Support, Privacy Policy and Terms rows. The privacy page is a **draft** at `public/privacy/index.html` and needs legal review and deployment.
- **Rebuild from iCloud.** It is confirmed first, and it moves aside only the synced store.
- **Data-entry fixes:**
  - Food logs save with blank macros.
  - Archived habits can be restored.
  - Home completion saves before it shows success.
- **Broken links and dead ends:**
  - Widget habit links open the habit.
  - The dead Rescue "More" button is gone.
  - The "Make LifeBoard more useful" card opens Setup Center.
  - The Insights Review lens no longer nests a navigation stack.

### What changed, by area
- **Trust.**
  - Deletes, archives, moves and logs across Plan, Track, Health, Life Moments, Projects, Knowledge and Weekly run at once and offer Undo.
  - Only permanent actions confirm.
  - `AppRouter.shellReceipt` keeps Undo reachable after a detail screen pops.
  - Swallowed errors are surfaced.
  - Eva generation failures are transient rows with Retry instead of saved chat messages.
- **Routing.**
  - Track › Areas has a typed "Your areas" grid (Journal, Notes, Nutrition, Fasting, Wellness, Life Moments, Habits, Routines, Trackers, Goals).
  - Home rows open their subject.
  - Rescue always opens the Overdue Rescue deck.
  - Ask Eva from the day loop is a sheet with context.
  - Notifications, widgets and Live Activities land on their subject.
  - Cold-launch notification links and deep links wait out onboarding.
- **Time and sync.**
  - Home and Plan roll over at midnight and on time-zone changes.
  - DST-safe canvas placement.
  - 12/24-hour aware times.
  - A second device waits (bounded) for its first iCloud import before offering onboarding.
  - The Recovery Center reports real sync state (`CloudSyncStatusStore`).
  - Read-only mode shows a banner.
  - Day Close keeps a same-day draft.
- **Rituals.**
  - Back and step counts in Weekly Reset, Make It Fit and Friction Detective.
  - One decision vocabulary (`DecisionDestination`).
  - Honest Make It Fit receipts.
  - Routine finish summaries.
  - Focus ends in two taps.
  - Fasting reminders are actually scheduled.
- **Capture.**
  - Add Task parses dates and tags in the title and has one primary action.
  - p1 is the highest priority.
  - A verb-less phrase asks "Save as task / Ask Eva".
  - Denied dictation offers Settings.
  - The share extension has a confirmation UI.
  - The Control Center capture button opens the composer.
- **Voice.**
  - Raw enum and jargon strings removed across the app.
  - The assistant is named by its persona.
  - "App motion" replaces the false "Full motion" copy.
- **Visual, motion and haptics.**
  - Widgets moved to the clay palette, and the gallery is trimmed to about 13 widgets.
  - Pale accents used as ink were fixed.
  - Sheets use content-sized detents.
  - Clay shadows sit on the shape only.
  - `HapticFeedback` honours `MotionPolicy`.
  - The Home sky pauses after 20 s idle and under onboarding.
  - The launch splash shows loading status.
- **Accessibility.**
  - 44 pt targets, including `SectionHeader`'s trailing slot.
  - Audio Graphs on the Nutrition, Health, Wellness and Insights charts.
  - The tracker-history VoiceOver order is fixed.
  - Calendar marks use shape as well as colour.
  - Esc works on the remaining text sheets.

### Still open
- **Environment.**
  - The iOS simulator runtime was evicted (only watchOS 26.5 is installed). Everything here was compile-checked on Mac Catalyst; nothing was run on the simulator.
  - Reinstall the runtime, then run `LifeBoardTests` and the ReleaseQualification UI suites. Several UI-test assertions were updated for new copy.
- **Device-only checks.**
  - Haptic timing.
  - Live Activity intents: fasting Finish and routine controls.
  - The Control Center controls.
  - The Watch.
  - A two-device first sync.
  - Midnight rollover.
  - Home idle energy.
- **Features not built:**
  - Habit Done/Snooze and medication Taken/Skip notification actions.
  - New App Shortcuts for habit, mood, Close the day and "What's next"; the provider is at its 10-shortcut limit.
  - Reminders as a fourth onboarding connector; the Ready row is a fallback.
  - An inline "Add one" in Day Close.
  - "Move to Today" on Inbox receipts.
  - Journal paging and not loading media for the list.
- **Iteration 13 launch-readiness items:**
  - Whole-app export and delete-all.
  - Dark and tinted app icons.
  - Re-shoot the App Store screenshots.
  - Telemetry is on by default; that is a product decision.
- **Dead UI to delete:**
  - `Eva/UI/SunriseEvaSheets.swift`
  - `CelebrationEffects`, `BadgeDetailSheet`, `XPBadge`
  - `NavPieChart`, `HomeMomentumSummaryCard`
  - `QuietTrackingComposerView`, `ProjectSelectionSheet`
  - `WeeklyPlannerView`, `QuickViewSelector`
  - The retired widget types (kept compiled in `RetiredTaskWidgets`).
- **Directory shrapnel.** Unchanged, and was already failing: `DesignSystem/HomeCards` and `Eva/Views/Chat/Conversation`.

