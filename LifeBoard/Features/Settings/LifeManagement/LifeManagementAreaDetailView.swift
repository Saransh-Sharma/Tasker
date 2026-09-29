import SwiftUI
import UIKit

struct LifeManagementAreaDetailView: View {
    let snapshot: LifeManagementAreaDetailSnapshot?
    let onEditArea: (UUID) -> Void
    let onOpenHabit: (HabitLibraryRow) -> Void
    let onCreateHabit: (AddHabitPrefillTemplate) -> Void
    let onArchiveArea: (UUID) -> Void
    let onRestoreArea: (UUID) -> Void
    let onDeleteArea: (UUID) -> Void
    let onBeginCreateProject: (UUID) -> Void

    @Environment(\.lifeboardTokens) private var tokens

    var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    var body: some View {
        Group {
            if let snapshot {
                let row = snapshot.row
                ScrollView {
                    VStack(spacing: spacing.s16) {
                        SettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                AreaSummaryRow(row: row)
                                LifeManagementAppearanceLine(
                                    title: "Color",
                                    accentHex: lifeManagementAreaAccentHex(row.lifeArea),
                                    value: ""
                                )
                                if row.lifeArea.isArchived == false {
                                    Button("Edit area") {
                                        onEditArea(row.id)
                                    }
                                    .buttonStyle(.lifeBoardChip)
                                }
                            }
                        }

                        SettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                        sectionTitle("Projects")
                                        Spacer()
                                        Button("Add project") {
                                            onBeginCreateProject(row.id)
                                        }
                                        .buttonStyle(.lifeBoardChip)
                                        .disabled(row.lifeArea.isArchived)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        sectionTitle("Projects")
                                        Button("Add project") {
                                            onBeginCreateProject(row.id)
                                        }
                                        .buttonStyle(.lifeBoardChip)
                                        .disabled(row.lifeArea.isArchived)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                if snapshot.projectRows.isEmpty {
                                    Text("No projects yet")
                                        .font(.lifeboard(.callout))
                                        .foregroundStyle(Color.lifeboard(.textSecondary))
                                } else {
                                    VStack(spacing: spacing.chipSpacing) {
                                        ForEach(snapshot.projectRows) { projectRow in
                                            NavigationLink(value: LifeManagementSelection.project(projectRow.id)) {
                                                ProjectSummaryRow(row: projectRow)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        SettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                        sectionTitle("Habits")
                                        Spacer()
                                        Button("Add habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.lifeBoardChip)
                                        .disabled(row.lifeArea.isArchived)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        sectionTitle("Habits")
                                        Button("Add habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.lifeBoardChip)
                                        .disabled(row.lifeArea.isArchived)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                if snapshot.habitRows.isEmpty {
                                    Text("No habits yet")
                                        .font(.lifeboard(.callout))
                                        .foregroundStyle(Color.lifeboard(.textSecondary))
                                } else {
                                    VStack(spacing: spacing.chipSpacing) {
                                        ForEach(snapshot.habitRows) { habitRow in
                                            HabitSummaryRow(row: habitRow) {
                                                onOpenHabit(habitRow.row)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        SettingsCard(active: true) {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                sectionTitle("Actions")

                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: spacing.s8) {
                                        areaActionButtons(row: row)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        areaActionButtons(row: row)
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
                .navigationTitle(row.lifeArea.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Color.lifeboard(.bgCanvas)
                    .overlay {
                        Text("This area isn’t available.")
                            .font(.lifeboard(.body))
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
            }
        }
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.lifeboard(.headline))
            .foregroundStyle(Color.lifeboard(.textPrimary))
    }

    @ViewBuilder
    func areaActionButtons(row: LifeManagementAreaRow) -> some View {
        if row.lifeArea.isArchived {
            Button("Restore") {
                onRestoreArea(row.id)
            }
            .buttonStyle(.lifeBoardPrimaryCompact)
        } else if row.isGeneral == false {
            Button("Archive area") {
                onArchiveArea(row.id)
            }
            .buttonStyle(.bordered)
        }

        if row.isGeneral == false {
            Button("Delete area", role: .destructive) {
                onDeleteArea(row.id)
            }
            .buttonStyle(.bordered)
        }
    }
}
