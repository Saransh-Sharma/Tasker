# Tasker

Tasker is a personal execution system with two codebases in one repository:

- `To Do List/` contains the iOS app, widgets, Core Data stack, and XCTest targets.
- `src/` contains the marketing site built with React, TypeScript, and Vite.

## Setup

### iOS app

1. Install CocoaPods dependencies with `pod install`.
2. Open `Tasker.xcworkspace` in Xcode.
3. Use `./taskerctl setup` to validate the local environment when bootstrapping a machine.
4. Use `./taskerctl build`, `./taskerctl test`, and `./taskerctl doctor` for the common build, test, and diagnostics flows.

### Marketing site

1. Install dependencies with `npm install`.
2. Start the dev server with `npm run dev`.
3. Create a production bundle with `npm run build`.

## Architecture

- `To Do List/Domain` holds the app domain models and use cases.
- `To Do List/Presentation` holds Home planning state, view models, and presentation adapters.
- `To Do List/View` and `To Do List/ViewControllers` hold the SwiftUI and UIKit surfaces.
- `To Do ListTests/` and `To Do ListUITests/` cover unit, integration, and UI regressions.
- `Shared/` and `TaskerWidgets/` contain shared code and widget targets.

## Documentation

- `docs/README.md` is the main docs index.
- `docs/habits/README.md` documents Tasker's habit streak system, product behavior, runtime contract, risks, and roadmap.
- `docs/calendar/README.md` documents Tasker's read-only calendar integration, timeline context, risks, and roadmap.
- `docs/audits/HABITS_IOS_UX_AUDIT_2026-04-17.md` captures the current habit UX audit findings and follow-up items.

## Local EVA / LLM

EVA is Tasker's local assistant layer. It uses on-device MLX inference and deterministic planner guards; prompts and task context are not sent to a cloud AI service.

Current LLM-backed and planner-backed use cases include:

- Chat answers over the current task context.
- Read-only task and day review prompts, such as "What are my tasks?"
- Plan with EVA text prompts that can produce either visible assistant text or proposal cards.
- Proposal review cards with selected apply for non-empty task command runs that can be applied.
- Slash-command context, daily brief, top three, task breakdown, dynamic chips, and task suggestions.

See `docs/architecture/LOCAL_LLM_EVA_ARCHITECTURE.md` for the LLM/EVA architecture, use cases, decisions, risks, and manual test guide. Use `Tasker.xcworkspace` for iOS builds and tests because CocoaPods dependencies are required.

### Eva Mascot System

Eva is also Tasker's visual Chief of Staff. The app uses pose-specific mascot states for identity, planning, thinking, review, suggestion, warning, completion, rest, and discovery so Eva communicates what kind of help is present without becoming decorative filler. Mascot placement philosophy, asset ownership, accessibility rules, and QA expectations live in `docs/design/EVA_MASCOT_PLACEMENT_GUIDE.md`; LLM behavior and planner architecture remain in `docs/architecture/LOCAL_LLM_EVA_ARCHITECTURE.md`.

## Calendar And Timeline

Tasker's calendar integration is view-only schedule context, not a calendar editing system.

Home and the timeline are intended to be Tasker's single-glanceable command center for the day. The surface brings together tasks, fixed calendar commitments, routines, busy blocks, open gaps, and EVA guidance into one calm visual flow so users can understand what matters now without switching between a calendar, task list, and planner.

The feature is documented in `docs/calendar/README.md` and covers:

- Calendar permission onboarding and recovery
- Local multi-calendar selection
- Next meeting and busy-block projections
- Task-fit hints based on the user's current availability
- Timeline surfaces that remain task-first, schedule-aware, and optimized for orientation rather than calendar density

## Workflows

- Prefer `taskerctl` for repeatable local build and test flows.
- Keep Home-screen behavior covered with focused unit tests plus the targeted Secondary UI suite.
- The repository may contain in-progress TODO documents; treat them as implementation context, not source of truth.

## Operations

- `./taskerctl status` reports environment and project state.
- `./taskerctl clean` removes build artifacts.
- `./taskerctl archive` and `./taskerctl export` support release packaging.

## Tooling

The marketing site uses Vite, React 19, TypeScript, and ESLint. The React app currently keeps the default Vite toolchain, including `@vitejs/plugin-react`, and does not enable React Compiler by default.
