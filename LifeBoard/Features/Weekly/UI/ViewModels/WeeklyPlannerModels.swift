import Foundation

public struct WeeklyOutcomeDraft: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var sourceProjectID: UUID?
    public var whyItMatters: String
    public var successDefinition: String
    public var showsDetails: Bool
    public var showsProjectPicker: Bool

    public init(
        id: UUID = UUID(),
        title: String = "",
        sourceProjectID: UUID? = nil,
        whyItMatters: String = "",
        successDefinition: String = "",
        showsDetails: Bool = false,
        showsProjectPicker: Bool = false
    ) {
        self.id = id
        self.title = title
        self.sourceProjectID = sourceProjectID
        self.whyItMatters = whyItMatters
        self.successDefinition = successDefinition
        self.showsDetails = showsDetails
        self.showsProjectPicker = showsProjectPicker
    }
}

public enum WeeklyPlannerStep: Int, CaseIterable, Identifiable {
    case direction
    case outcomes
    case tasks
    case review

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .direction: return WeeklyCopy.plannerSteps[0]
        case .outcomes: return WeeklyCopy.plannerSteps[1]
        case .tasks: return WeeklyCopy.plannerSteps[2]
        case .review: return WeeklyCopy.plannerSteps[3]
        }
    }

    public var prompt: String {
        switch self {
        case .direction:
            return WeeklyCopy.directionPrompt
        case .outcomes:
            return WeeklyCopy.outcomesPrompt
        case .tasks:
            return WeeklyCopy.tasksPrompt
        case .review:
            return WeeklyCopy.reviewPrompt
        }
    }

    public var nextButtonTitle: String {
        switch self {
        case .direction:
            return WeeklyCopy.continueToOutcomes
        case .outcomes:
            return WeeklyCopy.continueToTasks
        case .tasks:
            return WeeklyCopy.reviewPlan
        case .review:
            return WeeklyCopy.savePlan
        }
    }

    public var stepLabel: String {
        String(localized: "Step \(rawValue + 1) of \(Self.allCases.count)")
    }
}

public enum WeeklyTaskSourceMode: String, CaseIterable, Identifiable {
    case weeklyCandidates
    case suggested
    case allOpen

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .weeklyCandidates:
            return WeeklyCopy.weeklyCandidates
        case .suggested:
            return WeeklyCopy.suggestedTasks
        case .allOpen:
            return WeeklyCopy.allOpenTasks
        }
    }
}

public struct WeeklyTaskTriageDecision: Equatable {
    public let task: TaskDefinition
    public let sourceBucket: TaskPlanningBucket?
    public let destinationBucket: TaskPlanningBucket
    public let restoredQueueIndex: Int
    public let reviewedCountBefore: Int

    public init(
        task: TaskDefinition,
        sourceBucket: TaskPlanningBucket?,
        destinationBucket: TaskPlanningBucket,
        restoredQueueIndex: Int,
        reviewedCountBefore: Int
    ) {
        self.task = task
        self.sourceBucket = sourceBucket
        self.destinationBucket = destinationBucket
        self.restoredQueueIndex = restoredQueueIndex
        self.reviewedCountBefore = reviewedCountBefore
    }
}

public struct WeeklyPlannerReviewOutcomeSummary: Identifiable, Equatable {
    public let id: UUID
    public let title: String
    public let projectName: String?
    public let linkedTaskCount: Int

    public init(id: UUID, title: String, projectName: String?, linkedTaskCount: Int) {
        self.id = id
        self.title = title
        self.projectName = projectName
        self.linkedTaskCount = linkedTaskCount
    }
}

public struct WeeklyPlannerReviewLaneSummary: Identifiable, Equatable {
    public let bucket: TaskPlanningBucket
    public let title: String
    public let tasks: [TaskDefinition]

    public var id: String { bucket.rawValue }

    public init(bucket: TaskPlanningBucket, title: String, tasks: [TaskDefinition]) {
        self.bucket = bucket
        self.title = title
        self.tasks = tasks
    }
}

public struct WeeklyPlannerReviewSummary: Equatable {
    public let direction: String?
    public let outcomes: [WeeklyPlannerReviewOutcomeSummary]
    public let lanes: [WeeklyPlannerReviewLaneSummary]
    public let habits: [HabitLibraryRow]
    public let compactSummary: String
    public let compactDetail: String?

    public init(
        direction: String?,
        outcomes: [WeeklyPlannerReviewOutcomeSummary],
        lanes: [WeeklyPlannerReviewLaneSummary],
        habits: [HabitLibraryRow],
        compactSummary: String,
        compactDetail: String?
    ) {
        self.direction = direction
        self.outcomes = outcomes
        self.lanes = lanes
        self.habits = habits
        self.compactSummary = compactSummary
        self.compactDetail = compactDetail
    }
}

public struct WeeklyPlannerTriageCardModel: Equatable {
    public let task: TaskDefinition
    public let currentPlacementText: String
    public let outcomeTitle: String?

    public init(task: TaskDefinition, currentPlacementText: String, outcomeTitle: String?) {
        self.task = task
        self.currentPlacementText = currentPlacementText
        self.outcomeTitle = outcomeTitle
    }
}

public struct WeeklyPlannerTriageSnapshot: Equatable {
    public let cardModel: WeeklyPlannerTriageCardModel?
    public let progressText: String
    public let sectionDetail: String

    public init(cardModel: WeeklyPlannerTriageCardModel?, progressText: String, sectionDetail: String) {
        self.cardModel = cardModel
        self.progressText = progressText
        self.sectionDetail = sectionDetail
    }
}

public struct WeeklyPlannerFooterSnapshot: Equatable {
    public let title: String
    public let detail: String
    public let warning: String?

    public init(title: String, detail: String, warning: String? = nil) {
        self.title = title
        self.detail = detail
        self.warning = warning
    }
}

public struct WeeklyPlannerTaskSourceSnapshot: Equatable {
    public let mode: WeeklyTaskSourceMode
    public let tasks: [TaskDefinition]

    public init(mode: WeeklyTaskSourceMode, tasks: [TaskDefinition]) {
        self.mode = mode
        self.tasks = tasks
    }
}

struct WeeklyPlannerOutcomeOption: Identifiable, Equatable {
    let outcomeID: UUID?
    let title: String

    var id: String { outcomeID?.uuidString ?? "none" }
}
