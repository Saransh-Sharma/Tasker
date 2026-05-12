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
            return String(localized: "Archived", defaultValue: "Archived")
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
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).corner }

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
        let lifeArea = viewModel.lifeAreas.first(where: { $0.id == viewModel.selectedLifeAreaID })?.name ?? "Pick an area"
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

    private var composerAccentColor: Color {
        HabitEverydayPalette.familyPreview(
            HabitColorFamily.family(
                for: viewModel.selectedColorHex,
                fallback: viewModel.selectedKind == .positive ? .green : .coral
            )
        )
    }

    private var composerAccentWash: Color {
        composerAccentColor.opacity(0.14)
    }

    private var selectedComposerAccentTitle: String {
        habitAccentPresetMatch(
            for: viewModel.selectedColorHex,
            fallback: viewModel.selectedKind == .positive ? .green : .coral
        )?.title ?? HabitColorFamily.family(
            for: viewModel.selectedColorHex,
            fallback: viewModel.selectedKind == .positive ? .green : .coral
        ).title
    }

    private var advancedSummary: String {
        var pieces: [String] = []
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
            return "Type, reminders, notes, and appearance"
        }
        return pieces.joined(separator: " · ")
    }

    private var trimmedWindowSummary: String {
        let start = viewModel.reminderWindowStart.nilIfBlank
        let end = viewModel.reminderWindowEnd.nilIfBlank
        switch (start, end) {
        case (.some(let start), .some(let end)):
            return "\(start) to \(end)"
        case (.some(let start), .none):
            return "Starts \(start)"
        case (.none, .some(let end)):
            return "Until \(end)"
        case (.none, .none):
            return viewModel.selectedTrackingMode == .lapseOnly ? "Recovery window unset" : "Reminder window unset"
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
                        placeholder: "Name this habit",
                        helperText: "Start with the behavior. Add the why and the details later.",
                        onSubmit: onCreate
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    baseComposerSections
                        .enhancedStaggeredAppearance(index: 1)

                    advancedDisclosure
                        .enhancedStaggeredAppearance(index: 2)

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
        .background(Color.lifeboard.bgCanvas)
        .accessibilityIdentifier("addHabit.view")
        .overlay(
            Color.lifeboard.statusSuccess
                .opacity(successFlash ? 0.045 : 0)
                .animation(reduceMotion ? nil : LifeBoardAnimation.ctaConfirmation, value: successFlash)
                .allowsHitTesting(false)
        )
        .task {
            viewModel.loadIfNeeded()
            showAdvancedSettings = hasAdvancedContent
        }
    }

    private var baseComposerSections: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: spacing.s16) {
                    cadenceSection
                    ownershipSection
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: spacing.s16) {
                        cadenceSection
                            .frame(maxWidth: .infinity, alignment: .leading)
                        ownershipSection
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: spacing.s16) {
                        cadenceSection
                        ownershipSection
                    }
                }
            }
        }
    }

    private var habitKindPicker: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HabitSectionLabel(title: "Habit type", detail: "Switch this only when the habit is about avoiding a slip.")

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
                HabitSectionLabel(title: "Support style", detail: "Choose daily accountability or only log slips.")

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
            HabitSectionLabel(title: "Cadence", detail: "Pick a rhythm you can restart easily.")

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
            .lifeboardDenseSurface(cornerRadius: corner.r2, fillColor: Color.lifeboard.surfacePrimary)
        }
    }

    private var ownershipSection: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            if viewModel.isLoading {
                HabitInlineMessage(
                    title: "Loading areas and projects",
                    message: "Fetching your latest life areas and project lists."
                )
            }

            if let dependencyError = viewModel.errorMessage,
               viewModel.lifeAreas.isEmpty {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    Text("Couldn't load ownership options.")
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.statusWarning)
                    Text(dependencyError)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Retry loading options") {
                        viewModel.reloadDependencies()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("addHabit.ownership.retry")
                }
            }

            LifeBoardComposerOptionGrid(
                title: "Life Area",
                helperText: "Every habit needs a home.",
                options: viewModel.lifeAreas.map {
                    LifeBoardComposerOption(
                        id: $0.id,
                        title: $0.name,
                        icon: $0.icon,
                        accentHex: LifeAreaColorPalette.normalizeOrMap(hex: $0.color, for: $0.id)
                    )
                },
                selectedID: viewModel.selectedLifeAreaID,
                noneOptionTitle: nil,
                emptyStateText: viewModel.lifeAreas.isEmpty ? "No life areas yet." : nil,
                accessibilityIdentifier: "addHabit.lifeAreaSelector"
            ) { selectedID in
                withAnimation(LifeBoardAnimation.snappy) {
                    viewModel.selectedLifeAreaID = selectedID
                }
            }

            LifeBoardComposerOptionGrid(
                title: "Project",
                helperText: "Optional. Filtered to the selected area.",
                options: viewModel.filteredProjectsForSelectedLifeArea.map {
                    LifeBoardComposerOption(id: $0.project.id, title: $0.project.name, icon: nil, accentHex: nil)
                },
                selectedID: viewModel.selectedProjectID,
                noneOptionTitle: "No project",
                emptyStateText: viewModel.filteredProjectsForSelectedLifeArea.isEmpty ? "No projects in this area." : nil,
                accessibilityIdentifier: "addHabit.projectSelector"
            ) { selectedID in
                withAnimation(LifeBoardAnimation.snappy) {
                    viewModel.selectedProjectID = selectedID
                }
            }

            if viewModel.selectedLifeAreaID == nil {
                Text("Pick an area before saving.")
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.statusWarning)
            }
        }
    }

    private var advancedDisclosure: some View {
        LifeBoardComposerDisclosureRow(
            title: "Add details",
            summary: advancedSummary,
            isExpanded: showAdvancedSettings,
            accessibilityIdentifier: "addHabit.detailsDisclosure"
        ) {
            if reduceMotion {
                showAdvancedSettings.toggle()
            } else {
                withAnimation(LifeBoardAnimation.panelIn) {
                    showAdvancedSettings.toggle()
                }
            }
            if showAdvancedSettings == false {
                titleFieldFocused = false
            }
        }
    }

    @ViewBuilder
    private var advancedSections: some View {
        VStack(spacing: spacing.s16) {
            HabitSurfaceCard(
                title: "Behavior setup",
                subtitle: "Only change the habit type when this is about resisting a slip.",
                iconSystemName: "slider.horizontal.3"
            ) {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    habitKindPicker
                    trackingModeSection
                }
            }
            .enhancedStaggeredAppearance(index: 3)

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
                            .font(.lifeboard(.meta))
                            .foregroundStyle(Color.lifeboard.statusWarning)
                    } else {
                        Text(viewModel.selectedTrackingMode == .lapseOnly ? "Use a recovery window when slips usually show up." : "Use this if you want the habit to nudge inside a deliberate part of the day.")
                            .font(.lifeboard(.meta))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 4)

            HabitSurfaceCard(
                title: "Appearance",
                subtitle: "Pick an icon and accent color that make the habit easy to spot.",
                iconSystemName: "square.grid.2x2"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    HStack(spacing: spacing.s12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                                .fill(composerAccentWash)
                                .frame(width: 52, height: 52)

                            Image(systemName: viewModel.selectedIconSymbolName ?? "circle.dashed")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(composerAccentColor)
                        }

                        TextField("Search SF Symbols", text: $viewModel.iconSearchQuery)
                            .textFieldStyle(LifeBoardTextFieldStyle())
                    }

                    HabitAccentPaletteField(
                        selectedHex: $viewModel.selectedColorHex,
                        selectedTitle: selectedComposerAccentTitle,
                        previewColor: composerAccentColor,
                        previewFamily: HabitColorFamily.family(
                            for: viewModel.selectedColorHex,
                            fallback: viewModel.selectedKind == .positive ? .green : .coral
                        )
                    )

                    let options = Array(viewModel.availableIconOptions.prefix(layoutClass.isPad ? 24 : 16))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 84 : 72), spacing: spacing.s8)], spacing: spacing.s8) {
                        ForEach(options) { option in
                            iconButton(option)
                        }
                    }
                }
            }
            .enhancedStaggeredAppearance(index: 5)

            HabitSurfaceCard(
                title: "Why this matters",
                subtitle: "Capture a trigger, replacement action, or the reason you want this to stick.",
                iconSystemName: "note.text"
            ) {
                TextEditor(text: $viewModel.habitNotes)
                    .font(.lifeboard(.body))
                    .frame(minHeight: layoutClass.isPad ? 120 : 110)
                    .padding(.horizontal, spacing.s12)
                    .padding(.vertical, spacing.s8)
                    .lifeboardDenseSurface(cornerRadius: corner.r2, fillColor: Color.lifeboard.surfacePrimary)
            }
            .enhancedStaggeredAppearance(index: 6)
        }
    }

    private var hasAdvancedContent: Bool {
        viewModel.reminderWindowStart.nilIfBlank != nil
            || viewModel.reminderWindowEnd.nilIfBlank != nil
            || viewModel.habitNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || viewModel.iconSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || viewModel.selectedKind == .negative
    }

    private func expandAdvancedIfNeeded() {
        guard showAdvancedSettings == false else { return }
        if reduceMotion {
            showAdvancedSettings = true
        } else {
            withAnimation(LifeBoardAnimation.snappy) {
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
            withAnimation(LifeBoardAnimation.snappy) {
                viewModel.selectedIconSymbolName = option.symbolName
            }
        } label: {
            VStack(spacing: spacing.s8) {
                Image(systemName: option.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(isSelected ? Color.lifeboard.accentWash : Color.lifeboard.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text(option.displayName)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, spacing.s4)
            .padding(.vertical, spacing.s8)
            .lifeboardDenseSurface(
                cornerRadius: corner.r2,
                fillColor: isSelected ? Color.lifeboard.accentWash.opacity(0.7) : Color.lifeboard.surfaceSecondary,
                strokeColor: isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.strokeHairline
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
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textTertiary)

            TextField(placeholder, text: text)
                .font(.lifeboard(.body))
                .padding(.horizontal, spacing.s12)
                .frame(height: spacing.buttonHeight)
                .lifeboardDenseSurface(cornerRadius: corner.r2, fillColor: Color.lifeboard.surfacePrimary)
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
                .foregroundColor(Color.lifeboard.statusWarning)

            Text(message)
                .font(.lifeboard(.callout))
                .foregroundColor(Color.lifeboard.statusWarning)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .lifeboardDenseSurface(
            cornerRadius: corner.r2,
            fillColor: Color.lifeboard.statusWarning.opacity(0.12),
            strokeColor: Color.lifeboard.statusWarning.opacity(0.24)
        )
        .animation(LifeBoardAnimation.bouncy, value: viewModel.errorMessage != nil)
    }
}

@MainActor
struct HabitLibraryView: View {
    @ObservedObject var viewModel: HabitLibraryViewModel
    @State private var selectedRow: HabitLibraryRow?
    @State private var selectedFilter: HabitLibraryFilter = .active
    @State private var searchText = ""
    @State private var habitComposerPresented = false
    @State private var habitComposerSuccessFlash = false
    @StateObject private var habitComposerViewModel = PresentationDependencyContainer.shared.makeNewAddHabitViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).corner }

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
            .background(Color.lifeboard.bgCanvas)
            .navigationTitle("Manage Habits")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        presentHabitComposer()
                    } label: {
                        Label("Add Habit", systemImage: "plus")
                    }
                    .accessibilityLabel("Add habit")
                }
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
            .sheet(isPresented: $habitComposerPresented) {
                AddHabitForedropView(
                    viewModel: habitComposerViewModel,
                    containerMode: .sheet,
                    showAddAnother: false,
                    successFlash: $habitComposerSuccessFlash,
                    onCancel: {
                        habitComposerPresented = false
                    },
                    onCreate: {
                        createHabitFromLibrary()
                    },
                    onAddAnother: {
                        createHabitFromLibrary()
                    },
                    onExpandToLarge: {}
                )
                .background(Color.lifeboard(.bgCanvas))
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
                systemImage: "clock.arrow.circlepath",
                title: "Loading habits",
                message: "Pulling in your behavior loops and their latest streak signals.",
                showsProgress: true
            )
        } else if filteredRows.isEmpty {
            if searchText.isEmpty {
                HabitEmptyStateCard(
                    systemImage: "circle.dashed",
                    title: emptyTitle,
                    message: emptyBody,
                    actionTitle: "Add Habit",
                    action: presentHabitComposer
                )
            } else {
                HabitEmptyStateCard(
                    systemImage: "magnifyingglass",
                    title: "No matching habits",
                    message: "Try a different search or switch filters to see more habits."
                )
            }
        } else {
            LazyVGrid(columns: columns, spacing: spacing.s12) {
                ForEach(filteredRows) { row in
                    Button {
                        LifeBoardPerformanceTrace.event("HabitDetailTapReceived")
                        selectedRow = row
                    } label: {
                        HabitLibraryCard(row: row)
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
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

    private func presentHabitComposer() {
        habitComposerViewModel.resetForm()
        habitComposerPresented = true
    }

    private func createHabitFromLibrary() {
        guard habitComposerViewModel.canSubmit, habitComposerViewModel.isSaving == false else { return }
        habitComposerViewModel.createHabit { result in
            guard case .success = result else { return }
            Task { @MainActor in
                habitComposerPresented = false
                viewModel.refresh()
            }
        }
    }
}

struct HabitDetailSheetView: View {
    @StateObject private var viewModel: HabitDetailViewModel
    private let onMutation: @MainActor @Sendable () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @State private var isDetailsExpanded = false
    @State private var snackbar: SnackbarData?

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    init(viewModel: HabitDetailViewModel, onMutation: @escaping @MainActor @Sendable () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onMutation = onMutation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    if viewModel.isEditing {
                        editingCards
                    } else {
                        readOnlyContent
                    }
                }
                .padding(.horizontal, spacing.s12)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s24)
            }
            .background(Color.lifeboard.bgCanvas)
            .accessibilityIdentifier(HabitDetailAccessibilityID.view)
            .navigationTitle(viewModel.isEditing ? "Edit Habit" : viewModel.row.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                LifeBoardPerformanceTrace.event("HabitDetailSheetPresented")
            }
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
	                            let onMutation = onMutation
	                            viewModel.saveChanges {
	                                Task { @MainActor in onMutation() }
	                            }
                        }
                        .accessibilityIdentifier(HabitDetailAccessibilityID.saveButton)
                        .disabled(!viewModel.canSave || viewModel.isSaving)
                    } else {
                        Button {
                            viewModel.beginEditing()
                        } label: {
                            HStack(spacing: spacing.s4) {
                                if viewModel.isPreparingEditorData {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(viewModel.isPreparingEditorData ? "Loading" : "Edit")
                            }
                        }
                        .accessibilityIdentifier(HabitDetailAccessibilityID.editButton)
                        .disabled(viewModel.isSaving || viewModel.isPreparingEditorData)
                    }
                }
            }
            .task {
                viewModel.loadIfNeeded()
            }
            .onChange(of: viewModel.mutationFeedback) { _, feedback in
                guard let feedback else { return }
                snackbar = SnackbarData(message: feedback.message, autoDismissSeconds: 2)
                playMutationHaptic(feedback.haptic)
                viewModel.clearMutationFeedback()
            }
            .alert(
                "Couldn’t update habit",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.clearError() } }
                )
            ) {
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .lifeboardSnackbar($snackbar)
        }
    }

    private var readOnlyContent: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            HabitDetailContextStrip(
                row: viewModel.row,
                metaLine: metaLine,
                cadenceLine: cadenceSummary(viewModel.row.cadence)
            )

            HabitDetailCalendarMountHost(
                row: viewModel.row,
                calendarViewState: viewModel.calendarViewState,
                helperText: viewModel.detailCalendarHelperText,
                isMounted: viewModel.isCalendarMounted,
                isLoading: viewModel.isCalendarLoading,
                isSaving: viewModel.isSaving
	            ) { cell in
	                let onMutation = onMutation
	                viewModel.mutateDay(cell) {
	                    Task { @MainActor in onMutation() }
	                }
            }

            HStack(spacing: spacing.s8) {
                HabitDetailMetricCapsule(
                    title: "Current streak",
                    value: "\(viewModel.row.currentStreak)d",
                    detail: viewModel.row.bestStreak > 0 ? "Best \(viewModel.row.bestStreak)d" : "No best streak yet"
                )
                HabitDetailMetricCapsule(
                    title: "Next due",
                    value: nextDueSummary,
                    detail: cadenceSummary(viewModel.row.cadence)
                )
            }

            DisclosureGroup(
                isExpanded: $isDetailsExpanded.animation(LifeBoardAnimation.snappy)
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    HabitDefinitionLine(label: "Ownership", value: ownershipSummary)
                    HabitDefinitionLine(label: "Cadence", value: cadenceSummary(viewModel.row.cadence))
                    HabitDefinitionLine(label: "Reminder", value: reminderSummary)

                    if let notes = viewModel.row.notes, notes.isEmpty == false {
                        HabitActionMessageCard(
                            title: "Notes",
                            message: notes,
                            tone: .neutral
                        )
                    }

                    lifecycleContent
                        .padding(.top, spacing.s4)
                }
                .padding(.top, spacing.s12)
            } label: {
                HStack(spacing: spacing.s8) {
                    Text("Details & lifecycle")
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard.textPrimary)

                    Spacer(minLength: 0)

                    Text(isDetailsExpanded ? "Collapse" : "Expand")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                }
            }
            .padding(spacing.s16)
            .lifeboardDenseSurface(
                cornerRadius: LifeBoardTheme.CornerRadius.card,
                fillColor: Color.lifeboard.surfacePrimary,
                strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
            )
            .accessibilityIdentifier(HabitDetailAccessibilityID.detailsDisclosure)

            if let error = viewModel.errorMessage {
                HabitActionMessageCard(
                    title: "Couldn’t update habit",
                    message: error,
                    tone: .warning
                )
            }
        }
    }

    private var editingCards: some View {
        VStack(spacing: spacing.s16) {
            HabitSurfaceCard(
                title: "Essentials",
                subtitle: "Keep the name and behavior clear.",
                iconSystemName: "sparkles"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    TextField("Title", text: $viewModel.draft.title)
                        .textFieldStyle(LifeBoardTextFieldStyle())

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

            HabitSurfaceCard(
                title: "Schedule",
                subtitle: "Set when this habit should show up.",
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
                            .font(.lifeboard(.caption2))
                            .foregroundColor(Color.lifeboard.statusWarning)
                    }
                }
            }

            HabitSurfaceCard(
                title: "Organize",
                subtitle: "Keep the habit attached to the right area or project.",
                iconSystemName: "square.grid.2x2"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    AddTaskEntityPicker(
                        label: "Area",
                        items: viewModel.lifeAreas.map {
                            AddTaskEntityPickerItem(
                                id: $0.id,
                                name: $0.name,
                                icon: $0.icon,
                                accentHex: LifeAreaColorPalette.normalizeOrMap(hex: $0.color, for: $0.id)
                            )
                        },
                        selectedID: $viewModel.draft.lifeAreaID
                    )

                    AddTaskEntityPicker(
                        label: "Project",
                        items: viewModel.projects.map {
                            AddTaskEntityPickerItem(
                                id: $0.project.id,
                                name: $0.project.name,
                                icon: nil,
                                accentHex: nil
                            )
                        },
                        selectedID: $viewModel.draft.projectID
                    )
                }
            }

            HabitSurfaceCard(
                title: "Notes and appearance",
                subtitle: "Keep the reason clear and choose how it should look.",
                iconSystemName: "swatchpalette"
            ) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    TextEditor(text: $viewModel.draft.notes)
                        .font(.lifeboard(.body))
                        .frame(minHeight: 110)
                        .padding(.horizontal, spacing.s12)
                        .padding(.vertical, spacing.s8)
                        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: Color.lifeboard.surfacePrimary)

                    HabitAccentPaletteField(
                        selectedHex: $viewModel.draft.colorHex,
                        selectedTitle: habitAccentPresetMatch(
                            for: viewModel.draft.colorHex,
                            fallback: viewModel.draft.kind == .positive ? .green : .coral
                        )?.title ?? "Custom",
                        previewColor: LifeBoardHexColor.color(
                            viewModel.draft.colorHex.nilIfBlank,
                            fallback: viewModel.draft.kind == .positive ? Color.lifeboard.statusSuccess : Color.lifeboard.statusWarning
                        ),
                        previewFamily: HabitColorFamily.family(
                            for: viewModel.draft.colorHex,
                            fallback: viewModel.draft.kind == .positive ? .green : .coral
                        )
                    )

                    TextField("Search icons", text: $viewModel.draft.iconSearchQuery)
                        .textFieldStyle(LifeBoardTextFieldStyle())

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing.s8) {
                            ForEach(viewModel.availableIconOptions.prefix(18)) { option in
                                Button {
                                    viewModel.draft.selectedIconSymbolName = option.symbolName
                                } label: {
                                    Image(systemName: option.symbolName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                                        .frame(width: 40, height: 40)
                                        .background(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            HabitSurfaceCard(
                title: "Lifecycle",
                subtitle: "Change the state of the habit without losing its history.",
                iconSystemName: "arrow.triangle.branch"
            ) {
                lifecycleContent
            }
        }
    }

    private var lifecycleContent: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
	            Button(viewModel.row.isPaused ? "Resume habit" : "Pause habit") {
	                let onMutation = onMutation
	                viewModel.togglePause {
	                    Task { @MainActor in onMutation() }
	                }
            }
            .buttonStyle(HabitActionButtonStyle(tone: .secondary))
            .disabled(viewModel.isSaving)

	            if viewModel.row.trackingMode == .lapseOnly && !viewModel.row.isArchived {
	                Button("Log lapse") {
	                    let onMutation = onMutation
	                    viewModel.logLapse {
	                        Task { @MainActor in onMutation() }
	                    }
                }
                .buttonStyle(HabitActionButtonStyle(tone: .warning))
                .disabled(viewModel.isSaving)
            }

	            Button(String(localized: "Archive", defaultValue: "Archive") + " habit") {
	                let onMutation = onMutation
	                viewModel.archive {
	                    Task { @MainActor in onMutation() }
	                }
            }
            .buttonStyle(HabitActionButtonStyle(tone: .destructive))
            .disabled(viewModel.isSaving || viewModel.row.isArchived)

            Text("Pause keeps history intact. Archive removes the habit from active views.")
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
            return String(localized: "Archived", defaultValue: "Archived")
        }
        return "Not scheduled"
    }

    private var reminderSummary: String {
        let start = trimmedReminderValue(viewModel.row.reminderWindowStart) ?? "Not set"
        let end = trimmedReminderValue(viewModel.row.reminderWindowEnd) ?? "Not set"
        return "\(start) to \(end)"
    }

    private var metaLine: String {
        var parts = [viewModel.row.lifeAreaName]
        if let projectName = viewModel.row.projectName, projectName.isEmpty == false {
            parts.append(projectName)
        }
        parts.append(viewModel.row.trackingMode == .lapseOnly ? "Lapse only" : "Daily check-in")
        return parts.joined(separator: " · ")
    }

    private var ownershipSummary: String {
        if let projectName = viewModel.row.projectName, projectName.isEmpty == false {
            return "\(viewModel.row.lifeAreaName) · \(projectName)"
        }
        return viewModel.row.lifeAreaName
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
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textTertiary)

            TextField(title, text: text)
                .textFieldStyle(LifeBoardTextFieldStyle())
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

    private func playMutationHaptic(_ haptic: HabitDetailMutationFeedbackHaptic) {
        switch haptic {
        case .selection:
            LifeBoardFeedback.selection()
        case .success:
            LifeBoardFeedback.success()
        case .warning:
            LifeBoardFeedback.warning()
        }
    }
}

