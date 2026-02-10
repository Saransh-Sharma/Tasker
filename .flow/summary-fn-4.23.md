Created XP repository layer for persistence:
- XPRepositoryProtocol: Defines interface for XP persistence operations
- CoreDataXPRepository: Implementation using CoreData/NUserStats
- Methods for DailyXP CRUD, UserStats CRUD, XPEvent tracking
- Integrates with existing XPServiceProtocol
- Updates UserStats on XP events (lifetime, daily, streaks, task/habit counts)
