//
//  HomeViewController+TaskSelection.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import SwiftUI
import CoreData

extension HomeViewController {
    
    // MARK: - Task Selection

    func handleRevampedTaskTap(_ task: DomainTask) {
        print("HOME_TAP start id=\(task.id.uuidString) name=\(task.name)")
        guard let managedTask = resolveManagedTask(for: task) else {
            print("HOME_TAP resolve_failed id=\(task.id.uuidString) name=\(task.name)")
            return
        }
        print("HOME_TAP resolved taskID=\(managedTask.taskID?.uuidString ?? "nil") objectID=\(managedTask.objectID)")
        presentTaskDetailView(for: managedTask)
    }

    func handleRevampedTaskToggleComplete(_ task: DomainTask) {
        TaskerHaptic.selection()

        if let viewModel = viewModel {
            viewModel.toggleTaskCompletion(task)
        } else if let managedTask = resolveManagedTask(for: task) {
            managedTask.isComplete.toggle()
            managedTask.dateCompleted = managedTask.isComplete ? Date() as NSDate : nil
            try? managedTask.managedObjectContext?.save()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.updateViewForHome(viewType: self.currentViewType, dateForView: self.dateForTheView)
            self.refreshChartsAfterTaskCompletion()
            self.updateDailyScore()
            self.updateChartCardsScrollView()
        }
    }

    func handleRevampedTaskDelete(_ task: DomainTask) {
        print("HOME_SWIPE action=delete id=\(task.id.uuidString) name=\(task.name)")
        TaskerHaptic.selection()

        if let viewModel = viewModel {
            viewModel.deleteTask(task)
        } else if let managedTask = resolveManagedTask(for: task) {
            managedTask.managedObjectContext?.delete(managedTask)
            try? managedTask.managedObjectContext?.save()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.updateViewForHome(viewType: self.currentViewType, dateForView: self.dateForTheView)
            self.refreshChartsAfterTaskCompletion()
            self.updateDailyScore()
            self.updateChartCardsScrollView()
        }
    }

    func handleRevampedTaskReschedule(_ task: DomainTask) {
        print("HOME_SWIPE action=reschedule_prompt id=\(task.id.uuidString) name=\(task.name)")
        guard let managedTask = resolveManagedTask(for: task) else {
            print("HOME_SWIPE action=reschedule_resolve_failed id=\(task.id.uuidString)")
            return
        }

        let rescheduleVC = RescheduleViewController(task: managedTask) { [weak self] selectedDate in
            guard let self else { return }
            print("HOME_SWIPE action=reschedule_apply id=\(task.id.uuidString) date=\(selectedDate)")

            if let viewModel = self.viewModel {
                viewModel.rescheduleTask(task, to: selectedDate)
            } else {
                managedTask.dueDate = selectedDate as NSDate
                try? managedTask.managedObjectContext?.save()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateViewForHome(viewType: self.currentViewType, dateForView: self.dateForTheView)
                self.refreshChartsAfterTaskCompletion()
                self.updateDailyScore()
                self.updateChartCardsScrollView()
            }
        }

        let navController = UINavigationController(rootViewController: rescheduleVC)
        present(navController, animated: true)
    }

    private func resolveManagedTask(for task: DomainTask) -> NTask? {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return nil
        }

        // Stage 1: canonical UUID bridge.
        let idRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
        idRequest.fetchLimit = 1
        idRequest.predicate = NSPredicate(format: "taskID == %@", task.id as CVarArg)
        do {
            if let taskByID = try context.fetch(idRequest).first {
                print("HOME_TAP resolve_stage=taskID candidates=1")
                print("HOME_TAP resolve_success branch=taskID objectID=\(taskByID.objectID)")
                return taskByID
            }
        } catch {
            print("HOME_TAP resolve_taskID_error error=\(error)")
        }

