//
//  SunriseHabitDetailScreen.swift
//  LifeBoard
//
//  Sunrise Glass habit detail screen with progressive disclosure.
//

import SwiftUI

private enum SunriseHabitCadencePreset: String, CaseIterable, Identifiable {
    case daily
    case weekly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        }
    }
}

struct SunriseHabitDetailScreen: View {
    @StateObject private var viewModel: HabitDetailViewModel
    private let onMutation: @MainActor @Sendable () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showDetailReveal = false
    @State private var completionBurstTrigger = 0
    @State private var sawTodayCompletionThisSession = false
    @State private var isInitialReadOnlyHydrationComplete = false
    @State private var isInitialEditorSupportHydrationComplete = false
    @State private var snackbar: SnackbarData?

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var isInitialDraftHydrationComplete: Bool {
        isInitialReadOnlyHydrationComplete && isInitialEditorSupportHydrationComplete
    }
    private var isErrorAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if isPresented == false { viewModel.clearError() }
            }
        )
    }

    init(viewModel: HabitDetailViewModel, onMutation: @escaping @MainActor @Sendable () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onMutation = onMutation
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: spacing.s16) {
                headerChrome
                alwaysEditableContent
            }
            .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 760 : .infinity, alignment: .center)
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s32)
        }
        .background(sunriseBackground)
        .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.view)
        .task {
            isInitialReadOnlyHydrationComplete = false
            isInitialEditorSupportHydrationComplete = false
            viewModel.loadIfNeeded {
                isInitialReadOnlyHydrationComplete = true
            }
            viewModel.prepareAlwaysEditableSupport {
                isInitialEditorSupportHydrationComplete = true
            }
        }
        .onAppear {
            LifeBoardPerformanceTrace.event("SunriseHabitDetailScreenPresented")
        }
        .onDisappear {
            viewModel.flushPendingAutosave()
        }
        .onChange(of: viewModel.mutationFeedback) { _, feedback in
            guard let feedback else { return }
            snackbar = SnackbarData(message: feedback.message, autoDismissSeconds: 2)
            playMutationHaptic(feedback.haptic)
            viewModel.clearMutationFeedback()
        }
        .onChange(of: viewModel.draft.title) { _, _ in scheduleAutosaveIfHydrated(debounced: true) }
        .onChange(of: viewModel.draft.notes) { _, _ in scheduleAutosaveIfHydrated(debounced: true) }
        .onChange(of: viewModel.draft.kind) { _, _ in
            viewModel.normalizeDraftSelection()
            scheduleAutosaveIfHydrated(debounced: false)
        }
        .onChange(of: viewModel.draft.trackingMode) { _, _ in scheduleAutosaveIfHydrated(debounced: false) }
        .onChange(of: viewModel.draft.cadence) { _, _ in scheduleAutosaveIfHydrated(debounced: false) }
        .onChange(of: viewModel.draft.lifeAreaID) { _, _ in
            viewModel.normalizeDraftSelection()
            scheduleAutosaveIfHydrated(debounced: false)
        }
        .onChange(of: viewModel.draft.projectID) { _, _ in scheduleAutosaveIfHydrated(debounced: false) }
        .onChange(of: viewModel.draft.reminderWindowStart) { _, _ in scheduleAutosaveIfHydrated(debounced: false) }
        .onChange(of: viewModel.draft.reminderWindowEnd) { _, _ in scheduleAutosaveIfHydrated(debounced: false) }
        .onChange(of: viewModel.draft.selectedIconSymbolName) { _, _ in scheduleAutosaveIfHydrated(debounced: false) }
        .onChange(of: viewModel.draft.colorHex) { _, _ in scheduleAutosaveIfHydrated(debounced: false) }
        .lifeboardSnackbar($snackbar)
        .alert(
            "Couldn’t update habit",
            isPresented: isErrorAlertPresented
        ) {
            Button("OK", role: .cancel) { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? "Please try again.")
        }
    }

    private func scheduleAutosaveIfHydrated(debounced: Bool) {
        guard isInitialDraftHydrationComplete else { return }
        viewModel.scheduleAutosave(debounced: debounced)
    }

    private var headerChrome: some View {
        HStack(spacing: spacing.s12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.lifeboard.surfaceSecondary.opacity(0.72), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            VStack(alignment: .leading, spacing: 2) {
                Text("Habit")
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textTertiary)
                Text(viewModel.row.title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: spacing.s8)

            if viewModel.isPreparingEditorData {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Loading habit editor")
            }
            SunriseAutosaveWhisper(state: viewModel.autosaveState)
        }
    }

    private var alwaysEditableContent: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            heroCard
            autosaveFailureBanner
            detailReveal {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    CalmFieldGroup(title: "Essentials") { essentialsEditorContent }
                    CalmFieldGroup(title: "Rhythm") { rhythmEditorContent }
                    CalmFieldGroup(title: "Appearance") { appearanceContent }
                    CalmFieldGroup(title: "Lifecycle") { lifecycleContent }
                }
            }
            habitProgressCard
        }
    }

    @ViewBuilder
    private var autosaveFailureBanner: some View {
        if case .failed(let message) = viewModel.autosaveState {
            HStack(alignment: .center, spacing: spacing.s12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(LifeBoardDetailTonePalette.dangerText)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Retry") { viewModel.retryAutosave() }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isSaving)
            }
            .padding(spacing.s12)
            .background(LifeBoardDetailTonePalette.dangerText.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.autosaveFailure)
        }
    }

    private func detailReveal<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        CalmInlineReveal(
            title: "Details",
            collapsedHint: rhythmSummary,
            isExpanded: $showDetailReveal,
            accessibilityID: SunriseHabitDetailAccessibilityID.detailsDisclosure,
            onToggle: {
                LifeBoardFeedback.light()
                withAnimation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.snappy) {
                    showDetailReveal.toggle()
                }
            },
            content: content
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 58, height: 58)
                    Image(systemName: viewModel.draft.selectedIconSymbolName ?? viewModel.row.icon?.symbolName ?? "circle.dashed")
                        .font(.lifeboard(.title2))
                        .foregroundStyle(accentColor)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(
                            LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.snappy,
                            value: viewModel.draft.selectedIconSymbolName
                        )
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    TextField("Habit title", text: $viewModel.draft.title, axis: .vertical)
                        .font(.lifeboard(.title2))
                        .bold()
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(3)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Habit title")

                    HStack(spacing: spacing.s4) {
                        LifeBoardStatusPill(text: viewModel.draft.kind == .positive ? "Build" : "Quit", systemImage: "sparkles", tone: viewModel.draft.kind == .positive ? .success : .warning)
                        LifeBoardStatusPill(text: habitStateLabel, systemImage: habitStateSymbol, tone: viewModel.row.isArchived || viewModel.row.isPaused ? .quiet : .accent)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(metaLine)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.contextPrimary)

            if viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Habit title cannot be empty")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LifeBoardDetailTonePalette.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(cadenceSummary(viewModel.draft.cadence))
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.contextSecondary)
        }
        .padding(spacing.s16)
        .lifeboardPremiumSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary, accentColor: accentColor, level: .e2)
    }

    private var habitProgressCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text("Habit Progress")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text("A quiet view of the last \(HabitDetailCalendarBuilder.historyDayCount) days.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SunriseHabitCalendarSection(
                row: viewModel.row,
                viewState: viewModel.calendarViewState,
                helperText: viewModel.detailCalendarHelperText,
                isLoading: viewModel.isCalendarLoading,
                isSaving: viewModel.isSaving,
                onTapDay: mutate
            )

            SunriseHabitMetricGrid(
                metrics: viewModel.calendarViewState.summaryMetrics,
                accentColor: accentColor
            )

            if let todayCell {
                Button(todayActionTitle(for: todayCell), systemImage: todayActionSymbol(for: todayCell)) {
                    mutate(todayCell)
                }
                .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .success))
                .disabled(!todayCell.isInteractive || viewModel.isSaving)
                .completionCelebration(isComplete: todayCell.state == .success, tint: accentColor)
                .lbCelebrationBurst(trigger: completionBurstTrigger, tint: accentColor)
            }
        }
        .padding(spacing.s12)
        .lifeboardPremiumSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            accentColor: accentColor,
            level: .e1
        )
    }

    private var essentialsEditorContent: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
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
            }
        }
    }

    private var rhythmEditorContent: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
                Picker("Cadence", selection: cadencePresetBinding) {
                    ForEach(SunriseHabitCadencePreset.allCases) { cadence in
                        Text(cadence.title).tag(cadence)
                    }
                }
                .pickerStyle(.segmented)

                if cadencePresetBinding.wrappedValue == .weekly {
                    SunriseHabitWeekdayPickerRow(selectedDays: weeklyDaysBinding)
                }

                DatePicker("Check-in time", selection: cadenceTimeBinding, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)

                SunriseHabitReminderWindowPicker(
                    isEnabled: viewModel.draft.hasReminderWindow,
                    startDate: Binding(
                        get: { viewModel.draft.reminderWindowStartPickerDate },
                        set: { viewModel.draft.reminderWindowStartPickerDate = $0 }
                    ),
                    endDate: Binding(
                        get: { viewModel.draft.reminderWindowEndPickerDate },
                        set: { viewModel.draft.reminderWindowEndPickerDate = $0 }
                    ),
                    onEnable: {
                        withAnimation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.snappy) {
                            viewModel.draft.ensureReminderWindowDefaults()
                        }
                    },
                    onClear: {
                        withAnimation(LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) ? nil : LifeBoardAnimation.snappy) {
                            viewModel.draft.clearReminderWindow()
                        }
                    },
                    accessibilityIdentifierPrefix: "habitDetail.reminderWindow"
                )

                if let reminderError = viewModel.editorReminderWindowValidationError {
                    Text(reminderError)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(LifeBoardDetailTonePalette.dangerText)
                }

                if !viewModel.lifeAreas.isEmpty {
                    AddTaskEntityPicker(
                        label: "Area",
                        items: viewModel.lifeAreas.map { AddTaskEntityPickerItem(id: $0.id, name: $0.name, icon: $0.icon, accentHex: LifeAreaColorPalette.normalizeOrMap(hex: $0.color, for: $0.id)) },
                        selectedID: $viewModel.draft.lifeAreaID
                    )
                }

                if !viewModel.projects.isEmpty {
                    AddTaskEntityPicker(
                        label: "Project",
                        items: viewModel.projects.map { AddTaskEntityPickerItem(id: $0.project.id, name: $0.project.name, icon: nil, accentHex: nil) },
                        selectedID: $viewModel.draft.projectID
                    )
                }

                TextField("Notes", text: $viewModel.draft.notes, axis: .vertical)
                    .lineLimit(3...7)
                    .textFieldStyle(LifeBoardTextFieldStyle())

        }
    }

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
                TextField("Search icons", text: $viewModel.draft.iconSearchQuery)
                    .textFieldStyle(LifeBoardTextFieldStyle())

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing.s8) {
                        ForEach(viewModel.availableIconOptions.prefix(18)) { option in
                            Button {
                                viewModel.draft.selectedIconSymbolName = option.symbolName
                            } label: {
                                Image(systemName: option.symbolName)
                                    .font(LBTypographyTokens.bodyStrong)
                                    .foregroundStyle(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                                    .frame(width: LifeBoardCreationChipMetrics.compactSwatchSize, height: LifeBoardCreationChipMetrics.compactSwatchSize)
                                    .background(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: LifeBoardCreationChipMetrics.compactCornerRadius, style: .continuous))
                            }
                            .frame(width: LifeBoardCreationChipMetrics.hitHeight, height: LifeBoardCreationChipMetrics.hitHeight)
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.displayName)
                        }
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing.s8) {
                        ForEach(HabitColorFamily.allCases, id: \.rawValue) { family in
                            Button {
                                viewModel.draft.colorHex = family.canonicalHex
                            } label: {
                                RoundedRectangle(cornerRadius: LifeBoardCreationChipMetrics.compactCornerRadius, style: .continuous)
                                    .fill(Color(lifeboardHex: family.canonicalHex))
                                    .frame(width: LifeBoardCreationChipMetrics.compactSwatchSize, height: LifeBoardCreationChipMetrics.compactSwatchSize)
                                    .overlay {
                                        if colorFamily == family {
                                            RoundedRectangle(cornerRadius: LifeBoardCreationChipMetrics.compactCornerRadius, style: .continuous)
                                                .stroke(Color.lifeboard.accentOnPrimary, lineWidth: 2)
                                                .padding(3)
                                        }
                                    }
                            }
                            .frame(width: LifeBoardCreationChipMetrics.hitHeight, height: LifeBoardCreationChipMetrics.hitHeight)
                            .buttonStyle(.plain)
                            .accessibilityLabel(family.title)
                        }
                    }
                }
        }
    }

    private var lifecycleContent: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
                Button(viewModel.row.isPaused ? "Resume habit" : "Pause habit", systemImage: viewModel.row.isPaused ? "play.fill" : "pause.fill") {
                    viewModel.togglePause { didSucceed in
                        if didSucceed { notifyMutation() }
                    }
                }
                .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .quiet))
                .disabled(viewModel.isSaving)

                if viewModel.row.trackingMode == .lapseOnly && !viewModel.row.isArchived {
                    Button("Log lapse", systemImage: "arrow.uturn.backward.circle") {
                        viewModel.logLapse { didSucceed in
                            if didSucceed { notifyMutation() }
                        }
                    }
                    .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .warning))
                    .disabled(viewModel.isSaving)
                }

                Button(String(localized: "Archive", defaultValue: "Archive") + " habit", systemImage: "archivebox.fill") {
                    viewModel.archive { didSucceed in
                        if didSucceed { notifyMutation() }
                    }
                }
                .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .danger))
                .disabled(viewModel.isSaving || viewModel.row.isArchived)

                Text("Pause keeps history intact. Archive removes the habit from active views.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
        }
    }

    private func definitionLine(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textTertiary)
            Text(value)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textPrimary)
        }
    }

    private var sunriseBackground: some View {
        LinearGradient(
            colors: [
                LBColorTokens.warmCanvas,
                LBColorTokens.canvas,
                LBColorTokens.coolCanvas
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var todayCell: HabitDetailDayCell? {
        viewModel.calendarViewState.weeks
            .flatMap(\.cells)
            .map(\.cell)
            .first(where: \.isToday)
    }

    private var colorFamily: HabitColorFamily {
        HabitColorFamily.family(
            for: viewModel.draft.colorHex,
            fallback: viewModel.draft.kind == .positive ? .green : .coral
        )
    }

    private var accentColor: Color {
        LifeBoardHexColor.color(
            viewModel.draft.colorHex,
            fallback: viewModel.draft.kind == .positive ? Color.lifeboard.statusSuccess : Color.lifeboard.statusWarning
        )
    }

    private var habitStateLabel: String {
        if viewModel.row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
        if viewModel.row.isPaused { return "Paused" }
        return "Live"
    }

    private var habitStateSymbol: String {
        if viewModel.row.isArchived { return "archivebox.fill" }
        if viewModel.row.isPaused { return "pause.fill" }
        return "leaf.fill"
    }

    private var reminderSummary: String {
        let startText = viewModel.draft.reminderWindowStart.trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = viewModel.draft.reminderWindowEnd.trimmingCharacters(in: .whitespacesAndNewlines)
        let start = startText.isEmpty ? "Not set" : startText
        let end = endText.isEmpty ? "Not set" : endText
        return "\(start) to \(end)"
    }

    private var rhythmSummary: String {
        "\(cadenceSummary(viewModel.draft.cadence)) · \(reminderSummary)"
    }

    private var appearanceSummary: String {
        let icon = viewModel.draft.selectedIconSymbolName ?? viewModel.row.icon?.symbolName ?? "circle.dashed"
        return "\(colorFamily.title) · \(icon)"
    }

    private var ownershipSummary: String {
        if let projectName = selectedProjectName, projectName.isEmpty == false {
            return "\(selectedLifeAreaName) · \(projectName)"
        }
        return selectedLifeAreaName
    }

    private var metaLine: String {
        var parts = [selectedLifeAreaName]
        if let projectName = selectedProjectName, projectName.isEmpty == false {
            parts.append(projectName)
        }
        parts.append(viewModel.draft.trackingMode == .lapseOnly ? "Lapse only" : "Daily check-in")
        return parts.joined(separator: " · ")
    }

    private var selectedLifeAreaName: String {
        viewModel.lifeAreas.first { $0.id == viewModel.draft.lifeAreaID }?.name ?? viewModel.row.lifeAreaName
    }

    private var selectedProjectName: String? {
        if let projectID = viewModel.draft.projectID {
            return viewModel.projects.first { $0.project.id == projectID }?.project.name ?? viewModel.row.projectName
        }
        return nil
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
        let date = calendar.date(bySettingHour: hour ?? 9, minute: minute ?? 0, second: 0, of: calendar.startOfDay(for: Date())) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func weekdaySummary(_ days: [Int]) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        if days.count == 5 && days == [2, 3, 4, 5, 6] { return "Weekdays" }
        if days.count == 7 { return "Every day" }
        return days.compactMap { day in
            let index = max(0, min(symbols.count - 1, day - 1))
            guard symbols.indices.contains(index) else { return nil }
            return symbols[index]
        }.joined(separator: " · ")
    }

    private func todayActionTitle(for cell: HabitDetailDayCell) -> String {
        switch cell.state {
        case .success: return "Mark today skipped"
        case .skipped, .lapsed: return "Reset today"
        case .future: return "Today is upcoming"
        default:
            return viewModel.row.trackingMode == .lapseOnly ? "Log today" : "Mark today done"
        }
    }

    private func todayActionSymbol(for cell: HabitDetailDayCell) -> String {
        switch cell.state {
        case .success: return "arrow.uturn.backward.circle"
        case .skipped, .lapsed: return "minus.circle"
        default: return "checkmark.circle.fill"
        }
    }

    private var cadencePresetBinding: Binding<SunriseHabitCadencePreset> {
        Binding(
            get: {
                switch viewModel.draft.cadence {
                case .daily: return .daily
                case .weekly: return .weekly
                }
            },
            set: { preset in
                let time = cadenceTime(from: viewModel.draft.cadence)
                switch preset {
                case .daily:
                    viewModel.draft.cadence = .daily(hour: time.hour, minute: time.minute)
                case .weekly:
                    let days = weeklyDays(from: viewModel.draft.cadence)
                    viewModel.draft.cadence = .weekly(daysOfWeek: days.isEmpty ? [2, 3, 4, 5, 6] : days, hour: time.hour, minute: time.minute)
                }
            }
        )
    }

    private var weeklyDaysBinding: Binding<[Int]> {
        Binding(
            get: {
                let days = weeklyDays(from: viewModel.draft.cadence)
                return days.isEmpty ? [2, 3, 4, 5, 6] : days
            },
            set: { days in
                let time = cadenceTime(from: viewModel.draft.cadence)
                viewModel.draft.cadence = .weekly(daysOfWeek: days.sorted().isEmpty ? [2, 3, 4, 5, 6] : days.sorted(), hour: time.hour, minute: time.minute)
            }
        )
    }

    private var cadenceTimeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let time = cadenceTime(from: viewModel.draft.cadence)
                return calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: calendar.startOfDay(for: Date())) ?? Date()
            },
            set: { date in
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: date)
                let minute = calendar.component(.minute, from: date)
                switch viewModel.draft.cadence {
                case .daily:
                    viewModel.draft.cadence = .daily(hour: hour, minute: minute)
                case .weekly(let days, _, _):
                    viewModel.draft.cadence = .weekly(daysOfWeek: days, hour: hour, minute: minute)
                }
            }
        )
    }

    private func cadenceTime(from cadence: HabitCadenceDraft) -> (hour: Int?, minute: Int?) {
        switch cadence {
        case .daily(let hour, let minute): return (hour, minute)
        case .weekly(_, let hour, let minute): return (hour, minute)
        }
    }

    private func weeklyDays(from cadence: HabitCadenceDraft) -> [Int] {
        switch cadence {
        case .daily: return []
        case .weekly(let days, _, _): return days
        }
    }

    private func mutate(_ cell: HabitDetailDayCell) {
        let onMutation = onMutation
        let willCompleteToday = cell.isToday && cell.state != .success && cell.state != .future
        viewModel.mutateDay(cell) { didSucceed in
            guard didSucceed else { return }
            if willCompleteToday, sawTodayCompletionThisSession == false {
                sawTodayCompletionThisSession = true
                completionBurstTrigger += 1
            }
            onMutation()
        }
    }

    private func notifyMutation() {
        let onMutation = onMutation
        Task { @MainActor in onMutation() }
    }

    private func playMutationHaptic(_ haptic: HabitDetailMutationFeedbackHaptic) {
        switch haptic {
        case .selection: LifeBoardFeedback.selection()
        case .success: LifeBoardFeedback.success()
        case .warning: LifeBoardFeedback.warning()
        }
    }
}

