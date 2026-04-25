# Structured AI Raw Research Notes

Date: 2026-04-24
Device surface: Structured iPhone app through iPhone Mirroring.
Scope update: Voice and scan/image workflows were intentionally skipped in this pass per user instruction.

## Capture Limitation

- iPhone Mirroring was visible through Computer Use and supported live inspection.
- macOS `screencapture` failed with `could not create image from display`, likely because the mirrored iPhone surface is protected.
- As a result, screenshot evidence is recorded as named observed screen states in the teardown instead of saved PNG files.

## Baseline Observations

- Structured opened on Timeline for Friday, April 24, 2026.
- Bottom nav: Inbox, Timeline, AI, Settings.
- Floating green plus button is always present at bottom right.
- Timeline showed existing synthetic/older items:
  - Rise and Shine, completed/struck through.
  - Existing task around 11:30 AM-12:30 PM, completed/struck through.
  - Wind Down.
- Inbox contained an existing item: `Do this 7847`, 45 min.

## AI Entry Points Observed

- Bottom nav AI tab:
  - Label: `AI`.
  - Icon: sparkle.
  - Main heading: `Hi there! What tasks are on your agenda?`
  - Input placeholder: `Tell me your plans...`
  - Input bar includes microphone icon and scan/camera icon.
  - Suggestion chips:
    - `Plan my morning routine`
    - `Scan my school timetable`
  - Help button opens Structured help center.
- AI help/introduction:
  - In-app response lists capabilities: create and organize tasks/routines/events; suggest daily/weekly/project plans; edit/delete/move tasks; shift schedule when plans change; summarize plans/completed tasks; distribute inbox tasks; break down goals; identify conflicts.
- Add-task flow:
  - Entering Add from bottom plus opened normal task creation/edit UI, not an AI-specific flow in this pass.

## Official Help / Policy Sources Consulted

- Structured Help Center: `What is Structured AI?`
  - https://help.structured.app/en/articles/1782402
  - Confirms written/verbal instructions, timeline task creation, editing existing tasks, scanning physical planner/to-do list, external OpenAI processing, up to 30-day storage, and Pro requirement.
- Structured Help Center: `What is Structured Pro?`
  - https://help.structured.app/en/articles/324674
  - Confirms Structured AI is included in Structured Pro on iOS and Android, not Web.

## Text Creation Test A

Prompt:
`Tomorrow I have a morning walk at 7:30, deep work from 10 to 12, lunch at 1, design review at 3, gym at 6:30, and dinner at 8.`

Loading copy observed:
- `Calculating perfect agenda`
- `Calibrating your calendar..`

Result summary copy:
- `Here's your plan for tomorrow, including all the activities you mentioned with reasonable time estimates.`

Generated suggestions:
- `Morning Walk`, 04/25/2026, 7:30-8:30 AM, 1 hr, walking icon, CREATE badge.
- `Deep Work`, 04/25/2026, 10:00 AM-12:00 PM, 2 hr, monitor icon, CREATE badge.
- `Lunch`, 04/25/2026, 1:00-2:00 PM, 1 hr, utensils icon, CREATE badge.
- `Design Review`, 04/25/2026, 3:00-4:00 PM, 1 hr, target/check style icon, CREATE badge.
- `Gym`, 04/25/2026, 6:30-7:30 PM, 1 hr, dumbbell icon, CREATE badge.
- `Dinner`, 04/25/2026, 8:00-9:00 PM, 1 hr, utensils icon, CREATE badge.

Review UI:
- Each card has pink `CREATE` badge.
- Expanded card actions: `Add`, `Edit`, `Discard`.
- Each card has right-side selection circle.
- Bottom action: `Accept All`.
- Feedback icons: thumbs up/down.
- Back navigation warns: `Are you sure you want to discard your changes?` with `Discard Changes`.

## Text Inbox Creation Test

Prompt:
`Add these to my inbox: call dentist, buy groceries, pay electricity bill, review PRD.`

Loading copy observed:
- `Checking the forecast`
- `Fine-tuning your itinerary..`

