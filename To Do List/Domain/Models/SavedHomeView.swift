//
//  SavedHomeView.swift
//  Tasker
//
//  User-defined reusable Home filter presets
//

import Foundation

public struct SavedHomeView: Codable, Equatable, Identifiable {
    public static let schemaVersion = 1

    public let id: UUID
    public let version: Int
    public var name: String
    public var quickView: HomeQuickView
    public var selectedProjectIDs: [UUID]
    public var advancedFilter: HomeAdvancedFilter?
    public var showCompletedInline: Bool
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        version: Int = SavedHomeView.schemaVersion,
        name: String,
        quickView: HomeQuickView,
        selectedProjectIDs: [UUID] = [],
        advancedFilter: HomeAdvancedFilter? = nil,
        showCompletedInline: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.version = version
        self.name = name
        self.quickView = quickView
        self.selectedProjectIDs = selectedProjectIDs
        self.advancedFilter = advancedFilter
        self.showCompletedInline = showCompletedInline
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public func asFilterState(pinnedProjectIDs: [UUID]) -> HomeFilterState {
        HomeFilterState(
            quickView: quickView,
            selectedProjectIDs: selectedProjectIDs,
            pinnedProjectIDs: pinnedProjectIDs,
            advancedFilter: advancedFilter,
            showCompletedInline: showCompletedInline,
            selectedSavedViewID: id
        )
    }
}