        // Stage 2: exact name + projectID bridge.
        let nameProjectRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
        nameProjectRequest.fetchLimit = 20
        nameProjectRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "name == %@", task.name),
            NSPredicate(format: "projectID == %@", task.projectID as CVarArg)
        ])
        nameProjectRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
        if let candidates = try? context.fetch(nameProjectRequest) {
            print("HOME_TAP resolve_stage=name_project_id candidates=\(candidates.count)")
            if let best = bestCandidate(for: task, in: candidates) {
                print("HOME_TAP resolve_success branch=name_project_id objectID=\(best.objectID)")
                return best
            }
        }

        // Stage 3: tolerant metadata bridge (project optional to support legacy rows).
        let metadataRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
        metadataRequest.fetchLimit = 30
        var metadataPredicates: [NSPredicate] = [
            NSPredicate(format: "name == %@", task.name),
            NSPredicate(format: "taskType == %d", task.type.rawValue),
            NSPredicate(format: "taskPriority == %d", task.priority.rawValue)
        ]
        if let dueDate = task.dueDate {
            let lowerBound = dueDate.addingTimeInterval(-180)
            let upperBound = dueDate.addingTimeInterval(180)
            metadataPredicates.append(
                NSPredicate(format: "dueDate >= %@ AND dueDate <= %@", lowerBound as NSDate, upperBound as NSDate)
            )
        } else {
            metadataPredicates.append(NSPredicate(format: "dueDate == nil"))
        }
        metadataRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: metadataPredicates)
        metadataRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

        if let candidates = try? context.fetch(metadataRequest) {
            print("HOME_TAP resolve_stage=metadata candidates=\(candidates.count)")
            if let best = bestCandidate(for: task, in: candidates) {
                print("HOME_TAP resolve_success branch=metadata objectID=\(best.objectID)")
                return best
            }
        }

        // Stage 4: final name fallback.
        let fallbackRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
        fallbackRequest.fetchLimit = 20
        fallbackRequest.predicate = NSPredicate(format: "name == %@", task.name)
        fallbackRequest.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

        if let candidates = try? context.fetch(fallbackRequest) {
            print("HOME_TAP resolve_stage=name_fallback candidates=\(candidates.count)")
            if let best = bestCandidate(for: task, in: candidates) {
                print("HOME_TAP resolve_success branch=name_fallback objectID=\(best.objectID)")
                return best
            }
        }

        print("HOME_TAP resolve_failed id=\(task.id.uuidString) name=\(task.name)")
        return nil
    }

    private func bestCandidate(for task: DomainTask, in candidates: [NTask]) -> NTask? {
        guard !candidates.isEmpty else { return nil }

        var scored: [(NTask, Int)] = candidates.map { candidate in
            var score = 0
            if candidate.name == task.name { score += 4 }
            if candidate.isComplete == task.isComplete { score += 2 }
            if candidate.projectID == task.projectID { score += 4 }
            if candidate.taskType == task.type.rawValue { score += 2 }
            if candidate.taskPriority == task.priority.rawValue { score += 2 }

            if let taskProject = task.project?.lowercased(),
               let candidateProject = candidate.project?.lowercased(),
               !taskProject.isEmpty,
               taskProject == candidateProject {
                score += 3
            }

            switch (candidate.dueDate as Date?, task.dueDate) {
            case let (lhs?, rhs?):
                if abs(lhs.timeIntervalSince(rhs)) <= 180 {
                    score += 2
                }
            case (nil, nil):
                score += 1
            default:
                break
            }

            return (candidate, score)
        }

        scored.sort { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
            let lhsDate = lhs.0.dateAdded as Date? ?? Date.distantPast
            let rhsDate = rhs.0.dateAdded as Date? ?? Date.distantPast
            return lhsDate > rhsDate
        }

        return scored.first?.0
    }
    
