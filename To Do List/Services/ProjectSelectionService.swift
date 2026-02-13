//
//  ProjectSelectionService.swift
//  To Do List
//
//  Created by Assistant on Radar Chart Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import Foundation
import CoreData

/// Service for managing user's selected projects for radar chart visualization
/// Handles persistence and smart defaults for project selection
class ProjectSelectionService {

    // MARK: - Constants

    private static let selectedProjectIDsKey = "RadarChartSelectedProjectIDs" // Legacy key (kept for migration)
    private static let pinnedProjectIDsKey = "RadarChartPinnedProjectIDs" // New pinning system
    private static let maxProjectSelections = 5
    private static let hasAutoSelectedKey = "RadarChartHasAutoSelected" // Track if we've done initial auto-selection

    // MARK: - Properties

    private let context: NSManagedObjectContext
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) {
        self.context = context
        self.userDefaults = userDefaults
    }

    // MARK: - Public Methods

    /// Get the list of pinned project IDs for radar chart display
    /// On first use, auto-selects and pins top 5 projects by score
    /// Returns pinned projects (either user-selected or auto-selected)
    func getPinnedProjectIDs(completion: @escaping ([UUID]) -> Void) {

        // Check if we have pinned projects
        if let pinnedIDs = loadPinnedProjectIDs(), !pinnedIDs.isEmpty {
            for (index, uuid) in pinnedIDs.enumerated() {
            }

            // 🔥 NEW: Validate and clean stale UUIDs before returning
            validateAndCleanPinnedProjects(pinnedIDs: pinnedIDs) { validIDs in

                // If we cleaned up stale UUIDs, update UserDefaults
                if validIDs.count < pinnedIDs.count {
                    do {
                        try self.setPinnedProjectIDs(validIDs)
                    } catch {
                        logWarning(
                            event: "project_pins_cleanup_persist_failed",
                            message: "Failed to persist cleaned pinned project IDs",
                            fields: ["error": error.localizedDescription]
                        )
                    }
                }

                completion(validIDs)
                return
            }
        }


        // Check if we've already done auto-selection
        let hasAutoSelected = userDefaults.bool(forKey: Self.hasAutoSelectedKey)

        if !hasAutoSelected {
            // First time use - auto-select and pin top 5 projects
            getTopProjectIDsByScore(limit: Self.maxProjectSelections) { [weak self] topIDs in
                guard let self = self else {
                    completion([])
                    return
                }

                // Save these as pinned projects
                if !topIDs.isEmpty {
                    do {
                        try self.setPinnedProjectIDs(topIDs)
                        self.userDefaults.set(true, forKey: Self.hasAutoSelectedKey)
                        self.userDefaults.synchronize()
                    } catch {
                        logWarning(
                            event: "project_auto_pin_persist_failed",
                            message: "Failed to persist auto-selected pinned projects",
                            fields: ["error": error.localizedDescription]
                        )
                    }
                }

                completion(topIDs)
            }
        } else {
            // Has auto-selected before but list is empty (user unpinned all)
            completion([])
        }
    }

    /// Set pinned project IDs for radar chart display
    /// Replaces any existing pinned projects
    func setPinnedProjectIDs(_ projectIDs: [UUID]) throws {
        guard projectIDs.count <= Self.maxProjectSelections else {
            throw ProjectSelectionError.tooManyProjects(max: Self.maxProjectSelections)
        }

        let idStrings = projectIDs.map { $0.uuidString }
        userDefaults.set(idStrings, forKey: Self.pinnedProjectIDsKey)
        userDefaults.synchronize()

    }

    /// Check if a specific project is pinned
    func isProjectPinned(_ projectID: UUID) -> Bool {
        guard let pinnedIDs = loadPinnedProjectIDs() else { return false }
        return pinnedIDs.contains(projectID)
    }

    /// Add a project to pinned list
    func pinProject(_ projectID: UUID) throws {
        var pinned = loadPinnedProjectIDs() ?? []

        guard !pinned.contains(projectID) else {
            // Already pinned
            return
        }

        guard pinned.count < Self.maxProjectSelections else {
            throw ProjectSelectionError.tooManyProjects(max: Self.maxProjectSelections)
        }

        pinned.append(projectID)
        try setPinnedProjectIDs(pinned)
    }

    /// Remove a project from pinned list
    func unpinProject(_ projectID: UUID) throws {
        var pinned = loadPinnedProjectIDs() ?? []
        pinned.removeAll { $0 == projectID }
        try setPinnedProjectIDs(pinned)
    }

    /// Clear all pinned projects
    func clearPinnedProjects() {
        userDefaults.removeObject(forKey: Self.pinnedProjectIDsKey)
        userDefaults.synchronize()
    }

    /// Get the list of project IDs selected for radar chart display (LEGACY)
    /// Returns auto-selected top projects if no manual selection exists
    @available(*, deprecated, message: "Use getPinnedProjectIDs instead")
    func getSelectedProjectIDs(completion: @escaping ([UUID]) -> Void) {
        // First check if user has manually selected projects
        if let savedIDs = loadSavedProjectIDs(), !savedIDs.isEmpty {
            completion(savedIDs)
            return
        }

        // Otherwise, auto-select top 5 projects by score
        getTopProjectIDsByScore(limit: Self.maxProjectSelections) { topIDs in
            completion(topIDs)
        }
    }

    /// Save user's manual project selection for radar chart
    func setSelectedProjectIDs(_ projectIDs: [UUID]) throws {
        guard projectIDs.count <= Self.maxProjectSelections else {
            throw ProjectSelectionError.tooManyProjects(max: Self.maxProjectSelections)
        }

        // Convert UUIDs to strings for storage
        let idStrings = projectIDs.map { $0.uuidString }
        userDefaults.set(idStrings, forKey: Self.selectedProjectIDsKey)
        userDefaults.synchronize()
    }

    /// Clear manual selection (reverts to auto-selection)
    func clearSelection() {
        userDefaults.removeObject(forKey: Self.selectedProjectIDsKey)
        userDefaults.synchronize()
    }

    /// Get top N projects by total weekly score
    func getTopProjectIDsByScore(limit: Int, weekOf referenceDate: Date = Date(), completion: @escaping ([UUID]) -> Void) {

        context.perform { [weak self] in
            guard let self = self else {
                completion([])
                return
            }

            // Fetch all custom projects (exclude Inbox)
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(
                format: "projectID != %@",
                ProjectConstants.inboxProjectID as CVarArg
            )


            guard let allProjects = try? self.context.fetch(request) else {
                logError(
                    event: "project_top_list_fetch_failed",
                    message: "Failed to fetch projects for top-project calculation"
                )
                completion([])
                return
            }

            for project in allProjects {
            }

            // Calculate weekly score for each project
            var projectScores: [(UUID, Int)] = []
            let group = DispatchGroup()

            for project in allProjects {
                guard let projectID = project.projectID else {
                    continue
                }

                group.enter()
                self.calculateWeeklyScore(for: projectID, weekOf: referenceDate) { score in
                    projectScores.append((projectID, score))
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                for (index, (projectID, score)) in projectScores.enumerated() {
                    let projectName = allProjects.first { $0.projectID == projectID }?.projectName ?? "Unknown"
                }

                // Sort by score descending and take top N
                let topProjects = projectScores
                    .sorted { $0.1 > $1.1 }
                    .prefix(limit)
                    .map { $0.0 }

                for (index, uuid) in topProjects.enumerated() {
                    let projectName = allProjects.first { $0.projectID == uuid }?.projectName ?? "Unknown"
                    let score = projectScores.first { $0.0 == uuid }?.1 ?? 0
                }


                completion(Array(topProjects))
            }
        }
    }

    /// Check if a project selection is manual (user-set) or automatic
    func isManualSelection() -> Bool {
        return loadSavedProjectIDs() != nil
    }

    /// Get maximum allowed project selections
    var maxSelections: Int {
        return Self.maxProjectSelections
    }

    /// 🔥 NEW: Public method to validate and clean pinned projects
    /// Can be called manually to trigger cleanup of stale pins
    func validateAndCleanPinnedProjectsNow(completion: @escaping (Int, Int) -> Void) {
        // total: original count, valid: count after cleanup
        guard let pinnedIDs = loadPinnedProjectIDs(), !pinnedIDs.isEmpty else {
            completion(0, 0)
            return
        }

        validateAndCleanPinnedProjects(pinnedIDs: pinnedIDs) { [weak self] validIDs in
            guard let self = self else {
                completion(pinnedIDs.count, pinnedIDs.count)
                return
            }

            let originalCount = pinnedIDs.count
            let validCount = validIDs.count

            // If we found stale UUIDs, update UserDefaults
            if validCount < originalCount {
                do {
                    try self.setPinnedProjectIDs(validIDs)
                } catch {
                    logWarning(
                        event: "project_pin_integrity_persist_failed",
                        message: "Failed to persist cleaned pinned project list",
                        fields: ["error": error.localizedDescription]
                    )
                }
            }

            completion(originalCount, validCount)
        }
    }

    // MARK: - Private Methods

    /// 🔥 NEW: Validate pinned UUIDs against database and remove stale ones
    private func validateAndCleanPinnedProjects(pinnedIDs: [UUID], completion: @escaping ([UUID]) -> Void) {

        context.perform {
            // Fetch all projects that actually exist in the database
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            guard let allProjects = try? self.context.fetch(request) else {
                logError(
                    event: "project_pin_validation_fetch_failed",
                    message: "Failed to fetch projects for pin validation"
                )
                DispatchQueue.main.async {
                    completion(pinnedIDs) // Return original list if validation fails
                }
                return
            }


            // Create a set of existing UUIDs for efficient lookup
            let existingUUIDs = Set(allProjects.compactMap { $0.projectID })

            // Filter out stale UUIDs
            var validUUIDs: [UUID] = []
            var staleUUIDs: [UUID] = []

            for uuid in pinnedIDs {
                if existingUUIDs.contains(uuid) {
                    validUUIDs.append(uuid)
                } else {
                    staleUUIDs.append(uuid)
                }
            }


            if !staleUUIDs.isEmpty {
                for staleUUID in staleUUIDs {
                }
            }


            DispatchQueue.main.async {
                completion(validUUIDs)
            }
        }
    }

    private func loadPinnedProjectIDs() -> [UUID]? {
        guard let idStrings = userDefaults.stringArray(forKey: Self.pinnedProjectIDsKey) else {
            return nil
        }

        let uuids = idStrings.compactMap { UUID(uuidString: $0) }
        return uuids.isEmpty ? nil : uuids
    }

    private func loadSavedProjectIDs() -> [UUID]? {
        guard let idStrings = userDefaults.stringArray(forKey: Self.selectedProjectIDsKey) else {
            return nil
        }

        let uuids = idStrings.compactMap { UUID(uuidString: $0) }
        return uuids.isEmpty ? nil : uuids
    }

    private func calculateWeeklyScore(for projectID: UUID, weekOf referenceDate: Date, completion: @escaping (Int) -> Void) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1 // Sunday

        let week = calendar.daysWithSameWeekOfYear(as: referenceDate)
        let startOfWeek = week.first ?? referenceDate.startOfDay
        let endOfWeek = week.last?.endOfDay ?? referenceDate.endOfDay

        // Fetch all tasks completed in this week for this project
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(
            format: "projectID == %@ AND isComplete == YES AND dateCompleted >= %@ AND dateCompleted <= %@",
            projectID.uuidString,
            startOfWeek as NSDate,
            endOfWeek as NSDate
        )

        guard let tasks = try? context.fetch(request) else {
            completion(0)
            return
        }

        // Sum scores of all completed tasks
        var totalScore = 0
        for task in tasks {
            totalScore += TaskScoringService.shared.calculateScore(for: task)
        }

        completion(totalScore)
    }
}

// MARK: - Errors

enum ProjectSelectionError: LocalizedError {
    case tooManyProjects(max: Int)

    var errorDescription: String? {
        switch self {
        case .tooManyProjects(let max):
            return "Cannot select more than \(max) projects for radar chart"
        }
    }
}
