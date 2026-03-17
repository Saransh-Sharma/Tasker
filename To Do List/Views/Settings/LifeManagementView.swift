import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct LifeManagementView: View {
    @StateObject private var viewModel: LifeManagementViewModel
    @State private var iconSearchQuery = ""
    @State private var expandedCreateSection: CreateSection? = nil

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    /// Initializes a new instance.
    init(viewModel: LifeManagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private enum CreateSection {
        case lifeArea
        case project
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.s12) {
                helperHeaderCard

                if let errorMessage = viewModel.errorMessage {
                    errorCard(message: errorMessage)
                }

                createSection
                groupedBoardSection
                archivedBoardSection
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
                    .background(
                        Color.tasker.surfacePrimary,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.isMutating {
                HStack(spacing: spacing.s8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating life management...")
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
        .sheet(item: lifeAreaEditDraftBinding) { draft in
            LifeAreaEditSheet(
                draft: draft,
                isSaving: viewModel.isMutating,
                onSave: { name, colorHex in
                    viewModel.saveLifeAreaEdit(name: name, colorHex: colorHex)
                },
                onCancel: {
                    viewModel.dismissLifeAreaEdit()
                }
            )
        }
        .sheet(item: projectEditDraftBinding) { draft in
            ProjectEditSheet(
                draft: draft,
                isSaving: viewModel.isMutating,
                onSave: { name, description in
                    viewModel.saveProjectEdit(name: name, description: description)
                },
                onCancel: {
                    viewModel.dismissProjectEdit()
                }
            )
        }
        .sheet(item: iconPickerContextBinding) { context in
            LifeAreaIconPickerSheet(
                context: context,
                options: viewModel.filteredIconOptions(query: iconSearchQuery),
                isSaving: viewModel.isMutating,
                searchQuery: $iconSearchQuery,
                onSelect: { symbol in
                    viewModel.applyIconSelection(symbol)
                },
                onCancel: {
                    viewModel.dismissIconPicker()
                }
            )
            .onAppear {
                iconSearchQuery = ""
            }
        }
        .alert(item: lifeAreaArchivePreviewBinding) { preview in
            Alert(
                title: Text("Archive \(preview.lifeAreaName)?"),
                message: Text("\(preview.projectCount) projects and \(preview.taskCount) tasks are in this life area."),
                primaryButton: .destructive(Text("Archive")) {
                    viewModel.confirmLifeAreaArchive()
                },
                secondaryButton: .cancel {
                    viewModel.cancelLifeAreaArchive()
                }
            )
        }
        .alert(item: projectArchivePreviewBinding) { preview in
            Alert(
                title: Text("Archive \(preview.projectName)?"),
                message: Text("\(preview.taskCount) tasks are in this project."),
                primaryButton: .destructive(Text("Archive")) {
                    viewModel.confirmProjectArchive()
                },
                secondaryButton: .cancel {
                    viewModel.cancelProjectArchive()
                }
            )
        }
        .animation(accessibilityReduceMotion ? nil : TaskerAnimation.snappy, value: viewModel.activeDropLifeAreaID)
        .animation(accessibilityReduceMotion ? nil : TaskerAnimation.gentle, value: viewModel.sections)
    }

    private var lifeAreaEditDraftBinding: Binding<LifeAreaEditDraft?> {
        Binding(
            get: { viewModel.lifeAreaEditDraft },
            set: { nextValue in
                if nextValue == nil {
                    viewModel.dismissLifeAreaEdit()
                }
            }
        )
    }

    private var projectEditDraftBinding: Binding<ProjectEditDraft?> {
        Binding(
            get: { viewModel.projectEditDraft },
            set: { nextValue in
                if nextValue == nil {
                    viewModel.dismissProjectEdit()
                }
            }
        )
    }

    private var iconPickerContextBinding: Binding<LifeAreaIconPickerContext?> {
        Binding(
            get: { viewModel.iconPickerContext },
            set: { nextValue in
                if nextValue == nil {
                    viewModel.dismissIconPicker()
                }
            }
        )
    }

    private var lifeAreaArchivePreviewBinding: Binding<LifeAreaArchivePreview?> {
        Binding(
            get: { viewModel.lifeAreaArchivePreview },
            set: { nextValue in
                if nextValue == nil {
                    viewModel.cancelLifeAreaArchive()
                }
            }
        )
    }

    private var projectArchivePreviewBinding: Binding<ProjectArchivePreview?> {
        Binding(
            get: { viewModel.projectArchivePreview },
            set: { nextValue in
                if nextValue == nil {
                    viewModel.cancelProjectArchive()
                }
            }
        )
    }

    private var helperHeaderCard: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text("Organize life areas and projects")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                Text("Create areas and projects, then move projects between areas as your system evolves.")
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

    private var createSection: some View {
        TaskerCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Create")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                VStack(alignment: .leading, spacing: spacing.s12) {
                    createLifeAreaCard
                    createProjectCard
                }
            }
        }
        .enhancedStaggeredAppearance(index: 2)
    }

    private var createLifeAreaCard: some View {
        createPanelCard(
            title: "New Life Area",
            subtitle: "Create a top-level area like Health, Career, or Home.",
            isExpanded: expandedCreateSection == .lifeArea,
            onToggle: {
                expandedCreateSection = expandedCreateSection == .lifeArea ? nil : .lifeArea
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(spacing: spacing.s8) {
                    TextField("Name (e.g., Learning)", text: $viewModel.draftLifeAreaName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.createLifeAreaFromDraft()
                        }
                        .disabled(viewModel.isCreatingLifeArea || viewModel.isLoading)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("settings.lifeManagement.create.lifeArea.name")

                    Button {
                        viewModel.createLifeAreaFromDraft()
                    } label: {
                        if viewModel.isCreatingLifeArea {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 44, height: 44)
                        } else {
                            Text("Create Life Area")
                                .font(.tasker(.buttonSmall))
                                .frame(minWidth: 132, minHeight: 44)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        viewModel.isCreatingLifeArea ||
                        viewModel.isLoading ||
                        viewModel.draftLifeAreaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                    .accessibilityIdentifier("settings.lifeManagement.create.lifeArea.submit")
                }

                if viewModel.visibleSuggestions.isEmpty == false {
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
                                    .font(.tasker(.caption1))
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
        }
    }

    private var createProjectCard: some View {
        createPanelCard(
            title: "New Project",
            subtitle: "Create a project and place it in a life area.",
            isExpanded: expandedCreateSection == .project,
            onToggle: {
                expandedCreateSection = expandedCreateSection == .project ? nil : .project
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                TextField("Project name", text: $viewModel.draftProjectName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .disabled(viewModel.isCreatingProject || viewModel.isLoading)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("settings.lifeManagement.create.project.name")

                TextField("Description (optional)", text: $viewModel.draftProjectDescription, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                    .disabled(viewModel.isCreatingProject || viewModel.isLoading)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("settings.lifeManagement.create.project.description")

                Menu {
                    ForEach(viewModel.projectCreationLifeAreas, id: \.id) { area in
                        Button {
                            viewModel.draftProjectLifeAreaID = area.id
                        } label: {
                            Label(area.name, systemImage: area.icon ?? "square.grid.2x2")
                        }
                    }
                } label: {
                    HStack(spacing: spacing.s8) {
                        Image(systemName: "square.grid.2x2")
                            .foregroundColor(Color.tasker.textSecondary)
                        Text(viewModel.selectedDraftProjectLifeAreaName)
                            .font(.tasker(.callout))
                            .foregroundColor(Color.tasker.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: spacing.s8)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color.tasker.textQuaternary)
                    }
                    .padding(.horizontal, spacing.s12)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.tasker.surfaceSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                    )
                }
                .disabled(viewModel.projectCreationLifeAreas.isEmpty || viewModel.isCreatingProject || viewModel.isLoading)
                .accessibilityIdentifier("settings.lifeManagement.create.project.lifeArea")

                Button {
                    viewModel.createProjectFromDraft()
                } label: {
                    HStack(spacing: spacing.s8) {
                        if viewModel.isCreatingProject {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "plus.circle.fill")
                        }
                        Text("Create Project")
                            .font(.tasker(.bodyEmphasis))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    viewModel.isCreatingProject ||
                    viewModel.isLoading ||
                    viewModel.draftProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    viewModel.draftProjectLifeAreaID == nil
                )
                .accessibilityIdentifier("settings.lifeManagement.create.project.submit")
            }
        }
    }

    private func createPanelCard<Content: View>(
        title: String,
        subtitle: String,
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Button(action: onToggle) {
                HStack(spacing: spacing.s8) {
                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text(title)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundColor(Color.tasker.textPrimary)
                        Text(subtitle)
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: spacing.s8)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.tasker.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
        .padding(spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.tasker.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.tasker.strokeHairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var groupedBoardSection: some View {
        if !viewModel.isLoading && viewModel.sections.isEmpty {
            ContentUnavailableView(
                "No Active Life Areas",
                systemImage: "square.grid.2x2",
                description: Text("Create a life area and project above to start organizing.")
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, spacing.s24)
            .enhancedStaggeredAppearance(index: 3)
        } else {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Active life areas")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                ForEach(Array(viewModel.sections.enumerated()), id: \.element.id) { index, section in
                    lifeAreaCard(section: section, isArchivedSection: false)
                        .enhancedStaggeredAppearance(index: index + 4)
                }
            }
        }
    }

    @ViewBuilder
    private var archivedBoardSection: some View {
        if viewModel.hasArchivedContent {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Archived")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                if viewModel.archivedLifeAreaSections.isEmpty == false {
                    TaskerCard {
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            archivedToggleHeader(
                                title: "Archived Life Areas",
                                count: viewModel.archivedLifeAreaSections.count,
                                isExpanded: viewModel.isArchivedLifeAreasExpanded
                            ) {
                                viewModel.isArchivedLifeAreasExpanded.toggle()
                            }

                            if viewModel.isArchivedLifeAreasExpanded {
                                VStack(spacing: spacing.s8) {
                                    ForEach(viewModel.archivedLifeAreaSections) { section in
                                        lifeAreaCard(section: section, isArchivedSection: true)
                                    }
                                }
                                .padding(.top, spacing.s4)
                            }
                        }
                    }
                }

                if viewModel.archivedProjectGroups.isEmpty == false {
                    TaskerCard {
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            archivedToggleHeader(
                                title: "Archived Projects",
                                count: viewModel.archivedProjectGroups.reduce(0) { $0 + $1.projects.count },
                                isExpanded: viewModel.isArchivedProjectsExpanded
                            ) {
                                viewModel.isArchivedProjectsExpanded.toggle()
                            }

                            if viewModel.isArchivedProjectsExpanded {
                                VStack(alignment: .leading, spacing: spacing.s8) {
                                    ForEach(viewModel.archivedProjectGroups) { group in
                                        archivedProjectGroup(group)
                                    }
                                }
                                .padding(.top, spacing.s4)
                            }
                        }
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 90)
        }
    }

    private func archivedToggleHeader(
        title: String,
        count: Int,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: spacing.s8) {
                Text(title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
                Text("\(count)")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
                    .padding(.horizontal, spacing.s8)
                    .frame(minHeight: 24)
                    .background(Color.tasker.surfaceSecondary, in: Capsule())
                Spacer(minLength: spacing.s8)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    private func archivedProjectGroup(_ group: LifeManagementArchivedProjectGroup) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                Image(systemName: group.lifeArea.icon ?? "square.grid.2x2")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.tasker.accentPrimary)
                Text(group.lifeArea.name)
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundColor(Color.tasker.textSecondary)
                Spacer(minLength: spacing.s8)
            }
            .frame(minHeight: 32)

            VStack(spacing: 0) {
                ForEach(Array(group.projects.enumerated()), id: \.element.id) { index, row in
                    draggableProjectRow(row: row, isArchivedContext: true)
                    if index < group.projects.count - 1 {
                        Divider().background(Color.tasker.strokeHairline)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary)
            )
        }
    }

    private func lifeAreaCard(section: LifeManagementLifeAreaSection, isArchivedSection: Bool) -> some View {
        let isDropTarget = !isArchivedSection && viewModel.activeDropLifeAreaID == section.lifeArea.id
        let isGeneralArea = viewModel.isGeneralLifeArea(section.lifeArea.id)

        return TaskerCard(active: isDropTarget, elevated: isDropTarget) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    ZStack {
                        Circle()
                            .fill(lifeAreaAccentColor(section.lifeArea).opacity(0.2))
                            .frame(width: 34, height: 34)
                        Image(systemName: section.lifeArea.icon ?? "square.grid.2x2")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(lifeAreaAccentColor(section.lifeArea))
                    }
                    .frame(minWidth: 44, minHeight: 44)

                    VStack(alignment: .leading, spacing: spacing.s2) {
                        HStack(spacing: spacing.s8) {
                            Text(section.lifeArea.name)
                                .font(.tasker(.headline))
                                .foregroundColor(Color.tasker.textPrimary)
                            if isGeneralArea {
                                Text("Pinned")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                                    .padding(.horizontal, spacing.s8)
                                    .frame(minHeight: 24)
                                    .background(Color.tasker.surfaceSecondary, in: Capsule())
                            }
                            if isArchivedSection {
                                Text("Archived")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                            }
                        }

                        Text("\(section.projectCount) projects • \(section.taskCount) tasks")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)

                        if isDropTarget {
                            Label("Drop here to move project", systemImage: "arrow.down.circle.fill")
                                .font(.tasker(.caption1))
                                .foregroundColor(Color.tasker.accentPrimary)
                        }
                    }

                    Spacer(minLength: spacing.s8)

                    lifeAreaActionMenu(lifeArea: section.lifeArea, isArchivedSection: isArchivedSection, isGeneralArea: isGeneralArea)
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
                            draggableProjectRow(row: row, isArchivedContext: isArchivedSection)
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
            of: isArchivedSection ? [] : [UTType.text.identifier],
            delegate: LifeAreaProjectDropDelegate(
                targetLifeAreaID: section.lifeArea.id,
                viewModel: viewModel,
                acceptsDrop: !isArchivedSection
            )
        )
        .accessibilityIdentifier("settings.lifeManagement.lifeArea.\(section.lifeArea.id.uuidString)")
    }

    private func lifeAreaActionMenu(
        lifeArea: LifeArea,
        isArchivedSection: Bool,
        isGeneralArea: Bool
    ) -> some View {
        Menu {
            Button("Edit Details", systemImage: "pencil") {
                viewModel.beginEditLifeArea(lifeArea.id)
            }

            Button("Change Icon", systemImage: "square.grid.2x2") {
                viewModel.showIconPicker(for: lifeArea.id)
            }

            if isArchivedSection {
                Button("Unarchive", systemImage: "arrow.uturn.backward") {
                    viewModel.unarchiveLifeArea(lifeArea.id)
                }
            } else {
                Button("Archive", systemImage: "archivebox") {
                    viewModel.requestArchiveLifeArea(lifeArea.id)
                }
                .disabled(isGeneralArea)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.tasker.textSecondary)
                .frame(width: 44, height: 44)
        }
        .accessibilityIdentifier("settings.lifeManagement.lifeArea.menu.\(lifeArea.id.uuidString)")
    }

    @ViewBuilder
    private func draggableProjectRow(row: LifeManagementProjectRow, isArchivedContext: Bool) -> some View {
        let rowContent = projectRowContent(row: row, isArchivedContext: isArchivedContext)
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .contentShape(Rectangle())
            .contextMenu {
                projectRowMenuActions(row: row)
            }
            .onTapGesture {
                guard row.isMoveLocked == false else { return }
                viewModel.beginEditProject(row.project.id)
            }

        if isArchivedContext || row.isMoveLocked || row.project.isArchived {
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

    private func projectRowContent(row: LifeManagementProjectRow, isArchivedContext: Bool) -> some View {
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
                        .lineLimit(1)
                }

                HStack(spacing: spacing.s8) {
                    Text("\(row.taskCount) tasks")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textTertiary)
                    if row.isMoveLocked {
                        Text("Pinned to General")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)
                    } else if isArchivedContext || row.project.isArchived {
                        Text("Archived")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)
                    }
                }
            }

            Spacer(minLength: spacing.s8)
        }
        .frame(minHeight: 44, alignment: .leading)
    }

    @ViewBuilder
    private func projectRowMenuActions(row: LifeManagementProjectRow) -> some View {
        Button("Edit Project", systemImage: "pencil") {
            viewModel.beginEditProject(row.project.id)
        }
        .disabled(row.isMoveLocked)

        if row.project.isArchived {
            Button("Unarchive", systemImage: "arrow.uturn.backward") {
                viewModel.unarchiveProject(row.project.id)
            }
            .disabled(row.isMoveLocked)
        } else {
            Button("Archive", systemImage: "archivebox") {
                viewModel.requestArchiveProject(row.project.id)
            }
            .disabled(row.isMoveLocked)
        }
    }

    private func lifeAreaAccentColor(_ lifeArea: LifeArea) -> Color {
        guard let colorHex = lifeArea.color?.trimmingCharacters(in: .whitespacesAndNewlines),
              colorHex.isEmpty == false else {
            return Color.tasker.accentPrimary
        }
        return Color(uiColor: UIColor(taskerHex: colorHex))
    }
}

