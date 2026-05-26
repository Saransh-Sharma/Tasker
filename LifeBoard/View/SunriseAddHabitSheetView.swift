//
//  SunriseAddHabitSheetView.swift
//  LifeBoard
//
//  Sunrise Glass habit creation sheet.
//

import SwiftUI

public struct SunriseAddHabitSheetView: View {
    @StateObject private var viewModel: AddHabitViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let onHabitCreated: ((UUID) -> Void)?
    private let onDismissWithoutHabit: (() -> Void)?

    @FocusState private var titleFieldFocused: Bool
    @FocusState private var notesFieldFocused: Bool
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var showDiscardConfirmation = false
    @State private var showDetails = false
    @State private var showAppearance = false
    @State private var successFlash = false
    @State private var didCreateHabit = false
    @State private var successResetTask: Task<Void, Never>?
    @State private var snackbar: SnackbarData?

    private var spacing: LifeBoardSpacingTokens {
        LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing
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
                title: "New Habit",
                canSave: canCreate,
                onCancel: handleCancel,
                onSave: handleCreate
            )
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    header
                    essentialsCard
                    rhythmCard
                    appearanceCard

                    if let validationText {
                        SunriseHabitInlineError(message: validationText)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s20)
            }

            SunriseHabitBottomActionBar(
                isEnabled: canCreate,
                isLoading: viewModel.isSaving,
                successFlash: successFlash,
                title: "Add Habit",
                action: handleCreate
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .lifeboardReadableContent(maxWidth: layoutClass.isPad ? 720 : .infinity, alignment: .center)
        .background(SunriseHabitSheetBackground().ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("addHabit.view")
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .interactiveDismissDisabled(viewModel.hasUnsavedChanges)
        .confirmationDialog(
            "Discard changes?",
            isPresented: $showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes that will be lost.")
        }
        .lifeboardSnackbar($snackbar)
        .overlay(
            LBColorTokens.leaf
                .opacity(successFlash ? 0.06 : 0)
                .animation(LifeBoardAnimation.gentle, value: successFlash)
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

    private var header: some View {
        HStack(alignment: .top, spacing: spacing.s12) {
            ZStack {
                Circle()
                    .fill(Color(lifeboardHex: viewModel.selectedColorHex).opacity(0.16))
                    .frame(width: 56, height: 56)

                Image(systemName: viewModel.selectedIconSymbolName ?? "repeat.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(lifeboardHex: viewModel.selectedColorHex))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: spacing.s4) {
                Text("Set a gentle rhythm")
                    .font(.lifeboard(.title3))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text("Choose the habit, where it belongs, and when LifeBoard should surface it.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(spacing.s16)
        .sunriseHabitGlassCard(reduceTransparency: reduceTransparency)
    }

    private var essentialsCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text("Essentials")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)

            AddTaskTitleField(
                text: $viewModel.habitName,
                isFocused: $titleFieldFocused,
                iconSystemName: viewModel.selectedIconSymbolName,
                iconAccessibilityLabel: viewModel.selectedIconOption?.displayName,
                onIconTap: expandAppearance,
                placeholder: "What do you want to repeat?",
                helperText: "Keep it small enough to show up on an ordinary day.",
                onSubmit: handleCreate
            )

            Picker("Type", selection: $viewModel.selectedKind) {
                ForEach(AddHabitKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedKind) { _, _ in
                viewModel.normalizeSelection()
            }

            if viewModel.selectedKind == .negative {
                Picker("Tracking", selection: $viewModel.selectedTrackingMode) {
                    ForEach(AddHabitTrackingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(spacing.s16)
        .sunriseHabitGlassCard(reduceTransparency: reduceTransparency)
    }

    private var rhythmCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Button {
                withAnimation(LifeBoardAnimation.snappy) {
                    showDetails.toggle()
                    if showDetails {
                        selectedDetent = .large
                    }
                }
            } label: {
                SunriseHabitDisclosureHeader(
                    title: "Rhythm",
                    systemImage: "calendar.badge.clock",
                    summary: rhythmSummary,
                    isExpanded: showDetails
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addHabit.rhythmDisclosure")

            if showDetails {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    Picker("Cadence", selection: cadencePresetBinding) {
                        ForEach(SunriseAddHabitCadencePreset.allCases) { cadence in
                            Text(cadence.title).tag(cadence)
                        }
                    }
                    .pickerStyle(.segmented)

                    if cadencePresetBinding.wrappedValue == .weekly {
                        SunriseAddHabitWeekdayPickerRow(selectedDays: weeklyDaysBinding)
                    }

                    DatePicker("Check-in time", selection: cadenceTimeBinding, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)

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

                    HStack(spacing: spacing.s8) {
                        timeWindowField("Start", text: $viewModel.reminderWindowStart)
                        timeWindowField("End", text: $viewModel.reminderWindowEnd)
                    }

                    AddTaskDescriptionField(text: $viewModel.habitNotes, isFocused: $notesFieldFocused)
                }
            }
        }
        .padding(spacing.s16)
        .sunriseHabitGlassCard(reduceTransparency: reduceTransparency)
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Button {
                expandAppearance()
            } label: {
                SunriseHabitDisclosureHeader(
                    title: "Appearance",
                    systemImage: "swatchpalette",
                    summary: appearanceSummary,
                    isExpanded: showAppearance
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("addHabit.appearanceDisclosure")

            if showAppearance {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    TextField("Search icons", text: $viewModel.iconSearchQuery)
                        .textFieldStyle(LifeBoardTextFieldStyle())
                        .accessibilityIdentifier("addHabit.iconSearchField")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing.s8) {
                            ForEach(viewModel.availableIconOptions.prefix(18)) { option in
                                Button {
                                    viewModel.selectedIconSymbolName = option.symbolName
                                } label: {
                                    Image(systemName: option.symbolName)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(viewModel.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                                        .frame(width: 44, height: 44)
                                        .background(viewModel.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.displayName)
                                .accessibilityAddTraits(viewModel.selectedIconSymbolName == option.symbolName ? .isSelected : [])
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: spacing.s8) {
                            ForEach(HabitColorFamily.allCases, id: \.rawValue) { family in
                                Button {
                                    viewModel.selectedColorHex = family.canonicalHex
                                } label: {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(lifeboardHex: family.canonicalHex))
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            if HabitColorFamily.family(for: viewModel.selectedColorHex) == family {
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(Color.white, lineWidth: 2)
                                                    .padding(3)
                                            }
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(family.title)
                                .accessibilityAddTraits(HabitColorFamily.family(for: viewModel.selectedColorHex) == family ? .isSelected : [])
                            }
                        }
                    }
                }
            }
        }
        .padding(spacing.s16)
        .sunriseHabitGlassCard(reduceTransparency: reduceTransparency)
    }

    private var validationText: String? {
        if let error = viewModel.errorMessage {
            return error
        }
        if viewModel.habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name the habit to continue."
        }
        if viewModel.selectedLifeAreaID == nil {
            return "Choose a life area for this habit."
        }
        return viewModel.reminderWindowValidationError
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

    private var appearanceSummary: String {
        let icon = viewModel.selectedIconOption?.displayName ?? "Icon"
        let color = HabitColorFamily.family(for: viewModel.selectedColorHex).title
        return "\(icon) · \(color)"
    }

    private func handleCancel() {
        if viewModel.hasUnsavedChanges {
            LifeBoardFeedback.medium()
            showDiscardConfirmation = true
        } else {
            LifeBoardFeedback.light()
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
                    LifeBoardFeedback.success()
                    runSuccessFlash()
                    dismiss()
                case .failure(let error):
                    snackbar = SnackbarData(message: error.localizedDescription, autoDismissSeconds: 4)
                }
            }
        }
    }

    private func runSuccessFlash() {
        successResetTask?.cancel()
        withAnimation(LifeBoardAnimation.snappy) {
            successFlash = true
        }
        successResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 750_000_000)
            withAnimation(LifeBoardAnimation.gentle) {
                successFlash = false
            }
        }
    }

    private func expandAppearance() {
        withAnimation(LifeBoardAnimation.snappy) {
            showAppearance.toggle()
            if showAppearance {
                selectedDetent = .large
            }
        }
    }

    private func timeWindowField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(label)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textTertiary)
            TextField("HH:mm", text: text)
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(LifeBoardTextFieldStyle())
                .accessibilityLabel("Reminder \(label.lowercased()) time")
        }
    }
}

private enum SunriseAddHabitCadencePreset: String, CaseIterable, Identifiable {
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

private extension SunriseAddHabitSheetView {
    var cadencePresetBinding: Binding<SunriseAddHabitCadencePreset> {
        Binding(
            get: {
                switch viewModel.selectedCadence {
                case .daily: return .daily
                case .weekly: return .weekly
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
                }
            }
        )
    }

    func cadenceSummary(_ cadence: HabitCadenceDraft) -> String {
        switch cadence {
        case .daily(let hour, let minute):
            return "Daily at \(formattedTime(hour: hour, minute: minute))"
        case .weekly(let days, let hour, let minute):
            return "\(weekdaySummary(days)) at \(formattedTime(hour: hour, minute: minute))"
        }
    }

    func cadenceTime(from cadence: HabitCadenceDraft) -> (hour: Int?, minute: Int?) {
        switch cadence {
        case .daily(let hour, let minute): return (hour, minute)
        case .weekly(_, let hour, let minute): return (hour, minute)
        }
    }

    func weeklyDays(from cadence: HabitCadenceDraft) -> [Int] {
        switch cadence {
        case .daily: return []
        case .weekly(let days, _, _): return days
        }
    }

    func formattedTime(hour: Int?, minute: Int?) -> String {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour ?? 9, minute: minute ?? 0, second: 0, of: calendar.startOfDay(for: Date())) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    func weekdaySummary(_ days: [Int]) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        if days.count == 5 && days == [2, 3, 4, 5, 6] { return "Weekdays" }
        if days.count == 7 { return "Every day" }
        return days.compactMap { day in
            let index = max(0, min(symbols.count - 1, day - 1))
            guard symbols.indices.contains(index) else { return nil }
            return symbols[index]
        }.joined(separator: " · ")
    }
}

private struct SunriseHabitDisclosureHeader: View {
    let title: String
    let systemImage: String
    let summary: String
    let isExpanded: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.lifeboard.accentPrimary)
                .frame(width: 34, height: 34)
                .background(Color.lifeboard.accentWash, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text(summary)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.lifeboard.textTertiary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .contentShape(Rectangle())
    }
}

