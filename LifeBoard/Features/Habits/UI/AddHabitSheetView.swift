//
//  AddHabitSheetView.swift
//  LifeBoard
//
//  Sunrise Glass habit creation sheet.
//

import SwiftUI
import UIKit

public struct AddHabitSheetView: View {
    @StateObject var viewModel: AddHabitViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private let onHabitCreated: ((UUID) -> Void)?
    private let onDismissWithoutHabit: (() -> Void)?

    @FocusState private var titleFieldFocused: Bool
    @FocusState private var notesFieldFocused: Bool
    @State var selectedDetent: PresentationDetent = .medium
    @State private var showDiscardConfirmation = false
    @State private var selectedTemplateID: String?
    @State private var showDetails = false
    @State var showAppearance = false
    @State private var successFlash = false
    @State private var didCreateHabit = false
    @State private var successResetTask: Task<Void, Never>?
    @State private var snackbar: SnackbarData?

    var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    private var canCreate: Bool {
        viewModel.canSubmit && viewModel.isSaving == false
    }

    public init(
        viewModel: AddHabitViewModel,
        onHabitCreated: ((UUID) -> Void)? = nil,
        onDismissWithoutHabit: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onHabitCreated = onHabitCreated
        self.onDismissWithoutHabit = onDismissWithoutHabit
    }

