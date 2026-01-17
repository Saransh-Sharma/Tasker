# fn-2.4 Add TaskPriority validation in GetTaskStatisticsUseCase

## Description
TBD

## Acceptance
- [ ] Validate rawValue before using TaskPriority(rawValue:)
- [ ] Skip or fail on invalid priorities instead of mapping to .none
- [ ] Optionally log invalid raw values


## Done summary
- Added TaskPriorityConfig.isValidPriority() check before creating TaskPriority
- Invalid raw values are now skipped with a warning log instead of silently mapping to .none
- Prevents corrupted/unknown priority codes from polluting statistics

**Why:**
- Silently mapping invalid priorities to .none could hide data corruption issues

**Verification:**
- Code review confirms validation is applied before TaskPriority initialization
## Evidence
- Commits: 8ac4fbbb35a6718de9645ea152319d0db1bc1cc6
- Tests:
- PRs: