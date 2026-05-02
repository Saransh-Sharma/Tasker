# Eva Mascot Placement Guide

Eva is Tasker's visual Chief of Staff. Her mascot poses communicate product state: present, planning, thinking, reviewing, suggesting, warning, celebrating, helping, or encouraging rest. Eva should make the app feel guided and humane without becoming a decorative sticker layer.

This guide owns mascot placement philosophy and visual-state mapping. LLM routing, planner guards, model behavior, and assistant privacy posture are documented separately in `../architecture/LOCAL_LLM_EVA_ARCHITECTURE.md`.

## Product Philosophy

- Eva is a functional companion, not filler art.
- Every mascot placement should answer what Eva is doing for the user right now.
- Use one visible Eva emotion per screen region.
- Keep Eva out of repeated rows, dense lists, and every prompt chip.
- Reserve large Eva artwork for onboarding, empty states, success screens, and full-screen planning experiences.
- Warning poses must feel supportive, not punitive.
- Eva must never imply that the assistant has mutated user data without explicit confirmation.

## Pose Ownership

| Asset | Product Meaning | Primary Use |
|---|---|---|
| `eva_neutral` | Identity, ready state | Eva entry point, chat greeting, Settings Eva profile |
| `eva_point_right` | Forward guidance | Onboarding next step, continue planning, right-side coach mark |
| `eva_point_left` | Feature discovery | Home guidance, timeline hints, left-side coach mark |
| `eva_celebration` | Completed work | Applied proposal, completed focus session, weekly completion, streak win |
| `eva_clipboard` | Review and organization | Chief of Staff guide, proposal review, task triage, weekly checklist |
| `eva_calendar` | Schedule and planning | Calendar permission, empty schedule, plan-with-Eva prompts |
| `eva_pencil` | Capture and editing | Add task, brain dump, task breakdown, first task setup |
| `eva_thinking` | Processing | Live generation, onboarding build step, smart reschedule loading |
| `eva_excited` | Activation and major milestone | Eva activation success, first successful plan, major habit milestone |
| `eva_focused` | Prioritization | Focus Now rationale, next action, protect-this-time prompt |
| `eva_surprised` | Noteworthy discovery | Calendar conflict, unexpected free slot, overloaded schedule discovery |
| `eva_sleepy` | Rest and wind-down | Evening empty state, no tasks left today, late-day stop cue |
| `eva_worried` | True risk | Deadline risk, missed-streak recovery, high overdue load |
| `eva_meditate` | Reflection | Weekly reflection, life-area planning, strategic review |
| `eva_running` | Execution momentum | Start focus session, begin today's plan, catch-up mode |
| `eva_sitting` | Low-pressure empty state | Habit empty state, first-run onboarding, relaxed welcome |
| `eva_idea` | Insight | Day overview, smart insight, recommendation card |
| `eva_peek` | Help and discovery | Structured chat help, first-time hints, notification permission education |

## Current Placement Map

### Onboarding

- Welcome intro: `eva_sitting` as a warm first contact.
- Goal and pain selection: `eva_point_right` as forward guidance.
- Eva value and Eva style: `eva_clipboard` to establish review and organization.
- Life areas, habit setup, and first task: `eva_pencil` for capture and setup.
- Processing/build step: `eva_thinking`.
- Calendar permission: `eva_calendar`.
- Notification permission: `eva_peek`.
- Focus room start: `eva_running`.
- Success: `eva_excited`, reserving `eva_celebration` for completed work.

### Chat And Eva Console

- Structured empty greeting: `eva_neutral`.
- Structured help control: `eva_peek`.
- Live generation: `eva_thinking`.
- Chief of Staff guide and proposal review: `eva_clipboard`.
- Day overview and recommendation cards: `eva_idea`.
- Applied proposal: `eva_celebration`.
- Prompt chips keep SF Symbols for scanning; Eva is not repeated in every chip.