    public var body: some View {
        VStack(spacing: 0) {
            AddTaskNavigationBar(
                containerMode: .sheet,
                title: "New habit",
                canSave: canCreate,
                onCancel: handleCancel,
                onSave: handleCreate
            )
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    livingPreview
                        .cardEntrance(index: 0)
                    // Templates first: one tap fills the whole form with a
                    // real target. Everything below stays editable.
                    templateRow
                        .cardEntrance(index: 1)
                    essentialsCard
                        .cardEntrance(index: 1)
                    rhythmCard
                        .cardEntrance(index: 2)
                    appearanceCard
                        .cardEntrance(index: 3)

                    if let validationText {
                        HabitInlineError(message: validationText)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s20)
            }

            HabitBottomActionBar(
                isEnabled: canCreate,
                isLoading: viewModel.isSaving,
                successFlash: successFlash,
                title: "Add habit",
                action: handleCreate
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 720 : .infinity, alignment: .center)
        .background(HabitSheetBackground().ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addHabit.view")
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        // Esc behaves like Cancel, including asking before unsaved changes go.
        .escapeCancels(perform: handleCancel)
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your changes won’t be saved.")
        }
        .lifeboardSnackbar($snackbar)
        .overlay(
            ClayColorTokens.leaf
                .opacity(successFlash ? 0.06 : 0)
                .lifeBoardMotion(.contentInsertion, value: successFlash)
                .allowsHitTesting(false)
        )
        .onAppear {
            viewModel.loadIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard layoutClass == .phone else { return }
                titleFieldFocused = true
            }
        }
        .onDisappear {
            successResetTask?.cancel()
            if didCreateHabit == false {
                onDismissWithoutHabit?()
            }
        }
    }

    /// Living identity preview — the habit takes shape as you choose its name, colour, and
    /// rhythm. Breathes gently while still unnamed.
    private var livingPreview: some View {
        let accent = HexColor.color(viewModel.selectedColorHex, fallback: Color.lifeboard.accentPrimary)
        let trimmedName = viewModel.habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isAwaiting = trimmedName.isEmpty
        return HStack(alignment: .center, spacing: spacing.s12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 60, height: 60)
                Image(systemName: viewModel.selectedIconSymbolName ?? "repeat.circle.fill")
                    .font(.lifeboard(.title2))
                    .foregroundStyle(accent)
                    .contentTransition(.symbolEffect(.replace))
            }
            .breathingPulse(min: isAwaiting ? 0.85 : 1.0, max: 1.0, duration: 2.6)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(isAwaiting ? "New habit" : trimmedName)
                    .font(.lifeboard(.title3))
                    .foregroundStyle(isAwaiting ? Color.lifeboard.textTertiary : Color.lifeboard.textPrimary)
                    .lineLimit(1)
                Text(previewRhythm)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .contentTransition(.opacity)
                    .accessibilityIdentifier("addHabit.preview.rhythm")
                HabitCadenceDots(cadence: viewModel.selectedCadence, accent: accent)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(spacing.s16)
        .sunriseHabitGlassCard(reduceTransparency: reduceTransparency)
        .lifeBoardMotion(.localState, value: viewModel.selectedColorHex)
    }

    /// "8 glasses a day · Daily at 9:00 AM": the target leads once it is
    /// more than a check-in, so a chosen template reads back immediately.
    private var previewRhythm: String {
        let cadence = cadenceSummary(viewModel.selectedCadence)
        switch viewModel.targetConfig.effectiveTarget {
        case .binary, .avoidance:
            return cadence
        case let target:
            return "\(HabitTemplateCatalog.summary(for: target)) · \(cadence)"
        }
    }

    private var templateRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: spacing.s8) {
                ForEach(HabitTemplateCatalog.all) { template in
                    let isSelected = selectedTemplateID == template.id
                    Button {
                        apply(template)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(template.title)
                                    .font(.lifeboard(.bodyStrong))
                                Text(template.targetSummary)
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard.textSecondary)
                            }
                        } icon: {
                            Image(systemName: template.systemImage)
                                .foregroundStyle(HexColor.color(template.colorHex, fallback: Color.lifeboard.accentPrimary))
                        }
                        .padding(.horizontal, spacing.s12)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .background(
                        (isSelected ? Color(SemanticColorTokens.foundationSurfaceSelected) : Color(SemanticColorTokens.foundationSurfaceRecessed))
                            .opacity(isSelected ? 1 : 0.6),
                        in: Capsule()
                    )
                    .overlay {
                        if isSelected {
                            Capsule().strokeBorder(Color(SemanticColorTokens.foundationApricotInk), lineWidth: 1.5)
                        }
                    }
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    .accessibilityLabel("\(template.title), \(template.targetSummary)")
                    .accessibilityIdentifier("addHabit.template.\(template.id)")
                }
            }
        }
        .scrollIndicators(.automatic)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addHabit.templates")
    }

    /// A template fills the form; it does not lock it.
    private func apply(_ template: HabitTemplate) {
        Haptic.pick.play()
        selectedTemplateID = template.id
        withAnimation(MotionProfile.localState.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled)) {
            viewModel.applyPrefill(HabitTemplateCatalog.prefill(
                for: template,
                lifeAreaID: viewModel.selectedLifeAreaID,
                projectID: viewModel.selectedProjectID
            ))
        }
    }

    private var essentialsCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            AddTaskTitleField(
                text: $viewModel.habitName,
                isFocused: $titleFieldFocused,
                iconSystemName: viewModel.selectedIconSymbolName,
                iconAccessibilityLabel: viewModel.selectedIconOption?.displayName,
                onIconTap: openAppearance,
                placeholder: "Habit name",
                onSubmit: handleCreate
            )

            // Was `.pickerStyle(.segmented)`, the stock grey segmented
            // control. `OptionRail` is the design system's equivalent and
            // keeps the semantics: one selection, per-value accessibility
            // identifiers, and reflow at accessibility text sizes.
            OptionRail(
                "Type",
                selection: $viewModel.selectedKind,
                values: Array(AddHabitKind.allCases),
                identifierPrefix: "addHabitSheetView.type",
                title: { $0.displayName }
            )
            .onChange(of: viewModel.selectedKind) { _, _ in
                viewModel.normalizeSelection()
            }

            if viewModel.selectedKind == .negative {
                // Was `.pickerStyle(.segmented)`, the stock grey segmented
                // control. `OptionRail` is the design system's equivalent and
                // keeps the semantics: one selection, per-value accessibility
                // identifiers, and reflow at accessibility text sizes.
                OptionRail(
                    "Tracking",
                    selection: $viewModel.selectedTrackingMode,
                    values: Array(AddHabitTrackingMode.allCases),
                    identifierPrefix: "addHabitSheetView.tracking",
                    title: { $0.displayName }
                )
            }
        }
        .padding(spacing.s16)
        .sunriseHabitGlassCard(reduceTransparency: reduceTransparency)
    }

    private var rhythmCard: some View {
        CalmInlineReveal(
            title: String(localized: "Schedule"),
            collapsedHint: rhythmSummary,
            isExpanded: $showDetails,
            accessibilityID: "addHabit.rhythmDisclosure",
            onToggle: {
                withAnimation(MotionProfile.localState.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled)) {
                    showDetails.toggle()
                    if showDetails {
                        selectedDetent = .large
                    }
                }
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                    // Was `.pickerStyle(.segmented)`, the stock grey segmented
                    // control. `OptionRail` is the design system's equivalent and
                    // keeps the semantics: one selection, per-value accessibility
                    // identifiers, and reflow at accessibility text sizes.
                    OptionRail(
                        "Cadence",
                        selection: cadencePresetBinding,
                        values: Array(AddHabitCadencePreset.allCases),
                        identifierPrefix: "addHabitSheetView.cadence",
                        title: { $0.title }
                    )

                    if cadencePresetBinding.wrappedValue == .weekly {
                        AddHabitWeekdayPickerRow(selectedDays: weeklyDaysBinding)
                    }
                    if cadencePresetBinding.wrappedValue == .interval {
                        Stepper(
                            "Every \(intervalDaysBinding.wrappedValue) days",
                            value: intervalDaysBinding,
                            in: 2...30
                        )
                        .frame(minHeight: 44)
                    }

                    DatePicker("Check-in time", selection: cadenceTimeBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)

                    HabitTargetEditor(config: $viewModel.targetConfig)

                    if viewModel.lifeAreas.isEmpty == false {
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
                            selectedID: $viewModel.selectedLifeAreaID
                        )
                    }

                    if viewModel.filteredProjectsForSelectedLifeArea.isEmpty == false {
                        AddTaskEntityPicker(
                            label: "Project",
                            items: viewModel.filteredProjectsForSelectedLifeArea.map {
                                AddTaskEntityPickerItem(id: $0.project.id, name: $0.project.name, icon: nil, accentHex: nil)
                            },
                            selectedID: $viewModel.selectedProjectID
                        )
                    }

                    HabitReminderWindowPicker(
                        isEnabled: viewModel.hasReminderWindow,
                        startDate: Binding(
                            get: { viewModel.reminderWindowStartPickerDate },
                            set: { viewModel.reminderWindowStartPickerDate = $0 }
                        ),
                        endDate: Binding(
                            get: { viewModel.reminderWindowEndPickerDate },
                            set: { viewModel.reminderWindowEndPickerDate = $0 }
                        ),
                        onEnable: {
                            withAnimation(MotionProfile.localState.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled)) {
                                viewModel.ensureReminderWindowDefaults()
                            }
                        },
                        onClear: {
                            withAnimation(MotionProfile.localState.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled)) {
                                viewModel.clearReminderWindow()
                            }
                        },
                        accessibilityIdentifierPrefix: "addHabit.reminderWindow"
                    )

                    AddTaskDescriptionField(text: $viewModel.habitNotes, isFocused: $notesFieldFocused)
            }
        }
    }

    private var rhythmSummary: String {
        var parts = [cadenceSummary(viewModel.selectedCadence)]
        if let area = viewModel.lifeAreas.first(where: { $0.id == viewModel.selectedLifeAreaID }) {
            parts.append(area.name)
        }
        if let project = viewModel.projects.first(where: { $0.project.id == viewModel.selectedProjectID })?.project {
            parts.append(project.name)
        }
        return parts.joined(separator: " · ")
    }
}

