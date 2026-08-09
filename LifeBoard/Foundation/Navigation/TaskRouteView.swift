import SwiftUI
import SwiftData
import TranscriptionKit
import UIKit
import VisionKit

struct TaskRouteView: View {
    let id: UUID
    let dependencies: PlanFeatureDependencies
    let router: AppRouter
    @State private var store: TaskEditorStore
    @State private var confirmsDelete = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(id: UUID, dependencies: PlanFeatureDependencies, router: AppRouter) {
        self.id = id
        self.dependencies = dependencies
        self.router = router
        _store = State(initialValue: TaskEditorStore(taskID: id, dependencies: dependencies))
    }

    var body: some View {
        Group {
            switch store.loadState {
            case .loading:
                ProgressView("Opening task…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .missing:
                ContentUnavailableView(
                    "Task not found",
                    systemImage: "checkmark.circle.badge.questionmark",
                    description: Text("It may have been removed on another device.")
                )
            case .failed(let message):
                ContentUnavailableView {
                    Label("Task could not be opened", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await store.load() } }
                }
            case .ready:
                editor
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { _ = await store.save() } }
                    .disabled(store.hasUnsavedChanges == false && {
                        if case .failed = store.mutationState { return false }
                        return true
                    }())
                    .keyboardShortcut("s", modifiers: .command)
                    .accessibilityIdentifier("task.editor.save.toolbar")
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button("Open in Plan", systemImage: "calendar") { router.select(.plan) }
                    Button("Archive", systemImage: "archivebox") {
                        Task {
                            await store.archive()
                            if case .saved = store.mutationState { router.pop() }
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        confirmsDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Task actions")
            }
        }
        .task(id: id) { await load() }
        .safeAreaInset(edge: .bottom) {
            if store.loadState == .ready {
                VStack(spacing: 8) {
                    CommitControl(
                        title: "Save task",
                        runningTitle: "Saving task",
                        successTitle: "Task saved",
                        phase: store.commitPhase,
                        isEnabled: store.hasUnsavedChanges || {
                            if case .failed = store.mutationState { return true }
                            return false
                        }()
                    ) {
                        Task { _ = await store.save() }
                    }
                    .accessibilityIdentifier("task.editor.save")

                    if let receipt = store.activeReceipt {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
                            Text("Task updated")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Undo") { Task { await store.undo() } }
                                .font(.subheadline.weight(.bold))
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .background(.regularMaterial, in: Capsule())
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .scale(scale: 0.92, anchor: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                )
                        )
                        .animation(LifeBoardAnimation.contentInsertion, value: receipt.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        }
        .confirmationDialog(
            "Delete this task?",
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button("Delete task", role: .destructive) {
                Task {
                    await store.delete()
                    if case .saved = store.mutationState { router.pop() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The task is removed from every task view. The receipt can restore it without rebuilding a second task.")
        }
    }

    private var editor: some View {
        @Bindable var editor = store
        return ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("What needs doing?", text: $editor.draft.title, axis: .vertical)
                        .font(.title2.weight(.semibold))
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("task.editor.title")
                    TextField(
                        "Notes, links, or the useful context future-you will need",
                        text: Binding(
                            get: { editor.draft.details ?? "" },
                            set: { editor.draft.details = $0.isEmpty ? nil : $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(3...10)
                    .accessibilityIdentifier("task.editor.notes")
                }
                .taskEditorSurface()

                VStack(alignment: .leading, spacing: 16) {
                    TaskEditorControls.header("Shape the work", symbol: "slider.horizontal.3")
                    Picker("Project", selection: $editor.draft.projectID) {
                        ForEach(editor.projects, id: \.id) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                    .onChange(of: editor.draft.projectID) {
                        editor.draft.projectName = editor.projects.first {
                            $0.id == editor.draft.projectID
                        }?.name
                        if editor.sections.contains(where: {
                            $0.id == editor.draft.sectionID
                                && $0.projectID == editor.draft.projectID
                        }) == false {
                            editor.draft.sectionID = nil
                        }
                    }
                    Picker(
                        "Section",
                        selection: Binding(
                            get: { editor.draft.sectionID },
                            set: { editor.draft.sectionID = $0 }
                        )
                    ) {
                        Text("No section").tag(UUID?.none)
                        ForEach(
                            editor.sections.filter { $0.projectID == editor.draft.projectID },
                            id: \.id
                        ) { section in
                            Text(section.name).tag(Optional(section.id))
                        }
                    }
                    .disabled(
                        editor.sections.contains { $0.projectID == editor.draft.projectID } == false
                    )
                    .accessibilityIdentifier("task.editor.section")
                    Picker(
                        "Life area",
                        selection: Binding(
                            get: { editor.draft.lifeAreaID },
                            set: { editor.draft.lifeAreaID = $0 }
                        )
                    ) {
                        Text("No life area").tag(UUID?.none)
                        ForEach(editor.lifeAreas, id: \.id) { area in
                            Text(area.name).tag(Optional(area.id))
                        }
                    }
                    .disabled(editor.lifeAreas.isEmpty)
                    .accessibilityIdentifier("task.editor.life-area")
                    LabeledContent("Priority") {
                        Picker("Priority", selection: $editor.draft.priority) {
                            ForEach(TaskPriority.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                    LabeledContent("Energy") {
                        Picker("Energy", selection: $editor.draft.energy) {
                            ForEach(TaskEnergy.allCases, id: \.self) {
                                Text($0.rawValue.capitalized).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                    LabeledContent("Context") {
                        Picker("Context", selection: $editor.draft.context) {
                            ForEach(TaskContext.allCases, id: \.self) {
                                Text($0.rawValue.capitalized).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                    estimateControl(editor: $editor)
                }
                .taskEditorSurface()

                dateAndPlanning(editor: $editor)
                TaskEditorRecurrenceSection(editor: editor)
                TaskEditorRelationsSection(editor: editor)

                Toggle(isOn: Binding(
                    get: { editor.draft.isComplete },
                    set: {
                        editor.draft.isComplete = $0
                        editor.draft.dateCompleted = $0 ? Date() : nil
                    }
                )) {
                    Label(
                        editor.draft.isComplete ? "Completed" : "Mark complete",
                        systemImage: editor.draft.isComplete ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.headline)
                }
                .tint(Color(LifeBoardColorTokens.foundationSageAccent))
                .accessibilityIdentifier("task.editor.completion")
                .taskEditorSurface()

                if case .failed(let message) = store.mutationState {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationDanger))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .taskEditorSurface()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 70)
        }
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid).ignoresSafeArea())
    }

    private func dateAndPlanning(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            TaskEditorControls.header("Place it gently", symbol: "calendar")
            TaskEditorControls.optionalDate(
                "Deadline",
                value: Binding(
                    get: { editor.wrappedValue.draft.dueDate },
                    set: { editor.wrappedValue.draft.dueDate = $0 }
                )
            )
            TaskEditorControls.optionalPlanningDay(
                "Start day",
                value: Binding(
                    get: { editor.wrappedValue.planning.startDay },
                    set: { editor.wrappedValue.planning.startDay = $0 }
                )
            )
            TaskEditorControls.optionalPlanningDay(
                "Planned day",
                value: Binding(
                    get: { editor.wrappedValue.planning.planningDay },
                    set: { editor.wrappedValue.planning.planningDay = $0 }
                )
            )
            TaskEditorControls.optionalDate(
                "Scheduled start",
                value: Binding(
                    get: { editor.wrappedValue.draft.scheduledStartAt },
                    set: { newValue in
                        editor.wrappedValue.draft.scheduledStartAt = newValue
                        if let newValue, editor.wrappedValue.draft.scheduledEndAt == nil {
                            editor.wrappedValue.draft.scheduledEndAt = newValue.addingTimeInterval(
                                editor.wrappedValue.draft.estimatedDuration ?? 30 * 60
                            )
                        }
                    }
                ),
                components: [.date, .hourAndMinute]
            )
            TaskEditorControls.optionalDate(
                "Scheduled end",
                value: Binding(
                    get: { editor.wrappedValue.draft.scheduledEndAt },
                    set: { editor.wrappedValue.draft.scheduledEndAt = $0 }
                ),
                components: [.date, .hourAndMinute]
            )
            if let start = editor.wrappedValue.draft.scheduledStartAt,
               let end = editor.wrappedValue.draft.scheduledEndAt,
               end <= start {
                Label(
                    "Scheduled end must be after the start.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.foundationDanger))
                .accessibilityIdentifier("task.editor.schedule-error")
            }
        }
        .taskEditorSurface()
    }

    private func estimateControl(editor: Bindable<TaskEditorStore>) -> some View {
        let minutes = Int((editor.wrappedValue.draft.estimatedDuration ?? 0) / 60)
        return HStack {
            Text("Estimate")
            Spacer()
            Button {
                editor.wrappedValue.draft.estimatedDuration = max(0, minutes - 5) == 0
                    ? nil
                    : TimeInterval(max(0, minutes - 5) * 60)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Reduce estimate")
            Text(minutes == 0 ? "Not set" : "\(minutes) min")
                .font(.body.monospacedDigit())
                .frame(minWidth: 72)
            Button {
                editor.wrappedValue.draft.estimatedDuration = TimeInterval(max(5, minutes + 5) * 60)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Increase estimate")
        }
    }

    private func load() async {
        await store.load()
    }
}
