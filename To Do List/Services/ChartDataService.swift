//
//  ChartDataService.swift
//  To Do List
//
//  Created by Assistant on Chart Data Service Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import Foundation
import CoreData
import DGCharts
import UIKit

// MARK: - Chart Data Service
class ChartDataService {
    // Remove singleton, use dependency injection
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Line Chart Data Generation
    
    func generateLineChartData(for referenceDate: Date? = nil) -> [ChartDataEntry] {
        var yValues: [ChartDataEntry] = []
        
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1 // Start on Sunday (1 for Sunday, 2 for Monday)
        
        // Get current week dates based on calendar's current page
        let currentReferenceDate = referenceDate ?? Date.today()
        let week = calendar.daysWithSameWeekOfYear(as: currentReferenceDate)
        let today = Date.today()
        
        // Log weekly chart generation
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy"
        print("📊 Generating chart data for week of \(dateFormatter.string(from: currentReferenceDate))")
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM dd"
        
        // Generate chart data points for the week (Sunday to Saturday)
        for (index, day) in week.enumerated() {
            let score: Int
            
            // Enhanced future date handling
            if day > today {
                // For future dates, show 0 but with special styling indication
                score = 0
                print("   🔮 Future date \(dayFormatter.string(from: day)): Setting score to 0")
            } else {
                // For past and current dates, calculate actual score
                print("   📅 Processing \(dayFormatter.string(from: day))...")
                score = calculateScoreForDate(date: day)
            }
            
            // Log each day's score
            let dayName = dayFormatter.string(from: day)
            let status = day > today ? "(Future)" : day.onSameDay(as: today) ? "(Today)" : "(Past)"
            print("   • \(dayName): \(score) points \(status)")
            
            // Ensure score is valid and not NaN or infinite
            let validScore = max(0, score) // Ensure non-negative
            let yValue = Double(validScore)
            
            // Additional safety check for NaN or infinite values
            let safeYValue = yValue.isNaN || yValue.isInfinite ? 0.0 : yValue
            
            let dataEntry = ChartDataEntry(x: Double(index), y: safeYValue)
            
            // Add metadata for future date styling (if needed)
            if day > today {
                dataEntry.data = ["isFuture": true]
            }
            
            yValues.append(dataEntry)
        }
        
        // Log weekly total
        let weeklyTotal = yValues.reduce(0) { $0 + Int($1.y) }
        print("   📈 Weekly Total: \(weeklyTotal) points")
        
        return yValues
    }
    
    func generateSampleData() -> [ChartDataEntry] {
        let sampleValues = [15.0, 25.0, 35.0, 45.0, 30.0, 50.0, 40.0]
        return sampleValues.enumerated().map { index, value in
            // Ensure value is valid and not NaN or infinite
            let safeValue = value.isNaN || value.isInfinite ? 0.0 : value
            return ChartDataEntry(x: Double(index), y: safeValue)
        }
    }
    
    // MARK: - Score Calculation
    
