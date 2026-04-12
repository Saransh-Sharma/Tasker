import SwiftUI

struct ProjectManagementView: View {
    /// Initializes a new instance.
    @StateObject private var viewModel: ProjectManagementViewModel
    @Environment(\.taskerLayoutClass) private var layoutClass
    @State private var showingCreateDialog = false
    @State private var showingReflectionComposer = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""
    @State private var selectedProjectID: UUID?

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
                            ContentUnavailableView(
                                "No Custom Projects",
                                systemImage: "folder.badge.plus",
                                description: Text("Tap + to create your first custom project")
                            )
                        }
                    }
            }
        }
        .accessibilityIdentifier("projectManagement.view")
        .alert("New Project", isPresented: $showingCreateDialog) {
            TextField("Project Name", text: $newProjectName)
            TextField("Description (Optional)", text: $newProjectDescription)
            Button("Cancel", role: .cancel) {
                resetDraft()
            }
            Button("Create") {
                let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedName.isEmpty == false else { return }
                viewModel.createProject(name: trimmedName, description: normalizedDescription())
                resetDraft()
            }
        } message: {
            Text("Create a new project under your life areas.")
        }
        .alert("Project Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.clearError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .sheet(isPresented: $showingReflectionComposer) {
            if let selectedProject = selectedProjectEntry?.project {
                ReflectionNoteComposerView(
                    viewModel: ReflectionNoteComposerViewModel(
                        title: "Project Reflection",
                        kind: .projectReflection,
                        linkedProjectID: selectedProject.id,
                        prompt: "What matters most about this project this week?",
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
                                .foregroundStyle(Color.tasker.accentPrimary)
                        }
                    }
                    if let description = entry.project.projectDescription, description.isEmpty == false {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Text("\(entry.taskCount) tasks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if entry.project.isArchived {
                            Text("Archived")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.tasker.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.tasker.surfaceSecondary, in: Capsule())
                        }
                    }
                }
                .tag(entry.project.id)
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
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let saveMessage = viewModel.saveMessage {
                        Text(saveMessage)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.tasker.accentPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.tasker.surfaceSecondary, in: Capsule())
                    }

                    HStack(spacing: 12) {
                        projectMetricCard(
                            title: "Open",
                            value: "\(max(0, selected.taskCount - selected.completedTaskCount))"
                        )
                        projectMetricCard(
                            title: "Completed",
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
                        Text("Inbox is your capture project and cannot be deleted.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Swipe left on the project in the list to delete it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .taskerReadableContent(maxWidth: 860, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(Color.tasker(.bgCanvas))
            .navigationTitle(selected.project.name)
        } else {
            ContentUnavailableView(
                "Select a Project",
                systemImage: "folder",
                description: Text("Choose a project from the sidebar to inspect details.")
            )
        }
    }

    private var createButton: some View {
        Button {
            showingCreateDialog = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityIdentifier("projectManagement.addProjectButton")
        .accessibilityLabel("Add Project")
    }

    private func projectMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(.tasker(.textPrimary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.tasker(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func autoSelectFirstProjectIfNeeded() {
        guard selectedProjectID == nil else { return }
        guard let firstProject = viewModel.filteredProjects.first else { return }
        selectedProjectID = firstProject.project.id
        viewModel.selectProject(firstProject)
    }

    private var weeklyContributionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly contribution")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                projectMetricCard(title: "This week", value: "\(viewModel.weeklyContributionStats.thisWeekCount)")
                projectMetricCard(title: "Done this week", value: "\(viewModel.weeklyContributionStats.completedThisWeekCount)")
                projectMetricCard(title: "Outcome links", value: "\(viewModel.weeklyContributionStats.linkedOutcomeCount)")
                projectMetricCard(title: "Carry pressure", value: "\(viewModel.weeklyContributionStats.carryPressureCount)")
            }

            HStack(spacing: 10) {
                quickActionButton(
                    title: viewModel.hasSelectedTasks ? "Add selected to this week" : "Add open tasks to this week",
                    systemImage: "calendar.badge.plus",
                    tint: Color.tasker.accentPrimary
                ) {
                    viewModel.applyQuickAction(bucket: .thisWeek)
                }

                quickActionButton(
                    title: viewModel.hasSelectedTasks ? "Move selected to next week" : "Move open tasks to next week",
                    systemImage: "arrow.right.circle",
                    tint: Color.tasker.statusWarning
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
                Button(viewModel.isSavingMotivation ? "Saving..." : "Save") {
                    viewModel.saveMotivation()
                }
                .disabled(viewModel.isSavingMotivation)
            }

            motivationEditor(
                title: "Why this matters now",
                text: $viewModel.motivationWhyDraft,
                prompt: project.isInbox ? "Inbox does not use weekly motivation." : "Why does this project matter right now?"
            )

            motivationEditor(
                title: "What progress looks like",
                text: $viewModel.motivationSuccessLooksLikeDraft,
                prompt: "What would a meaningful weekly win look like?"
            )

            motivationEditor(
                title: "What slips if it waits",
                text: $viewModel.motivationCostOfNeglectDraft,
                prompt: "What pressure builds if this slips?"
            )
        }
        .opacity(project.isInbox ? 0.55 : 1)
        .disabled(project.isInbox)
    }

    private var projectTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly planning")
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
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.selectedProjectTasks, id: \.id) { task in
                        Button {
                            viewModel.toggleTaskSelection(task.id)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: viewModel.selectedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(viewModel.selectedTaskIDs.contains(task.id) ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.callout)
                                        .foregroundStyle(Color.tasker.textPrimary)
                                        .strikethrough(task.isComplete, color: Color.tasker.textTertiary)
                                    HStack(spacing: 8) {
                                        planningBucketChip(task.planningBucket)
                                        if task.weeklyOutcomeID != nil {
                                            statusChip(WeeklyCopy.weeklyOutcomeLabel, tint: Color.tasker.statusSuccess)
                                        }
                                        if task.isComplete {
                                            statusChip("Done", tint: Color.tasker.textSecondary)
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.tasker.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                Text("Project reflections")
                    .font(.headline)
                Spacer()
                Button(WeeklyCopy.addReflection) {
                    showingReflectionComposer = true
                }
                .font(.caption.weight(.semibold))
            }

            if viewModel.recentReflectionNotes.isEmpty {
                Text("Project reflections help the weekly review stay grounded in what actually happened.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.recentReflectionNotes.prefix(4), id: \.id) { note in
                    VStack(alignment: .leading, spacing: 4) {
                        if let prompt = note.prompt, prompt.isEmpty == false {
                            Text(prompt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(note.noteText)
                            .font(.callout)
                            .foregroundStyle(Color.tasker.textPrimary)
                        Text(DateUtils.formatDateTime(note.createdAt))
                            .font(.caption2)
                            .foregroundStyle(Color.tasker.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.tasker.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private func motivationEditor(title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.tasker.textSecondary)
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func quickActionButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func planningBucketChip(_ bucket: TaskPlanningBucket) -> some View {
        statusChip(bucket.displayName, tint: bucketColor(bucket), systemImage: bucket.systemImageName)
    }

    private func statusChip(_ title: String, tint: Color, systemImage: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.08), in: Capsule())
    }

    private func bucketColor(_ bucket: TaskPlanningBucket) -> Color {
        switch bucket {
        case .today:
            return Color.tasker.statusSuccess
        case .thisWeek:
            return Color.tasker.accentPrimary
        case .nextWeek:
            return Color.tasker.statusWarning
        case .later, .someday:
            return Color.tasker.textSecondary
        }
    }

    /// Executes deleteProjects.
    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            guard viewModel.filteredProjects.indices.contains(index) else { continue }
            let entry = viewModel.filteredProjects[index]
            guard entry.project.id != ProjectConstants.inboxProjectID else { continue }
            viewModel.deleteProject(entry, strategy: .moveToInbox)
        }
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
        Text("ProjectManagementView preview requires an injected ProjectManagementViewModel.")
    }
}
