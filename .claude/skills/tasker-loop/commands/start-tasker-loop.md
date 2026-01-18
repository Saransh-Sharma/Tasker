---
description: "Start Tasker Loop in current session"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(${CLAUDE_SKILL_ROOT}/scripts/setup-tasker-loop.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Tasker Loop Command

Execute the setup script to initialize the Tasker loop:

```!
"${CLAUDE_SKILL_ROOT}/scripts/setup-tasker-loop.sh" $ARGUMENTS
```

Please work on the task. When you try to exit, the Tasker loop will feed the SAME PROMPT back to you for the next iteration. You'll see your previous work in files and git history, allowing you to iterate and improve.

**Tasker-Specific Guidelines:**

1. **Clean Architecture**: Always follow the 4-layer structure:
   - Domain: Pure Swift models, protocols, business logic
   - UseCases: Orchestrate workflows, apply business rules
   - State: CoreData CRUD, caching, Entity↔Domain mapping
   - Presentation: ViewModels with @Published, coordinate use cases

2. **Mapper Pattern**: NEVER manually map. Always use mappers:
   - `TaskMapper.toDomain(from:)` / `TaskMapper.toEntity(from:in:)`
   - `ProjectMapper.toDomain(from:)` / `ProjectMapper.toEntity(from:in:)`

3. **Protocol Injection**: Always inject protocols, never concrete implementations:
   ```swift
   class MyUseCase {
       private let repository: TaskRepositoryProtocol
       init(repository: TaskRepositoryProtocol) { ... }
   }
   ```

4. **Build & Test**: After changes, run:
   ```bash
   ./taskerctl build
   ```

5. **UUID Architecture**: All entities use UUID. Inbox project has fixed UUID:
   ```
   00000000-0000-0000-0000-000000000001
   ```

CRITICAL RULE: If a completion promise is set, you may ONLY output it when the statement is completely and unequivocally TRUE. Do not output false promises to escape the loop, even if you think you're stuck or should exit for other reasons. The loop is designed to continue until genuine completion.
