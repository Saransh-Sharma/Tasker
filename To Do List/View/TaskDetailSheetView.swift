//
//  TaskDetailSheetView.swift
//  Tasker
//
//  Premium "Gem Card" task detail sheet.
//  Matches the Obsidian & Gems design language with inline editing,
//  medium-detent presentation, and full token-system integration.
//

import SwiftUI
import CoreData

// MARK: - Task Detail Sheet View

struct TaskDetailSheetView: View {
    let task: NTask
    let projectNames: [String]
    var onSave: (() -> Void)?
    var onToggleComplete: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onDelete: (() -> Void)?

    // MARK: - Editable State

    @State private var taskName: String
    @State private var taskDescription: String
    @State private var taskPriority: Int32
    @State private var taskType: Int32
    @State private var selectedProject: String
    @State private var dueDate: Date?
    @State private var reminderTime: Date?
    @State private var isComplete: Bool

    // MARK: - UI State

    @State private var isEditingTitle = false
    @State private var isEditingDescription = false
    @State private var showDatePicker = false
    @State private var showReminderPicker = false
    @State private var showPriorityPicker = false
    @State private var showProjectPicker = false
    @State private var showTypePicker = false
    @State private var hasChanges = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Init

    init(
        task: NTask,
        projectNames: [String],
        onSave: (() -> Void)? = nil,
        onToggleComplete: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.task = task
        self.projectNames = projectNames
        self.onSave = onSave
        self.onToggleComplete = onToggleComplete
        self.onDismiss = onDismiss
        self.onDelete = onDelete

        _taskName = State(initialValue: task.name ?? "")
        _taskDescription = State(initialValue: task.taskDetails ?? "")
        _taskPriority = State(initialValue: task.taskPriority)
        _taskType = State(initialValue: task.taskType)
        _selectedProject = State(initialValue: task.project ?? "Inbox")
        _dueDate = State(initialValue: task.dueDate as Date?)
        _reminderTime = State(initialValue: task.alertReminderTime as Date?)
        _isComplete = State(initialValue: task.isComplete)
    }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                priorityAccentBar
                    .staggeredAppearance(index: 0)

                headerSection
                    .staggeredAppearance(index: 1)

                quickInfoRow
                    .staggeredAppearance(index: 2)

                descriptionSection
                    .staggeredAppearance(index: 3)

                TaskDetailSectionDivider("Details")
                    .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
                    .padding(.top, TaskerTheme.Spacing.lg)
                    .staggeredAppearance(index: 4)

                editableFieldsSection
                    .staggeredAppearance(index: 5)

                actionSection
                    .staggeredAppearance(index: 6)

