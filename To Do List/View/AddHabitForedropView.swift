import SwiftUI

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

private enum HabitLibraryFilter: String, CaseIterable, Identifiable {
    case active
    case paused
    case archived

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        case .archived:
            return "Archived"
        }
    }
}

struct AddHabitForedropView: View {
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
    @State private var showAdvancedSettings = false
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.tokens(for: layoutClass).corner }

    private var reminderLabel: String {
        switch viewModel.selectedTrackingMode {
        case .dailyCheckIn:
            return "Reminder window"
        case .lapseOnly:
            return "Recovery window"
        }
    }

    private var cadenceSummary: String {
        switch viewModel.selectedCadence {
        case .daily(let hour, let minute):
            return "Daily at \(formattedTime(hour: hour, minute: minute))"
        case .weekly(let days, let hour, let minute):
            return "\(weekdaySummary(days)) at \(formattedTime(hour: hour, minute: minute))"
        }
    }

    private var ownershipSummary: String {
        let lifeArea = viewModel.lifeAreas.first(where: { $0.id == viewModel.selectedLifeAreaID })?.name ?? "Pick a life area"
        if let selectedProjectID = viewModel.selectedProjectID,
           let projectName = viewModel.projects.first(where: { $0.project.id == selectedProjectID })?.project.name {
            return "\(lifeArea) · \(projectName)"
        }
        return lifeArea
    }

    private var habitModeSummary: String {
        switch (viewModel.selectedKind, viewModel.selectedTrackingMode) {
        case (.positive, _):
            return "Build habit"
        case (.negative, .dailyCheckIn):
            return "Quit with daily check-ins"
        case (.negative, .lapseOnly):
            return "Quit with lapse logging"
        }
    }

    private var advancedSummary: String {
        var pieces: [String] = []
        if viewModel.selectedProjectID != nil {
            pieces.append("Project")
        }
        if viewModel.reminderWindowStart.nilIfBlank != nil || viewModel.reminderWindowEnd.nilIfBlank != nil {
            pieces.append("Window")
        }
        if viewModel.habitNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            pieces.append("Notes")
        }
        if viewModel.selectedIconSymbolName != nil {
            pieces.append("Icon")
        }
        if pieces.isEmpty {
            return "Project, notes, icon, and reminder tuning"
        }
        return pieces.joined(separator: " · ")
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
                    HabitComposerSummaryCard(
                        iconSymbolName: viewModel.selectedIconSymbolName ?? "circle.dashed",
                        title: viewModel.habitName.nilIfBlank ?? "Your habit",
                        modeSummary: habitModeSummary,
                        cadenceSummary: cadenceSummary,
                        ownershipSummary: ownershipSummary,
                        isExpanded: showAdvancedSettings
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    AddTaskTitleField(
                        text: $viewModel.habitName,
                        isFocused: $titleFieldFocused,
                        placeholder: "What habit are you shaping?",
                        helperText: "Lead with the behavior. Keep the why and tactics for later.",
                        onSubmit: onCreate
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    HabitSurfaceCard(
                        title: "Essentials",
                        subtitle: "Define the behavior loop first.",
                        iconSystemName: "sparkles"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            habitKindPicker
                            trackingModeSection
                            cadenceSection
                            ownershipSection
                        }
                    }
                    .enhancedStaggeredAppearance(index: 2)

                    advancedDisclosure
                        .enhancedStaggeredAppearance(index: 3)

                    if showAdvancedSettings {
                        advancedSections
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }

                    if let error = viewModel.errorMessage {
                        errorMessageView(error)
                            .bellShake(trigger: $errorShakeTrigger)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s24)
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
        .background(Color.tasker.bgCanvas)
        .accessibilityIdentifier("addHabit.view")
        .task {
            viewModel.loadIfNeeded()
            if reduceMotion == false {
                withAnimation(TaskerAnimation.gentle.delay(0.08)) {
                    showAdvancedSettings = hasAdvancedContent
                }
            } else {
                showAdvancedSettings = hasAdvancedContent
            }
        }
    }

    private var habitKindPicker: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HabitSectionLabel(title: "Direction", detail: "Build momentum or protect against a slip.")

            Picker("Habit kind", selection: $viewModel.selectedKind) {
                ForEach(AddHabitKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedKind) { _, _ in
                viewModel.normalizeSelection()
                if viewModel.selectedKind == .negative {
                    expandAdvancedIfNeeded()
                }
            }
        }
    }

    @ViewBuilder
    private var trackingModeSection: some View {
        if viewModel.selectedKind == .negative {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HabitSectionLabel(title: "Support style", detail: "Choose whether this needs a daily check-in or only lapse logging.")

                Picker("Tracking mode", selection: $viewModel.selectedTrackingMode) {
                    ForEach(AddHabitTrackingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.selectedTrackingMode == .lapseOnly {
                    HabitInlineMessage(
                        title: "Recovery first",
                        message: "This habit stays quiet on normal days. You only log the slip, and clean days recover automatically."
                    )
                } else {
                    HabitInlineMessage(
                        title: "Daily accountability",
                        message: "This shows up as a daily behavior to confirm or record a lapse."
                    )
                }
            }
        }
    }

    private var cadenceSection: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HabitSectionLabel(title: "Cadence", detail: "Keep it predictable enough that it is easy to restart.")

            Picker("Cadence", selection: cadencePresetBinding) {
                ForEach(HabitCadencePreset.allCases) { cadence in
                    Text(cadence.title).tag(cadence)
                }
            }
            .pickerStyle(.segmented)

            if cadencePresetBinding.wrappedValue == .weekly {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    HabitSectionLabel(title: "Days", detail: "Choose the days that actually fit your week.")
                    HabitWeekdayPickerRow(selectedDays: weeklyDaysBinding)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            DatePicker(
                "Check-in time",
                selection: cadenceTimeBinding,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .taskerDenseSurface(cornerRadius: corner.r2, fillColor: Color.tasker.surfacePrimary)
        }
    }

    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HabitSectionLabel(title: "Life Area", detail: "Every habit needs a home so the system can keep it grounded.")

            AddTaskEntityPicker(
                label: "Life Area",
                items: viewModel.lifeAreas.map { (id: $0.id, name: $0.name, icon: $0.icon) },
                selectedID: $viewModel.selectedLifeAreaID
            )

            if viewModel.selectedLifeAreaID == nil {
                Text("Pick a life area before saving.")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.statusWarning)
            }
        }
    }

    private var advancedDisclosure: some View {
        Button {
            TaskerFeedback.selection()
            if reduceMotion {
                showAdvancedSettings.toggle()
            } else {
                withAnimation(TaskerAnimation.panelIn) {
                    showAdvancedSettings.toggle()
                }
            }
            if showAdvancedSettings == false {
                titleFieldFocused = false
            }
        } label: {
            HStack(spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(showAdvancedSettings ? "Hide advanced options" : "Refine the system")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.textPrimary)
                    Text(advancedSummary)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)

                Image(systemName: showAdvancedSettings ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color.tasker.accentPrimary)
            }
            .padding(spacing.s12)
            .taskerChromeSurface(cornerRadius: corner.r3, accentColor: Color.tasker.accentSecondary, level: .e1)
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }

    @ViewBuilder
    private var advancedSections: some View {
        VStack(spacing: spacing.s16) {
            HabitSurfaceCard(
                title: reminderLabel,
                subtitle: "Helpful when timing matters more than perfection.",
                iconSystemName: "clock.badge"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
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

                    if let reminderError = viewModel.reminderWindowValidationError {
                        Text(reminderError)
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.statusWarning)
                    } else {
                        Text(viewModel.selectedTrackingMode == .lapseOnly ? "Use a recovery window when slips usually show up." : "Use this if you want the habit to nudge inside a deliberate part of the day.")
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.textSecondary)
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 4)

            HabitSurfaceCard(
                title: "Context",
                subtitle: "Optional structure when this habit supports a larger plan.",
                iconSystemName: "tray.full"
            ) {
                AddTaskEntityPicker(
                    label: "Project",
                    items: viewModel.projects.map { (id: $0.project.id, name: $0.project.name, icon: nil as String?) },
                    selectedID: $viewModel.selectedProjectID
                )
            }
            .enhancedStaggeredAppearance(index: 5)

            HabitSurfaceCard(
                title: "Identity",
                subtitle: "Pick a symbol that makes the habit recognizable in a glance.",
                iconSystemName: "square.grid.2x2"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    HStack(spacing: spacing.s12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                                .fill(Color.tasker.accentWash)
                                .frame(width: 52, height: 52)

                            Image(systemName: viewModel.selectedIconSymbolName ?? "circle.dashed")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(Color.tasker.accentPrimary)
                        }

                        TextField("Search SF Symbols", text: $viewModel.iconSearchQuery)
                            .textFieldStyle(TaskerTextFieldStyle())
                    }

                    let options = Array(viewModel.availableIconOptions.prefix(layoutClass.isPad ? 24 : 16))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 84 : 72), spacing: spacing.s8)], spacing: spacing.s8) {
                        ForEach(options) { option in
                            iconButton(option)
                        }
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 6)

            HabitSurfaceCard(
                title: "Why this matters",
                subtitle: "Capture a trigger, replacement action, or the reason you want this to stick.",
                iconSystemName: "note.text"
            ) {
                TextEditor(text: $viewModel.habitNotes)
                    .font(.tasker(.body))
                    .frame(minHeight: layoutClass.isPad ? 120 : 110)
                    .padding(.horizontal, spacing.s12)
                    .padding(.vertical, spacing.s8)
                    .taskerDenseSurface(cornerRadius: corner.r2, fillColor: Color.tasker.surfacePrimary)
            }
            .enhancedStaggeredAppearance(index: 7)
        }
    }

    private var hasAdvancedContent: Bool {
        viewModel.selectedProjectID != nil
            || viewModel.reminderWindowStart.nilIfBlank != nil
            || viewModel.reminderWindowEnd.nilIfBlank != nil
            || viewModel.habitNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || viewModel.iconSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func expandAdvancedIfNeeded() {
        guard showAdvancedSettings == false else { return }
        if reduceMotion {
            showAdvancedSettings = true
        } else {
            withAnimation(TaskerAnimation.snappy) {
                showAdvancedSettings = true
            }
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

    private func formattedTime(hour: Int?, minute: Int?) -> String {
        let calendar = Calendar.current
        let date = calendar.date(
            bySettingHour: hour ?? 9,
            minute: minute ?? 0,
            second: 0,
            of: calendar.startOfDay(for: Date())
        ) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func weekdaySummary(_ days: [Int]) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        if days.count == 5 && days == [2, 3, 4, 5, 6] {
            return "Weekdays"
        }
        if days.count == 7 {
            return "Every day"
        }
        let labels = days.compactMap { day -> String? in
            let index = max(0, min(symbols.count - 1, day - 1))
            return symbols[safe: index]
        }
        return labels.joined(separator: " · ")
    }

    @ViewBuilder
    private func iconButton(_ option: HabitIconOption) -> some View {
        let isSelected = viewModel.selectedIconSymbolName == option.symbolName
        Button {
            withAnimation(TaskerAnimation.snappy) {
                viewModel.selectedIconSymbolName = option.symbolName
            }
        } label: {
            VStack(spacing: spacing.s8) {
                Image(systemName: option.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? Color.tasker.accentPrimary : Color.tasker.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? Color.tasker.accentWash : Color.tasker.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text(option.displayName)
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, spacing.s4)
            .padding(.vertical, spacing.s8)
            .taskerDenseSurface(
                cornerRadius: corner.r2,
                fillColor: isSelected ? Color.tasker.accentWash.opacity(0.7) : Color.tasker.surfaceSecondary,
                strokeColor: isSelected ? Color.tasker.accentPrimary : Color.tasker.strokeHairline
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel(option.displayName)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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
                .taskerDenseSurface(cornerRadius: corner.r2, fillColor: Color.tasker.surfacePrimary)
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
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .taskerDenseSurface(
            cornerRadius: corner.r2,
            fillColor: Color.tasker.statusWarning.opacity(0.12),
            strokeColor: Color.tasker.statusWarning.opacity(0.24)
        )
        .animation(TaskerAnimation.bouncy, value: viewModel.errorMessage != nil)
    }
}

struct HabitLibraryView: View {
    @ObservedObject var viewModel: HabitLibraryViewModel
    @State private var selectedRow: HabitLibraryRow?
    @State private var selectedFilter: HabitLibraryFilter = .active
    @State private var searchText = ""
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.tokens(for: layoutClass).corner }

    private var filteredRows: [HabitLibraryRow] {
        let baseRows: [HabitLibraryRow]
        switch selectedFilter {
        case .active:
            baseRows = viewModel.activeRows
        case .paused:
            baseRows = viewModel.pausedRows
        case .archived:
            baseRows = viewModel.archivedRows
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return baseRows }

        return baseRows.filter { row in
            row.title.lowercased().contains(query)
                || row.lifeAreaName.lowercased().contains(query)
                || (row.projectName?.lowercased().contains(query) ?? false)
                || trackingLabel(for: row).lowercased().contains(query)
        }
    }

    private var columns: [GridItem] {
        if layoutClass == .padRegular || layoutClass == .padExpanded {
            return [
                GridItem(.flexible(), spacing: spacing.s16),
                GridItem(.flexible(), spacing: spacing.s16)
            ]
        }
        return [GridItem(.flexible(), spacing: spacing.s12)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    HabitLibrarySummaryHeader(
                        activeCount: viewModel.activeRows.count,
                        pausedCount: viewModel.pausedRows.count,
                        archivedCount: viewModel.archivedRows.count
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    HabitLibraryControlRail(
                        selectedFilter: $selectedFilter,
                        searchText: $searchText
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    content
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s24)
            }
            .background(Color.tasker.bgCanvas)
            .navigationTitle("Manage Habits")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                    .accessibilityLabel("Refresh habits")
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
    private var content: some View {
        if viewModel.isLoading && viewModel.rows.isEmpty {
            HabitEmptyStateCard(
                systemImage: "progress.indicator",
                title: "Loading habits",
                message: "Pulling in your behavior loops and their latest streak signals."
            )
        } else if filteredRows.isEmpty {
            HabitEmptyStateCard(
                systemImage: searchText.isEmpty ? "circle.dashed" : "magnifyingglass",
                title: searchText.isEmpty ? emptyTitle : "No matching habits",
                message: searchText.isEmpty ? emptyBody : "Try a different search or switch filters to see more habits."
            )
        } else {
            LazyVGrid(columns: columns, spacing: spacing.s12) {
                ForEach(Array(filteredRows.enumerated()), id: \.element.id) { index, row in
                    Button {
                        selectedRow = row
                    } label: {
                        HabitLibraryCard(row: row)
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                    .enhancedStaggeredAppearance(index: index + 2)
                }
            }
        }
    }

    private var emptyTitle: String {
        switch selectedFilter {
        case .active:
            return "No active habits"
        case .paused:
            return "No paused habits"
        case .archived:
            return "No archived habits"
        }
    }

    private var emptyBody: String {
        switch selectedFilter {
        case .active:
            return "Create a behavior loop to keep consistency visible without adding more task clutter."
        case .paused:
            return "Paused habits stay here so they can come back without losing their history."
        case .archived:
            return "Archived habits keep their streak story, but stay out of your active management flow."
        }
    }

    private func trackingLabel(for row: HabitLibraryRow) -> String {
        row.trackingMode == .lapseOnly ? "Log lapse only" : "Daily check-in"
    }
}

struct HabitDetailSheetView: View {
    @ObservedObject var viewModel: HabitDetailViewModel
    let onMutation: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: spacing.s16) {
                    HabitDetailHeroCard(
                        row: viewModel.row,
                        historyMarks: viewModel.historyMarks,
                        isEditing: viewModel.isEditing
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    if viewModel.isEditing {
                        editingCards
                    } else {
                        readOnlyCards
                    }

                    if let error = viewModel.errorMessage {
                        HabitActionMessageCard(
                            title: "Something needs attention",
                            message: error,
                            tone: .warning
                        )
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s24)
            }
            .background(Color.tasker.bgCanvas)
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

    private var readOnlyCards: some View {
        VStack(spacing: spacing.s16) {
            HabitSurfaceCard(
                title: "Health snapshot",
                subtitle: "The key signals that keep this habit easy to read at a glance.",
                iconSystemName: "waveform.path.ecg"
            ) {
                HabitMetricGrid(metrics: [
                    HabitMetricDisplay(title: "Current streak", value: "\(viewModel.row.currentStreak) days", tone: .accent),
                    HabitMetricDisplay(title: "Best streak", value: "\(viewModel.row.bestStreak) days", tone: .neutral),
                    HabitMetricDisplay(title: "Next due", value: nextDueSummary, tone: nextDueTone),
                    HabitMetricDisplay(title: "Reminder", value: reminderSummary, tone: .neutral)
                ])
            }
            .enhancedStaggeredAppearance(index: 1)

            HabitSurfaceCard(
                title: "History and recovery",
                subtitle: historyInterpretation,
                iconSystemName: "clock.arrow.circlepath"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    HabitHistoryStripView(marks: viewModel.historyMarks)
                    HabitHistoryLegend()
                }
            }
            .enhancedStaggeredAppearance(index: 2)

            HabitSurfaceCard(
                title: "Context",
                subtitle: "Where this habit lives and what it supports.",
                iconSystemName: "folder"
            ) {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    HabitDefinitionLine(label: "Life Area", value: viewModel.row.lifeAreaName)
                    if let projectName = viewModel.row.projectName, projectName.isEmpty == false {
                        HabitDefinitionLine(label: "Project", value: projectName)
                    }
                    HabitDefinitionLine(label: "Cadence", value: cadenceSummary(viewModel.row.cadence))
                    if let notes = viewModel.row.notes, notes.isEmpty == false {
                        HabitActionMessageCard(
                            title: "Why this matters",
                            message: notes,
                            tone: .neutral
                        )
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 3)

            lifecycleCard
                .enhancedStaggeredAppearance(index: 4)
        }
    }

    private var editingCards: some View {
        VStack(spacing: spacing.s16) {
            HabitSurfaceCard(
                title: "Essentials",
                subtitle: "Keep the identity and support style crisp.",
                iconSystemName: "sparkles"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    TextField("Title", text: $viewModel.draft.title)
                        .textFieldStyle(TaskerTextFieldStyle())

                    Picker("Type", selection: $viewModel.draft.kind) {
                        ForEach(AddHabitKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.draft.kind) { _, _ in
                        viewModel.normalizeDraftSelection()
                    }

                    if viewModel.draft.kind == .negative {
                        Picker("Tracking", selection: $viewModel.draft.trackingMode) {
                            ForEach(AddHabitTrackingMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        if viewModel.draft.trackingMode == .lapseOnly {
                            HabitInlineMessage(
                                title: "Low-friction recovery",
                                message: "You only log the lapse. Clean days recover automatically in the background."
                            )
                        }
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 1)

            HabitSurfaceCard(
                title: "Schedule",
                subtitle: "Tune when this habit should show up and how recovery gets timed.",
                iconSystemName: "calendar.badge.clock"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    Picker("Cadence", selection: detailCadencePresetBinding) {
                        ForEach(HabitCadencePreset.allCases) { cadence in
                            Text(cadence.title).tag(cadence)
                        }
                    }
                    .pickerStyle(.segmented)

                    if detailCadencePresetBinding.wrappedValue == .weekly {
                        HabitWeekdayPickerRow(selectedDays: detailWeeklyDaysBinding)
                    }

                    DatePicker(
                        "Check-in time",
                        selection: detailCadenceTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)

                    HStack(spacing: spacing.s8) {
                        detailTimeWindowField(title: "Start", text: $viewModel.draft.reminderWindowStart)
                        detailTimeWindowField(title: "End", text: $viewModel.draft.reminderWindowEnd)
                    }

                    if let reminderError = viewModel.editorReminderWindowValidationError {
                        Text(reminderError)
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.statusWarning)
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 2)

            HabitSurfaceCard(
                title: "Organize",
                subtitle: "Keep the habit anchored to the area of life it supports.",
                iconSystemName: "square.grid.2x2"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    AddTaskEntityPicker(
                        label: "Life Area",
                        items: viewModel.lifeAreas.map { (id: $0.id, name: $0.name, icon: $0.icon) },
                        selectedID: $viewModel.draft.lifeAreaID
                    )

                    AddTaskEntityPicker(
                        label: "Project",
                        items: viewModel.projects.map { (id: $0.project.id, name: $0.project.name, icon: nil as String?) },
                        selectedID: $viewModel.draft.projectID
                    )
                }
            }
            .enhancedStaggeredAppearance(index: 3)

            HabitSurfaceCard(
                title: "Notes and Icon",
                subtitle: "Preserve the reason this habit exists and how it should feel in the UI.",
                iconSystemName: "swatchpalette"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    TextEditor(text: $viewModel.draft.notes)
                        .font(.tasker(.body))
                        .frame(minHeight: 110)
                        .padding(.horizontal, spacing.s12)
                        .padding(.vertical, spacing.s8)
                        .taskerDenseSurface(cornerRadius: TaskerTheme.CornerRadius.md, fillColor: Color.tasker.surfacePrimary)

                    TextField("Search icons", text: $viewModel.draft.iconSearchQuery)
                        .textFieldStyle(TaskerTextFieldStyle())

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing.s8) {
                            ForEach(viewModel.availableIconOptions.prefix(18)) { option in
                                Button {
                                    viewModel.draft.selectedIconSymbolName = option.symbolName
                                } label: {
                                    Image(systemName: option.symbolName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.tasker.accentOnPrimary : Color.tasker.textPrimary)
                                        .frame(width: 40, height: 40)
                                        .background(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 4)

            lifecycleCard
                .enhancedStaggeredAppearance(index: 5)
        }
    }

    private var lifecycleCard: some View {
        HabitSurfaceCard(
            title: "Lifecycle",
            subtitle: "Change the state of the habit without losing its history.",
            iconSystemName: "arrow.triangle.branch"
        ) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Button(viewModel.row.isPaused ? "Resume Habit" : "Pause Habit") {
                    viewModel.togglePause {
                        onMutation()
                    }
                }
                .buttonStyle(HabitActionButtonStyle(tone: .secondary))
                .disabled(viewModel.isSaving)

                if viewModel.row.trackingMode == .lapseOnly && !viewModel.row.isArchived {
                    Button("Log Lapse") {
                        viewModel.logLapse {
                            onMutation()
                        }
                    }
                    .buttonStyle(HabitActionButtonStyle(tone: .warning))
                    .disabled(viewModel.isSaving)
                }

                Button("Archive Habit") {
                    viewModel.archive {
                        onMutation()
                    }
                }
                .buttonStyle(HabitActionButtonStyle(tone: .destructive))
                .disabled(viewModel.isSaving || viewModel.row.isArchived)

                Text("Pausing keeps the streak history intact. Archiving removes the habit from active management flows but preserves context for reflection.")
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
            }
        }
    }

    private var nextDueSummary: String {
        if let nextDueAt = viewModel.row.nextDueAt {
            return nextDueAt.formatted(date: .abbreviated, time: .shortened)
        }
        if viewModel.row.isPaused {
            return "Paused"
        }
        if viewModel.row.isArchived {
            return "Archived"
        }
        return "Not scheduled"
    }

    private var reminderSummary: String {
        let start = trimmedReminderValue(viewModel.row.reminderWindowStart) ?? "Not set"
        let end = trimmedReminderValue(viewModel.row.reminderWindowEnd) ?? "Not set"
        return "\(start) to \(end)"
    }

    private var nextDueTone: HabitMetricTone {
        if viewModel.row.isPaused || viewModel.row.isArchived {
            return .neutral
        }
        return .warning
    }

    private var historyInterpretation: String {
        switch viewModel.row.trackingMode {
        case .dailyCheckIn:
            return "The last 14 days stay visible so misses remain recoverable instead of feeling final."
        case .lapseOnly:
            return "Lapses show clearly, while clean days stay lightweight so the habit does not demand constant attention."
        }
    }

    private func cadenceSummary(_ cadence: HabitCadenceDraft) -> String {
        switch cadence {
        case .daily(let hour, let minute):
            return "Daily at \(formattedTime(hour: hour, minute: minute))"
        case .weekly(let days, let hour, let minute):
            return "\(weekdaySummary(days)) at \(formattedTime(hour: hour, minute: minute))"
        }
    }

    private func formattedTime(hour: Int?, minute: Int?) -> String {
        let calendar = Calendar.current
        let date = calendar.date(
            bySettingHour: hour ?? 9,
            minute: minute ?? 0,
            second: 0,
            of: calendar.startOfDay(for: Date())
        ) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func weekdaySummary(_ days: [Int]) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        if days.count == 5 && days == [2, 3, 4, 5, 6] {
            return "Weekdays"
        }
        if days.count == 7 {
            return "Every day"
        }
        return days.compactMap { symbols[safe: max(0, min(symbols.count - 1, $0 - 1))] }
            .joined(separator: " · ")
    }

    private var detailCadencePresetBinding: Binding<HabitCadencePreset> {
        Binding(
            get: {
                switch viewModel.draft.cadence {
                case .daily:
                    return .daily
                case .weekly:
                    return .weekly
                }
            },
            set: { newValue in
                let time = detailCadenceTime(from: viewModel.draft.cadence)
                switch newValue {
                case .daily:
                    viewModel.draft.cadence = .daily(hour: time.hour, minute: time.minute)
                case .weekly:
                    let existingDays = detailWeeklyDays(from: viewModel.draft.cadence)
                    viewModel.draft.cadence = .weekly(
                        daysOfWeek: existingDays.isEmpty ? [2, 3, 4, 5, 6] : existingDays,
                        hour: time.hour,
                        minute: time.minute
                    )
                }
            }
        )
    }

    private var detailWeeklyDaysBinding: Binding<[Int]> {
        Binding(
            get: {
                let days = detailWeeklyDays(from: viewModel.draft.cadence)
                return days.isEmpty ? [2, 3, 4, 5, 6] : days
            },
            set: { newValue in
                let normalized = newValue.sorted()
                let time = detailCadenceTime(from: viewModel.draft.cadence)
                viewModel.draft.cadence = .weekly(
                    daysOfWeek: normalized.isEmpty ? [2, 3, 4, 5, 6] : normalized,
                    hour: time.hour,
                    minute: time.minute
                )
            }
        )
    }

    private var detailCadenceTimeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let time = detailCadenceTime(from: viewModel.draft.cadence)
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
                switch viewModel.draft.cadence {
                case .daily:
                    viewModel.draft.cadence = .daily(hour: hour, minute: minute)
                case .weekly(let daysOfWeek, _, _):
                    viewModel.draft.cadence = .weekly(daysOfWeek: daysOfWeek, hour: hour, minute: minute)
                }
            }
        )
    }

    @ViewBuilder
    private func detailTimeWindowField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textTertiary)

            TextField(title, text: text)
                .textFieldStyle(TaskerTextFieldStyle())
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func detailCadenceTime(from cadence: HabitCadenceDraft) -> (hour: Int?, minute: Int?) {
        switch cadence {
        case .daily(let hour, let minute):
            return (hour, minute)
        case .weekly(_, let hour, let minute):
            return (hour, minute)
        }
    }

    private func detailWeeklyDays(from cadence: HabitCadenceDraft) -> [Int] {
        switch cadence {
        case .daily:
            return []
        case .weekly(let daysOfWeek, _, _):
            return daysOfWeek
        }
    }

    private func trimmedReminderValue(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct HabitComposerSummaryCard: View {
    let iconSymbolName: String
    let title: String
    let modeSummary: String
    let cadenceSummary: String
    let ownershipSummary: String
    let isExpanded: Bool

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        HStack(spacing: spacing.s12) {
            ZStack {
                Circle()
                    .fill(Color.tasker.accentWash)
                    .frame(width: 58, height: 58)

                Image(systemName: iconSymbolName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color.tasker.accentPrimary)
            }

            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(title)
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.textPrimary)
                    .lineLimit(2)

                Text(modeSummary)
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundColor(Color.tasker.accentPrimary)

                Text("\(cadenceSummary) · \(ownershipSummary)")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: isExpanded ? "slider.horizontal.3.circle.fill" : "slider.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color.tasker.textSecondary)
        }
        .padding(spacing.s16)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary,
            accentColor: Color.tasker.accentSecondary,
            level: .e2
        )
    }
}

private struct HabitSurfaceCard<Content: View>: View {
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
                    .foregroundColor(Color.tasker.accentPrimary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)
                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(spacing.s16)
        .taskerDenseSurface(cornerRadius: TaskerTheme.CornerRadius.card, fillColor: Color.tasker.surfacePrimary)
        .taskerElevation(.e1, cornerRadius: TaskerTheme.CornerRadius.card, includesBorder: false)
    }
}

private struct HabitSectionLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(Color.tasker.textPrimary)
            Text(detail)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textSecondary)
        }
    }
}

private struct HabitWeekdayPickerRow: View {
    @Binding var selectedDays: [Int]

    @ObservedObject private var themeManager = TaskerThemeManager.shared
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { themeManager.tokens(for: layoutClass).spacing }

    private var weekdays: [(day: Int, label: String)] {
        let labels = Calendar.current.veryShortWeekdaySymbols
        return (1...7).map { day in
            let index = labels.indices.contains(day - 1) ? day - 1 : 0
            return (day, labels[index])
        }
    }

    var body: some View {
        HStack(spacing: spacing.s4) {
            ForEach(weekdays, id: \.day) { item in
                let isSelected = selectedDays.contains(item.day)

                Button {
                    TaskerFeedback.selection()
                    withAnimation(TaskerAnimation.snappy) {
                        toggle(item.day)
                    }
                } label: {
                    Text(item.label)
                        .font(.tasker(.callout))
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceTertiary)
                        )
                }
                .buttonStyle(.plain)
                .scaleOnPress()
            }
        }
    }

    private func toggle(_ day: Int) {
        if selectedDays.contains(day) {
            selectedDays.removeAll { $0 == day }
        } else {
            selectedDays.append(day)
            selectedDays.sort()
        }
    }
}

