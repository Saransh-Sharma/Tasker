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
    @ViewBuilder
    var calendarPermissionCTA: some View {
        if shouldShowCalendarPermissionCTA {
            Button(action: onRequestCalendarPermission) {
                Text(calendarPermissionButtonTitle)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard.textInverse)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color.lifeboard.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: LifeBoardTheme.CornerRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.calendar.connect")
        }
    }

    var calendarSummaryHeader: some View {
        Text(calendarSummaryLine)
            .font(.lifeboard(.bodyStrong))
            .foregroundStyle(Color.lifeboard.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("home.calendar.nextMeeting")
    }

    var calendarSummaryLine: String {
        let dateText = LifeBoardCalendarPresentation.compactDateText(for: calendarSnapshot.selectedDate)

        if let nextMeeting = calendarSnapshot.nextMeeting {
            let timeText = LifeBoardCalendarPresentation.timeRangeText(for: nextMeeting.event)
            return "\(dateText) · Next up: \(nextMeeting.event.title) · \(timeText)"
        }

        if let freeUntil = calendarSnapshot.freeUntil {
            return "\(dateText) · Next up: Clear · Free until \(freeUntil.formatted(date: .omitted, time: .shortened))"
        }

        return "\(dateText) · Next up: Clear"
    }

    var calendarCardAccessibilityLabel: String {
        let spokenLine = calendarSummaryLine.replacingOccurrences(of: " - ", with: " to ")
        return String(localized: "Open schedule, \(spokenLine)")
    }

    @ViewBuilder
    var calendarModuleBody: some View {
        switch calendarSnapshot.moduleState {
        case .permissionRequired:
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(calendarPermissionBodyText)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .accessibilityIdentifier(calendarPermissionStateAccessibilityID)
            }
            .accessibilityLabel(calendarPermissionBodyText)
            .accessibilityIdentifier("home.calendar.state.permission")
        case .noCalendarsSelected:
            Text(String(localized: "No calendars selected. Choose at least one calendar for schedule insights."))
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityIdentifier("home.calendar.state.noCalendars")
        case .allDayOnly:
            Text(String(localized: "Only all-day events are scheduled. No timed blocks for this day."))
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityIdentifier("home.calendar.state.allDayOnly")
        case .empty:
            Text(String(localized: "No events are scheduled. Use this open window for focused work."))
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .accessibilityIdentifier("home.calendar.state.empty")
        case .error(let message):
            Text(message)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.statusWarning)
                .accessibilityIdentifier("home.calendar.state.error")
        case .active:
            VStack(alignment: .leading, spacing: spacing.s8) {
                calendarTimelinePreview
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.calendar.state.active")
        }
    }

    @ViewBuilder
    var calendarTimelinePreview: some View {
        if calendarSnapshot.selectedDayTimelineEvents.isEmpty == false {
            LifeBoardCalendarTimelineView(
                date: calendarSnapshot.selectedDate,
                events: calendarSnapshot.selectedDayEvents,
                density: .compact,
                showsDateLabel: false,
                accessibilityIdentifier: "home.calendar.timelinePreview",
                accessibilityLabelText: String(localized: "Home calendar timeline preview."),
                eventAccessibilityIdentifierPrefix: "home.calendar.event",
                onSelectEvent: handleHomeCalendarEventSelection
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    var shouldShowCalendarPermissionCTA: Bool {
        guard calendarSnapshot.moduleState == .permissionRequired else { return false }
        switch calendarSnapshot.accessAction {
        case .requestPermission, .openSystemSettings:
            return true
        case .unavailable, .noneNeeded:
            return false
        }
    }

    var calendarPermissionButtonTitle: String {
        switch calendarSnapshot.accessAction {
        case .openSystemSettings:
            return String(localized: "Open Settings")
        case .requestPermission:
            return String(localized: "Allow Full Calendar Access")
        case .unavailable, .noneNeeded:
            return String(localized: "Connect")
        }
    }

    var calendarPermissionBodyText: String {
        switch calendarSnapshot.authorizationStatus {
        case .notDetermined:
            return String(localized: "Connect Calendar to surface next meetings and free windows.")
        case .denied:
            return String(localized: "Calendar access is denied by iOS. Enable LifeBoard in Settings > Privacy & Security > Calendars. If LifeBoard is missing, restart your device, reinstall LifeBoard, or reset Location & Privacy.")
        case .restricted:
            return String(localized: "Calendar access is restricted by system policy.")
        case .writeOnly:
            return String(localized: "LifeBoard has write-only access. Allow full calendar access so schedule events can appear.")
        case .authorized:
            return String(localized: "Connect Calendar to surface next meetings and free windows.")
        }
    }

    var calendarPermissionStateAccessibilityID: String {
        switch calendarSnapshot.authorizationStatus {
        case .notDetermined:
            return "home.calendar.state.permission.notDetermined"
        case .denied:
            return "home.calendar.state.permission.denied"
        case .restricted:
            return "home.calendar.state.permission.restricted"
        case .writeOnly:
            return "home.calendar.state.permission.writeOnly"
        case .authorized:
            return "home.calendar.state.permission"
        }
    }

    func handleHomeCalendarEventSelection(_ event: LifeBoardCalendarEventSnapshot) {
        handleHomeCalendarEventSelection(eventID: event.id, allowsTimelineHide: false)
    }

    func handleHomeCalendarEventSelection(eventID: String, allowsTimelineHide: Bool) {
        suppressNextCalendarScheduleOpen = true
        selectedHomeCalendarEventDetail = HomeCalendarEventDetailSelection(
            eventID: eventID,
            selectedDate: viewModel.selectedDate,
            allowsTimelineHide: allowsTimelineHide
        )
        Task { @MainActor in
            suppressNextCalendarScheduleOpen = false
        }
    }

    func handleOpenScheduleAction() {
        if suppressNextCalendarScheduleOpen {
            suppressNextCalendarScheduleOpen = false
            return
        }
        onOpenCalendarSchedule()
    }

    var weeklySummaryCard: some View {
        HomeWeeklySummaryCard(
            summary: chromeSnapshot.weeklySummary,
            isLoading: chromeSnapshot.weeklySummaryIsLoading,
            errorMessage: chromeSnapshot.weeklySummaryErrorMessage,
            onPrimaryAction: {
                guard let summary = chromeSnapshot.weeklySummary else { return }
                switch summary.ctaState {
                case .planThisWeek, .planUpcomingWeek:
                    onOpenWeeklyPlanner()
                case .reviewWeek:
                    onOpenWeeklyReview()
                }
            },
            onRetryAction: onRetryWeeklySummary
        )
        .accessibilityIdentifier("home.weeklySummary.card")
    }

    var taskListFooterContent: AnyView? {
        guard tasksSnapshot.activeQuickView != .today else { return nil }
        return AnyView(
            persistentReplanDayEntry
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
        )
    }

    var timelineFooterModules: AnyView? {
        guard tasksSnapshot.activeQuickView == .today else { return nil }

        let hasWeeklySummary = chromeSnapshot.weeklySummary != nil
            || chromeSnapshot.weeklySummaryIsLoading
            || chromeSnapshot.weeklySummaryErrorMessage != nil
        let hasPrimaryHabits = habitsSnapshot.habitHomeSectionState.primaryRows.isEmpty == false
        let hasRecoveryHabits = habitsSnapshot.habitHomeSectionState.recoveryRows.isEmpty == false

        guard hasWeeklySummary || hasPrimaryHabits || hasRecoveryHabits else { return nil }

        return AnyView(
            VStack(alignment: .leading, spacing: spacing.s12) {
                if hasPrimaryHabits {
                    habitsSectionCard
                }

                if hasRecoveryHabits {
                    recoveryHabitsSectionCard
                }

                if hasWeeklySummary {
                    weeklySummaryCard
                }
            }
        )
    }

    var persistentReplanDayEntry: some View {
        let summary = overlaySnapshot.replanState.persistentSummary
        return NeedsReplanTrayView(
            title: summary.persistentTitle,
            subtitle: summary.persistentSubtitle,
            callToAction: summary.persistentCallToAction,
            accessibilityHint: "Opens Replan Day.",
            accessibilityIdentifier: "home.replanDay.entry",
            isProminent: false
        ) {
            viewModel.openNeedsReplanLauncher()
        }
    }

    var shouldShowDueTodayAgenda: Bool {
        chromeSnapshot.activeScope.quickView == .today && tasksSnapshot.dueTodaySection?.rows.isEmpty == false
    }

    @ViewBuilder
    var rootTimelineRescueLauncher: some View {
        if isTodayTimelineVisible,
           isRescueEnabled,
           let item = visibleAgendaTailItems.first,
           case .rescue(let state) = item {
            HStack {
                Button {
                    viewModel.openRescue()
                } label: {
                    HStack(spacing: spacing.s8) {
                        Image(systemName: "lifepreserver")
                            .font(.system(size: 13, weight: .semibold))
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(localized: "Rescue"))
                                .font(.lifeboard(.caption1).weight(.semibold))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                            Text(state.subtitle)
                                .font(.lifeboard(.caption2))
                                .foregroundStyle(Color.lifeboard.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, spacing.s8)
                    .padding(.horizontal, spacing.s12)
                    .background(Color.lifeboard.surfacePrimary.opacity(0.96))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.lifeboard.strokeHairline.opacity(0.65), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Rescue")
                .accessibilityValue(state.subtitle)
                .accessibilityIdentifier("home.rescue.open")
                .contentShape(Rectangle())
            }
            .padding(.top, layoutMetrics.safeAreaTop + spacing.s8)
            .padding(.trailing, spacing.s16)
            .zIndex(30)
        }
    }

    var passiveTrackingRailCards: [QuietTrackingRailCardPresentation] {
        habitsSnapshot.quietTrackingSummaryState.railCards
    }

    var showsFullTimelineQuietTrackingUITestMarker: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-UI_TESTING")
            && arguments.contains("-LIFEBOARD_TEST_SEED_FULL_TIMELINE_WORKSPACE")
    }

    var shouldShowHomeDebugCountsMarker: Bool {
        Self.launchArguments.contains("-UI_TESTING")
            && Self.launchArguments.contains("-ENABLE_DEBUG_LOGGING")
    }

    var homeDebugCountsValue: String {
        [
            "quick=\(tasksSnapshot.activeQuickView.rawValue)",
            "morning=\(tasksSnapshot.morningTasks.count)",
            "evening=\(tasksSnapshot.eveningTasks.count)",
            "overdue=\(tasksSnapshot.overdueTasks.count)",
            "tail=\(tasksSnapshot.agendaTailItems.count)",
            "visibleTail=\(visibleAgendaTailItems.count)",
            "focus=\(tasksSnapshot.focusRows.count)",
            "todayRows=\(tasksSnapshot.todayAgendaSectionState.totalCount)"
        ].joined(separator: " ")
    }

    var passiveTrackingRailHorizontalInset: CGFloat {
        5
    }

    var passiveTrackingRailLayout: QuietTrackingRailLayoutSpec {
        QuietTrackingRailLayoutSpec.resolve(
            viewportWidth: passiveTrackingRailViewportWidth,
            totalCardCount: passiveTrackingRailCards.count,
            historyCellCount: passiveTrackingRailCards.map(\.historyCells.count).max() ?? 0,
            interItemSpacing: spacing.s8
        )
    }

    var passiveTrackingRail: some View {
        let layout = passiveTrackingRailLayout
        let horizontalPadding = spacing.s16 * 2

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(passiveTrackingRailCards) { card in
                    passiveTrackingRailButton(for: card, layout: layout)
                        .frame(width: layout.slotWidth, alignment: .leading)
                }
            }
            .padding(.horizontal, spacing.s16)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            max(proxy.size.width - horizontalPadding, 0)
        } action: { newWidth in
            guard abs(newWidth - passiveTrackingRailViewportWidth) > 0.5 else { return }
            passiveTrackingRailViewportWidth = newWidth
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { newHeight in
            guard abs(newHeight - measuredPassiveTrackingRailHeight) > 0.5 else { return }
            measuredPassiveTrackingRailHeight = newHeight
        }
        .accessibilityIdentifier("home.passiveTracking.rail")
    }

    func passiveTrackingRailButton(
        for card: QuietTrackingRailCardPresentation,
        layout: QuietTrackingRailLayoutSpec
    ) -> some View {
        let visibleDayCount = min(layout.visibleDayCount, card.historyCells.count)

        return Button {
            openHabitDetail(habitID: card.habitID)
        } label: {
            QuietTrackingRailStreakWidget(
                card: card,
                slotWidth: layout.slotWidth,
                visibleDayCount: visibleDayCount
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityIdentifier("home.passiveTracking.card.\(card.id)")
        .accessibilityHint("Opens habit details for \(card.title)")
    }
}
