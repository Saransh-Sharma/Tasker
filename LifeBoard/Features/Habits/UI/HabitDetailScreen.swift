//
//  HabitDetailScreen.swift
//  LifeBoard
//
//  Sunrise Glass habit detail screen with progressive disclosure.
//

import SwiftUI

private enum HabitCadencePreset: String, CaseIterable, Identifiable {
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

struct HabitDetailScreen: View {
    @StateObject var viewModel: HabitDetailViewModel
    private let onMutation: @MainActor @Sendable () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @State private var showDetailReveal = false
    @State private var completionBurstTrigger = 0
    @State private var sawTodayCompletionThisSession = false
    @State private var isInitialReadOnlyHydrationComplete = false
    @State private var isInitialEditorSupportHydrationComplete = false
    @State private var snackbar: SnackbarData?
    @State private var confirmsSlip = false

    private var spacing: SemanticSpacingTokens { tokens.spacing }
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
        .accessibilityIdentifier(HabitDetailAccessibilityID.view)
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
            PerformanceTrace.event("SunriseHabitDetailScreenPresented")
        }
        .onDisappear {
            viewModel.flushPendingAutosave()
        }
        .onChange(of: viewModel.mutationFeedback) { _, feedback in
            guard let feedback else { return }
            // Undo is offered while it is actually possible, and a snackbar
            // that carries it no longer dismisses itself out from under the
            // reader.
            snackbar = SnackbarData(
                message: feedback.message,
                actions: viewModel.undoableDayCell == nil ? [] : [
                    SnackbarAction(title: "Undo") {
                        viewModel.undoLastDayMutation()
                    }
                ]
            )
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
            Text(viewModel.errorMessage ?? String(localized: "Try again."))
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
                    .accessibilityLabel("Loading")
            }
            AutosaveWhisper(state: viewModel.autosaveState)
        }
    }

    private var alwaysEditableContent: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            heroCard
            autosaveFailureBanner
            detailReveal {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    CalmFieldGroup(title: String(localized: "Type")) { essentialsEditorContent }
                    CalmFieldGroup(title: String(localized: "Schedule")) { rhythmEditorContent }
                    CalmFieldGroup(title: String(localized: "Appearance")) { appearanceContent }
                    CalmFieldGroup(title: String(localized: "Status")) { lifecycleContent }
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
                    .foregroundStyle(DetailTonePalette.dangerText)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Try again") { viewModel.retryAutosave() }
                    .buttonStyle(.lifeBoardChip)
                    .disabled(viewModel.isSaving)
            }
            .padding(spacing.s12)
            .background(DetailTonePalette.dangerText.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(HabitDetailAccessibilityID.autosaveFailure)
        }
    }

    private func detailReveal<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        CalmInlineReveal(
            title: String(localized: "Details"),
            collapsedHint: rhythmSummary,
            isExpanded: $showDetailReveal,
            accessibilityID: HabitDetailAccessibilityID.detailsDisclosure,
            onToggle: {
                Haptic.pick.play()
                withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                    showDetailReveal.toggle()
                }
            },
            content: content
        )
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                // The ring is the habit's identity here as it is on Home: tap
                // opens nothing (this *is* the habit), hold completes today.
                if let todayCell {
                    HabitProgressRing(
                        title: viewModel.draft.title.isEmpty ? viewModel.row.title : viewModel.draft.title,
                        value: todayCell.state == .success ? 1 : 0,
                        target: 1,
                        step: 1,
                        unit: "",
                        isTimed: false,
                        size: .hero,
                        tapBehavior: .perform({}),
                        showsCount: false,
                        onChange: { change in
                            await logToday(change, cell: todayCell)
                        }
                    )
                    .accessibilityIdentifier(HabitDetailAccessibilityID.heroRing)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                            .fill(accentColor.opacity(0.14))
                            .frame(width: 58, height: 58)
                        Image(systemName: viewModel.draft.selectedIconSymbolName ?? viewModel.row.icon?.symbolName ?? "circle.dashed")
                            .font(.lifeboard(.title2))
                            .foregroundStyle(accentColor)
                    }
                    .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: spacing.s4) {
                    TextField("Habit title", text: $viewModel.draft.title, prompt: Text("Habit title").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                        .font(.lifeboard(.title2))
                        .bold()
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .lineLimit(3)
                        .returnKeyEndsEditing(text: $viewModel.draft.title)
                        .textFieldStyle(.plain)
                        .accessibilityLabel("Habit title")

                    HStack(spacing: spacing.s4) {
                        StatusPill(text: viewModel.draft.kind == .positive ? String(localized: "Build") : String(localized: "Quit"), systemImage: "sparkles", tone: viewModel.draft.kind == .positive ? .success : .warning)
                        StatusPill(text: habitStateLabel, systemImage: habitStateSymbol, tone: viewModel.row.isArchived || viewModel.row.isPaused ? .quiet : .accent)
                    }
                }

                Spacer(minLength: 0)
            }

            Text(metaLine)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(HabitDetailAccessibilityID.contextPrimary)

            if viewModel.draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Add a name.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(DetailTonePalette.dangerText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(cadenceSummary(viewModel.draft.cadence))
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityIdentifier(HabitDetailAccessibilityID.contextSecondary)
        }
        .padding(spacing.s16)
        .lifeboardPremiumSurface(cornerRadius: Theme.CornerRadius.card, fillColor: Color.lifeboard.surfacePrimary, accentColor: accentColor, level: .e2)
    }

    private var habitProgressCard: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text("Progress")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text("Last \(HabitDetailCalendarBuilder.historyDayCount) days")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HabitCalendarSection(
                row: viewModel.row,
                viewState: viewModel.calendarViewState,
                helperText: viewModel.detailCalendarHelperText,
                isLoading: viewModel.isCalendarLoading,
                isSaving: viewModel.isSaving,
                onTapDay: mutate
            )

            HabitMetricGrid(
                metrics: viewModel.calendarViewState.summaryMetrics,
                accentColor: accentColor
            )

            HabitWeekdayBarsSection(
                statistics: HabitWeekdayStatistics.make(marks: viewModel.historyMarks),
                accent: accentColor
            )

            if let todayCell {
                Button(todayActionTitle(for: todayCell), systemImage: todayActionSymbol(for: todayCell)) {
                    mutate(todayCell)
                }
                .buttonStyle(DetailCapsuleButtonStyle(tone: .success))
                .disabled(!todayCell.isInteractive || viewModel.isSaving)
                // One burst after the persisted completion, as on the task
                // detail; see `TaskDetailScreen` for why the stack went.
                .lifeboardCompletionBurst(trigger: completionBurstTrigger)
            }
        }
        .padding(spacing.s12)
        .lifeboardPremiumSurface(
            cornerRadius: Theme.CornerRadius.card,
            fillColor: Color.lifeboard.surfacePrimary,
            accentColor: accentColor,
            level: .e1
        )
    }

    private var essentialsEditorContent: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            // Was `.pickerStyle(.segmented)`, the stock grey segmented
            // control. `OptionRail` is the design system's equivalent and
            // keeps the semantics: one selection, per-value accessibility
            // identifiers, and reflow at accessibility text sizes.
            OptionRail(
                "Type",
                selection: $viewModel.draft.kind,
                values: Array(AddHabitKind.allCases),
                identifierPrefix: "habitDetailScreen.type",
                title: { $0.displayName }
            )
            .onChange(of: viewModel.draft.kind) { _, _ in
                viewModel.normalizeDraftSelection()
            }
            if viewModel.draft.kind == .negative {
                // Was `.pickerStyle(.segmented)`, the stock grey segmented
                // control. `OptionRail` is the design system's equivalent and
                // keeps the semantics: one selection, per-value accessibility
                // identifiers, and reflow at accessibility text sizes.
                OptionRail(
                    "Tracking",
                    selection: $viewModel.draft.trackingMode,
                    values: Array(AddHabitTrackingMode.allCases),
                    identifierPrefix: "habitDetailScreen.tracking",
                    title: { $0.displayName }
                )
            }
        }
    }

    private var rhythmEditorContent: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
                // Was `.pickerStyle(.segmented)`, the stock grey segmented
                // control. `OptionRail` is the design system's equivalent and
                // keeps the semantics: one selection, per-value accessibility
                // identifiers, and reflow at accessibility text sizes.
                OptionRail(
                    "Cadence",
                    selection: cadencePresetBinding,
                    values: Array(HabitCadencePreset.allCases),
                    identifierPrefix: "habitDetailScreen.cadence",
                    title: { $0.title }
                )

                if cadencePresetBinding.wrappedValue == .weekly {
                    HabitWeekdayPickerRow(selectedDays: weeklyDaysBinding)
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

                HabitTargetEditor(config: $viewModel.draft.targetConfig)

                HabitReminderWindowPicker(
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
                        withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                            viewModel.draft.ensureReminderWindowDefaults()
                        }
                    },
                    onClear: {
                        withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                            viewModel.draft.clearReminderWindow()
                        }
                    },
                    accessibilityIdentifierPrefix: "habitDetail.reminderWindow"
                )

                if let reminderError = viewModel.editorReminderWindowValidationError {
                    Text(reminderError)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(DetailTonePalette.dangerText)
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

                TextField("Notes", text: $viewModel.draft.notes, prompt: Text("Notes").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                    .lineLimit(3...7)
                    .textFieldStyle(TokenTextFieldStyle())

        }
    }

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
                TextField("Search icons", text: $viewModel.draft.iconSearchQuery, prompt: Text("Search icons").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                    .textFieldStyle(TokenTextFieldStyle())

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing.s8) {
                        ForEach(viewModel.availableIconOptions.prefix(18)) { option in
                            Button {
                                viewModel.draft.selectedIconSymbolName = option.symbolName
                            } label: {
                                Image(systemName: option.symbolName)
                                    .font(ClayTypography.bodyStrong)
                                    .foregroundStyle(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                                    .frame(width: CreationChipMetrics.compactSwatchSize, height: CreationChipMetrics.compactSwatchSize)
                                    .background(viewModel.draft.selectedIconSymbolName == option.symbolName ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary, in: RoundedRectangle(cornerRadius: CreationChipMetrics.compactCornerRadius, style: .continuous))
                                .minimumHitTarget(CreationChipMetrics.hitHeight)
                            }
                            .frame(width: CreationChipMetrics.hitHeight, height: CreationChipMetrics.hitHeight)
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
                                RoundedRectangle(cornerRadius: CreationChipMetrics.compactCornerRadius, style: .continuous)
                                    .fill(Color(lifeboardHex: family.canonicalHex))
                                    .frame(width: CreationChipMetrics.compactSwatchSize, height: CreationChipMetrics.compactSwatchSize)
                                    .overlay {
                                        if colorFamily == family {
                                            RoundedRectangle(cornerRadius: CreationChipMetrics.compactCornerRadius, style: .continuous)
                                                .stroke(Color.lifeboard.accentOnPrimary, lineWidth: 2)
                                                .padding(3)
                                        }
                                    }
                                    .minimumHitTarget(CreationChipMetrics.hitHeight)
                            }
                            .frame(width: CreationChipMetrics.hitHeight, height: CreationChipMetrics.hitHeight)
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
                .buttonStyle(DetailCapsuleButtonStyle(tone: .quiet))
                .disabled(viewModel.isSaving)

                if viewModel.row.trackingMode == .lapseOnly && !viewModel.row.isArchived {
                    // Same words and flow as Home's "Log a slip…": confirm,
                    // save, then a receipt with Undo.
                    Button("Log a slip…", systemImage: "arrow.uturn.backward.circle") {
                        confirmsSlip = true
                    }
                    .buttonStyle(DetailCapsuleButtonStyle(tone: .warning))
                    .disabled(viewModel.isSaving)
                    .confirmationDialog(
                        HomeHabitCopy.slipConfirmTitle,
                        isPresented: $confirmsSlip,
                        titleVisibility: .visible
                    ) {
                        Button(HomeHabitCopy.slipConfirmAction) { logSlip() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(HomeHabitCopy.slipConfirmMessage)
                    }
                }

                if viewModel.row.isArchived {
                    if viewModel.canRestoreFromArchive {
                        Button("Restore habit", systemImage: "arrow.uturn.backward") {
                            restoreFromArchive()
                        }
                        .buttonStyle(DetailCapsuleButtonStyle(tone: .quiet))
                        .disabled(viewModel.isSaving)
                        .accessibilityIdentifier("habit.detail.restore")
                    }
                } else {
                    Button("Archive habit", systemImage: "archivebox.fill") {
                        let title = viewModel.row.title
                        viewModel.archive { didSucceed in
                            guard didSucceed else { return }
                            notifyMutation()
                            // Archiving is reversible, so it runs at once and
                            // offers Undo instead of asking first.
                            snackbar = SnackbarData(
                                message: String(localized: "Archived \u{201C}\(title)\u{201D}"),
                                actions: viewModel.canRestoreFromArchive ? [
                                    SnackbarAction(title: "Undo") { restoreFromArchive() }
                                ] : []
                            )
                        }
                    }
                    .buttonStyle(DetailCapsuleButtonStyle(tone: .danger))
                    .disabled(viewModel.isSaving)
                }

                Text("Paused and archived habits keep their history.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
        }
    }
}

extension HabitDetailScreen {
    /// Persist first, then a quiet haptic and a receipt that can take it back.
    /// A slip is a fact about a day, so nothing here buzzes like failure.
    private func logSlip() {
        let title = viewModel.row.title
        viewModel.logLapse { didSucceed in
            guard didSucceed else {
                Haptic.fail.play()
                return
            }
            Haptic.decline.play()
            notifyMutation()
            snackbar = SnackbarData(
                message: HomeHabitCopy.slipReceipt(title),
                actions: [
                    SnackbarAction(title: "Undo") {
                        viewModel.undoTodayLapse { undone in
                            if undone {
                                Haptic.pick.play()
                                notifyMutation()
                            } else {
                                Haptic.fail.play()
                            }
                        }
                    }
                ]
            )
        }
    }

    private func restoreFromArchive() {
        viewModel.restoreFromArchive { didSucceed in
            guard didSucceed else { return }
            notifyMutation()
            snackbar = SnackbarData(message: String(localized: "Habit restored"))
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
                ClayColorTokens.warmCanvas,
                ClayColorTokens.canvas,
                ClayColorTokens.coolCanvas
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
        HexColor.color(
            viewModel.draft.colorHex,
            fallback: viewModel.draft.kind == .positive ? Color.lifeboard.statusSuccess : Color.lifeboard.statusWarning
        )
    }

    private var habitStateLabel: String {
        if viewModel.row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
        if viewModel.row.isPaused { return String(localized: "Paused") }
        return String(localized: "Active")
    }

    private var habitStateSymbol: String {
        if viewModel.row.isArchived { return "archivebox.fill" }
        if viewModel.row.isPaused { return "pause.fill" }
        return "leaf.fill"
    }

    private var reminderSummary: String {
        let startText = viewModel.draft.reminderWindowStart.trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = viewModel.draft.reminderWindowEnd.trimmingCharacters(in: .whitespacesAndNewlines)
        if startText.isEmpty && endText.isEmpty { return String(localized: "No reminder") }
        let start = startText.isEmpty ? "—" : startText
        let end = endText.isEmpty ? "—" : endText
        return "\(start)–\(end)"
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
        parts.append(viewModel.draft.trackingMode == .lapseOnly ? String(localized: "Log slips only") : String(localized: "Daily check-in"))
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
            return String(localized: "Daily at \(formattedTime(hour: hour, minute: minute))")
        case .weekly(let days, let hour, let minute):
            return String(localized: "\(weekdaySummary(days)) at \(formattedTime(hour: hour, minute: minute))")
        case .interval(let days, let hour, let minute):
            return String(localized: "Every \(max(1, days)) days at \(formattedTime(hour: hour, minute: minute))")
        }
    }

    private func formattedTime(hour: Int?, minute: Int?) -> String {
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour ?? 9, minute: minute ?? 0, second: 0, of: calendar.startOfDay(for: Date())) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func weekdaySummary(_ days: [Int]) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        if days.count == 5 && days == [2, 3, 4, 5, 6] { return String(localized: "Weekdays") }
        if days.count == 7 { return String(localized: "Every day") }
        return days.compactMap { day in
            let index = max(0, min(symbols.count - 1, day - 1))
            guard symbols.indices.contains(index) else { return nil }
            return symbols[index]
        }.joined(separator: " · ")
    }

    private func todayActionTitle(for cell: HabitDetailDayCell) -> String {
        switch cell.state {
        case .success:
            return viewModel.row.kind == .negative ? String(localized: "Log slip today") : String(localized: "Skip today")
        case .skipped, .lapsed: return String(localized: "Clear today")
        case .future: return String(localized: "Not due yet")
        default:
            if viewModel.row.kind == .negative {
                return viewModel.row.trackingMode == .lapseOnly ? String(localized: "Log slip today") : String(localized: "Mark clean")
            }
            return String(localized: "Mark done")
        }
    }

    private func todayActionSymbol(for cell: HabitDetailDayCell) -> String {
        switch cell.state {
        case .success: return "arrow.uturn.backward.circle"
        case .skipped, .lapsed: return "minus.circle"
        default: return "checkmark.circle.fill"
        }
    }

    private var cadencePresetBinding: Binding<HabitCadencePreset> {
        Binding(
            get: {
                switch viewModel.draft.cadence {
                case .daily: return .daily
                case .weekly: return .weekly
                case .interval: return .interval
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
                case .interval:
                    viewModel.draft.cadence = .interval(days: intervalDays(from: viewModel.draft.cadence), hour: time.hour, minute: time.minute)
                }
            }
        )
    }

    /// Hold on the hero ring: to the target completes today, back to zero
    /// resets it. Both are the calendar's own next-mutation, so the receipt
    /// and Undo snackbar are the same ones a tapped cell gets.
    private func logToday(_ change: HabitAmountChange, cell: HabitDetailDayCell) async -> Bool {
        let wantsDone = HabitAmountRule.apply(change, to: cell.state == .success ? 1 : 0, target: 1) >= 1
        guard wantsDone != (cell.state == .success), cell.isInteractive else { return true }
        return await withCheckedContinuation { continuation in
            let onMutation = onMutation
            viewModel.mutateDay(cell) { didSucceed in
                if didSucceed { onMutation() }
                continuation.resume(returning: didSucceed)
            }
        }
    }

    private func mutate(_ cell: HabitDetailDayCell) {
        let onMutation = onMutation
        let willCompleteToday = cell.isToday && cell.state != .success && cell.state != .future
        viewModel.mutateDay(cell) { didSucceed in
            guard didSucceed else { return }
            // The mutation feedback already plays its haptic.
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
        case .selection: Haptic.pick.play()
        case .success: Haptic.commit.play()
        // A lapse or reset is a fact about a day, not a failure.
        case .warning: Haptic.decline.play()
        }
    }
}

