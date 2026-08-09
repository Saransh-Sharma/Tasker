import SwiftUI
import UIKit

/// The multi-select action bar in the task library.
///
/// Split out of `TaskExecutionLibraryView` purely for size: it reads the
/// library's selection and choice lists but owns none of them, so everything
/// arrives as a plain value and mutations go back through `applyBatch`.
struct TaskExecutionBatchActionBar: View {
    let selectionCount: Int
    let scope: TaskExecutionQuery.Scope
    let tags: [TagDefinition]
    let projects: [Project]
    let sectionsByProjectID: [UUID: [LifeBoardProjectSection]]
    let isApplyingBatch: Bool
    let applyBatch: (TaskBatchMutation) -> Void
    @Binding var destructiveMutation: TaskBatchMutation?

    var body: some View {
        HStack(spacing: 10) {
            Text("\(selectionCount) selected")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .accessibilityLabel("\(selectionCount) tasks selected")

            Spacer(minLength: 4)

            Menu {
                Button("Today") {
                    applyBatch(
                        .schedule(
                            planningDay: PlanningDay(date: Date()),
                            startAt: nil,
                            endAt: nil
                        )
                    )
                }
                Button("Tomorrow") {
                    applyBatch(.deferTo(planningDay(daysFromToday: 1)))
                }
                Button("Next week") {
                    applyBatch(.deferTo(planningDay(daysFromToday: 7)))
                }
            } label: {
                Label("Plan", systemImage: "calendar")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isApplyingBatch)
            .accessibilityIdentifier("plan.taskLibrary.batch.plan")

            Menu {
                if tags.isEmpty == false {
                    Section("Add tag") {
                        ForEach(tags, id: \.id) { tag in
                            Button(tag.name) {
                                applyBatch(.addTags([tag.id]))
                            }
                        }
                    }
                }
                if projects.isEmpty == false {
                    Section("Move to project") {
                        ForEach(projects, id: \.id) { project in
                            Menu(project.name) {
                                Button("No section") {
                                    applyBatch(
                                        .move(
                                            projectID: project.id,
                                            projectName: project.name,
                                            sectionID: nil
                                        )
                                    )
                                }
                                ForEach(
                                    sectionsByProjectID[project.id] ?? [],
                                    id: \.id
                                ) { section in
                                    Button(section.name) {
                                        applyBatch(
                                            .move(
                                                projectID: project.id,
                                                projectName: project.name,
                                                sectionID: section.id
                                            )
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                if tags.isEmpty && projects.isEmpty {
                    Text("No tags or projects available")
                }
            } label: {
                Label("Organize", systemImage: "tray.full")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isApplyingBatch)
            .accessibilityIdentifier("plan.taskLibrary.batch.organize")

            Button {
                applyBatch(.setCompletion(scope != .completed))
            } label: {
                Label(
                    scope == .completed ? "Reopen" : "Complete",
                    systemImage: scope == .completed
                        ? "arrow.uturn.backward.circle"
                        : "checkmark.circle"
                )
                .frame(minWidth: 44, minHeight: 44)
            }
            .disabled(isApplyingBatch)
            .accessibilityIdentifier("plan.taskLibrary.batch.complete")

            Menu {
                Button("Archive", role: .destructive) {
                    destructiveMutation = .archive
                }
                Button("Delete", role: .destructive) {
                    destructiveMutation = .delete
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 44, height: 44)
            }
            .disabled(isApplyingBatch)
            .accessibilityLabel("More batch actions")
            .accessibilityIdentifier("plan.taskLibrary.batch.more")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func planningDay(daysFromToday offset: Int) -> PlanningDay {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return PlanningDay(date: date)
    }
}
