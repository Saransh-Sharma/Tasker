import SwiftUI
import UIKit

struct LifeManagementProjectDetailView: View {
    let snapshot: LifeManagementProjectDetailSnapshot?
    let onEditProject: (UUID) -> Void
    let onOpenHabit: (HabitLibraryRow) -> Void
    let onCreateHabit: (AddHabitPrefillTemplate) -> Void
    let onBeginMoveProject: (UUID) -> Void
    let onArchiveProject: (UUID) -> Void
    let onRestoreProject: (UUID) -> Void
    let onDeleteProject: (UUID) -> Void

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        Group {
            if let snapshot {
                let row = snapshot.row
                let canAddLinkedHabits = row.project.isArchived == false && row.lifeArea?.isArchived != true
                ScrollView {
                    VStack(spacing: spacing.s16) {
                        LifeBoardSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ProjectSummaryRow(row: row)
                                Text("\(row.project.color.displayName) · \(row.project.icon.displayName)")
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard(.textSecondary))
                                Text(row.project.projectDescription?.lifeManagementNilIfBlank ?? "No project description yet.")
                                    .font(.lifeboard(.callout))
                                    .foregroundStyle(Color.lifeboard(.textSecondary))
                                if row.project.isArchived == false {
                                    Button("Edit Project") {
                                        onEditProject(row.id)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        LifeBoardSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                Text("Structure")
                                    .font(.lifeboard(.headline))
                                    .foregroundStyle(Color.lifeboard(.textPrimary))

                                detailLine(title: "Area", value: row.lifeArea?.name ?? "No Area")
                                detailLine(title: "Open tasks", value: "\(row.taskCount)")
                                detailLine(title: "Linked habits", value: "\(snapshot.linkedHabits.count)")
                            }
                        }

                        LifeBoardSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                        Text("Linked habits")
                                            .font(.lifeboard(.headline))
                                            .foregroundStyle(Color.lifeboard(.textPrimary))
                                        Spacer()
                                        Button("Add Habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.project.lifeAreaID,
                                                    projectID: row.project.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(canAddLinkedHabits == false)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        Text("Linked habits")
                                            .font(.lifeboard(.headline))
                                            .foregroundStyle(Color.lifeboard(.textPrimary))
                                        Button("Add Habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.project.lifeAreaID,
                                                    projectID: row.project.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(canAddLinkedHabits == false)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                if snapshot.linkedHabits.isEmpty {
                                    Text("No habits are linked to this project.")
                                        .font(.lifeboard(.callout))
                                        .foregroundStyle(Color.lifeboard(.textSecondary))
                                } else {
                                    VStack(spacing: spacing.chipSpacing) {
                                        ForEach(snapshot.linkedHabits) { habitRow in
                                            HabitSummaryRow(row: habitRow) {
                                                onOpenHabit(habitRow.row)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        LifeBoardSettingsCard(active: true) {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                Text("Actions")
                                    .font(.lifeboard(.headline))
                                    .foregroundStyle(Color.lifeboard(.textPrimary))

                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: spacing.s8) {
                                        projectActionButtons(row: row)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        projectActionButtons(row: row)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, spacing.screenHorizontal)
                    .padding(.vertical, spacing.s16)
                    .lifeboardReadableContent(maxWidth: 920, alignment: .center)
                }
                .background(Color.lifeboard(.bgCanvas))
                .navigationTitle(row.project.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Color.lifeboard(.bgCanvas)
                    .overlay {
                        Text("This project is no longer available.")
                            .font(.lifeboard(.body))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
            }
        }
    }

    func detailLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Spacer()
            Text(value)
                .font(.lifeboard(.bodyEmphasis))
                .foregroundStyle(Color.lifeboard(.textPrimary))
        }
    }

    @ViewBuilder
    func projectActionButtons(row: LifeManagementProjectRow) -> some View {
        if row.isMoveLocked == false {
            Button("Move Project") {
                onBeginMoveProject(row.id)
            }
            .buttonStyle(.bordered)
        }

        if row.project.isArchived {
            Button("Restore") {
                onRestoreProject(row.id)
            }
            .buttonStyle(.borderedProminent)
        } else if row.isInbox == false {
            Button("Archive Project") {
                onArchiveProject(row.id)
            }
            .buttonStyle(.bordered)
        }

        if row.project.isDefault == false {
            Button("Delete Project", role: .destructive) {
                onDeleteProject(row.id)
            }
            .buttonStyle(.bordered)
        }
    }
}
