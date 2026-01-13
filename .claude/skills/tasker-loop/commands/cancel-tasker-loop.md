---
description: "Cancel active Tasker loop"
hide-from-slash-command-tool: "true"
---

# Cancel Tasker Loop

This command cancels an active Tasker loop by removing the state file.

```!
if [ -f ".claude/tasker-loop.local.md" ]; then
  ITERATION=$(grep '^iteration:' .claude/tasker-loop.local.md | sed 's/iteration: *//')
  STARTED=$(grep '^started_at:' .claude/tasker-loop.local.md | sed 's/started_at: *//')
  rm .claude/tasker-loop.local.md
  echo "🛑 Tasker loop cancelled"
  echo "   Iterations completed: $ITERATION"
  echo "   Started at: $STARTED"
else
  echo "ℹ️  No active Tasker loop found"
fi
```