private struct LifeAreaProjectDropDelegate: DropDelegate {
    let targetLifeAreaID: UUID
    let viewModel: LifeManagementViewModel
    let acceptsDrop: Bool

    func validateDrop(info: DropInfo) -> Bool {
        lifeAreaProjectDropIsValid(
            acceptsDrop: acceptsDrop,
            canDropProject: viewModel.canDropProject(on: targetLifeAreaID),
            hasTextItem: info.hasItemsConforming(to: [UTType.text.identifier])
        )
    }

    func dropEntered(info: DropInfo) {
        guard acceptsDrop else { return }
        viewModel.dropEntered(targetLifeAreaID: targetLifeAreaID)
    }

    func dropExited(info: DropInfo) {
        guard acceptsDrop else { return }
        viewModel.clearDropTarget(targetLifeAreaID)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard acceptsDrop else { return DropProposal(operation: .forbidden) }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard acceptsDrop else { return false }
        let providers = info.itemProviders(for: [UTType.text.identifier])
        let handled = viewModel.performDrop(providers: providers, targetLifeAreaID: targetLifeAreaID)
        viewModel.clearDropTarget(targetLifeAreaID)
        return handled
    }
}

func lifeAreaProjectDropIsValid(
    acceptsDrop: Bool,
    canDropProject: Bool,
    hasTextItem: Bool
) -> Bool {
    guard acceptsDrop else { return false }
    guard canDropProject else { return false }
    return hasTextItem
}

