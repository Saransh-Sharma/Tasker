import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct TaskRouteView: View {
    let id: UUID
    let dependencies: PlanFeatureDependencies
    let router: AppRouter
    @State private var store: TaskEditorStore
    @State private var confirmsDelete = false
    @State private var expandedFields: Set<String> = []
    @State private var dismissedReceiptID: UUID?
    /// Title and notes each get their own focus value — they shared one `Bool`,
    /// which gave "focus the notes" no defined target — so Return on the title
    /// can hand the keyboard to the notes.
    private enum EditorField: Hashable { case title, notes }
    @FocusState private var textFocus: EditorField?
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
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .missing:
                StatusSurface(
                    state: .unavailable,
                    title: "Task not found",
                    message: String(localized: "It may have been deleted.")
                )
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn’t open task", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message).foregroundColor(Color(SemanticColorTokens.inkSecondary))
                } actions: {
                    Button("Try again") { Task { await store.load() } }
                }
            case .ready:
                editor
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    // Reschedule to tomorrow in two taps from anywhere a task
                    // opens, keeping a time of day when the task has one.
                    Button(DecisionDestination.tomorrow.title, systemImage: DecisionDestination.tomorrow.systemImage) {
                        Task { await moveToTomorrow() }
                    }
                    .accessibilityIdentifier("task.editor.tomorrow")
                    // "Open in Plan" only switched tabs and left Plan on
                    // whatever day it was showing. It now lands on this task's
                    // day, and is offered only when the task has one.
                    if let day = plannedDay {
                        Button("Show in Plan", systemImage: "calendar") {
                            showInPlan(day)
                        }
                        .accessibilityIdentifier("task.editor.showInPlan")
                    }
                    Button("Archive", systemImage: "archivebox") {
                        Task {
                            let title = store.draft.task.title
                            await store.archive()
                            guard case .saved = store.mutationState else { return }
                            handOffReceipt(String(localized: "Archived \u{201C}\(title)\u{201D}"))
                            router.pop()
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        confirmsDelete = true
                    }
                    .accessibilityIdentifier("task.editor.delete")
                } label: {
                    // A titled label, not a bare image: the toolbar still draws
                    // only the icon, but on iPhone this item folds into the
                    // navigation bar's overflow menu, where an untitled menu
                    // was listed as a second, meaningless "More".
                    Label("Task actions", systemImage: "ellipsis.circle")
                }
                .accessibilityIdentifier("task.editor.actions")
            }
        }
        .task(id: id) { await load() }
        .onChange(of: store.draft) { old, new in
            var previous = old
            previous.title = new.title
            previous.details = new.details
            store.scheduleAutosave(textOnly: previous == new)
        }
        .onChange(of: textFocus) { _, focus in
            if focus == nil { Task { await store.flushAutosave() } }
        }
        .onDisappear { Task { await store.flushAutosave() } }
        .safeAreaInset(edge: .bottom) {
            if store.loadState == .ready {
                VStack(spacing: 8) {
                    // Autosave is quiet while it works: a spinner on every pause
                    // in typing made the editor flicker. Only a failure speaks up,
                    // and it keeps the person's text and offers the retry.
                    if case .failed(let message) = store.mutationState {
                        HStack(spacing: 12) {
                            Text(message)
                                .lifeboardFont(.support)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button("Try again") { Task { await store.flushAutosave() } }
                                .lifeboardFont(.buttonSmall)
                                .frame(minHeight: 44)
                        }
                        .padding(.horizontal, 16)
                        .lifeBoardClaySurface(.floating, cornerRadius: Radius.card)
                    }
                    if let receipt = store.activeReceipt, receipt.id != dismissedReceiptID {
                        // One bar that updates in place as edits save, on the
                        // shared receipt so Undo behaves as it does everywhere.
                        ReceiptBar(
                            ActionReceiptPresentation(id: receipt.id, message: "Task updated"),
                            undo: { Task { await store.undo() } },
                            destination: nil,
                            onDismiss: { dismissedReceiptID = receipt.id }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion), value: store.activeReceipt?.id)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .confirmationDialog(
            "Delete this task?",
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button("Delete task", role: .destructive) {
                Task {
                    let title = store.draft.task.title
                    await store.delete()
                    guard case .saved = store.mutationState else { return }
                    handOffReceipt(String(localized: "Deleted \u{201C}\(title)\u{201D}"))
                    router.pop()
                }
            }
            .accessibilityIdentifier("task.editor.delete.confirm")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You can undo this.")
        }
    }
}

extension TaskRouteView {
    /// This screen pops after archiving or deleting, so its own receipt would
    /// vanish; the shell keeps the Undo reachable. The store stays alive inside
    /// the closure because its receipt is what reverses the change.
    private func handOffReceipt(_ message: String) {
        let store = store
        router.shellReceipt = ShellReceipt(message: message) {
            await store.undo()
            if case .failed = store.mutationState { return false }
            return true
        }
    }

    /// The day this task is planned for, timed or not.
    private var plannedDay: PlanningDay? {
        if let start = store.draft.scheduledStartAt { return PlanningDay(date: start) }
        return store.planning.planningDay
    }

    private func showInPlan(_ day: PlanningDay) {
        Haptic.pick.play()
        Task {
            await store.flushAutosave()
            PlanDayHandoff.request(day)
            router.popToRoot(in: .plan)
            router.select(.plan)
        }
    }

    private func moveToTomorrow() async {
        let calendar = Calendar.current
        let draft = store.draft
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
        let selection: TaskWhenSelection
        if let start = draft.scheduledStartAt {
            // Same time of day, tomorrow — whichever day it was on before.
            let time = calendar.dateComponents([.hour, .minute], from: start)
            let moved = calendar.date(
                bySettingHour: time.hour ?? 9,
                minute: time.minute ?? 0,
                second: 0,
                of: tomorrow
            ) ?? tomorrow
            selection = .timed(moved)
        } else {
            selection = .day(tomorrow)
        }
        store.draft = selection.applying(to: draft)
        await store.flushAutosave()
        if case .failed = store.mutationState {
            Haptic.fail.play()
        } else {
            Haptic.commit.play()
            UIAccessibility.post(notification: .announcement, argument: String(localized: "Moved to Tomorrow"))
        }
    }

    private var editor: some View {
        @Bindable var editor = store
        return ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Task name", text: $editor.draft.title, prompt: Text("Task name").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                        .font(.title2.weight(.semibold))
                        .textInputAutocapitalization(.sentences)
                        .focused($textFocus, equals: .title)
                        // A title never holds a newline: Return moves on to notes.
                        .returnKey(.next, text: $editor.draft.title) { textFocus = .notes }
                        .accessibilityIdentifier("task.editor.title")
                    TextField(
                        "Notes",
                        text: Binding(
                            get: { editor.draft.details ?? "" },
                            set: { editor.draft.details = $0.isEmpty ? nil : $0 }
                        ),
                        // The default placeholder measured 1.7:1 on paper.
                        prompt: Text("Notes")
                            .foregroundColor(Color(SemanticColorTokens.inkSecondary)),
                        axis: .vertical
                    )
                    .lineLimit(3...10)
                    .focused($textFocus, equals: .notes)
                    .keyboardBar(focus: $textFocus, equals: .notes)
                    .accessibilityIdentifier("task.editor.notes")
                }
                .taskEditorSurface()

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TaskEditorChipCopy.fields, id: \.self) { field in
                            let value = TaskEditorChipCopy.value(
                                for: field,
                                draft: editor.draft,
                                projectName: editor.projects.first { $0.id == editor.draft.projectID }?.name,
                                tagNames: editor.tags.filter { editor.draft.tagIDs.contains($0.id) }.map(\.name)
                            )
                            Button {
                                Haptic.pick.play()
                                withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                                    if expandedFields.contains(field) { expandedFields.remove(field) }
                                    else { expandedFields.insert(field) }
                                }
                            } label: {
                                // A chip with a value reads the value ("Fri 3 PM");
                                // an empty one names the field it would add.
                                Label(value ?? field, systemImage: value == nil ? "plus" : TaskEditorChipCopy.symbol(for: field))
                                    .foregroundStyle(Color(value == nil ? SemanticColorTokens.inkSecondary : SemanticColorTokens.inkPrimary))
                            }
                            .buttonStyle(.lifeBoardChip)
                            .accessibilityLabel(value.map { "\(field), \($0)" } ?? "Add \(field.lowercased())")
                            .accessibilityIdentifier("task.editor.chip.\(field.lowercased())")
                        }
                    }
                }
                if expandedFields.contains("When") || editor.planning.planningDay != nil || editor.draft.scheduledStartAt != nil {
                    TaskWhenEditor(store: editor)
                }
                if expandedFields.contains("Deadline") || editor.draft.dueDate != nil {
                    TaskEditorControls.optionalDate("Deadline", value: $editor.draft.dueDate)
                }
                if expandedFields.contains("Duration") || editor.draft.estimatedDuration != nil {
                    estimateControl(editor: $editor)
                }
                if expandedFields.contains("Project") || editor.draft.projectID != ProjectConstants.inboxProjectID {
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
                }
                if expandedFields.contains("Priority") || editor.draft.priority != .low {
                    LabeledContent("Priority") {
                        Picker("Priority", selection: $editor.draft.priority) {
                            ForEach(TaskPriority.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                }
                if expandedFields.contains("Tags") || !editor.draft.tagIDs.isEmpty {
                    TaskEditorRelationsSection(editor: editor, tagsOnly: true)
                }
                if expandedFields.contains("Repeat") || editor.draft.repeatPattern != nil {
                    TaskEditorRecurrenceSection(editor: editor)
                }
                DisclosureGroup("More") {
                VStack(alignment: .leading, spacing: 16) {
                    TaskEditorControls.header("Details", symbol: "slider.horizontal.3")
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
                    LabeledContent("Energy") {
                        Picker("Energy", selection: $editor.draft.energy) {
                            ForEach(TaskEnergy.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                    LabeledContent("Context") {
                        Picker("Context", selection: $editor.draft.context) {
                            ForEach(TaskContext.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        .labelsHidden()
                    }

                }
                .taskEditorSurface()

                TaskEditorRelationsSection(editor: editor, showsTags: false)
                }

                // Commit-first: the switch moves at once, the write follows, and a
                // failed write puts it back with `Haptic.fail`. The success
                // haptic plays only once the completion is persisted. Kept a
                // switch (not `CompletionControl`) because the UI suite reads
                // "task.editor.completion" as a switch with a 0/1 value.
                Toggle(isOn: Binding(
                    get: { editor.draft.isComplete },
                    set: { commitCompletion($0) }
                )) {
                    Label(
                        editor.draft.isComplete ? "Completed" : "Mark complete",
                        systemImage: editor.draft.isComplete ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.headline)
                }
                .tint(Color(SemanticColorTokens.foundationSageInk))
                .accessibilityIdentifier("task.editor.completion")
                .taskEditorSurface()

                if case .failed(let message) = store.mutationState {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Color(SemanticColorTokens.foundationDanger))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .taskEditorSurface()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 70)
        }
        .background(Color(SemanticColorTokens.foundationSurfaceSolid).ignoresSafeArea())
    }

    private func commitCompletion(_ isComplete: Bool) {
        let previous = store.draft
        store.draft.isComplete = isComplete
        store.draft.dateCompleted = isComplete ? Date() : nil
        Task {
            await store.flushAutosave()
            if case .failed = store.mutationState {
                store.draft.isComplete = previous.isComplete
                store.draft.dateCompleted = previous.dateCompleted
                Haptic.fail.play()
            } else if isComplete {
                Haptic.commit.play()
            } else {
                Haptic.pick.play()
            }
        }
    }

    /// Preset lengths, not a 5-minute stepper: getting to two hours took
    /// twenty-four taps.
    private static let estimatePresets = [15, 30, 45, 60, 120]

    private func estimateControl(editor: Bindable<TaskEditorStore>) -> some View {
        let minutes = Int(((editor.wrappedValue.draft.estimatedDuration ?? 0) / 60).rounded())
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Estimate")
                Spacer()
                Text(minutes == 0 ? "Not set" : LifeBoardDuration.text(minutes: minutes))
                    .monospacedDigit()
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.estimatePresets, id: \.self) { preset in
                        let isSelected = minutes == preset
                        Button {
                            Haptic.pick.play()
                            editor.wrappedValue.draft.estimatedDuration = isSelected ? nil : TimeInterval(preset * 60)
                        } label: {
                            Text(LifeBoardDuration.text(minutes: preset))
                                .foregroundStyle(Color(isSelected ? SemanticColorTokens.inkPrimary : SemanticColorTokens.inkSecondary))
                        }
                        .buttonStyle(.lifeBoardChip)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityHint(isSelected ? "Clears the estimate" : "")
                        .accessibilityIdentifier("task.editor.estimate.\(preset)")
                    }
                }
            }
        }
    }

    private func load() async {
        await store.load()
    }
}

