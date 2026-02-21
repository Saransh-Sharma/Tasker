//
//  HomeForedropView.swift
//  Tasker
//
//  New SwiftUI Home shell with backdrop/foredrop pattern.
//

import SwiftUI
import UIKit

// MARK: - Foredrop Anchor

enum ForedropAnchor: Equatable {
    /// Foredrop covers calendar + charts. Default state.
    case collapsed
    /// Foredrop anchors below the weekly calendar strip.
    case midReveal
    /// Foredrop anchors below the chart cards (full analytics view).
    case fullReveal
}

struct HomeForedropLayoutMetrics {
    static let midRevealBaseOffset: CGFloat = 94
    static let extraFullRevealPadding: CGFloat = 72
    static let minimumVisibleForedropHeight: CGFloat = 120
    static let minimumAnalyticsPeekAtFullReveal: CGFloat = 620

    var calendarExpandedHeight: CGFloat
    var analyticsSectionHeight: CGFloat
    var geometryHeight: CGFloat

    var midOffset: CGFloat {
        Self.midRevealBaseOffset + calendarExpandedHeight
    }

    var fullOffset: CGFloat {
        let analyticsDrivenPeek = analyticsSectionHeight + Self.extraFullRevealPadding
        let targetPeek = max(analyticsDrivenPeek, Self.minimumAnalyticsPeekAtFullReveal)
        let fullRaw = midOffset + targetPeek
        let cappedOffset = min(fullRaw, geometryHeight - Self.minimumVisibleForedropHeight)
        return max(midOffset, cappedOffset)
    }

    /// Executes offset.
    func offset(for anchor: ForedropAnchor) -> CGFloat {
        switch anchor {
        case .collapsed:
            return 0
        case .midReveal:
            return midOffset
        case .fullReveal:
            return fullOffset
        }
    }
}

struct HomeForedropHintEligibility {
    static let triggerCooldown: TimeInterval = 0.7

    /// Executes canTrigger.
    static func canTrigger(
        isHomeVisible: Bool,
        foredropAnchor: ForedropAnchor,
        reduceMotionEnabled: Bool,
        isUITesting: Bool,
        hasRunningAnimation: Bool,
        lastTriggerDate: Date?,
        now: Date = Date(),
        cooldown: TimeInterval = triggerCooldown
    ) -> Bool {
        guard isHomeVisible else { return false }
        guard foredropAnchor == .collapsed else { return false }
        guard !reduceMotionEnabled else { return false }
        guard !isUITesting else { return false }
        guard !hasRunningAnimation else { return false }
        guard let lastTriggerDate else { return true }

        return now.timeIntervalSince(lastTriggerDate) >= cooldown
    }
}

private struct CalendarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 80
    /// Executes reduce.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AnalyticsSectionHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    /// Executes reduce.
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct SettingsButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .null
    /// Executes reduce.
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private extension TimeInterval {
    var nanoseconds: UInt64 {
        UInt64((self * 1_000_000_000).rounded())
    }
}

private extension ForedropAnchor {
    var accessibilityValue: String {
        switch self {
        case .collapsed:
            return "collapsed"
        case .midReveal:
            return "midReveal"
        case .fullReveal:
            return "fullReveal"
        }
    }
}

struct HomeBackdropForedropRootView: View {
    @ObservedObject var viewModel: HomeViewModel
    @ObservedObject var chartCardViewModel: ChartCardViewModel
    @ObservedObject var radarChartCardViewModel: RadarChartCardViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onTaskTap: (TaskDefinition) -> Void
    let onToggleComplete: (TaskDefinition) -> Void
    let onDeleteTask: (TaskDefinition) -> Void
    let onRescheduleTask: (TaskDefinition) -> Void
    let onReorderCustomProjects: ([UUID]) -> Void
    let onAddTask: () -> Void
    let onOpenSearch: () -> Void
    let onOpenChat: () -> Void
    let onOpenProjectCreator: () -> Void
    let onOpenSettings: () -> Void
    let onSettingsButtonFrameChange: (CGRect) -> Void