private struct LifeAreaEditSheet: View {
    let draft: LifeAreaEditDraft
    let isSaving: Bool
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var colorHex: String

    init(
        draft: LifeAreaEditDraft,
        isSaving: Bool,
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.draft = draft
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: draft.name)
        _colorHex = State(initialValue: draft.colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Life Area Details") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                    TextField("Color hex (optional)", text: $colorHex)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Edit Life Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(name, colorHex)
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ProjectEditSheet: View {
    let draft: ProjectEditDraft
    let isSaving: Bool
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var description: String

    init(
        draft: ProjectEditDraft,
        isSaving: Bool,
        onSave: @escaping (String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.draft = draft
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: draft.name)
        _description = State(initialValue: draft.description)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(name, description)
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct LifeAreaIconPickerSheet: View {
    let context: LifeAreaIconPickerContext
    let options: [LifeAreaIconOption]
    let isSaving: Bool
    @Binding var searchQuery: String
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 68), spacing: 10, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Choose an icon for \(context.lifeAreaName)")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)

                TextField("Search symbols", text: $searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .accessibilityIdentifier("settings.lifeManagement.iconPicker.search")

                if let currentIcon = context.currentIcon,
                   options.contains(where: { $0.symbolName == currentIcon }) == false {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current icon")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textSecondary)
                        iconButton(symbol: currentIcon, isSelected: false)
                    }
                }

                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(options, id: \.symbolName) { option in
                            iconButton(
                                symbol: option.symbolName,
                                isSelected: option.symbolName == context.currentIcon
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(16)
            .navigationTitle("Change Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onCancel)
                }
            }
        }
    }

    private func iconButton(symbol: String, isSelected: Bool) -> some View {
        Button {
            guard isSaving == false else { return }
            onSelect(symbol)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? Color.tasker.accentPrimary : Color.tasker.textPrimary)
                Text(symbol)
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .frame(minHeight: 68)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isSelected ? Color.tasker.accentRing : Color.tasker.strokeHairline,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .frame(minHeight: 44)
        .accessibilityIdentifier("settings.lifeManagement.iconPicker.symbol.\(symbol)")
    }
}
