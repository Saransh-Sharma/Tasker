# LifeBoard

LifeBoard is a personal execution system with two codebases in one repository:

- `LifeBoard/` contains the iOS app, widgets, Core Data stack, and XCTest targets.
- `src/` contains the marketing site built with React, TypeScript, and Vite.

## Setup

### iOS app

1. Install CocoaPods dependencies with `pod install`.
2. Open `LifeBoard.xcworkspace` in Xcode.
3. Use `./lifeboardctl setup` to validate the local environment when bootstrapping a machine.
4. Use `./lifeboardctl build`, `./lifeboardctl test`, and `./lifeboardctl doctor` for the common build, test, and diagnostics flows.

### Marketing site

1. Install dependencies with `npm install`.
2. Start the dev server with `npm run dev`.
3. Create a production bundle with `npm run build`.

## Architecture

- `LifeBoard/Domain` holds the app domain models and use cases.
- `LifeBoard/Presentation` holds Home planning state, view models, and presentation adapters.
- `LifeBoard/View` and `LifeBoard/ViewControllers` hold the SwiftUI and UIKit surfaces.
- `LifeBoardTests/` and `LifeBoardUITests/` cover unit, integration, and UI regressions.
- `Shared/` and `LifeBoardWidgets/` contain shared code and widget targets.

## Documentation

- `docs/README.md` is the main docs index.
- `docs/habits/README.md` documents LifeBoard's habit streak system, product behavior, runtime contract, risks, and roadmap.
- `docs/calendar/README.md` documents LifeBoard's read-only calendar integration, calendar schedule surfaces, Home timeline, timeline-aware Eva guidance, risks, and roadmap.
- `docs/audits/HABITS_IOS_UX_AUDIT_2026-04-17.md` captures the current habit UX audit findings and follow-up items.

## Local EVA / LLM

EVA is LifeBoard's local assistant layer and day-management interface. It uses on-device MLX inference, deterministic planner guards, schema-validated proposal cards, and the existing task action pipeline; prompts and task context are not sent to a cloud AI service in the local path.

Product-wise, Eva acts as the user's Chief of Staff: a chat-first assistant that can explain the day, summarize open commitments, highlight overloaded windows, suggest a realistic sequence, and help the user repair the plan after interruptions. Eva is not an autonomous scheduler. Meaningful changes remain proposal-driven, explicitly confirmed, and undoable where the action pipeline supports undo.

Current LLM-backed and planner-backed use cases include:

- Chat answers over the current task context.
- Read-only task and day review prompts, such as "What are my tasks?"
- Chief-of-staff day overview cards that separate overdue tasks, today tasks, focus candidates, due habits, recovery habits, and quiet tracking.
- Plan with EVA text prompts that can produce either visible assistant text or proposal cards.
- Proposal review cards with selected apply for non-empty task command runs that can be applied.
- Slash-command context, daily brief, top three, task breakdown, dynamic chips, and task suggestions.

Timeline-aware assistant work is documented across two canonical packages:

- `docs/architecture/LOCAL_LLM_EVA_ARCHITECTURE.md` covers the local LLM, chat routing, context projection, proposal pipeline, day overview card contract, trust boundaries, risks, and manual test guide.
- `docs/calendar/README.md` covers the calendar schedule and Home timeline contract that Eva can read from when offering schedule-aware planning guidance.

Use `LifeBoard.xcworkspace` for iOS builds and tests because CocoaPods dependencies are required.

### Assistant Mascot Persona System

LifeBoard's visual Chief of Staff is user-selectable. Eva remains the default persona, and users can choose Eva, Cloudlet, Dude, Elon, Friday, Johnny, Maddie, Paperclip, Punch, Retriever, Sato, Steve, Theo, or YesMan during onboarding or from Settings. The selected persona controls the visible assistant name, accessibility labels, and mascot artwork while the local assistant architecture can keep Eva-prefixed internal implementation names.

Eva uses the original static PNG pose set in `Assets.xcassets`; non-Eva personas use bundled sprite assets from `LifeBoard/LLM/MascotSprites/`. Mascot placement philosophy, sprite ownership, semantic animation mapping, accessibility rules, and QA expectations live in `docs/design/EVA_MASCOT_PLACEMENT_GUIDE.md`; LLM behavior and planner architecture remain in `docs/architecture/LOCAL_LLM_EVA_ARCHITECTURE.md`.

## Calendar And Timeline

LifeBoard's calendar integration is view-only schedule context, not a calendar editing system.

Home and the timeline are intended to be LifeBoard's single-glanceable command center for the day. The surface brings together tasks, fixed calendar commitments, routines, busy blocks, open gaps, and EVA guidance into one calm visual flow so users can understand what matters now without switching between a calendar, task list, and planner.

The calendar schedule feature reads EventKit data, lets users choose the calendars that matter, filters schedule context locally, and projects that context into Home, task detail, and timeline views. It answers practical execution questions: what meeting is next, when the user is free until, whether a task fits the current window, which part of the day is overloaded, and where there is usable open time.

The timeline feature is LifeBoard's day narrative rather than a dense calendar grid. Fixed events stay anchored, tasks stay flexible, routines give the day rhythm, overlapping busy periods collapse into readable flocks, and long gaps become labeled opportunity windows. Eva can use the same day picture to offer optional Chief of Staff guidance such as sequencing, deferral, focus protection, and recovery suggestions, while calendar data remains read-only and task mutations stay behind confirmation.

The feature is documented in `docs/calendar/README.md` and covers:

- Calendar permission onboarding and recovery
- Local multi-calendar selection
- Next meeting and busy-block projections
- Task-fit hints based on the user's current availability
- Calendar schedule surfaces for day, week, and month glances
- Timeline surfaces that remain task-first, schedule-aware, and optimized for orientation rather than calendar density
- Timeline-aware Eva guidance that helps the user act, repair, defer, or protect focus without taking over scheduling

## Workflows

- Prefer `lifeboardctl` for repeatable local build and test flows.
- Keep Home-screen behavior covered with focused unit tests plus the targeted Secondary UI suite.
- The repository may contain in-progress TODO documents; treat them as implementation context, not source of truth.

## Operations

- `./lifeboardctl status` reports environment and project state.
- `./lifeboardctl clean` removes build artifacts.
- `./lifeboardctl archive` and `./lifeboardctl export` support release packaging.

## Tooling

The marketing site uses Vite, React 19, TypeScript, and ESLint. The React app currently keeps the default Vite toolchain, including `@vitejs/plugin-react`, and does not enable React Compiler by default.
