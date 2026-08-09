import Foundation

public enum Destination: String, Codable, CaseIterable, Hashable, Sendable {
    case home
    case plan
    case track
    case insights
    case eva

    public var title: String {
        switch self {
        case .home: return "Home"
        case .plan: return "Plan"
        case .track: return "Track"
        case .insights: return "Insights"
        case .eva: return "Eva"
        }
    }

    public var systemImage: String {
        switch self {
        case .home: return "house"
        case .plan: return "calendar"
        case .track: return "chart.bar.fill"
        case .insights: return "sparkles"
        case .eva: return "bubble.left.and.bubble.right"
        }
    }
}

public enum DashboardMode: String, Codable, CaseIterable, Hashable, Sendable {
    case smart
    case work
    case personal
    case lowEnergy

    public var title: String {
        switch self {
        case .smart: return "Smart"
        case .work: return "Work"
        case .personal: return "Personal"
        case .lowEnergy: return "Low Energy"
        }
    }

    public var systemImage: String {
        switch self {
        case .smart: return "sparkles"
        case .work: return "briefcase"
        case .personal: return "person.crop.circle"
        // A leaf, not a moon — night is already the daypart's symbol.
        case .lowEnergy: return "leaf"
        }
    }

    public var summary: String {
        switch self {
        case .smart: return "Everything, ordered by what needs you."
        case .work: return "Work commitments only. Personal care stays private."
        case .personal: return "Life outside work."
        case .lowEnergy: return "Less on screen. Care and rest first."
        }
    }
}

public enum WidgetSizePreset: String, CaseIterable, Hashable, Sendable {
    case compact
    case standard
    case wide
    case tall
    case expanded

    public static func persistedValue(rawValue: String) -> WidgetSizePreset? {
        if rawValue == "hero" { return .tall }
        if rawValue == "glance" { return .compact }
        if rawValue == "story" { return .tall }
        return WidgetSizePreset(rawValue: rawValue)
    }

    public var title: String {
        switch self {
        case .compact: return "Glance"
        case .standard: return "Compact"
        case .wide: return "Wide"
        case .tall: return "Story"
        case .expanded: return "Expanded"
        }
    }

