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
    public var selectedProjectIDs: [UUID]
    public var pinnedProjectIDs: [UUID]
    public var advancedFilter: HomeAdvancedFilter?
    public var showCompletedInline: Bool
    public var selectedSavedViewID: UUID?

    public init(
        version: Int = HomeFilterState.schemaVersion,
        quickView: HomeQuickView = .defaultView,
        selectedProjectIDs: [UUID] = [],
        pinnedProjectIDs: [UUID] = [],
        advancedFilter: HomeAdvancedFilter? = nil,
        showCompletedInline: Bool = false,
        selectedSavedViewID: UUID? = nil
    ) {
        self.version = version
        self.quickView = quickView
        self.selectedProjectIDs = selectedProjectIDs
        self.pinnedProjectIDs = pinnedProjectIDs
        self.advancedFilter = advancedFilter
        self.showCompletedInline = showCompletedInline
        self.selectedSavedViewID = selectedSavedViewID
    }

    public static var `default`: HomeFilterState {
        HomeFilterState(
            quickView: .today,
            selectedProjectIDs: [],
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
}
