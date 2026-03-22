import SwiftUI

struct AddHabitForedropView: View {
    private enum HabitCadencePreset: String, CaseIterable, Identifiable {
        case daily
        case weekly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .daily:
                return "Daily"
            case .weekly:
                return "Weekly"
            }
        }
    }

    @ObservedObject var viewModel: AddHabitViewModel
    let containerMode: AddTaskContainerMode
    let showAddAnother: Bool
    @Binding var successFlash: Bool
    let onCancel: () -> Void
    let onCreate: () -> Void
    let onAddAnother: () -> Void
    let onExpandToLarge: () -> Void

    @FocusState private var titleFieldFocused: Bool
    @State private var errorShakeTrigger = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    private var reminderLabel: String {
        switch viewModel.selectedTrackingMode {
        case .dailyCheckIn:
            return "Reminder window"
        case .lapseOnly:
            return "Recovery window"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            AddTaskNavigationBar(
                containerMode: containerMode,
                title: "New Habit",
                canSave: viewModel.canSubmit && !viewModel.isSaving
            ) {
                onCancel()
            } onSave: {
                onCreate()
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    AddTaskTitleField(
                        text: $viewModel.habitName,
                        isFocused: $titleFieldFocused,
                        placeholder: "What habit are you building or breaking?",
                        helperText: "Name the behavior. Keep the outcome in the notes.",
                        onSubmit: onCreate
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    sectionCard("Intent", index: 1) {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            Picker("Habit kind", selection: $viewModel.selectedKind) {
                                ForEach(AddHabitKind.allCases) { kind in
                                    Text(kind.displayName).tag(kind)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: viewModel.selectedKind) { _ in
                                viewModel.normalizeSelection()
                            }

                            if viewModel.selectedKind == .negative {
                                Picker("Tracking mode", selection: $viewModel.selectedTrackingMode) {
                                    ForEach(AddHabitTrackingMode.allCases) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)

                                if viewModel.selectedTrackingMode == .lapseOnly {
                                    Text("Lapse-only habits do not create daily due cards. They track days since the last slip.")
                                        .font(.tasker(.caption2))
                                        .foregroundColor(Color.tasker.textQuaternary)
                                }
                            }
                        }
                    }

                    sectionCard("Schedule", index: 2) {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            Picker("Cadence", selection: cadencePresetBinding) {
                                ForEach(HabitCadencePreset.allCases) { cadence in
                                    Text(cadence.title).tag(cadence)
                                }
                            }
                            .pickerStyle(.segmented)

                            if cadencePresetBinding.wrappedValue == .weekly {
                                VStack(alignment: .leading, spacing: spacing.s8) {
                                    Text("Days")
                                        .font(.tasker(.caption2))
                                        .foregroundColor(Color.tasker.textTertiary)

                                    HabitWeekdayPickerRow(selectedDays: weeklyDaysBinding)
                                }
                            }

                            DatePicker(
                                "Check-in time",
                                selection: cadenceTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)

                            VStack(alignment: .leading, spacing: spacing.s8) {
                                Text(reminderLabel)
                                    .font(.tasker(.caption2))
                                    .foregroundColor(Color.tasker.textTertiary)

                                HStack(spacing: spacing.s8) {
                                    timeWindowField(
                                        title: "Start",
                                        text: $viewModel.reminderWindowStart,
                                        placeholder: "08:00"
                                    )

                                    timeWindowField(
                                        title: "End",
                                        text: $viewModel.reminderWindowEnd,
                                        placeholder: "21:00"
                                    )
                                }
                            }
                        }
                    }

                    sectionCard("Icon", index: 3) {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            TextField("Search SF Symbols", text: $viewModel.iconSearchQuery)
                                .font(.tasker(.body))
                                .padding(.horizontal, spacing.s12)
                                .frame(height: spacing.buttonHeight)
                                .background(Color.tasker.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: corner.r2, style: .continuous))

                            let options = viewModel.availableIconOptions
                            if options.isEmpty {
                                Text("No matching symbols.")
                                    .font(.tasker(.caption1))
                                    .foregroundColor(Color.tasker.textSecondary)
                            } else {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 12)], spacing: spacing.s8) {
                                    ForEach(options.prefix(24)) { option in
                                        iconButton(option)
                                    }
                                }
                            }
                        }
                    }

                    sectionCard("Organize", index: 4) {
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            AddTaskEntityPicker(
                                label: "Life Area",
                                items: viewModel.lifeAreas.map { (id: $0.id, name: $0.name, icon: $0.icon) },
                                selectedID: $viewModel.selectedLifeAreaID
                            )

                            AddTaskEntityPicker(
                                label: "Project",
                                items: viewModel.projects.map { (id: $0.project.id, name: $0.project.name, icon: nil as String?) },
                                selectedID: $viewModel.selectedProjectID
                            )
                        }
                    }

                    sectionCard("Notes", index: 5) {
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            TextEditor(text: $viewModel.habitNotes)
                                .font(.tasker(.body))
                                .frame(minHeight: 100)
                                .padding(.horizontal, spacing.s12)
                                .padding(.vertical, spacing.s8)
                                .background(Color.tasker.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                                        .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                                )

                            Text("Use this to capture why the habit matters, the trigger to avoid, or the replacement action.")
                                .font(.tasker(.caption2))
                                .foregroundColor(Color.tasker.textQuaternary)
                        }
                    }

                    if let error = viewModel.errorMessage {
                        errorMessageView(error)
                            .bellShake(trigger: $errorShakeTrigger)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s20)
            }

            AddTaskCreateButton(
                isEnabled: viewModel.canSubmit,
                isLoading: viewModel.isSaving,
                successFlash: successFlash,
                showAddAnother: showAddAnother,
                buttonTitle: "Add Habit",
                onCreateAction: onCreate,
                onAddAnotherAction: onAddAnother
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.tasker.surfacePrimary)
        .accessibilityIdentifier("addHabit.view")
        .task {
            viewModel.loadIfNeeded()
        }
    }

    private var cadencePresetBinding: Binding<HabitCadencePreset> {
        Binding(
            get: {
                switch viewModel.selectedCadence {
                case .daily:
                    return .daily
                case .weekly:
                    return .weekly
                }
            },
            set: { newValue in
                let time = extractedCadenceTime(from: viewModel.selectedCadence)
                switch newValue {
                case .daily:
                    viewModel.selectedCadence = .daily(hour: time.hour, minute: time.minute)
                case .weekly:
                    let existingDays = extractedWeeklyDays(from: viewModel.selectedCadence)
                    viewModel.selectedCadence = .weekly(
                        daysOfWeek: existingDays.isEmpty ? [2, 3, 4, 5, 6] : existingDays,
                        hour: time.hour,
                        minute: time.minute
                    )
                }
            }
        )
    }

    private var weeklyDaysBinding: Binding<[Int]> {
        Binding(
            get: {
                let days = extractedWeeklyDays(from: viewModel.selectedCadence)
                return days.isEmpty ? [2, 3, 4, 5, 6] : days
            },
            set: { newValue in
                let normalized = newValue.sorted()
                let time = extractedCadenceTime(from: viewModel.selectedCadence)
                viewModel.selectedCadence = .weekly(
                    daysOfWeek: normalized.isEmpty ? [2, 3, 4, 5, 6] : normalized,
                    hour: time.hour,
                    minute: time.minute
                )
            }
        )
    }

    private var cadenceTimeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let time = extractedCadenceTime(from: viewModel.selectedCadence)
                let startOfDay = calendar.startOfDay(for: Date())
                return calendar.date(
                    bySettingHour: time.hour ?? 9,
                    minute: time.minute ?? 0,
                    second: 0,
                    of: startOfDay
                ) ?? Date()
            },
            set: { newValue in
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: newValue)
                let minute = calendar.component(.minute, from: newValue)
                switch viewModel.selectedCadence {
                case .daily:
                    viewModel.selectedCadence = .daily(hour: hour, minute: minute)
                case .weekly(let daysOfWeek, _, _):
                    viewModel.selectedCadence = .weekly(daysOfWeek: daysOfWeek, hour: hour, minute: minute)
                }
            }
        )
    }

    @ViewBuilder
    private func iconButton(_ option: HabitIconOption) -> some View {
        let isSelected = viewModel.selectedIconSymbolName == option.symbolName
        Button {
            withAnimation(TaskerAnimation.snappy) {
                viewModel.selectedIconSymbolName = option.symbolName
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(isSelected ? Color.tasker.accentPrimary.opacity(0.15) : Color.tasker.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(option.displayName)
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.tasker.accentPrimary : Color.tasker.strokeHairline, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    @ViewBuilder
    private func sectionCard(_ title: String, index: Int, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)
            content()
        }
        .padding(spacing.s12)
        .background(Color.tasker.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
        .enhancedStaggeredAppearance(index: index)
    }

    @ViewBuilder
    private func timeWindowField(
        title: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)

            TextField(placeholder, text: text)
                .font(.tasker(.body))
                .padding(.horizontal, spacing.s12)
                .frame(height: spacing.buttonHeight)
                .background(Color.tasker.surfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: corner.r2, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                        .stroke(Color.tasker.strokeHairline, lineWidth: 1)
                )
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func extractedCadenceTime(from cadence: HabitCadenceDraft) -> (hour: Int?, minute: Int?) {
        switch cadence {
        case .daily(let hour, let minute):
            return (hour, minute)
        case .weekly(_, let hour, let minute):
            return (hour, minute)
        }
    }

    private func extractedWeeklyDays(from cadence: HabitCadenceDraft) -> [Int] {
        switch cadence {
        case .daily:
            return []
        case .weekly(let daysOfWeek, _, _):
            return daysOfWeek
        }
    }

    @ViewBuilder
    private func errorMessageView(_ message: String) -> some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.tasker.statusWarning)

            Text(message)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.statusWarning)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(
            RoundedRectangle(cornerRadius: corner.r2)
                .fill(Color.tasker.statusWarning.opacity(0.12))
        )
        .animation(TaskerAnimation.bouncy, value: viewModel.errorMessage != nil)
    }
}

