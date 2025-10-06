//
//  ProjectSelectionSheet.swift
//  To Do List
//
//  Created by Assistant on Radar Chart Implementation
//  Copyright 2025 saransh1337. All rights reserved.
//

import SwiftUI
import CoreData

// MARK: - Project Selection Sheet

struct ProjectSelectionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selectedProjectIDs: [UUID]
    let onSave: ([UUID]) -> Void

    @State private var currentSelection: Set<UUID>
    @State private var availableProjects: [ProjectInfo] = []
    @State private var isLoading = true

    private let maxSelections = 5

    init(selectedProjectIDs: [UUID], onSave: @escaping ([UUID]) -> Void) {
        self.selectedProjectIDs = selectedProjectIDs
        self.onSave = onSave
        _currentSelection = State(initialValue: Set(selectedProjectIDs))
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
                    .disabled(currentSelection.isEmpty)
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

            // Project list
            List {
                ForEach(availableProjects) { project in
                    ProjectRow(
                        project: project,
                        isSelected: currentSelection.contains(project.id),
                        onToggle: {
                            toggleProjectSelection(project.id)
                        }
                    )
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Selection Info Banner

    private var selectionInfoBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)

                Text("Select up to \(maxSelections) projects")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(currentSelection.count)/\(maxSelections)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(currentSelection.count >= maxSelections ? .red : .blue)
            }

            if currentSelection.count >= maxSelections {
                Text("Maximum selections reached")
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Custom Projects")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text("Create custom projects to see them here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                dismiss()
                // Notify to show project management
                NotificationCenter.default.post(name: Notification.Name("ShowProjectManagement"), object: nil)
            }) {
                Text("Create Project")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Actions

    private func toggleProjectSelection(_ projectID: UUID) {
        if currentSelection.contains(projectID) {
            // Deselect
            currentSelection.remove(projectID)
        } else {
            // Select (if under limit)
            if currentSelection.count < maxSelections {
                currentSelection.insert(projectID)
            }
        }
    }

    private func saveSelection() {
        let selectedArray = Array(currentSelection)
        onSave(selectedArray)
        dismiss()
    }

    private func loadProjects() {
        isLoading = true

        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            isLoading = false
            return
        }

        context.perform {
            // Fetch all custom projects (exclude Inbox)
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(
                format: "projectID != %@",
                ProjectConstants.inboxProjectID as CVarArg
            )
            request.sortDescriptors = [NSSortDescriptor(key: "projectName", ascending: true)]

            let projects = (try? context.fetch(request)) ?? []

            // Convert to ProjectInfo
            let projectInfos = projects.compactMap { project -> ProjectInfo? in
                guard let id = project.projectID,
                      let name = project.projectName else {
                    return nil
                }

                // Calculate task count for this project
                let taskRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
                taskRequest.predicate = NSPredicate(
                    format: "projectID == %@",
                    id as CVarArg
                )
                let taskCount = (try? context.count(for: taskRequest)) ?? 0

                return ProjectInfo(
                    id: id,
                    name: name,
                    taskCount: taskCount
                )
            }

            DispatchQueue.main.async {
                self.availableProjects = projectInfos
                withAnimation {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - Project Row

struct ProjectRow: View {
    let project: ProjectInfo
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .blue : .gray)

                // Project info
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text("\(project.taskCount) tasks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
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
