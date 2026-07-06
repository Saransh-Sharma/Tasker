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
    /// The Tasks-face Home screen. Extracted with a concrete return type so the large
    /// initializer is type-checked in isolation, keeping `homeScreenBody` within budget.
    private var tasksFaceScreen: SunriseHomeScreen {
        SunriseHomeScreen(
            chrome: chromeSnapshot,
            tasks: tasksSnapshot,
            habits: habitsSnapshot,
            calendar: calendarSnapshot,
            timeline: timelineSnapshot,
            bottomInset: layoutMetrics.taskListBottomInset,
            safeAreaTop: layoutMetrics.safeAreaTop,
            isShellInteractive: shellPhase == .interactive,
            isDaySwipeEnabled: isDaySwipeChromeAvailable,
            isDaySwipeInteractive: isDaySwipeGestureEnabled,
            onSelectQuickView: { viewModel.setQuickView($0) },
            onShowDatePicker: {
                draftDate = chromeSnapshot.selectedDate
                showDatePicker = true
            },
            onShiftSelectedDay: { dayOffset, source in
                guard dayOffset != 0 else { return }
                if source == .datePicker {
                    shiftSunriseSelectedDay(by: dayOffset)
                } else {
                    viewModel.shiftSelectedDay(byDays: dayOffset, source: source)
                }
            },
            onShowAdvancedFilters: {
                showAdvancedFilters = true
            },
            onOpenSettings: {
                onOpenSettings()
            },
            onOpenSearch: {
                openSearch(source: "sunrise_home")
            },
            onOpenChat: {
                onOpenChat()
            },
            onOpenHabitBoard: {
                showHabitBoardPresented = true
            },
            onCycleHabit: { habit in
                performHabitRowAction(habit, source: "sunrise_habits_row_tap")
            },
            onAddHabit: presentHomeAddHabitComposer,
            onAddTask: onAddTask,
            onRequestCalendarPermission: onRequestCalendarPermission,
            onOpenCalendarChooser: onOpenCalendarChooser,
            onRetryCalendar: onRetryCalendarContext,
            onTimelineItemTap: { item in
                if let eventID = item.eventID {
                    handleHomeCalendarEventSelection(eventID: eventID, allowsTimelineHide: true)
                    return
                }
                if let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) {
                    onTaskTap(task)
                }
            },
            onTimelineItemToggleComplete: { item in
                guard let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) else { return }
                trackTaskToggle(task, source: "sunrise_timeline")
                onToggleComplete(task)
            },
            onAnchorTap: onTimelineAnchorTap,
            onScrollStateChange: { state in
                updateDaySunriseSwipeChromeVisibility(for: state)
                onTaskListScrollChromeStateChange(state)
            },
            onSelectLens: { lens in
                viewModel.applyHomeLens(lens)
            },
            onManageLenses: {
                showManageLensLifeAreas = true
            },
            onStreamTaskTap: { task in
                onTaskTap(task)
            },
            onStreamTaskToggleComplete: { task in
                trackTaskToggle(task, source: "home_stream")
                onToggleComplete(task)
            },
            onDayCompassPrimary: { state in
                handleDayCompassPrimary(state)
            },
            onDayCompassSnooze: { flow in
                viewModel.snoozeDayCompass(flow)
            }
        )
    }

    var homeScreenBody: some View {
        let baseHomeScreen = ZStack {
            ZStack(alignment: .top) {
                if activeFace == .tasks {
                    tasksFaceScreen
                } else if activeFace == .schedule {
                    sunriseScheduleSurface()
                } else {
                    Color.lifeboard.bgCanvas
                        .ignoresSafeArea()

                    if shouldAttachSecondaryFaceToTop {
                        ZStack(alignment: .top) {
                            backdropLayer()

                            sunriseLayer(taskListBottomInset: layoutMetrics.taskListBottomInset)
                                .offset(y: sunriseHintOffset + sunriseInteractiveOffset)
                                .animation(sunriseFlipAnimation, value: activeFace)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(edges: .top)
                    } else {
                        VStack(spacing: 0) {
                            topNavigationBar()
                                .padding(.top, layoutMetrics.safeAreaTop + spacing.s8)
                                .accessibilityIdentifier("home.topNav.container")

                            ZStack(alignment: .top) {
                                backdropLayer()

                                sunriseLayer(taskListBottomInset: layoutMetrics.taskListBottomInset)
                                    .offset(y: sunriseHintOffset + sunriseInteractiveOffset)
                                    .animation(sunriseFlipAnimation, value: activeFace)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                    }
                }
            }

        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .accessibilityIdentifier("home.view")
        .lifeboardSnackbar($snackbar)
        .overlay(alignment: .bottom) {
            needsReplanFloatingOverlay
        }
        .overlay(alignment: .topLeading) {
            if shouldShowHomeDebugCountsMarker {
                Text(homeDebugCountsValue)
                    .font(.caption2)
                    .foregroundStyle(Color.lifeboard.textPrimary.opacity(0.01))
                    .lineLimit(1)
                    .frame(width: 240, height: 24, alignment: .leading)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Home debug counts")
                    .accessibilityValue(homeDebugCountsValue)
                    .accessibilityIdentifier("home.debug.counts")
            }
        }
        .overlay(alignment: .center) {
            rescueLauncherOverlay
        }
        .overlay {
            rescueDeckOverlay
        }
        .overlay(alignment: .top) {
            if showDatePicker {
                sunriseDatePickerDropdown
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
            }
        }
        .animation(.snappy(duration: reduceMotion || isUITesting ? 0.01 : 0.24), value: showDatePicker)
        .onPreferenceChange(TimelineHeaderHeightPreferenceKey.self) { measuredTimelineHeaderHeight = $0 }
        .onPreferenceChange(TimelineCalendarCardHeightPreferenceKey.self) { measuredCalendarCardHeight = $0 }
        .onPreferenceChange(TimelineBackdropWeekHeightPreferenceKey.self) { measuredWeekBackdropHeight = $0 }
        .onChange(of: daySunriseSwipeRestingCenterY) { _, newValue in
            resetIdleDaySunriseSwipeHandles(restingCenterY: newValue)
        }
        .onChange(of: isTodayTimelineVisible) { _, isVisible in
            guard isVisible else { return }
            resetDaySunriseSwipeChromeVisibility()
        }
        .onChange(of: isScheduleFaceVisible) { _, isVisible in
            guard isVisible else { return }
            resetDaySunriseSwipeChromeVisibility()
            resetIdleDaySunriseSwipeHandles(restingCenterY: daySunriseSwipeRestingCenterY)
        }
        .onChange(of: habitRenderSignature) { _, _ in
            HomePerformanceSignposts.endHabitMutation(activeHabitMutationInterval)
            activeHabitMutationInterval = nil
            HomePerformanceSignposts.endLastCellTap(activeLastCellTapInterval)
            activeLastCellTapInterval = nil
        }
        .confirmationDialog(
            "Replace a Focus Now item",
            isPresented: Binding(
                get: { pendingFocusPromotionTask != nil && focusReplacementOptions.isEmpty == false },
                set: { isPresented in
                    if !isPresented {
                        clearPendingFocusReplacement()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            ForEach(focusReplacementOptions, id: \.id) { focusTask in
                Button("Replace \(focusTask.title)") {
                    if let promotedTask = pendingFocusPromotionTask {
                        replaceFocusTask(promotedTask, replacing: focusTask, source: "today_agenda_replace")
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                clearPendingFocusReplacement()
            }
        } message: {
            Text("Focus Now already has 3 items. Choose which one to swap out.")
        }
        .fullScreenCover(isPresented: $showNextActionFocusTimer, onDismiss: {
            if isNextActionFocusEnding == false {
                activeNextActionFocusSession = nil
            }
        }) {
            if let session = activeNextActionFocusSession {
                SunriseFocusTimerView(
                    taskTitle: resolveTaskForFocusSession(taskID: session.taskID)?.title,
                    taskPriority: resolveTaskForFocusSession(taskID: session.taskID)?.priority.displayName,
                    targetDurationSeconds: session.targetDurationSeconds,
                    onComplete: { _ in
                        finishNextActionFocusSession(sessionID: session.id, source: activeFocusTimerSource)
                    },
                    onCancel: {
                        finishNextActionFocusSession(sessionID: session.id, source: "\(activeFocusTimerSource)_cancel")
                    }
                )
            } else {
                Color.clear
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showNextActionFocusSummary, onDismiss: {
            nextActionFocusSummaryResult = nil
        }) {
            if let result = nextActionFocusSummaryResult {
                SunriseFocusSessionSummaryView(
                    durationSeconds: result.session.durationSeconds,
                    xpAwarded: result.xpResult?.awardedXP ?? result.session.xpAwarded,
                    dailyXPSoFar: result.xpResult?.dailyXPSoFar ?? viewModel.dailyScore,
                    onDismiss: {
                        dismissNextActionFocusSummary()
                    },
                    onContinueMomentum: {
                        viewModel.setQuickView(.today)
                        dismissNextActionFocusSummary()
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAdvancedFilters) {
            SunriseAdvancedFilterSheetView(
                initialFilter: viewModel.activeFilterState.advancedFilter,
                initialShowCompletedInline: viewModel.activeFilterState.showCompletedInline,
                savedViews: chromeSnapshot.savedHomeViews,
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
        .sheet(isPresented: $showManageLensLifeAreas) {
            SunriseLensLifeAreasSheet(
                lifeAreas: viewModel.lifeAreas,
                initialPinnedIDs: viewModel.activeFilterState.pinnedLifeAreaIDs,
                onSave: { pinnedIDs in
                    viewModel.setPinnedLifeAreas(pinnedIDs)
                },
                onCreateLifeArea: { name, completion in
                    viewModel.createLifeArea(name: name, completion: completion)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedHomeCalendarEventDetail) { selection in
            HomeCalendarEventDetailSheet(
                selection: selection,
                onDismiss: {
                    selectedHomeCalendarEventDetail = nil
                },
                onHideFromTimeline: {
                    viewModel.hideCalendarEventFromTimeline(
                        eventID: selection.eventID,
                        on: selection.selectedDate
                    )
                    selectedHomeCalendarEventDetail = nil
                    snackbar = SnackbarData(message: "Hidden from Home timeline for this day.", autoDismissSeconds: 2)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.lifeboard(.bgElevated))
        }
        .onAppear {
            if let forcedFaceValue {
                setActiveFace(forcedFaceValue, animated: false)
            }
            isHomeVisible = true
            timelineViewModel.syncSelectedDate(viewModel.selectedDate)
            hasAutoFocusedSearchField = false
            searchDraftQuery = searchState.query
            hasMountedSearchSurface = activeFace == .search
            hasMountedAnalyticsSurface = activeFace == .analytics
            triggerSunriseHintIfEligible()
            presentHabitBoardIfRequestedForUITests()
        }
        .onChange(of: habitRenderSignature) { _, _ in
            presentHabitBoardIfRequestedForUITests()
        }
        .onDisappear {
            HomePerformanceSignposts.endHabitMutation(activeHabitMutationInterval)
            activeHabitMutationInterval = nil
            HomePerformanceSignposts.endLastCellTap(activeLastCellTapInterval)
            activeLastCellTapInterval = nil
            isHomeVisible = false
            cancelSunriseHintAnimation()
            cancelPendingSearchCommit()
            searchState.deactivate()
            isSearchFieldFocused = false
        }
        .overlay(alignment: .topTrailing) {
            if shouldPresentHabitBoardForUITests {
                Button {
                    showHabitBoardPresented = true
                } label: {
                    Text("Board")
                        .font(.lifeboard(.caption2).weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, layoutMetrics.safeAreaTop + spacing.s12)
                .padding(.trailing, spacing.s8)
                .contentShape(Rectangle())
                .accessibilityIdentifier("home.habits.openBoard")
                .accessibilityLabel("Open Habit Board")
                .opacity(0.16)
            }
        }

        let routedHomeScreen = AnyView(applyHabitPresentationRouting(to: baseHomeScreen))
        let observedHomeScreen = applyHomeStateObservers(to: routedHomeScreen)

        return applyObservedHomeOverlaySheets(to: observedHomeScreen)
    }

    @ViewBuilder
    private func applyObservedHomeOverlaySheets<Content: View>(to content: Content) -> some View {
        content
            .sheet(isPresented: focusWhySheetPresented) {
                SunriseEvaFocusWhySheet(
                    focusTasks: tasksSnapshot.focusTasks,
                    shuffleCandidates: viewModel.focusWhyShuffleCandidates,
                    insightProvider: { taskID in
                        viewModel.evaFocusInsight(for: taskID)
                    },
                    isStartingFocus: isNextActionFocusRequestInFlight,
                    onToggleComplete: { task in
                        trackTaskToggle(task, source: "focus_why_sheet")
                        onToggleComplete(task)
                    },
                    onStartFocus: { draftTasks, task, durationSeconds in
                        startFocusNowTimer(draftTasks: draftTasks, task: task, durationSeconds: durationSeconds)
                    },
                    onShuffleCandidates: {
                        refreshFocusWhyShuffleCandidates()
                    },
                    onReplaceFocusTask: { candidate, replacing in
                        replaceFocusTaskFromWhySheet(candidate, replacing: replacing)
                    }
                )
            }
            .sheet(isPresented: needsReplanLauncherPresented, onDismiss: {
                launchPendingNeedsReplanRescueIfNeeded()
            }) {
                NeedsReplanLauncherSheet(
                    summary: overlaySnapshot.replanState.launcherSummary ?? .empty,
                    onStart: {
                        if overlaySnapshot.replanState.launcherSummary?.count == 0 {
                            pendingRescueLaunchAfterNeedsReplanDismiss = false
                            viewModel.dismissNeedsReplanSessionUI()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onAddTask(nil)
                            }
                        } else {
                            pendingRescueLaunchAfterNeedsReplanDismiss = true
                            viewModel.dismissNeedsReplanSessionUI()
                        }
                    },
                    onLater: {
                        pendingRescueLaunchAfterNeedsReplanDismiss = false
                        viewModel.dismissNeedsReplanLater()
                    }
                )
            }
            .sheet(item: habitRecoveryReflectionPromptBinding) { prompt in
                SunriseReflectionNoteComposerView(
                    viewModel: SunriseReflectionNoteComposerViewModel(
                        title: "Recovery note",
                        kind: .habitRecovery,
                        linkedHabitID: prompt.habitID,
                        prompt: "What helped \(prompt.habitTitle) recover today?",
                        saveNoteHandler: { note, completion in
                            viewModel.saveReflectionNote(note) { result in
                                Task { @MainActor in
                                    completion(result)
                                }
                            }
                        }
                    )
                )
            }
            .sheet(isPresented: padDailyReflectPlanPresented, onDismiss: {
                dailyReflectPlanViewModel = nil
            }) {
                reflectPlanPresentation
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(isPresented: phoneDailyReflectPlanPresented, onDismiss: {
                dailyReflectPlanViewModel = nil
            }) {
                reflectPlanPresentation
            }
    }

    private var focusWhySheetPresented: Binding<Bool> {
        Binding(
            get: { overlaySnapshot.focusWhyPresented },
            set: { viewModel.setEvaFocusWhyPresented($0) }
        )
    }

    private var needsReplanLauncherPresented: Binding<Bool> {
        Binding(
            get: { overlaySnapshot.replanState.launcherSummary != nil },
            set: { isPresented in
                guard isPresented == false else { return }
                guard overlaySnapshot.replanState.launcherSummary != nil else { return }
                viewModel.dismissNeedsReplanLater()
            }
        )
    }

    private func launchPendingNeedsReplanRescueIfNeeded() {
        guard pendingRescueLaunchAfterNeedsReplanDismiss else { return }
        pendingRescueLaunchAfterNeedsReplanDismiss = false
        viewModel.openOverdueRescueFromHome(
            source: "needs_replan_start",
            action: "needs_replan_start_rescue"
        )
    }

    private var habitRecoveryReflectionPromptBinding: Binding<HabitRecoveryReflectionPrompt?> {
        Binding(
            get: { viewModel.habitRecoveryReflectionPrompt },
            set: { if $0 == nil { viewModel.clearHabitRecoveryReflectionPrompt() } }
        )
    }

    private var padDailyReflectPlanPresented: Binding<Bool> {
        Binding(
            get: { layoutClass.isPad && showDailyReflectPlan },
            set: { isPresented in
                showDailyReflectPlan = isPresented
                if isPresented == false {
                    activeDayCompassFlow = nil
                }
            }
        )
    }

    private var phoneDailyReflectPlanPresented: Binding<Bool> {
        Binding(
            get: { !layoutClass.isPad && showDailyReflectPlan },
            set: { isPresented in
                showDailyReflectPlan = isPresented
                if isPresented == false {
                    activeDayCompassFlow = nil
                }
            }
        )
    }

    func handleDayCompassPrimary(_ state: DayCompassState) {
        switch state {
        case .replan:
            viewModel.startDayCompassReplanSession()
        case .morningPlan:
            activeDayCompassFlow = .morningPlan
            openDailyReflectPlan()
        case .eveningReview:
            activeDayCompassFlow = .eveningReview
            openDailyReflectPlan()
        case .rescue:
            viewModel.startDayCompassRescueSession()
        case .inbox:
            viewModel.startDayCompassInboxSession()
        case .resumeTask(_, _, let taskID):
            viewModel.handleDayCompassResumeTask(taskID: taskID)
        case .allClear:
            // Tapping the transient confirmation dismisses it early.
            viewModel.clearDayCompassAllClear()
            viewModel.scheduleHomeRenderStateRefresh([.chrome])
        }
    }
}
