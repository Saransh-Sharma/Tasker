import LifeBoardContracts
import LifeBoardDomain
import CoreData
import Foundation

/// Manual counterparts for the entities that historical model versions marked
/// as Xcode "Class Definition". Their Swift names are persistence-specific,
/// while `@objc` preserves every archived Core Data runtime class name.
@objc(ExternalContainerMap)
public final class ExternalContainerMap: NSManagedObject {
    @NSManaged public var createdAt: Date?
    @NSManaged public var externalContainerID: String?
    @NSManaged public var id: UUID?
    @NSManaged public var lastSyncAt: Date?
    @NSManaged public var projectID: UUID?
    @NSManaged public var projectRef: NSManagedObject?
    @NSManaged public var provider: String?
    @NSManaged public var syncEnabled: Bool
}

@objc(HabitDefinition)
public final class HabitDefinition: NSManagedObject {
    @NSManaged public var archivedAt: Date?
    @NSManaged public var colorHex: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var failureMask14Raw: Int16
    @NSManaged public var generatedTasks: NSSet?
    @NSManaged public var habitType: String?
    @NSManaged public var iconCategoryKey: String?
    @NSManaged public var iconSymbolName: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isPaused: Bool
    @NSManaged public var kindRaw: String?
    @NSManaged public var lastGeneratedDate: Date?
    @NSManaged public var lastHistoryRollDate: Date?
    @NSManaged public var lifeAreaID: UUID?
    @NSManaged public var lifeAreaRef: NSManagedObject?
    @NSManaged public var metricConfigData: Data?
    @NSManaged public var minimumTargetData: Data?
    @NSManaged public var notes: String?
    @NSManaged public var projectID: UUID?
    @NSManaged public var projectRef: NSManagedObject?
    @NSManaged public var quotaPeriodRaw: String?
    @NSManaged public var quotaTargetCount: Int32
    @NSManaged public var streakBest: Int32
    @NSManaged public var streakCurrent: Int32
    @NSManaged public var successMask14Raw: Int16
    @NSManaged public var targetConfigData: Data?
    @NSManaged public var timedTargetSeconds: Double
    @NSManaged public var title: String?
    @NSManaged public var trackingModeRaw: String?
    @NSManaged public var updatedAt: Date?
}

@objc(LifeAreaEntity)
public final class LifeAreaEntity: NSManagedObject {
    @NSManaged public var color: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var habits: NSSet?
    @NSManaged public var icon: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isArchived: Bool
    @NSManaged public var name: String?
    @NSManaged public var projects: NSSet?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var updatedAt: Date?
    @NSManaged public var updatedByDeviceID: String?
    @NSManaged public var version: Int32
}

@objc(ProjectSectionEntity)
public final class ProjectSectionEntity: NSManagedObject {
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var isCollapsed: Bool
    @NSManaged public var name: String?
    @NSManaged public var projectID: UUID?
    @NSManaged public var projectRef: NSManagedObject?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var tasks: NSSet?
    @NSManaged public var updatedAt: Date?
}

@objc(ReflectionNoteEntity)
public final class ReflectionNoteEntity: NSManagedObject {
    @NSManaged public var createdAt: Date?
    @NSManaged public var energy: Int16
    @NSManaged public var id: UUID?
    @NSManaged public var kind: String?
    @NSManaged public var linkedHabitID: UUID?
    @NSManaged public var linkedProjectID: UUID?
    @NSManaged public var linkedTaskID: UUID?
    @NSManaged public var linkedWeeklyPlanID: UUID?
    @NSManaged public var mood: Int16
    @NSManaged public var noteText: String?
    @NSManaged public var prompt: String?
    @NSManaged public var updatedAt: Date?
}

@objc(TagEntity)
public final class TagEntity: NSManagedObject {
    @NSManaged public var color: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var icon: String?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var taskLinks: NSSet?
}

@objc(TaskDependency)
public final class TaskDependency: NSManagedObject {
    @NSManaged public var createdAt: Date?
    @NSManaged public var dependsOnTaskID: UUID?
    @NSManaged public var dependsOnTaskRef: NSManagedObject?
    @NSManaged public var id: UUID?
    @NSManaged public var kind: String?
    @NSManaged public var taskID: UUID?
    @NSManaged public var taskRef: NSManagedObject?
}

@objc(TaskTagLink)
public final class TaskTagLink: NSManagedObject {
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var tagID: UUID?
    @NSManaged public var tagRef: NSManagedObject?
    @NSManaged public var taskID: UUID?
    @NSManaged public var taskRef: NSManagedObject?
}

@objc(WeeklyOutcomeEntity)
public final class WeeklyOutcomeEntity: NSManagedObject {
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var orderIndex: Int32
    @NSManaged public var sourceProjectID: UUID?
    @NSManaged public var status: String?
    @NSManaged public var successDefinition: String?
    @NSManaged public var title: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var weeklyPlanID: UUID?
    @NSManaged public var whyItMatters: String?
}

@objc(WeeklyPlanEntity)
public final class WeeklyPlanEntity: NSManagedObject {
    @NSManaged public var createdAt: Date?
    @NSManaged public var focusStatement: String?
    @NSManaged public var id: UUID?
    @NSManaged public var minimumViableWeekEnabled: Bool
    @NSManaged public var reviewStatus: String?
    @NSManaged public var selectedHabitIDs: NSObject?
    @NSManaged public var targetCapacity: Int32
    @NSManaged public var updatedAt: Date?
    @NSManaged public var weekEndDate: Date?
    @NSManaged public var weekStartDate: Date?
}

@objc(WeeklyReviewEntity)
public final class WeeklyReviewEntity: NSManagedObject {
    @NSManaged public var blockers: String?
    @NSManaged public var completedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var lessons: String?
    @NSManaged public var nextWeekPrepNotes: String?
    @NSManaged public var perceivedWeekRating: Int32
    @NSManaged public var updatedAt: Date?
    @NSManaged public var weeklyPlanID: UUID?
    @NSManaged public var wins: String?
}
