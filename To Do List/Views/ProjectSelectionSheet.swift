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

    @State private var currentSelection: Set<UUID>
    @State private var pinnedProjects: Set<UUID> // Track pinned state separately
    @State private var availableProjects: [ProjectInfo] = []
    @State private var isLoading = true
    private var colors: TaskerSwiftUIColorTokens { Color.tasker }
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corners: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    private let maxSelections = 5

    init(selectedProjectIDs: [UUID], onSave: @escaping ([UUID]) -> Void) {
        self.selectedProjectIDs = selectedProjectIDs
        self.onSave = onSave
        _currentSelection = State(initialValue: Set(selectedProjectIDs))
        _pinnedProjects = State(initialValue: Set(selectedProjectIDs)) // Initially, pinned = selected
    }

    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading projects...")
                        .scaleEffect(1.2)
                } else if availableProjects.isEmpty {
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
        availableProjects.sorted { p1, p2 in
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
        return availableProjects.filter { pinnedProjects.contains($0.id) }.count
    }

    // 🔥 NEW: Check if we have stale pins (pinned UUIDs that don't match available projects)
    private var hasStalePins: Bool {
        let availableUUIDs = Set(availableProjects.map { $0.id })
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
                // Notify to show project management
                NotificationCenter.default.post(name: Notification.Name("ShowProjectManagement"), object: nil)
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
            return availableProjects.contains { $0.id == pinnedUUID }
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
        isLoading = true

        logDebug("📋 [ProjectSelectionSheet] Loading projects...")

        guard
            let projectRepository = EnhancedDependencyContainer.shared.projectRepository,
            let taskRepository = EnhancedDependencyContainer.shared.taskRepository
        else {
            logWarning(
                event: "project_selection_dependencies_missing",
                message: "Project/task repositories unavailable for project selection"
            )
            isLoading = false
            return
        }

        projectRepository.fetchCustomProjects { projectResult in
            switch projectResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    logError("❌ [ProjectSelectionSheet] Failed to load projects: \(error.localizedDescription)")
                    self.availableProjects = []
                    withAnimation {
                        self.isLoading = false
                    }
                }
            case .success(let projects):
                taskRepository.fetchAllTasks { taskResult in
                    let allTasks = (try? taskResult.get()) ?? []
                    let taskCountsByProject = allTasks.reduce(into: [UUID: Int]()) { counts, task in
                        counts[task.projectID, default: 0] += 1
                    }

                    let infos = projects
                        .filter { $0.id != ProjectConstants.inboxProjectID }
                        .map { project in
                            ProjectInfo(
                                id: project.id,
                                name: project.name,
                                taskCount: taskCountsByProject[project.id, default: 0]
                            )
                        }
                        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

                    DispatchQueue.main.async {
                        self.availableProjects = infos
                        self.pinnedProjects = self.pinnedProjects.intersection(Set(infos.map(\.id)))
                        withAnimation {
                            self.isLoading = false
                        }
                        logDebug("✅ [ProjectSelectionSheet] Loaded \(infos.count) projects")
                    }
                }
            }
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
        ProjectSelectionSheet(selectedProjectIDs: []) { _ in }
    }
}