extension AddHabitSheetView {
    private func handleCancel() {
        // No haptic: cancelling is not an event worth a buzz.
        if viewModel.hasUnsavedChanges {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func handleCreate() {
        guard canCreate else {
            if viewModel.selectedLifeAreaID == nil || viewModel.reminderWindowValidationError != nil {
                selectedDetent = .large
                showDetails = true
            }
            return
        }

        viewModel.createHabit { result in
            Task { @MainActor in
                switch result {
                case .success(let habit):
                    didCreateHabit = true
                    onHabitCreated?(habit.id)
                    Haptic.commit.play()
                    runSuccessFlash()
                    dismiss()
                case .failure:
                    Haptic.fail.play()
                    snackbar = SnackbarData(message: String(localized: "Couldn’t save habit. Try again."), autoDismissSeconds: 4)
                }
            }
        }
    }

    private func runSuccessFlash() {
        successResetTask?.cancel()
        withAnimation(MotionProfile.localState.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled)) {
            successFlash = true
        }
        successResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: UIAccessibility.isReduceMotionEnabled)) {
                successFlash = false
            }
        }
    }
}

private enum AddHabitCadencePreset: String, CaseIterable, Identifiable {
    case daily
    case weekly
    case interval

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return String(localized: "Daily")
        case .weekly: return String(localized: "Weekly")
        case .interval: return String(localized: "Every few days")
        }
    }
}

