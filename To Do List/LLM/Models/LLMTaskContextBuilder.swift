//
//  LLMTaskContextBuilder.swift
//  To Do List
//
//
//  Utility responsible for exporting the user's tasks for the current week
//  as a compact JSON string that can be injected into the LLM system prompt.
//  Keeping it separate avoids touching PromptMiddleware logic while keeping
//  ChatView lightweight.
//

import Foundation
import CoreData
import UIKit
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
    static func weeklyTasksTextCached() -> String {
        if let cached = cachedWeekly, Date().timeIntervalSince(cached.generated) < cacheTTL {
            // convert cached JSON to txt quickly? regenerate for now
        }
        return weeklyTasksText()
    }

    private static func weeklyTasksText() -> String {
        let jsonString = weeklyTasksJSON()
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let prettyDate: DateFormatter = {
            let f = DateFormatter()
            f.dateFormat = "EEEE, MMM d"
            return f
        }()
        let todayDate = Date()
        func relativeLabel(for dateStr: String) -> String {
            guard let date = df.date(from: dateStr) else { return dateStr }
            let cal = Calendar.current
            if cal.isDateInToday(date) { return "Today" }
            if cal.isDateInYesterday(date) { return "Yesterday" }
            if cal.isDateInTomorrow(date) { return "Tomorrow" }
            let weekday = DateFormatter().weekdaySymbols[cal.component(.weekday, from: date)-1]
            if date > todayDate {
                // future
                if let diff = cal.dateComponents([.day], from: todayDate, to: date).day, diff <= 7 {
                    return "next " + weekday
                }
            } else {
                if let diff = cal.dateComponents([.day], from: date, to: todayDate).day, diff <= 7 {
                    return "last " + weekday
                }
            }
            return weekday + ", " + DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none)
        }

        func priorityLabel(_ raw: Int) -> String {
            switch raw {
            case 3: return "high"
            case 2: return "medium"
            default: return "low"
            }
        }
        func renderTasks(_ arr: [[String: Any]]) -> String {
            arr.compactMap { t in
                let title = t["title"] as? String ?? ""
                let project = (t["project"] as? String ?? "").isEmpty ? "inbox" : (t["project"] as! String)
                let dueRaw = t["dueDate"] as? String ?? ""
                let due = dueRaw.isEmpty ? "" : relativeLabel(for: dueRaw)
                let prio = priorityLabel(t["priority"] as? Int ?? 0)
                return "- \(title) project: \(project) priority: \(prio) due \(due)"
            }.joined(separator: "\n")
        }
        var output = "Date: " + prettyDate.string(from: todayDate) + "\n\n"
        if let todayArr = obj["tasks_due_today"] as? [[String: Any]], !todayArr.isEmpty {
            output += "Tasks due today or overdue:\n" + renderTasks(todayArr) + "\n\n"
        }
        if let weekArr = obj["tasks_week"] as? [[String: Any]], !weekArr.isEmpty {
            output += "Other tasks this week:\n" + renderTasks(weekArr) + "\n\n"
        }
        // Build open projects section
        var projectCounts: [String: Int] = [:]
        if let all = obj["tasks_week"] as? [[String: Any]] {
            for t in all {
                guard (t["isCompleted"] as? Bool) == false else { continue }
                let proj = (t["project"] as? String ?? "").isEmpty ? "inbox" : (t["project"] as! String)
                projectCounts[proj, default: 0] += 1
            }
        }
        if let todayArr = obj["tasks_due_today"] as? [[String: Any]] {
            for t in todayArr {
                guard (t["isCompleted"] as? Bool) == false else { continue }
                let proj = (t["project"] as? String ?? "").isEmpty ? "inbox" : (t["project"] as! String)
                projectCounts[proj, default: 0] += 1
            }
        }
        let openProjects = projectCounts.filter { $0.value > 0 }
        if !openProjects.isEmpty {
            output += "Open projects with active tasks:\n"
            for (proj, count) in openProjects.sorted(by: { $0.key < $1.key }) {
                output += "- \(proj) (\(count) tasks)\n"
            }
        }
        return output
    }

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

        // Get tasks from Core Data directly
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let allTasks = (try? context?.fetch(request)) ?? []
        
        let tasks = allTasks.filter { task in
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

        // Build list of tasks due today including overdue ones
        let endOfToday = cal.date(byAdding: .day, value: 1, to: startOfToday)!
        let tasksDueToday: [NTask] = allTasks.filter { task in
            if task.isComplete { return false }
            guard let due = task.dueDate as Date? else { return false }
            // Due date passed or today
            return due < endOfToday
        }
        
        let encodedWeekly: [[String: Any]] = tasks.map { task in
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

        let encodedToday: [[String: Any]] = tasksDueToday.map { task in
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
            if let notes = task.taskDetails, !(notes.isEmpty ?? true) {
                dict["notes"] = notes
            }
            return dict
        }

        let payload: [String: Any] = [
            "context_type": "weekly_tasks",
            "current_date": dateFormatter.string(from: today),
            "week_start_date": dateFormatter.string(from: startOfToday),
            "tasks_due_today": encodedToday,
            "tasks_week": encodedWeekly
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
        // Get tasks from Core Data directly
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let tasks = (try? context?.fetch(request)) ?? []
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