private struct HabitAccentPreset: Identifiable {
    let family: HabitColorFamily

    var id: String { family.rawValue }
    var title: String { family.title }
    var hex: String { family.canonicalHex }
}

private let habitAccentPresets: [HabitAccentPreset] = HabitColorFamily.allCases.map(HabitAccentPreset.init)

private func habitAccentPresetMatch(
    for hex: String?,
    fallback: HabitColorFamily
) -> HabitAccentPreset? {
    let family = HabitColorFamily.family(for: hex, fallback: fallback)
    return habitAccentPresets.first { $0.family == family }
}

private struct HabitAccentPaletteField: View {
    @Binding var selectedHex: String
    let selectedTitle: String
    let previewColor: Color
    let previewFamily: HabitColorFamily

    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(spacing: spacing.s8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(previewColor)
                    .frame(width: 14, height: 14)

                Text("Streak family")
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                Text(selectedTitle)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)

                Spacer(minLength: 0)

                if selectedHex.nilIfBlank != nil {
                    Button("Clear") {
                        selectedHex = ""
                    }
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .buttonStyle(.plain)
                }
            }

            HabitBoardStripView(
                cells: previewCells,
                family: previewFamily,
                mode: .expanded
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.s8) {
                    ForEach(habitAccentPresets) { preset in
                        HabitAccentSwatchButton(
                            preset: preset,
                            isSelected: LifeBoardHexColor.normalized(selectedHex.nilIfBlank) == LifeBoardHexColor.normalized(preset.hex)
                        ) {
                            selectedHex = preset.hex
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            DisclosureGroup("Advanced custom hex") {
                TextField("Accent color (hex, optional)", text: $selectedHex)
                    .textFieldStyle(LifeBoardTextFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.top, 8)
            }
            .font(.lifeboard(.caption1))
            .foregroundStyle(Color.lifeboard.textSecondary)
        }
    }

    private var previewCells: [HabitBoardCell] {
        [
            HabitBoardCell(date: Date(), state: .done(depth: 1), isToday: false, isWeekend: false),
            HabitBoardCell(date: Date(), state: .done(depth: 2), isToday: false, isWeekend: false),
            HabitBoardCell(date: Date(), state: .done(depth: 3), isToday: false, isWeekend: false),
            HabitBoardCell(date: Date(), state: .bridge(kind: .single, source: .skipped), isToday: false, isWeekend: false),
            HabitBoardCell(date: Date(), state: .done(depth: 4), isToday: false, isWeekend: false),
            HabitBoardCell(date: Date(), state: .done(depth: 5), isToday: false, isWeekend: false),
            HabitBoardCell(date: Date(), state: .missed, isToday: false, isWeekend: false),
            HabitBoardCell(date: Date(), state: .done(depth: 1), isToday: true, isWeekend: false)
        ]
    }
}

