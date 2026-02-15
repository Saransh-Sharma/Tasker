//
//  HomeFilterState.swift
//  Tasker
//
//  Persisted filter state for Home "Focus Engine"
//

import Foundation

public enum HomeTagMatchMode: String, Codable {
    case any
    case all
}

public struct HomeDateRange: Codable, Equatable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public struct HomeAdvancedFilter: Codable, Equatable {
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

public struct HomeFilterState: Codable, Equatable {
    public static let schemaVersion = 1

    public let version: Int
    public var quickView: HomeQuickView
    public var projectGroupingMode: HomeProjectGroupingMode
    public var selectedProjectIDs: [UUID]
    public var customProjectOrderIDs: [UUID]
    public var pinnedProjectIDs: [UUID]
    public var advancedFilter: HomeAdvancedFilter?
    public var showCompletedInline: Bool
    public var selectedSavedViewID: UUID?

    public init(
        version: Int = HomeFilterState.schemaVersion,
        quickView: HomeQuickView = .defaultView,
        projectGroupingMode: HomeProjectGroupingMode = .defaultMode,
        selectedProjectIDs: [UUID] = [],
        customProjectOrderIDs: [UUID] = [],
        pinnedProjectIDs: [UUID] = [],
        advancedFilter: HomeAdvancedFilter? = nil,
        showCompletedInline: Bool = false,
        selectedSavedViewID: UUID? = nil
    ) {
        self.version = version
        self.quickView = quickView
        self.projectGroupingMode = projectGroupingMode
        self.selectedProjectIDs = selectedProjectIDs
        self.customProjectOrderIDs = customProjectOrderIDs
        self.pinnedProjectIDs = pinnedProjectIDs
        self.advancedFilter = advancedFilter
        self.showCompletedInline = showCompletedInline
        self.selectedSavedViewID = selectedSavedViewID
    }

    public static var `default`: HomeFilterState {
        HomeFilterState(
            quickView: .today,
            projectGroupingMode: .defaultMode,
            selectedProjectIDs: [],
            customProjectOrderIDs: [],
            pinnedProjectIDs: [],
            advancedFilter: nil,
            showCompletedInline: false,
            selectedSavedViewID: nil
        )
    }

    public var selectedProjectIDSet: Set<UUID> {
        Set(selectedProjectIDs)
    }

    public var pinnedProjectIDSet: Set<UUID> {
        Set(pinnedProjectIDs)
    }

    /// Compatibility helper for legacy filter checks in views.
    public var hasActiveFilters: Bool {
        !selectedProjectIDs.isEmpty
            || advancedFilter != nil
            || quickView != .today
            || projectGroupingMode != .defaultMode
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case quickView
        case projectGroupingMode
        case selectedProjectIDs
        case customProjectOrderIDs
        case pinnedProjectIDs
        case advancedFilter
        case showCompletedInline
        case selectedSavedViewID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? HomeFilterState.schemaVersion
        quickView = try container.decodeIfPresent(HomeQuickView.self, forKey: .quickView) ?? .defaultView
        projectGroupingMode = try container.decodeIfPresent(HomeProjectGroupingMode.self, forKey: .projectGroupingMode) ?? .defaultMode
        selectedProjectIDs = try container.decodeIfPresent([UUID].self, forKey: .selectedProjectIDs) ?? []
        customProjectOrderIDs = try container.decodeIfPresent([UUID].self, forKey: .customProjectOrderIDs) ?? []
        pinnedProjectIDs = try container.decodeIfPresent([UUID].self, forKey: .pinnedProjectIDs) ?? []
        advancedFilter = try container.decodeIfPresent(HomeAdvancedFilter.self, forKey: .advancedFilter)
        showCompletedInline = try container.decodeIfPresent(Bool.self, forKey: .showCompletedInline) ?? false
        selectedSavedViewID = try container.decodeIfPresent(UUID.self, forKey: .selectedSavedViewID)
    }
}
