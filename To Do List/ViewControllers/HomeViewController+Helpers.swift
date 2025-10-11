//
//  HomeViewController+Helpers.swift
//  Tasker
//
//  Helper methods for HomeViewController migration
//

import UIKit
import CoreData

extension HomeViewController {
    
    // MARK: - Task Fetching Helpers
    
    /// Get task from TaskListItem without using TaskManager singleton
    func getTaskFromTaskListItem(_ item: TaskListItem) -> NTask? {
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        // Try to match by name and due date for uniqueness
        if let dueDate = item.TaskDueDate {
            request.predicate = NSPredicate(
                format: "name == %@ AND dueDate == %@", 
                item.TaskTitle, 
                dueDate as NSDate
            )
        } else {
            request.predicate = NSPredicate(format: "name == %@", item.TaskTitle)
        }
        
        return try? context?.fetch(request).first
    }
    
    /// Save context without using TaskManager singleton
    func saveContext() {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return
        }
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    /// Delete task without using TaskManager singleton
    func deleteTaskDirectly(_ task: NTask) {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return
        }
        
        context.delete(task)
        saveContext()
    }
    
    /// Reschedule task without using TaskManager singleton
    func rescheduleTaskDirectly(_ task: NTask, to date: Date) {
        task.dueDate = date as NSDate
        saveContext()
    }
}
