//
//  ProjectSelectionSheet.swift
//  To Do List
//
//  Created by Assistant on Radar Chart Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import SwiftUI

// MARK: - Project Selection Sheet

struct ProjectSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedProjectIDs: [UUID]
    let onSave: ([UUID]) -> Void
    let onCreateProject: () -> Void
    @StateObject private var viewModel: ProjectSelectionViewModel

    @State private var currentSelection: Set<UUID>
    @State private var pinnedProjects: Set<UUID> // Track pinned state separately
    private var colors: TaskerSwiftUIColorTokens { Color.tasker }
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corners: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private let maxSelections = 5

    init(
        selectedProjectIDs: [UUID],
        onSave: @escaping ([UUID]) -> Void,
        onCreateProject: @escaping () -> Void = {},
        viewModel: ProjectSelectionViewModel
    ) {
        self.selectedProjectIDs = selectedProjectIDs
        self.onSave = onSave
        self.onCreateProject = onCreateProject
        _viewModel = StateObject(wrappedValue: viewModel)
        _currentSelection = State(initialValue: Set(selectedProjectIDs))
        _pinnedProjects = State(initialValue: Set(selectedProjectIDs)) // Initially, pinned = selected
    }

    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading projects...")
                        .scaleEffect(1.2)
                } else if viewModel.availableProjects.isEmpty {
                    emptyStateView
                } else {
                    projectListView
                }
            }
            .navigationTitle("Select Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSelection()
                    }
                    .fontWeight(.semibold)
                    .disabled(pinnedProjects.isEmpty)
                }
            }
            .onAppear {
                loadProjects()
            }
        }
    }

    // MARK: - Project List View

    private var projectListView: some View {
        VStack(spacing: 0) {
            // Selection info banner
            selectionInfoBanner

            // Project list (sorted: pinned first, then alphabetically)
            List {
                ForEach(sortedProjects) { project in
                    ProjectRow(
                        project: project,
                        isPinned: pinnedProjects.contains(project.id),
                        onTogglePin: {
                            toggleProjectPin(project.id)
                        }
                    )
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // Sorted projects: pinned first, then alphabetically
    private var sortedProjects: [ProjectInfo] {
        viewModel.availableProjects.sorted { p1, p2 in
            let p1Pinned = pinnedProjects.contains(p1.id)
            let p2Pinned = pinnedProjects.contains(p2.id)

            // Pinned projects come first
            if p1Pinned != p2Pinned {
                return p1Pinned
            }

            // Otherwise, sort alphabetically
            return p1.name.localizedCaseInsensitiveCompare(p2.name) == .orderedAscending
        }
    }

    // 🔥 NEW: Count of valid pinned projects (that actually exist in available projects)
    private var validPinnedCount: Int {
        return viewModel.availableProjects.filter { pinnedProjects.contains($0.id) }.count
    }

    // 🔥 NEW: Check if we have stale pins (pinned UUIDs that don't match available projects)
    private var hasStalePins: Bool {
        let availableUUIDs = Set(viewModel.availableProjects.map { $0.id })
        let pinnedUUIDs = Set(pinnedProjects)
        return !pinnedUUIDs.isSubset(of: availableUUIDs)
    }

    // MARK: - Selection Info Banner

    private var selectionInfoBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "pin.fill")
                    .foregroundColor(colors.accentPrimary)

                Text("Pin up to \(maxSelections) projects for radar chart")
                    .font(.tasker(.callout))
                    .foregroundColor(colors.textSecondary)

                Spacer()

                // Show valid pinned count vs available projects
                Text("\(validPinnedCount)/\(maxSelections)")
                    .font(.tasker(.callout))
                    .fontWeight(.semibold)
                    .foregroundColor(validPinnedCount >= maxSelections ? colors.statusDanger : colors.accentPrimary)
            }

            if validPinnedCount >= maxSelections {
                Text("Maximum pins reached")
                    .font(.tasker(.caption1))
                    .foregroundColor(colors.statusDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pinnedProjects.isEmpty {
                Text("Tap pin icon to select projects for radar chart")
                    .font(.tasker(.caption1))
                    .foregroundColor(colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if hasStalePins {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(colors.statusWarning)
                        .font(.tasker(.caption1))
                    Text("Cleaning up invalid project pins...")
                        .font(.tasker(.caption1))
                        .foregroundColor(colors.statusWarning)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("\(validPinnedCount) project\(validPinnedCount == 1 ? "" : "s") pinned")
                    .font(.tasker(.caption1))
                    .foregroundColor(colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(spacing.s16)
        .background(colors.surfaceSecondary)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.tasker(.display))
                .foregroundColor(colors.textTertiary.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Custom Projects")
                    .font(.tasker(.headline))
                    .foregroundColor(colors.textPrimary)

                Text("Create custom projects to see them here")
                    .font(.tasker(.callout))
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                dismiss()
                onCreateProject()
            }) {
                Text("Create Project")
                    .font(.tasker(.bodyEmphasis))
                    .fontWeight(.semibold)
                    .foregroundColor(colors.accentOnPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(colors.accentPrimary)
                    .cornerRadius(corners.r2)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Actions

    private func toggleProjectPin(_ projectID: UUID) {
        if pinnedProjects.contains(projectID) {
            // Unpin
            pinnedProjects.remove(projectID)
            logDebug("📌 Unpinned project: \(projectID)")
        } else {
            // Pin (if under limit)
            if pinnedProjects.count < maxSelections {
                pinnedProjects.insert(projectID)
                logDebug("📌 Pinned project: \(projectID)")
            }
        }
    }

    private func saveSelection() {
        // 🔥 NEW: Automatically filter out stale pins before saving
        let validPinnedProjects = pinnedProjects.filter { pinnedUUID in
            return viewModel.availableProjects.contains { $0.id == pinnedUUID }
        }

        let pinnedArray = Array(validPinnedProjects)

        // Log cleanup if it happened
        if pinnedArray.count < pinnedProjects.count {
            let cleanedCount = pinnedProjects.count - pinnedArray.count
            logDebug("🧹 [ProjectSelectionSheet] Cleaned up \(cleanedCount) stale pins during save")
        }

        logDebug("📌 Saving \(pinnedArray.count) valid pinned projects")
        onSave(pinnedArray)
        dismiss()
    }

    private func loadProjects() {
        logDebug("📋 [ProjectSelectionSheet] Loading projects...")
        viewModel.load { infos in
            self.pinnedProjects = self.pinnedProjects.intersection(Set(infos.map(\.id)))
            logDebug("✅ [ProjectSelectionSheet] Loaded \(infos.count) projects")
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: ProjectInfo
    let isPinned: Bool
    let onTogglePin: () -> Void
    private var colors: TaskerSwiftUIColorTokens { Color.tasker }
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corners: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        Button(action: onTogglePin) {
            HStack(spacing: spacing.s12) {
                // Project info
                VStack(alignment: .leading, spacing: spacing.s4) {
                    HStack(spacing: 8) {
                        Text(project.name)
                            .font(.tasker(.body))
                            .fontWeight(isPinned ? .semibold : .medium)
                            .foregroundColor(colors.textPrimary)

                        // Pin badge for pinned projects
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.tasker(.caption2))
                                .foregroundColor(colors.accentPrimary)
                        }
                    }

                    Text("\(project.taskCount) tasks")
                        .font(.tasker(.caption1))
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                // Pin button
                Image(systemName: isPinned ? "pin.circle.fill" : "pin.circle")
                    .font(.tasker(.title1))
                    .foregroundColor(isPinned ? colors.accentPrimary : colors.textQuaternary)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.vertical, spacing.s8)
            .padding(.horizontal, spacing.s4)
            .background(
                RoundedRectangle(cornerRadius: corners.r1)
                    .fill(isPinned ? colors.accentWash : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corners.r1)
                    .stroke(isPinned ? colors.accentRing : Color.clear, lineWidth: isPinned ? 1 : 0)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Project Info Model

struct ProjectInfo: Identifiable {
    let id: UUID
    let name: String
    let taskCount: Int
}

// MARK: - Preview

struct ProjectSelectionSheet_Previews: PreviewProvider {
    static var previews: some View {
        let taskRepository = PreviewProjectSelectionTaskRepository()
        let projectRepository = PreviewProjectSelectionProjectRepository()
        let viewModel = ProjectSelectionViewModel(
            taskRepository: taskRepository,
            projectRepository: projectRepository
        )
        ProjectSelectionSheet(selectedProjectIDs: [], onSave: { _ in }, viewModel: viewModel)
    }
}

private final class PreviewProjectSelectionTaskRepository: TaskRepositoryProtocol {
    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) { completion(.success(nil)) }
    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) { completion(.success(task)) }
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) { completion(.success(task)) }
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success(tasks)) }
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
}

private final class PreviewProjectSelectionProjectRepository: ProjectRepositoryProtocol {
    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success([])) }
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) { completion(.success([])) }
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(project)) }
    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) { completion(.success(project)) }
    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) { completion(.success(0)) }
    func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) { completion(.success([])) }
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) { completion(.success(())) }
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) { completion(.success(true)) }
}