private enum SunriseHabitDetailAccessibilityID {
    static let view = "habitDetail.view"
    static let grid = "habitDetail.grid"
    static let contextPrimary = "habitDetail.context.primary"
    static let contextSecondary = "habitDetail.context.secondary"
    static let detailsDisclosure = "habitDetail.detailsDisclosure"
    static let helperText = "habitDetail.helperText"
    static let autosaveFailure = "habitDetail.autosaveFailure"
    static let currentStreakMetric = "habitDetail.metric.currentStreak"
    static let bestStreakMetric = "habitDetail.metric.bestStreak"
    static let totalCountMetric = "habitDetail.metric.totalCount"
    static let completionRateMetric = "habitDetail.metric.completionRate"
}

private enum SunriseHabitCalendarMetrics {
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
        let side = cellSide(for: availableWidth)
        return (side * CGFloat(columnCount)) + (CGFloat(columnCount - 1) * cellSpacing)
    }
}

enum HabitDetailCalendarLayoutMetrics {
    static let columnCount = SunriseHabitCalendarMetrics.columnCount
    static let cellSpacing = SunriseHabitCalendarMetrics.cellSpacing
    static let minimumCellSide = SunriseHabitCalendarMetrics.minimumCellSide
    static let maximumCellSide = SunriseHabitCalendarMetrics.maximumCellSide

