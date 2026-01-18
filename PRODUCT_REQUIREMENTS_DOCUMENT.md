# Tasker iOS - Product Requirements Document (PRD)

**Version:** 3.0
**Last Updated:** January 13, 2026
**Platform:** iOS 16.0+
**Status:** Production (App Store Published)
**Clean Architecture:** ~70% migrated

---

## Executive Summary

Tasker is a gamified iOS task management app that transforms productivity into an engaging experience. Users earn points for completing tasks based on priority (P0=7, P1=4, P2=3, P3=2), track streaks, and sync seamlessly across devices via CloudKit.

### Core Value Proposition

- **Smart Prioritization**: Priority-based scoring motivates users to focus on what matters
- **Gamification**: Points, streaks, and visual progress make productivity rewarding
- **Reliability**: UUID-based architecture ensures data never gets lost
- **AI Assistant**: On-device Eva assistant provides task recommendations (Beta)

---

## User Personas

### 1. Alex - Busy Professional (Primary)
**Demographics**: 25-45, knowledge worker, uses multiple devices

**Goals**:
- Manage work tasks across projects
- Balance work and personal responsibilities
- Track productivity trends

**Pain Points**:
- Overwhelmed by too many tasks
- Difficulty prioritizing
- Loses track of deadlines

**Tasker Solutions**: Priority scoring, project analytics, CloudKit sync, overdue detection

### 2. Sam - Student (Secondary)
**Demographics**: 18-25, high school/college student

**Goals**: Track assignments, build study habits, stay motivated

**Pain Points**: Procrastination, lack of motivation, forgets tasks

**Tasker Solutions**: Habit builder, gamification, visual analytics, reminders

### 3. Jordan - Habit Builder (Tertiary)
**Demographics**: 20-50, focused on self-improvement

**Goals**: Build sustainable habits, track consistency, see long-term progress

**Pain Points**: Difficulty maintaining habits, lacks accountability

**Tasker Solutions**: Habit templates, streak tracking, momentum indicators

---

## Feature Specifications

### 1. Task Management ✅ Implemented

**Problem**: Users struggle to organize and prioritize tasks effectively.

**User Stories**:
- Quickly create tasks with title, description, priority, due date
- Assign tasks to projects for organization
- Set priorities (P0-P3) to focus on what matters most

**Acceptance Criteria**:
- Task name required (1-200 characters)
- Priority levels: P0 (Highest), P1 (High), P2 (Medium), P3 (Low)
- Due date with smart defaults
- Tasks default to Inbox project if none specified

**Success Metrics**:
- Task creation < 5 seconds
- 70%+ tasks have priorities assigned
- <5% tasks in Inbox (users organize)

---

### 2. Project Organization ✅ Implemented

**Problem**: Tasks across different areas of life get mixed together.

**User Stories**:
- Create projects for work, personal, hobbies
- View tasks filtered by project
- Track completion rates per project

**Acceptance Criteria**:
- Custom projects with colors and icons
- Fixed Inbox project (UUID: `00000000-0000-0000-0000-000000000001`)
- Project-based filtering and analytics

**Success Metrics**:
- 60%+ of tasks belong to named projects
- Users create 3+ projects on average

---

### 3. Gamification & Scoring ✅ Implemented

**Problem**: Task management feels like a chore—users lack motivation.

**User Stories**:
- Earn points for completing tasks based on priority
- Track completion streaks
- View productivity charts and trends

**Scoring System**:
- P0 (Max): 7 points
- P1 (High): 4 points
- P2 (Medium): 3 points
- P3 (Low): 2 points

**Acceptance Criteria**:
- Points display immediately after task completion
- Streak tracking with 30-day history
- Visual charts showing completion trends

**Success Metrics**:
- 40%+ of users maintain 7+ day streaks
- Daily engagement (DAU) increases with gamification

---

### 4. CloudKit Sync ✅ Implemented

**Problem**: Users need access to tasks across multiple devices.

**User Stories**:
- Access tasks on iPhone, iPad, Mac
- Work offline with automatic sync when connected
- Never lose data (UUID-based architecture)

**Acceptance Criteria**:
- Automatic CloudKit synchronization
- Offline-first architecture
- Conflict resolution for concurrent edits
- Private CloudKit database

**Success Metrics**:
- 60%+ of users sync across 2+ devices
- <1% sync errors reported

---

### 5. AI Assistant (Eva) 🚧 In Development

**Problem**: Users need help organizing tasks and getting recommendations.

**User Stories**:
- Chat with AI assistant to get task recommendations
- Receive smart scheduling suggestions
- Get productivity insights

**Acceptance Criteria**:
- On-device AI chat interface (privacy-first, no server calls)
- MLX-based local inference
- Task understanding and natural language recommendations
- Calendar integration for smart scheduling

**Technical Approach**:
- Uses MLX framework for on-device inference
- 23 Swift files, 10 currently in Xcode target
- Models/ (data controllers), Views/ (chat), Controllers/ (host)

**Success Metrics** (Beta):
- Chat responses < 2 seconds
- 70%+ of recommendations are relevant
- Privacy: all data stays on-device

**Status**: Beta—core features functional, expanding capabilities

---

## Success Metrics

| Metric | Baseline | Target (Q2 2026) |
|--------|----------|-----------------|
| Daily Active Users | 1,200 | 5,000 |
| Task Completion Rate | 45% | 65% |
| App Store Rating | 4.2 | 4.6 |
| Retention (D30) | 18% | 28% |
| Streak Users (7+ days) | 35% | 40% |

---

## Roadmap

### Completed (v1.0 - v2.0)
- ✅ Core task management
- ✅ Project organization
- ✅ Gamification & scoring
- ✅ CloudKit sync
- ✅ Clean Architecture (~70% migrated)

### In Progress (v2.1)
- 🚧 AI Assistant (Eva) - Beta
- 🚧 Habit builder UI

### Planned (v3.0)
- ⏳ Team collaboration features
- ⏳ Siri Shortcuts integration
- ⏳ Apple Watch app
- ⏳ Calendar integration (full)

---

## Technical Notes

For technical architecture, Clean Architecture patterns, and implementation details, see:
- **[CLAUDE.md](CLAUDE.md)** — Architecture rules, patterns, coding guidelines
- **[TECHNICAL_DEBT.md](TECHNICAL_DEBT.md)** — Migration status, known issues

---

**Document History**:
- v3.0 (Jan 2026): Streamlined from 2,754 lines, added LLM specs, product-focused
- v2.0 (Jan 2026): Previous comprehensive version
- v1.0 (2024): Initial PRD