enum HabitDetailAccessibilityID {
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
    static let heroRing = "habitDetail.hero.ring"
}

private struct HabitMetricGrid: View {
    let metrics: HabitDetailCalendarSummaryMetrics
    let accentColor: Color

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens
    private var spacing: SemanticSpacingTokens { tokens.spacing }

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
        HabitMetricTile(
            title: String(localized: "Streak"),
            subtitle: nil,
            value: metrics.currentStreakDisplay,
            valueColor: accentColor,
            accessibilityIdentifier: HabitDetailAccessibilityID.currentStreakMetric
        )
        HabitMetricTile(
            title: String(localized: "Best streak"),
            subtitle: nil,
            value: metrics.bestStreakDisplay,
            valueColor: Color.lifeboard.textPrimary,
            accessibilityIdentifier: HabitDetailAccessibilityID.bestStreakMetric
        )
        HabitMetricTile(
            title: String(localized: "Total"),
            subtitle: nil,
            value: metrics.totalCountDisplay,
            valueColor: Color.lifeboard.textPrimary,
            accessibilityIdentifier: HabitDetailAccessibilityID.totalCountMetric
        )
        HabitMetricTile(
            title: String(localized: "Completion rate"),
            subtitle: nil,
            value: metrics.completionRateDisplay,
            valueColor: completionRateColor,
            accessibilityIdentifier: HabitDetailAccessibilityID.completionRateMetric
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

private struct HabitMetricTile: View {
    let title: String
    let subtitle: String?
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

            Text(title)
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .lifeboardDenseSurface(
            cornerRadius: Theme.CornerRadius.md,
            fillColor: Color.lifeboard.surfaceSecondary.opacity(0.72),
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.78)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
        .lifeBoardMotion(.contentInsertion, value: value)
    }
}

private struct HabitWeekdayPickerRow: View {
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
