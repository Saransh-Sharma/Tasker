# fn-2 Home Redesign Focus Streak Cockpit

## Overview
Redesign the Home screen into a **high-clarity, game-forward execution cockpit** that prioritizes: 
1) daily completion speed, 2) streak protection, 3) meaningful reward feedback.

Design direction (mobile-first): **"Guild Command Deck"**
- Visual intent: compact, premium, tactical; less decorative card clutter, more actionable hierarchy.
- Emotional intent: users should instantly see "how am I doing" and "what do I do next".
- Product intent: remove noise from done tasks and reserve reward emphasis for XP moments.

## Scope
In scope:
- Home header overhaul from Potential Pts label to XP/Streak cockpit.
- Focus strip (top 1-3 ranked tasks) for immediate action.
- Dense execution list redesign with compact rows and metadata consolidation.
- Inline completed behavior with muted styling and collapsed-by-default subgroup.
- Completion/reward micro-interactions and swipe affordances.
- ViewModel presentation models for progress and focus ranking.
- Unit/UI test coverage for ranking, progress, and interaction regressions.

Out of scope:
- Core data schema changes or migrations.
- New backend APIs.
- Non-Home screens (except shared checkbox style parity where required).

## Approach
### 1) Information architecture
Top-down hierarchy:
1. Progress cockpit (XP today + streak safety + thin progress meter)
2. Focus Now strip (1-3 tasks)
3. Dense task sections
4. Completed inline subgroup (collapsed by default when >2)

### 2) Visual and interaction language
- Row baseline target: ~60pt balanced compact density.
- Completed tasks become visually quiet (muted check, reduced contrast).
- Gold/accent emphasis reserved for XP/reward moments.
- Swipe right full action: complete/reopen.
- Swipe left actions: reschedule/snooze, delete (existing capabilities preserved).

### 3) Data/presentation contracts
- Add `HomeProgressState` to `HomeViewModel`.
- Add deterministic `focusTasks` derivation to `HomeViewModel`.
- Add row display model for compact metadata (`rowMetaText`, `trailingMetaText`, `xpValue`).

### 4) Phasing
- Phase A: Header cockpit + focus strip + compact row foundations.
- Phase B: Completed subgroup collapse behavior + checkbox visual parity.
- Phase C: Reward motion polish (+XP fly-to-header), analytics events, regression tests.

## Quick commands
- `./taskerctl build`
- `xcodebuild -workspace Tasker.xcworkspace -scheme 'To Do List' -configuration Debug -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO`
- `xcodebuild -workspace Tasker.xcworkspace -scheme 'To Do List' -destination 'platform=iOS Simulator,name=iPhone 15' test`

## Acceptance
- [ ] Home shows `XP Today: earned/target`, streak safety copy, and progress meter from ViewModel state.
- [ ] Focus strip displays top 1-3 tasks with deterministic ranking: overdue > due today > higher XP > earlier due > stable ID.
- [ ] Task rows are compact, title-first, with single-line metadata and optional note only when present.
- [ ] Completed tasks render muted and appear in inline subgroup collapsed by default when count >2.
- [ ] Checkbox completed style is subtle and non-gold; swipe right supports complete/reopen full swipe.
- [ ] Completion and reward micro-interactions are present (checkbox spring + XP feedback motion).
- [ ] Unit/UI tests validate ranking, progress updates, compact row metadata, and collapse interactions.
- [ ] No regressions in task tap, completion toggle, delete, and reschedule flows.

## References
- Existing home shell: `To Do List/View/HomeForedropView.swift`
- Existing list stack: `To Do List/View/TaskListView.swift`, `To Do List/View/TaskSectionView.swift`, `To Do List/View/TaskRowView.swift`
- Existing home VM: `To Do List/Presentation/ViewModels/HomeViewModel.swift`
- Skill guidance used: `frontend-design` (fallback for unavailable `mobile-design` skill in current session)
