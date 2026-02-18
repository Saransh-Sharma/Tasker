//
//  TaskDetailSheetView.swift
//  Tasker
//
//  Restored shared legacy-style task detail sheet backed by V2 use cases.
//

import SwiftUI

// MARK: - Task Detail Sheet

private enum TaskDetailAutosaveState: Equatable {
    case idle
    case saving
    case saved
    case failed(String)

    var label: String {
        switch self {
        case .idle:
            return ""
        case .saving:
            return "Saving..."
        case .saved:
            return "Saved"
        case .failed(let message):
            return message
        }
    }

    @MainActor
    var color: Color {
        switch self {
        case .idle:
            return Color.clear
        case .saving:
            return Color.tasker.textTertiary
        case .saved:
            return Color.tasker.statusSuccess
        case .failed:
            return Color.tasker.statusDanger
        }
    }
}

struct TaskDetailSheetView: View {
    typealias UpdateHandler = (UpdateTaskRequest, @escaping (Result<DomainTask, Error>) -> Void) -> Void
    typealias CompletionHandler = (Bool, @escaping (Result<DomainTask, Error>) -> Void) -> Void
    typealias DeleteHandler = (@escaping (Result<Void, Error>) -> Void) -> Void
    typealias RescheduleHandler = (Date, @escaping (Result<DomainTask, Error>) -> Void) -> Void

    let task: DomainTask
    let projects: [Project]
    let onUpdate: UpdateHandler
    let onSetCompletion: CompletionHandler
    let onDelete: DeleteHandler
    let onReschedule: RescheduleHandler

    @Environment(\.dismiss) private var dismiss

    @State private var persistedTask: DomainTask
    @State private var taskName: String
    @State private var taskDescription: String
    @State private var taskPriorityRaw: Int32
    @State private var taskTypeRaw: Int32
    @State private var selectedProjectID: UUID
    @State private var dueDate: Date?
    @State private var reminderTime: Date?
    @State private var isComplete: Bool

    @State private var isEditingTitle = false
    @State private var isEditingDescription = false
    @State private var showDatePicker = false
    @State private var showReminderPicker = false
    @State private var showPriorityPicker = false
    @State private var showProjectPicker = false
    @State private var showTypePicker = false

    @State private var autosaveWorkItem: DispatchWorkItem?
    @State private var isSaving = false
    @State private var needsSaveAfterCurrentRequest = false
    @State private var suppressAutosave = false
    @State private var autosaveState: TaskDetailAutosaveState = .idle

    private let textAutosaveDebounceSeconds: TimeInterval = 0.4