    static func cellSide(for availableWidth: CGFloat) -> CGFloat {
        SunriseHabitCalendarMetrics.cellSide(for: availableWidth)
    }

    static func requiredWidth(for availableWidth: CGFloat) -> CGFloat {
        SunriseHabitCalendarMetrics.requiredWidth(for: availableWidth)
    }
}

private struct SunriseHabitMetricGrid: View {
    let metrics: HabitDetailCalendarSummaryMetrics
    let accentColor: Color

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: spacing.s8) {
                metricTiles
            }

            LazyVGrid(columns: compactColumns, spacing: spacing.s8) {
                metricTiles
            }
        }
    }

    @ViewBuilder
    private var metricTiles: some View {
        SunriseHabitMetricTile(
            title: "Current",
            subtitle: "Active",
            value: metrics.currentStreakDisplay,
            valueColor: accentColor,
            accessibilityIdentifier: SunriseHabitDetailAccessibilityID.currentStreakMetric
        )
        SunriseHabitMetricTile(
            title: "Longest",
            subtitle: "Active",
            value: metrics.bestStreakDisplay,
            valueColor: Color.lifeboard.textPrimary,
            accessibilityIdentifier: SunriseHabitDetailAccessibilityID.bestStreakMetric
        )
        SunriseHabitMetricTile(
            title: "Total",
            subtitle: "Count",
            value: metrics.totalCountDisplay,
            valueColor: Color.lifeboard.textPrimary,
            accessibilityIdentifier: SunriseHabitDetailAccessibilityID.totalCountMetric
        )
        SunriseHabitMetricTile(
            title: "Completion",
            subtitle: "Rate",
            value: metrics.completionRateDisplay,
            valueColor: completionRateColor,
            accessibilityIdentifier: SunriseHabitDetailAccessibilityID.completionRateMetric
        )
    }

    private var compactColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: spacing.s8),
            GridItem(.flexible(), spacing: spacing.s8)
        ]
    }

    private var completionRateColor: Color {
        metrics.completionRate >= 0.5 ? accentColor : Color.lifeboard.textPrimary
    }
}