private struct HabitAccentSwatchButton: View {
    let preset: HabitAccentPreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: UIColor(lifeboardHex: preset.hex)))
                .frame(width: 42, height: 42)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.95), lineWidth: 2)
                            .padding(2)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(
                            isSelected ? Color.lifeboard.textPrimary.opacity(0.4) : Color.lifeboard.strokeHairline.opacity(0.45),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(preset.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .scaleOnPress()
    }
}

private struct HabitComposerSummaryCard: View {
    let iconSymbolName: String
    let title: String
    let modeSummary: String
    let cadenceSummary: String
    let ownershipSummary: String
    let accentColor: Color
    let isExpanded: Bool
    let successFlash: Bool
    let reminderSummary: String

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(spacing: spacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 58, height: 58)

                    if reduceMotion {
                        Image(systemName: iconSymbolName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(accentColor)
                    } else {
                        Image(systemName: iconSymbolName)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(accentColor)
                            .symbolEffect(.pulse.byLayer, value: successFlash || isExpanded)
                    }
                }

                VStack(alignment: .leading, spacing: spacing.s4) {
                    HStack(spacing: spacing.s8) {
                        Text(successFlash ? "Habit captured" : "Behavior loop")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(accentColor)
                        LifeBoardStatusPill(
                            text: isExpanded ? "Refined" : "Essentials",
                            systemImage: isExpanded ? "slider.horizontal.3" : "sparkles",
                            tone: isExpanded ? .accent : .quiet
                        )
                    }

                    Text(title)
                        .font(.lifeboard(.title3))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(2)

                    Text(modeSummary)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(accentColor)
                }

