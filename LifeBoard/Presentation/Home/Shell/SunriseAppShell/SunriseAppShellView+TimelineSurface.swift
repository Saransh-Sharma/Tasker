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
    func todayTimelineSurface(taskListBottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            SunriseTimelineBar(
                onSnapAnchor: { anchor in
                    withAnimation(sunriseFlipAnimation) {
                        timelineViewModel.snap(to: anchor)
                    }
                },
                onDragChanged: { translation in
                    timelineViewModel.updateDrag(translation, metrics: timelineLayoutMetrics)
                },
                onDragEnded: { translation in
                    timelineViewModel.endDrag(predictedTranslation: translation, metrics: timelineLayoutMetrics)
                }
            )
            .reportHeight(to: TimelineHeaderHeightPreferenceKey.self)
            .padding(.horizontal, spacing.s16)

            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: spacing.s12) {
                        if showsFullTimelineQuietTrackingUITestMarker {
                            Text("Quiet tracking seeded")
                                .font(.caption2)
                                .foregroundStyle(Color.lifeboard.textPrimary.opacity(0.01))
                                .lineLimit(1)
                                .frame(width: 1, height: 1)
                                .clipped()
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Quiet tracking seeded")
                                .accessibilityIdentifier("home.passiveTracking.rail")
                        }

                        if habitsSnapshot.quietTrackingSummaryState.isVisible {
                            passiveTrackingRail
                                .padding(.horizontal, passiveTrackingRailHorizontalInset)
                        }

                        if case .trayVisible(let summary) = overlaySnapshot.replanState.phase {
                            timelineColumnContent {
                                NeedsReplanTrayView(
                                    title: summary.title,
                                    subtitle: summary.subtitle,
                                    callToAction: summary.callToAction,
                                    accessibilityHint: "Opens Plan the Day.",
                                    accessibilityIdentifier: "home.needsReplan.tray",
                                    isProminent: true
                                ) {
                                    viewModel.openNeedsReplanLauncher()
                                }
                                .padding(.horizontal, spacing.s16)
                                .onGeometryChange(for: CGFloat.self) { proxy in
                                    proxy.size.height
                                } action: { newHeight in
                                    guard abs(newHeight - measuredNeedsReplanTrayHeight) > 0.5 else { return }
                                    measuredNeedsReplanTrayHeight = newHeight
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        timelineRescueTail

                        timelineColumnContent {
                            let snapshot = timelineSnapshot
                            let selectedDayKey = Int(Calendar.current.startOfDay(for: snapshot.selectedDate).timeIntervalSince1970)
                            SunriseTimelineSurface(
                                snapshot: snapshot,
                                layoutClass: layoutClass,
                                showsRevealHandle: false,
                                hasNextHomeWidget: timelineHasNextHomeWidget,
                                onSelectDate: { date in
                                    timelineViewModel.syncSelectedDate(date)
                                    viewModel.selectDate(date, source: .weekStrip)
                                },
                                onSnapAnchor: { anchor in
                                    withAnimation(sunriseFlipAnimation) {
                                        timelineViewModel.snap(to: anchor)
                                    }
                                },
                                onDragChanged: { translation in
                                    timelineViewModel.updateDrag(translation, metrics: timelineLayoutMetrics)
                                },
                                onDragEnded: { translation in
                                    timelineViewModel.endDrag(predictedTranslation: translation, metrics: timelineLayoutMetrics)
                                },
                                onTaskTap: { item in
                                    if let eventID = item.eventID {
                                        handleHomeCalendarEventSelection(eventID: eventID, allowsTimelineHide: true)
                                        return
                                    }
                                    if let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) {
                                        onTaskTap(task)
                                    }
                                },
                                onToggleComplete: { item in
                                    guard let taskID = item.taskID, let task = viewModel.taskSnapshot(for: taskID) else { return }
                                    trackTaskToggle(task, source: "timeline")
                                    onToggleComplete(task)
                                },
                                onAnchorTap: onTimelineAnchorTap,
                                onAddTask: onAddTask,
                                onScheduleInbox: {
                                    viewModel.openRescue()
                                },
                                onShowCalendarInTimeline: {
                                    viewModel.showCalendarEventsInTimelineFromHome()
                                },
                                onPlaceReplanAtTime: { candidate, date in
                                    LifeBoardFeedback.success()
                                    viewModel.placeReplanCandidate(taskID: candidate.taskID, at: date)
                                    snackbar = SnackbarData(
                                        message: "Scheduled for \(date.formatted(date: .omitted, time: .shortened))",
                                        actions: [
                                            SnackbarAction(title: "Undo") {
                                                viewModel.undoLastReplanAction()
                                            }
                                        ],
                                        autoDismissSeconds: 3
                                    )
                                },
                                onPlaceReplanAllDay: { candidate, date in
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
                                },
                                onCancelReplanPlacement: {
                                    viewModel.cancelCurrentReplanPlacement()
                                },
                                onSkipReplanPlacement: {
                                    viewModel.skipCurrentReplanCandidate()
                                },
                                onClearReplanError: {
                                    viewModel.clearReplanError()
                                }
                            )
                            .id(selectedDayKey)
                            .transition(daySwipeTransition)
                            .animation(daySwipeAnimation, value: selectedDayKey)
                            .padding(.horizontal, spacing.s16)
                            .accessibilityAction(named: Text("Previous Day")) {
                                beginDaySwipeTrace()
                                commitDaySwipe(.previous)
                            }
                            .accessibilityAction(named: Text("Next Day")) {
                                beginDaySwipeTrace()
                                commitDaySwipe(.next)
                            }
                        }

                        if let entryState = chromeSnapshot.dailyReflectionEntryState {
                            timelineColumnContent {
                                HomeDailyReflectionEntryCard(
                                    state: entryState,
                                    mode: .compact
                                ) {
                                    openDailyReflectPlan(preferredReflectionDate: entryState.reflectionDate)
                                }
                                .padding(.horizontal, spacing.s16)
                            }
                        }

                        if let footerContent = timelineFooterModules {
                            footerContent
                        }

                        if let guidanceState = overlaySnapshot.guidanceState {
                            HomeOnboardingGuidanceBanner(state: guidanceState)
                                .padding(.horizontal, spacing.s16)
                        }

                        timelineColumnContent {
                            persistentReplanDayEntry
                                .padding(.horizontal, spacing.s16)
                        }

                        timelineBottomContentSpacer(taskListBottomInset: taskListBottomInset)
                    }
                    .padding(.top, spacing.s8)
                    .contentShape(Rectangle())
                    .lifeboardScrollOptimizedRendering()
                    .background {
                        SunriseDaySwipeGestureSurface(
                            isEnabled: isDaySwipeInteractionEnabled,
                            containerSize: daySunriseSwipeContainerSize,
                            restingCenterY: daySunriseSwipeRestingCenterY,
                            resolver: .default,
                            onInteractionStarted: beginDaySwipeTrace,
                            onChanged: { side, translation, location in
                                updateDaySunriseSwipe(
                                    side: side,
                                    translation: translation,
                                    location: location,
                                    size: daySunriseSwipeContainerSize
                                )
                            },
                            onEnded: { side, translation, predictedEndTranslation, _ in
                                endDaySunriseSwipe(
                                    side: side,
                                    translation: translation,
                                    predictedEndTranslation: predictedEndTranslation,
                                    size: daySunriseSwipeContainerSize
                                )
                            },
                            onCancelled: { side in
                                cancelDaySunriseSwipe(
                                    side: side,
                                    size: daySunriseSwipeContainerSize
                                )
                            }
                        )
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    }
                }
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(
                    for: CGFloat.self,
                    of: { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    },
                    action: { _, newOffset in
                        handleTimelineScrollOffsetChange(max(0, newOffset))
                    }
                )

                if visibleAgendaTailItems.isEmpty == false {
                    pinnedTimelineRescueLauncher
                        .zIndex(6)
                }

                if activeFace != .tasks {
                    daySunriseSwipeOverlay
                }
            }
            .coordinateSpace(name: Self.daySunriseSwipeCoordinateSpaceName)
        }
        .accessibilityIdentifier("home.timeline.surface")
    }

    @ViewBuilder
    var timelineRescueTail: some View {
        if isRescueEnabled {
            ForEach(visibleAgendaTailItems) { item in
                switch item {
                case .rescue(let state):
                    timelineColumnContent {
                        timelineRescueTailItem(state)
                            .padding(.horizontal, spacing.s16)
                    }
                }
            }
        }
    }

    @ViewBuilder
    var pinnedTimelineRescueLauncher: some View {
        if isRescueEnabled,
           let item = visibleAgendaTailItems.first,
           case .rescue(let state) = item {
            VStack(spacing: 0) {
                timelineColumnContent {
                    timelineRescueTailItem(state)
                        .padding(.horizontal, spacing.s16)
                }
                .padding(.top, spacing.s8)
                .background(Color.lifeboard.surfacePrimary.opacity(0.96))

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(true)
        }
    }

    func timelineRescueTailItem(_ state: RescueTailState) -> some View {
        HStack(alignment: .center, spacing: spacing.s12) {
            Button {
                viewModel.openRescue()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Rescue"))
                        .font(.lifeboard(.headline))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .accessibilityIdentifier("home.rescue.header")

                    Text(state.subtitle)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.rescue.open")

            if state.mode == .expanded {
                Button(String(localized: "Start rescue")) {
                    viewModel.openRescue()
                }
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.rescue.start")
            }
        }
        .padding(.vertical, spacing.s12)
        .padding(.horizontal, spacing.s16)
        .background(Color.lifeboard.surfaceSecondary.opacity(0.22))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.lifeboard.strokeHairline.opacity(0.55), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .accessibilityIdentifier("home.rescue.section")
    }

    var daySunriseSwipeOverlay: some View {
        SunriseDaySwipeOverlay(
            isEnabled: isDaySwipeGestureEnabled,
            isChromeVisible: isDaySunriseSwipeChromeVisible,
            reduceMotion: reduceMotion || isUITesting,
            restingCenterY: daySunriseSwipeRestingCenterY,
            onInteractionStarted: beginDaySwipeTrace,
            onInteractionCancelled: cancelDaySwipeTraceIfNeeded,
            onCommit: commitDaySwipe,
            onHandleDragChanged: { side, translation, location, size in
                updateDaySunriseSwipe(
                    side: side,
                    translation: translation,
                    location: location,
                    size: size
                )
            },
            onHandleDragEnded: { side, translation, predictedEndTranslation, _, size in
                endDaySunriseSwipe(
                    side: side,
                    translation: translation,
                    predictedEndTranslation: predictedEndTranslation,
                    size: size
                )
            },
            leadingData: $leadingDaySunriseSwipeData,
            trailingData: $trailingDaySunriseSwipeData,
            topSide: $topDaySunriseSwipeSide
        )
    }

    func timelineBottomContentSpacer(taskListBottomInset: CGFloat) -> some View {
        Color.clear
            .frame(height: timelineBottomContentClearance(taskListBottomInset: taskListBottomInset))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    func timelineBottomContentClearance(taskListBottomInset: CGFloat) -> CGFloat {
        HomeTimelineColumnLayout.bottomContentClearance(
            taskListBottomInset: taskListBottomInset,
            layoutClass: layoutClass,
            spacing: spacing
        )
    }

    @ViewBuilder
    var calendarScheduleModuleCard: some View {
        if calendarSnapshot.moduleState == .permissionRequired {
            calendarCardChrome {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    calendarSummaryHeader
                    calendarModuleBody
                    calendarPermissionCTA
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            calendarCardChrome {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    calendarSummaryHeader
                    calendarModuleBody
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.card, style: .continuous))
            .gesture(
                TapGesture().onEnded {
                    handleOpenScheduleAction()
                },
                including: .gesture
            )
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(calendarCardAccessibilityLabel)
            .accessibilityHint(String(localized: "Opens the full calendar schedule"))
        }
    }

    @ViewBuilder
    func calendarCardChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .modifier(CalendarCardChromeModifier())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.calendar.card")
    }
}
