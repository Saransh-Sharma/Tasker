import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum LifeManagementDestination: Hashable {
    case area(UUID)
    case project(UUID)
}

private enum LifeManagementComposerRoute: Identifiable, Equatable {
    case area(LifeManagementLifeAreaDraft)
    case project(LifeManagementProjectDraft)

    var id: UUID {
        switch self {
        case .area(let draft):
            return draft.id
        case .project(let draft):
            return draft.id
        }
    }
}

struct LifeManagementView: View {
    @StateObject private var viewModel: LifeManagementViewModel
    @StateObject private var habitComposerViewModel = PresentationDependencyContainer.shared.makeNewAddHabitViewModel()
    @State private var habitComposerPresented = false
    @State private var selectedHabitRow: HabitLibraryRow?
    @State private var habitComposerSuccessFlash = false

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    /// Initializes a new instance.
    init(viewModel: LifeManagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var isSearching: Bool {
        viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var isEmptyState: Bool {
        viewModel.areaRows.isEmpty &&
        viewModel.projectGroups.isEmpty &&
        viewModel.habitGroups.isEmpty &&
        viewModel.archiveSections.hasContent == false
    }

    private var activeComposerRoute: Binding<LifeManagementComposerRoute?> {
        Binding(
            get: {
                if let draft = viewModel.lifeAreaDraft {
                    return .area(draft)
                }
                if let draft = viewModel.projectDraft {
                    return .project(draft)
                }
                return nil
            },
            set: { newValue in
                switch newValue {
                case .area(let draft):
                    viewModel.lifeAreaDraft = draft
                    viewModel.projectDraft = nil
                case .project(let draft):
                    viewModel.projectDraft = draft
                    viewModel.lifeAreaDraft = nil
                case nil:
                    viewModel.dismissLifeAreaDraft()
                    viewModel.dismissProjectDraft()
                }
            }
        )
    }

    private var compactComposerRoute: Binding<LifeManagementComposerRoute?> {
        Binding(
            get: {
                layoutClass == .phone ? activeComposerRoute.wrappedValue : nil
            },
            set: { newValue in
                activeComposerRoute.wrappedValue = newValue
            }
        )
    }

    private var regularComposerRoute: Binding<LifeManagementComposerRoute?> {
        Binding(
            get: {
                layoutClass == .phone ? nil : activeComposerRoute.wrappedValue
            },
            set: { newValue in
                activeComposerRoute.wrappedValue = newValue
            }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: spacing.s16, pinnedViews: [.sectionHeaders]) {
                heroCard
                    .enhancedStaggeredAppearance(index: 0)

                if let errorMessage = viewModel.errorMessage {
                    errorCard(message: errorMessage)
                        .enhancedStaggeredAppearance(index: 1)
                }

                Section {
                    if isSearching {
                        searchResultsContent
                    } else {
                        scopeContent
                    }
                } header: {
                    scopeRail
                }
            }
            .taskerReadableContent(maxWidth: 1100, alignment: .center)
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.top, spacing.s16)
            .padding(.bottom, spacing.sectionGap)
        }
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("Life Management")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.lifeManagement.console")
        .searchable(text: $viewModel.searchQuery, prompt: "Search areas, projects, habits")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add Area", systemImage: "square.grid.2x2") {
                        viewModel.beginCreateLifeArea()
                    }
                    Button("Add Project", systemImage: "folder.badge.plus") {
                        viewModel.beginCreateProject()
                    }
                    Button("Add Habit", systemImage: "repeat") {
                        presentHabitComposer()
                    }
                } label: {
                    LifeManagementMenuLabel(title: "Add", systemImage: "plus")
                }
                .accessibilityIdentifier("settings.lifeManagement.addMenu")
            }
        }
        .overlay {
            if viewModel.isLoading && isEmptyState {
                ProgressView("Loading life management...")
                    .font(.tasker(.body))
                    .padding(.horizontal, spacing.s16)
                    .padding(.vertical, spacing.s12)
                    .background(
                        Color.tasker.surfacePrimary,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.isMutating {
                mutationPill
            }
        }
        .taskerSnackbar($viewModel.snackbar)
        .task {
            viewModel.loadIfNeeded()
        }
        .refreshable {
            viewModel.reload()
        }
        .navigationDestination(for: LifeManagementDestination.self) { destination in
            switch destination {
            case .area(let areaID):
                LifeManagementAreaDetailView(
                    viewModel: viewModel,
                    areaID: areaID,
                    onOpenHabit: { row in
                        selectedHabitRow = row
                    },
                    onCreateHabit: { template in
                        presentHabitComposer(prefill: template)
                    }
                )
            case .project(let projectID):
                LifeManagementProjectDetailView(
                    viewModel: viewModel,
                    projectID: projectID,
                    onOpenHabit: { row in
                        selectedHabitRow = row
                    },
                    onCreateHabit: { template in
                        presentHabitComposer(prefill: template)
                    }
                )
            }
        }
        .fullScreenCover(item: compactComposerRoute) { route in
            composerDestination(for: route, containerMode: .sheet)
        }
        .sheet(item: regularComposerRoute) { route in
            composerDestination(for: route, containerMode: .inspector)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color.tasker(.bgElevated))
                .interactiveDismissDisabled(viewModel.isMutating)
        }
        .sheet(item: $viewModel.moveProjectDraft) { draft in
            ProjectMoveSheet(
                draft: draft,
                targets: viewModel.availableAreaTargets(excluding: viewModel.projectRow(for: draft.projectID)?.lifeArea?.id),
                isSaving: viewModel.isMutating,
                onSave: { updatedDraft in
                    viewModel.moveProjectDraft = updatedDraft
                    viewModel.moveProjectFromDraft()
                },
                onCancel: {
                    viewModel.dismissMoveProjectDraft()
                }
            )
        }
        .sheet(item: $viewModel.deleteAreaDraft) { draft in
            DeleteAreaSheet(
                draft: draft,
                targets: viewModel.availableAreaTargets(excluding: draft.areaID),
                isSaving: viewModel.isMutating,
                onSave: { updatedDraft in
                    viewModel.deleteAreaDraft = updatedDraft
                    viewModel.confirmDeleteArea()
                },
                onCancel: {
                    viewModel.dismissDeleteAreaDraft()
                }
            )
        }
        .sheet(item: $viewModel.deleteProjectDraft) { draft in
            DeleteProjectSheet(
                draft: draft,
                targets: viewModel.availableProjectDeleteTargets(excluding: draft.projectID),
                isSaving: viewModel.isMutating,
                onSave: { updatedDraft in
                    viewModel.deleteProjectDraft = updatedDraft
                    viewModel.confirmDeleteProject()
                },
                onCancel: {
                    viewModel.dismissDeleteProjectDraft()
                }
            )
        }
        .confirmationDialog(
            "Delete habit permanently?",
            isPresented: Binding(
                get: { viewModel.deleteHabitDraft != nil },
                set: { if !$0 { viewModel.dismissDeleteHabitDraft() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                viewModel.confirmDeleteHabit()
            }
            Button("Cancel", role: .cancel) {
                viewModel.dismissDeleteHabitDraft()
            }
        } message: {
            Text("This removes the habit and its scheduling history.")
        }
        .sheet(isPresented: $habitComposerPresented) {
            habitComposerSheet
        }
        .sheet(item: $selectedHabitRow) { row in
            HabitDetailSheetView(
                viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                onMutation: {
                    viewModel.reload()
                }
            )
        }
    }

    @ViewBuilder
    private func composerDestination(for route: LifeManagementComposerRoute, containerMode: AddTaskContainerMode) -> some View {
        switch route {
        case .area(let draft):
            LifeManagementAreaComposerView(
                draft: draft,
                iconOptions: viewModel.lifeAreaIconCatalog,
                containerMode: containerMode,
                isSaving: viewModel.isMutating,
                errorMessage: viewModel.errorMessage,
                onSave: { updatedDraft in
                    viewModel.lifeAreaDraft = updatedDraft
                    viewModel.saveLifeAreaDraft()
                },
                onCancel: {
                    viewModel.dismissLifeAreaDraft()
                }
            )
        case .project(let draft):
            LifeManagementProjectComposerView(
                draft: draft,
                lifeAreas: viewModel.availableAreaTargets(excluding: nil),
                fallbackAreaRows: viewModel.areaRows,
                containerMode: containerMode,
                isSaving: viewModel.isMutating,
                errorMessage: viewModel.errorMessage,
                onSave: { updatedDraft in
                    viewModel.projectDraft = updatedDraft
                    viewModel.saveProjectDraft()
                },
                onCancel: {
                    viewModel.dismissProjectDraft()
                }
            )
        }
    }

    private var heroCard: some View {
        TaskerSettingsHeroCard(
            eyebrow: "Manage your setup",
            title: "Life Management",
            subtitle: heroSubtitle,
            statusItems: heroStatusItems,
            accessibilityIdentifier: "settings.lifeManagement.hero"
        )
    }

    private var heroSubtitle: String {
        let stats = viewModel.overview.stats
        let summary = stats.map { "\($0.value) \($0.title.lowercased())" }.joined(separator: " · ")
        if summary.isEmpty {
            return "Create and organize areas, projects, and habits from one place."
        }
        return "\(summary). Rename, move, archive, and restore everything from here."
    }

    private var heroStatusItems: [TaskerSettingsStatusDescriptor] {
        viewModel.overview.stats.map { stat in
            TaskerSettingsStatusDescriptor(
                id: stat.id,
                title: stat.title,
                value: stat.value,
                systemImage: stat.symbolName,
                tone: .accent
            )
        }
    }

    private func errorCard(message: String) -> some View {
        TaskerSettingsCard(active: true) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Label("Couldn’t complete the last action", systemImage: "exclamationmark.triangle.fill")
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))

                Text(message)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: spacing.s8) {
                    Button("Retry") {
                        viewModel.reload()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Dismiss") {
                        viewModel.clearError()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var scopeRail: some View {
        ZStack {
            Color.tasker(.bgCanvas)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.s8) {
                    ForEach(LifeManagementScope.allCases) { scope in
                        Button {
                            withAnimation(accessibilityReduceMotion ? nil : TaskerAnimation.quick) {
                                viewModel.selectedScope = scope
                            }
                        } label: {
                            Text(scope.title)
                                .font(.tasker(.callout).weight(.semibold))
                                .foregroundStyle(viewModel.selectedScope == scope ? Color.tasker(.accentOnPrimary) : Color.tasker(.textSecondary))
                                .padding(.horizontal, spacing.s12)
                                .frame(minHeight: TaskerSettingsMetrics.chipMinHeight)
                                .background(
                                    Capsule()
                                        .fill(viewModel.selectedScope == scope ? Color.tasker(.accentPrimary) : Color.tasker(.surfacePrimary))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.tasker(.strokeHairline), lineWidth: viewModel.selectedScope == scope ? 0 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .scaleOnPress()
                    }
                }
                .padding(.vertical, spacing.s8)
            }
        }
    }

    @ViewBuilder
    private var scopeContent: some View {
        switch viewModel.selectedScope {
        case .overview:
            overviewContent
        case .areas:
            areasContent
        case .projects:
            projectsContent
        case .habits:
            habitsContent
        case .archive:
            archiveContent
        }
    }

    private var overviewContent: some View {
        VStack(spacing: spacing.s16) {
            if viewModel.overview.attentionItems.isEmpty == false {
                TaskerSettingsCard {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        sectionHeader(title: "Needs attention", subtitle: "Quick cleanup that is easier to handle from here.")
                        VStack(spacing: spacing.chipSpacing) {
                            ForEach(viewModel.overview.attentionItems) { item in
                                attentionRow(item)
                            }
                        }
                    }
                }
                .enhancedStaggeredAppearance(index: 2)
            }

            pairedCards(
                first: {
                    TaskerSettingsCard {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            sectionHeader(title: "Areas", subtitle: "Your top-level buckets for projects and habits.")
                            if viewModel.overview.topAreas.isEmpty {
                                Text("Add an area so projects and habits have a clear home.")
                                    .font(.tasker(.callout))
                                    .foregroundStyle(Color.tasker(.textSecondary))
                            } else {
                                VStack(spacing: spacing.chipSpacing) {
                                    ForEach(viewModel.overview.topAreas) { row in
                                        NavigationLink(value: LifeManagementDestination.area(row.id)) {
                                            AreaSummaryRow(row: row)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                },
                second: {
                    TaskerSettingsCard {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            sectionHeader(title: "Projects to review", subtitle: "Empty projects usually need work, a move, or an archive.")
                            if viewModel.overview.attentionProjects.isEmpty {
                                Text("No empty projects need attention right now.")
                                    .font(.tasker(.callout))
                                    .foregroundStyle(Color.tasker(.textSecondary))
                            } else {
                                VStack(spacing: spacing.chipSpacing) {
                                    ForEach(viewModel.overview.attentionProjects) { row in
                                        NavigationLink(value: LifeManagementDestination.project(row.id)) {
                                            ProjectSummaryRow(row: row)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            )
            .enhancedStaggeredAppearance(index: 3)

            TaskerSettingsCard {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    sectionHeader(title: "Habits to review", subtitle: "Paused habits stay here until you resume, archive, or delete them.")
                    if viewModel.overview.attentionHabits.isEmpty {
                        Text("No paused habits need attention right now.")
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    } else {
                        VStack(spacing: spacing.chipSpacing) {
                            ForEach(viewModel.overview.attentionHabits) { row in
                                HabitSummaryRow(row: row) {
                                    selectedHabitRow = row.row
                                }
                            }
                        }
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 4)

            if viewModel.overview.attentionItems.isEmpty &&
                viewModel.overview.topAreas.isEmpty &&
                viewModel.overview.attentionProjects.isEmpty &&
                viewModel.overview.attentionHabits.isEmpty {
                emptyStateCard(
                    title: "Start here",
                    body: "Add an area first, then place projects and habits inside it.",
                    actionTitle: "Add Area",
                    action: {
                        viewModel.beginCreateLifeArea()
                    }
                )
            }
        }
    }

    private var areasContent: some View {
        VStack(spacing: spacing.s12) {
            if viewModel.areaRows.isEmpty {
                emptyStateCard(
                    title: "No areas yet",
                    body: "Areas are the top-level homes for projects and habits. Start there.",
                    actionTitle: "Add Area",
                    action: {
                        viewModel.beginCreateLifeArea()
                    }
                )
            } else {
                ForEach(viewModel.areaRows) { row in
                    TaskerSettingsCard {
                        HStack(alignment: .top, spacing: spacing.s12) {
                            NavigationLink(value: LifeManagementDestination.area(row.id)) {
                                AreaListRow(row: row)
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button("Edit", systemImage: "pencil") {
                                    viewModel.beginEditLifeArea(row.id)
                                }
                                Button("Add Project", systemImage: "folder.badge.plus") {
                                    viewModel.beginCreateProject(prefillLifeAreaID: row.id)
                                }
                                Button("Add Habit", systemImage: "repeat") {
                                    presentHabitComposer(
                                        prefill: AddHabitPrefillTemplate(
                                            title: "",
                                            lifeAreaID: row.id
                                        )
                                    )
                                }
                                if row.isGeneral == false {
                                    Button("Archive", systemImage: "archivebox") {
                                        viewModel.archiveLifeArea(row.id)
                                    }
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        viewModel.beginDeleteArea(row.id)
                                    }
                                }
                            } label: {
                                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var projectsContent: some View {
        VStack(spacing: spacing.s12) {
            if viewModel.projectGroups.isEmpty {
                emptyStateCard(
                    title: "No projects yet",
                    body: "Projects hold related tasks inside an area. Add one here or from an area detail.",
                    actionTitle: "Add Project",
                    action: {
                        viewModel.beginCreateProject()
                    }
                )
            } else {
                ForEach(viewModel.projectGroups) { group in
                    projectGroupCard(group)
                }
            }
        }
    }

    private var habitsContent: some View {
        VStack(spacing: spacing.s12) {
            habitFilterRail

            if viewModel.habitGroups.isEmpty {
                emptyStateCard(
                    title: "No habits in this filter",
                    body: "Build, quit, and paused habits all live here with the same controls as areas and projects.",
                    actionTitle: "Add Habit",
                    action: {
                        presentHabitComposer()
                    }
                )
            } else {
                ForEach(Array(viewModel.habitGroups), id: \.id) { group in
                    TaskerSettingsCard {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            groupHeader(title: group.title, subtitle: "\(group.rows.count) habit\(group.rows.count == 1 ? "" : "s")")
                            VStack(spacing: spacing.chipSpacing) {
                                ForEach(group.rows) { row in
                                    HabitListRow(
                                        row: row,
                                        onOpen: {
                                            selectedHabitRow = row.row
                                        },
                                        onTogglePause: {
                                            viewModel.toggleHabitPause(row.id)
                                        },
                                        onArchive: {
                                            viewModel.archiveHabit(row.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var archiveContent: some View {
        VStack(spacing: spacing.s12) {
            if viewModel.archiveSections.hasContent == false {
                emptyStateCard(
                    title: "Archive is clear",
                    body: "Archived areas, projects, and habits show up here for restore or permanent delete.",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                if viewModel.archiveSections.areas.isEmpty == false {
                    archiveAreaSection
                }
                if viewModel.archiveSections.projects.isEmpty == false {
                    archiveProjectSection
                }
                if viewModel.archiveSections.habits.isEmpty == false {
                    archiveHabitSection
                }
            }
        }
    }

    private var searchResultsContent: some View {
        VStack(spacing: spacing.s12) {
            if viewModel.searchResults.isEmpty {
                emptyStateCard(
                    title: "No matches",
                    body: viewModel.selectedScope == .archive
                        ? "Try a different search in archived areas, projects, or habits."
                        : "Try a different search in active areas, projects, or habits.",
                    actionTitle: nil,
                    action: nil
                )
            } else {
                if viewModel.searchResults.areas.isEmpty == false {
                    TaskerSettingsCard {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            sectionHeader(title: "Areas", subtitle: "Search matches in top-level structure.")
                            VStack(spacing: spacing.chipSpacing) {
                                ForEach(viewModel.searchResults.areas) { row in
                                    NavigationLink(value: LifeManagementDestination.area(row.id)) {
                                        AreaSummaryRow(row: row)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if viewModel.searchResults.projects.isEmpty == false {
                    TaskerSettingsCard {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            sectionHeader(title: "Projects", subtitle: "Search matches in project names and metadata.")
                            VStack(spacing: spacing.chipSpacing) {
                                ForEach(viewModel.searchResults.projects) { row in
                                    NavigationLink(value: LifeManagementDestination.project(row.id)) {
                                        ProjectSummaryRow(row: row)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if viewModel.searchResults.habits.isEmpty == false {
                    TaskerSettingsCard {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            sectionHeader(title: "Habits", subtitle: "Search matches in habit names, area, project, and notes.")
                            VStack(spacing: spacing.chipSpacing) {
                                ForEach(viewModel.searchResults.habits) { row in
                                    HabitSummaryRow(row: row) {
                                        selectedHabitRow = row.row
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var archiveAreaSection: some View {
        TaskerSettingsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                sectionHeader(title: "Archived Areas", subtitle: "Restore areas that still matter, or delete with reassignment.")
                VStack(spacing: spacing.chipSpacing) {
                    ForEach(viewModel.archiveSections.areas) { row in
                        HStack(alignment: .top, spacing: spacing.s12) {
                            NavigationLink(value: LifeManagementDestination.area(row.id)) {
                                AreaSummaryRow(row: row)
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button("Restore", systemImage: "arrow.uturn.backward") {
                                    viewModel.restoreLifeArea(row.id)
                                }
                                if row.isGeneral == false {
                                    Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                                        viewModel.beginDeleteArea(row.id)
                                    }
                                }
                            } label: {
                                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var archiveProjectSection: some View {
        VStack(spacing: spacing.s12) {
            ForEach(Array(viewModel.archiveSections.projects), id: \.id) { group in
                TaskerSettingsCard {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        groupHeader(title: group.title, subtitle: "Archived projects")
                        VStack(spacing: spacing.chipSpacing) {
                            ForEach(group.rows) { row in
                                HStack(alignment: .top, spacing: spacing.s12) {
                                    NavigationLink(value: LifeManagementDestination.project(row.id)) {
                                        ProjectSummaryRow(row: row)
                                    }
                                    .buttonStyle(.plain)

                                    Menu {
                                        Button("Restore", systemImage: "arrow.uturn.backward") {
                                            viewModel.restoreProject(row.id)
                                        }
                                        Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                                            viewModel.beginDeleteProject(row.id)
                                        }
                                    } label: {
                                        LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var archiveHabitSection: some View {
        VStack(spacing: spacing.s12) {
            ForEach(Array(viewModel.archiveSections.habits), id: \.id) { group in
                TaskerSettingsCard {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        groupHeader(title: group.title, subtitle: "Archived habits")
                        VStack(spacing: spacing.chipSpacing) {
                            ForEach(group.rows) { row in
                                HabitArchiveRow(
                                    row: row,
                                    onOpen: {
                                        selectedHabitRow = row.row
                                    },
                                    onRestore: {
                                        viewModel.restoreHabit(row.id)
                                    },
                                    onDelete: {
                                        viewModel.beginDeleteHabit(row.id)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    private var habitFilterRail: some View {
        TaskerSettingsCard {
            HStack(spacing: spacing.s8) {
                ForEach(LifeManagementHabitFilter.allCases) { filter in
                    Button {
                        withAnimation(accessibilityReduceMotion ? nil : TaskerAnimation.quick) {
                            viewModel.selectedHabitFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.tasker(.caption1).weight(.semibold))
                            .foregroundStyle(viewModel.selectedHabitFilter == filter ? Color.tasker(.accentOnPrimary) : Color.tasker(.textSecondary))
                            .padding(.horizontal, spacing.chipSpacing)
                            .frame(minHeight: TaskerSettingsMetrics.chipMinHeight)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedHabitFilter == filter ? Color.tasker(.accentPrimary) : Color.tasker(.surfaceSecondary))
                            )
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func projectGroupCard(_ group: LifeManagementProjectGroup) -> some View {
        let lifeAreaID = group.lifeArea?.id
        return TaskerSettingsCard(active: viewModel.activeDropLifeAreaID == lifeAreaID) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                groupHeader(
                    title: group.title,
                    subtitle: group.rows.count == 1 ? "1 project" : "\(group.rows.count) projects"
                )

                VStack(spacing: spacing.chipSpacing) {
                    ForEach(group.rows) { row in
                        ProjectListRow(
                            row: row,
                            destination: .project(row.id),
                            onEdit: {
                                viewModel.beginEditProject(row.id)
                            },
                            onMove: row.isMoveLocked ? nil : {
                                viewModel.beginMoveProject(row.id)
                            },
                            onArchive: row.isInbox ? nil : {
                                viewModel.archiveProject(row.id)
                            },
                            onDelete: row.project.isDefault ? nil : {
                                viewModel.beginDeleteProject(row.id)
                            },
                            onDrag: {
                                viewModel.beginProjectDrag(row.id)
                            }
                        )
                    }
                }
            }
        }
        .onDrop(
            of: [UTType.text],
            isTargeted: Binding(
                get: { viewModel.activeDropLifeAreaID == lifeAreaID && lifeAreaID != nil },
                set: { targeted in
                    viewModel.setDropTarget(targeted ? lifeAreaID : nil)
                }
            )
        ) { providers in
            guard let lifeAreaID else { return false }
            return viewModel.handleProjectDrop(providers: providers, targetLifeAreaID: lifeAreaID)
        }
    }

    private func presentHabitComposer(prefill: AddHabitPrefillTemplate? = nil) {
        habitComposerViewModel.resetForm()
        if let prefill {
            habitComposerViewModel.applyPrefill(prefill)
        }
        habitComposerPresented = true
    }

    private func createHabitAndDismiss() {
        guard habitComposerViewModel.canSubmit, habitComposerViewModel.isSaving == false else { return }
        habitComposerViewModel.createHabit { result in
            guard case .success = result else { return }
            habitComposerPresented = false
            viewModel.reload()
        }
    }

    private var habitComposerSheet: some View {
        AddHabitForedropView(
            viewModel: habitComposerViewModel,
            containerMode: .sheet,
            showAddAnother: false,
            successFlash: $habitComposerSuccessFlash,
            onCancel: {
                habitComposerPresented = false
            },
            onCreate: {
                createHabitAndDismiss()
            },
            onAddAnother: {
                createHabitAndDismiss()
            },
            onExpandToLarge: {}
        )
        .background(Color.tasker(.bgCanvas))
    }

    private var mutationPill: some View {
        HStack(spacing: spacing.s8) {
            ProgressView()
                .controlSize(.small)
            Text("Updating life management...")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(Color.tasker(.surfacePrimary), in: Capsule())
        .padding(.bottom, spacing.s8)
    }

    private func pairedCards<First: View, Second: View>(
        @ViewBuilder first: () -> First,
        @ViewBuilder second: () -> Second
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: spacing.s16) {
                first()
                    .frame(maxWidth: .infinity, alignment: .top)
                second()
                    .frame(maxWidth: .infinity, alignment: .top)
            }

            VStack(spacing: spacing.s16) {
                first()
                second()
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(title)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker(.textPrimary))
            Text(subtitle)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
            Text(title)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker(.textPrimary))
            Text(subtitle)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func attentionRow(_ item: LifeManagementAttentionItem) -> some View {
        HStack(alignment: .top, spacing: spacing.chipSpacing) {
            Image(systemName: item.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tasker(.accentPrimary))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.tasker(.accentWash))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker(.textPrimary))
                Text(item.detail)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func emptyStateCard(
        title: String,
        body: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        TaskerSettingsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))

                Text(body)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle, let action {
                    Button(actionTitle) {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

private struct LifeManagementMenuLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.tasker(.textSecondary))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(title))
    }
}

private struct LifeManagementAppearanceLine: View {
    let title: String
    let accentHex: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(uiColor: UIColor(taskerHex: accentHex)))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
            Spacer()
            Text(value)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker(.textPrimary))
        }
    }
}

private func lifeManagementHabitStatusText(_ row: HabitLibraryRow) -> String {
    if row.isArchived { return "Archived" }
    if row.isPaused { return "Paused" }
    if row.currentStreak > 0 { return "\(row.currentStreak)d streak" }
    return lifeManagementHabitCadenceLabel(row.cadence)
}

private func lifeManagementHabitCadenceLabel(_ cadence: HabitCadenceDraft) -> String {
    switch cadence {
    case .daily:
        return "Daily"
    case .weekly(let days, _, _):
        return days.count == 1 ? "Weekly" : "\(days.count)x weekly"
    }
}

private struct AreaListRow: View {
    let row: LifeManagementAreaRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccentIconBadge(
                symbolName: row.lifeArea.icon ?? "square.grid.2x2",
                accentHex: row.lifeArea.color ?? LifeAreaConstants.generalSeedColor
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.lifeArea.name)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    if row.isGeneral {
                        InlineToneBadge(title: "Pinned")
                    }
                }

                Text("\(row.projectCount) projects · \(row.habitCount) habits")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.tasker(.textTertiary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AreaSummaryRow: View {
    let row: LifeManagementAreaRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccentIconBadge(
                symbolName: row.lifeArea.icon ?? "square.grid.2x2",
                accentHex: row.lifeArea.color ?? LifeAreaConstants.generalSeedColor
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(row.lifeArea.name)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker(.textPrimary))
                Text("\(row.projectCount) projects · \(row.habitCount) habits")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProjectListRow: View {
    let row: LifeManagementProjectRow
    let destination: LifeManagementDestination
    let onEdit: () -> Void
    let onMove: (() -> Void)?
    let onArchive: (() -> Void)?
    let onDelete: (() -> Void)?
    let onDrag: () -> NSItemProvider

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(value: destination) {
                HStack(alignment: .top, spacing: 12) {
                    AccentIconBadge(
                        symbolName: row.project.icon.systemImageName,
                        accentHex: row.project.color.hexString
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.project.name)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(Color.tasker(.textPrimary))
                        Text(projectSubtitle)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit", systemImage: "pencil") {
                    onEdit()
                }
                if let onMove {
                    Button("Move Project", systemImage: "arrow.left.arrow.right") {
                        onMove()
                    }
                }
                if let onArchive {
                    Button("Archive", systemImage: "archivebox") {
                        onArchive()
                    }
                }
                if let onDelete {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        onDelete()
                    }
                }
            } label: {
                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
        .onDrag {
            onDrag()
        }
    }

    private var projectSubtitle: String {
        if row.taskCount == 0 {
            return "Empty"
        }
        let owner = row.lifeArea?.name ?? "No Area"
        return "\(owner) · \(row.taskCount) open tasks"
    }
}

private struct ProjectSummaryRow: View {
    let row: LifeManagementProjectRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccentIconBadge(
                symbolName: row.project.icon.systemImageName,
                accentHex: row.project.color.hexString
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(row.project.name)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker(.textPrimary))
                Text(summarySubtitle)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summarySubtitle: String {
        if row.taskCount == 0 {
            return "Empty"
        }
        return "\(row.lifeArea?.name ?? "No Area") · \(row.taskCount) open tasks"
    }
}

private struct HabitListRow: View {
    let row: LifeManagementHabitRow
    let onOpen: () -> Void
    let onTogglePause: () -> Void
    let onArchive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                onOpen()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    AccentIconBadge(
                        symbolName: row.row.icon?.symbolName ?? "circle.dashed",
                        accentHex: row.row.colorHex ?? row.lifeArea?.color ?? LifeAreaConstants.generalSeedColor
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.row.title)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(Color.tasker(.textPrimary))
                        Text(habitSubtitle)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button(row.row.isPaused ? "Resume" : "Pause", systemImage: row.row.isPaused ? "play.fill" : "pause.fill") {
                    onTogglePause()
                }
                Button("Archive", systemImage: "archivebox") {
                    onArchive()
                }
            } label: {
                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private var habitSubtitle: String {
        var parts: [String] = [row.row.kind == .positive ? "Build" : "Quit"]
        parts.append(lifeManagementHabitStatusText(row.row))
        return parts.joined(separator: " · ")
    }
}

private struct HabitSummaryRow: View {
    let row: LifeManagementHabitRow
    let onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                AccentIconBadge(
                    symbolName: row.row.icon?.symbolName ?? "circle.dashed",
                    accentHex: row.row.colorHex ?? row.lifeArea?.color ?? LifeAreaConstants.generalSeedColor
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.row.title)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    Text(lifeManagementHabitStatusText(row.row))
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HabitArchiveRow: View {
    let row: LifeManagementHabitRow
    let onOpen: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HabitSummaryRow(row: row, onOpen: onOpen)

            Menu {
                Button("Restore", systemImage: "arrow.uturn.backward") {
                    onRestore()
                }
                Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
            } label: {
                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct AccentIconBadge: View {
    let symbolName: String
    let accentHex: String

    var body: some View {
        let color = Color(uiColor: UIColor(taskerHex: accentHex))
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.14))
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

private struct InlineToneBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.tasker(.caption1).weight(.semibold))
            .foregroundStyle(Color.tasker(.accentPrimary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.tasker(.accentWash))
            )
    }
}

private struct LifeManagementAreaDetailView: View {
    @ObservedObject var viewModel: LifeManagementViewModel
    let areaID: UUID
    let onOpenHabit: (HabitLibraryRow) -> Void
    let onCreateHabit: (AddHabitPrefillTemplate) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        Group {
            if let row = viewModel.areaRow(for: areaID) {
                ScrollView {
                    VStack(spacing: spacing.s16) {
                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                AreaSummaryRow(row: row)
                                LifeManagementAppearanceLine(
                                    title: "Appearance",
                                    accentHex: row.lifeArea.color ?? LifeAreaConstants.generalSeedColor,
                                    value: row.lifeArea.color?.nilIfBlank == nil ? "Default area color" : "Custom area color"
                                )
                            }
                        }

                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                        sectionTitle("Projects")
                                        Spacer()
                                        Button("Add Project") {
                                            viewModel.beginCreateProject(prefillLifeAreaID: row.id)
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        sectionTitle("Projects")
                                        Button("Add Project") {
                                            viewModel.beginCreateProject(prefillLifeAreaID: row.id)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                let projects = viewModel.projects(inLifeArea: row.id).filter { $0.project.isArchived == false }
                                if projects.isEmpty {
                                    Text("No projects in this area yet.")
                                        .font(.tasker(.callout))
                                        .foregroundStyle(Color.tasker(.textSecondary))
                                } else {
                                    VStack(spacing: spacing.chipSpacing) {
                                        ForEach(projects) { projectRow in
                                            NavigationLink(value: LifeManagementDestination.project(projectRow.id)) {
                                                ProjectSummaryRow(row: projectRow)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                        sectionTitle("Habits")
                                        Spacer()
                                        Button("Add Habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        sectionTitle("Habits")
                                        Button("Add Habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                let habits = viewModel.habits(inLifeArea: row.id).filter { $0.row.isArchived == false }
                                if habits.isEmpty {
                                    Text("No habits in this area yet.")
                                        .font(.tasker(.callout))
                                        .foregroundStyle(Color.tasker(.textSecondary))
                                } else {
                                    VStack(spacing: spacing.chipSpacing) {
                                        ForEach(habits) { habitRow in
                                            HabitSummaryRow(row: habitRow) {
                                                onOpenHabit(habitRow.row)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        TaskerSettingsCard(active: true) {
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
                    .taskerReadableContent(maxWidth: 920, alignment: .center)
                }
                .background(Color.tasker(.bgCanvas))
                .navigationTitle(row.lifeArea.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Color.tasker(.bgCanvas)
                    .overlay {
                        Text("This area is no longer available.")
                            .font(.tasker(.body))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.tasker(.headline))
            .foregroundStyle(Color.tasker(.textPrimary))
    }

    @ViewBuilder
    private func areaActionButtons(row: LifeManagementAreaRow) -> some View {
        if row.lifeArea.isArchived {
            Button("Restore") {
                viewModel.restoreLifeArea(row.id)
            }
            .buttonStyle(.borderedProminent)
        } else if row.isGeneral == false {
            Button("Archive Area") {
                viewModel.archiveLifeArea(row.id)
            }
            .buttonStyle(.bordered)
        }

        if row.isGeneral == false {
            Button("Delete Area", role: .destructive) {
                viewModel.beginDeleteArea(row.id)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct LifeManagementProjectDetailView: View {
    @ObservedObject var viewModel: LifeManagementViewModel
    let projectID: UUID
    let onOpenHabit: (HabitLibraryRow) -> Void
    let onCreateHabit: (AddHabitPrefillTemplate) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        Group {
            if let row = viewModel.projectRow(for: projectID) {
                ScrollView {
                    VStack(spacing: spacing.s16) {
                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ProjectSummaryRow(row: row)
                                Text("\(row.project.color.displayName) · \(row.project.icon.displayName)")
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker(.textSecondary))
                                Text(row.project.projectDescription?.nilIfBlank ?? "No project description yet.")
                                    .font(.tasker(.callout))
                                    .foregroundStyle(Color.tasker(.textSecondary))
                            }
                        }

                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                Text("Structure")
                                    .font(.tasker(.headline))
                                    .foregroundStyle(Color.tasker(.textPrimary))

                                detailLine(title: "Area", value: row.lifeArea?.name ?? "No Area")
                                detailLine(title: "Open tasks", value: "\(row.taskCount)")
                                detailLine(title: "Linked habits", value: "\(viewModel.projectHabits(projectID: projectID).filter { $0.row.isArchived == false }.count)")
                            }
                        }

                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                        Text("Linked habits")
                                            .font(.tasker(.headline))
                                            .foregroundStyle(Color.tasker(.textPrimary))
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
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        Text("Linked habits")
                                            .font(.tasker(.headline))
                                            .foregroundStyle(Color.tasker(.textPrimary))
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
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                let habits = viewModel.projectHabits(projectID: projectID).filter { $0.row.isArchived == false }
                                if habits.isEmpty {
                                    Text("No habits are linked to this project.")
                                        .font(.tasker(.callout))
                                        .foregroundStyle(Color.tasker(.textSecondary))
                                } else {
                                    VStack(spacing: spacing.chipSpacing) {
                                        ForEach(habits) { habitRow in
                                            HabitSummaryRow(row: habitRow) {
                                                onOpenHabit(habitRow.row)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        TaskerSettingsCard(active: true) {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                Text("Actions")
                                    .font(.tasker(.headline))
                                    .foregroundStyle(Color.tasker(.textPrimary))

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
                    .taskerReadableContent(maxWidth: 920, alignment: .center)
                }
                .background(Color.tasker(.bgCanvas))
                .navigationTitle(row.project.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Color.tasker(.bgCanvas)
                    .overlay {
                        Text("This project is no longer available.")
                            .font(.tasker(.body))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    }
            }
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
            Spacer()
            Text(value)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker(.textPrimary))
        }
    }

    @ViewBuilder
    private func projectActionButtons(row: LifeManagementProjectRow) -> some View {
        if row.isMoveLocked == false {
            Button("Move Project") {
                viewModel.beginMoveProject(row.id)
            }
            .buttonStyle(.bordered)
        }

        if row.project.isArchived {
            Button("Restore") {
                viewModel.restoreProject(row.id)
            }
            .buttonStyle(.borderedProminent)
        } else if row.isInbox == false {
            Button("Archive Project") {
                viewModel.archiveProject(row.id)
            }
            .buttonStyle(.bordered)
        }

        if row.project.isDefault == false {
            Button("Delete Project", role: .destructive) {
                viewModel.beginDeleteProject(row.id)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct LifeManagementAreaComposerView: View {
    @State private var draft: LifeManagementLifeAreaDraft
    @State private var showCustomColorField: Bool
    @State private var errorShakeTrigger = false
    @FocusState private var titleFieldFocused: Bool

    let iconOptions: [LifeAreaIconOption]
    let containerMode: AddTaskContainerMode
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (LifeManagementLifeAreaDraft) -> Void
    let onCancel: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var readableWidth: CGFloat {
        switch containerMode {
        case .inspector:
            return layoutClass.isPad ? 860 : 760
        case .sheet:
            return 720
        }
    }

    init(
        draft: LifeManagementLifeAreaDraft,
        iconOptions: [LifeAreaIconOption],
        containerMode: AddTaskContainerMode,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (LifeManagementLifeAreaDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        _showCustomColorField = State(initialValue: lifeManagementAreaPaletteMatch(for: draft.colorHex) == nil && draft.colorHex.nilIfBlank != nil)
        self.iconOptions = iconOptions
        self.containerMode = containerMode
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var canSave: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isSaving
    }

    private var selectedColorTitle: String {
        if showCustomColorField {
            return draft.colorHex.nilIfBlank == nil ? "Custom" : "Custom hex"
        }
        return lifeManagementAreaPaletteMatch(for: draft.colorHex)?.title ?? "Default"
    }

    private var selectedIconTitle: String {
        lifeManagementAreaIconLabel(for: draft.iconSymbolName, options: iconOptions)
    }

    var body: some View {
        VStack(spacing: 0) {
            AddTaskNavigationBar(
                containerMode: containerMode,
                title: draft.isNew ? "New Area" : "Edit Area",
                canSave: canSave
            ) {
                onCancel()
            } onSave: {
                commit()
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    LifeManagementComposerPreviewCard(
                        eyebrow: draft.isNew ? "Create area" : "Edit area",
                        title: draft.name.nilIfBlank ?? "New area",
                        subtitle: "Define the bucket that holds related projects and habits.",
                        iconName: draft.iconSymbolName,
                        accentColor: lifeManagementResolvedColor(hex: draft.colorHex, fallback: Color.tasker.accentPrimary),
                        metrics: [
                            LifeManagementComposerPreviewMetric(title: "Accent", value: selectedColorTitle),
                            LifeManagementComposerPreviewMetric(title: "Icon", value: selectedIconTitle)
                        ]
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    AddTaskTitleField(
                        text: $draft.name,
                        isFocused: $titleFieldFocused,
                        placeholder: "Name this area",
                        helperText: "Use a clear bucket like Health, Career, or Home.",
                        onSubmit: commit
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    LifeManagementComposerSectionCard(
                        title: "Appearance",
                        subtitle: "Pick an accent and icon so the area is easy to spot across the app.",
                        iconSystemName: "paintpalette.fill"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            LifeManagementComposerFieldLabel(
                                title: "Accent",
                                detail: "Start with the Tasker palette, or switch to a custom hex when you need one."
                            )

                            LifeManagementAreaSwatchPicker(
                                selectedHex: $draft.colorHex,
                                showCustomField: $showCustomColorField
                            )

                            LifeManagementComposerFieldLabel(
                                title: "Icon",
                                detail: "Choose the symbol that best represents this part of your life."
                            )

                            LifeManagementAreaIconPicker(
                                iconOptions: iconOptions,
                                selectedSymbolName: $draft.iconSymbolName
                            )
                        }
                    }
                    .enhancedStaggeredAppearance(index: 2)

                    if showCustomColorField {
                        LifeManagementComposerSectionCard(
                            title: "Custom accent",
                            subtitle: "Paste a hex code to keep an existing area color or use a one-off accent.",
                            iconSystemName: "eyedropper.halffull"
                        ) {
                            TextField("Accent hex", text: $draft.colorHex)
                                .textFieldStyle(TaskerTextFieldStyle())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        .enhancedStaggeredAppearance(index: 3)
                    }

                    if let errorMessage {
                        LifeManagementComposerInlineMessage(
                            title: "Couldn’t save area",
                            message: errorMessage
                        )
                        .bellShake(trigger: $errorShakeTrigger)
                        .enhancedStaggeredAppearance(index: 4)
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s24)
            }

            AddTaskCreateButton(
                isEnabled: canSave,
                isLoading: isSaving,
                successFlash: false,
                showAddAnother: false,
                buttonTitle: draft.isNew ? "Add Area" : "Save Area",
                onCreateAction: commit,
                onAddAnotherAction: {}
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.tasker.bgCanvas)
        .taskerReadableContent(maxWidth: readableWidth, alignment: .center)
        .accessibilityIdentifier("settings.lifeManagement.areaComposer")
        .onAppear {
            guard containerMode == .sheet else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                titleFieldFocused = true
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil {
                errorShakeTrigger.toggle()
            }
        }
    }

    private func commit() {
        guard canSave else { return }
        onSave(draft)
    }
}

private struct LifeManagementProjectComposerView: View {
    @State private var draft: LifeManagementProjectDraft
    @State private var errorShakeTrigger = false
    @FocusState private var titleFieldFocused: Bool

    let lifeAreas: [LifeManagementAreaRow]
    let fallbackAreaRows: [LifeManagementAreaRow]
    let containerMode: AddTaskContainerMode
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (LifeManagementProjectDraft) -> Void
    let onCancel: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var readableWidth: CGFloat {
        switch containerMode {
        case .inspector:
            return layoutClass.isPad ? 860 : 760
        case .sheet:
            return 720
        }
    }

    private var availableAreas: [LifeManagementAreaRow] {
        lifeAreas.isEmpty ? fallbackAreaRows : lifeAreas
    }

    private var canSave: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isSaving
    }

    init(
        draft: LifeManagementProjectDraft,
        lifeAreas: [LifeManagementAreaRow],
        fallbackAreaRows: [LifeManagementAreaRow],
        containerMode: AddTaskContainerMode,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (LifeManagementProjectDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.lifeAreas = lifeAreas
        self.fallbackAreaRows = fallbackAreaRows
        self.containerMode = containerMode
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var selectedAreaName: String {
        availableAreas.first(where: { $0.id == draft.lifeAreaID })?.lifeArea.name ?? "No area yet"
    }

    var body: some View {
        VStack(spacing: 0) {
            AddTaskNavigationBar(
                containerMode: containerMode,
                title: draft.isNew ? "New Project" : "Edit Project",
                canSave: canSave
            ) {
                onCancel()
            } onSave: {
                commit()
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    LifeManagementComposerPreviewCard(
                        eyebrow: draft.isNew ? "Create project" : "Edit project",
                        title: draft.name.nilIfBlank ?? "New project",
                        subtitle: draft.description.nilIfBlank ?? "Projects group related tasks inside an area.",
                        iconName: draft.icon.systemImageName,
                        accentColor: lifeManagementResolvedColor(hex: draft.color.hexString, fallback: Color.tasker.accentPrimary),
                        metrics: [
                            LifeManagementComposerPreviewMetric(title: "Area", value: selectedAreaName),
                            LifeManagementComposerPreviewMetric(title: "Accent", value: draft.color.displayName)
                        ]
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    AddTaskTitleField(
                        text: $draft.name,
                        isFocused: $titleFieldFocused,
                        placeholder: "Name this project",
                        helperText: "Keep it specific enough that it still makes sense later.",
                        onSubmit: commit
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    LifeManagementComposerSectionCard(
                        title: "Essentials",
                        subtitle: "Set the project’s name, a short description, and where it belongs.",
                        iconSystemName: "text.alignleft"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            VStack(alignment: .leading, spacing: spacing.s8) {
                                LifeManagementComposerFieldLabel(
                                    title: "Description",
                                    detail: "Optional, but useful when the project name needs context."
                                )

                                TextField("What is this project for?", text: $draft.description, axis: .vertical)
                                    .textFieldStyle(TaskerTextFieldStyle())
                                    .lineLimit(3, reservesSpace: true)
                            }

                            AddTaskEntityPicker(
                                label: "Area",
                                items: availableAreas.map { (id: $0.id, name: $0.lifeArea.name, icon: $0.lifeArea.icon) },
                                selectedID: $draft.lifeAreaID
                            )
                        }
                    }
                    .enhancedStaggeredAppearance(index: 2)

                    LifeManagementComposerSectionCard(
                        title: "Appearance",
                        subtitle: "Choose an accent and icon that make this project easy to scan in lists.",
                        iconSystemName: "paintbrush.pointed.fill"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            LifeManagementComposerFieldLabel(
                                title: "Accent",
                                detail: "Project colors already map to the app’s built-in palette."
                            )

                            LifeManagementProjectColorPicker(selectedColor: $draft.color)

                            LifeManagementComposerFieldLabel(
                                title: "Icon",
                                detail: "Pick the symbol that fits this project best."
                            )

                            LifeManagementProjectIconPicker(selectedIcon: $draft.icon)
                        }
                    }
                    .enhancedStaggeredAppearance(index: 3)

                    if let errorMessage {
                        LifeManagementComposerInlineMessage(
                            title: "Couldn’t save project",
                            message: errorMessage
                        )
                        .bellShake(trigger: $errorShakeTrigger)
                        .enhancedStaggeredAppearance(index: 4)
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s24)
            }

            AddTaskCreateButton(
                isEnabled: canSave,
                isLoading: isSaving,
                successFlash: false,
                showAddAnother: false,
                buttonTitle: draft.isNew ? "Add Project" : "Save Project",
                onCreateAction: commit,
                onAddAnotherAction: {}
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.tasker.bgCanvas)
        .taskerReadableContent(maxWidth: readableWidth, alignment: .center)
        .accessibilityIdentifier("settings.lifeManagement.projectComposer")
        .onAppear {
            guard containerMode == .sheet else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                titleFieldFocused = true
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil {
                errorShakeTrigger.toggle()
            }
        }
    }

    private func commit() {
        guard canSave else { return }
        onSave(draft)
    }
}

private struct LifeManagementComposerPreviewMetric: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String { title }
}

private struct LifeManagementAreaPaletteOption: Identifiable, Equatable {
    let id: String
    let title: String
    let hex: String
    let systemImage: String?
}

private struct LifeManagementComposerPreviewCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    let metrics: [LifeManagementComposerPreviewMetric]

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var previewSignature: String {
        "\(title)-\(subtitle)-\(iconName)-\(metrics.map(\.value).joined(separator: "|"))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 58, height: 58)

                    Group {
                        if reduceMotion {
                            Image(systemName: iconName)
                        } else {
                            Image(systemName: iconName)
                                .symbolEffect(.bounce, value: previewSignature)
                        }
                    }
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(eyebrow)
                        .font(.tasker(.eyebrow))
                        .foregroundStyle(Color.white.opacity(0.78))

                    Text(title)
                        .font(.tasker(.title2).weight(.semibold))
                        .foregroundStyle(Color.white)
                        .contentTransition(.opacity)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.tasker(.callout))
                        .foregroundStyle(Color.white.opacity(0.84))
                        .contentTransition(.opacity)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if metrics.isEmpty == false {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: spacing.s8) {
                        ForEach(metrics) { metric in
                            LifeManagementComposerMetricTile(metric: metric)
                        }
                    }

                    VStack(spacing: spacing.s8) {
                        ForEach(metrics) { metric in
                            LifeManagementComposerMetricTile(metric: metric)
                        }
                    }
                }
            }
        }
        .padding(spacing.s16)
        .background(
            LinearGradient(
                colors: [
                    accentColor.opacity(0.92),
                    accentColor.opacity(0.58),
                    Color.tasker.surfacePrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.03),
                    Color.white.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: .clear,
            strokeColor: Color.white.opacity(0.16),
            accentColor: accentColor,
            level: .e2
        )
        .animation(reduceMotion ? nil : TaskerAnimation.heroEmphasis, value: previewSignature)
    }
}

private struct LifeManagementComposerMetricTile: View {
    let metric: LifeManagementComposerPreviewMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.white.opacity(0.72))

            Text(metric.value)
                .font(.tasker(.callout).weight(.semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct LifeManagementComposerSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let iconSystemName: String
    let content: Content

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    init(
        title: String,
        subtitle: String,
        iconSystemName: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s8) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.tasker.accentPrimary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)

                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(spacing.s16)
        .taskerDenseSurface(cornerRadius: TaskerTheme.CornerRadius.card, fillColor: Color.tasker.surfacePrimary)
    }
}

private struct LifeManagementComposerFieldLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.textPrimary)

            Text(detail)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
        }
    }
}

private struct LifeManagementComposerInlineMessage: View {
    let title: String
    let message: String

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.statusDanger)

            Text(message)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(spacing.s12)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.md,
            fillColor: Color.tasker.statusDanger.opacity(0.08),
            strokeColor: Color.tasker.statusDanger.opacity(0.18)
        )
    }
}

private struct LifeManagementAreaSwatchPicker: View {
    @Binding var selectedHex: String
    @Binding var showCustomField: Bool

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(lifeManagementAreaPaletteOptions()) { option in
                    LifeManagementColorSwatchButton(
                        title: option.title,
                        color: option.hex.nilIfBlank.flatMap { _ in lifeManagementResolvedColor(hex: option.hex, fallback: Color.tasker.surfaceSecondary) },
                        systemImage: option.systemImage,
                        isSelected: lifeManagementNormalizedHex(selectedHex) == lifeManagementNormalizedHex(option.hex) && showCustomField == false
                    ) {
                        withAnimation(TaskerAnimation.snappy) {
                            selectedHex = option.hex
                            showCustomField = false
                        }
                    }
                }

                LifeManagementColorSwatchButton(
                    title: "Custom",
                    color: nil,
                    systemImage: "eyedropper.halffull",
                    isSelected: showCustomField
                ) {
                    withAnimation(TaskerAnimation.snappy) {
                        showCustomField = true
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct LifeManagementProjectColorPicker: View {
    @Binding var selectedColor: ProjectColor

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(ProjectColor.allCases, id: \.rawValue) { color in
                    LifeManagementColorSwatchButton(
                        title: color.displayName,
                        color: lifeManagementResolvedColor(hex: color.hexString, fallback: Color.tasker.accentPrimary),
                        systemImage: nil,
                        isSelected: selectedColor == color
                    ) {
                        withAnimation(TaskerAnimation.snappy) {
                            selectedColor = color
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct LifeManagementColorSwatchButton: View {
    let title: String
    let color: Color?
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color ?? Color.tasker.surfaceSecondary)
                        .frame(width: 26, height: 26)

                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color == nil ? Color.tasker.textSecondary : Color.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.tasker.accentPrimary : Color.tasker.strokeHairline, lineWidth: isSelected ? 2 : 1)
                )

                Text(title)
                    .font(.tasker(.caption2))
                    .foregroundStyle(isSelected ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 74)
            .frame(minHeight: 76)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                    .fill(isSelected ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.tasker.accentMuted : Color.tasker.strokeHairline.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(reduceMotion ? nil : TaskerAnimation.quick, value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct LifeManagementAreaIconPicker: View {
    let iconOptions: [LifeAreaIconOption]
    @Binding var selectedSymbolName: String

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 88 : 74), spacing: spacing.s8)],
            spacing: spacing.s8
        ) {
            ForEach(iconOptions) { option in
                LifeManagementIconTile(
                    systemImage: option.symbolName,
                    title: option.keywords.first?.capitalized ?? option.symbolName,
                    isSelected: selectedSymbolName == option.symbolName
                ) {
                    withAnimation(TaskerAnimation.snappy) {
                        selectedSymbolName = option.symbolName
                    }
                }
            }
        }
    }
}

private struct LifeManagementProjectIconPicker: View {
    @Binding var selectedIcon: ProjectIcon

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 88 : 74), spacing: spacing.s8)],
            spacing: spacing.s8
        ) {
            ForEach(ProjectIcon.allCases, id: \.rawValue) { icon in
                LifeManagementIconTile(
                    systemImage: icon.systemImageName,
                    title: icon.displayName,
                    isSelected: selectedIcon == icon
                ) {
                    withAnimation(TaskerAnimation.snappy) {
                        selectedIcon = icon
                    }
                }
            }
        }
    }
}

private struct LifeManagementIconTile: View {
    let systemImage: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
                    .frame(height: 46)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
                    }

                Text(title)
                    .font(.tasker(.caption2))
                    .foregroundStyle(isSelected ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(8)
            .frame(minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                    .fill(Color.tasker.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.tasker.accentPrimary.opacity(0.34) : Color.tasker.strokeHairline.opacity(0.72), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

@MainActor
private func lifeManagementAreaPaletteOptions() -> [LifeManagementAreaPaletteOption] {
    let palette = TaskerThemeManager.shared.currentTheme.palette
    return [
        LifeManagementAreaPaletteOption(id: "default", title: "Default", hex: "", systemImage: "circle.dashed"),
        LifeManagementAreaPaletteOption(id: "sandstone", title: "Sandstone", hex: lifeManagementHexString(from: palette.brandSandstone), systemImage: nil),
        LifeManagementAreaPaletteOption(id: "emerald", title: "Emerald", hex: lifeManagementHexString(from: palette.brandEmerald), systemImage: nil),
        LifeManagementAreaPaletteOption(id: "magenta", title: "Magenta", hex: lifeManagementHexString(from: palette.brandMagenta), systemImage: nil),
        LifeManagementAreaPaletteOption(id: "marigold", title: "Marigold", hex: lifeManagementHexString(from: palette.brandMarigold), systemImage: nil),
        LifeManagementAreaPaletteOption(id: "red", title: "Red", hex: lifeManagementHexString(from: palette.brandRed), systemImage: nil)
    ]
}

@MainActor
private func lifeManagementAreaPaletteMatch(for hex: String) -> LifeManagementAreaPaletteOption? {
    let normalizedHex = lifeManagementNormalizedHex(hex)
    return lifeManagementAreaPaletteOptions().first { option in
        lifeManagementNormalizedHex(option.hex) == normalizedHex
    }
}

private func lifeManagementResolvedColor(hex: String?, fallback: Color) -> Color {
    guard let normalizedHex = lifeManagementResolvedHex(hex) else { return fallback }
    return Color(uiColor: UIColor(taskerHex: normalizedHex))
}

private func lifeManagementResolvedHex(_ hex: String?) -> String? {
    let normalized = lifeManagementNormalizedHex(hex ?? "")
    guard normalized.isEmpty == false, normalized.count == 6 || normalized.count == 8 else {
        return nil
    }
    return normalized
}

private func lifeManagementHexString(from color: UIColor) -> String {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
        return ""
    }

    let redValue = Int(round(red * 255))
    let greenValue = Int(round(green * 255))
    let blueValue = Int(round(blue * 255))
    return String(format: "%02X%02X%02X", redValue, greenValue, blueValue)
}

private func lifeManagementNormalizedHex(_ hex: String) -> String {
    hex.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "#", with: "")
        .uppercased()
}

private func lifeManagementAreaIconLabel(for symbolName: String, options: [LifeAreaIconOption]) -> String {
    options.first(where: { $0.symbolName == symbolName })?.keywords.first?.capitalized ?? symbolName
}

private struct ProjectMoveSheet: View {
    @State private var draft: LifeManagementProjectMoveDraft
    let targets: [LifeManagementAreaRow]
    let isSaving: Bool
    let onSave: (LifeManagementProjectMoveDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: LifeManagementProjectMoveDraft,
        targets: [LifeManagementAreaRow],
        isSaving: Bool,
        onSave: @escaping (LifeManagementProjectMoveDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.targets = targets
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    Text(draft.projectName)
                }

                Section("Move to Area") {
                    Picker("Area", selection: $draft.targetLifeAreaID) {
                        ForEach(targets) { target in
                            Text(target.lifeArea.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            .navigationTitle("Move Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        onSave(draft)
                    }
                    .disabled(isSaving || draft.targetLifeAreaID == nil)
                }
            }
        }
    }
}

private struct DeleteAreaSheet: View {
    @State private var draft: LifeManagementDeleteAreaDraft
    let targets: [LifeManagementAreaRow]
    let isSaving: Bool
    let onSave: (LifeManagementDeleteAreaDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: LifeManagementDeleteAreaDraft,
        targets: [LifeManagementAreaRow],
        isSaving: Bool,
        onSave: @escaping (LifeManagementDeleteAreaDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.targets = targets
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Delete Area") {
                    Text("\(draft.areaName) has \(draft.projectCount) projects and \(draft.habitCount) habits. Move them to another area before you delete it.")
                }

                Section("Move items to") {
                    Picker("Destination", selection: $draft.destinationLifeAreaID) {
                        ForEach(targets) { target in
                            Text(target.lifeArea.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            .navigationTitle("Delete Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete", role: .destructive) {
                        onSave(draft)
                    }
                    .disabled(isSaving || draft.destinationLifeAreaID == nil)
                }
            }
        }
    }
}

private struct DeleteProjectSheet: View {
    @State private var draft: LifeManagementDeleteProjectDraft
    let targets: [LifeManagementProjectRow]
    let isSaving: Bool
    let onSave: (LifeManagementDeleteProjectDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: LifeManagementDeleteProjectDraft,
        targets: [LifeManagementProjectRow],
        isSaving: Bool,
        onSave: @escaping (LifeManagementDeleteProjectDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.targets = targets
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Delete Project") {
                    Text("\(draft.projectName) has \(draft.taskCount) open tasks and \(draft.linkedHabitCount) linked habits. Move the open tasks before you delete it.")
                }

                Section("Move open tasks to") {
                    Picker("Project", selection: $draft.destinationProjectID) {
                        ForEach(targets) { target in
                            Text(target.project.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            .navigationTitle("Delete Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete", role: .destructive) {
                        onSave(draft)
                    }
                    .disabled(isSaving || draft.destinationProjectID == nil)
                }
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
