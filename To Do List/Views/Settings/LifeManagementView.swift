import SwiftUI
import UniformTypeIdentifiers

struct LifeManagementView: View {
    @StateObject private var viewModel: LifeManagementViewModel

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    /// Initializes a new instance.
    init(viewModel: LifeManagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.s12) {
                helperHeaderCard

                if let errorMessage = viewModel.errorMessage {
                    errorCard(message: errorMessage)
                }

                if !viewModel.visibleSuggestions.isEmpty {
                    suggestionSection
                }

                quickCreateSection
                groupedBoardSection
            }
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.top, spacing.s16)
            .padding(.bottom, spacing.sectionGap)
        }
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("Life Management")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.lifeManagement.view")
        .overlay {
            if viewModel.isLoading && viewModel.sections.isEmpty {
                ProgressView("Loading life areas...")
                    .font(.tasker(.body))
                    .padding(.horizontal, spacing.s16)
                    .padding(.vertical, spacing.s12)
                    .background(Color.tasker.surfacePrimary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.isMutating {
                HStack(spacing: spacing.s8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Moving project...")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                }
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s8)
                .background(Color.tasker.surfacePrimary, in: Capsule())
                .padding(.bottom, spacing.s8)
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .refreshable {
            viewModel.reload()
        }
        .animation(accessibilityReduceMotion ? nil : TaskerAnimation.snappy, value: viewModel.activeDropLifeAreaID)
    }

    private var helperHeaderCard: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text("LIFE MANAGEMENT")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
                    .tracking(0.5)

                Text("Organize projects by life area")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                Text("Drag projects between life areas to remap all tasks in that project.")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)
            }
        }
        .enhancedStaggeredAppearance(index: 0)
    }

    private func errorCard(message: String) -> some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(spacing: spacing.s8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(Color.tasker.statusWarning)
                    Text("Couldn’t complete the last action")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.textPrimary)
                }

                Text(message)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: spacing.s8) {
                    Button("Retry") {
                        viewModel.reload()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(minHeight: 44)

                    Button("Dismiss") {
                        viewModel.clearError()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .frame(minHeight: 44)
                }
            }
        }
        .enhancedStaggeredAppearance(index: 1)
    }

    private var suggestionSection: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("SUGGESTED LIFE AREAS")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
                    .tracking(0.5)

                Text("Start with these")
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing.s8) {
                        ForEach(viewModel.visibleSuggestions) { suggestion in
                            Button {
                                TaskerFeedback.selection()
                                viewModel.createSuggestedLifeArea(suggestion)
                            } label: {
                                HStack(spacing: spacing.s4) {
                                    Image(systemName: suggestion.icon)
                                    Text(suggestion.name)
                                }
                                .font(.tasker(.callout))
                                .foregroundColor(Color.tasker.textPrimary)
                                .padding(.horizontal, spacing.s12)
                                .frame(minHeight: 44)
                                .background(Color.tasker.surfaceSecondary, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.tasker.accentRing.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isCreatingLifeArea || viewModel.isLoading)
                            .accessibilityIdentifier("settings.lifeManagement.suggestion.\(suggestion.id)")
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .enhancedStaggeredAppearance(index: 2)
    }

    private var quickCreateSection: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("QUICK CREATE")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
                    .tracking(0.5)

                HStack(spacing: spacing.s8) {
                    TextField("Add life area (e.g., Learning)", text: $viewModel.draftLifeAreaName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.createLifeAreaFromDraft()
                        }
                        .disabled(viewModel.isCreatingLifeArea || viewModel.isLoading)
                        .frame(minHeight: 44)

                    Button {
                        viewModel.createLifeAreaFromDraft()
                    } label: {
                        if viewModel.isCreatingLifeArea {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 44, height: 44)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 44, height: 44)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        viewModel.isCreatingLifeArea ||
                        viewModel.isLoading ||
                        viewModel.draftLifeAreaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .accessibilityIdentifier("settings.lifeManagement.quickCreate")
                }
            }
        }
        .enhancedStaggeredAppearance(index: 3)
    }

    @ViewBuilder
    private var groupedBoardSection: some View {
        if !viewModel.isLoading && viewModel.sections.isEmpty {
            ContentUnavailableView(
                "No Life Areas Yet",
                systemImage: "square.grid.2x2",
                description: Text("Create your first life area to organize projects.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, spacing.s24)
            .enhancedStaggeredAppearance(index: 4)
        } else {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("LIFE AREAS")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
                    .tracking(0.5)

                ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                    lifeAreaCard(section: section)
                        .enhancedStaggeredAppearance(index: index + 5)
                }
            }
        }
    }

    private func lifeAreaCard(section: LifeManagementLifeAreaSection) -> some View {
        let isDropTarget = viewModel.activeDropLifeAreaID == section.lifeArea.id

        return TaskerCard(active: isDropTarget, elevated: isDropTarget) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    ZStack {
                        Circle()
                            .fill(Color.tasker.accentWash)
                            .frame(width: 34, height: 34)
                        Image(systemName: section.lifeArea.icon ?? "square.grid.2x2")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color.tasker.accentPrimary)
                    }
                    .frame(minWidth: 44, minHeight: 44)

                    VStack(alignment: .leading, spacing: spacing.s2) {
                        Text(section.lifeArea.name)
                            .font(.tasker(.headline))
                            .foregroundColor(Color.tasker.textPrimary)
                        Text("\(section.projectCount) projects • \(section.taskCount) tasks")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                    }

                    Spacer(minLength: spacing.s8)

                    if isDropTarget {
                        Label("Drop Here", systemImage: "arrow.down.circle.fill")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.accentPrimary)
                    }
                }

                if section.projects.isEmpty {
                    Text("No projects here yet.")
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, spacing.s8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(section.projects.enumerated()), id: \.element.id) { index, row in
                            draggableProjectRow(row: row)
                            if index < section.projects.count - 1 {
                                Divider()
                                    .background(Color.tasker.strokeHairline)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.tasker.surfaceSecondary)
                    )
                }
            }
        }
        .onDrop(
            of: [UTType.text.identifier],
            delegate: LifeAreaProjectDropDelegate(
                targetLifeAreaID: section.lifeArea.id,
                viewModel: viewModel
            )
        )
        .accessibilityIdentifier("settings.lifeManagement.lifeArea.\(section.lifeArea.id.uuidString)")
    }

    @ViewBuilder
    private func draggableProjectRow(row: LifeManagementProjectRow) -> some View {
        let rowContent = projectRowContent(row: row)
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)

        if row.isMoveLocked {
            rowContent
        } else {
            rowContent
                .onDrag {
                    TaskerFeedback.light()
                    viewModel.beginDrag(projectID: row.project.id)
                    return NSItemProvider(object: row.project.id.uuidString as NSString)
                }
        }
    }

    private func projectRowContent(row: LifeManagementProjectRow) -> some View {
        HStack(alignment: .top, spacing: spacing.s12) {
            Image(systemName: row.isMoveLocked ? "lock.fill" : "line.3.horizontal")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(row.isMoveLocked ? Color.tasker.textTertiary : Color.tasker.textSecondary)
                .frame(width: 16, height: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(row.project.name)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)

                if let description = row.project.projectDescription,
                   description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    Text(description)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .lineLimit(2)
                }

                HStack(spacing: spacing.s8) {
                    Text("\(row.taskCount) tasks")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)
                    if row.isMoveLocked {
                        Text("Pinned to General")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)
                    }
                }
            }

            Spacer(minLength: spacing.s8)

            if !row.isMoveLocked {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.tasker.textQuaternary)
                    .padding(.top, 2)
            }
        }
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }
}

private struct LifeAreaProjectDropDelegate: DropDelegate {
    let targetLifeAreaID: UUID
    let viewModel: LifeManagementViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.canDropProject(on: targetLifeAreaID) || info.hasItemsConforming(to: [UTType.text.identifier])
    }

    func dropEntered(info: DropInfo) {
        viewModel.dropEntered(targetLifeAreaID: targetLifeAreaID)
    }

    func dropExited(info: DropInfo) {
        viewModel.clearDropTarget(targetLifeAreaID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [UTType.text.identifier])
        let handled = viewModel.performDrop(providers: providers, targetLifeAreaID: targetLifeAreaID)
        viewModel.clearDropTarget(targetLifeAreaID)
        return handled
    }
}