    /// Calculates the total score for a specific calendar day based **solely** on
    /// tasks that were *completed* on that day (regardless of their due date).
    /// - Parameter date: The day to calculate the score for (00:00 – 24:00)
    /// - Returns: The summed score of all tasks completed on that day.
    func calculateScoreForDate(date: Date) -> Int {
        var score = 0
        // Formatter reused for multiple debug prints
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Fetch **all** tasks once – cheaper than multiple Core-Data fetches during week generation
        // Fetch all tasks using Core Data directly
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let allTasks = (try? context.fetch(request)) ?? []
        
        #if DEBUG
        print("────────────────────────────────────────────────────────")
        print("🕵️‍♂️ [ChartDataService] Debug Score Calculation")
        let rangeFormatter = DateFormatter()
        rangeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("Date being evaluated: \(dayFormatter.string(from: date))")
        print(" → startOfDay: \(rangeFormatter.string(from: startOfDay))")
        print(" → endOfDay  : \(rangeFormatter.string(from: endOfDay))")
        print("Fetched ALL tasks count: \(allTasks.count)")
        #endif
        
        // Filter only the tasks that were completed on the specific day
        let tasksCompletedOnDate = allTasks.filter { task in
            guard task.isComplete, let completedDate = task.dateCompleted as Date? else { return false }
            return completedDate >= startOfDay && completedDate < endOfDay
        }
        
        #if DEBUG
        print("Tasks completed on this date (after filtering): \(tasksCompletedOnDate.count)")
        // Show up to first 10 tasks with key metadata for deeper inspection
        for (idx, task) in allTasks.prefix(20).enumerated() {
            let cd = (task.dateCompleted as Date?)?.toString(format: "yyyy-MM-dd HH:mm:ss") ?? "nil"
            let dd = (task.dueDate as Date?)?.toString(format: "yyyy-MM-dd") ?? "nil"
            print("   [AllTasks] #\(idx+1) \(task.name ?? "Unnamed") | complete: \(task.isComplete) | dateCompleted: \(cd) | dueDate: \(dd)")
        }
        #endif
        
        // --- Debug logging (can be removed in production) ---
        #if DEBUG
        print("\n🔍 [ChartDataService] Score calc for \(dayFormatter.string(from: date)) – completed tasks: \(tasksCompletedOnDate.count)")
        #endif
        print("📅 [ChartDataService] Tasks actually completed on \(dayFormatter.string(from: date)): \(tasksCompletedOnDate.count)")
        
        for (index, task) in tasksCompletedOnDate.enumerated() {
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            let completedDateStr = task.dateCompleted != nil ? dayFormatter.string(from: task.dateCompleted! as Date) : "nil"
            let dueDateStr = task.dueDate != nil ? dayFormatter.string(from: task.dueDate! as Date) : "nil"
            
            print("📝 [ChartDataService] Task \(index + 1): '\(task.name ?? "Unknown")'")
            print("   - Complete: \(task.isComplete), Priority: \(task.taskPriority), Score: \(taskScore)")
            print("   - Due Date: \(dueDateStr), Completed Date: \(completedDateStr)")
            score += taskScore
            #if DEBUG
            print("   ✅ Adding \(taskScore) points (task is complete on this date)")
            #endif
        }
        
        #if DEBUG
        print("   📊 Final score: \(score) points")
        #endif
        return score
    }
    
    func calculateScoreForProject(project: String) -> Int {
        var score = 0
        
        // Only consider tasks for the specified project
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(format: "project == %@", project)
        let projectTasks = (try? context.fetch(request)) ?? []
        
        let morningTasks = projectTasks.filter { $0.taskType == 1 } // TaskType.morning.rawValue
        let eveningTasks = projectTasks.filter { $0.taskType == 2 } // TaskType.evening.rawValue
        
        for task in morningTasks {
            if task.isComplete {
                score = score + task.getTaskScore(task: task)
            }
        }
        
        for task in eveningTasks {
            if task.isComplete {
                score = score + task.getTaskScore(task: task)
            }
        }
        
        return score
    }
    
    // MARK: - Chart Configuration Helpers
    
    func calculateDynamicMaximum(for dataEntries: [ChartDataEntry]) -> Double {
        let maxScore = dataEntries.map { $0.y }.max() ?? 0
        return max(maxScore * 1.2, 10) // Ensure minimum scale of 10
    }
    