                Spacer(minLength: 0)

                LifeBoardStatusPill(
                    text: successFlash ? "Saved" : (isExpanded ? "Expanded" : "Calm"),
                    systemImage: successFlash ? "checkmark.circle.fill" : "leaf.fill",
                    tone: successFlash ? .success : .quiet
                )
            }

            HStack(spacing: spacing.s8) {
                LifeBoardHeroMetricTile(
                    title: "Cadence",
                    value: cadenceSummary,
                    detail: ownershipSummary,
                    tone: .accent
                )
                LifeBoardHeroMetricTile(
                    title: "Window",
                    value: reminderSummary,
                    detail: isExpanded ? "Advanced settings visible" : "Advanced stays optional",
                    tone: reminderSummary.contains("unset") ? .warning : .neutral
                )
            }
        }
        .padding(spacing.s16)
        .lifeboardPremiumSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            accentColor: accentColor,
            level: .e2
        )
        .lifeboardSuccessPulse(isActive: successFlash)
    }
}

private enum HabitDetailAccessibilityID {
    static let view = "habitDetail.view"
    static let grid = "habitDetail.grid"
    static let contextPrimary = "habitDetail.context.primary"
    static let contextSecondary = "habitDetail.context.secondary"
    static let detailsDisclosure = "habitDetail.detailsDisclosure"
    static let helperText = "habitDetail.helperText"
    static let editButton = "habitDetail.editButton"
    static let saveButton = "habitDetail.saveButton"
    static func dayCell(_ date: Date) -> String { HabitDetailCalendarBuilder.accessibilityIdentifier(for: date) }
}

