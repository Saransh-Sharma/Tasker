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
        
        // Generate chart data points for the week (Sunday to Saturday)
        for (index, day) in week.enumerated() {
            let score: Int
            
            // Enhanced future date handling
            if day > today {
                // For future dates, show 0 but with special styling indication
                score = 0
            } else {
                // For past and current dates, calculate actual score
                score = calculateScoreForDate(date: day)
            }
            
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
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let allTasks: [NTask]
        do {
            allTasks = try context.fetch(request)
        } catch {
            logError(
                event: "line_chart_task_fetch_failed",
                message: "Failed to fetch tasks for score calculation",
                fields: ["error": error.localizedDescription]
            )
            return 0
        }
        
        // Filter only the tasks that were completed on the specific day
        let tasksCompletedOnDate = allTasks.filter { task in
            guard task.isComplete, let completedDate = task.dateCompleted as Date? else { return false }
            return completedDate >= startOfDay && completedDate < endOfDay
        }

        for task in tasksCompletedOnDate {
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            score += taskScore
        }

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
    
    func createLineChartDataSet(
        with entries: [ChartDataEntry],
        colors: TaskerColorTokens,
        typography: TaskerTypographyTokens
    ) -> LineChartDataSet {
        let dataSet = LineChartDataSet(entries: entries, label: "Daily Score")
        
        // Enhanced visual configuration
        dataSet.mode = .linear
        dataSet.drawCirclesEnabled = true
        dataSet.lineWidth = 3.5
        dataSet.circleRadius = 6
        dataSet.setCircleColor(colors.accentPrimary)
        dataSet.setColor(colors.chartPrimary)
        dataSet.drawCircleHoleEnabled = true
        dataSet.circleHoleRadius = 3
        dataSet.circleHoleColor = colors.surfacePrimary
        dataSet.valueFont = typography.font(for: .caption2)
        dataSet.valueTextColor = colors.textTertiary
        
        // Enhanced gradient fill with better visual appeal
        let gradientColors = [
            colors.chartPrimary.withAlphaComponent(0.35).cgColor,
            colors.chartPrimary.withAlphaComponent(0.18).cgColor,
            colors.chartPrimary.withAlphaComponent(0.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: nil, colors: gradientColors as CFArray, locations: [0.0, 0.5, 1.0])!
        
        dataSet.fill = LinearGradientFill(gradient: gradient, angle: 90)
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.5
        
        // Enhanced line style for better visibility
        dataSet.lineDashLengths = nil // Solid line for better readability
        dataSet.highlightEnabled = true
        dataSet.highlightColor = colors.accentPrimary
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


        // Get projects to display with their scores
        var projectsWithScores: [(Projects, Int)] = []

        if let selectedIDs = selectedProjectIDs, !selectedIDs.isEmpty {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()

            if selectedIDs.count == 1 {
                request.predicate = NSPredicate(format: "projectID == %@", selectedIDs[0] as CVarArg)
            } else {
                let predicates = selectedIDs.map { uuid in
                    NSPredicate(format: "projectID == %@", uuid as CVarArg)
                }
                request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
            }

            do {
                let selectedProjects = try context.fetch(request)
                if selectedProjects.isEmpty {
                    logWarning(
                        event: "radar_pinned_projects_missing",
                        message: "Pinned projects missing; using auto-selection",
                        fields: ["requested_count": String(selectedIDs.count)]
                    )
                    projectsWithScores = getTopProjectsByWeeklyScore(limit: 5, startOfWeek: startOfWeek, endOfWeek: endOfWeek)
                } else {
                    if selectedProjects.count < selectedIDs.count {
                        logWarning(
                            event: "radar_pinned_projects_partial",
                            message: "Pinned project set partially resolved",
                            fields: [
                                "requested_count": String(selectedIDs.count),
                                "resolved_count": String(selectedProjects.count)
                            ]
                        )
                    }

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
            } catch {
                logError(
                    event: "radar_pinned_projects_fetch_failed",
                    message: "Failed to fetch pinned projects",
                    fields: ["error": error.localizedDescription]
                )
                projectsWithScores = getTopProjectsByWeeklyScore(limit: 5, startOfWeek: startOfWeek, endOfWeek: endOfWeek)
            }
        } else {
            projectsWithScores = getTopProjectsByWeeklyScore(limit: 5, startOfWeek: startOfWeek, endOfWeek: endOfWeek)
        }

        // Filter out Inbox project by name
        projectsWithScores = projectsWithScores.filter {
            $0.0.projectName != "Inbox"
        }

        var entries: [RadarChartDataEntry] = []
        var labels: [String] = []

        for (project, score) in projectsWithScores {
            guard let projectName = project.projectName else { continue }
            let entry = RadarChartDataEntry(value: Double(score))
            entries.append(entry)
            labels.append(projectName)
        }


        return (entries, labels)
    }

    /// Calculate weekly score for a specific project by name (fallback for nil projectIDs)
    private func calculateWeeklyScoreForProjectByName(
        projectName: String,
        startOfWeek: Date,
        endOfWeek: Date
    ) -> Int {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(
            format: "project == %@ AND isComplete == YES AND dateCompleted >= %@ AND dateCompleted <= %@",
            projectName,
            startOfWeek as NSDate,
            endOfWeek as NSDate
        )

        let tasks: [NTask]
        do {
            tasks = try context.fetch(request)
        } catch {
            logError(
                event: "radar_weekly_score_fetch_failed",
                message: "Failed to fetch tasks for project weekly score",
                fields: ["error": error.localizedDescription]
            )
            return 0
        }

        var totalScore = 0
        for task in tasks {
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            totalScore += taskScore
        }

        return totalScore
    }

    /// Calculate weekly score for a specific project (legacy UUID-based method)
    private func calculateWeeklyScoreForProject(
        projectID: UUID,
        startOfWeek: Date,
        endOfWeek: Date
    ) -> Int {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(
            format: "projectID == %@ AND isComplete == YES AND dateCompleted >= %@ AND dateCompleted <= %@",
            projectID as CVarArg,
            startOfWeek as NSDate,
            endOfWeek as NSDate
        )

        let tasks: [NTask]
        do {
            tasks = try context.fetch(request)
        } catch {
            logError(
                event: "radar_weekly_score_fetch_failed",
                message: "Failed to fetch tasks for project weekly score",
                fields: ["error": error.localizedDescription]
            )
            return 0
        }

        var totalScore = 0
        for task in tasks {
            let taskScore = TaskScoringService.shared.calculateScore(for: task)
            totalScore += taskScore
        }

        return totalScore
    }

    /// Get top N projects by weekly score
    private func getTopProjectsByWeeklyScore(
        limit: Int,
        startOfWeek: Date,
        endOfWeek: Date
    ) -> [(Projects, Int)] {
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        request.predicate = NSPredicate(
            format: "projectName != %@ AND projectName != nil",
            "Inbox"
        )

        let allProjects: [Projects]
        do {
            allProjects = try context.fetch(request)
        } catch {
            logError(
                event: "radar_custom_projects_fetch_failed",
                message: "Failed to fetch custom projects for radar chart",
                fields: ["error": error.localizedDescription]
            )
            return []
        }

        var projectScores: [(Projects, Int)] = []

        for project in allProjects {
            guard let projectName = project.projectName else { continue }
            let score = calculateWeeklyScoreForProjectByName(
                projectName: projectName,
                startOfWeek: startOfWeek,
                endOfWeek: endOfWeek
            )

            projectScores.append((project, score))
        }

        let sortedProjects = projectScores.sorted { $0.1 > $1.1 }
        return Array(sortedProjects.prefix(limit))
    }

    /// Create configured radar chart dataset
    func createRadarChartDataSet(
        with entries: [RadarChartDataEntry],
        colors: TaskerColorTokens,
        typography: TaskerTypographyTokens
    ) -> RadarChartDataSet {
        let dataSet = RadarChartDataSet(entries: entries, label: "Project Scores")

        // Visual configuration matching app theme
        dataSet.setColor(colors.accentPrimary)
        dataSet.fillColor = colors.accentMuted
        dataSet.drawFilledEnabled = true
        dataSet.fillAlpha = 0.3
        dataSet.lineWidth = 4.0
        dataSet.drawHighlightCircleEnabled = true
        dataSet.setDrawHighlightIndicators(false)

        // Value labels
        dataSet.valueFont = typography.font(for: .caption1)
        dataSet.valueTextColor = colors.textSecondary
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