private struct HabitInlineMessage: View {
    let title: String
    let message: String

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(Color.tasker.accentPrimary)
            Text(message)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(spacing.s8)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.md,
            fillColor: Color.tasker.accentWash,
            strokeColor: Color.tasker.accentPrimary.opacity(0.18)
        )
    }
}

private struct HabitLibrarySummaryHeader: View {
    let activeCount: Int
    let pausedCount: Int
    let archivedCount: Int

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text("Habit system")
                .font(.tasker(.screenTitle))
                .foregroundColor(Color.tasker.textPrimary)

            Text("Keep recurring behavior legible without turning it into more task noise.")
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textSecondary)

            HStack(spacing: spacing.s8) {
                HabitCountPill(title: "Active", value: activeCount, tone: .accent)
                HabitCountPill(title: "Paused", value: pausedCount, tone: .neutral)
                HabitCountPill(title: "Archived", value: archivedCount, tone: .neutral)
            }
        }
        .padding(spacing.s16)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary,
            accentColor: Color.tasker.accentSecondary
        )
    }
}

private struct HabitCountPill: View {
    let title: String
    let value: Int
    let tone: HabitMetricTone

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.tasker(.title3))
                .foregroundColor(tone.textColor)
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.md,
            fillColor: tone.fillColor,
            strokeColor: tone.strokeColor
        )
    }
}