private struct TaskWhenEditor: View {
    @Bindable var store: TaskEditorStore
    private var date: Date {
        store.draft.scheduledStartAt ?? store.planning.planningDay?.startDate(calendar: .current) ?? Date()
    }
    private var mode: Int {
        store.draft.scheduledStartAt != nil ? 2 : (store.planning.planningDay != nil ? 1 : 0)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("When", selection: Binding(get: { mode }, set: { value in
                let start = store.draft.scheduledStartAt ?? TaskWhenSelection.defaultStart(on: date)
                store.draft = (value == 0 ? TaskWhenSelection.anytime : value == 1 ? .day(date) : .timed(start)).applying(to: store.draft)
            })) {
                Text("Anytime").tag(0)
                Text("Day").tag(1)
                Text("Day + time").tag(2)
            }.pickerStyle(.segmented)
            if mode != 0 {
                DatePicker("When", selection: Binding(get: { date }, set: { value in
                    store.draft = (mode == 2 ? TaskWhenSelection.timed(value) : .day(value)).applying(to: store.draft)
                }), displayedComponents: mode == 2 ? [.date, .hourAndMinute] : [.date])
            }
        }
        .accessibilityIdentifier("task.editor.when")
    }
}

/// What each chip in the task editor says. Pure so the wording is tested.
enum TaskEditorChipCopy {
    static let fields = ["When", "Deadline", "Duration", "Project", "Tags", "Priority", "Repeat"]