enum HabitDetailCalendarLayoutMetrics {
    static let columnCount = 7
    static let cellSpacing: CGFloat = 3
    static let minimumCellSide: CGFloat = 44
    static let maximumCellSide: CGFloat = 52

    static func cellSide(for availableWidth: CGFloat) -> CGFloat {
        let requiredSpacing = CGFloat(columnCount - 1) * cellSpacing
        let cellWidth = (availableWidth - requiredSpacing) / CGFloat(columnCount)
        return min(maximumCellSide, max(minimumCellSide, floor(cellWidth)))
    }

    static func requiredWidth(for availableWidth: CGFloat) -> CGFloat {
        let cellSide = cellSide(for: availableWidth)
        return (cellSide * CGFloat(columnCount)) + (CGFloat(columnCount - 1) * cellSpacing)
    }
}

private struct HabitDetailContextStrip: View {
    let row: HabitLibraryRow
    let metaLine: String
    let cadenceLine: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 42, height: 42)

                Image(systemName: row.icon?.symbolName ?? "circle.dashed")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(metaLine)
                    .font(.lifeboard(.support).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(2)
                    .accessibilityIdentifier(HabitDetailAccessibilityID.contextPrimary)

                Text(cadenceLine)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(2)
                    .accessibilityIdentifier(HabitDetailAccessibilityID.contextSecondary)
            }

            Spacer(minLength: 0)

            if row.isArchived || row.isPaused {
                Text(row.isArchived ? String(localized: "Archived", defaultValue: "Archived") : "Paused")
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.lifeboard.surfaceSecondary)
                    .clipShape(Capsule())
            }
        }
    }

    private var accentColor: Color {
        LifeBoardHexColor.color(
            row.colorHex,
            fallback: row.kind == .positive ? Color.lifeboard.statusSuccess : Color.lifeboard.statusWarning
        )
    }
}

private struct HabitDetailMetricCapsule: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(title)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
            Text(detail)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
    }
}

private struct HabitDetailCalendarMountHost: View {
    let row: HabitLibraryRow
    let calendarViewState: HabitDetailCalendarViewState
    let helperText: String
    let isMounted: Bool
    let isLoading: Bool
    let isSaving: Bool
    let onTapDay: (HabitDetailDayCell) -> Void

    var body: some View {
        if isMounted {
            HabitDetailCalendarSection(
                row: row,
                viewState: calendarViewState,
                helperText: helperText,
                isLoading: isLoading,
                isSaving: isSaving,
                onTapDay: onTapDay
            )
        } else {
            HabitDetailCalendarPlaceholder(helperText: helperText)
        }
    }
}