    init(
        task: DomainTask,
        projects: [Project],
        onUpdate: @escaping UpdateHandler,
        onSetCompletion: @escaping CompletionHandler,
        onDelete: @escaping DeleteHandler,
        onReschedule: @escaping RescheduleHandler
    ) {
        self.task = task
        self.projects = projects
        self.onUpdate = onUpdate
        self.onSetCompletion = onSetCompletion
        self.onDelete = onDelete
        self.onReschedule = onReschedule

        _persistedTask = State(initialValue: task)
        _taskName = State(initialValue: task.name)
        _taskDescription = State(initialValue: task.details ?? "")
        _taskPriorityRaw = State(initialValue: task.priority.rawValue)
        _taskTypeRaw = State(initialValue: task.type.rawValue)
        _selectedProjectID = State(initialValue: task.projectID)
        _dueDate = State(initialValue: task.dueDate)
        _reminderTime = State(initialValue: task.alertReminderTime)
        _isComplete = State(initialValue: task.isComplete)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(priorityColor)
                    .frame(height: 4)

                headerSection
                    .staggeredAppearance(index: 0)

                if autosaveState != .idle {
                    Text(autosaveState.label)
                        .font(.tasker(.caption2))
                        .foregroundColor(autosaveState.color)
                        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
                        .padding(.bottom, TaskerTheme.Spacing.sm)
                }

                quickInfoRow
                    .staggeredAppearance(index: 1)

                descriptionSection
                    .staggeredAppearance(index: 2)

                TaskDetailSectionDivider("Details")
                    .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
                    .padding(.top, TaskerTheme.Spacing.lg)
                    .staggeredAppearance(index: 3)

                editableFieldsSection
                    .staggeredAppearance(index: 4)

                actionSection
                    .staggeredAppearance(index: 5)

                metadataFooter
                    .staggeredAppearance(index: 6)
            }
        }
        .background(Color.tasker.bgCanvas)
        .presentationDragIndicator(.visible)
        .onChange(of: taskName) { _ in
            scheduleAutosave(debounced: true)
        }
        .onChange(of: taskDescription) { _ in
            scheduleAutosave(debounced: true)
        }
        .onChange(of: taskPriorityRaw) { _ in
            scheduleAutosave(debounced: false)
        }
        .onChange(of: taskTypeRaw) { _ in
            scheduleAutosave(debounced: false)
        }
        .onChange(of: selectedProjectID) { _ in
            scheduleAutosave(debounced: false)
        }
        .onChange(of: dueDate) { _ in
            scheduleAutosave(debounced: false)
        }
        .onChange(of: reminderTime) { _ in
            scheduleAutosave(debounced: false)
        }
        .onDisappear {
            autosaveWorkItem?.cancel()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: TaskerTheme.Spacing.md) {
                CompletionCheckbox(isComplete: isComplete) {
                    toggleCompletion()
                }

                if isEditingTitle {
                    TextField("Task name", text: $taskName)
                        .font(.tasker(.title2))
                        .foregroundColor(Color.tasker.textPrimary)
                        .textFieldStyle(.plain)
                        .onSubmit { isEditingTitle = false }
                } else {
                    Text(taskName.isEmpty ? "Untitled Task" : taskName)
                        .font(.tasker(.title2))
                        .foregroundColor(isComplete ? Color.tasker.textTertiary : Color.tasker.textPrimary)
                        .strikethrough(isComplete, color: Color.tasker.textTertiary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .onTapGesture { isEditingTitle = true }
                }
            }

            HStack(spacing: TaskerTheme.Spacing.sm) {
                PriorityBadge(priority: taskPriorityRaw)
                ScoreBadge(points: TaskPriority(rawValue: taskPriorityRaw).scorePoints)

                Spacer()

                Text(selectedProjectName)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.accentPrimary)
                    .padding(.horizontal, TaskerTheme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.tasker.accentMuted)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.top, TaskerTheme.Spacing.lg)
        .padding(.bottom, TaskerTheme.Spacing.md)
    }

    private var quickInfoRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TaskerTheme.Spacing.sm) {
                if let dueDate {
                    InfoPill(
                        icon: "calendar",
                        text: DateUtils.formatDate(dueDate),
                        color: dueDateColor(for: dueDate)
                    )
                }

                InfoPill(
                    icon: taskTypeIcon,
                    text: taskTypeLabel,
                    color: Color.tasker.textSecondary
                )

                if let reminderTime {
                    InfoPill(
                        icon: "bell.fill",
                        text: formatTime(reminderTime),
                        color: Color.tasker.accentPrimary
                    )
                }

                if isComplete, let completedDate = persistedTask.dateCompleted {
                    InfoPill(
                        icon: "checkmark",
                        text: "Done \(DateUtils.formatDate(completedDate))",
                        color: Color.tasker.statusSuccess
                    )
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        }
        .padding(.bottom, TaskerTheme.Spacing.md)
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            if isEditingDescription {
                TextEditor(text: $taskDescription)
                    .font(.tasker(.body))
                    .foregroundColor(Color.tasker.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80, maxHeight: 160)
                    .padding(TaskerTheme.Spacing.md)
                    .background(Color.tasker.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md)
                            .stroke(Color.tasker.accentRing, lineWidth: 2)
                    )
            } else {
                Group {
                    if taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Add a description...")
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker.textQuaternary)
                            .italic()
                    } else {
                        Text(taskDescription)
                            .font(.tasker(.body))
                            .foregroundColor(Color.tasker.textSecondary)
                            .lineLimit(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TaskerTheme.Spacing.lg)
                .background(Color.tasker.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md)
                        .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                )
                .onTapGesture { isEditingDescription = true }
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var editableFieldsSection: some View {
        VStack(spacing: 0) {
            dueDateRow

            Divider()
                .foregroundColor(Color.tasker.strokeHairline)

            priorityRow

            Divider()
                .foregroundColor(Color.tasker.strokeHairline)

            projectRow

            Divider()
                .foregroundColor(Color.tasker.strokeHairline)

            typeRow

            Divider()
                .foregroundColor(Color.tasker.strokeHairline)

            reminderRow
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    private var dueDateRow: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "calendar", label: "Due Date", action: {
                withAnimation(TaskerAnimation.snappy) {
                    showDatePicker.toggle()
                    showReminderPicker = false
                }
            }) {
                if let dueDate {
                    Text(DateUtils.formatDate(dueDate))
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(dueDateColor(for: dueDate))
                } else {
                    Text("Not set")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.textTertiary)
                }
            }

            if showDatePicker {
                DatePicker(
                    "Due Date",
                    selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(Color.tasker.accentPrimary)
                .padding(.bottom, TaskerTheme.Spacing.md)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    private var priorityRow: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "flag.fill", iconColor: priorityColor, label: "Priority", action: {
                withAnimation(TaskerAnimation.snappy) {
                    showPriorityPicker.toggle()
                }
            }) {
                Text(priorityLabel)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(priorityColor)
            }

            if showPriorityPicker {
                PriorityPillSelector(selectedPriority: $taskPriorityRaw)
                    .padding(.bottom, TaskerTheme.Spacing.md)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    private var projectRow: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "folder.fill", label: "Project", action: {
                withAnimation(TaskerAnimation.snappy) {
                    showProjectPicker.toggle()
                }
            }) {
                Text(selectedProjectName)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
            }

            if showProjectPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TaskerTheme.Spacing.sm) {
                        ForEach(projectOptions, id: \.id) { project in
                            TaskerChip(
                                title: project.name,
                                isSelected: selectedProjectID == project.id,
                                selectedStyle: .tinted
                            ) {
                                withAnimation(TaskerAnimation.snappy) {
                                    selectedProjectID = project.id
                                }
                                TaskerFeedback.selection()
                            }
                        }
                    }
                }
                .padding(.bottom, TaskerTheme.Spacing.md)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    private var typeRow: some View {
        VStack(spacing: 0) {
            DetailRow(icon: taskTypeIcon, label: "Type", action: {
                withAnimation(TaskerAnimation.snappy) {
                    showTypePicker.toggle()
                }
            }) {
                Text(taskTypeLabel)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
            }

            if showTypePicker {
                TypeChipSelector(selectedType: $taskTypeRaw)
                    .padding(.bottom, TaskerTheme.Spacing.md)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    private var reminderRow: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "bell.fill", label: "Reminder", action: {
                withAnimation(TaskerAnimation.snappy) {
                    showReminderPicker.toggle()
                    showDatePicker = false
                }
            }) {
                if let reminderTime {
                    Text(formatTime(reminderTime))
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.accentPrimary)
                } else {
                    Text("Not set")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.textTertiary)
                }
            }

            if showReminderPicker {
                DatePicker(
                    "Reminder",
                    selection: Binding(
                        get: { reminderTime ?? Date() },
                        set: { reminderTime = $0 }
                    ),
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .tint(Color.tasker.accentPrimary)
                .frame(height: 120)
                .padding(.bottom, TaskerTheme.Spacing.md)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    private var actionSection: some View {
        VStack(spacing: TaskerTheme.Spacing.md) {
            if let dueDate {
                Button(action: {
                    applyReschedule(to: dueDate)
                }) {
                    HStack(spacing: TaskerTheme.Spacing.sm) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 14, weight: .bold))
                        Text("Apply Reschedule")
                            .font(.tasker(.button))
                    }
                    .foregroundColor(Color.tasker.accentOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.tasker.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
                }
                .scaleOnPress()
            }

            Button(action: {
                toggleCompletion()
            }) {
                HStack(spacing: TaskerTheme.Spacing.sm) {
                    Image(systemName: isComplete ? "arrow.uturn.backward" : "checkmark.circle")
                        .font(.system(size: 14, weight: .bold))
                    Text(isComplete ? "Mark Incomplete" : "Mark Complete")
                        .font(.tasker(.button))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(isComplete ? Color.tasker.statusWarning : Color.tasker.statusSuccess)
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
            }
            .scaleOnPress()

            Button(action: deleteTask) {
                Text("Delete Task")
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.statusDanger)
            }
            .padding(.top, TaskerTheme.Spacing.xs)
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.top, TaskerTheme.Spacing.xl)
    }

    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            Text("Added \(DateUtils.formatDateTime(persistedTask.dateAdded))")
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)

            if isComplete, let dateCompleted = persistedTask.dateCompleted {
                Text("Completed \(DateUtils.formatDateTime(dateCompleted))")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.top, TaskerTheme.Spacing.lg)
        .padding(.bottom, TaskerTheme.Spacing.xxxl)
    }

    private var projectOptions: [Project] {
        var ordered: [Project] = []
        var seen = Set<UUID>()

        let inbox = projects.first(where: { $0.id == ProjectConstants.inboxProjectID }) ?? Project.createInbox()
        ordered.append(inbox)
        seen.insert(inbox.id)

        for project in projects.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            guard seen.contains(project.id) == false else { continue }
            ordered.append(project)
            seen.insert(project.id)
        }

        return ordered
    }

    private var selectedProjectName: String {
        projectOptions.first(where: { $0.id == selectedProjectID })?.name
            ?? persistedTask.project
            ?? ProjectConstants.inboxProjectName
    }

    private var priorityColor: Color {
        switch taskPriorityRaw {
        case 1: return Color.tasker.priorityNone
        case 2: return Color.tasker.priorityLow
        case 3: return Color.tasker.priorityHigh
        case 4: return Color.tasker.priorityMax
        default: return Color.tasker.priorityLow
        }
    }

    private var priorityLabel: String {
        switch taskPriorityRaw {
        case 1: return "None"
        case 2: return "Low"
        case 3: return "High"
        case 4: return "Max"
        default: return "Low"
        }
    }

    private var taskTypeIcon: String {
        switch taskTypeRaw {
        case 1: return "sunrise.fill"
        case 2: return "moon.fill"
        case 3: return "calendar.badge.clock"
        case 4: return "tray.fill"
        default: return "sunrise.fill"
        }
    }

    private var taskTypeLabel: String {
        switch taskTypeRaw {
        case 1: return "Morning"
        case 2: return "Evening"
        case 3: return "Upcoming"
        case 4: return "Inbox"
        default: return "Morning"
        }
    }

    private func scheduleAutosave(debounced: Bool) {
        guard suppressAutosave == false else { return }

        autosaveWorkItem?.cancel()

        if isSaving {
            needsSaveAfterCurrentRequest = true
            return
        }

        let workItem = DispatchWorkItem {
            performAutosave()
        }
        autosaveWorkItem = workItem

        if debounced {
            DispatchQueue.main.asyncAfter(deadline: .now() + textAutosaveDebounceSeconds, execute: workItem)
        } else {
            DispatchQueue.main.async(execute: workItem)
        }
    }

    private func performAutosave() {
        guard suppressAutosave == false else { return }

        let trimmedTitle = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedTitle.isEmpty == false else {
            autosaveState = .failed("Task name cannot be empty")
            return
        }

        guard let request = makeUpdateRequest() else {
            autosaveState = .saved
            return
        }

        autosaveState = .saving
        isSaving = true

        onUpdate(request) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success(let updatedTask):
                    syncDraftFromTask(updatedTask)
                    autosaveState = .saved

                case .failure(let error):
                    autosaveState = .failed(error.localizedDescription)
                }

                if needsSaveAfterCurrentRequest {
                    needsSaveAfterCurrentRequest = false
                    scheduleAutosave(debounced: false)
                }
            }
        }
    }

    private func makeUpdateRequest() -> UpdateTaskRequest? {
        let trimmedName = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDetails = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let detailsForStorage: String? = normalizedDetails.isEmpty ? nil : taskDescription

        let priority = TaskPriority(rawValue: taskPriorityRaw)
        let type = TaskType(rawValue: taskTypeRaw)

        var name: String?
        var details: String?
        var priorityChange: TaskPriority?
        var typeChange: TaskType?
        var dueDateChange: Date?
        var projectID: UUID?
        var projectName: String?
        var reminderChange: Date?

        if trimmedName != persistedTask.name {
            name = trimmedName
        }

        if detailsForStorage != persistedTask.details {
            // Empty string requests a clear in UpdateTaskUseCase.
            details = detailsForStorage ?? ""
        }

        if priority != persistedTask.priority {
            priorityChange = priority
        }

        if type != persistedTask.type {
            typeChange = type
        }

        if areDatesDifferent(dueDate, persistedTask.dueDate), let dueDate {
            dueDateChange = dueDate
        }

        if selectedProjectID != persistedTask.projectID || selectedProjectName != (persistedTask.project ?? ProjectConstants.inboxProjectName) {
            projectID = selectedProjectID
            projectName = selectedProjectName
        }

        if areDatesDifferent(reminderTime, persistedTask.alertReminderTime), let reminderTime {
            reminderChange = reminderTime
        }

        let request = UpdateTaskRequest(
            name: name,
            details: details,
            type: typeChange,
            priority: priorityChange,
            dueDate: dueDateChange,
            projectID: projectID,
            projectName: projectName,
            alertReminderTime: reminderChange
        )

        let hasChanges =
            name != nil ||
            details != nil ||
            priorityChange != nil ||
            typeChange != nil ||
            dueDateChange != nil ||
            projectID != nil ||
            projectName != nil ||
            reminderChange != nil

        return hasChanges ? request : nil
    }

    private func toggleCompletion() {
        let requested = !isComplete
        withAnimation(TaskerAnimation.bouncy) {
            isComplete = requested
        }

        onSetCompletion(requested) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedTask):
                    syncDraftFromTask(updatedTask)
                    autosaveState = .saved
                    TaskerFeedback.success()

                case .failure(let error):
                    withAnimation(TaskerAnimation.bouncy) {
                        isComplete.toggle()
                    }
                    autosaveState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func deleteTask() {
        onDelete { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    TaskerFeedback.success()
                    dismiss()
                case .failure(let error):
                    autosaveState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func applyReschedule(to date: Date) {
        onReschedule(date) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedTask):
                    syncDraftFromTask(updatedTask)
                    autosaveState = .saved
                    TaskerFeedback.success()
                case .failure(let error):
                    autosaveState = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func syncDraftFromTask(_ updatedTask: DomainTask) {
        suppressAutosave = true
        persistedTask = updatedTask
        taskName = updatedTask.name
        taskDescription = updatedTask.details ?? ""
        taskPriorityRaw = updatedTask.priority.rawValue
        taskTypeRaw = updatedTask.type.rawValue
        selectedProjectID = updatedTask.projectID
        dueDate = updatedTask.dueDate
        reminderTime = updatedTask.alertReminderTime
        isComplete = updatedTask.isComplete
        DispatchQueue.main.async {
            suppressAutosave = false
        }
    }

    private func dueDateColor(for date: Date) -> Color {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return Color.tasker.statusWarning
        } else if date < Date() {
            return Color.tasker.statusDanger
        } else if calendar.isDateInTomorrow(date) {
            return Color.tasker.accentPrimary
        } else {
            return Color.tasker.textSecondary
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func areDatesDifferent(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case let (left?, right?):
            return abs(left.timeIntervalSince(right)) > 0.5
        default:
            return true
        }
    }
}