private struct HabitWeekdayPickerRow: View {
    @Binding var selectedDays: [Int]

    private let weekdays: [(day: Int, label: String)] = [
        (1, "S"),
        (2, "M"),
        (3, "T"),
        (4, "W"),
        (5, "T"),
        (6, "F"),
        (7, "S")
    ]

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack(spacing: spacing.s8) {
            ForEach(weekdays, id: \.day) { item in
                let isSelected = selectedDays.contains(item.day)
                Button {
                    TaskerFeedback.selection()
                    if isSelected {
                        selectedDays.removeAll { $0 == item.day }
                    } else {
                        selectedDays.append(item.day)
                    }
                } label: {
                    Text(item.label)
                        .font(.tasker(.callout))
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfacePrimary)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected ? Color.tasker.accentPrimary : Color.tasker.strokeHairline,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HabitLibraryView: View {
    @ObservedObject var viewModel: HabitLibraryViewModel
    @State private var selectedRow: HabitLibraryRow?

    var body: some View {
        NavigationStack {
            List {
                section(title: "Active", rows: viewModel.activeRows)
                section(title: "Paused", rows: viewModel.pausedRows)
                section(title: "Archived", rows: viewModel.archivedRows)
            }
            .overlay {
                if viewModel.isLoading && viewModel.rows.isEmpty {
                    ProgressView("Loading habits…")
                } else if viewModel.rows.isEmpty {
                    ContentUnavailableView("No habits yet", systemImage: "circle.dashed")
                }
            }
            .navigationTitle("Manage Habits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                viewModel.loadIfNeeded()
            }
            .sheet(item: $selectedRow) { row in
                HabitDetailSheetView(
                    viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                    onMutation: {
                        viewModel.refresh()
                    }
                )
            }
            .alert(
                "Habit Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.clearError() } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private func section(title: String, rows: [HabitLibraryRow]) -> some View {
        if rows.isEmpty == false {
            Section(title) {
                ForEach(rows) { row in
                    Button {
                        selectedRow = row
                    } label: {
                        HabitLibraryRowCell(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct HabitLibraryRowCell: View {
    let row: HabitLibraryRow

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.icon?.symbolName ?? "circle.dashed")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(row.kind == .positive ? Color.tasker.statusSuccess : Color.tasker.statusWarning)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.tasker(.body))
                    .foregroundStyle(Color.tasker.textPrimary)
                Text(subtitle)
                    .font(.tasker(.caption2))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Text("\(row.currentStreak)")
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.tasker.surfaceSecondary)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        var parts = [row.lifeAreaName]
        if let projectName = row.projectName, projectName.isEmpty == false {
            parts.append(projectName)
        }
        parts.append(row.trackingMode == .lapseOnly ? "Lapse only" : "Daily check-in")
        return parts.joined(separator: " · ")
    }
}

struct HabitDetailSheetView: View {
    @ObservedObject var viewModel: HabitDetailViewModel
    let onMutation: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                overviewSection
                historySection
                if viewModel.isEditing {
                    editorSection
                }
                actionsSection
            }
            .navigationTitle(viewModel.isEditing ? "Edit Habit" : "Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.isEditing ? "Cancel" : "Close") {
                        if viewModel.isEditing {
                            viewModel.cancelEditing()
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isEditing {
                        Button("Save") {
                            viewModel.saveChanges {
                                onMutation()
                            }
                        }
                        .disabled(!viewModel.canSave || viewModel.isSaving)
                    } else {
                        Button("Edit") {
                            viewModel.beginEditing()
                        }
                    }
                }
            }
            .task {
                viewModel.loadIfNeeded()
            }
            .alert(
                "Habit Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.clearError() } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var overviewSection: some View {
        Section("Overview") {
            LabeledContent("Title", value: viewModel.row.title)
            LabeledContent("Type", value: viewModel.row.kind == .positive ? "Build" : "Quit")
            LabeledContent("Tracking", value: viewModel.row.trackingMode == .dailyCheckIn ? "Daily check-in" : "Lapse only")
            LabeledContent("Life Area", value: viewModel.row.lifeAreaName)
            if let projectName = viewModel.row.projectName {
                LabeledContent("Project", value: projectName)
            }
            LabeledContent("Current Streak", value: "\(viewModel.row.currentStreak) days")
            LabeledContent("Best Streak", value: "\(viewModel.row.bestStreak) days")
            if let nextDueAt = viewModel.row.nextDueAt {
                LabeledContent("Next Due", value: nextDueAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let notes = viewModel.row.notes, notes.isEmpty == false, viewModel.isEditing == false {
                Text(notes)
                    .font(.tasker(.body))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
        }
    }

    private var historySection: some View {
        Section("Last 14 Days") {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.historyMarks.prefix(14).enumerated()), id: \.offset) { _, mark in
                    Circle()
                        .fill(color(for: mark.state))
                        .frame(width: 10, height: 10)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var editorSection: some View {
        Section("Edit") {
            TextField("Title", text: $viewModel.draft.title)
            Picker("Type", selection: $viewModel.draft.kind) {
                ForEach(AddHabitKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            if viewModel.draft.kind == .negative {
                Picker("Tracking", selection: $viewModel.draft.trackingMode) {
                    ForEach(AddHabitTrackingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }
            Picker("Life Area", selection: $viewModel.draft.lifeAreaID) {
                ForEach(viewModel.lifeAreas, id: \.id) { area in
                    Text(area.name).tag(Optional(area.id))
                }
            }
            Picker("Project", selection: $viewModel.draft.projectID) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(viewModel.projects, id: \.project.id) { project in
                    Text(project.project.name).tag(Optional(project.project.id))
                }
            }
            TextField("Why this matters", text: $viewModel.draft.notes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
            TextField("Search icons", text: $viewModel.draft.iconSearchQuery)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(viewModel.availableIconOptions.prefix(18)) { option in
                        Button {
                            viewModel.draft.selectedIconSymbolName = option.symbolName
                        } label: {
                            Image(systemName: option.symbolName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.tasker.accentOnPrimary : Color.tasker.textPrimary)
                                .frame(width: 36, height: 36)
                                .background(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button(viewModel.row.isPaused ? "Resume Habit" : "Pause Habit") {
                viewModel.togglePause {
                    onMutation()
                }
            }
            .disabled(viewModel.isSaving)

            if viewModel.row.trackingMode == .lapseOnly && !viewModel.row.isArchived {
                Button("Log Lapse", role: .destructive) {
                    viewModel.logLapse {
                        onMutation()
                    }
                }
                .disabled(viewModel.isSaving)
            }

            if !viewModel.row.isArchived {
                Button("Archive Habit", role: .destructive) {
                    viewModel.archive {
                        onMutation()
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
    }

    private func color(for state: HabitDayState) -> Color {
        switch state {
        case .success:
            return Color.tasker.statusSuccess
        case .failure:
            return Color.tasker.statusDanger
        case .skipped:
            return Color.tasker.textTertiary
        case .none:
            return Color.tasker.strokeHairline
        case .future:
            return Color.tasker.accentMuted
        }
    }
}