private struct SunriseHabitMetricTile: View {
    let title: String
    let subtitle: String
    let value: String
    let valueColor: Color
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.lifeboard(.title2))
                .bold()
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .contentTransition(.numericText())

            Text(title.uppercased())
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .lineLimit(1)

            Text(subtitle.uppercased())
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(.horizontal, LifeBoardTheme.Spacing.md)
        .padding(.vertical, LifeBoardTheme.Spacing.sm)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: Color.lifeboard.surfaceSecondary.opacity(0.72),
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.78)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
        .animation(LifeBoardAnimation.numericUpdate, value: value)
    }
}

private struct SunriseHabitCalendarSection: View {
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
            Text(helperText)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.helperText)

            GeometryReader { proxy in
                let availableWidth = max(proxy.size.width, SunriseHabitCalendarMetrics.requiredWidth(for: 0))
                let gridWidth = SunriseHabitCalendarMetrics.requiredWidth(for: availableWidth)
                let cellSide = SunriseHabitCalendarMetrics.cellSide(for: availableWidth)

                VStack(alignment: .leading, spacing: spacing.s8) {
                    weekdayHeader(cellSide: cellSide)

                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            ForEach(viewState.weeks) { week in
                                VStack(alignment: .leading, spacing: spacing.s4) {
                                    if let monthLabel = week.monthLabel {
                                        Text(monthLabel)
                                            .font(.lifeboard(.callout).weight(.semibold))
                                            .foregroundStyle(Color.lifeboard.textSecondary)
                                    }

                                    HStack(spacing: SunriseHabitCalendarMetrics.cellSpacing) {
                                        ForEach(week.cells) { cell in
                                            SunriseHabitCalendarDayCell(row: row, cell: cell, side: cellSide, isSaving: isSaving) {
                                                onTapDay(cell.cell)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .frame(width: gridWidth, alignment: .leading)
                    }
                    .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.grid)
                }
            }
            .frame(height: gridHeight)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Refreshing rhythm")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                }
            }
        }
        .padding(2)
    }

    private var gridHeight: CGFloat {
        let weekCount = max(viewState.weeks.count, 1)
        let monthLabelCount = viewState.weeks.reduce(0) { $0 + ($1.monthLabel == nil ? 0 : 1) }
        return 20 + spacing.s8 + (CGFloat(weekCount) * SunriseHabitCalendarMetrics.maximumCellSide) + (CGFloat(max(weekCount - 1, 0)) * spacing.s8) + (CGFloat(monthLabelCount) * (22 + spacing.s4))
    }

    private func weekdayHeader(cellSide: CGFloat) -> some View {
        HStack(spacing: SunriseHabitCalendarMetrics.cellSpacing) {
            ForEach(Array(Calendar.current.veryShortWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.lifeboard(.meta).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: cellSide, alignment: .center)
            }
        }
    }
}

