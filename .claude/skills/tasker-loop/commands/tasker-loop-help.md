---
description: "Tasker Loop help documentation"
---

# Tasker Loop - Self-Referential Development for Tasker iOS

## Overview

Tasker Loop implements the **Ralph Wiggum technique** for continuous self-referential AI development, optimized for the Tasker iOS codebase. It runs Claude in a while-true loop with the same prompt until task completion, allowing iterative refinement through seeing your own previous work.

## Philosophy

**Iteration > Perfection** - Let Claude attempt the same task multiple times, each time seeing what worked and what didn't in previous attempts. This is particularly effective for:

- Complex multi-file refactoring (migrating to Clean Architecture)
- Debugging CoreData and CloudKit sync issues
- Building new features with proper use cases and repositories
- Writing comprehensive unit tests with mappers
- Gradual code improvements

## Commands

### `/start-tasker-loop PROMPT [--max-iterations N] [--completion-promise TEXT]`

Start a Tasker loop in the current session.

**Arguments:**
- `PROMPT` - The task description (multi-word without quotes)
- `--max-iterations N` - Maximum iterations before auto-stop (default: unlimited)
- `--completion-promise 'TEXT'` - Completion phrase (must be quoted if multi-word)

**Examples:**
```bash
/start-tasker-loop Add label feature using Clean Architecture --completion-promise 'LABELS DONE' --max-iterations 15
/start-tasker-loop --max-iterations 10 Fix CoreData migration issue
/start-tasker-loop Refactor HomeViewController to use Clean Architecture
/start-tasker-loop --completion-promise 'TESTS PASSING' Add unit tests for TaskMapper
```

### `/cancel-tasker-loop`

Cancel the active Tasker loop and show iteration statistics.

## How It Works

1. **State File**: `.claude/tasker-loop.local.md` stores loop configuration (YAML frontmatter)
2. **Stop Hook**: Intercepts session exit attempts, checks completion status
3. **Completion Detection**: Looks for `<promise>TEXT</promise>` in output
4. **Iteration Control**: Stops at max iterations if specified
5. **Self-Reference**: Feeds same prompt back; Claude sees previous work in files

## Usage Patterns

### Good Use Cases ✅

- **Well-defined tasks with clear success criteria**:
  ```bash
  /start-tasker-loop Add label feature with Clean Architecture --completion-promise 'FEATURE COMPLETE'
  ```

- **Tasks requiring iterative refinement**:
  ```bash
  /start-tasker-loop Fix CoreData migration issue --max-iterations 20
  ```

- **Greenfield features**:
  ```bash
  /start-tasker-loop Implement user authentication with CloudKit --completion-promise 'AUTH DONE'
  ```

- **Tasks with automatic verification**:
  ```bash
  /start-tasker-loop Add unit tests for TaskMapper --completion-promise 'ALL TESTS PASSING'
  ```

### Bad Use Cases ❌

- Tasks requiring human judgment (design decisions, UI polish)
- One-shot operations (running a single build, creating one file)
- Unclear success criteria
- Production debugging on live systems

## Tasker-Specific Guidelines

### Clean Architecture Rules

Always follow the 4-layer structure:

```text
Domain (pure Swift, no framework deps)
    ↓
UseCases (orchestrate workflows, business rules)
    ↓
State (CoreData CRUD, caching, mappers)
    ↓
Presentation (ViewModels, coordinate use cases)
```

### Mapper Pattern

**NEVER** manually map Entity↔Domain:

```swift
// ❌ WRONG
let tasks = entities.map { Task(id: $0.taskID ?? UUID(), ...) }

// ✅ CORRECT
let tasks = TaskMapper.toDomainArray(from: entities)
```

### Protocol Injection

Always inject protocols:

```swift
// ❌ WRONG
class GetTasksUseCase {
    private let repository = CoreDataTaskRepository()
}

// ✅ CORRECT
class GetTasksUseCase {
    private let repository: TaskRepositoryProtocol
    init(repository: TaskRepositoryProtocol) { ... }
}
```

### UUID Architecture

All entities use UUID:
- Inbox project: `00000000-0000-0000-0000-000000000001`
- Legacy data gets deterministic UUID generation
- Use `TaskMapper` for backward compatibility

### Build Commands

After changes, run:
```bash
./taskerctl build              # Build simulator
./taskerctl build device       # Build physical device
./taskerctl clean --all        # Clean build
```

## Completion Promises

**Only output the promise when the statement is COMPLETELY TRUE.**

Do not:
- Lie to escape the loop
- Output the promise prematurely
- Force completion when you're stuck

Do:
- Trust the process
- Let the loop continue until genuine completion
- The promise will become true naturally

Example:
```bash
/start-tasker-loop Fix CoreData migration --completion-promise 'MIGRATION WORKING'
```

Only output `<promise>MIGRATION WORKING</promise>` when:
- Migration runs without errors
- All entities are converted to UUID
- App launches successfully
- Data is accessible

## Monitoring

```bash
# View current iteration
grep '^iteration:' .claude/tasker-loop.local.md

# View full state
head -10 .claude/tasker-loop.local.md

# View prompt
tail -n +10 .claude/tasker-loop.local.md
```

## Safety Features

- **Max Iterations**: Prevents infinite loops on impossible tasks
- **Completion Promise**: Only allows exit when conditions are genuinely met
- **Corruption Handling**: Detects and recovers from state file corruption
- **Error Validation**: Robust input validation and error reporting

## Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| Loop won't start | Existing state file | Run `/cancel-tasker-loop` first |
| "State file corrupted" | Manual editing | Cancel and restart |
| Max iterations reached | Task took too long | Increase limit or refine prompt |
| Promise not detected | Wrong format | Check XML tags: `<promise>TEXT</promise>` |

## Example Workflow

```text
# 1. Start loop for complex feature
/start-tasker-loop Add label support with Clean Architecture --completion-promise 'LABELS WORKING' --max-iterations 20

# 2. Claude attempts implementation (iteration 1)
# ... creates domain models, protocols, repositories ...

# 3. Loop feeds same prompt back (iteration 2)
# ... adds use cases, updates coordinator ...

# 4. Loop continues (iteration 3+)
# ... creates view models, wires UI, fixes bugs ...

# 5. Claude outputs completion promise when done
<promise>LABELS WORKING</promise>

# 6. Loop exits, feature complete!
```

## Advanced Tips

1. **Iterate on Prompts**: First run without completion promise to see progress, then restart with specific promise
2. **Use Lower Max First**: Start with 5-10 iterations to test approach, then increase if needed
3. **Check Files Between Runs**: Loop pauses on exit attempts - review changes before continuing
4. **Git Commit Between**: Commit progress between iterations if running long sessions

## See Also

- [taskerctl](../../../../taskerctl) - Build and diagnostic commands
- [Core Data Model](../../../../To%20Do%20List/TaskModel.xcdatamodeld/) - Entity definitions