                metadataFooter
                    .staggeredAppearance(index: 7)
            }
        }
        .background(Color.tasker.bgCanvas)
        .presentationDragIndicator(.visible)
        .onChange(of: taskName) { hasChanges = true }
        .onChange(of: taskDescription) { hasChanges = true }
        .onChange(of: taskPriority) { hasChanges = true }
        .onChange(of: taskType) { hasChanges = true }
        .onChange(of: selectedProject) { hasChanges = true }
        .onChange(of: dueDate) { hasChanges = true }
        .onChange(of: reminderTime) { hasChanges = true }
    }

    // MARK: - Priority Accent Bar

    private var priorityAccentBar: some View {
        Rectangle()
            .fill(priorityColor)
            .frame(height: 4)
            .animation(TaskerAnimation.snappy, value: taskPriority)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            // Checkbox + Title row
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

            // Badges row
            HStack(spacing: TaskerTheme.Spacing.sm) {
                PriorityBadge(priority: taskPriority)
                ScoreBadge(points: scorePoints)

                Spacer()

                // Project chip
                Text(selectedProject)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.accentPrimary)
                    .padding(.horizontal, TaskerTheme.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Color.tasker.accentWash)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.top, TaskerTheme.Spacing.lg)
        .padding(.bottom, TaskerTheme.Spacing.md)
    }

    // MARK: - Quick Info Row

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

                if reminderTime != nil {
                    InfoPill(
                        icon: "bell.fill",
                        text: formatTime(reminderTime!),
                        color: Color.tasker.accentPrimary
                    )
                }

                if isComplete, let completedDate = task.dateCompleted as Date? {
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

    // MARK: - Description Section

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
                    if taskDescription.isEmpty {
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

    // MARK: - Editable Fields Section

    private var editableFieldsSection: some View {
        VStack(spacing: 0) {
            // Due Date
            dueDateRow

            Divider()
                .foregroundColor(Color.tasker.strokeHairline)

            // Priority
            priorityRow

            Divider()
                .foregroundColor(Color.tasker.strokeHairline)

            // Project
            projectRow

            Divider()
                .foregroundColor(Color.tasker.strokeHairline)

            // Task Type
            typeRow

            Divider()
                .foregroundColor(Color.tasker.strokeHairline)

            // Reminder
            reminderRow
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
    }

    // MARK: - Due Date Row

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
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(Color.tasker.accentPrimary)
                .padding(.bottom, TaskerTheme.Spacing.md)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    // MARK: - Priority Row

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
                PriorityPillSelector(selectedPriority: $taskPriority)
                    .padding(.bottom, TaskerTheme.Spacing.md)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    // MARK: - Project Row

    private var projectRow: some View {
        VStack(spacing: 0) {
            DetailRow(icon: "folder.fill", label: "Project", action: {
                withAnimation(TaskerAnimation.snappy) {
                    showProjectPicker.toggle()
                }
            }) {
                Text(selectedProject)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
            }

            if showProjectPicker {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TaskerTheme.Spacing.sm) {
                        ForEach(projectNames, id: \.self) { name in
                            TaskerChip(
                                title: name,
                                isSelected: selectedProject == name,
                                selectedStyle: .tinted
                            ) {
                                withAnimation(TaskerAnimation.snappy) {
                                    selectedProject = name
                                }
                                TaskerHaptic.selection()
                            }
                        }
                    }
                }
                .padding(.bottom, TaskerTheme.Spacing.md)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    // MARK: - Type Row

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
                TypeChipSelector(selectedType: $taskType)
                    .padding(.bottom, TaskerTheme.Spacing.md)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    // MARK: - Reminder Row

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

    // MARK: - Action Section

    private var actionSection: some View {
        VStack(spacing: TaskerTheme.Spacing.md) {
            // Save button (visible when changes detected)
            if hasChanges {
                Button(action: saveChanges) {
                    HStack(spacing: TaskerTheme.Spacing.sm) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Save Changes")
                            .font(.tasker(.button))
                    }
                    .foregroundColor(Color.tasker.accentOnPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color.tasker.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md))
                }
                .scaleOnPress()
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // Complete / Incomplete toggle
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

            // Delete button
            if onDelete != nil {
                Button(action: { onDelete?() }) {
                    Text("Delete Task")
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.statusDanger)
                }
                .padding(.top, TaskerTheme.Spacing.xs)
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
        .padding(.top, TaskerTheme.Spacing.xl)
    }

    // MARK: - Metadata Footer

    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            if let dateAdded = task.dateAdded as Date? {
                Text("Added \(DateUtils.formatDateTime(dateAdded))")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textTertiary)
            }

            if isComplete, let dateCompleted = task.dateCompleted as Date? {
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

    // MARK: - Save Logic

    private func saveChanges() {
        guard !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let resolvedProject = resolveProjectSelection(for: selectedProject)
        let oldProjectID = task.projectID
        let oldPriority = task.taskPriority
        let oldType = task.taskType
        let oldDueDate = task.dueDate as Date?

        task.name = taskName
        task.taskDetails = taskDescription.isEmpty ? nil : taskDescription
        task.taskPriority = taskPriority
        task.taskType = taskType
        task.project = resolvedProject.name
        task.projectID = resolvedProject.id
        task.dueDate = dueDate as NSDate?
        task.alertReminderTime = reminderTime as NSDate?
        task.isEveningTask = taskType == 2

        do {
            try task.managedObjectContext?.save()
            hasChanges = false
            TaskerHaptic.success()
            var mutationReasons: [HomeTaskMutationEvent] = []
            if oldProjectID != resolvedProject.id {
                mutationReasons.append(.projectChanged)
            }
            if oldPriority != taskPriority {
                mutationReasons.append(.priorityChanged)
            }
            if oldType != taskType {
                mutationReasons.append(.typeChanged)
            }
            if oldDueDate != dueDate {
                mutationReasons.append(.dueDateChanged)
            }
            if mutationReasons.isEmpty {
                mutationReasons = [.updated]
            }
            for reason in mutationReasons {
                NotificationCenter.default.post(
                    name: .homeTaskMutation,
                    object: nil,
                    userInfo: ["reason": reason.rawValue]
                )
            }
            onSave?()
        } catch {
            logError(
                event: "task_detail_save_failed",
                message: "Failed to save task details",
                fields: [
                    "task_id": task.taskID?.uuidString ?? "nil",
                    "error": error.localizedDescription
                ]
            )
        }
    }

    private func toggleCompletion() {
        withAnimation(TaskerAnimation.bouncy) {
            isComplete.toggle()
        }

        task.isComplete = isComplete
        task.dateCompleted = isComplete ? Date() as NSDate : nil

        do {
            try task.managedObjectContext?.save()
            TaskerHaptic.success()
            NotificationCenter.default.post(
                name: .homeTaskMutation,
                object: nil,
                userInfo: [
                    "reason": (isComplete ? HomeTaskMutationEvent.completed : HomeTaskMutationEvent.reopened).rawValue
                ]
            )
            onToggleComplete?()
        } catch {
            logError(
                event: "task_detail_toggle_failed",
                message: "Failed to toggle task completion",
                fields: [
                    "task_id": task.taskID?.uuidString ?? "nil",
                    "error": error.localizedDescription
                ]
            )
        }
    }

    private func resolveProjectSelection(for projectName: String) -> (name: String, id: UUID, source: String) {
        let trimmed = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = ProjectConstants.inboxProjectName
        let fallbackID = ProjectConstants.inboxProjectID

        guard let context = task.managedObjectContext else {
            let selectedName = trimmed.isEmpty ? fallbackName : trimmed
            logWarning(
                event: "task_detail_project_context_missing",
                message: "Task context unavailable while resolving project; using fallback",
                fields: ["project_id": fallbackID.uuidString]
            )
            return (selectedName, fallbackID, "no_context")
        }

        if !trimmed.isEmpty {
            let byNameRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
            byNameRequest.fetchLimit = 1
            byNameRequest.predicate = NSPredicate(format: "projectName =[c] %@", trimmed)
            if let project = try? context.fetch(byNameRequest).first,
               let projectID = project.projectID {
                let resolvedName = project.projectName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = (resolvedName?.isEmpty == false) ? (resolvedName ?? trimmed) : trimmed
                return (name, projectID, "matched_name")
            }
        }

        let inboxRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
        inboxRequest.fetchLimit = 1
        inboxRequest.predicate = NSPredicate(format: "projectID == %@", fallbackID as CVarArg)
        if let inbox = try? context.fetch(inboxRequest).first,
           let inboxID = inbox.projectID {
            let name = inbox.projectName ?? fallbackName
            return (name, inboxID, "inbox_entity")
        }

        let selectedName = trimmed.isEmpty ? fallbackName : trimmed
        logWarning(
            event: "task_detail_project_fallback",
            message: "Project resolution fallback used Inbox project",
            fields: ["project_id": fallbackID.uuidString]
        )
        return (selectedName, fallbackID, "inbox_fallback")
    }

    // MARK: - Computed Helpers

    private var priorityColor: Color {
        switch taskPriority {
        case 1: return Color.tasker.priorityMax
        case 2: return Color.tasker.priorityHigh
        case 3: return Color.tasker.priorityLow
        case 4: return Color.tasker.priorityNone
        default: return Color.tasker.priorityLow
        }
    }

    private var priorityLabel: String {
        switch taskPriority {
        case 1: return "Max"
        case 2: return "High"
        case 3: return "Low"
        case 4: return "None"
        default: return "Low"
        }
    }

    private var scorePoints: Int {
        switch taskPriority {
        case 1: return 7
        case 2: return 5
        case 3: return 3
        case 4: return 2
        default: return 3
        }
    }

    private var taskTypeIcon: String {
        switch taskType {
        case 1: return "sunrise.fill"
        case 2: return "moon.fill"
        case 3: return "calendar.badge.clock"
        default: return "sunrise.fill"
        }
    }

    private var taskTypeLabel: String {
        switch taskType {
        case 1: return "Morning"
        case 2: return "Evening"
        case 3: return "Upcoming"
        default: return "Morning"
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
}
