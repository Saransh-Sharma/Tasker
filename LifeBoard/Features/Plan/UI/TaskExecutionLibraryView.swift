import SwiftUI
import UIKit

/// The production surface for every canonical task scope.
///
/// This intentionally lives inside Plan rather than becoming a sixth root.
/// `TaskExecutionStore` supplies every row and count, and selection routes to
/// the same task editor used by project, Home, search, and deep links.
struct TaskExecutionLibraryView: View {
    @Bindable var store: TaskExecutionStore
    let batchCoordinator: TaskBatchMutationCoordinator
    let projectRepository: any ProjectRepositoryProtocol
    let sectionRepository: (any SectionRepositoryProtocol)?
    let tagRepository: any TagRepositoryProtocol
    let onOpenTask: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var projects: [Project] = []
    @State private var sectionsByProjectID: [UUID: [LifeBoardProjectSection]] = [:]
    @State private var tags: [TagDefinition] = []
    @State private var isApplyingBatch = false
    @State private var batchReceipt: TaskBatchReceipt?
    @State private var batchError: String?
    @State private var destructiveMutation: TaskBatchMutation?

    var body: some View {
        List(selection: $selectedTaskIDs) {
            Section {
                Picker("Task view", selection: $store.query.scope) {
                    ForEach(TaskExecutionQuery.Scope.allCases, id: \.self) { scope in
                        Text(scope.titleWithCount(store.counts[scope]))
                            .tag(scope)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("plan.taskLibrary.scope")
            }

            switch store.state {
            case .loading where store.tasks.isEmpty:
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading tasks…")
                        Spacer()
                    }
                    .frame(minHeight: 88)
                }
            case .empty:
                Section {
                    ContentUnavailableView(
                        store.query.scope.emptyTitle,
                        systemImage: store.query.scope.emptySymbol,
                        description: Text(store.query.scope.emptyDetail)
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            case .failed(let message):
                Section {
                    ContentUnavailableView {
                        Label("Tasks couldn’t be loaded", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { Task { await store.load() } }
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            case .permissionDenied:
                Section {
                    ContentUnavailableView(
                        "Task access unavailable",
                        systemImage: "lock",
                        description: Text("LifeBoard can’t read this task view right now.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
            case .stale(let lastUpdatedAt):
                taskRows
                Section {
                    Label(
                        "Showing tasks from \(lastUpdatedAt.formatted(date: .omitted, time: .shortened))",
                        systemImage: "clock.arrow.circlepath"
                    )
                    .font(.footnote)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
            case .loaded, .loading:
                taskRows
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
                    .accessibilityIdentifier("plan.taskLibrary.select")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if selectedTaskIDs.isEmpty == false {
                TaskExecutionBatchActionBar(
                    selectionCount: selectedTaskIDs.count,
                    scope: store.query.scope,
                    tags: tags,
                    projects: projects,
                    sectionsByProjectID: sectionsByProjectID,
                    isApplyingBatch: isApplyingBatch,
                    applyBatch: applyBatch,
                    destructiveMutation: $destructiveMutation
                )
            } else if let batchReceipt {
                batchUndoBar(batchReceipt)
            }
        }
        .task {
            async let loadTasks: Void = store.load()
            async let loadChoices: Void = loadBatchChoices()
            _ = await (loadTasks, loadChoices)
        }
        .onChange(of: store.query) {
            selectedTaskIDs.removeAll()
            Task { await store.load() }
        }
        .refreshable { await store.load() }
        .alert(
            "Batch action couldn’t finish",
            isPresented: Binding(
                get: { batchError != nil },
                set: { if $0 == false { batchError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { batchError = nil }
        } message: {
            Text(batchError ?? "")
        }
        .confirmationDialog(
            destructiveTitle,
            isPresented: Binding(
                get: { destructiveMutation != nil },
                set: { if $0 == false { destructiveMutation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let destructiveMutation {
                Button(destructiveActionTitle, role: .destructive) {
                    applyBatch(destructiveMutation)
                    self.destructiveMutation = nil
                }
            }
            Button("Cancel", role: .cancel) { destructiveMutation = nil }
        } message: {
            Text("This applies once to every selected task and can be undone as one action.")
        }
        .accessibilityIdentifier("plan.taskLibrary")
    }

    @ViewBuilder
    private var taskRows: some View {
        Section(store.query.scope.sectionTitle) {
            ForEach(store.tasks) { task in
                Button {
                    onOpenTask(task.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: store.query.scope == .completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(
                                store.query.scope == .completed
                                    ? Color(LifeBoardColorTokens.foundationSageAccent)
                                    : Color(LifeBoardColorTokens.inkSecondary)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                                .multilineTextAlignment(.leading)
                            Text(taskMetadata(task))
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tag(task.id)
                .accessibilityHint("Opens the canonical task editor")
                .accessibilityAction(
                    named: selectedTaskIDs.contains(task.id)
                        ? "Remove from batch selection"
                        : "Add to batch selection"
                ) {
                    if selectedTaskIDs.contains(task.id) {
                        selectedTaskIDs.remove(task.id)
                    } else {
                        selectedTaskIDs.insert(task.id)
                    }
                }
                .accessibilityIdentifier("plan.taskLibrary.task.\(task.id.uuidString)")
            }
        }
    }

    private func batchUndoBar(_ receipt: TaskBatchReceipt) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            Text(receiptSummary(receipt))
                .font(.subheadline)
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            Spacer()
            Button("Undo") { undoBatch(receipt) }
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .disabled(isApplyingBatch)
                .accessibilityIdentifier("plan.taskLibrary.batch.undo")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private var destructiveTitle: String {
        switch destructiveMutation {
        case .archive: "Archive selected tasks?"
        case .delete: "Delete selected tasks?"
        default: "Apply to selected tasks?"
        }
    }

    private var destructiveActionTitle: String {
        switch destructiveMutation {
        case .archive: "Archive Tasks"
        case .delete: "Delete Tasks"
        default: "Apply"
        }
    }

    private func applyBatch(_ mutation: TaskBatchMutation) {
        let taskIDs = selectedTaskIDs
        guard taskIDs.isEmpty == false, isApplyingBatch == false else { return }
        isApplyingBatch = true
        Task {
            do {
                let receipt = try await batchCoordinator.apply(
                    TaskBatchMutationRequest(
                        taskIDs: taskIDs,
                        mutation: mutation,
                        source: "plan.task-library"
                    )
                )
                batchReceipt = receipt
                selectedTaskIDs.removeAll()
                await store.load()
            } catch {
                batchError = error.localizedDescription
            }
            isApplyingBatch = false
        }
    }

    private func undoBatch(_ receipt: TaskBatchReceipt) {
        guard isApplyingBatch == false else { return }
        isApplyingBatch = true
        Task {
            do {
                try await batchCoordinator.undo(receipt)
                batchReceipt = nil
                await store.load()
            } catch {
                batchError = error.localizedDescription
            }
            isApplyingBatch = false
        }
    }

    private func receiptSummary(_ receipt: TaskBatchReceipt) -> String {
        let count = receipt.before.count
        return "\(count) task\(count == 1 ? "" : "s") updated"
    }

    private func loadBatchChoices() async {
        async let loadedProjects = withCheckedContinuation {
            (continuation: CheckedContinuation<[Project], Never>) in
            projectRepository.fetchAllProjects { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
        async let loadedTags = withCheckedContinuation {
            (continuation: CheckedContinuation<[TagDefinition], Never>) in
            tagRepository.fetchAll { result in
                continuation.resume(returning: (try? result.get()) ?? [])
            }
        }
        projects = await loadedProjects
            .filter { $0.isArchived == false }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        tags = await loadedTags
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        guard let sectionRepository else {
            sectionsByProjectID = [:]
            return
        }
        var loadedSections: [UUID: [LifeBoardProjectSection]] = [:]
        for project in projects {
            let values = await withCheckedContinuation {
                (continuation: CheckedContinuation<[LifeBoardProjectSection], Never>) in
                sectionRepository.fetchSections(projectID: project.id) { result in
                    continuation.resume(returning: (try? result.get()) ?? [])
                }
            }
            loadedSections[project.id] = values.sorted { $0.sortOrder < $1.sortOrder }
        }
        sectionsByProjectID = loadedSections
    }

    private func taskMetadata(_ task: PlanningTaskSummary) -> String {
        var values: [String] = []
        if let day = task.metadata.planningDay?.startDate() {
            values.append(day.formatted(date: .abbreviated, time: .omitted))
        }
        if let due = task.dueDate {
            values.append("Due \(due.formatted(date: .abbreviated, time: .omitted))")
        }
        if let estimate = task.estimatedDuration {
            let minutes = max(1, Int((estimate / 60).rounded()))
            values.append(minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m")
        }
        if task.dependenciesReady == false { values.append("Waiting on dependency") }
        return values.isEmpty ? "No date or estimate" : values.joined(separator: " · ")
    }
}

private extension TaskExecutionQuery.Scope {
    func titleWithCount(_ count: Int?) -> String {
        guard let count else { return sectionTitle }
        return "\(sectionTitle) (\(count))"
    }

    var sectionTitle: String {
        switch self {
        case .inbox: "Inbox"
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .waiting: "Waiting"
        case .someday: "Someday"
        case .completed: "Completed"
        case .all: "All"
        }
    }

    var emptyTitle: String {
        switch self {
        case .inbox: "Inbox clear"
        case .today: "A spacious day"
        case .upcoming: "Nothing queued ahead"
        case .waiting: "Nothing waiting"
        case .someday: "Someday is open"
        case .completed: "No completed tasks yet"
        case .all: "No tasks yet"
        }
    }

    var emptyDetail: String {
        switch self {
        case .inbox: "Every filed task has somewhere to be."
        case .today: "Choose something intentionally when you’re ready."
        case .upcoming: "Future planned work will appear here."
        case .waiting: "Blocked and delegated work will appear here."
        case .someday: "Ideas you deliberately set aside will appear here."
        case .completed: "Finished work remains available without crowding Today."
        case .all: "Captured and planned work will appear here."
        }
    }

    var emptySymbol: String {
        switch self {
        case .inbox: "tray"
        case .today: "sun.max"
        case .upcoming: "calendar"
        case .waiting: "hourglass"
        case .someday: "sparkles"
        case .completed: "checkmark.circle"
        case .all: "checklist"
        }
    }
}