private struct HabitDetailCalendarPlaceholder: View {
    let helperText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                Text(helperText)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(HabitDetailAccessibilityID.helperText)
            }

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.lifeboard.surfaceSecondary.opacity(0.65))
                .frame(height: 184)
                .overlay {
                    ProgressView()
                        .controlSize(.small)
                }
        }
        .padding(12)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
    }
}

private struct HabitDetailCalendarSection: View {
    let row: HabitLibraryRow
    let viewState: HabitDetailCalendarViewState
    let helperText: String
    let isLoading: Bool
    let isSaving: Bool
    let onTapDay: (HabitDetailDayCell) -> Void

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                Text(helperText)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(HabitDetailAccessibilityID.helperText)
            }

            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width, HabitDetailCalendarLayoutMetrics.requiredWidth(for: 0))
                let gridWidth = HabitDetailCalendarLayoutMetrics.requiredWidth(for: availableWidth)
                let cellSide = HabitDetailCalendarLayoutMetrics.cellSide(for: availableWidth)

                VStack(alignment: .leading, spacing: spacing.s8) {
                    weekdayHeader(cellSide: cellSide)

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            ForEach(viewState.weeks) { week in
                                VStack(alignment: .leading, spacing: spacing.s4) {
                                    if let monthLabel = week.monthLabel {
                                        Text(monthLabel)
                                            .font(.lifeboard(.caption1).weight(.semibold))
                                            .foregroundStyle(Color.lifeboard.textSecondary)
                                    }

                                    HStack(spacing: HabitDetailCalendarLayoutMetrics.cellSpacing) {
                                        ForEach(week.cells) { cell in
                                            HabitDetailCalendarDayCellView(
                                                row: row,
                                                cell: cell,
                                                side: cellSide,
                                                isSaving: isSaving
                                            ) {
                                                onTapDay(cell.cell)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: gridWidth, alignment: .leading)
                    }
                    .accessibilityIdentifier(HabitDetailAccessibilityID.grid)
                }
            }
            .frame(height: gridHeight)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing streaks")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                }
            }
        }
        .padding(12)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
    }

    private var gridHeight: CGFloat {
        let weekCount = max(viewState.weeks.count, 1)
        let monthLabelCount = viewState.weeks.reduce(0) { partialResult, week in
            partialResult + (week.monthLabel == nil ? 0 : 1)
        }
        let rowSpacing = CGFloat(max(weekCount - 1, 0)) * spacing.s8
        let monthLabelHeight = CGFloat(monthLabelCount) * 18
        let monthLabelSpacing = CGFloat(monthLabelCount) * spacing.s4
        let baselineCellSide = HabitDetailCalendarLayoutMetrics.maximumCellSide
        return 18 + spacing.s8 + (CGFloat(weekCount) * baselineCellSide) + rowSpacing + monthLabelHeight + monthLabelSpacing
    }

    private func weekdayHeader(cellSide: CGFloat) -> some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols

        return HStack(spacing: HabitDetailCalendarLayoutMetrics.cellSpacing) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.lifeboard(.caption2).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: cellSide, alignment: .center)
            }
        }
    }
}

private struct HabitDetailCalendarDayCellView: View {
    let row: HabitLibraryRow
    let cell: HabitDetailCalendarCellViewState
    let side: CGFloat
    let isSaving: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle()
                    .fill(fillColor)

                Rectangle()
                    .strokeBorder(borderColor, style: strokeStyle)

                if cell.cell.isToday {
                    Rectangle()
                        .strokeBorder(HabitEverydayPalette.todayStroke(colorScheme: colorScheme), lineWidth: 1.5)
                        .padding(1)
                }

                Text(cell.dayNumber)
                    .font(.lifeboard(.callout).weight(textWeight))
                    .foregroundStyle(textColor)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: side, height: side)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!cell.cell.isInteractive || isSaving)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(cell.accessibilityIdentifier)
        .accessibilityLabel(cell.accessibilityLabel)
        .accessibilityValue(cell.accessibilityValue)
        .accessibilityHint(cell.accessibilityHint)
        .accessibilityAddTraits(cell.cell.isInteractive ? .isButton : .isStaticText)
    }

    private var colorFamily: HabitColorFamily {
        HabitColorFamily.family(
            for: row.colorHex,
            fallback: row.kind == .positive ? .green : .coral
        )
    }

    private var fillColor: Color {
        switch cell.cell.state {
        case .empty:
            return HabitEverydayPalette.paperFill(colorScheme: colorScheme)
        case .success:
            return HabitEverydayPalette.depthColor(
                for: colorFamily,
                depth: max(1, min(cell.streakDepth ?? 1, 8)),
                colorScheme: colorScheme
            )
        case .skipped:
            return HabitEverydayPalette.paperFill(colorScheme: colorScheme)
        case .lapsed:
            return HabitEverydayPalette.missedFill(colorScheme: colorScheme)
        case .notScheduled:
            return HabitEverydayPalette.paperFill(colorScheme: colorScheme)
        case .future:
            return HabitEverydayPalette.futureFill(colorScheme: colorScheme)
        }
    }

    private var borderColor: Color {
        switch cell.cell.state {
        case .empty:
            return HabitEverydayPalette.gridStroke(colorScheme: colorScheme).opacity(0.85)
        case .success:
            return HabitEverydayPalette.gridStroke(colorScheme: colorScheme).opacity(0.7)
        case .skipped:
            return HabitEverydayPalette.gridStroke(colorScheme: colorScheme).opacity(0.9)
        case .lapsed:
            return Color.lifeboard.statusDanger.opacity(0.44)
        case .notScheduled:
            return HabitEverydayPalette.gridStroke(colorScheme: colorScheme).opacity(0.78)
        case .future:
            return HabitEverydayPalette.gridStroke(colorScheme: colorScheme).opacity(0.55)
        }
    }

    private var strokeStyle: StrokeStyle {
        switch cell.cell.state {
        case .skipped:
            return StrokeStyle(lineWidth: 1, dash: [4, 3])
        default:
            return StrokeStyle(lineWidth: 1)
        }
    }

    private var textColor: Color {
        switch cell.cell.state {
        case .empty:
            return Color.lifeboard.textPrimary
        case .success:
            return successTextColor
        case .skipped:
            return Color.lifeboard.textSecondary
        case .lapsed:
            return Color.lifeboard.statusDanger
        case .notScheduled, .future:
            return Color.lifeboard.textTertiary
        }
    }

    private var textWeight: Font.Weight {
        switch cell.cell.state {
        case .success, .lapsed:
            return .semibold
        default:
            return .medium
        }
    }

    private var successTextColor: Color {
        let depth = cell.streakDepth ?? 1
        if depth >= 4 {
            return Color.white.opacity(colorScheme == .dark ? 0.95 : 0.98)
        }
        return Color.lifeboard.textPrimary
    }
}