    @State private var foredropAnchor: ForedropAnchor = .collapsed
    @State private var calendarExpandedHeight: CGFloat = 0
    @State private var analyticsSectionHeight: CGFloat = 0
    @State private var showAdvancedFilters = false
    @State private var showDatePicker = false
    @State private var draftDate = Date()
    @State private var lastDailyScore: Int?
    @State private var showXPBurst = false
    @State private var xpBurstValue = 0
    @State private var bottomBarState = HomeBottomBarState()
    @State private var lastTaskListOffset: CGFloat = 0
    @State private var foredropHintOffset: CGFloat = 0
    @State private var hintAnimationTask: _Concurrency.Task<Void, Never>?
    @State private var lastHintTriggerAt: Date?
    @State private var isHomeVisible = false

    private static let foredropHintLaunchDelay: TimeInterval = 0.10
    private static let foredropHintPeekDistance: CGFloat = 24
    private static let foredropHintPeekDuration: TimeInterval = 0.10
    private static let foredropHintReturnResponse: TimeInterval = 0.22
    private static let foredropHintReturnDampingFraction: CGFloat = 0.86
    private static let foredropHintSettleDuration: TimeInterval = 0.16
    private static let launchArguments = Set(ProcessInfo.processInfo.arguments)

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }
    private var isUITesting: Bool {
        Self.launchArguments.contains("-UI_TESTING") || Self.launchArguments.contains("-DISABLE_ANIMATIONS")
    }

    /// Executes foredropOffset.
    private func foredropOffset(for geometryHeight: CGFloat) -> CGFloat {
        let metrics = HomeForedropLayoutMetrics(
            calendarExpandedHeight: calendarExpandedHeight,
            analyticsSectionHeight: analyticsSectionHeight,
            geometryHeight: geometryHeight
        )
        return metrics.offset(for: foredropAnchor)
    }

    /// Executes chartCardsViewportHeight.
    private func chartCardsViewportHeight(for geometry: GeometryProxy) -> CGFloat {
        let preferred = geometry.size.height * 0.66
        let lowerBound: CGFloat = 560
        let upperBound = geometry.size.height - 150
        return min(max(preferred, lowerBound), upperBound)
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    backdropLayer(geometry: geometry)

                    foredropLayer(geometry: geometry)
                        .offset(y: foredropOffset(for: geometry.size.height) + foredropHintOffset)
                        .animation(TaskerAnimation.snappy, value: foredropAnchor)
                        .animation(TaskerAnimation.snappy, value: calendarExpandedHeight)
                        .animation(TaskerAnimation.snappy, value: analyticsSectionHeight)
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onEnded { value in
                                    let threshold: CGFloat = 50
                                    withAnimation(TaskerAnimation.snappy) {
                                        if value.translation.height > threshold {
                                            // Pull down: advance to next stop
                                            switch foredropAnchor {
                                            case .collapsed:  foredropAnchor = .midReveal
                                            case .midReveal:  foredropAnchor = .fullReveal
                                            case .fullReveal: break
                                            }
                                        } else if value.translation.height < -threshold {
                                            // Pull up: retreat to previous stop
                                            switch foredropAnchor {
                                            case .collapsed:  break
                                            case .midReveal:  foredropAnchor = .collapsed
                                            case .fullReveal: foredropAnchor = .midReveal
                                            }
                                        }
                                    }
                                }
                        )
                }
                .background(Color.tasker.bgCanvas)
                .sheet(isPresented: $showDatePicker) {
                    NavigationView {
                        VStack(spacing: spacing.s16) {
                            DatePicker(
                                "Select date",
                                selection: $draftDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .padding(.horizontal, spacing.s16)

                            HStack(spacing: spacing.s12) {
                                Button("Today") {
                                    draftDate = Date()
                                    viewModel.selectDate(Date())
                                    showDatePicker = false
                                }
                                .buttonStyle(.bordered)

                                Button("Apply") {
                                    viewModel.selectDate(draftDate)
                                    showDatePicker = false
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .navigationTitle("Date")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showDatePicker = false }
                            }
                        }
                    }
                }
                .sheet(isPresented: $showAdvancedFilters) {
                    HomeAdvancedFilterSheetView(
                        initialFilter: viewModel.activeFilterState.advancedFilter,
                        initialShowCompletedInline: viewModel.activeFilterState.showCompletedInline,
                        savedViews: viewModel.savedHomeViews,
                        activeSavedViewID: viewModel.activeFilterState.selectedSavedViewID,
                        onApply: { filter, showCompletedInline in
                            viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                        },
                        onClear: {
                            viewModel.applyAdvancedFilter(nil, showCompletedInline: false)
                            viewModel.clearProjectFilters()
                            viewModel.setQuickView(.today)
                        },
                        onSaveNamedView: { filter, showCompletedInline, name in
                            viewModel.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                            viewModel.saveCurrentFilterAsView(name: name)
                        },
                        onApplySavedView: { id in
                            viewModel.applySavedView(id: id)
                        },
                        onDeleteSavedView: { id in
                            viewModel.deleteSavedView(id: id)
                        }
                    )
                }
            }

            if showXPBurst {
                xpBurstOverlay
            }
        }
        .accessibilityIdentifier("home.view")
        .overlay(alignment: .bottom) {
            homeBottomBar
        }
        .onAppear {
            isHomeVisible = true
            lastDailyScore = viewModel.dailyScore
            triggerForedropHintIfEligible()
        }
        .onDisappear {
            isHomeVisible = false
            cancelForedropHintAnimation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            triggerForedropHintIfEligible()
        }
        .onPreferenceChange(SettingsButtonFramePreferenceKey.self) { frame in
            onSettingsButtonFrameChange(frame)
        }
        .onReceive(viewModel.$dailyScore.receive(on: RunLoop.main)) { newScore in
            handleDailyScoreUpdate(newScore)
        }
        .sheet(
            isPresented: Binding(
                get: { viewModel.shouldShowOverdueTriage },
                set: { isPresented in
                    if isPresented == false, viewModel.shouldShowOverdueTriage {
                        viewModel.dismissOverdueTriage()
                    }
                }
            )
        ) {
            overdueTriageSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.tasker.bgElevated)
        }
    }

    /// Executes triggerForedropHintIfEligible.
    private func triggerForedropHintIfEligible(now: Date = Date()) {
        let canTrigger = HomeForedropHintEligibility.canTrigger(
            isHomeVisible: isHomeVisible,
            foredropAnchor: foredropAnchor,
            reduceMotionEnabled: reduceMotion,
            isUITesting: isUITesting,
            hasRunningAnimation: hintAnimationTask != nil,
            lastTriggerDate: lastHintTriggerAt,
            now: now
        )
        guard canTrigger else { return }

        startForedropHintAnimation(triggeredAt: now)
    }

    /// Executes startForedropHintAnimation.
    private func startForedropHintAnimation(triggeredAt timestamp: Date) {
        cancelForedropHintAnimation()
        lastHintTriggerAt = timestamp

        hintAnimationTask = _Concurrency.Task { @MainActor in
            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.foredropHintLaunchDelay.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(.easeOut(duration: Self.foredropHintPeekDuration)) {
                foredropHintOffset = Self.foredropHintPeekDistance
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.foredropHintPeekDuration.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(
                .spring(
                    response: Self.foredropHintReturnResponse,
                    dampingFraction: Self.foredropHintReturnDampingFraction
                )
            ) {
                foredropHintOffset = 0
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.foredropHintSettleDuration.nanoseconds)
            } catch {
                return
            }

            hintAnimationTask = nil
        }
    }

    /// Executes cancelForedropHintAnimation.
    private func cancelForedropHintAnimation() {
        hintAnimationTask?.cancel()
        hintAnimationTask = nil
        foredropHintOffset = 0
    }

    /// Executes backdropLayer.
    private func backdropLayer(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tasker.accentPrimary.opacity(0.24),
                            Color.tasker.bgCanvas
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: max(480, geometry.size.height * 0.65))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        // 1. Weekly Calendar Strip
                        WeeklyCalendarStripView(
                            selectedDate: Binding(
                                get: { viewModel.selectedDate },
                                set: { viewModel.selectDate($0) }
                            ),
                            todayDate: Date()
                        )
                        .background(
                            GeometryReader { calGeo in
                                Color.clear.preference(
                                    key: CalendarHeightPreferenceKey.self,
                                    value: calGeo.size.height
                                )
                            }
                        )
                        .onPreferenceChange(CalendarHeightPreferenceKey.self) { height in
                            let baseWeekHeight: CGFloat = 80
                            calendarExpandedHeight = max(0, height - baseWeekHeight)
                        }
                        .opacity(foredropAnchor != .collapsed ? 1 : 0.001)

                        // 2. Chart Cards (visible when fully revealed)
                        VStack(alignment: .leading, spacing: spacing.s12) {
                            Text("Analytics")
                                .font(.tasker(.headline))
                                .foregroundColor(Color.tasker.textPrimary)

                            ChartCardsScrollView(
                                referenceDate: viewModel.selectedDate,
                                onCreateProject: onOpenProjectCreator,
                                chartViewModel: chartCardViewModel,
                                radarViewModel: radarChartCardViewModel
                            )
                                .frame(height: chartCardsViewportHeight(for: geometry))
                        }
                        .background(
                            GeometryReader { analyticsGeo in
                                Color.clear.preference(
                                    key: AnalyticsSectionHeightPreferenceKey.self,
                                    value: analyticsGeo.size.height
                                )
                            }
                        )
                        .onPreferenceChange(AnalyticsSectionHeightPreferenceKey.self) { height in
                            analyticsSectionHeight = max(0, height)
                        }
                        .opacity(foredropAnchor == .fullReveal ? 1 : 0.001)
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s8)
                }
            Spacer(minLength: 0)
        }
    }

    /// Executes foredropLayer.
    private func foredropLayer(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            handleBar
                .padding(.top, spacing.s8)

            homeHeader
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)

            if viewModel.canUseManualFocusDrag || !viewModel.focusTasks.isEmpty {
                focusStrip
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s2)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home.focus.strip")
            }

            // Next action module: contextual guidance for empty/low-content states
            if viewModel.activeScope.quickView == .today && viewModel.pinnedFocusTaskIDs.count < 3 {
                NextActionModule(
                    openTaskCount: viewModel.todayOpenTaskCount,
                    focusPinnedCount: viewModel.pinnedFocusTaskIDs.count,
                    onAddTask: { onAddTask() }
                )
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s4)
            }

            aiAssistCard
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s4)

            TaskListView(
                morningTasks: viewModel.morningTasks,
                eveningTasks: viewModel.eveningTasks,
                overdueTasks: viewModel.overdueTasks,
                inlineCompletedTasks: viewModel.activeScope.quickView == .today ? viewModel.completedTasks : [],
                projects: viewModel.projects,
                doneTimelineTasks: viewModel.doneTimelineTasks,
                activeQuickView: viewModel.activeScope.quickView,
                projectGroupingMode: viewModel.activeFilterState.projectGroupingMode,
                customProjectOrderIDs: viewModel.activeFilterState.customProjectOrderIDs,
                emptyStateMessage: viewModel.emptyStateMessage,
                emptyStateActionTitle: viewModel.emptyStateActionTitle,
                isTaskDragEnabled: viewModel.canUseManualFocusDrag,
                onTaskTap: onTaskTap,
                onToggleComplete: { task in
                    trackTaskToggle(task, source: "task_list")
                    onToggleComplete(task)
                },
                onDeleteTask: onDeleteTask,
                onRescheduleTask: onRescheduleTask,
                onReorderCustomProjects: onReorderCustomProjects,
                onCompletedSectionToggle: { sectionID, collapsed, count in
                    viewModel.trackHomeInteraction(
                        action: "home_completed_group_toggled",
                        metadata: [
                            "section_id": sectionID.uuidString,
                            "collapsed": collapsed,
                            "count": count
                        ]
                    )
                },
                onEmptyStateAction: { onAddTask() },
                onTaskDragStarted: { task in
                    trackTaskDragStarted(task, source: "task_list")
                },
                onScrollOffsetChange: { newOffset in
                    let delta = newOffset - lastTaskListOffset
                    bottomBarState.updateMinimizeState(fromScrollDelta: delta)
                    lastTaskListOffset = newOffset
                },
                bottomContentInset: 0
            )
            .padding(.top, spacing.s4)
            .onDrop(of: ["public.text"], isTargeted: nil, perform: handleListDrop)
            .accessibilityIdentifier("home.list.dropzone")
        }
        .frame(
            width: geometry.size.width,
            height: geometry.size.height,
            alignment: .top
        )
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: corner.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: corner.modal
            )
                .fill(Color.tasker.surfacePrimary)
                .taskerElevation(.e2, cornerRadius: corner.modal, includesBorder: false)
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: corner.modal,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: corner.modal
            )
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.foredrop.surface")
        .accessibilityValue(foredropAnchor.accessibilityValue)
    }

    @ViewBuilder
    private var aiAssistCard: some View {
        if V2FeatureFlags.assistantCopilotEnabled &&
            (viewModel.activeScope.quickView == .today || viewModel.isGeneratingAITopSuggestions || !viewModel.aiTopSuggestions.isEmpty) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack {
                    Text("Eva suggestions")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                    Spacer()
                    Button("Help me choose") {
                        viewModel.helpMeChooseTop3()
                    }
                    .font(.tasker(.caption1))
                    .buttonStyle(.plain)
                }

                if viewModel.isGeneratingAITopSuggestions {
                    HStack(spacing: spacing.s8) {
                        ProgressView()
                        Text("Choosing top 3...")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)
                    }
                } else {
                    if let banner = viewModel.aiTopSuggestionsRouteBanner, banner.isEmpty == false {
                        HStack(alignment: .top, spacing: spacing.s8) {
                            Image(systemName: "cpu")
                                .foregroundColor(Color.tasker.accentPrimary)
                            Text(banner)
                                .font(.tasker(.caption2))
                                .foregroundColor(Color.tasker.textTertiary)
                            Spacer(minLength: 0)
                        }
                    }
                    ForEach(viewModel.aiTopSuggestions, id: \.taskID) { suggestion in
                        Text(
                            "• \(suggestion.title) — \(suggestion.rationale) (\(Int((suggestion.confidence * 100).rounded()))%)"
                        )
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textPrimary)
                    }
                }

                if !viewModel.energyAwareSuggestedTasks.isEmpty {
                    Text("Right now energy fit:")
                        .font(.tasker(.caption2))
                        .foregroundColor(Color.tasker.textTertiary)
                    Text(viewModel.energyAwareSuggestedTasks.map(\.title).joined(separator: " • "))
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s12)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary)
            )
        }
    }

    @ViewBuilder
    private var overdueTriageSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("\(viewModel.overdueTasks.count) overdue tasks")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                if let suggestion = viewModel.overdueTriageSuggestion {
                    ForEach(suggestion.summaryLines, id: \.self) { line in
                        Text("• \(line)")
                            .font(.tasker(.callout))
                            .foregroundColor(Color.tasker.textSecondary)
                    }
                }

                HStack(spacing: spacing.s8) {
                    Button("Dismiss") {
                        viewModel.dismissOverdueTriage()
                    }
                    .buttonStyle(.bordered)

                    Button("Customize in Chat") {
                        viewModel.customizeOverdueTriageInChat()
                        onOpenChat()
                    }
                    .buttonStyle(.bordered)

                    Button("Apply All") {
                        viewModel.applyOverdueTriage { _ in }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isApplyingOverdueTriage)
                }
                Spacer(minLength: 0)
            }
            .padding(spacing.s16)
            .navigationTitle("Overdue Triage")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.dismissOverdueTriage()
                    }
                }
            }
        }
    }

    private var handleBar: some View {
        VStack(spacing: spacing.s4) {
            Capsule()
                .fill(Color.tasker.textQuaternary.opacity(0.4))
                .frame(width: 44, height: 5)
                .accessibilityIdentifier("home.foredrop.handle")

            if foredropAnchor == .fullReveal {
                Button {
                    withAnimation(TaskerAnimation.snappy) {
                        foredropAnchor = .collapsed
                    }
                } label: {
                    HStack(spacing: spacing.s4) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                        Text("collapse")
                            .font(.tasker(.caption2))
                    }
                    .foregroundColor(Color.tasker.textQuaternary.opacity(0.85))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.foredrop.collapseHint")
                .accessibilityLabel("Collapse analytics")
            }
        }
    }

    private var homeHeader: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            // Navigation bar with quick view selector, pie chart, and actions
            HStack(spacing: spacing.s8) {
                // Quick view selector
                QuickViewSelector(
                    selectedQuickView: Binding(
                        get: { viewModel.activeScope.quickView },
                        set: { viewModel.setQuickView($0) }
                    ),
                    taskCounts: viewModel.quickViewCounts,
                    onShowDatePicker: {
                        draftDate = viewModel.selectedDate
                        showDatePicker = true
                    },
                    onShowAdvancedFilters: {
                        showAdvancedFilters = true
                    },
                    onResetFilters: {
                        viewModel.resetAllFilters()
                    }
                )

                Spacer()

                // Score pie chart
                NavPieChart(
                    score: viewModel.dailyScore,
                    maxScore: viewModel.progressState.todayTargetXP
                ) {
                    withAnimation(TaskerAnimation.snappy) {
                        foredropAnchor = foredropAnchor == .fullReveal ? .collapsed : .fullReveal
                    }
                }

                // Settings button
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.tasker.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.tasker.surfaceSecondary))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.settingsButton")
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: SettingsButtonFramePreferenceKey.self,
                            value: proxy.frame(in: .global)
                        )
                    }
                )
            }

            // XP progress bar with streak
            cockpitStats

            // Quick filter pills (when filters are active)
            if !viewModel.activeFilterState.selectedProjectIDs.isEmpty
                || viewModel.activeFilterState.advancedFilter != nil {
                quickFilterPills
            }
        }
    }

    private var quickFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s4) {
                if let projectFilter = viewModel.activeFilterState.selectedProjectIDs.first {
                    FilterPill(
                        title: viewModel.projects.first(where: { $0.id == projectFilter })?.name ?? "Project",
                        systemImage: "folder"
                    ) {
                        viewModel.clearProjectFilters()
                    }
                }

                if viewModel.activeFilterState.advancedFilter != nil {
                    FilterPill(
                        title: "Filters",
                        systemImage: "slider.horizontal.3"
                    ) {
                        viewModel.applyAdvancedFilter(nil, showCompletedInline: false)
                    }
                }

                FilterPill(
                    title: "Clear all",
                    systemImage: "xmark.circle.fill",
                    isDestructive: true
                ) {
                    viewModel.resetAllFilters()
                }
            }
        }
    }

    private var cockpitStats: some View {
        let progress = viewModel.progressState
        let denominator = max(1, progress.todayTargetXP)
        let progressRatio = min(1, Double(progress.earnedXP) / Double(denominator))

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: spacing.s8) {
                Text("\(progress.earnedXP)/\(progress.todayTargetXP) XP Today")
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
                    .accessibilityIdentifier("home.dailyScoreLabel")

                Text("\u{00B7}")
                    .foregroundColor(Color.tasker.textQuaternary)

                streakIndicator(for: progress)

                Spacer()
            }

            // Enhanced progress bar with gradient and glow
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.tasker.surfaceSecondary)

                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: progressGradientColors(isStreakSafe: progress.isStreakSafeToday),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressRatio)
                        .shadow(
                            color: progress.isStreakSafeToday
                                ? Color.tasker.accentPrimary.opacity(0.4)
                                : Color.tasker.statusWarning.opacity(0.4),
                            radius: 4,
                            x: 2,
                            y: 0
                        )
                }
            }
            .frame(height: 6)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: progressRatio)
        }
    }

    /// Executes progressGradientColors.
    private func progressGradientColors(isStreakSafe: Bool) -> [Color] {
        if isStreakSafe {
            return [Color.tasker.accentPrimary, Color.tasker.accentSecondary]
        } else {
            return [Color.tasker.statusWarning, Color.tasker.statusWarning.opacity(0.7)]
        }
    }

    /// Executes streakIndicator.
    @ViewBuilder
    private func streakIndicator(for progress: HomeProgressState) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(progress.isStreakSafeToday ? Color.tasker.accentSecondary : Color.tasker.statusWarning)
                .symbolEffect(.pulse, options: .repeating.speed(0.5), isActive: !progress.isStreakSafeToday)

            Text("\(progress.streakDays)d")
                .font(.tasker(.caption1))
                .fontWeight(.medium)
                .foregroundColor(progress.isStreakSafeToday ? Color.tasker.textSecondary : Color.tasker.statusWarning)
        }
    }

    private var focusStrip: some View {
        FocusZone(
            tasks: viewModel.focusTasks,
            canDrag: viewModel.canUseManualFocusDrag,
            onTaskTap: { task in
                onTaskTap(task)
            },
            onToggleComplete: { task in
                trackTaskToggle(task, source: "focus_strip")
                onToggleComplete(task)
            },
            onTaskDragStarted: { task in
                trackTaskDragStarted(task, source: "focus_strip")
            },
            onDrop: handleFocusDrop
        )
    }

    private var homeBottomBar: some View {
        HomeGlassBottomBar(
            state: bottomBarState,
            onChartsToggle: {
                withAnimation(TaskerAnimation.snappy) {
                    foredropAnchor = foredropAnchor == .fullReveal ? .collapsed : .fullReveal
                }
            },
            onSearch: {
                onOpenSearch()
            },
            onChat: {
                onOpenChat()
            },
            onCreate: {
                onAddTask()
            }
        )
        .padding(.horizontal, spacing.s16)
        .padding(.bottom, 0)
        .ignoresSafeArea(.container, edges: .bottom)
        .offset(y: 6)
        .animation(TaskerAnimation.snappy, value: bottomBarState.isMinimized)
    }

    private var xpBurstOverlay: some View {
        XPCelebrationView(xpValue: xpBurstValue, isPresented: $showXPBurst)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 100)
            .allowsHitTesting(false)
    }

    private var headerTitle: String {
        switch viewModel.activeScope {
        case .today:
            return "Today"
        case .customDate(let date):
            return Self.dateFormatter.string(from: date)
        case .upcoming:
            return "Upcoming"
        case .done:
            return "Done"
        case .morning:
            return "Morning"
        case .evening:
            return "Evening"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter
    }()

    /// Executes trackTaskToggle.
    private func trackTaskToggle(_ task: TaskDefinition, source: String) {
        viewModel.trackHomeInteraction(
            action: "home_task_toggle",
            metadata: [
                "source": source,
                "task_id": task.id.uuidString,
                "current_state": task.isComplete ? "done" : "open"
            ]
        )
    }

    /// Executes trackTaskDragStarted.
    private func trackTaskDragStarted(_ task: TaskDefinition, source: String) {
        var metadata = focusScopeMetadata(source: source, taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
        viewModel.trackHomeInteraction(
            action: "home_focus_drag_started",
            metadata: metadata
        )
    }

    /// Executes handleFocusDrop.
    private func handleFocusDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }

            let pinResult = viewModel.pinTaskToFocus(taskID)
            var metadata = focusScopeMetadata(source: "task_list", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

            switch pinResult {
            case .pinned:
                TaskerFeedback.success()
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .alreadyPinned:
                TaskerFeedback.selection()
                metadata["result"] = "already_pinned"
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .capacityReached(let limit):
                TaskerFeedback.light()
                metadata["limit"] = limit
                viewModel.trackHomeInteraction(action: "home_focus_drop_rejected_capacity", metadata: metadata)
            case .taskIneligible:
                TaskerFeedback.selection()
            }
        }
    }

    /// Executes handleListDrop.
    private func handleListDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }
            let wasPinned = viewModel.pinnedFocusTaskIDs.contains(taskID)
            guard wasPinned else { return }

            viewModel.unpinTaskFromFocus(taskID)
            TaskerFeedback.selection()

            var metadata = focusScopeMetadata(source: "focus_strip", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
            viewModel.trackHomeInteraction(action: "home_focus_dropped_out", metadata: metadata)
        }
    }

    /// Executes loadTaskIDFromDrop.
    private func loadTaskIDFromDrop(
        providers: [NSItemProvider],
        completion: @escaping (UUID?) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            completion(nil)
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            let rawValue = (object as? NSString)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let taskID = rawValue.flatMap(UUID.init(uuidString:))
            DispatchQueue.main.async {
                completion(taskID)
            }
        }
        return true
    }

    /// Executes focusScopeMetadata.
    private func focusScopeMetadata(source: String, taskID: UUID) -> [String: Any] {
        [
            "source": source,
            "task_id": taskID.uuidString,
            "quick_view": viewModel.activeScope.quickView.analyticsAction,
            "scope": scopeAnalyticsName
        ]
    }

    private var scopeAnalyticsName: String {
        switch viewModel.activeScope {
        case .today:
            return "today"
        case .customDate:
            return "custom_date"
        case .upcoming:
            return "upcoming"
        case .done:
            return "done"
        case .morning:
            return "morning"
        case .evening:
            return "evening"
        }
    }

    /// Executes handleDailyScoreUpdate.
    private func handleDailyScoreUpdate(_ newScore: Int) {
        defer { lastDailyScore = newScore }

        guard let previous = lastDailyScore else { return }
        let delta = newScore - previous
        guard delta > 0 else { return }

        xpBurstValue = delta
        showXPBurst = true

        // Enhanced haptic feedback based on XP gain
        if delta >= 7 {
            TaskerFeedback.success()
        } else if delta >= 4 {
            TaskerFeedback.medium()
        } else {
            TaskerFeedback.light()
        }

        viewModel.trackHomeInteraction(
            action: "home_reward_xp_burst",
            metadata: ["delta": delta, "new_score": newScore]
        )
    }
}