private extension AddHabitSheetView {
    var cadencePresetBinding: Binding<AddHabitCadencePreset> {
        Binding(
            get: {
                switch viewModel.selectedCadence {
                case .daily: return .daily
                case .weekly: return .weekly
                case .interval: return .interval
                }
            },
            set: { preset in
                let time = cadenceTime(from: viewModel.selectedCadence)
                switch preset {
                case .daily:
                    viewModel.selectedCadence = .daily(hour: time.hour, minute: time.minute)
                case .weekly:
                    let days = weeklyDays(from: viewModel.selectedCadence)
                    viewModel.selectedCadence = .weekly(daysOfWeek: days.isEmpty ? [2, 3, 4, 5, 6] : days, hour: time.hour, minute: time.minute)
                case .interval:
                    viewModel.selectedCadence = .interval(days: intervalDays(from: viewModel.selectedCadence), hour: time.hour, minute: time.minute)
                }
            }
        )
    }

    var weeklyDaysBinding: Binding<[Int]> {
        Binding(
            get: {
                let days = weeklyDays(from: viewModel.selectedCadence)
                return days.isEmpty ? [2, 3, 4, 5, 6] : days
            },
            set: { days in
                let time = cadenceTime(from: viewModel.selectedCadence)
                viewModel.selectedCadence = .weekly(daysOfWeek: days.sorted().isEmpty ? [2, 3, 4, 5, 6] : days.sorted(), hour: time.hour, minute: time.minute)
            }
        )
    }

    var cadenceTimeBinding: Binding<Date> {
        Binding(
            get: {
                let calendar = Calendar.current
                let time = cadenceTime(from: viewModel.selectedCadence)
                return calendar.date(bySettingHour: time.hour ?? 9, minute: time.minute ?? 0, second: 0, of: calendar.startOfDay(for: Date())) ?? Date()
            },
            set: { date in
                let calendar = Calendar.current
                let hour = calendar.component(.hour, from: date)
                let minute = calendar.component(.minute, from: date)
                switch viewModel.selectedCadence {
                case .daily:
                    viewModel.selectedCadence = .daily(hour: hour, minute: minute)
                case .weekly(let days, _, _):
                    viewModel.selectedCadence = .weekly(daysOfWeek: days, hour: hour, minute: minute)
                case .interval(let days, _, _):
                    viewModel.selectedCadence = .interval(days: days, hour: hour, minute: minute)
                }
            }
        )
    }

    func cadenceSummary(_ cadence: HabitCadenceDraft) -> String {
        switch cadence {
        case .daily(let hour, let minute):
            return String(localized: "Daily at \(formattedTime(hour: hour, minute: minute))")
        case .weekly(let days, let hour, let minute):
            return String(localized: "\(weekdaySummary(days)) at \(formattedTime(hour: hour, minute: minute))")
        case .interval(let days, let hour, let minute):
            return String(localized: "Every \(max(1, days)) days at \(formattedTime(hour: hour, minute: minute))")
        }
    }

    func cadenceTime(from cadence: HabitCadenceDraft) -> (hour: Int?, minute: Int?) {
        switch cadence {
        case .daily(let hour, let minute): return (hour, minute)
        case .weekly(_, let hour, let minute): return (hour, minute)
        case .interval(_, let hour, let minute): return (hour, minute)
        }
    }

