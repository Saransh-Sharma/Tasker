//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

extension SunriseAppShellView {
    var todayAgendaHeader: some View {
        HStack(alignment: .center, spacing: spacing.s8) {
            Label("Today Agenda", systemImage: "list.bullet.rectangle.portrait")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
            Spacer(minLength: 0)
            Text("\(tasksSnapshot.todayAgendaSectionState.totalCount)")
                .font(.lifeboard(.caption2).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .padding(.horizontal, spacing.s8)
                .padding(.vertical, spacing.s4)
                .background(Color.lifeboard.surfaceSecondary)
                .clipShape(Capsule())
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s4)
        .accessibilityIdentifier("home.todayAgenda.header")
    }

    var habitsSectionCard: some View {
        HomeHabitSectionCardHost(
            title: "Habits",
            summaryLine: "\(habitsSnapshot.habitHomeSectionState.totalCount) active · \(habitsSnapshot.habitHomeSectionState.onStreakCount) in rhythm · \(habitsSnapshot.habitHomeSectionState.atRiskCount) need care",
            rows: habitsSnapshot.habitHomeSectionState.primaryRows,
            accessibilityIdentifier: "home.habits.section",
            onOpenBoard: { showHabitBoardPresented = true },
            onPrimaryAction: handleHabitPrimaryAction(_:),
            onSecondaryAction: handleHabitSecondaryAction(_:),
            onRowAction: handleHabitRowAction(_:),
            onLastCellAction: handleHabitLastCellAction(_:),
            onOpenHabit: openHabitDetail,
            showsAddHabitCTA: true,
            onAddHabit: presentHomeAddHabitComposer
        )
        .equatable()
    }

    var recoveryHabitsSectionCard: some View {
        HomeHabitSectionCardHost(
            title: "Recovery",
            summaryLine: "\(habitsSnapshot.habitHomeSectionState.recoveryRows.count) in recovery",
            rows: habitsSnapshot.habitHomeSectionState.recoveryRows,
            accessibilityIdentifier: "home.habits.recovery",
            onOpenBoard: { showHabitBoardPresented = true },
            onPrimaryAction: handleHabitPrimaryAction(_:),
            onSecondaryAction: handleHabitSecondaryAction(_:),
            onRowAction: handleHabitRowAction(_:),
            onLastCellAction: handleHabitLastCellAction(_:),
            onOpenHabit: openHabitDetail,
            showsAddHabitCTA: false,
            onAddHabit: nil
        )
        .equatable()
    }

    func presentHomeAddHabitComposer() {
        selectedHomeHabitRow = nil
        showHabitBoardPresented = false
        showHabitLibraryPresented = false
        homeHabitComposerViewModel.resetForm()
        showHomeAddHabitPresented = true
    }

    func handleHabitPrimaryAction(_ habit: HomeHabitRow) {
        performHabitPrimaryAction(habit, source: "habit_home")
    }

    func handleHabitSecondaryAction(_ habit: HomeHabitRow) {
        performHabitSecondaryAction(habit, source: "habit_home")
    }

    func handleHabitRowAction(_ habit: HomeHabitRow) {
        performHabitRowAction(habit, source: "habit_home_row_tap")
    }

    func handleHabitLastCellAction(_ habit: HomeHabitRow) {
        performHabitLastCellAction(habit, source: "habit_home_last_cell")
    }

    var habitDetailFallbackRows: [HomeHabitRow] {
        habitsSnapshot.habitHomeSectionState.primaryRows
        + habitsSnapshot.habitHomeSectionState.recoveryRows
        + habitsSnapshot.quietTrackingSummaryState.stableRows
    }

    func makeFallbackHabitLibraryRow(from habit: HomeHabitRow) -> HabitLibraryRow {
        HabitLibraryRow(
            habitID: habit.habitID,
            title: habit.title,
            kind: habit.kind,
            trackingMode: habit.trackingMode,
            cadence: habit.cadence,
            lifeAreaID: habit.lifeAreaID,
            lifeAreaName: habit.lifeAreaName,
            projectID: habit.projectID,
            projectName: habit.projectName,
            icon: HabitIconMetadata(symbolName: habit.iconSymbolName, categoryKey: "home_fallback"),
            colorHex: habit.accentHex,
            isPaused: false,
            isArchived: false,
            currentStreak: habit.currentStreak,
            bestStreak: habit.bestStreak,
            last14Days: habit.last14Days,
            nextDueAt: habit.dueAt,
            lastCompletedAt: nil,
            reminderWindowStart: nil,
            reminderWindowEnd: nil,
            notes: habit.helperText
        )
    }

    func openHabitDetail(_ habit: HomeHabitRow) {
        HomePerformanceSignposts.openDetailTap()
        LifeBoardPerformanceTrace.event("HabitDetailTapReceived")
        if let row = viewModel.habitLibraryRow(for: habit.habitID) {
            selectedHomeHabitRow = row
            return
        }

        // Fallback keeps detail navigation available when Home rows are ready
        // before the library cache hydrates.
        selectedHomeHabitRow = makeFallbackHabitLibraryRow(from: habit)
    }

    func openHabitDetail(habitID: UUID) {
        HomePerformanceSignposts.openDetailTap()
        LifeBoardPerformanceTrace.event("HabitDetailTapReceived")

        if let row = viewModel.habitLibraryRow(for: habitID) {
            selectedHomeHabitRow = row
            return
        }

        if let fallback = habitDetailFallbackRows.first(where: { $0.habitID == habitID }) {
            selectedHomeHabitRow = makeFallbackHabitLibraryRow(from: fallback)
            return
        }
    }

    func presentHabitBoardFromDeepLink() {
        showHomeAddHabitPresented = false
        showHabitLibraryPresented = false
        selectedHomeHabitRow = nil
        showHabitBoardPresented = true
    }

    func presentHabitLibraryFromDeepLink() {
        showHomeAddHabitPresented = false
        selectedHomeHabitRow = nil
        showHabitBoardPresented = false
        showHabitLibraryPresented = true
    }

    func presentHabitDetailFromDeepLink(habitID: UUID) {
        showHomeAddHabitPresented = false
        showHabitLibraryPresented = false
        showHabitBoardPresented = false
        selectedHomeHabitRow = nil
        if let row = viewModel.habitLibraryRow(for: habitID) {
            selectedHomeHabitRow = row
            return
        }

        if let fallback = habitDetailFallbackRows.first(where: { $0.habitID == habitID }) {
            selectedHomeHabitRow = makeFallbackHabitLibraryRow(from: fallback)
            return
        }

        snackbar = SnackbarData(message: "Couldn't find that habit. Opening Habit Board.")
        showHabitBoardPresented = true
    }

    func beginHabitMutationSignpost(trackLastCellTap: Bool = false) {
        HomePerformanceSignposts.endHabitMutation(activeHabitMutationInterval)
        activeHabitMutationInterval = HomePerformanceSignposts.beginHabitMutation()

        if trackLastCellTap {
            HomePerformanceSignposts.endLastCellTap(activeLastCellTapInterval)
            activeLastCellTapInterval = HomePerformanceSignposts.beginLastCellTap()
        }
    }

    func performHabitPrimaryAction(_ habit: HomeHabitRow, source: String) {
        beginHabitMutationSignpost()
        switch (habit.kind, habit.trackingMode) {
        case (_, .lapseOnly):
            viewModel.lapseHabit(habit, source: source)
        case (.positive, _):
            viewModel.completeHabit(habit, source: source)
        case (.negative, .dailyCheckIn):
            viewModel.completeHabit(habit, source: source)
        }
    }

    func performHabitSecondaryAction(_ habit: HomeHabitRow, source: String) {
        beginHabitMutationSignpost()
        switch (habit.kind, habit.trackingMode) {
        case (.positive, _):
            viewModel.skipHabit(habit, source: source)
        case (.negative, .dailyCheckIn):
            viewModel.lapseHabit(habit, source: source)
        case (.negative, .lapseOnly):
            break
        }
    }

    func performHabitRowAction(_ habit: HomeHabitRow, source: String) {
        LifeBoardPerformanceTrace.event("home.habitRowTap.accepted")
        HomePerformanceSignposts.lastCellTapAccepted()
        beginHabitMutationSignpost(trackLastCellTap: true)
        viewModel.performHabitLastCellAction(habit, source: source)
    }

    func performHabitLastCellAction(_ habit: HomeHabitRow, source: String) {
        HomePerformanceSignposts.lastCellTapAccepted()
        beginHabitMutationSignpost(trackLastCellTap: true)
        viewModel.performHabitLastCellAction(habit, source: source)
    }

    @ViewBuilder
    var dueTodayAgendaSection: some View {
        let rows = Array((tasksSnapshot.dueTodaySection?.rows ?? []).prefix(5))
        let hasHabitRows = rows.contains { row in
            if case .habit = row { return true }
            return false
        }

        fullBleedTaskListHeaderModule {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                    Label("Due today", systemImage: "calendar.badge.clock")
                        .font(.lifeboard(.headline))
                        .foregroundColor(Color.lifeboard.textPrimary)

                    Spacer(minLength: 0)

                    Text("\(tasksSnapshot.dueTodaySection?.rows.count ?? 0)")
                        .font(.lifeboard(.caption2).weight(.semibold))
                        .foregroundColor(Color.lifeboard.textSecondary)
                        .padding(.horizontal, spacing.s8)
                        .padding(.vertical, spacing.s4)
                        .background(Color.lifeboard.surfaceSecondary)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, spacing.s16)
                .padding(.bottom, spacing.s8)

                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        dueTodayAgendaRow(row, showTypeBadge: hasHabitRows)

                        if index < rows.count - 1 {
                            HomeTaskRowDivider()
                        }
                    }
                }
            }
            .padding(.vertical, spacing.s12)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.dueTodayAgenda.section")
        }
    }

    @ViewBuilder
    func dueTodayAgendaRow(_ row: HomeTodayRow, showTypeBadge: Bool) -> some View {
        switch row {
        case .task(let task):
            let fallbackIconSymbolName = projectIconSymbolName(for: task.projectID)
            SunriseTaskRowView(
                task: task,
                fallbackIconSymbolName: fallbackIconSymbolName,
                accentHex: HomeTaskTintResolver.rowAccentHex(
                    for: row,
                    projectsByID: tasksSnapshot.projectsByID,
                    lifeAreasByID: lifeAreasByID
                ),
                showTypeBadge: showTypeBadge,
                isInOverdueSection: task.isOverdue,
                tagNameByID: tasksSnapshot.tagNameByID,
                todayXPSoFar: tasksSnapshot.todayXPSoFar,
                isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
                isTaskDragEnabled: false,
                metadataPolicy: .homeUnifiedList,
                chromeStyle: .flatHomeList,
                onTap: { onTaskTap(task) },
                onToggleComplete: {
                    trackTaskToggle(task, source: "due_today_agenda")
                    onToggleComplete(task)
                },
                onDelete: { onDeleteTask(task) },
                onReschedule: { onRescheduleTask(task) },
                onPromoteToFocus: { promoteAgendaTaskToFocus(task) }
            )
            .equatable()

        case .habit(let habit):
            HomeHabitRowView(
                row: habit,
                onPrimaryAction: {
                    performHabitPrimaryAction(habit, source: "due_today_agenda")
                },
                onSecondaryAction: {
                    performHabitSecondaryAction(habit, source: "due_today_agenda")
                },
                onRowAction: {
                    performHabitRowAction(habit, source: "due_today_agenda_row_tap")
                },
                onOpenDetail: {
                    openHabitDetail(habit)
                },
                onLastCellAction: {
                    performHabitLastCellAction(habit, source: "due_today_agenda_last_cell")
                }
            )
        }
    }

    func projectIconSymbolName(for projectID: UUID) -> String? {
        tasksSnapshot.projectsByID[projectID]?.icon.systemImageName
    }

    var focusStrip: some View {
        SunriseFocusZone(
            rows: tasksSnapshot.focusNowSectionState.rows,
            maxVisibleRows: 3,
            canDrag: false,
            pinnedTaskIDs: tasksSnapshot.focusNowSectionState.pinnedTaskIDs,
            shellPhase: shellPhase,
            insightForTaskID: { taskID in
                viewModel.evaFocusInsight(for: taskID)
            },
            onWhy: {
                viewModel.openFocusWhy()
            },
            onPinTask: { task in
                pinFocusTask(task)
            },
            onUnpinTask: { task in
                unpinFocusTask(task)
            },
            onTaskTap: { task in
                onTaskTap(task)
            },
            onToggleComplete: { task in
                trackTaskToggle(task, source: "focus_strip")
                onToggleComplete(task)
            },
            onStartFocus: { task in
                onStartFocus(task)
            },
            onTaskDragStarted: { task in
                trackTaskDragStarted(task, source: "focus_strip")
            },
            onCompleteHabit: { habit in
                viewModel.completeHabit(habit, source: "focus_strip")
            },
            onSkipHabit: { habit in
                viewModel.skipHabit(habit, source: "focus_strip")
            },
            onLapseHabit: { habit in
                viewModel.lapseHabit(habit, source: "focus_strip")
            },
            onCycleHabit: { habit in
                performHabitRowAction(habit, source: "focus_strip_row_tap")
            },
            onOpenHabit: { habit in
                openHabitDetail(habit)
            },
            onDrop: handleFocusDrop
        )
    }

    /// Executes trackTaskToggle.

    func trackTaskToggle(_ task: TaskDefinition, source: String) {
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

    func trackTaskDragStarted(_ task: TaskDefinition, source: String) {
        var metadata = focusScopeMetadata(source: source, taskID: task.id)
        metadata["pinned_count"] = viewModel.pinnedFocusTaskIDs.count
        viewModel.trackHomeInteraction(
            action: "home_focus_drag_started",
            metadata: metadata
        )
    }

    /// Executes pinFocusTask.
}
