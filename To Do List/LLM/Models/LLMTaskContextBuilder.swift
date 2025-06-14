//
//  LLMTaskContextBuilder.swift
//  To Do List
//
//  Created by Cascade AI on 14/06/2025.
//
//  Utility responsible for exporting the user's tasks for the current week
//  as a compact JSON string that can be injected into the LLM system prompt.
//  Keeping it separate avoids touching PromptMiddleware logic while keeping
//  ChatView lightweight.
//

import Foundation

import os

struct LLMTaskContextBuilder {
    private static var cachedWeekly: (generated: Date, json: String)?
    private static var cachedProjects: (generated: Date, json: String)?
    private static let cacheTTL: TimeInterval = 60 * 5 // 5 minutes

    /// Public helper that fetches weekly tasks JSON but uses in-memory cache to avoid recomputation within short interval.
    static func weeklyTasksJSONCached() -> String {
        if let cached = cachedWeekly, Date().timeIntervalSince(cached.generated) < cacheTTL {
            return cached.json
        }
        let start = Date()
        let json = weeklyTasksJSON()
        cachedWeekly = (Date(), json)
        os_log("WeeklyTasksJSON regenerated in %.2f ms, length=%d", (Date().timeIntervalSince(start) * 1000), json.count)
        return json
    }

    /// Public helper that fetches project details JSON with cache.
    static func projectDetailsJSONCached() -> String {
        if let cached = cachedProjects, Date().timeIntervalSince(cached.generated) < cacheTTL {
            return cached.json
        }
        let start = Date()
        let json = projectDetailsJSON()
        cachedProjects = (Date(), json)
        os_log("ProjectDetailsJSON regenerated in %.2f ms, length=%d", (Date().timeIntervalSince(start) * 1000), json.count)
        return json
    }
    /// Returns a nested JSON string describing all tasks whose dueDate or
    /// completion date is within the next 7 days (including today).
    /// The JSON is intentionally kept small to fit within the model context.
    static func weeklyTasksJSON() -> String {
        let cal = Calendar.current
        let today = Date()
        let startOfToday = cal.startOfDay(for: today)
        guard let endOfWeek = cal.date(byAdding: .day, value: 7, to: startOfToday) else {
            return "{}"
        }

        let tasks = TaskManager.sharedInstance.getAllTasks.filter { task in
            // Include tasks whose dueDate or completion falls within [today, today+7)
            if let due = task.dueDate as Date?, due >= startOfToday && due < endOfWeek {
                return true
            }
            if let completed = task.dateCompleted as Date?, completed >= startOfToday && completed < endOfWeek {
                return true
            }
            return false
        }

        // Helper to format dates as YYYY-MM-DD strings
        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone.current
            return df
        }()

        // Map NTask -> Dictionary
        let encodedTasks: [[String: Any]] = tasks.map { task in
            var dict: [String: Any] = [
                "id": task.objectID.uriRepresentation().absoluteString,
                "title": task.name ?? "",
                "project": task.project ?? "",
                "priority": task.taskPriority,
                "isCompleted": task.isComplete
            ]
            if let due = task.dueDate as Date? {
                dict["dueDate"] = dateFormatter.string(from: due)
            }
            if let completed = task.dateCompleted as Date? {
                dict["completionDate"] = dateFormatter.string(from: completed)
            }
            if let notes = task.taskDetails, !(notes.isEmpty ?? true) {
                dict["notes"] = notes
            }
            return dict
        }

        let payload: [String: Any] = [
            "context_type": "weekly_tasks",
            "current_date": dateFormatter.string(from: today),
            "week_start_date": dateFormatter.string(from: startOfToday),
            "tasks": encodedTasks
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Returns a JSON string containing all projects and their tasks.
    /// Groups tasks by `project` field (case-insensitive). Tasks with empty project
    /// are grouped under "inbox" (default project).
    static func projectDetailsJSON() -> String {
        let tasks = TaskManager.sharedInstance.getAllTasks
        // Group tasks by project name
        let groups = Dictionary(grouping: tasks) { (task: NTask) -> String in
            let proj = (task.project ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return proj.isEmpty ? "inbox" : proj
        }

        let dateFormatter: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            df.timeZone = TimeZone.current
            return df
        }()

        // Build projects array
        let projectsArray: [[String: Any]] = groups.keys.sorted().map { key in
            let projTasks = groups[key] ?? []
            let taskDicts: [[String: Any]] = projTasks.map { task in
                var dict: [String: Any] = [
                    "id": task.objectID.uriRepresentation().absoluteString,
                    "title": task.name ?? "",
                    "isCompleted": task.isComplete,
                    "priority": task.taskPriority
                ]
                if let due = task.dueDate as Date? {
                    dict["dueDate"] = dateFormatter.string(from: due)
                }
                if let completed = task.dateCompleted as Date? {
                    dict["completionDate"] = dateFormatter.string(from: completed)
                }
                if let notes = task.taskDetails, !(notes.isEmpty ?? true) {
                    dict["notes"] = notes
                }
                return dict
            }
            return [
                "projectName": key,
                "tasks": taskDicts
            ]
        }

        let payload: [String: Any] = [
            "context_type": "project_details",
            "projects": projectsArray
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