    static func value(
        for field: String,
        draft: TaskEditorDraft,
        projectName: String?,
        tagNames: [String],
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> String? {
        switch field {
        case "When":
            if let start = draft.scheduledStartAt {
                return "\(dayLabel(start, calendar: calendar, now: now)) \(start.formatted(date: .omitted, time: .shortened))"
            }
            if let day = draft.planning.planningDay?.startDate(calendar: calendar) {
                return dayLabel(day, calendar: calendar, now: now)
            }
            return nil
        case "Deadline":
            return draft.dueDate.map { "Due \(dayLabel($0, calendar: calendar, now: now))" }
        case "Duration":
            guard let seconds = draft.estimatedDuration, seconds > 0 else { return nil }
            return LifeBoardDuration.text(seconds: seconds)
        case "Project":
            guard draft.projectID != ProjectConstants.inboxProjectID else { return nil }
            return projectName
        case "Tags":
            guard let first = tagNames.sorted().first else { return nil }
            return tagNames.count == 1 ? "#\(first)" : "#\(first) +\(tagNames.count - 1)"
        case "Priority":
            return draft.priority == .low ? nil : draft.priority.displayName
        case "Repeat":
            return draft.repeatPattern == nil ? nil : "Repeats"
        default:
            return nil
        }
    }

    static func symbol(for field: String) -> String {
        switch field {
        case "When": "calendar"
        case "Deadline": "flag"
        case "Duration": "hourglass"
        case "Project": "folder"
        case "Tags": "number"
        case "Priority": "exclamationmark"
        default: "repeat"
        }
    }

    private static func dayLabel(_ date: Date, calendar: Calendar, now: Date) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "Today" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
