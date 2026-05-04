//
//  ProjectSelectionSheet.swift
//  LifeBoard
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
    private var colors: LifeBoardSwiftUIColorTokens { Color.lifeboard }
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corners: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    private let maxSelections = 5

    /// Initializes a new instance.
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
        NavigationStack {
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
            .lifeboardReadableContent(maxWidth: 760, alignment: .center)
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
                    .font(.lifeboard(.callout))
                    .foregroundColor(colors.textSecondary)

                Spacer()

                // Show valid pinned count vs available projects
                Text("\(validPinnedCount)/\(maxSelections)")
                    .font(.lifeboard(.callout))
                    .fontWeight(.semibold)
                    .foregroundColor(validPinnedCount >= maxSelections ? colors.statusDanger : colors.accentPrimary)
            }

            if validPinnedCount >= maxSelections {
                Text("Maximum pins reached")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(colors.statusDanger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if pinnedProjects.isEmpty {
                Text("Tap pin icon to select projects for radar chart")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if hasStalePins {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(colors.statusWarning)
                        .font(.lifeboard(.caption1))
                    Text("Cleaning up invalid project pins...")
                        .font(.lifeboard(.caption1))
                        .foregroundColor(colors.statusWarning)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("\(validPinnedCount) project\(validPinnedCount == 1 ? "" : "s") pinned")
                    .font(.lifeboard(.caption1))
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
                .font(.lifeboard(.display))
                .foregroundColor(colors.textTertiary.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Custom Projects")
                    .font(.lifeboard(.headline))
                    .foregroundColor(colors.textPrimary)

                Text("Create custom projects to see them here")
                    .font(.lifeboard(.callout))
                    .foregroundColor(colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                dismiss()
                onCreateProject()
            }) {
                Text("Create Project")
                    .font(.lifeboard(.bodyEmphasis))
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

    /// Executes toggleProjectPin.
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

    /// Executes saveSelection.
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

    /// Executes loadProjects.
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
    private var colors: LifeBoardSwiftUIColorTokens { Color.lifeboard }
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corners: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        Button(action: onTogglePin) {
            HStack(spacing: spacing.s12) {
                // Project info
                VStack(alignment: .leading, spacing: spacing.s4) {
                    HStack(spacing: 8) {
                        Text(project.name)
                            .font(.lifeboard(.body))
                            .fontWeight(isPinned ? .semibold : .medium)
                            .foregroundColor(colors.textPrimary)

                        // Pin badge for pinned projects
                        if isPinned {
                            Image(systemName: "pin.fill")
                                .font(.lifeboard(.caption2))
                                .foregroundColor(colors.accentPrimary)
                        }
                    }

                    Text("\(project.taskCount) tasks")
                        .font(.lifeboard(.caption1))
                        .foregroundColor(colors.textSecondary)
                }

                Spacer()

                // Pin button
                Image(systemName: isPinned ? "pin.circle.fill" : "pin.circle")
                    .font(.lifeboard(.title1))
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

struct ProjectInfo: Identifiable, Sendable {
    let id: UUID
    let name: String
    let taskCount: Int
}

// MARK: - Preview

struct ProjectSelectionSheet_Previews: PreviewProvider {
    static var previews: some View {
        let readModelRepository = PreviewProjectSelectionReadModelRepository()
        let projectRepository = PreviewProjectSelectionProjectRepository()
        let viewModel = ProjectSelectionViewModel(
            projectRepository: projectRepository,
            readModelRepository: readModelRepository
        )
        ProjectSelectionSheet(selectedProjectIDs: [], onSave: { _ in }, viewModel: viewModel)
    }
}

private final class PreviewProjectSelectionReadModelRepository: TaskReadModelRepositoryProtocol {
    /// Executes fetchTasks.
    func fetchTasks(query: TaskReadQuery, completion: @escaping @Sendable (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    /// Executes searchTasks.
    func searchTasks(query: TaskSearchQuery, completion: @escaping @Sendable (Result<TaskDefinitionSliceResult, Error>) -> Void) {
        completion(.success(TaskDefinitionSliceResult(tasks: [], totalCount: 0, limit: query.limit, offset: query.offset)))
    }

    /// Executes fetchProjectTaskCounts.
    func fetchProjectTaskCounts(
        includeCompleted: Bool,
        completion: @escaping @Sendable (Result<[UUID: Int], Error>) -> Void
    ) {
        completion(.success([:]))
    }

    /// Executes fetchProjectCompletionScoreTotals.
    func fetchProjectCompletionScoreTotals(
        from startDate: Date,
        to endDate: Date,
        completion: @escaping @Sendable (Result<[UUID: Int], Error>) -> Void
    ) {
        completion(.success([:]))
    }
}

private final class PreviewProjectSelectionProjectRepository: ProjectRepositoryProtocol {
    /// Executes fetchAllProjects.
    func fetchAllProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) { completion(.success([])) }
    /// Executes fetchProject.
    func fetchProject(withId id: UUID, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    /// Executes fetchProject.
    func fetchProject(withName name: String, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) { completion(.success(nil)) }
    /// Executes fetchInboxProject.
    func fetchInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    /// Executes fetchCustomProjects.
    func fetchCustomProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) { completion(.success([])) }
    /// Executes createProject.
    func createProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.success(project)) }
    /// Executes ensureInboxProject.
    func ensureInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    /// Executes repairProjectIdentityCollisions.
    func repairProjectIdentityCollisions(completion: @escaping @Sendable (Result<ProjectRepairReport, Error>) -> Void) {
        completion(.success(ProjectRepairReport(scanned: 0, merged: 0, deleted: 0, inboxCandidates: 0, warnings: [])))
    }
    /// Executes updateProject.
    func updateProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.success(project)) }
    /// Executes renameProject.
    func renameProject(withId id: UUID, to newName: String, completion: @escaping @Sendable (Result<Project, Error>) -> Void) { completion(.failure(NSError(domain: "preview", code: 1))) }
    /// Executes deleteProject.
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    /// Executes getTaskCount.
    func getTaskCount(for projectId: UUID, completion: @escaping @Sendable (Result<Int, Error>) -> Void) { completion(.success(0)) }
    /// Executes moveTasks.
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) { completion(.success(())) }
    /// Executes isProjectNameAvailable.
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) { completion(.success(true)) }
}