    func createLineChartDataSet(with entries: [ChartDataEntry], colors: ToDoColors) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: entries, label: "Daily Score")
        
        // Enhanced visual configuration
        dataSet.mode = .linear
        dataSet.drawCirclesEnabled = true
        dataSet.lineWidth = 3.5
        dataSet.circleRadius = 6
        dataSet.setCircleColor(colors.secondaryAccentColor)
        dataSet.setColor(colors.primaryColor)
        dataSet.drawCircleHoleEnabled = true
        dataSet.circleHoleRadius = 3
        dataSet.circleHoleColor = UIColor.systemBackground
        dataSet.valueFont = .systemFont(ofSize: 10, weight: .medium)
        dataSet.valueTextColor = colors.primaryTextColor
        
        // Enhanced gradient fill with better visual appeal
        let gradientColors = [
            colors.secondaryAccentColor.withAlphaComponent(0.5).cgColor,
            colors.secondaryAccentColor.withAlphaComponent(0.25).cgColor,
            colors.secondaryAccentColor.withAlphaComponent(0.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: [0.0, 0.5, 1.0])!
        
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.5
        
        // Enhanced line style for better visibility
        dataSet.lineDashLengths = nil // Solid line for better readability
        dataSet.highlightEnabled = true
        dataSet.highlightColor = colors.secondaryAccentColor
        dataSet.highlightLineWidth = 2
        dataSet.drawHorizontalHighlightIndicatorEnabled = false
        dataSet.drawVerticalHighlightIndicatorEnabled = true

        return dataSet
    }

    // MARK: - Radar Chart Data Generation

    /// Generate radar chart data for top custom projects
    /// Shows weekly scores across up to 5 custom projects
    func generateRadarChartData(
        for referenceDate: Date? = nil,
        selectedProjectIDs: [UUID]? = nil
    ) -> (entries: [RadarChartDataEntry], labels: [String]) {
        let currentReferenceDate = referenceDate ?? Date.today()

        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 1 // Start on Sunday

        let week = calendar.daysWithSameWeekOfYear(as: currentReferenceDate)
        let startOfWeek = week.first ?? currentReferenceDate.startOfDay
        let endOfWeek = week.last?.endOfDay ?? currentReferenceDate.endOfDay

        print("🎯 [RADAR] ========================================")
        print("🎯 [RADAR] Generating radar chart data for week of \(currentReferenceDate)")
        print("🎯 [RADAR] Week range: \(startOfWeek) to \(endOfWeek)")

        // Get projects to display with their scores
        var projectsWithScores: [(Projects, Int)] = []

        if let selectedIDs = selectedProjectIDs, !selectedIDs.isEmpty {
            // Use user-selected/pinned projects
            print("🎯 [RADAR] Using \(selectedIDs.count) pinned projects: \(selectedIDs)")

            // Fetch projects by UUID (handles migrated projects)
            // Use compound OR predicates for UUID array matching (proven pattern from CoreDataProjectRepository)
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()

            if selectedIDs.count == 1 {
                // Single UUID - use simple equality (fastest)
                request.predicate = NSPredicate(format: "projectID == %@", selectedIDs[0] as CVarArg)
                print("🎯 [RADAR] Using single UUID predicate for: \(selectedIDs[0])")
            } else {
                // Multiple UUIDs - use compound OR predicates
                let predicates = selectedIDs.map { uuid in
                    NSPredicate(format: "projectID == %@", uuid as CVarArg)
                }
                request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
                print("🎯 [RADAR] Using compound OR predicate for \(selectedIDs.count) UUIDs")
                print("🎯 [RADAR] UUIDs: \(selectedIDs.map { $0.uuidString }.joined(separator: ", "))")
            }

            var selectedProjects = (try? context.fetch(request)) ?? []
            print("🎯 [RADAR] Predicate format: \(request.predicate?.predicateFormat ?? "none")")
            print("🎯 [RADAR] Fetched \(selectedProjects.count) projects from \(selectedIDs.count) UUIDs")

            // 🔥 NEW: Handle case where all pinned UUIDs are stale
            if selectedProjects.isEmpty {
                print("🚨 [RADAR] All pinned UUIDs are stale! Falling back to auto-selection...")
                projectsWithScores = getTopProjectsByWeeklyScore(limit: 5, startOfWeek: startOfWeek, endOfWeek: endOfWeek)
                print("🎯 [RADAR] Auto-selected \(projectsWithScores.count) projects as fallback")
            } else {
                // Detailed fetch results with database inspection
                print("🔍 [COMPOUND PRED] ==================")

                // CRITICAL: Inspect what's ACTUALLY in the database
                print("🔍 [DB INSPECTION] Checking ALL projects in database:")
                let allProjectsRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
                let allProjectsInDB = (try? context.fetch(allProjectsRequest)) ?? []
                print("🔍 [DB INSPECTION] Total projects in database: \(allProjectsInDB.count)")

                for (index, proj) in allProjectsInDB.enumerated() {
                    let uuid = proj.projectID?.uuidString ?? "NIL"
                    let name = proj.projectName ?? "NIL"
                    let isInbox = proj.projectID == ProjectConstants.inboxProjectID
                    print("   DB Project #\(index + 1): '\(name)' | UUID: \(uuid) | isInbox: \(isInbox)")
                }

                print("🔍 [COMPOUND PRED] Fetch results:")
                print("   Expected: \(selectedIDs.count) projects")
                print("   Fetched: \(selectedProjects.count) projects")

                if selectedProjects.count < selectedIDs.count {
                    print("   ⚠️ MISMATCH! Missing \(selectedIDs.count - selectedProjects.count) projects")
                    print("   Requested UUIDs:")
                    for uuid in selectedIDs {
                        print("      - \(uuid.uuidString)")
                    }
                    print("   Fetched UUIDs:")
                    for project in selectedProjects {
                        print("      - \(project.projectID?.uuidString ?? "NIL")")
                    }

                    let fetchedUUIDs = Set(selectedProjects.compactMap { $0.projectID })
                    let requestedUUIDs = Set(selectedIDs)
                    let missing = requestedUUIDs.subtracting(fetchedUUIDs)
                    print("   ❌ Missing UUIDs (pinned but not found in DB):")
                    for uuid in missing {
                        print("      \(uuid.uuidString)")
                        // Check if this UUID exists in DB at all
                        let exists = allProjectsInDB.contains { $0.projectID == uuid }
                        print("         Exists in DB: \(exists)")
                    }

                    print("")
                    print("   💡 DIAGNOSIS: Pinned UUIDs are STALE (don't match current projects)")
                    print("   💡 SOLUTION: ProjectSelectionService will auto-clean stale pins on next load")

                    // 🔥 NEW: Provide better fallback handling
                    if selectedProjects.isEmpty {
                        print("   🔄 FALLBACK: No valid projects found, will auto-select top projects")
                    } else {
                        print("   🔄 PARTIAL: Using \(selectedProjects.count) valid projects, ignoring \(missing.count) stale UUIDs")
                    }
                } else if selectedProjects.count == selectedIDs.count {
                    print("   ✅ All requested projects found!")
                } else if selectedProjects.count == 0 && selectedIDs.count == 0 {
                    print("   ⚠️ No projects requested (empty selectedIDs)")
                }

                for project in selectedProjects {
                    print("   ✅ Fetched: '\(project.projectName ?? "nil")' | UUID: \(project.projectID?.uuidString ?? "nil")")
                }
                print("🔍 [COMPOUND PRED] ==================")

                // Fallback: If UUID lookup didn't find all projects, some might be legacy (no projectID)
                // This shouldn't normally happen after migration, but provides safety
                if selectedProjects.count < selectedIDs.count {
                    print("⚠️ [RADAR] UUID lookup incomplete - some projects may be legacy data")
                }

                // Calculate scores for selected projects
                for project in selectedProjects {
                    guard let projectName = project.projectName else { continue }
                    let score = calculateWeeklyScoreForProjectByName(
                        projectName: projectName,
                        startOfWeek: startOfWeek,
                        endOfWeek: endOfWeek
                    )
                    projectsWithScores.append((project, score))
                }
            }
        } else {
            // Auto-select top 5 projects by weekly score
            print("🎯 [RADAR] Auto-selecting top 5 projects by weekly score...")
            projectsWithScores = getTopProjectsByWeeklyScore(limit: 5, startOfWeek: startOfWeek, endOfWeek: endOfWeek)
            print("🎯 [RADAR] Auto-selected \(projectsWithScores.count) projects")
        }

        // Filter out Inbox project by name
        let beforeFilterCount = projectsWithScores.count
        projectsWithScores = projectsWithScores.filter {
            $0.0.projectName != "Inbox"
        }
        print("🎯 [RADAR] Filtered out Inbox. Before: \(beforeFilterCount), After: \(projectsWithScores.count)")

        print("🎯 [RADAR] Final: Displaying \(projectsWithScores.count) custom projects on radar chart")

        // Generate radar chart entries
        var entries: [RadarChartDataEntry] = []
        var labels: [String] = []

        print("🎯 [RADAR] Generating chart entries for \(projectsWithScores.count) projects...")

        for (index, (project, score)) in projectsWithScores.enumerated() {
            guard let projectName = project.projectName else {
                print("   ⚠️ [RADAR] Skipping project #\(index) with nil name")
                continue
            }

            print("   📈 [RADAR] Project #\(index+1): '\(projectName)' - \(score) points")

            // Create radar chart entry using pre-calculated score
            let entry = RadarChartDataEntry(value: Double(score))
            entries.append(entry)
            labels.append(projectName)
        }

        print("🎯 [RADAR] ========================================")
        print("🎯 [RADAR] FINAL RESULT: \(entries.count) data points created")
        print("🎯 [RADAR] Projects: \(labels.joined(separator: ", "))")
        print("🎯 [RADAR] Scores: \(entries.map { Int($0.value) })")
        print("🎯 [RADAR] ========================================")

        return (entries, labels)
    }

    /// Calculate weekly score for a specific project by name (fallback for nil projectIDs)
    private func calculateWeeklyScoreForProjectByName(
        projectName: String,
        startOfWeek: Date,
        endOfWeek: Date
    ) -> Int {
        print("   📊 [WEEKLY SCORE] ==================")
        print("   📊 [WEEKLY SCORE] Calculating for '\(projectName)'")
        print("      Week range: \(startOfWeek) to \(endOfWeek)")

        // Fetch all tasks completed in this week for this project
        // NOTE: Using project string field since projectID is often nil
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(
            format: "project == %@ AND isComplete == YES AND dateCompleted >= %@ AND dateCompleted <= %@",
            projectName,
            startOfWeek as NSDate,
            endOfWeek as NSDate
        )

        print("      🔍 Predicate: project == '\(projectName)' AND isComplete == YES")

        guard let tasks = try? context.fetch(request) else {
            print("      ⚠️ Failed to fetch tasks (query error)")
            print("   📊 [WEEKLY SCORE] ==================")
            return 0
        }

        print("      📝 Tasks found: \(tasks.count)")

        if tasks.isEmpty {
            print("      ⚠️ No completed tasks found for this project in this week!")
        } else {
            print("      Task list:")
            for task in tasks {
                let completedStr = task.dateCompleted != nil ? "\(task.dateCompleted! as Date)" : "nil"
                print("         • '\(task.name ?? "Unknown")' completed: \(completedStr)")
            }
        }

        // Sum scores of all completed tasks
        var totalScore = 0
        for task in tasks {
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            totalScore += taskScore
            print("         → Score: \(taskScore) points (Priority: \(task.taskPriority))")
        }

        print("      💯 Total score: \(totalScore)")
        print("   📊 [WEEKLY SCORE] ==================")
        return totalScore
    }

    /// Calculate weekly score for a specific project (legacy UUID-based method)
    private func calculateWeeklyScoreForProject(
        projectID: UUID,
        startOfWeek: Date,
        endOfWeek: Date
    ) -> Int {
        // Fetch all tasks completed in this week for this project
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(
            format: "projectID == %@ AND isComplete == YES AND dateCompleted >= %@ AND dateCompleted <= %@",
            projectID as CVarArg,
            startOfWeek as NSDate,
            endOfWeek as NSDate
        )

        print("      🔍 [RADAR] Fetching tasks for project \(projectID)")
        print("         Predicate: projectID == \(projectID) AND isComplete == YES AND dateCompleted between \(startOfWeek) and \(endOfWeek)")

        guard let tasks = try? context.fetch(request) else {
            print("      ⚠️ [RADAR] Failed to fetch tasks")
            return 0
        }

        print("      📝 [RADAR] Found \(tasks.count) completed tasks")

        // Sum scores of all completed tasks
        var totalScore = 0
        for task in tasks {
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            totalScore += taskScore
            print("         - '\(task.name ?? "Unknown")': \(taskScore) points (Priority: \(task.taskPriority))")
        }

        print("      💯 [RADAR] Total score: \(totalScore)")
        return totalScore
    }

    /// Get top N projects by weekly score
    private func getTopProjectsByWeeklyScore(
        limit: Int,
        startOfWeek: Date,
        endOfWeek: Date
    ) -> [(Projects, Int)] {
        print("   🔎 [RADAR] Fetching all custom projects (excluding Inbox)...")
        print("   🔎 [RADAR] Inbox UUID to exclude: \(ProjectConstants.inboxProjectID)")

        // First, let's fetch ALL projects to see what we have
        let allRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
        print("   🔍 [RADAR] DEBUG: About to fetch ALL projects...")

        do {
            let allProjectsDebug = try context.fetch(allRequest)
            print("   📊 [RADAR] DEBUG: Total projects in database: \(allProjectsDebug.count)")
            print("   🔍 [RADAR] DEBUG: Starting project enumeration...")

            for (index, project) in allProjectsDebug.enumerated() {
                let hasID = project.projectID != nil
                let projectID = project.projectID?.uuidString ?? "nil"
                let projectName = project.projectName ?? "nil"
                let isInbox = project.projectID == ProjectConstants.inboxProjectID
                print("      #\(index+1): '\(projectName)' | hasID: \(hasID) | ID: \(projectID) | isInbox: \(isInbox)")

                // Also check if the project has value for projectID attribute
                if let id = project.projectID {
                    print("         UUID value exists: \(id), comparing to inbox: \(ProjectConstants.inboxProjectID), equal: \(id == ProjectConstants.inboxProjectID)")
                } else {
                    print("         ⚠️ projectID is NIL!")
                }
            }

            print("   ✅ [RADAR] DEBUG: Project enumeration complete")
        } catch {
            print("   ❌ [RADAR] DEBUG: Failed to fetch all projects: \(error)")
        }

        // Fetch all custom projects
        // NOTE: Many projects have nil projectID, so we filter by name instead
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        request.predicate = NSPredicate(
            format: "projectName != %@ AND projectName != nil",
            "Inbox"
        )

        print("   🔍 [RADAR] Executing predicate: projectName != 'Inbox' AND projectName != nil")

        guard let allProjects = try? context.fetch(request) else {
            print("   ⚠️ [RADAR] Failed to fetch custom projects - fetch() returned nil")
            return []
        }

        print("   📂 [RADAR] Found \(allProjects.count) custom projects (after excluding Inbox by name)")

        // Calculate score for each project
        var projectScores: [(Projects, Int)] = []

        for project in allProjects {
            guard let projectName = project.projectName else {
                print("   ⚠️ [RADAR] Skipping project with nil name")
                continue
            }

            print("   📊 [RADAR] Calculating score for '\(projectName)'...")

            // Use project name instead of UUID since many projects have nil projectID
            let score = calculateWeeklyScoreForProjectByName(
                projectName: projectName,
                startOfWeek: startOfWeek,
                endOfWeek: endOfWeek
            )

            projectScores.append((project, score))
        }

        print("   🎯 [RADAR] Calculated scores for \(projectScores.count) projects")

        // Sort by score descending and take top N
        let sortedProjects = projectScores.sorted { $0.1 > $1.1 }
        let topProjects = Array(sortedProjects.prefix(limit))

        print("   🏆 [RADAR] Top \(limit) projects by score:")
        for (project, score) in topProjects {
            print("      - \(project.projectName ?? "Unknown"): \(score) points")
        }

        return topProjects
    }

    /// Create configured radar chart dataset
    func createRadarChartDataSet(with entries: [RadarChartDataEntry], colors: ToDoColors) -> RadarChartDataSet {
        let dataSet = RadarChartDataSet(entries: entries, label: "Project Scores")

        // Visual configuration matching app theme
        dataSet.setColor(colors.primaryColor)
        dataSet.fillColor = colors.secondaryAccentColor
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.3
        dataSet.lineWidth = 4.0
        dataSet.drawHighlightCircleEnabled = true
        dataSet.setDrawHighlightIndicators(false)

        // Value labels
        dataSet.valueFont = .systemFont(ofSize: 16, weight: .semibold)
        dataSet.valueTextColor = colors.primaryTextColor
        dataSet.drawValuesEnabled = true

        return dataSet
    }

    /// Calculate dynamic maximum for radar chart scaling
    func calculateRadarChartMaximum(for entries: [RadarChartDataEntry]) -> Double {
        let maxValue = entries.map { $0.value }.max() ?? 0
        // Round up to nearest 5 for cleaner scaling that fits actual data
        let roundedMax = ceil(maxValue / 5) * 5
        return max(roundedMax, 5) // Minimum scale of 5
    }
}