private struct HabitLibraryControlRail: View {
    @Binding var selectedFilter: HabitLibraryFilter
    @Binding var searchText: String

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(spacing: spacing.s8) {
                ForEach(HabitLibraryFilter.allCases) { filter in
                    Button {
                        withAnimation(TaskerAnimation.snappy) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.tasker(.callout).weight(.semibold))
                            .foregroundColor(selectedFilter == filter ? Color.tasker.accentOnPrimary : Color.tasker.textSecondary)
                            .frame(maxWidth: .infinity)
            .padding(.vertical, spacing.s8)
                            .background(selectedFilter == filter ? Color.tasker.accentPrimary : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                }
            }
            .padding(spacing.s4)
            .taskerChromeSurface(
                cornerRadius: TaskerTheme.CornerRadius.pill,
                accentColor: Color.tasker.accentSecondary,
                level: .e1
            )

            HStack(spacing: spacing.s8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.tasker.textSecondary)
                TextField("Search habits, life areas, or projects", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.tasker(.body))
            }
            .padding(.horizontal, spacing.s12)
            .frame(height: spacing.buttonHeight)
            .taskerDenseSurface(cornerRadius: TaskerTheme.CornerRadius.md, fillColor: Color.tasker.surfacePrimary)
        }
    }
}

private struct HabitLibraryCard: View {
    let row: HabitLibraryRow

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    Circle()
                        .fill(kindColor.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: row.icon?.symbolName ?? "circle.dashed")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(kindColor)
                }

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(row.title)
                        .font(.tasker(.headline))
                        .foregroundColor(Color.tasker.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: spacing.s4) {
                        HabitPill(text: row.kind == .positive ? "Build" : "Quit", tone: row.kind == .positive ? .success : .warning)
                        HabitPill(text: row.trackingMode == .lapseOnly ? "Log lapse only" : "Daily check-in", tone: .neutral)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(metaLine)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
                .lineLimit(2)

            HabitHistoryStripView(marks: row.last14Days)

            HStack(spacing: spacing.s8) {
                HabitMiniMetric(title: "Current", value: "\(row.currentStreak)d")
                HabitMiniMetric(title: "Best", value: "\(row.bestStreak)d")
                HabitMiniMetric(title: stateLabel, value: stateValue)
            }
        }
        .padding(spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .taskerDenseSurface(cornerRadius: TaskerTheme.CornerRadius.card, fillColor: Color.tasker.surfacePrimary)
    }

    private var kindColor: Color {
        row.kind == .positive ? Color.tasker.statusSuccess : Color.tasker.statusWarning
    }

    private var metaLine: String {
        var parts = [row.lifeAreaName]
        if let projectName = row.projectName, projectName.isEmpty == false {
            parts.append(projectName)
        }
        return parts.joined(separator: " · ")
    }

    private var stateLabel: String {
        if row.isArchived { return "Status" }
        if row.isPaused { return "Status" }
        return "Next"
    }

    private var stateValue: String {
        if row.isArchived { return "Archived" }
        if row.isPaused { return "Paused" }
        if let nextDueAt = row.nextDueAt {
            return nextDueAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Open"
    }
}

