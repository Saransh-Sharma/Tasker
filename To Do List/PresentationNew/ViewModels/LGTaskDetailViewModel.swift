// LGTaskDetailViewModel.swift
// MVVM ViewModel for Task Detail Screen - Phase 4 Implementation
// Reactive task management with Core Data integration

import Foundation
import UIKit
import CoreData
import RxSwift
import RxCocoa

class LGTaskDetailViewModel {
    
    // MARK: - Dependencies
    private let context: NSManagedObjectContext
    private let disposeBag = DisposeBag()
    
    // MARK: - Properties
    private let task: NTask
    
    // MARK: - Output Properties
    let taskData = BehaviorRelay<TaskCardData>(value: TaskCardData(id: "", title: "", description: "", dueDate: nil, priority: .medium, project: nil, progress: 0, isCompleted: false))
    let isLoading = BehaviorRelay<Bool>(value: false)
    let error = PublishRelay<Error>()
    let taskUpdated = PublishRelay<NTask>()
    let taskDeleted = PublishRelay<Void>()
    
    // MARK: - Initialization
    
    init(task: NTask, context: NSManagedObjectContext) {
        self.task = task
        self.context = context
        
        refreshTask()
    }
    
    // MARK: - Public Methods
    
    func refreshTask() {
        let data = TaskCardData(
            id: task.objectID.uriRepresentation().absoluteString,
            title: task.taskName ?? "Untitled Task",
            description: task.taskDescription ?? "",
            dueDate: task.dueDate,
            priority: TaskPriority(rawValue: Int(task.taskPriority)) ?? .medium,
            project: task.taskProject?.projectData,
            progress: task.isComplete ? 1.0 : 0.0,
            isCompleted: task.isComplete
        )
        
        taskData.accept(data)
    }
    
    func toggleTaskCompletion() {
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Toggle completion status
                self.task.isComplete.toggle()
                
                // Set completion date
                if self.task.isComplete {
                    self.task.dateCompleted = Date()
                } else {
                    self.task.dateCompleted = nil
                }
                
                // Save context
                try self.context.save()
                
                DispatchQueue.main.async {
                    self.isLoading.accept(false)
                    self.refreshTask()
                    self.taskUpdated.accept(self.task)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    func deleteTask() {
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                self.context.delete(self.task)
                try self.context.save()
                
                DispatchQueue.main.async {
                    self.isLoading.accept(false)
                    self.taskDeleted.accept(())
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    func duplicateTask() {
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Create new task with same properties
                let duplicatedTask = NTask(context: self.context)
                duplicatedTask.taskName = (self.task.taskName ?? "") + " (Copy)"
                duplicatedTask.taskDescription = self.task.taskDescription
                duplicatedTask.taskPriority = self.task.taskPriority
                duplicatedTask.taskProject = self.task.taskProject
                duplicatedTask.dueDate = self.task.dueDate
                duplicatedTask.reminderDate = self.task.reminderDate
                duplicatedTask.dateCreated = Date()
                duplicatedTask.isComplete = false
                
                try self.context.save()
                
                DispatchQueue.main.async {
                    self.isLoading.accept(false)
                    self.taskUpdated.accept(duplicatedTask)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    var taskTitle: String {
        return task.taskName ?? "Untitled Task"
    }
    
    var taskDescription: String {
        return task.taskDescription ?? "No description"
    }
    
    var formattedDueDate: String {
        guard let dueDate = task.dueDate else { return "No due date" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
    
    var formattedCreationDate: String {
        guard let creationDate = task.dateCreated else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
    
    var formattedCompletionDate: String? {
        guard let completionDate = task.dateCompleted else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: completionDate)
    }
    
    var priorityDisplayName: String {
        let priority = TaskPriority(rawValue: Int(task.taskPriority)) ?? .medium
        return priority.displayName
    }
    
    var priorityColor: UIColor {
        let priority = TaskPriority(rawValue: Int(task.taskPriority)) ?? .medium
        return priority.color
    }
    
    var projectDisplayName: String {
        return task.taskProject?.projectName ?? "No Project"
    }
    
    var isOverdue: Bool {
        guard let dueDate = task.dueDate, !task.isComplete else { return false }
        return dueDate < Date()
    }
    
    var timeUntilDue: String {
        guard let dueDate = task.dueDate else { return "" }
        
        let now = Date()
        let timeInterval = dueDate.timeIntervalSince(now)
        
        if timeInterval < 0 {
            return "Overdue"
        }
        
        let days = Int(timeInterval / 86400)
        let hours = Int((timeInterval.truncatingRemainder(dividingBy: 86400)) / 3600)
        
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s") remaining"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s") remaining"
        } else {
            return "Due soon"
        }
    }
    
    var hasReminder: Bool {
        return task.reminderDate != nil
    }
    
    var formattedReminderDate: String? {
        guard let reminderDate = task.reminderDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: reminderDate)
    }
}
