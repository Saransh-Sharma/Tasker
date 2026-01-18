# Comprehensive Documentation Update

## Overview

Deep audit and update of all project documentation based on current codebase state. **Goals: reduce size by 60-75%**, ensure accuracy across all docs, remove contradictions, add LLM features, and document actual migration status from layer-by-layer audit.

## Verified Facts (from Deep Audit)

| Metric | Value | Source |
|--------|-------|--------|
| **Total Swift files** | 730 files | `find` command |
| **Clean Architecture** | ~70% migrated | Layer-by-layer audit |
| **iOS version** | 16.0+ | Info.plist |
| **Swift version** | 5+ | Project settings |
| **State/Presentation in target** | ✅ YES | Xcode project verified |
| **LLM files** | 23 files, 10 in target | Folder audit |
| **LLM status** | Beta/In progress | User confirmed |

## Migration Status (from Deep Audit)

| Layer | Files | Compliance | Key Issues |
|-------|-------|------------|------------|
| **Domain** | 30 | 80% | Mappers import CoreData, business logic in Task model |
| **UseCases** | 28 | 96% | Excellent, minor violations |
| **State** | 9 | 85% | DI container has UIKit import |
| **Presentation** | 4 | 95% | ViewModels clean, DI has legacy imports |
| **ViewControllers** | 47 | 42% | 23 files with NSFetchRequest violations |
| **Overall** | 118 | **~70%** | Weighted average |

## Document Targets

| Document | Current | Target | Primary Audience |
|----------|---------|--------|------------------|
| **README.md** | 6,012 lines | <1,500 lines | New + existing developers |
| **TECHNICAL_DEBT.md** | 1,517 lines | <800 lines | Maintainers |
| **PRD** | 2,754 lines | <1,200 lines | Product focused |
| **CLAUDE.md** | 442 lines | ~450 lines | AI agents + developers |

## Task Execution Order (UPDATED)

1. **fn-1.2** - Rewrite README.md (START HERE - biggest impact)
2. **fn-1.1** - Update CLAUDE.md (update migration %, add LLM)
3. **fn-1.3** - Condense TECHNICAL_DEBT.md
4. **fn-1.4** - Streamline PRD + add LLM specs
5. **fn-1.5** - Cross-check and validate all documentation

## README.md Specification (<1,500 lines)

### Structure (in order):
1. **Title + Badges** (Platform + Project Health)
2. **Overview** (2 paragraphs: what it does, who for)
3. **Features** (Task mgmt, Projects, Gamification, CloudKit, **LLM/AI**)
4. **Quick Stats** (embedded: 730 files, ~70% Clean Arch, iOS 16+)
5. **Quick Start** (Installation, Build commands)
6. **Architecture Overview** (2 paragraphs + link to CLAUDE.md, ASCII diagram)
7. **Dependencies** (Structured table: name, version, purpose)
8. **Testing** (Brief section)
9. **Contributing** (Brief reference)
10. **License**

### LLM/AI Section (Comprehensive, Marketing-focused):
- Eva Assistant (on-device chat)
- MLX-based local inference (privacy-first)
- Task understanding and recommendations
- Calendar integration
- **Status: Beta/In progress**

### Remove (4,500+ lines):
- Verbose "Recent Improvements" → Keep 10-line summary
- Detailed architecture → Link to CLAUDE.md
- Code examples → Link to CLAUDE.md
- Changelog/history

### Keep:
- Current screenshots and assets
- All badges (platform + project health)
- taskerctl build commands

### Key Examples to Keep (1-2 per doc):
- Build command: `./taskerctl build`
- Quick start installation

## CLAUDE.md Specification (~450 lines)

### Updates:
1. **Header**: Change "60% migrated" → "~70% migrated", "189 files" → "730 files"
2. **Migration Breakdown** (NEW): Full table with layer percentages
3. **File Map**: Add LLM/ folder (Models/, Views/, Controllers/)
4. **Inline Repositories**: Note as obsolete (State/Presentation confirmed in target)
5. **Tech Stack**: Update iOS/Swift versions

### Structure (concise across all):
- Architecture rules (brief)
- 5 Critical Patterns (reference)
- Workflow templates (reference)
- File map (key files, line numbers)

### Focus: Keep precise and concise across all sections

## TECHNICAL_DEBT.md Specification (<800 lines)

### Format (Top summary table + structured items):
```
| Priority | Count | Total Effort |
|----------|-------|--------------|
| P0       | X     | XXh          |
...
```

### Debt Item Format:
- **ID**: DEBT-001, DEBT-002...
- **Priority**: P0/P1/P2/P3
- **File Location**: Specific file path
- **Description**: Brief what/why
- **Effort Estimate**: Hours/days

### Active Debt Items (from audit):
1. **Mappers in Domain layer** (P1) - TaskMapper, ProjectMapper import CoreData
2. **Task model logic** (P2) - Business logic in domain model
3. **ViewControllers CoreData** (P0) - 23 files with NSFetchRequest
4. **UIKit in State/DI** (P2) - DI container imports UIKit

