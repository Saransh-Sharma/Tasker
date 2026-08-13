import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct ProjectRouteView: View {
    private enum DisplayMode: String, CaseIterable {
        case list = "List"
        case board = "Board"
    }

    let id: UUID
    let dependencies: PlanFeatureDependencies
    let router: AppRouter
    @State private var state: RouteLoadState<ProjectExecutionSnapshot> = .loading
    @State private var displayMode: DisplayMode = .list
    @State private var showsMilestoneComposer = false
    @State private var milestoneTitle = ""
    @State private var lastReceiptID: UUID?
    @State private var taskBatchReceipt: TaskBatchReceipt?
    @State private var archivedProjectSnapshot: Project?

    var body: some View {
        EntityRouteScaffold(title: "Project", systemImage: "folder", state: state) { tasks in
            VStack(alignment: .leading, spacing: 16) {
                projectHeader(tasks)
                Picker("Project view", selection: $displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("project.mode")

                milestones(tasks)

                ProjectTaskListSection(
                    snapshot: tasks,
                    projectID: id,
                    displaysBoard: displayMode != .list,
                    router: router,
                    move: { task, offset in
                        Task { await move(task, offset: offset, snapshot: tasks) }
                    },
                    moveToSection: { task, sectionID in
                        Task { await moveToSection(task, sectionID: sectionID, snapshot: tasks) }
                    }
                )
            }
        }
        .task(id: id) { await load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add milestone", systemImage: "flag") {
                        milestoneTitle = ""
                        showsMilestoneComposer = true
                    }
                    Button("Open in Plan", systemImage: "calendar") { router.select(.plan) }
                    Button("Archive project", systemImage: "archivebox") {
                        Task { await archiveProject() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Project actions")
            }
        }
        .sheet(isPresented: $showsMilestoneComposer) {
            NavigationStack {
                Form {
                    TextField("Milestone", text: $milestoneTitle)
                    Text("A milestone marks progress; it never appears as a task in Today.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("New Milestone")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showsMilestoneComposer = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await saveMilestone() }
                        }
                        .disabled(milestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if lastReceiptID != nil
                || taskBatchReceipt != nil
                || archivedProjectSnapshot != nil {
                HStack {
                    Text(projectReceiptMessage)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Undo") { Task { await undoLastProjectAction() } }
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 52)
                .background(.regularMaterial, in: Capsule())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private func load() async {
        state = .loading
        do {
            async let sections = fetchSections()
            async let milestones = dependencies.projectMilestoneRepository.milestones(projectID: id)
            guard let snapshot = try await dependencies.taskExecutionProjection.projectSnapshot(
                projectID: id,
                completedTaskCount: 0,
                sections: sections,
                milestones: milestones
            ) else {
                state = .missing
                return
            }
            state = .loaded(snapshot)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func projectHeader(_ snapshot: ProjectExecutionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.name)
                        .font(.title2.weight(.semibold))
                    Text(projectStatus(snapshot))
                        .font(.subheadline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer()
                if let fraction = snapshot.completionFraction {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
            }
            if let fraction = snapshot.completionFraction {
                ProgressView(value: fraction)
                    .tint(Color(SemanticColorTokens.foundationSageAccent))
            }
            if let next = snapshot.nextAction {
                Button {
                    router.push(.taskDetail(next.id), in: .plan)
                } label: {
                    HStack {
                        Label("Next: \(next.title)", systemImage: "arrow.right.circle.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .taskEditorSurface()
    }

    private func milestones(_ snapshot: ProjectExecutionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Milestones", systemImage: "flag")
                    .font(.headline)
                Spacer()
                Button("Add", systemImage: "plus") {
                    milestoneTitle = ""
                    showsMilestoneComposer = true
                }
                .font(.subheadline.weight(.semibold))
            }
            if snapshot.milestones.isEmpty {
                Text("No milestones yet")
                    .font(.subheadline)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            } else {
                ForEach(snapshot.milestones) { milestone in
                    HStack(spacing: 10) {
                        Button {
                            Task { await toggleMilestone(milestone) }
                        } label: {
                            Image(systemName: milestone.isComplete ? "checkmark.circle.fill" : "circle")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            milestone.isComplete ? "Mark \(milestone.title) incomplete" : "Complete \(milestone.title)"
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(milestone.title)
                                .strikethrough(milestone.isComplete)
                            if let target = milestone.targetDay?.startDate() {
                                Text(target.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .taskEditorSurface()
    }

    private func fetchSections() async throws -> [ProjectSectionDefinition] {
        guard let repository = dependencies.sectionRepository else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            repository.fetchSections(projectID: id) { continuation.resume(with: $0) }
        }
    }

    private func saveMilestone() async {
        let title = milestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return }
        do {
            let existing = try await dependencies.projectMilestoneRepository.milestones(projectID: id)
            try await dependencies.projectMilestoneRepository.saveMilestone(
                ProjectMilestone(projectID: id, title: title, sortOrder: existing.count)
            )
            showsMilestoneComposer = false
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func toggleMilestone(_ milestone: ProjectMilestone) async {
        var changed = milestone
        changed.completedAt = milestone.isComplete ? nil : Date()
        do {
            try await dependencies.projectMilestoneRepository.saveMilestone(changed)
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func move(
        _ task: PlanningTaskSummary,
        offset: Int,
        snapshot: ProjectExecutionSnapshot
    ) async {
        var ordered = ProjectTaskListSection.ordered(snapshot)
        guard
            let source = ordered.firstIndex(where: { $0.id == task.id }),
            ordered.indices.contains(source + offset)
        else { return }
        ordered.swapAt(source, source + offset)
        let mutations = ordered.enumerated().map { index, item in
            var after = item.metadata
            after.pinOrder = index
            after.updatedAt = Date()
            return PlanMutation.saveTaskMetadata(before: item.metadata, after: after)
        }
        do {
            let receipt = try await dependencies.planningRepository.prepare(
                .batch(mutations),
                source: "project.manual-order.\(id.uuidString)",
                summary: "Reordered \(snapshot.name)"
            )
            try await dependencies.planningRepository.apply(receiptID: receipt.id)
            lastReceiptID = receipt.id
            taskBatchReceipt = nil
            archivedProjectSnapshot = nil
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func archiveProject() async {
        do {
            let project = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Project?, any Error>) in
                dependencies.projectRepository.fetchProject(withId: id) {
                    continuation.resume(with: $0)
                }
            }
            guard var project else { return }
            archivedProjectSnapshot = project
            project.isArchived = true
            project.status = .onHold
            project.modifiedDate = Date()
            _ = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Project, any Error>) in
                dependencies.projectRepository.updateProject(project) {
                    continuation.resume(with: $0)
                }
            }
            lastReceiptID = nil
            taskBatchReceipt = nil
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func undoLastProjectAction() async {
        do {
            if let taskBatchReceipt {
                try await dependencies.taskBatchMutationCoordinator.undo(taskBatchReceipt)
                self.taskBatchReceipt = nil
            }
            if let receiptID = lastReceiptID {
                try await dependencies.planningRepository.undo(receiptID: receiptID)
                lastReceiptID = nil
            }
            if let project = archivedProjectSnapshot {
                _ = try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Project, any Error>) in
                    dependencies.projectRepository.updateProject(project) {
                        continuation.resume(with: $0)
                    }
                }
                archivedProjectSnapshot = nil
            }
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func moveToSection(
        _ task: PlanningTaskSummary,
        sectionID: UUID?,
        snapshot: ProjectExecutionSnapshot
    ) async {
        guard snapshot.sectionIDByTaskID[task.id] != sectionID else { return }
        do {
            taskBatchReceipt = try await dependencies.taskBatchMutationCoordinator.apply(
                TaskBatchMutationRequest(
                    taskIDs: [task.id],
                    mutation: .move(
                        projectID: id,
                        projectName: snapshot.name,
                        sectionID: sectionID
                    ),
                    source: "project.section-move.\(id.uuidString)"
                )
            )
            lastReceiptID = nil
            archivedProjectSnapshot = nil
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private var projectReceiptMessage: String {
        if archivedProjectSnapshot != nil { return "Project archived" }
        if taskBatchReceipt != nil { return "Task moved" }
        return "Project reordered"
    }

    private func projectStatus(_ snapshot: ProjectExecutionSnapshot) -> String {
        if snapshot.isArchived { return "Archived" }
        if snapshot.isBlocked { return "Blocked — no task is ready yet" }
        if let milestone = snapshot.nextMilestone { return "Next milestone: \(milestone.title)" }
        return snapshot.tasks.isEmpty ? "A quiet project" : "\(snapshot.completedTaskCount) completed"
    }

}
