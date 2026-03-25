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