### Remove:
- Resolved/completed items (keep active only)
- Verbose code examples
- Detailed "how to fix" sections

### Migration Progress:
- Summary only (full breakdown in CLAUDE.md)

## PRD Specification (<1,200 lines)

### Focus: Product-focused (not technical)

### LLM/AI Section (Full PRD format):
- **Problem Statement**: What AI feature solves
- **User Personas**: Who benefits
- **Acceptance Criteria**: Success metrics
- **Business Outcomes**: Value provided

### Features (all with status tags):
- Task management ✅ Implemented
- Project organization ✅ Implemented
- Gamification ✅ Implemented
- CloudKit sync ✅ Implemented
- **LLM/AI features** 🚧 In Development

### Remove:
- Code examples (belong in CLAUDE.md)
- Technical architecture details
- Duplicate user story + acceptance + use case sections

### Keep:
- Problem statements
- User personas
- Acceptance criteria
- Business outcomes

## Validation Checks (fn-1.5)

```bash
# Verify file sizes
wc -l README.md TECHNICAL_DEBT.md PRODUCT_REQUIREMENTS_DOCUMENT.md CLAUDE.md

# Check internal links (README)
grep -n "\[.*\](.*\.md)" README.md

# Check cross-doc references
grep -r "CLAUDE.md\|TECHNICAL_DEBT.md\|PRODUCT_REQUIREMENTS_DOCUMENT.md" *.md

# Verify file paths exist
grep -oE "To Do List/[a-zA-Z/]+\.swift" README.md CLAUDE.md | xargs -I {} ls {} 2>&1 | grep -v "No such file"

# Verify LLM mentions
grep -c "LLM\|AI\|Eva\|MLX" README.md PRODUCT_REQUIREMENTS_DOCUMENT.md

# Verify migration consistency
grep -n "70%\|75%\|60%" *.md
```

## Acceptance Checks

- [ ] README.md < 1,500 lines
- [ ] TECHNICAL_DEBT.md < 800 lines  
- [ ] PRD < 1,200 lines
- [ ] CLAUDE.md ~450 lines
- [ ] All docs show "730 files, ~70% migrated"
- [ ] LLM features in README (comprehensive, marketing)
- [ ] LLM features in PRD (full spec, beta status)
- [ ] LLM in CLAUDE.md file map
- [ ] No contradictions between docs
- [ ] Internal links valid (verified)
- [ ] Cross-doc references valid (verified)
- [ ] File paths mentioned actually exist
- [ ] Line numbers in references accurate
- [ ] Inline repos documented as obsolete
- [ ] Tech stack updated (iOS 16+, Swift 5+)
- [ ] Dependencies in structured table
- [ ] Badges added (platform + project health)
- [ ] Debt items have ID, priority, location, effort
- [ ] Summary table at top of TECHNICAL_DEBT.md
- [ ] Migration breakdown in CLAUDE.md
- [ ] Screenshots/assets preserved in README

## Quick Commands

```bash
# Verify file sizes after update
wc -l README.md TECHNICAL_DEBT.md PRODUCT_REQUIREMENTS_DOCUMENT.md CLAUDE.md

# Check for broken references  
grep -r "CLAUDE.md\|TECHNICAL_DEBT.md\|PRODUCT_REQUIREMENTS_DOCUMENT.md" *.md

# Verify LLM mentions
grep -c "LLM\|AI\|Eva\|MLX" README.md PRODUCT_REQUIREMENTS_DOCUMENT.md

# Verify migration consistency
grep -n "70%\|75%\|60%\|730\|189" *.md
```

## Key Decisions from Interview

1. **Audience**: Both new onboarding AND existing maintainers
2. **Separation**: Clear separation of concerns (README=overview, CLAUDE=architecture, PRD=product, Debt=tracking)
3. **LLM Status**: Beta/In progress (accurate, not overstated)
4. **Migration**: ~70% overall (from layer audit, not 75%)
5. **ViewModels**: Wired and functional (via PresentationDependencyContainer)
6. **Inline Repos**: Create debt items (they're obsolete since State/Presentation in target)
7. **Code Examples**: Keep 1-2 key examples per doc, remove verbose ones
8. **Diagrams**: Keep ASCII text diagrams in README
9. **Screenshots**: Keep current assets
10. **Badges**: Add platform + project health badges
11. **Dependencies**: Structured table format
12. **Debt Format**: ID + Priority + Location + Effort
13. **PRD Focus**: Product-focused (problem, personas, acceptance, outcomes)
14. **Validation**: Full check (links, paths, line numbers, LLM mentions, migration consistency)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking internal references | High | Validation checks in fn-1.5 |
| Removing needed info | Medium | CLAUDE.md kept as detailed reference |
| Migration % confusion | Medium | Document full breakdown in CLAUDE.md |
| LLM over/under-stated | Low | Document as Beta/In progress accurately |
