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

    private static let selectedProjectIDsKey = "RadarChartSelectedProjectIDs"
    private static let maxProjectSelections = 5

    // MARK: - Properties

    private let context: NSManagedObjectContext
    private let userDefaults: UserDefaults

    // MARK: - Initialization

    init(context: NSManagedObjectContext, userDefaults: UserDefaults = .standard) {
        self.context = context
        self.userDefaults = userDefaults
    }

    // MARK: - Public Methods

    /// Get the list of project IDs selected for radar chart display
    /// Returns auto-selected top projects if no manual selection exists
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
                completion([])
                return
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
                // Sort by score descending and take top N
                let topProjects = projectScores
                    .sorted { $0.1 > $1.1 }
                    .prefix(limit)
                    .map { $0.0 }

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

    // MARK: - Private Methods

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
