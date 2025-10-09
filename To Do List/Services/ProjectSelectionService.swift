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
        print("📌 [GET PINNED] ==================")
        print("📌 [GET PINNED] Loading pinned projects...")

        // Check if we have pinned projects
        if let pinnedIDs = loadPinnedProjectIDs(), !pinnedIDs.isEmpty {
            print("📌 [GET PINNED] Found \(pinnedIDs.count) pinned projects in UserDefaults:")
            for (index, uuid) in pinnedIDs.enumerated() {
                print("   Pin #\(index + 1): \(uuid.uuidString)")
            }

            // 🔥 NEW: Validate and clean stale UUIDs before returning
            validateAndCleanPinnedProjects(pinnedIDs: pinnedIDs) { validIDs in
                print("📌 [GET PINNED] After validation: \(validIDs.count) valid pinned projects")

                // If we cleaned up stale UUIDs, update UserDefaults
                if validIDs.count < pinnedIDs.count {
                    do {
                        try self.setPinnedProjectIDs(validIDs)
                        print("🧹 [GET PINNED] Cleaned up \(pinnedIDs.count - validIDs.count) stale UUIDs from UserDefaults")
                    } catch {
                        print("⚠️ [GET PINNED] Failed to save cleaned pinned list: \(error)")
                    }
                }

                print("📌 [GET PINNED] Returning \(validIDs.count) valid pinned UUIDs")
                print("📌 [GET PINNED] ==================")
                completion(validIDs)
                return
            }
        }

        print("📌 [GET PINNED] No pinned projects in UserDefaults")

        // Check if we've already done auto-selection
        let hasAutoSelected = userDefaults.bool(forKey: Self.hasAutoSelectedKey)
        print("📌 [GET PINNED] hasAutoSelected flag: \(hasAutoSelected)")

        if !hasAutoSelected {
            // First time use - auto-select and pin top 5 projects
            print("📌 [GET PINNED] First time use - triggering auto-selection of top 5 projects")
            print("📌 [GET PINNED] ==================")
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
                        print("📌 [ProjectSelectionService] Auto-pinned \(topIDs.count) top projects")
                    } catch {
                        print("⚠️ [ProjectSelectionService] Failed to auto-pin projects: \(error)")
                    }
                }

                completion(topIDs)
            }
        } else {
            // Has auto-selected before but list is empty (user unpinned all)
            print("📌 [GET PINNED] Previously auto-selected but pins were cleared")
            print("📌 [GET PINNED] Returning empty list")
            print("📌 [GET PINNED] ==================")
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

        print("📌 [ProjectSelectionService] Saved \(projectIDs.count) pinned projects")
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
        print("📌 [ProjectSelectionService] Cleared all pinned projects")
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
        print("🔝 [GET TOP PROJECTS] ==================")
        print("🔝 [GET TOP PROJECTS] Fetching top \(limit) projects by score")
        print("🔝 [GET TOP PROJECTS] Reference date: \(referenceDate)")

        context.perform { [weak self] in
            guard let self = self else {
                print("🔝 [GET TOP PROJECTS] Self is nil, returning empty")
                completion([])
                return
            }

            // Fetch all custom projects (exclude Inbox)
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(
                format: "projectID != %@",
                ProjectConstants.inboxProjectID as CVarArg
            )

            print("🔝 [GET TOP PROJECTS] Inbox UUID to exclude: \(ProjectConstants.inboxProjectID.uuidString)")

            guard let allProjects = try? self.context.fetch(request) else {
                print("🔝 [GET TOP PROJECTS] Failed to fetch projects (query error)")
                print("🔝 [GET TOP PROJECTS] ==================")
                completion([])
                return
            }

            print("🔝 [GET TOP PROJECTS] Found \(allProjects.count) custom projects")
            for project in allProjects {
                print("   - '\(project.projectName ?? "Unknown")' | UUID: \(project.projectID?.uuidString ?? "nil")")
            }

            // Calculate weekly score for each project
            var projectScores: [(UUID, Int)] = []
            let group = DispatchGroup()

            for project in allProjects {
                guard let projectID = project.projectID else {
                    print("   ⚠️ Skipping project '\(project.projectName ?? "Unknown")' - no UUID")
                    continue
                }

                group.enter()
                self.calculateWeeklyScore(for: projectID, weekOf: referenceDate) { score in
                    projectScores.append((projectID, score))
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                print("🔝 [GET TOP PROJECTS] Calculated scores for \(projectScores.count) projects:")
                for (index, (projectID, score)) in projectScores.enumerated() {
                    let projectName = allProjects.first { $0.projectID == projectID }?.projectName ?? "Unknown"
                    print("   #\(index+1): '\(projectName)' - \(score) points")
                }

                // Sort by score descending and take top N
                let topProjects = projectScores
                    .sorted { $0.1 > $1.1 }
                    .prefix(limit)
                    .map { $0.0 }

                print("🔝 [GET TOP PROJECTS] Top \(min(limit, topProjects.count)) projects selected:")
                for (index, uuid) in topProjects.enumerated() {
                    let projectName = allProjects.first { $0.projectID == uuid }?.projectName ?? "Unknown"
                    let score = projectScores.first { $0.0 == uuid }?.1 ?? 0
                    print("   #\(index+1): '\(projectName)' (\(uuid.uuidString)) - \(score) points")
                }

                print("🔝 [GET TOP PROJECTS] Returning \(topProjects.count) UUIDs")
                print("🔝 [GET TOP PROJECTS] ==================")

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
                    print("🧹 [INTEGRITY CHECK] Cleaned up \(originalCount - validCount) stale UUIDs")
                } catch {
                    print("⚠️ [INTEGRITY CHECK] Failed to save cleaned list: \(error)")
                }
            }

            completion(originalCount, validCount)
        }
    }

    // MARK: - Private Methods

    /// 🔥 NEW: Validate pinned UUIDs against database and remove stale ones
    private func validateAndCleanPinnedProjects(pinnedIDs: [UUID], completion: @escaping ([UUID]) -> Void) {
        print("🔍 [VALIDATE PINNED] ==================")
        print("🔍 [VALIDATE PINNED] Validating \(pinnedIDs.count) pinned UUIDs against database")

        context.perform {
            // Fetch all projects that actually exist in the database
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            guard let allProjects = try? self.context.fetch(request) else {
                print("   ❌ Failed to fetch projects for validation")
                DispatchQueue.main.async {
                    completion(pinnedIDs) // Return original list if validation fails
                }
                return
            }

            print("   📊 Found \(allProjects.count) projects in database")

            // Create a set of existing UUIDs for efficient lookup
            let existingUUIDs = Set(allProjects.compactMap { $0.projectID })
            print("   🎯 Found \(existingUUIDs.count) projects with valid UUIDs")

            // Filter out stale UUIDs
            var validUUIDs: [UUID] = []
            var staleUUIDs: [UUID] = []

            for uuid in pinnedIDs {
                if existingUUIDs.contains(uuid) {
                    validUUIDs.append(uuid)
                    print("   ✅ Valid: \(uuid.uuidString)")
                } else {
                    staleUUIDs.append(uuid)
                    print("   ❌ Stale: \(uuid.uuidString) (not found in database)")
                }
            }

            print("🔍 [VALIDATE PINNED] Results:")
            print("   Original pinned: \(pinnedIDs.count)")
            print("   Valid UUIDs: \(validUUIDs.count)")
            print("   Stale UUIDs: \(staleUUIDs.count)")

            if !staleUUIDs.isEmpty {
                print("   🧹 Will remove stale UUIDs:")
                for staleUUID in staleUUIDs {
                    print("      - \(staleUUID.uuidString)")
                }
            }

            print("🔍 [VALIDATE PINNED] ==================")

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
