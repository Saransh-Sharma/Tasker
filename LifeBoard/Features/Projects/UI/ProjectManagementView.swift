import SwiftUI

struct ProjectManagementView: View {
    /// Initializes a new instance.
    @StateObject private var viewModel: ProjectManagementViewModel
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @State private var showingCreateSheet = false
    @State private var showingReflectionComposer = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""
    @State private var selectedProjectID: UUID?
    /// The project waiting on the delete confirmation. Deleting moves its tasks
    /// to Inbox and cannot be undone, so it always asks first.
    @State private var projectPendingDeletion: ProjectWithStats?
    @FocusState private var projectNameFocused: Bool

    private var supportsIPadSplit: Bool {
        layoutClass.isPad
    }

    private var selectedProjectEntry: ProjectWithStats? {
        guard let selectedProjectID else { return nil }
        return viewModel.filteredProjects.first(where: { $0.project.id == selectedProjectID })
    }

    init(viewModel: ProjectManagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if supportsIPadSplit {
                NavigationSplitView {
                    projectList(selection: $selectedProjectID)
                        .navigationTitle("Projects")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                createButton
                            }
                        }
                } detail: {
                    projectDetailPanel
                }
                .navigationSplitViewStyle(.balanced)
                .onChange(of: selectedProjectID) { _, newValue in
                    guard let newValue else { return }
                    if let selected = viewModel.filteredProjects.first(where: { $0.project.id == newValue }) {
                        viewModel.selectProject(selected)
                    }
                }
            } else {
                projectList(selection: .constant(nil))
                    .navigationTitle("Projects")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            createButton
                        }
                    }
                    .overlay {
                        if viewModel.filteredProjects.filter({ $0.project.id != ProjectConstants.inboxProjectID }).isEmpty {
                            StatusSurface(
                                state: .empty,
                                title: "No projects yet",
                                message: ""
                            )
                        }
                    }
            }
        }
        .accessibilityIdentifier("projectManagement.view")
        .confirmationDialog(
            projectPendingDeletion.map { "Delete \u{201C}\($0.project.name)\u{201D}?" } ?? "Delete project?",
            isPresented: Binding(
                get: { projectPendingDeletion != nil },
                set: { if $0 == false { projectPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete project", role: .destructive) {
                guard let entry = projectPendingDeletion else { return }
                projectPendingDeletion = nil
                if selectedProjectID == entry.project.id { selectedProjectID = nil }
                viewModel.deleteProject(entry, strategy: .moveToInbox)
            }
            Button("Cancel", role: .cancel) { projectPendingDeletion = nil }
        } message: {
            Text(deletionMessage(for: projectPendingDeletion))
        }
        .alert("Couldn\u{2019}t save project.", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingCreateSheet, onDismiss: resetDraft) {
            projectCreateSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingReflectionComposer) {
            if let selectedProject = selectedProjectEntry?.project {
                ReflectionNoteComposerView(
                    viewModel: ReflectionNoteComposerViewModel(
                        title: String(localized: "Project note"),
                        kind: .projectReflection,
                        linkedProjectID: selectedProject.id,
                        prompt: String(localized: "What matters this week?"),
                        saveNoteHandler: { note, completion in
                            viewModel.saveReflectionNote(note, completion: completion)
                        }
                    )
                )
            }
        }
        .task {
            viewModel.loadProjects()
            if supportsIPadSplit {
                autoSelectFirstProjectIfNeeded()
            }
        }
        .onChange(of: viewModel.filteredProjects.map(\.project.id)) { _, _ in
            guard supportsIPadSplit else { return }
            autoSelectFirstProjectIfNeeded()
        }
    }

    @ViewBuilder
    private func projectList(selection: Binding<UUID?>) -> some View {
        List(selection: selection) {
            ForEach(viewModel.filteredProjects, id: \.project.id) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.project.name)
                            .font(.headline)
                        if entry.project.motivationWhy?.isEmpty == false
                            || entry.project.motivationSuccessLooksLike?.isEmpty == false
                            || entry.project.motivationCostOfNeglect?.isEmpty == false {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(Color.lifeboard.accentPrimary)
                        }
                    }
                    if let description = entry.project.projectDescription, description.isEmpty == false {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                    HStack(spacing: 8) {
                        Text(entry.taskCount == 1 ? "1 task" : "\(entry.taskCount) tasks")
                            .font(.caption)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                        if entry.project.isArchived {
                            Text("Archived")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.lifeboard.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.lifeboard.surfaceSecondary, in: Capsule())
                        }
                    }
                }
                .tag(entry.project.id).lifeBoardScrollEntrance(intensity: 0.55)
                .contextMenu {
                    if entry.project.id != ProjectConstants.inboxProjectID {
                        Button("Delete project\u{2026}", systemImage: "trash", role: .destructive) {
                            projectPendingDeletion = entry
                        }
                    }
                }
            }
            .onDelete(perform: deleteProjects)
        }
        .accessibilityIdentifier("projectManagement.projectsList")
    }

    @ViewBuilder
    private var projectDetailPanel: some View {
        if let selected = selectedProjectEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selected.project.name)
                            .font(.title2.weight(.semibold))

                        if let description = selected.project.projectDescription, description.isEmpty == false {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                        }
                    }

                    if let saveMessage = viewModel.saveMessage {
                        Text(saveMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.lifeboard.accentPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.lifeboard.surfaceSecondary, in: Capsule())
                    }

                    HStack(spacing: 12) {
                        projectMetricCard(
                            title: "Open",
                            value: "\(max(0, selected.taskCount - selected.completedTaskCount))"
                        )
                        projectMetricCard(
                            title: "Done",
                            value: "\(selected.completedTaskCount)"
                        )
                        projectMetricCard(
                            title: "Total",
                            value: "\(selected.taskCount)"
                        )
                    }

                    weeklyContributionSection
                    motivationSection(for: selected.project)
                    projectTasksSection
                    recentReflectionSection

                    if selected.project.id == ProjectConstants.inboxProjectID {
                        Text("Inbox can\u{2019}t be deleted.")
                            .font(.footnote)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    } else {
                        Button("Delete project\u{2026}", systemImage: "trash", role: .destructive) {
                            projectPendingDeletion = selected
                        }
                        .buttonStyle(.lifeBoardChip)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("projectManagement.delete")
                    }
                }
                .lifeboardReadableContent(maxWidth: 860, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(Color.lifeboard(.bgCanvas))
            .navigationTitle(selected.project.name)
        } else {
            StatusSurface(
                state: .empty,
                title: "No project selected",
                message: ""
            )
        }
    }

    private var createButton: some View {
        Button {
            showingCreateSheet = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityIdentifier("projectManagement.addProjectButton")
        .accessibilityLabel("Add project")
    }

    private var projectCreateSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New project")
                            .font(.lifeboard(.screenTitle))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        Text("Group related tasks.")
                            .font(.lifeboard(.body))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.lifeboard(.headline))
                            .foregroundStyle(Color.lifeboard.textPrimary)

                        TextField("Project name", text: $newProjectName, prompt: Text("Project name").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                            .textFieldStyle(TokenTextFieldStyle())
                            .focused($projectNameFocused)
                            .submitLabel(.done)
                            .onSubmit(createProjectFromDraft)

                        TextField("Description", text: $newProjectDescription, prompt: Text("Description").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(TokenTextFieldStyle())
                    }
                    .padding(16)
                    .lifeboardChromeSurface(
                        cornerRadius: Theme.CornerRadius.card,
                        accentColor: Color.lifeboard.accentSecondary,
                        level: .e2
                    )
                }
                .padding(16)
            }
            .background(Color.lifeboard.bgCanvas.ignoresSafeArea())
            .navigationTitle("New project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingCreateSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: createProjectFromDraft)
                        .disabled(canCreateProject == false)
                }
            }
        }
        .task {
            projectNameFocused = true
        }
    }

    private func projectMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Text(value)
                .font(.headline)
                .foregroundColor(.lifeboard(.textPrimary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.lifeboard(.surfaceSecondary), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
    }

    private func autoSelectFirstProjectIfNeeded() {
        guard selectedProjectID == nil else { return }
        guard let firstProject = viewModel.filteredProjects.first else { return }
        selectedProjectID = firstProject.project.id
        viewModel.selectProject(firstProject)
    }
}