private struct SunriseAddHabitWeekdayPickerRow: View {
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

private struct SunriseHabitInlineError: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.lifeboard.statusWarning)
            Text(message)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.lifeboard.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.lifeboard.statusWarning.opacity(0.35), lineWidth: 1)
        )
        .accessibilityIdentifier("addHabit.validationMessage")
    }
}

private struct SunriseHabitBottomActionBar: View {
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
                Text(isLoading ? "Adding..." : title)
            }
            .font(.lifeboard(.bodyEmphasis))
            .foregroundStyle(Color.lifeboard.textInverse)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: successFlash
                        ? [LBColorTokens.leaf, LBColorTokens.sky]
                        : [LBColorTokens.violetFill, LBColorTokens.violetFillDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .opacity(isEnabled ? 1 : 0.62)
        }
        .buttonStyle(.plain)
        .disabled(isEnabled == false || isLoading)
        .accessibilityIdentifier("addHabit.createButton")
    }
}

private struct SunriseHabitSheetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                LBColorTokens.warmCanvas,
                LBColorTokens.coolCanvas,
                LBColorTokens.canvas
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private extension View {
    func sunriseHabitGlassCard(reduceTransparency: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.card, style: .continuous)
        return background {
            if reduceTransparency {
                shape.fill(Color.lifeboard.surfacePrimary)
            } else if #available(iOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: shape)
                    .overlay(shape.fill(LBColorTokens.glass.opacity(0.50)))
            } else {
                shape
                    .fill(.regularMaterial)
                    .overlay(shape.fill(LBColorTokens.glass))
            }
        }
        .overlay {
            shape.stroke(LBColorTokens.glassBorder, lineWidth: 1)
        }
        .shadow(color: LBColorTokens.elevationShadow, radius: 18, x: 0, y: 10)
    }
}