private struct HabitMiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.tasker(.callout).weight(.semibold))
                .foregroundColor(Color.tasker.textPrimary)
            Text(title)
                .font(.tasker(.caption2))
                .foregroundColor(Color.tasker.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.md,
            fillColor: Color.tasker.surfaceSecondary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.72)
        )
    }
}

private struct HabitEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(spacing: spacing.s12) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(Color.tasker.textSecondary)

            Text(title)
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)

            Text(message)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(spacing.s20)
        .taskerDenseSurface(cornerRadius: TaskerTheme.CornerRadius.card, fillColor: Color.tasker.surfacePrimary)
    }
}

private struct HabitDetailHeroCard: View {
    let row: HabitLibraryRow
    let historyMarks: [HabitDayMark]
    let isEditing: Bool

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    Circle()
                        .fill(toneColor.opacity(0.14))
                        .frame(width: 56, height: 56)

                    Image(systemName: row.icon?.symbolName ?? "circle.dashed")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(toneColor)
                }

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(row.title)
                        .font(.tasker(.title2))
                        .foregroundColor(Color.tasker.textPrimary)
                        .lineLimit(3)

                    HStack(spacing: spacing.s4) {
                        HabitPill(text: row.kind == .positive ? "Build" : "Quit", tone: row.kind == .positive ? .success : .warning)
                        HabitPill(text: row.trackingMode == .lapseOnly ? "Log lapse only" : "Daily check-in", tone: .neutral)
                        HabitPill(text: row.isArchived ? "Archived" : (row.isPaused ? "Paused" : (isEditing ? "Editing" : "Live")), tone: row.isArchived ? .neutral : .accent)
                    }
                }

                Spacer(minLength: 0)
            }

            HabitHistoryStripView(marks: historyMarks)
        }
        .padding(spacing.s20)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: Color.tasker.surfacePrimary,
            accentColor: toneColor
        )
    }

    private var toneColor: Color {
        row.kind == .positive ? Color.tasker.statusSuccess : Color.tasker.statusWarning
    }
}

