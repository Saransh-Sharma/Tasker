Created NUserStats CoreData entity and supporting infrastructure:
- Added entity to TaskModel.xcdatamodeld with 14 attributes
- Created NSManagedObject subclass files (CoreDataClass + CoreDataProperties)
- Created UserStats domain model with computed properties (level, xpToNextLevel, progress)
- Created UserStatsMapper with full CRUD operations
- Computed properties: currentLevel, xpToNextLevel, levelProgress, isOnStreak, hasActivityToday