private struct HabitSurfaceCard<Content: View>: View {
    let title: String
    let subtitle: String
    let iconSystemName: String
    let content: Content

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

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
                    .foregroundColor(Color.lifeboard.accentPrimary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .font(.lifeboard(.headline))
                        .foregroundColor(Color.lifeboard.textPrimary)
                    Text(subtitle)
                        .font(.lifeboard(.caption1))
                        .foregroundColor(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(spacing.s16)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary)
    }
}

private struct HabitSectionLabel: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
            Text(detail)
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textSecondary)
        }
    }
}

private struct HabitWeekdayPickerRow: View {
    @Binding var selectedDays: [Int]

    @ObservedObject private var themeManager = LifeBoardThemeManager.shared
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens { themeManager.tokens(for: layoutClass).spacing }

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
                    LifeBoardFeedback.selection()
                    withAnimation(LifeBoardAnimation.snappy) {
                        toggle(item.day)
                    }
                } label: {
                    Text(item.label)
                        .font(.lifeboard(.callout))
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            Circle()
                                .fill(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceTertiary)
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

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(title)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundColor(Color.lifeboard.accentPrimary)
            Text(message)
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(spacing.s8)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: Color.lifeboard.accentWash,
            strokeColor: Color.lifeboard.accentPrimary.opacity(0.18)
        )
    }
}

private struct HabitLibrarySummaryHeader: View {
    let activeCount: Int
    let pausedCount: Int
    let archivedCount: Int

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text("Habit system")
                .font(.lifeboard(.screenTitle))
                .foregroundColor(Color.lifeboard.textPrimary)

            Text("Keep recurring behavior legible without turning it into more task noise.")
                .font(.lifeboard(.body))
                .foregroundColor(Color.lifeboard.textSecondary)

            HStack(spacing: spacing.s8) {
                HabitCountPill(title: "Active", value: activeCount, tone: .accent)
                HabitCountPill(title: "Paused", value: pausedCount, tone: .neutral)
                HabitCountPill(title: String(localized: "Archived", defaultValue: "Archived"), value: archivedCount, tone: .neutral)
            }
        }
        .padding(spacing.s16)
        .lifeboardPremiumSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            accentColor: Color.lifeboard.accentSecondary
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
                .font(.lifeboard(.title3))
                .foregroundColor(tone.textColor)
            Text(title)
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: tone.fillColor,
            strokeColor: tone.strokeColor
        )
    }
}

private struct HabitLibraryControlRail: View {
    @Binding var selectedFilter: HabitLibraryFilter
    @Binding var searchText: String

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(spacing: spacing.s8) {
                ForEach(HabitLibraryFilter.allCases) { filter in
                    Button {
                        withAnimation(LifeBoardAnimation.snappy) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.lifeboard(.callout).weight(.semibold))
                            .foregroundColor(selectedFilter == filter ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textSecondary)
                            .frame(maxWidth: .infinity)
            .padding(.vertical, spacing.s8)
                            .background(selectedFilter == filter ? Color.lifeboard.accentPrimary : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .scaleOnPress()
                }
            }
            .padding(spacing.s4)
            .lifeboardChromeSurface(
                cornerRadius: LifeBoardTheme.CornerRadius.pill,
                accentColor: Color.lifeboard.accentSecondary,
                level: .e1
            )

            HStack(spacing: spacing.s8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.lifeboard.textSecondary)
                TextField("Search habits, life areas, or projects", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.lifeboard(.body))
            }
            .padding(.horizontal, spacing.s12)
            .frame(height: spacing.buttonHeight)
            .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: Color.lifeboard.surfacePrimary)
        }
    }
}

private struct HabitLibraryCard: View {
    let row: HabitLibraryRow

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: row.icon?.symbolName ?? "circle.dashed")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(row.title)
                        .font(.lifeboard(.headline))
                        .foregroundColor(Color.lifeboard.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: spacing.s4) {
                        HabitPill(text: row.kind == .positive ? "Build" : "Quit", tone: row.kind == .positive ? .success : .warning)
                        HabitPill(text: row.trackingMode == .lapseOnly ? "Log lapse only" : "Daily check-in", tone: .neutral)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(metaLine)
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textSecondary)
                .lineLimit(2)

            HabitHistoryStripView(
                marks: row.last14Days,
                cadence: row.cadence,
                family: HabitColorFamily.family(
                    for: row.colorHex,
                    fallback: row.kind == .positive ? .green : .coral
                )
            )

            HStack(spacing: spacing.s8) {
                HabitMiniMetric(title: "Current", value: "\(row.currentStreak)d")
                HabitMiniMetric(title: "Best", value: "\(row.bestStreak)d")
                HabitMiniMetric(title: stateLabel, value: stateValue)
            }
        }
        .padding(spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary)
    }

    private var kindColor: Color {
        row.kind == .positive ? Color.lifeboard.statusSuccess : Color.lifeboard.statusWarning
    }

    private var accentColor: Color {
        LifeBoardHexColor.color(row.colorHex, fallback: kindColor)
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
        if row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
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
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundColor(Color.lifeboard.textPrimary)
            Text(title)
                .font(.lifeboard(.caption2))
                .foregroundColor(Color.lifeboard.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: Color.lifeboard.surfaceSecondary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
    }
}

private struct HabitEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    let showsProgress: Bool
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        showsProgress: Bool = false,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.showsProgress = showsProgress
        self.actionTitle = actionTitle
        self.action = action
    }

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(spacing: spacing.s12) {
            if showsProgress {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color.lifeboard.textSecondary)
            }

            Text(title)
                .font(.lifeboard(.headline))
                .foregroundColor(Color.lifeboard.textPrimary)

            Text(message)
                .font(.lifeboard(.body))
                .foregroundColor(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(spacing.s20)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary)
    }
}

private struct HabitDetailHeroCard: View {
    let row: HabitLibraryRow
    let historyMarks: [HabitDayMark]
    let isEditing: Bool

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(toneColor.opacity(0.14))
                        .frame(width: 56, height: 56)

