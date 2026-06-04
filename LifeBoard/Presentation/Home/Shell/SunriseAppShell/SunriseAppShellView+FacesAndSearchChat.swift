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
    func sunriseFrontFace(taskListBottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            if tasksSnapshot.activeQuickView == .today {
                todayTimelineSurface(taskListBottomInset: taskListBottomInset)
            } else {
                SunriseTaskListView(
                    headerContent: AnyView(taskListScrollHeader),
                    footerContent: taskListFooterContent,
                    footerContentCountsAsContentForEmptyState: false,
                    morningTasks: tasksSnapshot.morningTasks,
                    eveningTasks: tasksSnapshot.eveningTasks,
                    overdueTasks: tasksSnapshot.overdueTasks,
                    inlineCompletedTasks: tasksSnapshot.inlineCompletedTasks,
                    projects: tasksSnapshot.projects,
                    lifeAreas: viewModel.lifeAreas,
                    doneTimelineTasks: tasksSnapshot.doneTimelineTasks,
                    tagNameByID: tasksSnapshot.tagNameByID,
                    activeQuickView: tasksSnapshot.activeQuickView,
                    todayXPSoFar: tasksSnapshot.todayXPSoFar,
                    isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
                    projectGroupingMode: tasksSnapshot.projectGroupingMode,
                    customProjectOrderIDs: tasksSnapshot.customProjectOrderIDs,
                    emptyStateMessage: tasksSnapshot.emptyStateMessage,
                    emptyStateActionTitle: tasksSnapshot.emptyStateActionTitle,
                    isTaskDragEnabled: false,
                    todaySections: tasksSnapshot.todayAgendaSectionState.sections,
                    agendaTailItems: visibleAgendaTailItems,
                    expandedAgendaTailItemIDs: expandedAgendaTailItemIDs,
                    layoutStyle: .edgeToEdgeHome,
                    onTaskTap: onTaskTap,
                    onToggleComplete: { task in
                        trackTaskToggle(task, source: "task_list")
                        onToggleComplete(task)
                    },
                    onDeleteTask: onDeleteTask,
                    onRescheduleTask: onRescheduleTask,
                    onPromoteTaskToFocus: { task in
                        promoteAgendaTaskToFocus(task)
                    },
                    onCompleteHabit: { habit in
                        viewModel.completeHabit(habit, source: "task_list")
                    },
                    onSkipHabit: { habit in
                        viewModel.skipHabit(habit, source: "task_list")
                    },
                    onLapseHabit: { habit in
                        viewModel.lapseHabit(habit, source: "task_list")
                    },
                    onCycleHabit: { habit in
                        performHabitRowAction(habit, source: "task_list_row_tap")
                    },
                    onOpenHabit: { habit in
                        openHabitDetail(habit)
                    },
                    onReorderCustomProjects: onReorderCustomProjects,
                    onInboxHeaderAction: shouldShowInboxTriageAction ? {
                        viewModel.openRescue()
                    } : nil,
                    inboxHeaderActionTitle: shouldShowInboxTriageAction ? "Start rescue" : nil,
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
                    onEmptyStateAction: { onAddTask(nil) },
                    onToggleAgendaTailItemExpansion: { itemID in
                        if expandedAgendaTailItemIDs.contains(itemID) {
                            expandedAgendaTailItemIDs.remove(itemID)
                        } else {
                            expandedAgendaTailItemIDs.insert(itemID)
                        }
                    },
                    onOpenRescue: isRescueEnabled ? {
                        viewModel.openRescue()
                    } : nil,
                    onTaskDragStarted: { task in
                        trackTaskDragStarted(task, source: "task_list")
                    },
                    onScrollChromeStateChange: { state in
                        updateDaySunriseSwipeChromeVisibility(for: state)
                        onTaskListScrollChromeStateChange(state)
                    },
                    onPullToSearch: {
                        openSearch(source: "task_list_pull")
                    },
                    highlightedTaskID: overlaySnapshot.guidanceState?.taskID,
                    scrollResetKey: taskListScrollResetKey,
                    bottomContentInset: taskListBottomInset
                )
                .padding(.top, spacing.s4)
                .onDrop(of: ["public.text"], isTargeted: nil, perform: handleListDrop)
                .accessibilityIdentifier("home.list.dropzone")
            }
        }
    }

    func sunriseScheduleSurface() -> some View {
        ZStack {
            if let calendarIntegrationService {
                SunriseScheduleScreen(
                    service: calendarIntegrationService,
                    weekStartsOn: calendarIntegrationService.weekStartsOn,
                    presentationMode: .embedded,
                    selectedDate: Binding(
                        get: { viewModel.selectedDate },
                        set: { date in
                            viewModel.selectDate(date, source: .datePicker)
                        }
                    ),
                    bottomInset: layoutMetrics.taskListBottomInset
                )
            } else {
                Text("Schedule unavailable")
                    .font(.lifeboard(.body))
                    .foregroundColor(Color.lifeboard.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .coordinateSpace(name: Self.daySunriseSwipeCoordinateSpaceName)
    }

    func sunriseAnalyticsFace() -> some View {
        Group {
            if let insightsViewModel = faceCoordinator.insightsViewModel,
               analyticsSurfaceState == .ready {
                InsightsTabView(
                    viewModel: insightsViewModel,
                    homeProgress: chromeSnapshot.progressState,
                    homeCompletionRate: chromeSnapshot.completionRate,
                    reflectionEligible: false,
                    dailyReflectionEntryState: chromeSnapshot.dailyReflectionEntryState,
                    momentumGuidanceText: momentumGuidanceText,
                    animateMomentumCard: shellPhase == .interactive && !reduceMotion,
                    onOpenReflection: {
                        openDailyReflectPlan()
                    },
                    onPerformInsightAction: { intent in
                        performInsightAction(intent)
                    },
                    bottomInset: layoutMetrics.taskListBottomInset,
                    topContentInset: secondaryFaceTopContentInset,
                    onBackToTasks: {
                        onReturnToTasks("back_chip")
                    },
                    onOpenSettings: {
                        onOpenSettings()
                    }
                )
            } else {
                SunriseDestinationScaffold(
                    title: "Insights",
                    subtitle: "Your progress at a glance.",
                    headerSymbolName: "chart.bar.xaxis",
                    leadingSystemImage: "line.3.horizontal",
                    leadingAccessibilityLabel: "Back to tasks",
                    leadingAccessibilityIdentifier: "home.sunrise.collapseHint",
                    leadingAction: { onReturnToTasks("back_chip") },
                    trailingSystemImage: "gearshape",
                    trailingAccessibilityLabel: "Settings",
                    trailingAction: { onOpenSettings() },
                    topContentInset: secondaryFaceTopContentInset
                ) {
                    VStack(spacing: spacing.s8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text(analyticsSurfaceState == .placeholder ? "Opening insights…" : "Loading insights…")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(LBColorTokens.navyMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    func presentHabitBoardIfRequestedForUITests() {
        guard shouldPresentHabitBoardForUITests else { return }
        let hasVisibleHabits =
            habitsSnapshot.habitHomeSectionState.primaryRows.isEmpty == false
            || habitsSnapshot.habitHomeSectionState.recoveryRows.isEmpty == false
        guard hasVisibleHabits else { return }
        guard hasPresentedUITestHabitBoard == false, showHabitBoardPresented == false else { return }
        guard isSchedulingUITestHabitBoardPresentation == false else { return }
        isSchedulingUITestHabitBoardPresentation = true

        Task { @MainActor in
            setActiveFace(.tasks, animated: false)
            await Task.yield()
            await Task.yield()
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard showHabitBoardPresented == false else {
                isSchedulingUITestHabitBoardPresentation = false
                return
            }
            showHabitBoardPresented = true
            hasPresentedUITestHabitBoard = true
            isSchedulingUITestHabitBoardPresentation = false
        }
    }

    func sunriseSearchFace(taskListBottomInset: CGFloat) -> some View {
        let effectiveSearchBottomInset = max(
            taskListBottomInset,
            layoutMetrics.keyboardOverlapHeight + spacing.s16
        )

        return SunriseSearchFaceView(
            query: $searchDraftQuery,
            commandMode: Binding(
                get: { searchState.commandMode },
                set: { searchState.setCommandMode($0) }
            ),
            isFocused: $isSearchFieldFocused,
            bottomInset: effectiveSearchBottomInset,
            topContentInset: secondaryFaceTopContentInset,
            quickChips: searchQuickChipDescriptors,
            advancedStatusChips: searchStatusChipDescriptors,
            advancedPriorityChips: searchPriorityChipDescriptors,
            advancedProjectChips: searchProjectChipDescriptors,
            recentSearches: searchState.recentSearches,
            activeFilterCount: searchState.activeFilterCount,
            resultCount: searchState.activeSuggestedCommandResult?.resultCount ?? searchState.sections.reduce(0) { $0 + $1.tasks.count },
            isLoading: isSearchLoadingContentVisible,
            loadingMessage: searchLoadingMessage,
            showsNoResults: searchState.shouldShowNoResultsMessage,
            hasActiveSuggestedCommand: searchState.hasActiveSuggestedCommand,
            emptyTitle: searchState.emptyStateTitle,
            emptySubtitle: searchState.emptyStateSubtitle,
            emptyPrimaryTitle: searchState.emptyPrimaryTitle,
            hasActiveFilters: searchState.hasActiveFilters,
            onBack: {
                onReturnToTasks("back_chip")
            },
            onQueryChanged: { newValue in
                trackSearchQueryChanged(newValue)
                scheduleSearchCommit(for: newValue)
            },
            onSubmit: {
                commitDraftSearchQueryImmediately()
            },
            onClear: {
                cancelPendingSearchCommit()
                searchDraftQuery = ""
                searchState.clearQuery()
                trackSearchQueryChanged("")
            },
            onClearFilters: {
                searchState.clearFilters()
            },
            onEmptyPrimaryAction: {
                if let fallbackCommand = searchState.emptyFallbackCommand {
                    runSearchSuggestedCommand(fallbackCommand)
                }
            },
            onRunSuggestedCommand: { command in
                runSearchSuggestedCommand(command)
            },
            onAskEvaPrompt: { prompt in
                searchState.recordRecentSearch(prompt)
                onOpenChat()
            }
        ) {
            searchResultsContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.view")
    }

    @ViewBuilder
    func sunriseChatFace() -> some View {
        if let container = LLMDataController.shared {
            let chatContent = ChatContainerView(
                promptFocusRequestID: faceCoordinator.chatPromptFocusRequestID,
                onNavigationChromeChange: { state in
                    chatNavigationChromeState = state
                },
                onPromptFocusChange: onChatPromptFocusChange,
                onOpenTaskDetail: { task in
                    onTaskTap(task)
                },
                onOpenHabitDetail: { habitID in
                    openHabitDetail(habitID: habitID)
                },
                onPerformDayTaskAction: onPerformChatDayTaskAction,
                onPerformDayHabitAction: { action, card, completion in
                    if action == .open {
                        openHabitDetail(habitID: card.habitID)
                        completion(.success(()))
                        return
                    }
                    onPerformChatDayHabitAction(action, card, completion)
                }
            )
            .environmentObject(chatAppManager)
            .environment(LLMRuntimeCoordinator.shared.evaluator)
            .modelContainer(container)

            if layoutMetrics.keyboardOverlapHeight > 0.5 {
                chatContent
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        Color.clear
                            .frame(height: layoutMetrics.chatComposerBottomInset)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
            } else {
                chatContent
                    .padding(.bottom, layoutMetrics.chatComposerBottomInset + spacing.s16)
            }
        } else {
            LLMStoreUnavailableView()
        }
    }

    var searchFaceHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: spacing.s8) {
                Text("Search")
                    .font(.lifeboard(.headline))
                    .foregroundColor(Color.lifeboard.textPrimary)
                Spacer()
                Button {
                    onReturnToTasks("back_chip")
                } label: {
                    HStack(spacing: spacing.s4) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back to tasks")
                            .font(.lifeboard(.caption2))
                    }
                    .foregroundColor(Color.lifeboard.textQuaternary.opacity(0.92))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search.backChip")
                .accessibilityLabel("Back to tasks")
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s8)

            VStack(alignment: .leading, spacing: spacing.s8) {
                LifeBoardSearchFilterChipsView(chips: searchStatusChipDescriptors)
                LifeBoardSearchFilterChipsView(chips: searchPriorityChipDescriptors)
                if !searchProjectChipDescriptors.isEmpty {
                    LifeBoardSearchFilterChipsView(chips: searchProjectChipDescriptors)
                }
            }
            .padding(.horizontal, spacing.s12)
            .padding(.bottom, spacing.s8)

            Divider()
                .overlay(Color.lifeboard.strokeHairline)
        }
    }
}