    func weeklyDays(from cadence: HabitCadenceDraft) -> [Int] {
        switch cadence {
        case .daily: return []
        case .weekly(let days, _, _): return days
        case .interval: return []
        }
    }

    var intervalDaysBinding: Binding<Int> {
        Binding(
            get: { intervalDays(from: viewModel.selectedCadence) },
            set: { days in
                let time = cadenceTime(from: viewModel.selectedCadence)
                viewModel.selectedCadence = .interval(days: max(2, days), hour: time.hour, minute: time.minute)
            }
        )
    }

    func intervalDays(from cadence: HabitCadenceDraft) -> Int {
        if case let .interval(days, _, _) = cadence { return max(2, days) }
        return 2
    }

    func formattedTime(hour: Int?, minute: Int?) -> String {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour ?? 9, minute: minute ?? 0, second: 0, of: calendar.startOfDay(for: Date())) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    func weekdaySummary(_ days: [Int]) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        if days.count == 5 && days == [2, 3, 4, 5, 6] { return String(localized: "Weekdays") }
        if days.count == 7 { return String(localized: "Every day") }
        return days.compactMap { day in
            let index = max(0, min(symbols.count - 1, day - 1))
            guard symbols.indices.contains(index) else { return nil }
            return symbols[index]
        }.joined(separator: " · ")
    }
}

/// Seven-dot cadence glyph for the living preview. Mon→Sun; active days filled with the
/// habit accent, the rest quietly outlined. Daily fills every dot.
private struct HabitCadenceDots: View {
    let cadence: HabitCadenceDraft
    let accent: Color

    // Calendar weekday integers, displayed Mon…Sun.
    private let order: [Int] = [2, 3, 4, 5, 6, 7, 1]

    private var activeDays: Set<Int> {
        switch cadence {
        case .daily:
            return Set(order)
        case .weekly(let days, _, _):
            return days.isEmpty ? Set([2, 3, 4, 5, 6]) : Set(days)
        case .interval:
            return Set(order)
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            ForEach(order, id: \.self) { day in
                Circle()
                    .fill(activeDays.contains(day) ? accent : Color.clear)
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle().strokeBorder(accent.opacity(activeDays.contains(day) ? 0 : 0.35), lineWidth: 1)
                    )
            }
        }
        .lifeBoardMotion(.localState, value: activeDays)
        .accessibilityHidden(true)
    }
}

struct HabitTargetEditor: View {
    static func periodTitle(_ period: HabitQuotaPeriod) -> String {
        switch period {
        case .day: String(localized: "Per day")
        case .week: String(localized: "Per week")
        case .month: String(localized: "Per month")
        }
    }

    private enum TargetKind: String, CaseIterable, Identifiable {
        case binary, avoidance, quantitative, quota, timed
        var id: String { rawValue }
        var title: String {
            switch self {
            case .binary: String(localized: "Check-in")
            case .avoidance: String(localized: "Stay clear")
            case .quantitative: String(localized: "Amount")
            case .quota: String(localized: "Count")
            case .timed: String(localized: "Duration")
            }
        }
    }

    @Binding var config: HabitTargetConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Target", selection: kindBinding) {
                ForEach(TargetKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)

            switch kindBinding.wrappedValue {
            case .binary, .avoidance:
                EmptyView()
            case .quantitative:
                // The drum is the design system's number control; the raw
                // text field stayed only as the drum's own keyboard path.
                ValueDrum(
                    "Amount",
                    value: targetValueBinding,
                    in: 1...max(100, targetValueBinding.wrappedValue * 2),
                    step: 1,
                    coarseStep: 5,
                    unit: unitSuffix,
                    fractionDigits: 0,
                    identifier: "addHabit.target.value",
                    keyboardPrompt: "Amount"
                )
                HStack {
                    Text("Unit")
                    Spacer()
                    TextField("Unit", text: unitBinding, prompt: Text("Unit").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 160)
                        .accessibilityIdentifier("addHabit.target.unit")
                }
                .frame(minHeight: 44)
            case .quota:
                HStack {
                    Stepper(
                        "\(Int(targetValueBinding.wrappedValue.rounded())) times",
                        value: targetValueBinding,
                        in: 1...100,
                        step: 1
                    )
                    Picker("Period", selection: quotaPeriodBinding) {
                        ForEach(HabitQuotaPeriod.allCases, id: \.self) { period in
                            Text(Self.periodTitle(period)).tag(period)
                        }
                    }
                    .labelsHidden()
                }
                .frame(minHeight: 44)
            case .timed:
                ValueDrum(
                    "Minutes",
                    value: targetValueBinding,
                    in: 1...480,
                    step: 1,
                    coarseStep: 5,
                    unit: "min",
                    fractionDigits: 0,
                    identifier: "addHabit.target.value",
                    keyboardPrompt: "Minutes"
                )
            }