                    Image(systemName: row.icon?.symbolName ?? "circle.dashed")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(toneColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(row.title)
                        .font(.lifeboard(.title2))
                        .foregroundColor(Color.lifeboard.textPrimary)
                        .lineLimit(3)

                    HStack(spacing: spacing.s4) {
                        HabitPill(text: row.kind == .positive ? "Build" : "Quit", tone: row.kind == .positive ? .success : .warning)
                        HabitPill(text: row.trackingMode == .lapseOnly ? "Log lapse only" : "Daily check-in", tone: .neutral)
                        HabitPill(text: row.isArchived ? String(localized: "Archived", defaultValue: "Archived") : (row.isPaused ? "Paused" : (isEditing ? "Editing" : "Live")), tone: row.isArchived ? .neutral : .accent)
                    }
                }

                Spacer(minLength: 0)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: spacing.s8) {
                    LifeBoardHeroMetricTile(
                        title: "Current streak",
                        value: "\(row.currentStreak)d",
                        detail: row.bestStreak > 0 ? "Best \(row.bestStreak)d" : "Fresh cycle",
                        tone: row.currentStreak > 0 ? .success : .neutral
                    )
                    LifeBoardHeroMetricTile(
                        title: "Next due",
                        value: nextDueText,
                        detail: ownershipText,
                        tone: row.isPaused || row.isArchived ? .neutral : .accent
                    )
                }

                VStack(spacing: spacing.s8) {
                    LifeBoardHeroMetricTile(
                        title: "Current streak",
                        value: "\(row.currentStreak)d",
                        detail: row.bestStreak > 0 ? "Best \(row.bestStreak)d" : "Fresh cycle",
                        tone: row.currentStreak > 0 ? .success : .neutral
                    )
                    LifeBoardHeroMetricTile(
                        title: "Next due",
                        value: nextDueText,
                        detail: ownershipText,
                        tone: row.isPaused || row.isArchived ? .neutral : .accent
                    )
                }
            }

            HabitHistoryStripView(
                marks: historyMarks,
                cadence: row.cadence,
                family: HabitColorFamily.family(
                    for: row.colorHex,
                    fallback: row.kind == .positive ? .green : .coral
                )
            )
        }
        .padding(spacing.s20)
        .lifeboardPremiumSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            accentColor: toneColor
        )
    }

    private var toneColor: Color {
        LifeBoardHexColor.color(row.colorHex, fallback: row.kind == .positive ? Color.lifeboard.statusSuccess : Color.lifeboard.statusWarning)
    }

    private var nextDueText: String {
        if row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
        if row.isPaused { return "Paused" }
        if let nextDueAt = row.nextDueAt {
            return nextDueAt.formatted(date: .abbreviated, time: .shortened)
        }
        return "Not scheduled"
    }

    private var ownershipText: String {
        if let projectName = row.projectName, projectName.isEmpty == false {
            return "\(row.lifeAreaName) · \(projectName)"
        }
        return row.lifeAreaName
    }
}

private struct HabitMetricGrid: View {
    let metrics: [HabitMetricDisplay]
    @Environment(\.lifeboardLayoutClass) private var layoutClass

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
                        .font(.lifeboard(.bodyStrong))
                        .foregroundColor(metric.tone.textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(metric.title)
                        .font(.lifeboard(.caption2))
                        .foregroundColor(Color.lifeboard.textSecondary)
                    if let detail = metric.detail {
                        Text(detail)
                            .font(.lifeboard(.caption2))
                            .foregroundColor(Color.lifeboard.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .lifeboardDenseSurface(
                    cornerRadius: LifeBoardTheme.CornerRadius.md,
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
    var detail: String? = nil
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
            return Color.lifeboard.accentWash
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.12)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.12)
        case .neutral:
            return Color.lifeboard.surfaceSecondary
        }
    }

    var strokeColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary.opacity(0.22)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.22)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.22)
        case .neutral:
            return Color.lifeboard.strokeHairline.opacity(0.74)
        }
    }

    var textColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary
        case .warning:
            return Color.lifeboard.statusWarning
        case .success:
            return Color.lifeboard.statusSuccess
        case .neutral:
            return Color.lifeboard.textPrimary
        }
    }
}

private struct HabitHistoryLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            legendDot(color: Color.lifeboard.statusSuccess, label: "Success")
            legendDot(color: Color.lifeboard.statusDanger, label: "Lapse")
            legendDot(color: Color.lifeboard.textTertiary, label: "Skip")
            legendDot(color: Color.lifeboard.strokeHairline, label: "Quiet")
        }
        .font(.lifeboard(.caption2))
        .foregroundColor(Color.lifeboard.textSecondary)
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
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundColor(Color.lifeboard.textSecondary)
                .frame(width: 88, alignment: .leading)

            Text(value)
                .font(.lifeboard(.body))
                .foregroundColor(Color.lifeboard.textPrimary)
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
            return Color.lifeboard.surfaceSecondary
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.12)
        }
    }

    var strokeColor: Color {
        switch tone {
        case .neutral:
            return Color.lifeboard.strokeHairline.opacity(0.72)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.24)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundColor(Color.lifeboard.textPrimary)
            Text(message)
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: fillColor, strokeColor: strokeColor)
    }
}

private struct HabitPill: View {
    let text: String
    let tone: HabitPillTone

    var body: some View {
        Text(text)
            .font(.lifeboard(.caption2).weight(.semibold))
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
            return Color.lifeboard.accentPrimary
        case .neutral:
            return Color.lifeboard.textSecondary
        case .success:
            return Color.lifeboard.statusSuccess
        case .warning:
            return Color.lifeboard.statusWarning
        }
    }

    var fillColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentWash
        case .neutral:
            return Color.lifeboard.surfaceSecondary
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.12)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.12)
        }
    }

    var strokeColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary.opacity(0.18)
        case .neutral:
            return Color.lifeboard.strokeHairline.opacity(0.72)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.22)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.22)
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
            .font(.lifeboard(.callout).weight(.semibold))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.86 : 1))
            .overlay(
                RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous))
            .shadow(
                color: configuration.isPressed ? borderColor.opacity(0.12) : .clear,
                radius: configuration.isPressed ? 10 : 0,
                y: configuration.isPressed ? 6 : 0
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(LifeBoardAnimation.quick, value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        switch tone {
        case .secondary:
            return Color.lifeboard.surfaceSecondary
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.12)
        case .destructive:
            return Color.lifeboard.statusDanger.opacity(0.12)
        }
    }

    private var borderColor: Color {
        switch tone {
        case .secondary:
            return Color.lifeboard.strokeHairline.opacity(0.8)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.22)
        case .destructive:
            return Color.lifeboard.statusDanger.opacity(0.22)
        }
    }

    private var textColor: Color {
        switch tone {
        case .secondary:
            return Color.lifeboard.textPrimary
        case .warning:
            return Color.lifeboard.statusWarning
        case .destructive:
            return Color.lifeboard.statusDanger
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
