//
//  HomeFilterState.swift
//  LifeBoard
//
//  Persisted filter state for Home "Focus Engine"
//

import Foundation

public enum HomeTagMatchMode: String, Codable, Sendable {
    case any
    case all
}

public struct HomeDateRange: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date

    /// Initializes a new instance.
    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public struct HomeAdvancedFilter: Codable, Equatable, Sendable {
    public let priorities: [TaskPriority]
    public let categories: [TaskCategory]
    public let contexts: [TaskContext]
    public let energyLevels: [TaskEnergy]
    public let tags: [String]
    public let hasEstimate: Bool?
    public let hasDependencies: Bool?
    public let requireDueDate: Bool
    public let dateRange: HomeDateRange?
    public let tagMatchMode: HomeTagMatchMode

    /// Initializes a new instance.
    public init(
        priorities: [TaskPriority] = [],
        categories: [TaskCategory] = [],
        contexts: [TaskContext] = [],
        energyLevels: [TaskEnergy] = [],
        tags: [String] = [],
        hasEstimate: Bool? = nil,
        hasDependencies: Bool? = nil,
        requireDueDate: Bool = false,
        dateRange: HomeDateRange? = nil,
        tagMatchMode: HomeTagMatchMode = .any
    ) {
        self.priorities = priorities
        self.categories = categories
        self.contexts = contexts
        self.energyLevels = energyLevels
        self.tags = tags
        self.hasEstimate = hasEstimate
        self.hasDependencies = hasDependencies
        self.requireDueDate = requireDueDate
        self.dateRange = dateRange
        self.tagMatchMode = tagMatchMode
    }

    public var isEmpty: Bool {
        priorities.isEmpty
            && categories.isEmpty
            && contexts.isEmpty
            && energyLevels.isEmpty
            && tags.isEmpty
            && hasEstimate == nil
            && hasDependencies == nil
            && !requireDueDate
            && dateRange == nil
    }
}

public struct HomeFilterState: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public let version: Int
    public var quickView: HomeQuickView
    public var projectGroupingMode: HomeProjectGroupingMode
    public var selectedProjectIDs: [UUID]
    public var selectedLifeAreaIDs: [UUID]
    public var customProjectOrderIDs: [UUID]
    public var pinnedLifeAreaIDs: [UUID]
    public var advancedFilter: HomeAdvancedFilter?
    public var showCompletedInline: Bool
    public var selectedSavedViewID: UUID?
    /// When true, the Home content renders as a forward time-horizon stream (Upcoming and
    /// per-life-area lenses): all open tasks across time, grouped Overdue → Someday, rather than the
    /// day-scoped timeline/agenda. Drives `matchesScope` in `GetHomeFilteredTasksUseCase` and the
    /// section builder selection in `refreshDueTodayAgenda`.
    public var streamsAllForward: Bool

    /// Initializes a new instance.
    public init(
        version: Int = HomeFilterState.schemaVersion,
        quickView: HomeQuickView = .defaultView,
        projectGroupingMode: HomeProjectGroupingMode = .defaultMode,
        selectedProjectIDs: [UUID] = [],
        selectedLifeAreaIDs: [UUID] = [],
        customProjectOrderIDs: [UUID] = [],
        pinnedLifeAreaIDs: [UUID] = [],
        advancedFilter: HomeAdvancedFilter? = nil,
        showCompletedInline: Bool = false,
        selectedSavedViewID: UUID? = nil,
        streamsAllForward: Bool = false
    ) {
        self.version = version
        self.quickView = quickView
        self.projectGroupingMode = projectGroupingMode
        self.selectedProjectIDs = selectedProjectIDs
        self.selectedLifeAreaIDs = selectedLifeAreaIDs
        self.customProjectOrderIDs = customProjectOrderIDs
        self.pinnedLifeAreaIDs = pinnedLifeAreaIDs
        self.advancedFilter = advancedFilter
        self.showCompletedInline = showCompletedInline
        self.selectedSavedViewID = selectedSavedViewID
        self.streamsAllForward = streamsAllForward
    }

    public static var `default`: HomeFilterState {
        HomeFilterState(
            quickView: .today,
            projectGroupingMode: .defaultMode,
            selectedProjectIDs: [],
            selectedLifeAreaIDs: [],
            customProjectOrderIDs: [],
            pinnedLifeAreaIDs: [],
            advancedFilter: nil,
            showCompletedInline: false,
            selectedSavedViewID: nil,
            streamsAllForward: false
        )
    }

    public var selectedProjectIDSet: Set<UUID> {
        Set(selectedProjectIDs)
    }

    public var selectedLifeAreaIDSet: Set<UUID> {
        Set(selectedLifeAreaIDs)
    }

    public var pinnedLifeAreaIDSet: Set<UUID> {
        Set(pinnedLifeAreaIDs)
    }

    /// Compatibility helper for legacy filter checks in views.
    public var hasActiveFilters: Bool {
        !selectedProjectIDs.isEmpty
            || !selectedLifeAreaIDs.isEmpty
            || advancedFilter != nil
            || quickView != .today
            || streamsAllForward
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case quickView
        case projectGroupingMode
        case selectedProjectIDs
        case selectedLifeAreaIDs
        case customProjectOrderIDs
        case pinnedLifeAreaIDs
        case advancedFilter
        case showCompletedInline
        case selectedSavedViewID
        case streamsAllForward
    }

    /// Initializes a new instance.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? HomeFilterState.schemaVersion
        quickView = try container.decodeIfPresent(HomeQuickView.self, forKey: .quickView) ?? .defaultView
        projectGroupingMode = try container.decodeIfPresent(HomeProjectGroupingMode.self, forKey: .projectGroupingMode) ?? .defaultMode
        selectedProjectIDs = try container.decodeIfPresent([UUID].self, forKey: .selectedProjectIDs) ?? []
        selectedLifeAreaIDs = try container.decodeIfPresent([UUID].self, forKey: .selectedLifeAreaIDs) ?? []
        customProjectOrderIDs = try container.decodeIfPresent([UUID].self, forKey: .customProjectOrderIDs) ?? []
        pinnedLifeAreaIDs = try container.decodeIfPresent([UUID].self, forKey: .pinnedLifeAreaIDs) ?? []
        advancedFilter = try container.decodeIfPresent(HomeAdvancedFilter.self, forKey: .advancedFilter)
        showCompletedInline = try container.decodeIfPresent(Bool.self, forKey: .showCompletedInline) ?? false
        selectedSavedViewID = try container.decodeIfPresent(UUID.self, forKey: .selectedSavedViewID)
        streamsAllForward = try container.decodeIfPresent(Bool.self, forKey: .streamsAllForward) ?? false
    }
}