private struct SunriseHabitCalendarDayCell: View {
    let row: HabitLibraryRow
    let cell: HabitDetailCalendarCellViewState
    let side: CGFloat
    let isSaving: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Button(action: action) {
            let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)
            ZStack {
                shape.fill(fillColor)
                shape.strokeBorder(borderColor, style: strokeStyle)
                if cell.cell.isToday {
                    shape
                        .strokeBorder(Color.lifeboard.accentPrimary, lineWidth: 1.6)
                        .padding(1)
                }
                differentiateOverlay
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
        .accessibilityLabel("\(row.title), \(cell.accessibilityLabel)")
        .accessibilityValue(cell.accessibilityValue)
        .accessibilityHint(cell.accessibilityHint)
        .accessibilityAddTraits(cell.cell.isInteractive ? .isButton : .isStaticText)
    }

    @ViewBuilder
    private var differentiateOverlay: some View {
        if differentiateWithoutColor {
            switch cell.cell.state {
            case .lapsed, .empty:
                Rectangle()
                    .fill(Color.lifeboard.textSecondary.opacity(0.22))
                    .frame(width: side * 0.42, height: 1)
            case .skipped, .notScheduled:
                Circle()
                    .fill(Color.lifeboard.textSecondary.opacity(0.55))
                    .frame(width: 5, height: 5)
            case .success, .future:
                EmptyView()
            }
        }
    }

