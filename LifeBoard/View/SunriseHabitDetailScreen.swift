//
//  SunriseHabitDetailScreen.swift
//  LifeBoard
//
//  Sunrise Glass habit detail screen with progressive disclosure.
//

import SwiftUI

private enum SunriseHabitDetailSection: Hashable {
    case progress
    case rhythm
    case appearance
    case lifecycle
}

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
    @State private var expandedSections: Set<SunriseHabitDetailSection> = []
    @State private var snackbar: SnackbarData?

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    init(viewModel: HabitDetailViewModel, onMutation: @escaping @MainActor @Sendable () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onMutation = onMutation
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    if viewModel.isEditing {
                        editingContent
                    } else {
                        readOnlyContent
                    }
                }
                .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 760 : .infinity, alignment: .center)
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s32)
            }
            .background(sunriseBackground)
            .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.view)
            .navigationTitle(viewModel.isEditing ? "Edit Habit" : viewModel.row.title)
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
                            saveChanges()
                        }
                        .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.saveButton)
                        .disabled(!viewModel.canSave || viewModel.isSaving)
                    } else {
                        Button {
                            viewModel.beginEditing()
                        } label: {
                            HStack(spacing: spacing.s4) {
                                if viewModel.isPreparingEditorData {
                                    ProgressView().controlSize(.small)
                                }
                                Text(viewModel.isPreparingEditorData ? "Loading" : "Edit")
                            }
                        }
                        .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.editButton)
                        .disabled(viewModel.isSaving || viewModel.isPreparingEditorData)
                    }
                }
            }
            .task {
                viewModel.loadIfNeeded()
            }
            .onAppear {
                LifeBoardPerformanceTrace.event("SunriseHabitDetailScreenPresented")
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
            heroCard
            todayActionCard
            compactHistoryCard
            progressDisclosure
            rhythmDisclosure
            lifecycleDisclosure
        }
    }

    private var editingContent: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            heroCard
            essentialsEditor
            rhythmEditorDisclosure
            appearanceDisclosure
            lifecycleDisclosure
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(accentColor.opacity(0.14))
                        .frame(width: 58, height: 58)
                    Image(systemName: viewModel.row.icon?.symbolName ?? "circle.dashed")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(viewModel.row.title)
                        .font(.lifeboard(.title2))
                        .bold()
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(3)

                    HStack(spacing: spacing.s4) {
                        LifeBoardStatusPill(text: viewModel.row.kind == .positive ? "Build" : "Quit", systemImage: "sparkles", tone: viewModel.row.kind == .positive ? .success : .warning)
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

            Text(cadenceSummary(viewModel.row.cadence))
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityIdentifier(SunriseHabitDetailAccessibilityID.contextSecondary)
        }
        .padding(spacing.s16)
        .lifeboardPremiumSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary, accentColor: accentColor, level: .e2)
    }

    private var todayActionCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: spacing.s8) { habitMetrics }
                VStack(spacing: spacing.s8) { habitMetrics }
            }

            if let todayCell {
                Button(todayActionTitle(for: todayCell), systemImage: todayActionSymbol(for: todayCell)) {
                    mutate(todayCell)
                }
                .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .success))
                .disabled(!todayCell.isInteractive || viewModel.isSaving)
            }
        }
        .padding(spacing.s12)
        .lifeboardChromeSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, accentColor: accentColor, level: .e1)
    }

    @ViewBuilder
    private var habitMetrics: some View {
        LifeBoardHeroMetricTile(
            title: "Current streak",
            value: "\(viewModel.row.currentStreak)d",
            detail: viewModel.row.bestStreak > 0 ? "Best \(viewModel.row.bestStreak)d" : "Fresh cycle",
            tone: viewModel.row.currentStreak > 0 ? .success : .neutral
        )
        LifeBoardHeroMetricTile(
            title: "Next due",
            value: nextDueSummary,
            detail: cadenceSummary(viewModel.row.cadence),
            tone: viewModel.row.isPaused || viewModel.row.isArchived ? .neutral : .accent
        )
    }

    private var compactHistoryCard: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Last 14 days")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
            HabitHistoryStripView(
                marks: viewModel.historyMarks,
                cadence: viewModel.row.cadence,
                family: colorFamily
            )
            Text("Small steps, big changes.")
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
        }
        .padding(spacing.s12)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary)
    }

    private var progressDisclosure: some View {
        disclosureCard(.progress, title: "Progress", systemImage: "chart.bar.xaxis", summary: viewModel.detailCalendarHelperText, accessibilityIdentifier: nil) {
            SunriseHabitCalendarSection(
                row: viewModel.row,
                viewState: viewModel.calendarViewState,
                helperText: viewModel.detailCalendarHelperText,
                isLoading: viewModel.isCalendarLoading,
                isSaving: viewModel.isSaving,
                onTapDay: mutate
            )
        }
    }

    private var rhythmDisclosure: some View {
        disclosureCard(.rhythm, title: "Rhythm", systemImage: "calendar.badge.clock", summary: rhythmSummary, accessibilityIdentifier: SunriseHabitDetailAccessibilityID.detailsDisclosure) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                definitionLine("Ownership", ownershipSummary)
                definitionLine("Cadence", cadenceSummary(viewModel.row.cadence))
                definitionLine("Reminder", reminderSummary)
                if let notes = viewModel.row.notes, notes.isEmpty == false {
                    Text(notes)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .padding(spacing.s12)
                        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.md, fillColor: Color.lifeboard.surfaceSecondary.opacity(0.72))
                }
            }
        }
    }

    private var essentialsEditor: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text("Essentials")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
            TextField("Title", text: $viewModel.draft.title, axis: .vertical)
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
            }
        }
        .padding(spacing.s12)
        .lifeboardDenseSurface(cornerRadius: LifeBoardTheme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary)
    }

    private var rhythmEditorDisclosure: some View {
        disclosureCard(.rhythm, title: "Rhythm", systemImage: "calendar.badge.clock", summary: rhythmSummary, accessibilityIdentifier: SunriseHabitDetailAccessibilityID.detailsDisclosure) {
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

                HStack(spacing: spacing.s8) {
                    timeWindowField("Start", text: $viewModel.draft.reminderWindowStart)
                    timeWindowField("End", text: $viewModel.draft.reminderWindowEnd)
                }

                if let reminderError = viewModel.editorReminderWindowValidationError {
                    Text(reminderError)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.statusWarning)
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
    }

    private var appearanceDisclosure: some View {
        disclosureCard(.appearance, title: "Appearance", systemImage: "swatchpalette", summary: appearanceSummary, accessibilityIdentifier: nil) {
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
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
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
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(lifeboardHex: family.canonicalHex))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if colorFamily == family {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white, lineWidth: 2)
                                                .padding(3)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(family.title)
                        }
                    }
                }
            }
        }
    }

    private var lifecycleDisclosure: some View {
        disclosureCard(.lifecycle, title: "Lifecycle", systemImage: "arrow.triangle.branch", summary: "Pause, recover, or archive without losing history.", accessibilityIdentifier: nil) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Button(viewModel.row.isPaused ? "Resume habit" : "Pause habit", systemImage: viewModel.row.isPaused ? "play.fill" : "pause.fill") {
                    viewModel.togglePause { notifyMutation() }
                }
                .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .quiet))
                .disabled(viewModel.isSaving)

                if viewModel.row.trackingMode == .lapseOnly && !viewModel.row.isArchived {
                    Button("Log lapse", systemImage: "arrow.uturn.backward.circle") {
                        viewModel.logLapse { notifyMutation() }
                    }
                    .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .warning))
                    .disabled(viewModel.isSaving)
                }

                Button(String(localized: "Archive", defaultValue: "Archive") + " habit", systemImage: "archivebox.fill") {
                    viewModel.archive { notifyMutation() }
                }
                .buttonStyle(SunriseDetailCapsuleButtonStyle(tone: .danger))
                .disabled(viewModel.isSaving || viewModel.row.isArchived)

                Text("Pause keeps history intact. Archive removes the habit from active views.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }
        }
    }

    private func disclosureCard<Content: View>(
        _ section: SunriseHabitDetailSection,
        title: String,
        systemImage: String,
        summary: String,
        accessibilityIdentifier: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        SunriseDetailDisclosureCard(
            title: title,
            systemImage: systemImage,
            summary: summary,
            isExpanded: expandedSections.contains(section),
            accessibilityIdentifier: accessibilityIdentifier
        ) {
            LifeBoardFeedback.light()
            withAnimation(LifeBoardAnimation.snappy) {
                if expandedSections.contains(section) {
                    expandedSections.remove(section)
                } else {
                    expandedSections.insert(section)
                }
            }
        } content: {
            content()
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

    private func timeWindowField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(title)
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textTertiary)
            TextField(title, text: text)
                .textFieldStyle(LifeBoardTextFieldStyle())
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sunriseBackground: some View {
        LinearGradient(
            colors: [
                Color(lifeboardHex: "#FFF8EF"),
                Color(lifeboardHex: "#FFFDFC"),
                Color(lifeboardHex: "#F7FBFF")
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
            for: viewModel.isEditing ? viewModel.draft.colorHex : viewModel.row.colorHex,
            fallback: viewModel.row.kind == .positive ? .green : .coral
        )
    }

    private var accentColor: Color {
        LifeBoardHexColor.color(viewModel.isEditing ? viewModel.draft.colorHex : viewModel.row.colorHex, fallback: viewModel.row.kind == .positive ? Color.lifeboard.statusSuccess : Color.lifeboard.statusWarning)
    }

    private var habitStateLabel: String {
        if viewModel.row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
        if viewModel.row.isPaused { return "Paused" }
        if viewModel.isEditing { return "Editing" }
        return "Live"
    }

    private var habitStateSymbol: String {
        if viewModel.row.isArchived { return "archivebox.fill" }
        if viewModel.row.isPaused { return "pause.fill" }
        return "leaf.fill"
    }

    private var nextDueSummary: String {
        if let nextDueAt = viewModel.row.nextDueAt {
            return nextDueAt.formatted(date: .abbreviated, time: .shortened)
        }
        if viewModel.row.isPaused { return "Paused" }
        if viewModel.row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
        return "Not scheduled"
    }

    private var reminderSummary: String {
        let startText = viewModel.row.reminderWindowStart?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let endText = viewModel.row.reminderWindowEnd?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let start = startText.isEmpty ? "Not set" : startText
        let end = endText.isEmpty ? "Not set" : endText
        return "\(start) to \(end)"
    }

    private var rhythmSummary: String {
        "\(cadenceSummary(viewModel.row.cadence)) · \(reminderSummary)"
    }

    private var appearanceSummary: String {
        let icon = viewModel.draft.selectedIconSymbolName ?? viewModel.row.icon?.symbolName ?? "circle.dashed"
        return "\(colorFamily.title) · \(icon)"
    }

    private var ownershipSummary: String {
        if let projectName = viewModel.row.projectName, projectName.isEmpty == false {
            return "\(viewModel.row.lifeAreaName) · \(projectName)"
        }
        return viewModel.row.lifeAreaName
    }

    private var metaLine: String {
        var parts = [viewModel.row.lifeAreaName]
        if let projectName = viewModel.row.projectName, projectName.isEmpty == false {
            parts.append(projectName)
        }
        parts.append(viewModel.row.trackingMode == .lapseOnly ? "Lapse only" : "Daily check-in")
        return parts.joined(separator: " · ")
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
        viewModel.mutateDay(cell) {
            Task { @MainActor in onMutation() }
        }
    }

    private func saveChanges() {
        let onMutation = onMutation
        viewModel.saveChanges {
            Task { @MainActor in onMutation() }
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
    static let editButton = "habitDetail.editButton"
    static let saveButton = "habitDetail.saveButton"
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
                    Text("Refreshing streaks")
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

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle().fill(fillColor)
                Rectangle().strokeBorder(borderColor, style: strokeStyle)
                if cell.cell.isToday {
                    Rectangle()
                        .strokeBorder(Color.lifeboard.accentPrimary, lineWidth: 1.6)
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
            return Color.lifeboard.statusWarning.opacity(0.38)
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
            return Color.lifeboard.statusWarning
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