//    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
//        tableView.deselectRow(at: indexPath, animated: true)
//        
//        print("\n🔍 TASK SELECTION:")
//        print("  📍 IndexPath: Section \(indexPath.section), Row \(indexPath.row)")
//        print("  📱 Current View Type: \(currentViewType)")
//        
//        // Get the selected task
//        var selectedTask: NTask?
//        
//        switch currentViewType {
//        case .allProjectsGrouped, .selectedProjectsGrouped:
//            if indexPath.section > 0 {
//                let actualSection = indexPath.section - 1
//                if actualSection < projectsToDisplayAsSections.count {
//                    let projectName = projectsToDisplayAsSections[actualSection].projectName ?? ""
//                    if let tasks = tasksGroupedByProject[projectName], indexPath.row < tasks.count {
//                        selectedTask = tasks[indexPath.row]
//                        print("  📁 Selected from project: \(projectName)")
//                    }
//                }
//            }
//        default:
//            // Convert TaskListItem to NTask or find corresponding NTask
//            let allTaskItems = ToDoListSections.flatMap({ $0.items })
//            if indexPath.row < allTaskItems.count {
//                // Get the TaskListItem
//                let taskItem = allTaskItems[indexPath.row]
//                print("  📝 TaskItem title: '\(taskItem.TaskTitle)'")
//                // Find the corresponding NTask by title
//                selectedTask = TaskManager.sharedInstance.getAllTasks.first(where: { $0.name == taskItem.TaskTitle })
//            }
//        }
//        
//        guard let task = selectedTask else {
//            print("  ❌ No task found for selection")
//            return
//        }
//        
//        // Print detailed task information
//        print("\n📋 SELECTED TASK DETAILS:")
//        print("  📌 Name: '\(task.name ?? "Unknown")'")
//        print("  📁 Project: '\(task.project ?? "No Project")'")
//        print("  📝 Details: '\(task.taskDetails ?? "No details")'")
//        print("  ⏰ Due Date: \(task.dueDate?.description ?? "No due date")")
//        print("  📅 Date Added: \(task.dateAdded?.description ?? "Unknown")")
//        print("  🎯 Priority: P\(task.taskPriority - 1) (\(task.taskPriority))")
//        print("  🏷️ Type: \(task.taskType)")
//        print("  ✅ Completed: \(task.isComplete ? "Yes" : "No")")
//        if task.isComplete {
//            print("  🎉 Completed Date: \(task.dateCompleted?.description ?? "Unknown")")
//        }
//        print("  🌙 Evening Task: \(task.isEveningTask ? "Yes" : "No")")
//        if let reminderTime = task.alertReminderTime {
//            print("  ⏰ Reminder: \(reminderTime.description)")
//        }
//        print("")
//        
//        // Present task detail view
//        presentTaskDetailView(for: task)
//    }
    
    // MARK: - Present Task Detail
    
    func presentTaskDetailView(for task: NTask) {
        print("HOME_TAP_DETAIL mode=sheet action=present_start taskID=\(task.taskID?.uuidString ?? "nil") name=\(task.name ?? "Unknown")")
        let detailView = TaskDetailSheetView(
            task: task,
            projectNames: buildProjectChipData(),
            onSave: { [weak self] in
                self?.refreshHomeAfterTaskDetailMutation(reason: "save")
            },
            onToggleComplete: { [weak self] in
                self?.refreshHomeAfterTaskDetailMutation(reason: "toggle")
            },
            onDismiss: nil,
            onDelete: { [weak self] in
                guard let self else { return }
                task.managedObjectContext?.delete(task)
                do {
                    try task.managedObjectContext?.save()
                    print("HOME_TAP_DETAIL mode=sheet action=delete taskID=\(task.taskID?.uuidString ?? "nil")")
                } catch {
                    print("HOME_TAP_DETAIL mode=sheet action=delete_error taskID=\(task.taskID?.uuidString ?? "nil") error=\(error)")
                }

                self.presentedViewController?.dismiss(animated: true) { [weak self] in
                    self?.refreshHomeAfterTaskDetailMutation(reason: "delete")
                }
            }
        )

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        present(hostingController, animated: true)
        print("HOME_TAP_DETAIL mode=sheet action=presented taskID=\(task.taskID?.uuidString ?? "nil")")
    }

    private func refreshHomeAfterTaskDetailMutation(reason: String) {
        viewModel?.invalidateTaskCaches()
        updateViewForHome(viewType: currentViewType, dateForView: dateForTheView)
        refreshChartsAfterTaskCompletion()
        updateDailyScore()
        updateChartCardsScrollView()
        print("HOME_TAP_DETAIL mode=sheet action=refresh reason=\(reason) mode=\(currentViewType)")
    }

    private func buildProjectChipData() -> [String] {
        var projectNames: [String] = []
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "projectName", ascending: true)]
            if let projects = try? context.fetch(request) {
                projectNames = projects.compactMap { $0.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }

        let inboxTitle = ProjectConstants.inboxProjectName
        projectNames.removeAll { $0.caseInsensitiveCompare(inboxTitle) == .orderedSame }
        projectNames.insert(inboxTitle, at: 0)

        var deduped: [String] = []
        var seen = Set<String>()
        for name in projectNames {
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            deduped.append(name)
        }
        return deduped
    }
}