extension ProjectManagementView {
    private var weeklyContributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This week")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                projectMetricCard(title: "Planned", value: "\(viewModel.weeklyContributionStats.thisWeekCount)")
                projectMetricCard(title: "Done", value: "\(viewModel.weeklyContributionStats.completedThisWeekCount)")
                projectMetricCard(title: "Linked to goals", value: "\(viewModel.weeklyContributionStats.linkedOutcomeCount)")
                projectMetricCard(title: "From earlier", value: "\(viewModel.weeklyContributionStats.carryPressureCount)")
            }

            HStack(spacing: 12) {
                quickActionButton(
                    title: viewModel.hasSelectedTasks ? String(localized: "Add to this week") : String(localized: "All to this week"),
                    systemImage: "calendar.badge.plus",
                    tint: Color.lifeboard.accentPrimary
                ) {
                    viewModel.applyQuickAction(bucket: .thisWeek)
                }

                quickActionButton(
                    title: viewModel.hasSelectedTasks ? String(localized: "Move to next week") : String(localized: "All to next week"),
                    systemImage: "arrow.right.circle",
                    tint: Color.lifeboard.statusWarning
                ) {
                    viewModel.applyQuickAction(bucket: .nextWeek)
                }
            }
            .disabled(viewModel.isUpdatingTaskBuckets)
        }
    }

    private func motivationSection(for project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Motivation")
                    .font(.headline)
                Spacer()
                Button(viewModel.isSavingMotivation ? "Saving…" : "Save") {
                    viewModel.saveMotivation()
                }
                .disabled(viewModel.isSavingMotivation)
            }

            motivationEditor(
                title: String(localized: "Why now"),
                text: $viewModel.motivationWhyDraft,
                prompt: project.isInbox ? String(localized: "Not used for Inbox") : String(localized: "Reason")
            )

            motivationEditor(
                title: String(localized: "Done looks like"),
                text: $viewModel.motivationSuccessLooksLikeDraft,
                prompt: String(localized: "Result")
            )

            motivationEditor(
                title: String(localized: "If it slips"),
                text: $viewModel.motivationCostOfNeglectDraft,
                prompt: String(localized: "Why it matters")
            )
        }
        .opacity(project.isInbox ? 0.55 : 1)
        .disabled(project.isInbox)
    }

    private var projectTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Tasks")
                    .font(.headline)
                Spacer()
                if viewModel.hasSelectedTasks {
                    Button("Clear selection") {
                        viewModel.clearSelection()
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            if viewModel.selectedProjectTasks.isEmpty {
                Text(WeeklyCopy.noProjectTasks)
                    .font(.footnote)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.selectedProjectTasks, id: \.id) { task in
                        Button {
                            viewModel.toggleTaskSelection(task.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: viewModel.selectedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.selectedTaskIDs.contains(task.id) ? Color.lifeboard.accentPrimary : Color.lifeboard.textTertiary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.callout)
                                        .foregroundStyle(Color.lifeboard.textPrimary)
                                        .strikethrough(task.isComplete, color: Color.lifeboard.textTertiary)
                                    HStack(spacing: 8) {
                                        planningBucketChip(task.planningBucket)
                                        if task.weeklyOutcomeID != nil {
                                            statusChip(WeeklyCopy.weeklyOutcomeLabel, tint: Color.lifeboard.statusSuccess)
                                        }
                                        if task.isComplete {
                                            statusChip("Done", tint: Color.lifeboard.textSecondary)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recentReflectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                Spacer()
                Button(WeeklyCopy.addReflection) {
                    showingReflectionComposer = true
                }
                .font(.caption.weight(.semibold))
            }

            if viewModel.recentReflectionNotes.isEmpty {
                Text(WeeklyCopy.noWeeklyNotes)
                    .font(.footnote)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            } else {
                ForEach(viewModel.recentReflectionNotes.prefix(4), id: \.id) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        if let prompt = note.prompt, prompt.isEmpty == false {
                            Text(prompt)
                                .font(.caption)
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                        }
                        Text(note.noteText)
                            .font(.callout)
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        Text(DateUtils.formatDateTime(note.createdAt))
                            .font(.caption2)
                            .foregroundStyle(Color.lifeboard.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func motivationEditor(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.plain)
                // Clay well, not the system rounded border: that drew a pure white
                // box on warm paper and a pure black one in dark appearance.
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
        }
    }

    /// Swipe to delete asks first, like the visible Delete button: the
    /// project's tasks move to Inbox and the delete cannot be undone.
    private func deleteProjects(at offsets: IndexSet) {
        guard let index = offsets.first,
              viewModel.filteredProjects.indices.contains(index) else { return }
        let entry = viewModel.filteredProjects[index]
        guard entry.project.id != ProjectConstants.inboxProjectID else { return }
        projectPendingDeletion = entry
    }

    private func deletionMessage(for entry: ProjectWithStats?) -> String {
        guard let entry else { return "" }
        switch entry.taskCount {
        case 0: return String(localized: "This can\u{2019}t be undone.")
        case 1: return String(localized: "Its task moves to Inbox. This can\u{2019}t be undone.")
        default: return String(localized: "Its \(entry.taskCount) tasks move to Inbox. This can\u{2019}t be undone.")
        }
    }

    private var canCreateProject: Bool {
        newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func createProjectFromDraft() {
        let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else { return }
        viewModel.createProject(name: trimmedName, description: normalizedDescription())
        showingCreateSheet = false
        resetDraft()
    }

    /// Executes normalizedDescription.
    private func normalizedDescription() -> String? {
        let trimmed = newProjectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Executes resetDraft.
    private func resetDraft() {
        newProjectName = ""
        newProjectDescription = ""
    }
}

struct ProjectManagementView_Previews: PreviewProvider {
    static var previews: some View {
        Text("SunriseProjectManagementView preview requires an injected ProjectManagementViewModel.")
    }
}
