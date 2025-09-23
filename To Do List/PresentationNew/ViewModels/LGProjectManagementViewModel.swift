// LGProjectManagementViewModel.swift
// MVVM ViewModel for Project Management - Phase 5 Implementation
// Reactive project management with RxSwift and Core Data integration

import Foundation
import UIKit
import CoreData
import RxSwift
import RxCocoa

class LGProjectManagementViewModel {
    
    // MARK: - Dependencies
    private let context: NSManagedObjectContext
    private let disposeBag = DisposeBag()
    
    // MARK: - Input Properties (From UI)
    let searchText = BehaviorRelay<String>(value: "")
    let selectedFilter = BehaviorRelay<ProjectFilter>(value: .all)
    let sortOption = BehaviorRelay<SortOption>(value: .nameAscending)
    
    // MARK: - Output Properties (To UI)
    let projects = BehaviorRelay<[Projects]>(value: [])
    let filteredProjects = BehaviorRelay<[Projects]>(value: [])
    let totalProjects = BehaviorRelay<Int>(value: 0)
    let activeProjects = BehaviorRelay<Int>(value: 0)
    let completedProjects = BehaviorRelay<Int>(value: 0)
    let isLoading = BehaviorRelay<Bool>(value: false)
    let error = PublishRelay<Error>()
    
    // MARK: - Enums
    
    enum ProjectFilter {
        case all, active, completed, archived
        
        var title: String {
            switch self {
            case .all: return "All Projects"
            case .active: return "Active"
            case .completed: return "Completed"
            case .archived: return "Archived"
            }
        }
    }
    
    enum SortOption {
        case nameAscending, nameDescending, dateCreated, progress, taskCount
        
