//
//  HomeForedropView.swift
//  Tasker
//
//  New SwiftUI Home shell with backdrop/foredrop pattern.
//

import SwiftUI

// MARK: - Foredrop Anchor

enum ForedropAnchor: Equatable {
    /// Foredrop covers calendar + charts. Default state.
    case collapsed
    /// Foredrop anchors below the weekly calendar strip.
    case midReveal
    /// Foredrop anchors below the chart cards (full analytics view).
    case fullReveal
}

private struct CalendarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 80
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct HomeBackdropForedropRootView: View {
    @ObservedObject var viewModel: HomeViewModel

    let onTaskTap: (DomainTask) -> Void
    let onToggleComplete: (DomainTask) -> Void
    let onDeleteTask: (DomainTask) -> Void
    let onRescheduleTask: (DomainTask) -> Void
    let onReorderCustomProjects: ([UUID]) -> Void
    let onAddTask: () -> Void
    let onOpenSearch: () -> Void
    let onOpenChat: () -> Void
    let onOpenSettings: () -> Void

    @State private var foredropAnchor: ForedropAnchor = .collapsed
    @State private var calendarExpandedHeight: CGFloat = 0
    @State private var showFilterDropdown = false
    @State private var showAdvancedFilters = false
    @State private var showDatePicker = false
    @State private var draftDate = Date()
    @State private var lastDailyScore: Int?
    @State private var showXPBurst = false
    @State private var xpBurstValue = 0
    @State private var xpBurstOffsetY: CGFloat = 24
    @State private var xpBurstOpacity: Double = 0
    @State private var bottomBarState = HomeBottomBarState()
    @State private var lastTaskListOffset: CGFloat = 0

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    /// Vertical offset for the foredrop based on anchor + calendar expansion.
    private var foredropOffset: CGFloat {
        let baseOffset: CGFloat = {
            switch foredropAnchor {
            case .collapsed:  return 0
            case .midReveal:  return 94 + calendarExpandedHeight
            case .fullReveal: return 380 + calendarExpandedHeight
            }
        }()
        return baseOffset
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    backdropLayer(geometry: geometry)

                    foredropLayer(geometry: geometry)
                        .offset(y: foredropOffset)
                        .animation(TaskerAnimation.snappy, value: foredropAnchor)
                        .animation(TaskerAnimation.snappy, value: calendarExpandedHeight)
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

            // Filter dropdown overlay
            if showFilterDropdown {
                HomeQuickFilterDropdown(
                    viewModel: viewModel,
                    isPresented: $showFilterDropdown,
                    onShowDatePicker: {
                        draftDate = viewModel.selectedDate
                        showDatePicker = true
                    },
                    onShowAdvancedFilters: {
                        showAdvancedFilters = true
                    }
                )
            }
        }
        .accessibilityIdentifier("home.view")
        .overlay(alignment: .bottom) {
            homeBottomBar
        }
        .onAppear {
            lastDailyScore = viewModel.dailyScore
        }
        .onReceive(viewModel.$dailyScore.receive(on: RunLoop.main)) { newScore in
            handleDailyScoreUpdate(newScore)
        }
    }

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

                            ChartCardsScrollView(referenceDate: viewModel.selectedDate)
                                .frame(height: 260)
                        }
                        .opacity(foredropAnchor == .fullReveal ? 1 : 0.001)
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s8)
                }
            Spacer(minLength: 0)
        }
    }

    private func foredropLayer(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            handleBar
                .padding(.top, spacing.s8)

            homeHeader
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)

            if viewModel.canUseManualFocusDrag || !viewModel.focusTasks.isEmpty {
                focusStrip
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s8)
            }

            // Next action module: contextual guidance for empty/low-content states
            if viewModel.activeScope.quickView == .today && viewModel.pinnedFocusTaskIDs.count < 3 {
                NextActionModule(
                    openTaskCount: viewModel.todayOpenTaskCount,
                    focusPinnedCount: viewModel.pinnedFocusTaskIDs.count,
                    onAddTask: onAddTask
                )
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
            }

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
                onEmptyStateAction: onAddTask,
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
        .accessibilityIdentifier("home.foredrop.surface")
    }

    private var handleBar: some View {
        Capsule()
            .fill(Color.tasker.textQuaternary.opacity(0.4))
            .frame(width: 44, height: 5)
            .accessibilityIdentifier("home.foredrop.handle")
    }

    private var homeHeader: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(spacing: spacing.s8) {
                Text(headerTitle)
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.textPrimary)

                Spacer()

                HomeQuickFilterTriggerButton(
                    summary: filterSummary,
                    isOpen: $showFilterDropdown
                ) {
                    showFilterDropdown = true
                }
                .controlSize(.small)

                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            cockpitStats
        }
    }

    private var cockpitStats: some View {
        let progress = viewModel.progressState
        let denominator = max(1, progress.todayTargetXP)

        return VStack(alignment: .leading, spacing: spacing.s4) {
            Text("XP Today: \(progress.earnedXP) / \(progress.todayTargetXP)")
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)
                .accessibilityIdentifier("home.dailyScoreLabel")

            Text(streakSafetyText(for: progress))
                .font(.tasker(.caption1))
                .foregroundColor(progress.isStreakSafeToday ? Color.tasker.textSecondary : Color.tasker.statusWarning)
                .accessibilityIdentifier("home.streakLabel")

            ProgressView(value: min(1, Double(progress.earnedXP) / Double(denominator)))
                .progressViewStyle(.linear)
                .tint(progress.isStreakSafeToday ? Color.tasker.accentPrimary : Color.tasker.statusWarning)
                .frame(maxWidth: .infinity)
        }
    }

    private var focusStrip: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Focus Now")
                .font(.tasker(.headline))
                .foregroundColor(Color.tasker.textPrimary)

            if viewModel.focusTasks.isEmpty {
                RoundedRectangle(cornerRadius: corner.input, style: .continuous)
                    .strokeBorder(Color.tasker.strokeHairline, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    .frame(height: 56)
                    .overlay {
                        Text("Long-press and drag a task here")
                            .font(.tasker(.caption1))
                            .foregroundColor(Color.tasker.textTertiary)
                    }
            } else {
                VStack(spacing: spacing.s4) {
                    ForEach(Array(viewModel.focusTasks.enumerated()), id: \.element.id) { index, task in
                        focusCard(task: task, index: index)
                    }
                }
                .accessibilityIdentifier("home.focus.strip")
            }
        }
        .onDrop(of: ["public.text"], isTargeted: nil, perform: handleFocusDrop)
        .accessibilityIdentifier("home.focus.dropzone")
    }

    @ViewBuilder
    private func focusCard(task: DomainTask, index: Int) -> some View {
        let model = TaskRowDisplayModel.from(task: task, showTypeBadge: false)

        let cardContent = VStack(alignment: .leading, spacing: spacing.s4) {
            HStack(spacing: spacing.s8) {
                Text(task.name)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(model.trailingMetaText)
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: spacing.s8) {
                Text(model.rowMetaText)
                    .font(.tasker(.caption2))
                    .foregroundColor(Color.tasker.textSecondary)
                    .lineLimit(1)

                if let urgency = model.urgencyLabel {
                    Text(urgency)
                        .font(.tasker(.caption2))
                        .foregroundColor(urgency == "Overdue" ? Color.tasker.statusDanger : Color.tasker.statusWarning)
                        .padding(.horizontal, spacing.s8)
                        .padding(.vertical, spacing.s2)
                        .background((urgency == "Overdue" ? Color.tasker.statusDanger : Color.tasker.statusWarning).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(
            RoundedRectangle(cornerRadius: corner.input, style: .continuous)
                .fill(Color.tasker.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner.input, style: .continuous)
                .stroke(Color.tasker.strokeHairline, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: corner.input, style: .continuous))
        .onTapGesture { onTaskTap(task) }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                trackTaskToggle(task, source: "focus_strip")
                onToggleComplete(task)
            } label: {
                Label(task.isComplete ? "Reopen" : "Complete", systemImage: task.isComplete ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(task.isComplete ? Color.tasker.accentSecondary : Color.tasker.statusSuccess)
        }
        .staggeredAppearance(index: index)
        .accessibilityIdentifier("home.focus.task.\(task.id.uuidString)")

        if viewModel.canUseManualFocusDrag {
            cardContent.onDrag {
                trackTaskDragStarted(task, source: "focus_strip")
                return NSItemProvider(object: task.id.uuidString as NSString)
            }
        } else {
            cardContent
        }
    }

    private var filterSummary: HomeQuickFilterSummary {
        HomeQuickFilterSummary.from(
            scope: viewModel.activeScope,
            filterState: viewModel.activeFilterState,
            customDate: viewModel.selectedDate
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
        Text("+\(xpBurstValue) XP")
            .font(.tasker(.headline))
            .foregroundColor(Color.tasker.accentPrimary)
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .background(
                Capsule()
                    .fill(Color.tasker.surfacePrimary)
                    .overlay(
                        Capsule().stroke(Color.tasker.accentPrimary.opacity(0.4), lineWidth: 1)
                    )
            )
            .offset(y: xpBurstOffsetY)
            .opacity(xpBurstOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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

    private func streakSafetyText(for progress: HomeProgressState) -> String {
        if progress.isStreakSafeToday {
            return "Streak safe • \(progress.streakDays) day streak"
        }
        return "Streak at risk • Complete 1 task to protect"
    }


    private func trackTaskToggle(_ task: DomainTask, source: String) {
        viewModel.trackHomeInteraction(
            action: "home_task_toggle",
            metadata: [
                "source": source,
                "task_id": task.id.uuidString,
                "current_state": task.isComplete ? "done" : "open"
            ]
        )
    }

    private func trackTaskDragStarted(_ task: DomainTask, source: String) {
        var metadata = focusScopeMetadata(source: source, taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
        viewModel.trackHomeInteraction(
            action: "home_focus_drag_started",
            metadata: metadata
        )
    }

    private func handleFocusDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }

            let pinResult = viewModel.pinTaskToFocus(taskID)
            var metadata = focusScopeMetadata(source: "task_list", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count

            switch pinResult {
            case .pinned:
                TaskerHaptic.success()
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .alreadyPinned:
                TaskerHaptic.selection()
                metadata["result"] = "already_pinned"
                viewModel.trackHomeInteraction(action: "home_focus_dropped_in", metadata: metadata)
            case .capacityReached(let limit):
                TaskerHaptic.light()
                metadata["limit"] = limit
                viewModel.trackHomeInteraction(action: "home_focus_drop_rejected_capacity", metadata: metadata)
            case .taskIneligible:
                TaskerHaptic.selection()
            }
        }
    }

    private func handleListDrop(providers: [NSItemProvider]) -> Bool {
        guard viewModel.canUseManualFocusDrag else { return false }

        return loadTaskIDFromDrop(providers: providers) { taskID in
            guard let taskID else { return }
            let wasPinned = viewModel.pinnedFocusTaskIDs.contains(taskID)
            guard wasPinned else { return }

            viewModel.unpinTaskFromFocus(taskID)
            TaskerHaptic.selection()

            var metadata = focusScopeMetadata(source: "focus_strip", taskID: taskID)
            metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
            viewModel.trackHomeInteraction(action: "home_focus_dropped_out", metadata: metadata)
        }
    }

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

    private func handleDailyScoreUpdate(_ newScore: Int) {
        defer { lastDailyScore = newScore }

        guard let previous = lastDailyScore else { return }
        let delta = newScore - previous
        guard delta > 0 else { return }

        xpBurstValue = delta
        xpBurstOffsetY = 24
        xpBurstOpacity = 1
        showXPBurst = true

        TaskerHaptic.light()
        viewModel.trackHomeInteraction(
            action: "home_reward_xp_burst",
            metadata: ["delta": delta, "new_score": newScore]
        )

        withAnimation(TaskerAnimation.gentle) {
            xpBurstOffsetY = -18
        }
        withAnimation(.easeOut(duration: 0.38).delay(0.2)) {
            xpBurstOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            showXPBurst = false
        }
    }
}