private struct HabitMetricGrid: View {
    let metrics: [HabitMetricDisplay]
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var columns: [GridItem] {
        if layoutClass == .padRegular || layoutClass == .padExpanded {
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.value)
                        .font(.tasker(.bodyStrong))
                        .foregroundColor(metric.tone.textColor)
                    Text(metric.title)
                        .font(.tasker(.caption2))
                        .foregroundColor(Color.tasker.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .taskerDenseSurface(
                    cornerRadius: TaskerTheme.CornerRadius.md,
                    fillColor: metric.tone.fillColor,
                    strokeColor: metric.tone.strokeColor
                )
            }
        }
    }
}

private struct HabitMetricDisplay: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tone: HabitMetricTone
}

@MainActor
private enum HabitMetricTone {
    case accent
    case warning
    case success
    case neutral

    var fillColor: Color {
        switch self {
        case .accent:
            return Color.tasker.accentWash
        case .warning:
            return Color.tasker.statusWarning.opacity(0.12)
        case .success:
            return Color.tasker.statusSuccess.opacity(0.12)
        case .neutral:
            return Color.tasker.surfaceSecondary
        }
    }

    var strokeColor: Color {
        switch self {
        case .accent:
            return Color.tasker.accentPrimary.opacity(0.22)
        case .warning:
            return Color.tasker.statusWarning.opacity(0.22)
        case .success:
            return Color.tasker.statusSuccess.opacity(0.22)
        case .neutral:
            return Color.tasker.strokeHairline.opacity(0.74)
        }
    }