    public var canonicalGridSpan: HomeGridSpan {
        switch self {
        case .compact: return .init(columns: 2, rows: 1)
        case .standard: return .init(columns: 2, rows: 2)
        case .wide: return .init(columns: 4, rows: 2)
        case .tall: return .init(columns: 4, rows: 3)
        case .expanded: return .init(columns: 4, rows: 4)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let value = Self.persistedValue(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported widget size preset: \(rawValue)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

extension WidgetSizePreset: Codable {}

public struct HomeGridSpan: Codable, Hashable, Sendable {
    public let columns: Int
    public let rows: Int

    public init(columns: Int, rows: Int) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
    }
}

public struct HomeGridPosition: Codable, Hashable, Sendable {
    public var column: Int
    public var row: Int

    public init(column: Int, row: Int) {
        self.column = max(0, column)
        self.row = max(0, row)
    }
}

public enum HomeCardOwnership: String, Codable, CaseIterable, Hashable, Sendable {
    case pinned
    case smart
    case suggested
    case system

    public var accessibilityDescription: String {
        switch self {
        case .pinned: return "Pinned by you"
        case .smart: return "Adaptive smart slot"
        case .suggested: return "Suggested for now"
        case .system: return "Active system state"
        }
    }
}

public enum HomeSmartSlotSchedule: String, Codable, CaseIterable, Hashable, Sendable {
    case morning
    case workday
    case evening
    case weekend
    case always

    public var title: String {
        switch self {
        case .morning: return "Morning"
        case .workday: return "Workday"
        case .evening: return "Evening"
        case .weekend: return "Weekend"
        case .always: return "Always adaptive"
        }
    }
}

public struct HomeSmartSlotConfiguration: Codable, Hashable, Sendable {
    public var allowedDestinations: Set<Destination>
    public var schedule: HomeSmartSlotSchedule
    public var frozenWidgetKind: String?

    public init(
        allowedDestinations: Set<Destination> = Set(Destination.allCases),
        schedule: HomeSmartSlotSchedule = .always,
        frozenWidgetKind: String? = nil
    ) {
        self.allowedDestinations = allowedDestinations
        self.schedule = schedule
        self.frozenWidgetKind = frozenWidgetKind
    }
}

public enum DataSensitivity: String, Codable, CaseIterable, Hashable, Sendable {
    case privateSensitive
    case privateStandard
    case shareEligible
}


public enum FoundationSchema {
    public static let dashboardLayoutVersion = 5
    public static let goalContractVersion = 1
    public static let routineContractVersion = 1
    public static let trackerContractVersion = 1
    public static let journalContractVersion = 1
    public static let collaborationContractVersion = 1
    public static let wellnessContractVersion = 1
}

public struct DashboardWidgetKind: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Carries whatever setup the user deferred — permissions they skipped,
    /// targets they have not set — and removes itself once there is nothing
    /// left to offer. Onboarding cannot ask for everything, so the long tail
    /// lives here rather than in a longer wizard.
    public static let setupChecklist = Self(rawValue: "setupChecklist")
    public static let focusNow = Self(rawValue: "focusNow")
    public static let lifeSnapshot = Self(rawValue: "lifeSnapshot")
    public static let care = Self(rawValue: "care")
    public static let tasks = Self(rawValue: "tasks")
    public static let routines = Self(rawValue: "routines")
    public static let scheduleCapacity = Self(rawValue: "scheduleCapacity")
    public static let quickCapture = Self(rawValue: "quickCapture")
    public static let compactTimeline = Self(rawValue: "compactTimeline")
    public static let journal = Self(rawValue: "journal")
    public static let progressReflection = Self(rawValue: "progressReflection")
    public static let fasting = Self(rawValue: "fasting")
    public static let goals = Self(rawValue: "goals")
    public static let evaConversation = Self(rawValue: "evaConversation")
    public static let bodyMetric = Self(rawValue: "bodyMetric")
    public static let workout = Self(rawValue: "workout")
    public static let sleep = Self(rawValue: "sleep")
    public static let movement = Self(rawValue: "movement")
    public static let lifeMoment = Self(rawValue: "lifeMoment")
    public static let nutritionSummary = Self(rawValue: "nutritionSummary")
    public static let recentMeal = Self(rawValue: "recentMeal")
    public static let logMeal = Self(rawValue: "logMeal")
}

public enum WidgetGalleryCategory: String, Codable, CaseIterable, Sendable {
    case orient, act, plan, wellbeing, reflect, progress
}

public enum WidgetMultiplicity: String, Codable, Sendable {
    case singleton
    case multipleInstances
}

/// How a card presents itself. One archetype is one reusable body that must
/// render at *every* supported size — this is what removes the old
/// `EmptyView()` fallthrough, where eleven kinds drew nothing at wide and tall
/// (and therefore nothing at all at accessibility text sizes, which force wide).
public enum HomeCardArchetype: String, Codable, CaseIterable, Hashable, Sendable {
    /// Hero numeral, unit and change. Sparkline or chart as it grows.
    case metric
    /// Circular progress against a target.
    case ring
    /// A series over time: sparkline → chart → chart plus table.
    case trend
    /// Rows of work with state and a primary action.
    case queue
    /// Recent-performance dots or heat grid.
    case streak
    /// One claim, its rationale and one action. Home's hero.
    case decision
    /// A compressed view of the day's shape.
    case spine
    /// A remembered moment: mood, media or excerpt.
    case moment
    /// Time remaining until a dated thing.
    case countdown
    /// A capture affordance rather than a readout.
    case action
}

/// Which anchored Home section a card belongs to. Previously this lived as
/// three hardcoded string sets inside the Home view plus a fourth copy in the
/// layout repository, so registering a new kind silently dropped it into
/// "Your space" and the two anchored copies could disagree.
public enum HomeSectionRole: String, Codable, CaseIterable, Hashable, Sendable {
    /// Rendered by a fixed Home section, never as a free-floating placement.
    case anchored
    /// Today's committed work.
    case today
    /// Recurring care, routines and wellbeing.
    case keepSteady
    /// Reflection and closing the day.
    case closeLoop
    /// Whatever the user chose to pin.
    case userSpace

    public var title: String {
        switch self {
        case .anchored: "Now"
        case .today: "Today"
        case .keepSteady: "Keep steady"
        case .closeLoop: "Close the loop"
        case .userSpace: "Your space"
        }
    }
}

public struct DashboardWidgetDescriptor: Codable, Hashable, Sendable {
    public let kind: DashboardWidgetKind
    public let title: String
    public let category: WidgetGalleryCategory
    public let supportedSizes: Set<WidgetSizePreset>
    public let multiplicity: WidgetMultiplicity
    public let sensitivity: DataSensitivity
    public let archetype: HomeCardArchetype
    public let sectionRole: HomeSectionRole
    public let configurationVersion: Int

    public init(
        kind: DashboardWidgetKind,
        title: String,
        category: WidgetGalleryCategory,
        supportedSizes: Set<WidgetSizePreset>,
        multiplicity: WidgetMultiplicity,
        sensitivity: DataSensitivity,
        archetype: HomeCardArchetype = .queue,
        sectionRole: HomeSectionRole = .userSpace,
        configurationVersion: Int = 1
    ) {
        self.kind = kind
        self.title = title
        self.category = category
        self.supportedSizes = supportedSizes
        self.multiplicity = multiplicity
        self.sensitivity = sensitivity
        self.archetype = archetype
        self.sectionRole = sectionRole
        self.configurationVersion = configurationVersion
    }
}


public protocol DashboardWidgetRegistry: Sendable {
    func descriptor(for kind: DashboardWidgetKind) -> DashboardWidgetDescriptor?
    func availableDescriptors() -> [DashboardWidgetDescriptor]
}

public struct DefaultDashboardWidgetRegistry: DashboardWidgetRegistry {
    public static let shared = DefaultDashboardWidgetRegistry()

    private let descriptors: [DashboardWidgetDescriptor]

    public init() {
        let allSizes = Set(WidgetSizePreset.allCases)
        descriptors = [
            .init(kind: .setupChecklist, title: "Finish setup", category: .orient, supportedSizes: [.standard, .wide], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .ring, sectionRole: .userSpace),
            .init(kind: .focusNow, title: "Focus Now", category: .act, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .decision, sectionRole: .anchored),
            .init(kind: .lifeSnapshot, title: "Life Snapshot", category: .orient, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .metric, sectionRole: .anchored),
            .init(kind: .care, title: "Care", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .queue, sectionRole: .keepSteady),
            // Today's committed work belongs above wellbeing, not last on the
            // board. It has its own anchored section now.
            .init(kind: .tasks, title: "Today’s Tasks", category: .act, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .queue, sectionRole: .today),
            .init(kind: .routines, title: "Routines", category: .wellbeing, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .queue, sectionRole: .keepSteady),
            .init(kind: .scheduleCapacity, title: "Schedule & Capacity", category: .plan, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .multipleInstances, sensitivity: .privateStandard, archetype: .spine, sectionRole: .anchored),
            .init(kind: .quickCapture, title: "Quick Capture", category: .act, supportedSizes: [.compact, .standard, .wide], multiplicity: .singleton, sensitivity: .privateStandard, archetype: .action, sectionRole: .anchored),
            .init(kind: .compactTimeline, title: "Day Shape", category: .plan, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .multipleInstances, sensitivity: .privateStandard, archetype: .spine, sectionRole: .anchored),
            .init(kind: .journal, title: "Journal", category: .reflect, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .moment, sectionRole: .closeLoop),
            .init(kind: .progressReflection, title: "Progress & Reflection", category: .reflect, supportedSizes: allSizes, multiplicity: .multipleInstances, sensitivity: .privateSensitive, archetype: .trend, sectionRole: .closeLoop),
            .init(kind: .fasting, title: "Active Fast", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .ring, sectionRole: .keepSteady),
            .init(kind: .goals, title: "Goal Progress", category: .progress, supportedSizes: [.standard, .wide, .tall, .expanded], multiplicity: .multipleInstances, sensitivity: .privateStandard, archetype: .ring, sectionRole: .keepSteady),
            .init(kind: .evaConversation, title: "Saved Eva Insight", category: .reflect, supportedSizes: [.standard, .wide, .tall], multiplicity: .multipleInstances, sensitivity: .privateSensitive, archetype: .moment, sectionRole: .closeLoop),
            .init(kind: .bodyMetric, title: "Body Metric", category: .wellbeing, supportedSizes: allSizes, multiplicity: .multipleInstances, sensitivity: .privateSensitive, archetype: .trend, sectionRole: .keepSteady),
            .init(kind: .workout, title: "Recent Workout", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .metric, sectionRole: .keepSteady),
            .init(kind: .sleep, title: "Sleep Note", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .trend, sectionRole: .keepSteady),
            .init(kind: .movement, title: "Movement", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .metric, sectionRole: .keepSteady),
            .init(kind: .lifeMoment, title: "Life Moment", category: .reflect, supportedSizes: allSizes, multiplicity: .multipleInstances, sensitivity: .privateStandard, archetype: .countdown, sectionRole: .closeLoop),
            .init(kind: .nutritionSummary, title: "Nutrition Summary", category: .wellbeing, supportedSizes: allSizes, multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .metric, sectionRole: .keepSteady),
            .init(kind: .recentMeal, title: "Recent Meal", category: .wellbeing, supportedSizes: [.compact, .standard, .wide, .tall], multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .moment, sectionRole: .keepSteady),
            .init(kind: .logMeal, title: "Log Meal", category: .act, supportedSizes: [.compact, .standard, .wide], multiplicity: .singleton, sensitivity: .privateSensitive, archetype: .action, sectionRole: .keepSteady)
        ]
    }

    public func descriptor(for kind: DashboardWidgetKind) -> DashboardWidgetDescriptor? {
        descriptors.first { $0.kind == kind }
    }

    public func availableDescriptors() -> [DashboardWidgetDescriptor] {
        descriptors
    }
}