### Home And Timeline

- Bottom Eva/chat entry: `eva_neutral`.
- Focus Now rationale: `eva_focused`.
- Home guidance and feature discovery: `eva_point_left`.
- Timeline empty schedule: `eva_calendar`.
- Rest-oriented empty day: `eva_sleepy`.
- Start-plan or execution prompt: `eva_running`.
- Conflict/free-slot discovery: `eva_surprised`.
- True overload/risk: `eva_worried`.

### Calendar

- Permission, no calendars selected, and plan-with-Eva states: `eva_calendar`.
- Loading and smart reschedule processing: `eva_thinking`.
- Empty week/free-slot discovery: `eva_surprised`.
- Calendar load failure or risk recovery: `eva_worried`.

### Tasks

- Quick add, edit, brain dump, and task breakdown: `eva_pencil`.
- Triage or review: `eva_clipboard`.
- Deadline risk: `eva_worried`.
- Applied multi-task plan success: `eva_celebration`.

### Habits

- Empty habit board: `eva_sitting`.
- Streak win: `eva_celebration`.
- Missed-streak recovery: `eva_worried` with gentle copy.
- Major milestone: `eva_excited`.

### Weekly Review And Planning

- Reflection start: `eva_meditate`.
- Checklist review: `eva_clipboard`.
- AI suggestions: `eva_idea`.
- Completion: `eva_celebration`.

### Focus

- Start focus session: `eva_running`.
- Current next action: `eva_focused`.
- Session summary: `eva_celebration`.
- Late-day stop cue: `eva_sleepy`.

### Settings

- Eva profile and AI Assistant identity area: `eva_neutral`.

## Implementation Contract

- Mascot assets live in `To Do List/Assets.xcassets/EvaMascot/`.
- SwiftUI call sites should use `EvaMascotView` with `EvaMascotPlacement` whenever the pose is tied to product state.
- The shared API is:
  - `EvaMascotAsset`
  - `EvaMascotView`
  - `EvaMascotSize`
  - `EvaMascotPlacement`
  - `EvaMascotPlacementResolver`
- Add new product states by adding a placement case and resolver mapping; do not scatter raw asset strings through views.
- Use fixed size tiers:
  - `avatar`: 40 pt
  - `chip`: 32 pt
  - `inline`: 56 pt
  - `card`: 104 pt
  - `hero`: 184 pt
- Decorative Eva images should use `accessibilityHidden(true)`.
- Interactive Eva controls should expose labels such as "Ask Eva", "Eva help", or "Open Eva".

## Usage Rules

- Do use Eva for planning, insight, review, completion, empty state, coaching, and permission education.
- Do not use Eva as random decoration on every card.
- Do not put Eva inside every prompt chip, task row, habit row, or repeated list item.
- Do not show multiple conflicting mascot emotions in the same screen region.
- Reserve `eva_celebration` for completed work or confirmed apply success.
- Reserve `eva_excited` for activation, feature reveals, first successful plan generation, and major milestones.
- Use `eva_worried` only for true risk states and pair it with supportive copy.
- Use `eva_surprised` for noteworthy discoveries; it does not always mean something is wrong.
- Keep mascot treatment small-to-medium unless the screen is onboarding, success, empty state, or full-screen planning.

## QA Checklist

- Light and dark mode preserve contrast around transparent PNG artwork.
- Dynamic Type does not cause Eva to crowd titles, buttons, or explanatory text.
- Reduce Motion removes decorative animation without removing state meaning.
- VoiceOver ignores decorative mascot images.
- Interactive Eva controls have explicit accessibility labels.
- iPad split layouts keep Eva aligned with the relevant screen region.
- High contrast and reduced transparency keep text and controls readable around Eva placements.
- Chat empty state, active generation, proposal review, onboarding success, calendar permission, focus start, habit empty state, missed-streak recovery, and weekly completion are manually checked before release.