        var title: String {
            switch self {
            case .nameAscending: return "Name A-Z"
            case .nameDescending: return "Name Z-A"
            case .dateCreated: return "Date Created"
            case .progress: return "Progress"
            case .taskCount: return "Task Count"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupBindings()
        refreshProjects()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Combine projects with filters and search
        Observable.combineLatest(
            projects.asObservable(),
            searchText.asObservable(),
            selectedFilter.asObservable(),
            sortOption.asObservable()
        )
        .map { [weak self] projects, search, filter, sort in
            return self?.processProjects(projects, search: search, filter: filter, sort: sort) ?? []
        }
        .bind(to: filteredProjects)
        .disposed(by: disposeBag)
        
        // Update stats when projects change
        projects
            .subscribe(onNext: { [weak self] projects in
                self?.updateStats(projects)
            })
            .disposed(by: disposeBag)
    }
    
    private func processProjects(_ projects: [Projects], search: String, filter: ProjectFilter, sort: SortOption) -> [Projects] {
        var result = projects
        
        // Apply search filter
        if !search.isEmpty {
            result = result.filter { project in
                return project.name?.localizedCaseInsensitiveContains(search) == true ||
                       project.projectDescription?.localizedCaseInsensitiveContains(search) == true
            }
        }
        
        // Apply status filter
        switch filter {
        case .all:
            break
        case .active:
            result = result.filter { !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .archived:
            result = result.filter { $0.isArchived }
        }
        
        // Apply sorting
        switch sort {
        case .nameAscending:
            result = result.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .nameDescending:
            result = result.sorted { ($0.name ?? "") > ($1.name ?? "") }
        case .dateCreated:
            result = result.sorted { ($0.dateCreated ?? Date.distantPast) > ($1.dateCreated ?? Date.distantPast) }
        case .progress:
            result = result.sorted { calculateProgress($0) > calculateProgress($1) }
        case .taskCount:
            result = result.sorted { getTaskCount($0) > getTaskCount($1) }
        }
        
        return result
    }
    
    private func updateStats(_ projects: [Projects]) {
        totalProjects.accept(projects.count)
        activeProjects.accept(projects.filter { !$0.isCompleted }.count)
        completedProjects.accept(projects.filter { $0.isCompleted }.count)
    }
    
    // MARK: - Public Methods
    
    func refreshProjects() {
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let request: NSFetchRequest<Projects> = Projects.fetchRequest()
                request.sortDescriptors = [
                    NSSortDescriptor(key: "dateCreated", ascending: false)
                ]
                
                let fetchedProjects = try self.context.fetch(request)
                
                DispatchQueue.main.async {
                    self.projects.accept(fetchedProjects)
                    self.isLoading.accept(false)
                }
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    func setFilter(_ filter: ProjectFilter) {
        selectedFilter.accept(filter)
    }
    
    func setSortOption(_ option: SortOption) {
        sortOption.accept(option)
    }
    
    func searchProjects(_ query: String) {
        searchText.accept(query)
    }
    
    func deleteProject(_ project: Projects) {
        context.delete(project)
        
        do {
            try context.save()
            refreshProjects()
        } catch {
            self.error.accept(error)
        }
    }
    
    func toggleProjectCompletion(_ project: Projects) {
        project.isCompleted.toggle()
        if project.isCompleted {
            project.dateCompleted = Date()
        } else {
            project.dateCompleted = nil
        }
        
        do {
            try context.save()
            refreshProjects()
        } catch {
            self.error.accept(error)
        }
    }
    
    func archiveProject(_ project: Projects) {
        project.isArchived = true
        project.dateArchived = Date()
        
        do {
            try context.save()
            refreshProjects()
        } catch {
            self.error.accept(error)
        }
    }
    
    func duplicateProject(_ project: Projects) {
        let newProject = Projects(context: context)
        newProject.name = "\(project.name ?? "Project") Copy"
        newProject.projectDescription = project.projectDescription
        newProject.color = project.color
        newProject.dateCreated = Date()
        newProject.isCompleted = false
        newProject.isArchived = false
        
        do {
            try context.save()
            refreshProjects()
        } catch {
            self.error.accept(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateProgress(_ project: Projects) -> Float {
        guard let tasks = project.tasks?.allObjects as? [NTask] else { return 0.0 }
        
        let totalTasks = tasks.count
        guard totalTasks > 0 else { return 0.0 }
        
        let completedTasks = tasks.filter { $0.isComplete }.count
        return Float(completedTasks) / Float(totalTasks)
    }
    
    private func getTaskCount(_ project: Projects) -> Int {
        return project.tasks?.count ?? 0
    }
    
    func getProjectStats(_ project: Projects) -> ProjectStats {
        guard let tasks = project.tasks?.allObjects as? [NTask] else {
            return ProjectStats(totalTasks: 0, completedTasks: 0, progress: 0.0)
        }
        
        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.isComplete }.count
        let progress = totalTasks > 0 ? Float(completedTasks) / Float(totalTasks) : 0.0
        
        return ProjectStats(
            totalTasks: totalTasks,
            completedTasks: completedTasks,
            progress: progress
        )
    }
    
    func getRecentActivity(_ project: Projects) -> [ProjectActivity] {
        guard let tasks = project.tasks?.allObjects as? [NTask] else { return [] }
        
        var activities: [ProjectActivity] = []
        
        // Recent completions
        let recentCompletions = tasks
            .filter { $0.isComplete && $0.dateCompleted != nil }
            .sorted { ($0.dateCompleted ?? Date.distantPast) > ($1.dateCompleted ?? Date.distantPast) }
            .prefix(5)
        
        for task in recentCompletions {
            activities.append(ProjectActivity(
                type: .taskCompleted,
                taskName: task.name ?? "Unknown Task",
                date: task.dateCompleted ?? Date(),
                description: "Task completed"
            ))
        }
        
        // Recent additions
        let recentAdditions = tasks
            .sorted { ($0.dateCreated ?? Date.distantPast) > ($1.dateCreated ?? Date.distantPast) }
            .prefix(3)
        
        for task in recentAdditions {
            activities.append(ProjectActivity(
                type: .taskAdded,
                taskName: task.name ?? "Unknown Task",
                date: task.dateCreated ?? Date(),
                description: "Task added"
            ))
        }
        
        return activities.sorted { $0.date > $1.date }
    }
}

// MARK: - Data Models

struct ProjectStats {
    let totalTasks: Int
    let completedTasks: Int
    let progress: Float
    
    var progressPercentage: Int {
        return Int(progress * 100)
    }
    
    var remainingTasks: Int {
        return totalTasks - completedTasks
    }
}

struct ProjectActivity {
    enum ActivityType {
        case taskAdded, taskCompleted, taskDeleted, projectCreated, projectCompleted
        
        var icon: UIImage? {
            switch self {
            case .taskAdded: return UIImage(systemName: "plus.circle.fill")
            case .taskCompleted: return UIImage(systemName: "checkmark.circle.fill")
            case .taskDeleted: return UIImage(systemName: "trash.circle.fill")
            case .projectCreated: return UIImage(systemName: "folder.badge.plus")
            case .projectCompleted: return UIImage(systemName: "checkmark.seal.fill")
            }
        }
        
        var color: UIColor {
            switch self {
            case .taskAdded: return .systemBlue
            case .taskCompleted: return .systemGreen
            case .taskDeleted: return .systemRed
            case .projectCreated: return .systemPurple
            case .projectCompleted: return .systemOrange
            }
        }
    }
    
    let type: ActivityType
    let taskName: String
    let date: Date
    let description: String
}