    var textColor: Color {
        switch self {
        case .accent:
            return Color.tasker.accentPrimary
        case .warning:
            return Color.tasker.statusWarning
        case .success:
            return Color.tasker.statusSuccess
        case .neutral:
            return Color.tasker.textPrimary
        }
    }
}

private struct HabitHistoryLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            legendDot(color: Color.tasker.statusSuccess, label: "Success")
            legendDot(color: Color.tasker.statusDanger, label: "Lapse")
            legendDot(color: Color.tasker.textTertiary, label: "Skip")
            legendDot(color: Color.tasker.strokeHairline, label: "Quiet")
        }
        .font(.tasker(.caption2))
        .foregroundColor(Color.tasker.textSecondary)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

private struct HabitDefinitionLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(Color.tasker.textSecondary)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.tasker(.body))
                .foregroundColor(Color.tasker.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private enum HabitActionMessageTone {
    case neutral
    case warning
}

@MainActor
private struct HabitActionMessageCard: View {
    let title: String
    let message: String
    let tone: HabitActionMessageTone

    var fillColor: Color {
        switch tone {
        case .neutral:
            return Color.tasker.surfaceSecondary
        case .warning:
            return Color.tasker.statusWarning.opacity(0.12)
        }
    }

    var strokeColor: Color {
        switch tone {
        case .neutral:
            return Color.tasker.strokeHairline.opacity(0.72)
        case .warning:
            return Color.tasker.statusWarning.opacity(0.24)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundColor(Color.tasker.textPrimary)
            Text(message)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .taskerDenseSurface(cornerRadius: TaskerTheme.CornerRadius.md, fillColor: fillColor, strokeColor: strokeColor)
    }
}

private struct HabitPill: View {
    let text: String
    let tone: HabitPillTone

    var body: some View {
        Text(text)
            .font(.tasker(.caption2).weight(.semibold))
            .foregroundColor(tone.textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tone.fillColor)
            .overlay(
                Capsule()
                    .stroke(tone.strokeColor, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

@MainActor
private enum HabitPillTone {
    case accent
    case neutral
    case success
    case warning

    var textColor: Color {
        switch self {
        case .accent:
            return Color.tasker.accentPrimary
        case .neutral:
            return Color.tasker.textSecondary
        case .success:
            return Color.tasker.statusSuccess
        case .warning:
            return Color.tasker.statusWarning
        }
    }

    var fillColor: Color {
        switch self {
        case .accent:
            return Color.tasker.accentWash
        case .neutral:
            return Color.tasker.surfaceSecondary
        case .success:
            return Color.tasker.statusSuccess.opacity(0.12)
        case .warning:
            return Color.tasker.statusWarning.opacity(0.12)
        }
    }

    var strokeColor: Color {
        switch self {
        case .accent:
            return Color.tasker.accentPrimary.opacity(0.18)
        case .neutral:
            return Color.tasker.strokeHairline.opacity(0.72)
        case .success:
            return Color.tasker.statusSuccess.opacity(0.22)
        case .warning:
            return Color.tasker.statusWarning.opacity(0.22)
        }
    }
}

@MainActor
private struct HabitActionButtonStyle: ButtonStyle {
    enum Tone {
        case secondary
        case warning
        case destructive
    }

    let tone: Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.tasker(.callout).weight(.semibold))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.86 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(TaskerAnimation.quick, value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        switch tone {
        case .secondary:
            return Color.tasker.surfaceSecondary
        case .warning:
            return Color.tasker.statusWarning.opacity(0.12)
        case .destructive:
            return Color.tasker.statusDanger.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .secondary:
            return Color.tasker.strokeHairline.opacity(0.8)
        case .warning:
            return Color.tasker.statusWarning.opacity(0.22)
        case .destructive:
            return Color.tasker.statusDanger.opacity(0.22)
        }
    }

    private var textColor: Color {
        switch tone {
        case .secondary:
            return Color.tasker.textPrimary
        case .warning:
            return Color.tasker.statusWarning
        case .destructive:
            return Color.tasker.statusDanger
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
