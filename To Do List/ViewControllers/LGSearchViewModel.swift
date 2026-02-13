//
//  LGSearchViewModel.swift
//  Tasker
//
//  Search ViewModel for Liquid Glass Search Screen
//

import Foundation
import CoreData
import UIKit

class LGSearchViewModel {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    
    var searchResults: [NTask] = []
    var filteredProjects: Set<String> = []
    var filteredPriorities: Set<Int32> = []
    
    var onResultsUpdated: (([NTask]) -> Void)?
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Search Methods
    
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            onResultsUpdated?([])
            return
        }
        
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        // Build predicates
        var predicates: [NSPredicate] = []
        
        // Text search predicate
        let searchLower = query.lowercased()
        let textPredicate = NSPredicate(format: "name CONTAINS[cd] %@ OR taskDetails CONTAINS[cd] %@ OR project CONTAINS[cd] %@", searchLower, searchLower, searchLower)
        predicates.append(textPredicate)
        
        // Project filter
        if !filteredProjects.isEmpty {
            let projectPredicate = NSPredicate(format: "project IN %@", Array(filteredProjects))
            predicates.append(projectPredicate)
        }
        
        // Priority filter
        if !filteredPriorities.isEmpty {
            let priorityPredicate = NSPredicate(format: "taskPriority IN %@", Array(filteredPriorities))
            predicates.append(priorityPredicate)
        }
        
        // Combine predicates
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        // Sort by due date
        request.sortDescriptors = [
            NSSortDescriptor(key: "isComplete", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        
        // Execute search
        do {
            searchResults = try context.fetch(request)
            onResultsUpdated?(searchResults)
        } catch {
            logError(" Search error: \(error)")
            searchResults = []
            onResultsUpdated?([])
        }
    }
    
    func searchAll() {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "isComplete", ascending: true),
            NSSortDescriptor(key: "dueDate", ascending: true)
        ]
        
        do {
            searchResults = try context.fetch(request)
            onResultsUpdated?(searchResults)
        } catch {
            logError(" Fetch all tasks error: \(error)")
            searchResults = []
            onResultsUpdated?([])
        }
    }
    
    // MARK: - Filter Methods
    
    func toggleProjectFilter(_ project: String) {
        if filteredProjects.contains(project) {
            filteredProjects.remove(project)
        } else {
            filteredProjects.insert(project)
        }
    }
    
    func togglePriorityFilter(_ priority: Int32) {
        if filteredPriorities.contains(priority) {
            filteredPriorities.remove(priority)
        } else {
            filteredPriorities.insert(priority)
        }
    }
    
    func clearFilters() {
        filteredProjects.removeAll()
        filteredPriorities.removeAll()
    }
    
    // MARK: - Helper Methods
    
    func getAllProjects() -> [String] {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        do {
            let tasks = try context.fetch(request)
            let projects = Set(tasks.compactMap { $0.project })
            return Array(projects).sorted()
        } catch {
            logError(" Fetch projects error: \(error)")
            return []
        }
    }
    
    func groupTasksByProject(_ tasks: [NTask]) -> [(project: String, tasks: [NTask])] {
        let grouped = Dictionary(grouping: tasks) { $0.project ?? "Inbox" }
        return grouped.map { (project: $0.key, tasks: $0.value) }
            .sorted { $0.project < $1.project }
    }
}
