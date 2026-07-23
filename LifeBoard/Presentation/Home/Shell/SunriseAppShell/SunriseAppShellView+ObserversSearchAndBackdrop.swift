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
    func applyHomeStateObservers(to content: AnyView) -> AnyView {
        let withActiveFace = AnyView(
            content.onChange(of: activeFace) { _, newValue in
                forcedFace?.wrappedValue = newValue
                if newValue == .search {
                    hasMountedSearchSurface = true
                } else if newValue == .analytics {
                    hasMountedAnalyticsSurface = true
                }
                if newValue != .chat {
                    chatNavigationChromeState = .empty
                }
                if newValue != .search {
                    isSearchFieldFocused = false
                    cancelPendingSearchCommit()
                } else {
                    searchDraftQuery = searchState.query
                }
            }
        )

        let withSearchState = AnyView(
            withActiveFace
                .onChange(of: searchSurfaceState) { _, newValue in
                    switch newValue {
                    case .idle:
                        hasAutoFocusedSearchField = false
                        isSearchFieldFocused = false
                        cancelPendingSearchCommit()
                        searchDraftQuery = searchState.query
                        searchState.deactivate()
                    case .presenting, .preparing:
                        isSearchFieldFocused = false
                    case .ready:
                        guard activeFace == .search else { return }
                        hasAutoFocusedSearchField = false
                    }
                }
                .onChange(of: searchState.query) { _, newValue in
                    guard newValue != searchDraftQuery else { return }
                    guard isSearchFieldFocused == false else { return }
                    searchDraftQuery = newValue
                }
                .onChange(of: overlaySnapshot.guidanceState) { _, state in
                    guard state != nil, activeFace != .tasks else { return }
                    setActiveFace(.tasks, animated: true)
                }
                .onChange(of: agendaTailExpansionResetKey) { _, _ in
                    expandedAgendaTailItemIDs.removeAll()
                }
        )

        return AnyView(
            withSearchState
                .onChange(of: forcedFaceValue) { _, newValue in
                    guard let newValue, newValue != activeFace else { return }
                    setActiveFace(newValue, animated: true)
                }
                .onChange(of: chromeSnapshot.selectedDate) { _, newValue in
                    timelineViewModel.syncSelectedDate(newValue)
                }
                .onReceive(overlayStore.$snapshot.map(\.lastXPResult).receive(on: RunLoop.main)) { result in
                    handleXPResult(result)
                }
        )
    }

    func applyHabitPresentationRouting<Content: View>(to content: Content) -> some View {
        content
            .sheet(isPresented: $showHabitBoardPresented) {
                HabitBoardScreen(
                    viewModel: PresentationDependencyContainer.shared.makeHabitBoardViewModel(),
                    onManageHabits: {
                        showHabitBoardPresented = false
                        DispatchQueue.main.async { showHabitLibraryPresented = true }
                    }
                )
            }
            .sheet(isPresented: $showHabitLibraryPresented) {
                SunriseHabitLibraryView(
                    viewModel: PresentationDependencyContainer.shared.makeNewHabitLibraryViewModel()
                )
            }
            .sheet(isPresented: $showHomeAddHabitPresented) {
                SunriseAddHabitSheetView(
                    viewModel: homeHabitComposerViewModel,
                    onHabitCreated: { _ in
                        showHomeAddHabitPresented = false
                        viewModel.refreshCurrentScopeContent(source: "home_add_habit_created")
                    },
                    onDismissWithoutHabit: {
                        showHomeAddHabitPresented = false
                    }
                )
            }
            .sheet(item: $selectedHomeHabitRow) { row in
                SunriseHabitDetailScreen(
                    viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                    onMutation: {
                        viewModel.refreshCurrentScopeContent(source: "habit_detail_sheet_mutation")
                    }
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .lifeboardPresentHabitBoard)) { _ in
                presentHabitBoardFromDeepLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lifeboardPresentHabitLibrary)) { _ in
                presentHabitLibraryFromDeepLink()
            }
            .onReceive(NotificationCenter.default.publisher(for: .lifeboardPresentHabitDetail)) { notification in
                guard let rawHabitID = notification.userInfo?["habitID"] as? String,
                      let habitID = UUID(uuidString: rawHabitID) else {
                    return
                }
                presentHabitDetailFromDeepLink(habitID: habitID)
            }
            .onChange(of: habitsSnapshot.errorMessage) { _, message in
                guard let message, message.isEmpty == false else { return }
                snackbar = SnackbarData(
                    message: message,
                    actions: [
                        SnackbarAction(title: "Open board") {
                            showHabitBoardPresented = true
                        }
                    ]
                )
                viewModel.clearHabitMutationErrorMessage()
            }
            .onReceive(viewModel.$habitMutationFeedback.compactMap { $0 }) { feedback in
                snackbar = SnackbarData(id: feedback.id, message: feedback.message, autoDismissSeconds: 2)
                playHabitMutationFeedbackHaptic(feedback.haptic)
                viewModel.consumeHabitMutationFeedback(id: feedback.id)
            }
    }

    /// Executes triggerSunriseHintIfEligible.

    func triggerSunriseHintIfEligible(now: Date = Date()) {
        guard isSunriseHintAnimationEnabled else {
            cancelSunriseHintAnimation()
            return
        }
        if layoutClass.isPad && V2FeatureFlags.iPadPerfHomeAnimationTrimV3Enabled {
            logWarning(
                event: "ipadSunriseHintSuppressed",
                message: "Suppressed decorative sunrise hint animation on iPad"
            )
            return
        }

        let canTrigger = HomeSunriseHintEligibility.canTrigger(
            isHomeVisible: isHomeVisible && shellPhase == .interactive,
            sunriseAnchor: sunriseAnchorForHint,
            reduceMotionEnabled: reduceMotion,
            isUITesting: isUITesting,
            hasRunningAnimation: hintAnimationTask != nil,
            lastTriggerDate: lastHintTriggerAt,
            now: now
        )
        guard canTrigger else { return }

        startSunriseHintAnimation(triggeredAt: now)
    }

    /// Executes startSunriseHintAnimation.

    func startSunriseHintAnimation(triggeredAt timestamp: Date) {
        cancelSunriseHintAnimation()
        lastHintTriggerAt = timestamp

        hintAnimationTask = _Concurrency.Task { @MainActor in
            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.sunriseHintLaunchDelay.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(.easeOut(duration: Self.sunriseHintPeekDuration)) {
                sunriseHintOffset = Self.sunriseHintPeekDistance
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.sunriseHintPeekDuration.nanoseconds)
            } catch {
                return
            }
            guard !_Concurrency.Task.isCancelled else { return }

            withAnimation(
                .spring(
                    response: Self.sunriseHintReturnResponse,
                    dampingFraction: Self.sunriseHintReturnDampingFraction
                )
            ) {
                sunriseHintOffset = 0
            }

            do {
                try await _Concurrency.Task.sleep(nanoseconds: Self.sunriseHintSettleDuration.nanoseconds)
            } catch {
                return
            }

            hintAnimationTask = nil
        }
    }

    /// Executes cancelSunriseHintAnimation.

    func cancelSunriseHintAnimation() {
        hintAnimationTask?.cancel()
        hintAnimationTask = nil
        sunriseHintOffset = 0
    }

    func scheduleSearchCommit(for newValue: String) {
        pendingSearchCommitTask?.cancel()
        let pendingValue = newValue
        pendingSearchCommitTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: Self.searchCommitDebounceNanoseconds)
            } catch {
                pendingSearchCommitTask = nil
                return
            }
            guard !Task.isCancelled else { return }
            commitDraftSearchQuery(pendingValue)
            pendingSearchCommitTask = nil
        }
    }

    func commitDraftSearchQueryImmediately() {
        cancelPendingSearchCommit()
        commitDraftSearchQuery(searchDraftQuery)
    }

    func commitDraftSearchQuery(_ newValue: String) {
        let committedQuery = searchState.trimmedQuery
        let nextCommittedQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard committedQuery != nextCommittedQuery else { return }
        LifeBoardPerformanceTrace.event("HomeSearchQueryCommitted")
        searchState.updateQuery(newValue)
        searchState.submitCurrentQuery()
    }

    func runSearchSuggestedCommand(_ command: HomeSearchSuggestedCommand) {
        cancelPendingSearchCommit()
        searchDraftQuery = ""
        let result = HomeSearchCommandResultBuilder.build(
            command: command,
            tasksSnapshot: tasksSnapshot,
            habitsSnapshot: habitsSnapshot,
            calendarSnapshot: calendarSnapshot
        )
        searchState.runSuggestedCommand(result)
        trackSearchChipToggled(kind: "suggested_command", value: command.rawValue, isSelected: true)
    }

    func cancelPendingSearchCommit() {
        pendingSearchCommitTask?.cancel()
        pendingSearchCommitTask = nil
    }

    /// Executes backdropLayer.

    func backdropLayer() -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.clear)
                .frame(height: max(480, layoutMetrics.height * 0.65))
                .overlay(alignment: .topLeading) {
                    TimelineBackdropWeekView(
                        snapshot: timelineSnapshot,
                        onSelectDate: { date in
                            timelineViewModel.syncSelectedDate(date)
                            viewModel.selectDate(date, source: .weekStrip)
                            withAnimation(sunriseFlipAnimation) {
                                timelineViewModel.snap(to: .collapsed)
                            }
                        },
                        onStartReplanForDate: { date in
                            viewModel.openNeedsReplanLauncher(for: date)
                        },
                        onPlaceReplanAllDay: { candidate, date in
                            timelineViewModel.syncSelectedDate(date)
                            viewModel.selectDate(date, source: .replan)
                            LifeBoardFeedback.success()
                            viewModel.placeReplanCandidateAllDay(taskID: candidate.taskID, on: date)
                            snackbar = SnackbarData(
                                message: "Added to \(date.formatted(.dateTime.weekday(.abbreviated).month().day()))",
                                actions: [
                                    SnackbarAction(title: "Undo") {
                                        viewModel.undoLastReplanAction()
                                    }
                                ],
                                autoDismissSeconds: 3
                            )
                        }
                    )
                    .padding(.horizontal, spacing.s16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isBackFaceVisible ? 0.001 : 1)
                    .allowsHitTesting(!isBackFaceVisible)
                    .accessibilityHidden(isBackFaceVisible)
                }
            Spacer(minLength: 0)
        }
    }

    /// Executes sunriseLayer.

    func sunriseLayer(taskListBottomInset: CGFloat) -> some View {
        ZStack {
            persistentFace(.tasks) {
                sunriseFrontFace(taskListBottomInset: taskListBottomInset)
            }

            if hasMountedAnalyticsSurface || activeFace == .analytics {
                persistentFace(.analytics) {
                    sunriseAnalyticsFace()
                }
            }

            if hasMountedSearchSurface || activeFace == .search {
                persistentFace(.search) {
                    sunriseSearchFace(taskListBottomInset: taskListBottomInset)
                }
            }

            if activeFace == .chat {
                persistentFace(.chat) {
                    sunriseChatFace()
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .top
        )
        .modifier(HomeDenseSurfaceModifier(cornerRadius: sunriseSurfaceCornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.sunrise.surface")
        .accessibilityValue(activeFace == .tasks ? timelineViewModel.sunriseAnchor.accessibilityValue : activeFace.surfaceAccessibilityValue)
        .animation(sunriseFlipAnimation, value: activeFace)
    }

    func persistentFace<Content: View>(
        _ face: HomeSunriseFace,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isVisible = activeFace == face
        return content()
            .opacity(isVisible ? 1 : 0.001)
            .offset(x: isVisible ? 0 : (layoutClass.isPad ? 0 : (face == .tasks ? 0 : 10)))
            .allowsHitTesting(isVisible)
            .accessibilityHidden(!isVisible)
            .zIndex(isVisible ? 1 : 0)
    }
}
