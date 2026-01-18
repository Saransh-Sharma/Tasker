# Tasker Loop

Self-referential AI loop for iterative Tasker iOS development, implementing the Ralph Wiggum technique. Optimized for Swift, Clean Architecture, CoreData, and CloudKit.

## Quick Start

```bash
/start-tasker-loop Add label feature using Clean Architecture --completion-promise 'LABELS DONE' --max-iterations 15
```

## What Is Tasker Loop?

Tasker Loop runs Claude in a while-true loop with the same prompt until task completion. Each iteration, Claude sees its previous work in files and git history, allowing continuous improvement and refinement.

**Key Benefit**: Transform complex multi-file tasks into iterative, self-correcting development sessions.

## Features

- ✅ Self-referential loops (Claude sees previous work)
- ✅ Completion promises (exit only when done)
- ✅ Max iteration limits (safety guard)
- ✅ Tasker-specific Clean Architecture guidance
- ✅ Built-in mapper pattern enforcement
- ✅ UUID architecture support
- ✅ Automatic state management
- ✅ Corruption recovery

## Architecture

```
.claude/tasker-loop.local.md (state file)
    ↓
Stop Hook (hooks/stop-hook.sh)
    ↓
Setup Script (scripts/setup-tasker-loop.sh)
    ↓
Commands (/start-tasker-loop, /cancel-tasker-loop, /tasker-loop-help)
```

## Commands

| Command | Description |
|---------|-------------|
| `/start-tasker-loop PROMPT [OPTIONS]` | Start a loop |
| `/cancel-tasker-loop` | Cancel active loop |
| `/tasker-loop-help` | Show full documentation |

## Usage Examples

### Simple Feature

```bash
/start-tasker-loop Add label feature using Clean Architecture
```

### With Completion Promise

```bash
/start-tasker-loop Fix CoreData migration --completion-promise 'MIGRATION WORKING'
```

### With Iteration Limit

```bash
/start-tasker-loop Refactor HomeViewController --max-iterations 10
```

### Both Options

```bash
/start-tasker-loop Add unit tests --completion-promise 'TESTS PASSING' --max-iterations 20
```

## How It Works

1. **Initialize**: `/start-tasker-loop` creates state file with YAML frontmatter
2. **Work**: Claude executes the task, modifying files
3. **Exit Attempt**: When Claude tries to exit, stop hook activates
4. **Check**: Hook reads state file, checks completion criteria
5. **Continue**: If incomplete, updates iteration and feeds same prompt back
6. **Loop**: Claude sees previous work, iterates again
7. **Complete**: When promise detected, loop ends

## Clean Architecture Integration

Tasker Loop is optimized for the Tasker codebase architecture:

### Layer Structure

```
Domain/           # Pure Swift models, protocols
    ↓
UseCases/         # Orchestrate workflows
    ↓
State/            # CoreData CRUD, mappers
    ↓
Presentation/     # ViewModels, coordinate use cases
```

### Critical Patterns

- **Mapper Pattern**: `TaskMapper.toDomain()`, `ProjectMapper.toEntity()`
- **Protocol Injection**: `TaskRepositoryProtocol`, never concrete types
- **UUID Architecture**: All entities use UUID, Inbox = `00...001`
- **Domain Purity**: No CoreData/UIKit imports in Domain layer

## State File Format

```yaml
---
active: true
iteration: 1
max_iterations: 15
completion_promise: "LABELS DONE"
started_at: "2026-01-10T12:00:00Z"
---

Add label feature using Clean Architecture
```

## Completion Promises

**Only output when statement is COMPLETELY TRUE.**

```xml
<promise>YOUR_PHRASE</promise>
```

Do not lie to exit the loop - the system is designed to continue until genuine completion.

## Safety Features

| Feature | Description |
|---------|-------------|
| Max Iterations | Prevents infinite loops |
| Completion Promise | Only allows exit when done |
| Corruption Handling | Detects and recovers from issues |
| Error Validation | Robust input checking |
| Atomic Updates | Safe state file writes |

## Good Use Cases ✅

- Well-defined tasks with clear success criteria
- Tasks requiring iterative refinement (debugging, refactoring)
- Greenfield features (new use cases, repositories)
- Tasks with automatic verification (tests passing, build success)

## Bad Use Cases ❌

- Tasks requiring human judgment (design decisions, UI polish)
- One-shot operations (single file creation)
- Unclear success criteria
- Production debugging on live systems

## Monitoring

```bash
# View current iteration
grep '^iteration:' .claude/tasker-loop.local.md

# View full state
head -10 .claude/tasker-loop.local.md

# View prompt
tail -n +10 .claude/tasker-loop.local.md
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Loop won't start | Run `/cancel-tasker-loop` first |
| "State file corrupted" | Cancel and restart |
| Max iterations reached | Increase limit or refine prompt |
| Promise not detected | Check XML tags format |

## Tasker-Specific Build Commands

```bash
./taskerctl build              # Build simulator
./taskerctl build device       # Build physical device
./taskerctl clean --all        # Clean build
./taskerctl doctor             # Diagnostics
```

## Philosophy

**Iteration > Perfection**

Let Claude attempt the same task multiple times. Each iteration builds on previous work, enabling:

- Self-correction from failures
- Gradual refinement of approach
- Discovery of edge cases
- Better understanding of codebase
- More robust implementations

## File Structure

```
.claude/skills/tasker-loop/
├── .claude-skill/
│   └── skill.json              # Skill metadata
├── README.md                   # This file
├── commands/
│   ├── start-tasker-loop.md    # Start loop command
│   ├── cancel-tasker-loop.md   # Cancel command
│   └── tasker-loop-help.md     # Full documentation
├── hooks/
│   ├── hooks.json              # Hook configuration
│   └── stop-hook.sh            # Stop hook logic
└── scripts/
    └── setup-tasker-loop.sh    # Loop initialization
```

## Based On

Tasker Loop is based on the [ralph-loop](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop) plugin by Anthropic, adapted specifically for the Tasker iOS codebase.

## License

Same as Tasker project.
