# fn-1.1 Update CLAUDE.md migration status and LLM references

## Description
Update CLAUDE.md with accurate migration status and LLM references.

## Changes:
1. Header stats: "189 files" → "730 files", "60% migrated" → "~70% migrated"
2. Add Migration Breakdown table (NEW):
   | Layer | Files | Compliance | Issues |
   |-------|-------|------------|--------|
   | Domain | 30 | 80% | Mappers have CoreData import |
   | UseCases | 28 | 96% | Excellent |
   | State | 9 | 85% | DI has UIKit import |
   | Presentation | 4 | 95% | ViewModels clean |
   | ViewControllers | 47 | 42% | 23 files with NSFetchRequest |
   | **Overall** | **118** | **~70%** | |

3. File Map: Add LLM/ folder with Models/, Views/, Controllers/
4. Note inline repositories as obsolete (State/Presentation confirmed in Xcode target)
5. Update tech stack: iOS 16.0+, Swift 5+

## Keep concise (~450 lines) across all sections:
- Architecture rules (brief)
- 5 Critical Patterns (reference)
- Workflow templates (reference)
- File map (key files, line numbers)
## Acceptance
- [ ] CLAUDE.md header shows "730 files, ~70% migrated"
- [ ] Migration breakdown table added with all 5 layers
- [ ] File map includes LLM/ folder
- [ ] Inline repos noted as obsolete
- [ ] Tech stack updated (iOS 16+, Swift 5+)
- [ ] File size ~450 lines
## Done summary
TBD

## Evidence
- Commits:
- Tests:
- PRs:
