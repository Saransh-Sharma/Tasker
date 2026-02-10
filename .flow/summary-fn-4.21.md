Created XP domain events for tracking all XP operations:
- XPAddedEvent: Fired when XP is added (task/habit completion)
- XPSubtractedEvent: Fired when XP is subtracted (uncomplete)
- XPChangedEvent: Generic event for any XP change
- XPResetEvent: Fired at midnight or manual reset
- XPMilestoneEvent: Achievement tracking (levels, streaks, tasks)
- XPStreakBonusEvent: Streak multiplier bonus notifications
- XPEvent struct: Individual event record for persistence
