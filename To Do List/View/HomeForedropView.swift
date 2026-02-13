//
//  HomeForedropView.swift
//  Tasker
//
//  New SwiftUI Home shell with backdrop/foredrop pattern.
//

import SwiftUI

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

    @State private var isBackdropRevealed = false
    @State private var showFilterDropdown = false
    @State private var showAdvancedFilters = false
    @State private var showDatePicker = false
    @State private var draftDate = Date()
    @State private var lastDailyScore: Int?
    @State private var showXPBurst = false
    @State private var xpBurstValue = 0
    @State private var xpBurstOffsetY: CGFloat = 24
    @State private var xpBurstOpacity: Double = 0

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: .top) {
                    backdropLayer(geometry: geometry)

                    foredropLayer(geometry: geometry)
                        .offset(y: isBackdropRevealed ? 228 : 86)
                        .animation(TaskerAnimation.snappy, value: isBackdropRevealed)
                        .gesture(
                            DragGesture(minimumDistance: 8)
                                .onEnded { value in
                                    if value.translation.height > 40 {
                                        withAnimation(TaskerAnimation.snappy) {
                                            isBackdropRevealed = true
                                        }
                                    } else if value.translation.height < -40 {
                                        withAnimation(TaskerAnimation.snappy) {
                                            isBackdropRevealed = false
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
                .frame(height: max(320, geometry.size.height * 0.42))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        Text("Analytics")
                            .font(.tasker(.headline))
                            .foregroundColor(Color.tasker.textPrimary)

                        ChartCardsScrollView(referenceDate: viewModel.selectedDate)
                            .frame(height: 260)

                        VStack(alignment: .leading, spacing: spacing.s8) {
                            Text("Quick Actions")
                                .font(.tasker(.headline))
                                .foregroundColor(Color.tasker.textPrimary)

                            HStack(spacing: spacing.s8) {
                                launcherCard(
                                    title: "Search",
                                    systemImage: "magnifyingglass",
                                    accessibilityID: "home.launch.search",
                                    action: onOpenSearch
                                )
                                launcherCard(
                                    title: "Add Task",
                                    systemImage: "plus.circle.fill",
                                    accessibilityID: "home.launch.addTask",
                                    action: onAddTask
                                )
                                launcherCard(
                                    title: "Chat",
                                    systemImage: "bubble.left.and.bubble.right",
                                    accessibilityID: "home.launch.chat",
                                    action: onOpenChat
                                )
                            }
                        }
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s16)
                    .opacity(isBackdropRevealed ? 1 : 0.001)
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

            if !viewModel.focusTasks.isEmpty {
                focusStrip
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
                onEmptyStateAction: onAddTask
            )
            .padding(.top, spacing.s4)

            foredropBottomBar
                .padding(.horizontal, spacing.s16)
                .padding(.vertical, spacing.s12)
                .background(Color.tasker.surfacePrimary.opacity(0.98))
        }
        .frame(
            width: geometry.size.width,
            height: geometry.size.height - 58,
            alignment: .top
        )
        .background(
            RoundedRectangle(cornerRadius: corner.modal, style: .continuous)
                .fill(Color.tasker.surfacePrimary)
                .taskerElevation(.e2, cornerRadius: corner.modal, includesBorder: false)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner.modal, style: .continuous))
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

            VStack(spacing: spacing.s4) {
                ForEach(Array(viewModel.focusTasks.enumerated()), id: \.element.id) { index, task in
                    focusCard(task: task, index: index)
                }
            }
        }
        .accessibilityIdentifier("home.focus.strip")
    }

    private func focusCard(task: DomainTask, index: Int) -> some View {
        let model = TaskRowDisplayModel.from(task: task, showTypeBadge: false)

        return VStack(alignment: .leading, spacing: spacing.s4) {
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
    }

    private var filterSummary: HomeQuickFilterSummary {
        HomeQuickFilterSummary.from(
            scope: viewModel.activeScope,
            filterState: viewModel.activeFilterState,
            customDate: viewModel.selectedDate
        )
    }

    private var foredropBottomBar: some View {
        HStack(spacing: spacing.s12) {
            Button {
                withAnimation(TaskerAnimation.snappy) {
                    isBackdropRevealed.toggle()
                }
            } label: {
                Label("Charts", systemImage: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("home.foredrop.chartsToggle")

            Button {
                onOpenSearch()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)

            Button {
                onOpenChat()
            } label: {
                Label("Chat", systemImage: "bubble.left.and.bubble.right")
            }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                onAddTask()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 42, height: 42)
                    .foregroundColor(Color.tasker.accentOnPrimary)
                    .background(Color.tasker.accentPrimary)
                    .clipShape(Circle())
            }
            .accessibilityIdentifier("home.addTaskButton")
        }
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

    private func launcherCard(
        title: String,
        systemImage: String,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Image(systemName: systemImage)
                    .font(.tasker(.title3))
                    .foregroundColor(Color.tasker.accentPrimary)
                Text(title)
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s12)
            .background(
                RoundedRectangle(cornerRadius: corner.input, style: .continuous)
                    .fill(Color.tasker.surfacePrimary.opacity(0.96))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
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