    private var colorFamily: HabitColorFamily {
        HabitColorFamily.family(for: row.colorHex, fallback: row.kind == .positive ? .green : .coral)
    }

    private var fillColor: Color {
        switch cell.cell.state {
        case .success:
            return HabitEverydayPalette.depthColor(for: colorFamily, depth: max(1, min(cell.streakDepth ?? 1, 8)), colorScheme: colorScheme)
        case .future:
            return HabitEverydayPalette.futureFill(colorScheme: colorScheme)
        case .skipped, .notScheduled:
            return HabitEverydayPalette.paperFill(colorScheme: colorScheme)
        case .lapsed, .empty:
            return HabitEverydayPalette.missedFill(colorScheme: colorScheme).opacity(cell.cell.state == .lapsed ? 0.58 : 0.34)
        }
    }

    private var borderColor: Color {
        switch cell.cell.state {
        case .lapsed:
            return HabitEverydayPalette.gridStroke(colorScheme: colorScheme).opacity(0.96)
        default:
            return HabitEverydayPalette.gridStroke(colorScheme: colorScheme).opacity(0.78)
        }
    }

    private var strokeStyle: StrokeStyle {
        switch cell.cell.state {
        case .skipped, .notScheduled:
            return StrokeStyle(lineWidth: 1, dash: [4, 3])
        default:
            return StrokeStyle(lineWidth: 1)
        }
    }