Result summary copy:
- `I've added your tasks to your inbox: call dentist, buy groceries, pay electricity bill, and review PRD.`

Generated suggestions:
- `Call dentist`, Inbox, phone icon.
- `Buy groceries`, Inbox, cart icon.
- `Pay electricity bill`, Inbox, dollar icon.
- `Review PRD`, Inbox, monitor icon.

Applied result:
- After `Accept All`, Inbox showed generated tasks newest-first:
  - Review PRD
  - Pay electricity bill
  - Buy groceries
  - Call dentist
  - Existing `Do this 7847`
- No obvious persistent AI-origin badge was visible on Inbox rows.

## Text Timeline Creation Test

Prompt:
`Create scheduled timeline tasks for today, not inbox: 3:30 PM Design review for 45 minutes, 4:30 PM Deep work product spec for 60 minutes, 6:30 PM Gym for 60 minutes, and 8:00 PM Dinner for 60 minutes.`

Loading copy observed:
- `Aligning the stars`

Result summary copy:
- `Your timeline for today has been scheduled with the requested tasks at your specified times.`

Generated suggestions:
- `Design review`, 04/24/2026, 3:30-4:15 PM, 45 min, gears icon, CREATE badge.
- `Deep work product spec`, 04/24/2026, 4:30-5:30 PM, 1 hr, book icon, CREATE badge.
- `Gym`, 04/24/2026, 6:30-7:30 PM, 1 hr, dumbbell icon, CREATE badge.
- `Dinner`, 04/24/2026, 8:00-9:00 PM, 1 hr, utensils icon, CREATE badge.

Applied result:
- Timeline showed the created tasks at their requested times.
- No visible `created by AI` badge persisted on the timeline rows.
- Timeline top mini-day indicators changed to show more colored markers for April 24.
- Structured inserted contextual timeline helper copy, e.g. `Task ahead! 32m to prep.` and `Plan a snack in 1h?`.

## Text Edit Existing Timeline Test

Prompt:
`Edit today's timeline: move Design review to 4:00 PM for 30 minutes, shorten Deep work product spec to 45 minutes starting at 4:45 PM, keep Gym and Dinner unchanged.`

Note: iPhone Mirroring/keyboard entered mixed casing, but Structured still understood the intent.

Loading copy observed:
- `Scheduling your success`

Result summary copy:
- `Design review will now be at 4:00 PM for 30 minutes. Deep work product spec is shortened to 45 minutes starting at 4:45 PM. Gym and Dinner remain unchanged.`

Generated edit suggestions:
- `Design review`, 04/24/2026, 4:00-4:30 PM, 30 min, orange `EDIT` badge.
- `Deep work product spec`, 04/24/2026, 4:45-5:30 PM, 45 min, orange `EDIT` badge.

Review UI differences from creation:
- Orange `EDIT` badge.
- Expanded edit card actions: `Save`, `Edit`, `Discard`, `Show`.
- Bottom action: `Accept All`.
- Preserved unchanged tasks by omission: Gym and Dinner did not appear as edit cards.

Applied result:
- Timeline updated:
  - Design review moved to 4:00-4:30 PM.
  - Deep work product spec moved/shortened to 4:45-5:30 PM.
  - Gym remained 6:30-7:30 PM.
  - Dinner remained later in the day.

## No-Op / Empty Edit State

Prompt:
`I am running 90 minutes late. Shift all remaining tasks today by 90 minutes.`

Result:
- Structured returned no mutation suggestions.
- Copy: `You have no remaining tasks scheduled for the rest of today, so there's nothing to shift. If you were expecting specific tasks, please check your time frame or provide more details!`
- Actions: `Start New`, thumbs up/down feedback.

## Skipped This Pass

- Voice workflow: skipped per user instruction.
- Scan/image workflow: skipped per user instruction.
- Deletion prompts: not applied in this pass; deletion requires action-time confirmation.
- Paid subscription/paywall purchase: not attempted.
- Real calendar/reminders account import: not used.
