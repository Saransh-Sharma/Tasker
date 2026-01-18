# fn-1.3 Condense TECHNICAL_DEBT.md

## Description
Condense TECHNICAL_DEBT.md from 1,517 lines to <800 lines.

## Format:
Top summary table:
| Priority | Count | Total Effort |
|----------|-------|--------------|
| P0       | X     | XXh          |
...

## Debt Item Format:
- **ID**: DEBT-001
- **Priority**: P0/P1/P2/P3
- **File**: path/to/File.swift
- **Description**: Brief what/why
- **Effort**: Xh

## Add (from audit):
1. DEBT-001: Mappers in Domain layer (P1) - TaskMapper.swift, ProjectMapper.swift
2. DEBT-002: Task model logic (P2) - Business logic in Task.swift
3. DEBT-003: ViewControllers CoreData (P0) - 23 files with NSFetchRequest
4. DEBT-004: UIKit in State/DI (P2) - EnhancedDependencyContainer.swift

## Remove:
- Resolved/completed items (active only)
- Verbose code examples
- Detailed "how to fix" sections

## Migration:
- Summary only (full breakdown in CLAUDE.md)
- Change "60%" → "~70%"
## Acceptance
- [ ] TECHNICAL_DEBT.md < 800 lines
- [ ] Summary table at top (Priority, Count, Effort)
- [ ] Debt items have: ID, Priority, File, Description, Effort
- [ ] 4 audit findings added as debt items
- [ ] Migration shows ~70% (summary only)
- [ ] No verbose code examples
- [ ] Active items only
## Done summary
- TECHNICAL_DEBT.md reduced from 1,517 to 147 lines (90% reduction)
- Added summary table at top (Priority, Count, Effort)
- Added Migration Status table with ~70% overall
- Added 10 debt items (DEBT-001 through DEBT-010)
- 4 audit findings added as debt items (Mappers, Task logic, ViewControllers, UIKit)
- Debt items have: ID, Priority, File, Description, Effort
- No verbose code examples
- Active items only (resolved items removed)
- Noted inline repositories as obsolete
## Evidence
- Commits: 16e91463f09a25696d6081ad76a9aa451bc3436c
- Tests: wc -l TECHNICAL_DEBT.md # 147 lines
- PRs: