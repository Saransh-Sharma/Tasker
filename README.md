# Tasker - Gamified Tasks & Productivity

![iOS](https://img.shields.io/badge/iOS-16.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Xcode](https://img.shields.io/badge/Xcode-15.0-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Files](https://img.shields.io/badge/Files-730-blue)
![Architecture](https://img.shields.io/badge/Clean_Architecture-~70%25-brightgreen)

A gamified iOS task management app that transforms productivity into an engaging experience. Tasker combines smart task organization with priority-based scoring, seamless CloudKit sync, and on-device AI assistance.

## Overview

Tasker helps busy professionals stay organized with a unique gamification system—complete higher priority tasks to earn more points (P0=7pts, P1=4pts, P2=3pts, P3=2pts). With **730 Swift files** and a **~70% Clean Architecture** migration, the codebase demonstrates modern iOS development patterns using UIKit, SwiftUI, Combine, and CoreData with CloudKit synchronization.

The app is **production-published on the App Store** and features offline-first architecture, real-time analytics, and an AI-powered assistant (Eva) running on-device via MLX.

## Features

### Task Management
- Create, edit, and complete tasks with rich details (title, description, due date, priority)
- Four-level priority system (P0-Highest, P1-High, P2-Medium, P3-Low) with visual indicators
- Task types: Morning, Evening, Upcoming, and automatic Inbox categorization
- Smart rescheduling for overdue or postponed tasks
- Advanced search and filtering by project, priority, completion status, and date ranges

### Project Organization
- UUID-based project architecture for reliable cross-device sync
- Fixed Inbox project (`00000000-0000-0000-0000-000000000001`) for uncategorized tasks
- Custom projects with colors and icons
- Project-based filtering and analytics
- Orphaned task protection—automatic assignment to Inbox

### Gamification & Analytics
- **Scoring System**: Earn points based on task priority (P0: 7pts, P1: 4pts, P2: 3pts, P3: 2pts)
- **Streak Tracking**: Consecutive day completion streaks with 30-day history
- **Daily Dashboard**: Visual charts showing completion trends and productivity patterns
- **Performance Insights**: Historical data visualization with DGCharts integration

### CloudKit Sync
- Seamless cross-device synchronization via iCloud
- Offline-first architecture—works without internet
- Automatic conflict resolution with smart merge strategies
- Private CloudKit database with silent push notifications

### AI Assistant (Eva) 🚧 Beta
- **Eva Assistant**: On-device AI chat interface for task assistance
- **MLX-Based**: Local inference using MLX framework (privacy-first, no server calls)
- **Task Understanding**: Natural language task recommendations and insights
- **Calendar Integration**: Smart scheduling suggestions
- **Status**: In development—core features functional, expanding capabilities

## Quick Stats

| Metric | Value |
|--------|-------|
| Swift Files | 730 |
| Clean Architecture | ~70% migrated |
| iOS Deployment | 16.0+ |
| Swift Version | 5.9 |
| Architecture | Clean Architecture + UIKit/SwiftUI hybrid |

## Quick Start

### Prerequisites
- macOS 14.0+
- Xcode 15.0+
- CocoaPods

### Installation

```bash
# Clone the repository
git clone https://github.com/Saransh-Sharma/Tasker.git
cd Tasker

# Install dependencies
pod install

# Open the workspace
open Tasker.xcworkspace

# Build and run
# Select target device/simulator and press Cmd+R
```

### Build Commands

```bash
# Using taskerctl (recommended)
./taskerctl build              # Build for simulator
./taskerctl build device       # Build for physical device
./taskerctl clean --all        # Clean build artifacts
./taskerctl doctor             # Run diagnostics
```

## Architecture Overview

Tasker follows **Clean Architecture** principles with clear separation between layers:

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ ViewControllers│  │  ViewModels  │  │  UI Components│       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Business Logic Layer                      │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │   Use Cases  │  │ UseCaseCoord │                         │
│  └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Protocols  │  │   Entities   │  │   Constants  │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   State Management Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Repositories│  │Data Sources  │  │   Cache      │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Infrastructure                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  Core Data   │  │   CloudKit   │  │   Firebase   │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

**Key Principles:**
- Unidirectional dependencies (Presentation → Business Logic → Domain → State)
- Protocol-based injection for testability
- No upward dependencies—lower layers never depend on higher layers
- ViewModels expose @Published state; ViewControllers coordinate with Use Cases

For detailed architecture patterns, Clean Architecture rules, and coding guidelines, see **[CLAUDE.md](CLAUDE.md)**.

## Migration Status

| Layer | Files | Compliance | Status |
|-------|-------|------------|--------|
| Domain | 30 | 80% | Mappers import CoreData, business logic in Task model |
| UseCases | 28 | 96% | Excellent—protocol injection, no CoreData |
| State | 9 | 85% | DI container has UIKit import |
| Presentation | 4 | 95% | ViewModels clean |
| ViewControllers | 47 | 42% | 23 files with NSFetchRequest (gradual migration) |
| **Overall** | **118** | **~70%** | Weighted average |

See **[TECHNICAL_DEBT.md](TECHNICAL_DEBT.md)** for detailed migration status and remaining work.

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| Firebase/Crashlytics | ~11.13 | Crash reporting |
| Firebase/Analytics | ~11.13 | Analytics |
| Firebase/Performance | ~11.13 | Performance monitoring |
| MicrosoftFluentUI | ~0.34.0 | UI components |
| FSCalendar | ~2.8.1 | Calendar view |
| DGCharts | ~5.1 | Analytics charts |
| CircleMenu | ~4.1.0 | Circular menu UI |
| ViewAnimator | ~3.1 | View animations |
| Timepiece | ~1.3.1 | Date utilities |
| EasyPeasy | ~1.9.0 | Layout DSL |
| BEMCheckBox | ~1.4.1 | Checkboxes |
| TinyConstraints | ~4.0.1 | Layout constraints |

## Recent Improvements (2025-2026)

- **January 2026**: Clean Architecture ~70% complete—Domain layer 100% clean, ViewModels wired via PresentationDependencyContainer
- **October 2025**: UUID-based architecture implemented—stable IDs for tasks and projects
- **June 2025**: BEMCheckBox integration for inline task completion
- **May 2025**: Chat assistant interface (Eva) introduced
- **Ongoing**: LLM features with MLX-based on-device inference

## Testing

```bash
# Run unit tests
xcodebuild test -scheme Tasker -destination 'platform=iOS Simulator,name=iPhone 15'

# Run UI tests
xcodebuild test -scheme Tasker -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:TaskerUITests
```

Test coverage is currently ~10% with planned expansion as Clean Architecture migration progresses.

## Logging Policy

Runtime logging is restricted to actionable issues only:
- Levels retained by default: `WARN`, `ERROR`, `FATAL`
- Default minimum level: `.warning` in both Debug and Release
- Temporary deep diagnostics: launch with `-TASKER_VERBOSE_LOGS`
- Firebase startup in Debug: disabled by default to reduce simulator Network/QUIC noise; opt in with `-TASKER_ENABLE_FIREBASE_DEBUG`

Standard log contract:
- `ts=<ISO8601UTC> lvl=<WARN|ERROR|FATAL> cmp=<Component> evt=<event_name> msg="<short message>" key=value ...`
- `evt` is required and uses snake_case
- Logs are single-line key-value output (no multiline dumps, no emoji prefixes)

Guardrails:
```bash
./scripts/check-no-print-logs.sh
```
This fails when direct `print(...)` remains in production app source.

## Contributing

Contributions are welcome! This project follows Clean Architecture principles. Please review:
- **[CLAUDE.md](CLAUDE.md)** — Architecture rules, patterns, and coding guidelines
- **[TECHNICAL_DEBT.md](TECHNICAL_DEBT.md)** — Known issues and migration status

When contributing:
1. New features MUST use Clean Architecture (no CoreData in UseCases/Domain)
2. Always use `TaskMapper.toDomain/toEntity`—never manual mapping
3. Business logic belongs in UseCases, not ViewModels
4. UI updates MUST be on `DispatchQueue.main.async`

## Documentation

- **[CLAUDE.md](CLAUDE.md)** — Project instructions for AI agents and developers (architecture patterns, critical rules)
- **[TECHNICAL_DEBT.md](TECHNICAL_DEBT.md)** — Technical debt tracking and migration status
- **[PRODUCT_REQUIREMENTS_DOCUMENT.md](PRODUCT_REQUIREMENTS_DOCUMENT.md)** — Feature specifications and requirements

## License

This project is licensed under the MIT License — see the LICENSE file for details.

## Screenshots

| App Store | Task Flow |
|-------------|-------------|
| ![app_store](https://user-images.githubusercontent.com/4607881/123705006-fbb21700-d883-11eb-9c32-7c201067bf08.png) | ![Tasker v1 0 0](https://user-images.githubusercontent.com/4607881/123707145-e4285d80-d886-11eb-8868-13d257fab8f4.gif) |

---

**[App Store Link](https://apps.apple.com/app/id1574046107)** | **Built with ❤️ using Clean Architecture**