            Toggle("Set a minimum", isOn: minimumEnabledBinding)
                .frame(minHeight: 44)
            if config.minimumTarget != nil,
               ![TargetKind.binary, .avoidance].contains(kindBinding.wrappedValue) {
                HStack {
                    Text("Minimum")
                    Spacer()
                    TextField("Minimum", value: minimumValueBinding, format: .number, prompt: Text("Minimum").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                        .padKeyboard(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 100)
                    Text(kindBinding.wrappedValue == .timed ? String(localized: "min") : unitSuffix)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var kindBinding: Binding<TargetKind> {
        Binding(
            get: {
                switch config.effectiveTarget {
                case .binary: .binary
                case .avoidance: .avoidance
                case .quantitative: .quantitative
                case .quota: .quota
                case .timed: .timed
                }
            },
            set: { kind in
                config.targetCountPerDay = nil
                config.target = defaultTarget(for: kind)
                config.minimumTarget = nil
            }
        )
    }

    private var targetValueBinding: Binding<Double> {
        Binding(
            get: {
                switch config.effectiveTarget {
                case let .quantitative(value, _): value
                case let .quota(count, _): Double(count)
                case let .timed(seconds): seconds / 60
                case .binary, .avoidance: 1
                }
            },
            set: { value in
                let safe = max(1, value)
                switch config.effectiveTarget {
                case let .quantitative(_, unit):
                    config.target = .quantitative(value: safe, unit: unit)
                case let .quota(_, period):
                    config.target = .quota(count: Int(safe.rounded()), period: period)
                case .timed:
                    config.target = .timed(seconds: safe * 60)
                case .binary, .avoidance:
                    break
                }
                if let minimum = config.minimumTarget,
                   HabitTargetValidator.validate(.init(target: config.target, minimumTarget: minimum)) != nil {
                    config.minimumTarget = nil
                }
            }
        )
    }

    private var unitBinding: Binding<String> {
        Binding(
            get: {
                if case let .quantitative(_, unit) = config.effectiveTarget { return unit }
                return "units"
            },
            set: { unit in
                if case let .quantitative(value, _) = config.effectiveTarget {
                    config.target = .quantitative(value: value, unit: unit)
                }
            }
        )
    }

    private var quotaPeriodBinding: Binding<HabitQuotaPeriod> {
        Binding(
            get: {
                if case let .quota(_, period) = config.effectiveTarget { return period }
                return .day
            },
            set: { period in
                if case let .quota(count, _) = config.effectiveTarget {
                    config.target = .quota(count: count, period: period)
                    config.minimumTarget = nil
                }
            }
        )
    }

    private var minimumEnabledBinding: Binding<Bool> {
        Binding(
            get: { config.minimumTarget != nil },
            set: { enabled in
                config.minimumTarget = enabled ? defaultMinimum(for: config.effectiveTarget) : nil
            }
        )
    }

    private var minimumValueBinding: Binding<Double> {
        Binding(
            get: {
                switch config.minimumTarget {
                case let .quantitative(value, _): value
                case let .quota(count, _): Double(count)
                case let .timed(seconds): seconds / 60
                default: 1
                }
            },
            set: { value in
                let fullValue = targetValueBinding.wrappedValue
                let safe = min(fullValue, max(1, value))
                switch config.effectiveTarget {
                case let .quantitative(_, unit):
                    config.minimumTarget = .quantitative(value: safe, unit: unit)
                case let .quota(_, period):
                    config.minimumTarget = .quota(count: Int(safe.rounded()), period: period)
                case .timed:
                    config.minimumTarget = .timed(seconds: safe * 60)
                case .binary:
                    config.minimumTarget = .binary
                case .avoidance:
                    config.minimumTarget = .avoidance
                }
            }
        )
    }

    private var unitSuffix: String {
        switch config.effectiveTarget {
        case let .quantitative(_, unit): unit
        case .quota: "times"
        default: ""
        }
    }

    private func defaultTarget(for kind: TargetKind) -> HabitTarget {
        switch kind {
        case .binary: .binary
        case .avoidance: .avoidance
        case .quantitative: .quantitative(value: 1, unit: "units")
        case .quota: .quota(count: 3, period: .week)
        case .timed: .timed(seconds: 15 * 60)
        }
    }

    private func defaultMinimum(for target: HabitTarget) -> HabitTarget {
        switch target {
        case .binary: .binary
        case .avoidance: .avoidance
        case let .quantitative(value, unit): .quantitative(value: value / 2, unit: unit)
        case let .quota(count, period): .quota(count: max(1, count / 2), period: period)
        case let .timed(seconds): .timed(seconds: seconds / 2)
        }
    }
}

private struct AddHabitWeekdayPickerRow: View {
    @Binding var selectedDays: [Int]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(weekdays, id: \.day) { item in
                let isSelected = selectedDays.contains(item.day)
                Button {
                    Haptic.pick.play()
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
                .accessibilityLabel(item.fullLabel)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var weekdays: [(day: Int, label: String, fullLabel: String)] {
        let shortLabels = Calendar.current.veryShortWeekdaySymbols
        let fullLabels = Calendar.current.weekdaySymbols
        return (1...7).map { day in
            let index = shortLabels.indices.contains(day - 1) ? day - 1 : 0
            let fullIndex = fullLabels.indices.contains(day - 1) ? day - 1 : 0
            return (day, shortLabels[index], fullLabels[fullIndex])
        }
    }
}

private struct HabitBottomActionBar: View {
    let isEnabled: Bool
    let isLoading: Bool
    let successFlash: Bool
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: successFlash ? "checkmark.circle.fill" : "plus.circle.fill")
                }
                Text(isLoading ? "Adding…" : title)
            }
            .font(.lifeboard(.bodyEmphasis))
            // The violet fill is saturated in both appearances, so the ink is the
            // fixed light scenic ink. `textInverse` turned cocoa in dark (3.3:1
            // on violet), and the old leaf-to-sky success flash put light ink on
            // bright green at 2.4:1. Success now reads through the checkmark.
            .foregroundStyle(Color(SemanticColorTokens.foundationOnScenicDark))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [ClayColorTokens.violetFill, ClayColorTokens.violetFillDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .clipShape(Capsule())
            .lbAnimatedSheen(isEnabled: isEnabled && isLoading == false)
            .opacity(isEnabled ? 1 : 0.62)
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false || isLoading)
        .accessibilityIdentifier("addHabit.createButton")
    }
}

private struct HabitSheetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                ClayColorTokens.warmCanvas,
                ClayColorTokens.coolCanvas,
                ClayColorTokens.canvas
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    func sunriseHabitGlassCard(reduceTransparency: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.CornerRadius.card, style: .continuous)
        return background {
            if reduceTransparency {
                shape.fill(Color.lifeboard.surfacePrimary)
            } else {
                // Unreachable `.regularMaterial` fallback removed: the
                // deployment target is 26.0, so the availability branch was
                // always taken.
                shape
                    .fill(.clear)
                    .lifeBoardSystemGlass(.regular, in: shape)
                    .overlay(shape.fill(ClayColorTokens.glass.opacity(0.66)))
            }
        }
        .overlay {
            shape.stroke(ClayColorTokens.glassBorder, lineWidth: 1)
        }
        .shadow(color: ClayColorTokens.elevationShadow, radius: 18, x: 0, y: 10)
    }
}