    private var textColor: Color {
        switch cell.cell.state {
        case .success:
            return (cell.streakDepth ?? 1) >= 4 ? Color.white.opacity(0.98) : Color.lifeboard.textPrimary
        case .lapsed:
            return Color.lifeboard.textSecondary
        case .future, .notScheduled:
            return Color.lifeboard.textTertiary
        default:
            return Color.lifeboard.textPrimary
        }
    }

    private var textWeight: Font.Weight {
        switch cell.cell.state {
        case .success, .lapsed: return .semibold
        default: return .medium
        }
    }
}

private struct SunriseHabitWeekdayPickerRow: View {
    @Binding var selectedDays: [Int]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(weekdays, id: \.day) { item in
                let isSelected = selectedDays.contains(item.day)
                Button {
                    LifeBoardFeedback.selection()
                    if isSelected {
                        selectedDays.removeAll { $0 == item.day }
                    } else {
                        selectedDays.append(item.day)
                        selectedDays.sort()
                    }
                } label: {
                    Text(item.label)
                        .font(.lifeboard(.callout).weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary, in: Circle())
                        .overlay {
                            Circle()
                                .stroke(isSelected ? Color.lifeboard.accentRing : Color.lifeboard.strokeHairline.opacity(0.7), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weekdays: [(day: Int, label: String)] {
        let labels = Calendar.current.veryShortWeekdaySymbols
        return (1...7).map { day in
            let index = labels.indices.contains(day - 1) ? day - 1 : 0
            return (day, labels[index])
        }
    }
}
