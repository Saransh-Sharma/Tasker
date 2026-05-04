//
//  AddTaskProjectBar.swift
//  LifeBoard
//
//  Horizontal scrollable bar for project selection with inline project creation.
//

import SwiftUI

// MARK: - Add Task Project Bar

struct AddTaskProjectBar: View {
    @Binding var selectedProject: String
    let projects: [Project]
    let onCreateProject: (String) -> Void

    @State private var showInlineCreator = false
    @State private var newProjectName = ""

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        VStack(spacing: spacing.s8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    // Add project button
                    Button {
                        LifeBoardFeedback.selection()
                        withAnimation(LifeBoardAnimation.snappy) {
                            showInlineCreator = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .medium))
                            Text("Add Project")
                                .font(.lifeboard(.caption1))
                        }
                        .foregroundColor(Color.lifeboard.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.lifeboard.surfaceSecondary)
                                .overlay(
                                    Capsule()
                                        .stroke(Color.lifeboard.strokeHairline, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()

                    // Project pills
                    ForEach(projects, id: \.id) { project in
                        AddTaskProjectPill(
                            name: project.name,
                            isSelected: selectedProject == project.name
                        ) {
                            selectedProject = project.name
                        }
                    }
                }
            }

            // Inline creator
            if showInlineCreator {
                AddTaskInlineCreator(
                    projectName: $newProjectName,
                    onCreate: {
                        onCreateProject(newProjectName)
                        newProjectName = ""
                        showInlineCreator = false
                    },
                    onCancel: {
                        newProjectName = ""
                        showInlineCreator = false
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .animation(LifeBoardAnimation.snappy, value: showInlineCreator)
    }
}

// MARK: - Preview

#if DEBUG
struct AddTaskProjectBar_Previews: PreviewProvider {
    static let sampleProjects = [
        Project(id: UUID(), name: "Inbox", color: .gray),
        Project(id: UUID(), name: "Work", color: .blue),
        Project(id: UUID(), name: "Personal", color: .green)
    ]

    @State static var selectedProject = "Inbox"

    static var previews: some View {
        VStack(spacing: 16) {
            AddTaskProjectBar(
                selectedProject: $selectedProject,
                projects: sampleProjects,
                onCreateProject: { name in print("Created: \(name)") }
            )
        }
        .padding()
        .background(Color.lifeboard.surfacePrimary)
        .previewLayout(.sizeThatFits)
    }
}
#endif
