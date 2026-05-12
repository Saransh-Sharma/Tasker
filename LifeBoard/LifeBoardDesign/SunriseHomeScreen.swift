import SwiftUI

struct SunriseHomeScreen: View {
    let chrome: HomeChromeSnapshot
    let tasks: HomeTasksSnapshot
    let habits: HomeHabitsSnapshot
    let calendar: HomeCalendarSnapshot
    let timeline: HomeTimelineSnapshot
    let bottomInset: CGFloat
    let safeAreaTop: CGFloat
    let isShellInteractive: Bool
    let onSelectQuickView: (HomeQuickView) -> Void
    let onShowDatePicker: () -> Void
    let onShiftSelectedDay: (Int) -> Void
    let onShowAdvancedFilters: () -> Void
    let onOpenSettings: () -> Void
    let onOpenSearch: () -> Void
    let onOpenChat: () -> Void
    let onOpenHabitBoard: () -> Void
    let onAddTask: (Date?) -> Void
    let onRequestCalendarPermission: () -> Void
    let onOpenCalendarChooser: () -> Void
    let onRetryCalendar: () -> Void
    let onTimelineItemTap: (TimelinePlanItem) -> Void
    let onTimelineItemToggleComplete: (TimelinePlanItem) -> Void
    let onAnchorTap: (TimelineAnchorItem) -> Void
    let onScrollStateChange: (HomeScrollChromeState) -> Void

    @State private var isScrollActive = false
    @State private var scrollStopTask: Task<Void, Never>?
    @State private var scrollChromeStateTracker = HomeScrollChromeStateTracker()
    @State private var selectedFilterID = "all"
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .top) {
            LBColorTokens.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 0) {
                    header
                    content
                        .padding(.top, -headerContentOverlap)
                        .padding(.bottom, bottomInset + LBSpacingTokens.bottomDockClearance)
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: SunriseScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("sunriseHomeScroll")).minY)
                    }
                )
            }
            .coordinateSpace(name: "sunriseHomeScroll")
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .simultaneousGesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { _ in setScrolling(true) }
                    .onEnded { _ in scheduleScrollStop() }
            )
            .onPreferenceChange(SunriseScrollOffsetPreferenceKey.self) { offset in
                handleScrollOffsetChange(Self.chromeOffset(forScrollMinY: offset))
            }
        }
        .accessibilityIdentifier("home.view")
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let context = LBHeaderTimeContext.resolve(selectedDate: chrome.selectedDate, now: timeline.date)
            SunriseHeaderView(
                context: context,
                isScrollActive: isScrollActive,
                height: headerHeight
            ) {
                LBDateHeroHeader(
                    model: LBDateHeroHeader.Model(
                        date: chrome.selectedDate,
                        period: context.period,
                        subtitle: context.greeting,
                        heroTitleColor: context.foregroundStyle.titleColor,
                        heroSubtitleColor: context.foregroundStyle.controlColor,
                        chromeControlColor: context.foregroundStyle.controlColor,
                        chromeGlassFill: Color.white.opacity(0.12),
                        chromeGlassStroke: context.foregroundStyle.glassStroke.opacity(0.72),
                        navigatorColor: LBColorTokens.navy,
                        navigatorTitle: LBHeaderTimeContext.navigatorTitle(selectedDate: chrome.selectedDate, now: timeline.date),
                        navigatorGlassFill: Color.white.opacity(0.16),
                        navigatorGlassStroke: Color.white.opacity(0.58),
                        hasNotifications: false,
                        hasActiveFilters: chrome.activeFilterState.hasActiveFilters
                    ),
                    headerHeight: headerHeight,
                    safeAreaTop: safeAreaTop,
                    onMenu: onOpenSettings,
                    onSearch: onOpenSearch,
                    onDateTap: onShowDatePicker,
                    onPreviousDay: { onShiftSelectedDay(-1) },
                    onNextDay: { onShiftSelectedDay(1) }
                )
            }
        }
    }

    private var headerHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? LBSpacingTokens.compactHeaderAccessibilityHeight : LBSpacingTokens.compactHeaderHeight
    }

    private var headerContentOverlap: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? LBSpacingTokens.sunriseHeaderAccessibilityContentOverlap : LBSpacingTokens.sunriseHeaderContentOverlap
    }

    private var content: some View {
        VStack(spacing: LBSpacingTokens.xxs) {
            filterRow

            stateCards

            timelineContent

            habitPreview
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LBSpacingTokens.xs) {
                ForEach(filterChips) { chip in
                    LBFilterChip(model: chip.model) {
                        chip.action()
                    }
                }
            }
            .padding(.horizontal, LBSpacingTokens.screenMargin)
        }
        .padding(.horizontal, -LBSpacingTokens.screenMargin)
        .padding(.top, LBSpacingTokens.xs + 10)
    }

    @ViewBuilder
    private var stateCards: some View {
        if calendar.isLoading && timeline.day.plottedTimelineItems.isEmpty {
            LBLoadingSkeleton(lineCount: 3)
        }

        if let permission = permissionModel {
            LBPermissionCard(
                model: permission.model,
                primaryAction: permission.primaryAction,
                secondaryAction: permission.secondaryAction
            )
        }

        if let error = syncErrorModel {
            LBPermissionCard(
                model: error.model,
                primaryAction: error.primaryAction,
                secondaryAction: error.secondaryAction
            )
        }
    }

    @ViewBuilder
    private var timelineContent: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let rows = timelineRows(now: context.date)
            if rows.isEmpty {
                LBEmptyState(
                    model: LBEmptyState.Model(
                        title: "A quiet day",
                        message: "Nothing fixed is on the board yet. Add one meaningful next step when you are ready.",
                        actionTitle: "Add to today",
                        systemImage: "sun.max"
                    ),
                    action: { onAddTask(chrome.selectedDate) }
                )
            } else {
                LazyVStack(spacing: LBSpacingTokens.sm) {
                    ForEach(rows) { row in
                        let temporalState = row.temporalState(now: context.date)
                    switch row.kind {
                    case .anchor(let anchor):
                        let anchorRole = role(for: anchor)
                        LBTimelineItem(timeText: timeText(anchor.time), role: anchorRole, temporalState: temporalState) {
                            LBTimelineCard(
                                model: LBTimelineCard.Model(
                                    id: anchor.id,
                                    title: anchorTitle(for: anchor),
                                    subtitle: anchor.subtitle ?? routineSubtitle(for: LBHeaderTimeContext.resolve(selectedDate: chrome.selectedDate).period),
                                    timeText: timeText(anchor.time),
                                    role: anchorRole,
                                    kind: .anchor,
                                    systemImage: anchorSystemImage(for: anchor),
                                    accessoryText: nil,
                                    temporalState: temporalState,
                                    isCompleted: false,
                                    isToggleable: false,
                                    isCurrent: temporalState == .current
                                ),
                                onTap: { onAnchorTap(anchor) }
                            )
                        }
                    case .item(let item):
                        LBTimelineItem(timeText: timeText(item.startDate), role: role(for: item), temporalState: temporalState) {
                            LBTimelineCard(
                                model: timelineCardModel(for: item, temporalState: temporalState),
                                onTap: { onTimelineItemTap(item) },
                                onToggleComplete: item.taskID == nil ? nil : { onTimelineItemToggleComplete(item) }
                            )
                        }
                    case .meetingFlock(let model, let sourceItems):
                        LBTimelineItem(timeText: model.timeRange.components(separatedBy: " – ").first ?? model.timeRange, role: .meeting, temporalState: temporalState) {
                            LBMeetingFlockCard(model: model) { meeting in
                                if let item = sourceItems.first(where: { $0.id == meeting.id }) {
                                    onTimelineItemTap(item)
                                }
                            }
                        }
                    case .gap(let gap):
                        LBTimelineItem(timeText: timeText(row.sortDate(now: context.date)), role: .assistant, temporalState: temporalState) {
                            let copy = assistantCopy(for: gap)
                            LBAssistantPromptCard(
                                title: copy.title,
                                subtitle: copy.subtitle,
                                action: { onAddTask(gap.startDate) }
                            )
                        }
                    case .now(let now):
                        LBCurrentTimeRail(
                            model: LBCurrentTimeRail.Model(
                                now: now,
                                isToday: true
                            )
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var habitPreview: some View {
        let models = habitModels
        if !models.isEmpty {
            LBGlassCard(cornerRadius: LBRadiusTokens.largeCard) {
                VStack(spacing: LBSpacingTokens.md) {
                    HStack {
                        LBSectionHeader(title: "Habits", systemImage: "chart.bar")
                        Spacer()
                        Button("View All Habits", action: onOpenHabitBoard)
                            .font(LBTypographyTokens.meta)
                            .foregroundStyle(LBColorTokens.violetDeep)
                            .buttonStyle(.plain)
                    }
                    ForEach(models) { model in
                        LBHabitCell(model: model)
                    }
                    Divider().overlay(LBColorTokens.hairline)
                    HStack {
                        Image(systemName: "star")
                        Text("Small steps, big changes.")
                        Spacer()
                    }
                    .font(LBTypographyTokens.meta)
                    .foregroundStyle(LBColorTokens.navyMuted)
                }
                .padding(LBSpacingTokens.lg)
            }
            .padding(.bottom, LBSpacingTokens.xxl)
        }
    }

    private var filterChips: [SunriseFilterChip] {
        Self.filterChipModels(
            selectedFilterID: selectedFilterID,
            hasActiveFilters: chrome.activeFilterState.hasActiveFilters
        ).map { model in
            switch model.id {
            case "all":
                return SunriseFilterChip(
                    model: model,
                    action: {
                        selectedFilterID = "all"
                        onSelectQuickView(.today)
                    }
                )
            case "meetings":
                return SunriseFilterChip(
                    model: model,
                    action: {
                        selectedFilterID = "meetings"
                        onOpenCalendarChooser()
                    }
                )
            case "tasks":
                return SunriseFilterChip(
                    model: model,
                    action: {
                        selectedFilterID = "tasks"
                        onSelectQuickView(.today)
                    }
                )
            case "habits":
                return SunriseFilterChip(
                    model: model,
                    action: {
                        selectedFilterID = "habits"
                        onOpenHabitBoard()
                    }
                )
            case "filters":
                return SunriseFilterChip(
                    model: model,
                    action: onShowAdvancedFilters
                )
            default:
                return SunriseFilterChip(
                    model: model,
                    action: {}
                )
            }
        }
    }

    nonisolated static func filterChipModels(selectedFilterID: String, hasActiveFilters: Bool = false) -> [LBFilterChip.Model] {
        [
            LBFilterChip.Model(
                id: "all",
                title: "All",
                systemImage: "square.grid.2x2",
                isSelected: selectedFilterID == "all",
                accessibilityID: "home.sunrise.filter.all"
            ),
            LBFilterChip.Model(
                id: "meetings",
                title: "Meetings",
                systemImage: "calendar",
                isSelected: selectedFilterID == "meetings",
                accessibilityID: "home.sunrise.filter.meetings"
            ),
            LBFilterChip.Model(
                id: "tasks",
                title: "Tasks",
                systemImage: "checkmark.square",
                isSelected: selectedFilterID == "tasks",
                accessibilityID: "home.sunrise.filter.tasks"
            ),
            LBFilterChip.Model(
                id: "habits",
                title: "Habits",
                systemImage: "heart",
                isSelected: selectedFilterID == "habits",
                accessibilityID: "home.sunrise.filter.habits"
            ),
            LBFilterChip.Model(
                id: "filters",
                title: "Filters",
                systemImage: "slider.horizontal.3",
                isSelected: false,
                showsIndicator: hasActiveFilters,
                hidesTitle: true,
                accessibilityID: "home.sunrise.filter.filters"
            )
        ]
    }

    func timelineRows(now: Date) -> [SunriseTimelineRow] {
        Self.buildTimelineRows(
            wakeAnchor: timeline.day.wakeAnchor,
            sleepAnchor: timeline.day.sleepAnchor,
            plottedItems: timeline.day.plottedTimelineItems,
            gaps: timeline.day.actionableGaps,
            now: now,
            isToday: Calendar.current.isDate(chrome.selectedDate, inSameDayAs: now),
            meetingFlockModel: meetingFlockModel(for:)
        )
    }

    nonisolated static func buildTimelineRows(
        wakeAnchor: TimelineAnchorItem,
        sleepAnchor: TimelineAnchorItem,
        plottedItems: [TimelinePlanItem],
        gaps: [TimelineGap],
        now: Date,
        isToday: Bool,
        meetingFlockModel: ([TimelinePlanItem]) -> LBMeetingFlockCard.Model
    ) -> [SunriseTimelineRow] {
        var rows: [SunriseTimelineRow] = []
        rows.append(.anchor(wakeAnchor))

        let plotted = plottedItems
        var index = 0
        while index < plotted.count {
            let item = plotted[index]
            if item.isMeetingLike || item.source == .calendarEvent {
                let group = meetingGroup(startingAt: index, in: plotted)
                if group.count >= 3 {
                    rows.append(.meetingFlock(meetingFlockModel(group), group))
                    index += group.count
                    continue
                }
            }
            rows.append(.item(item))
            index += 1
        }

        if isToday {
            rows.append(.now(now))
        }

        if let gap = gaps.first(where: { Self.assistantDisplayDate(for: $0, now: now) != nil }) {
            rows.append(.gap(gap))
        }

        rows.append(.anchor(sleepAnchor))

        return Self.sortedRows(rows, now: now)
    }

    private var habitModels: [LBHabitCell.Model] {
        Array((habits.habitHomeSectionState.primaryRows + habits.habitHomeSectionState.recoveryRows).prefix(8)).map { row in
            let cells = Array((row.boardCellsCompact.isEmpty ? row.boardCellsExpanded : row.boardCellsCompact).suffix(7))
            let doneCount = cells.filter { cell in
                if case .done = cell.state { return true }
                return false
            }.count
            return LBHabitCell.Model(
                id: row.id,
                title: row.title,
                systemImage: row.iconSymbolName,
                color: Color(lifeboardHex: row.accentHex ?? HabitColorFamily.family(for: row.accentHex).canonicalHex),
                completionRatio: cells.isEmpty ? 0 : Double(doneCount) / Double(cells.count),
                dayLabels: Self.dayLabels(for: cells),
                cells: cells.map(LBHabitCell.CellState.init),
                allowsTwoLineTitle: true
            )
        }
    }

    private var permissionModel: (model: LBPermissionCard.Model, primaryAction: () -> Void, secondaryAction: (() -> Void)?)? {
        switch calendar.moduleState {
        case .permissionRequired:
            return (
                LBPermissionCard.Model(
                    title: "Connect your calendar",
                    message: "Meetings can sit inside your day timeline once calendar access is enabled.",
                    role: .warning,
                    primaryActionTitle: "Allow Access",
                    secondaryActionTitle: nil
                ),
                onRequestCalendarPermission,
                nil
            )
        case .noCalendarsSelected:
            return (
                LBPermissionCard.Model(
                    title: "Choose calendars",
                    message: "No calendars are selected for the Home timeline.",
                    role: .warning,
                    primaryActionTitle: "Choose Calendars",
                    secondaryActionTitle: nil
                ),
                onOpenCalendarChooser,
                nil
            )
        case .error(let message):
            return (
                LBPermissionCard.Model(
                    title: "Calendar is out of date",
                    message: message,
                    role: .error,
                    primaryActionTitle: "Retry",
                    secondaryActionTitle: "Calendars"
                ),
                onRetryCalendar,
                onOpenCalendarChooser
            )
        case .empty, .allDayOnly, .active:
            return nil
        }
    }

    private var syncErrorModel: (model: LBPermissionCard.Model, primaryAction: () -> Void, secondaryAction: (() -> Void)?)? {
        guard let message = habits.errorMessage, message.isEmpty == false else { return nil }
        return (
            LBPermissionCard.Model(
                title: "Habit sync needs attention",
                message: message,
                role: .warning,
                primaryActionTitle: "Refresh",
                secondaryActionTitle: nil
            ),
            onRetryCalendar,
            nil
        )
    }

    private nonisolated static func meetingGroup(startingAt index: Int, in items: [TimelinePlanItem]) -> [TimelinePlanItem] {
        guard let start = items[index].startDate else { return [items[index]] }
        let hour = Calendar.current.component(.hour, from: start)
        var group: [TimelinePlanItem] = []
        for item in items[index...] {
            guard item.isMeetingLike || item.source == .calendarEvent,
                  let itemStart = item.startDate,
                  Calendar.current.component(.hour, from: itemStart) == hour else {
                break
            }
            group.append(item)
        }
        return group
    }

    private func meetingFlockModel(for items: [TimelinePlanItem]) -> LBMeetingFlockCard.Model {
        let start = items.compactMap(\.startDate).min()
        let end = items.compactMap(\.endDate).max()
        return LBMeetingFlockCard.Model(
            id: "meeting-flock-\(items.map(\.id).joined(separator: "-"))",
            timeRange: "\(timeText(start)) – \(timeText(end))",
            meetings: items.map { item in
                LBMeetingFlockCard.Meeting(
                    id: item.id,
                    title: item.title,
                    timeText: "\(timeText(item.startDate)) – \(timeText(item.endDate))",
                    isNow: item.id == timeline.day.currentItemID
                )
            },
            eventCountText: "\(items.count) events"
        )
    }

    private func timelineCardModel(for item: TimelinePlanItem, temporalState: LBTimelineTemporalState) -> LBTimelineCard.Model {
        let kind = cardKind(for: item)
        return LBTimelineCard.Model(
            id: item.id,
            title: item.title,
            subtitle: item.subtitle ?? (item.source == .calendarEvent ? "Calendar" : ""),
            timeText: "\(timeText(item.startDate))\(item.endDate == nil ? "" : " – \(timeText(item.endDate))")",
            role: role(for: item),
            kind: kind,
            systemImage: kind == .calendar ? "calendar" : item.systemImageName,
            accessoryText: item.source == .task ? "Task" : nil,
            temporalState: temporalState,
            isCompleted: item.isComplete,
            isToggleable: item.taskID != nil,
            isCurrent: temporalState == .current
        )
    }

    private func cardKind(for item: TimelinePlanItem) -> LBTimelineCard.Kind {
        if item.source == .calendarEvent || item.isMeetingLike {
            return .calendar
        }
        return .task
    }

    private func role(for item: TimelinePlanItem) -> LBRole {
        if item.source == .calendarEvent || item.isMeetingLike { return .meeting }
        let title = item.title.lowercased()
        if title.contains("lunch") || title.contains("dinner") || title.contains("meal") { return .meal }
        if item.isPinnedFocusTask { return .focus }
        return .task
    }

    private func role(for anchor: TimelineAnchorItem) -> LBRole {
        anchor.id == "sleep" ? .windDown : .routine
    }

    private func anchorTitle(for anchor: TimelineAnchorItem) -> String {
        anchor.id == "sleep" ? "Wind Down" : anchor.title
    }

    private func anchorSystemImage(for anchor: TimelineAnchorItem) -> String {
        if anchor.id == "sleep" {
            return LBColorTokens.role(.windDown).symbolName
        }
        return anchor.systemImageName.isEmpty ? "sunrise" : anchor.systemImageName
    }

    private func routineSubtitle(for period: TimeOfDayHeaderAsset.Period) -> String {
        switch period {
        case .morning:
            return "Start the day with intention"
        case .afternoon:
            return "A steady anchor for today"
        case .evening:
            return "Close the day with care"
        case .night:
            return "Keep the night gentle"
        }
    }

    private func assistantCopy(for gap: TimelineGap) -> (title: String, subtitle: String) {
        let context = LBHeaderTimeContext.resolve(selectedDate: chrome.selectedDate)
        return LBHeaderTimeContext.assistantCopy(
            for: context.period,
            gapStart: gap.startDate,
            gapEnd: gap.endDate,
            now: context.now
        )
    }

    nonisolated static func sortedRows(_ rows: [SunriseTimelineRow], now: Date) -> [SunriseTimelineRow] {
        rows.sorted { lhs, rhs in
            let leftDate = lhs.sortDate(now: now)
            let rightDate = rhs.sortDate(now: now)
            if leftDate == rightDate {
                return lhs.sortPriority < rhs.sortPriority
            }
            return leftDate < rightDate
        }
    }

    nonisolated static func assistantDisplayDate(for gap: TimelineGap, now: Date) -> Date? {
        guard gap.endDate > now else { return nil }
        let remaining = gap.endDate.timeIntervalSince(max(now, gap.startDate))
        guard remaining >= 15 * 60 else { return nil }
        if gap.startDate <= now && gap.endDate > now {
            return now
        }
        return gap.startDate
    }

    private static func dayLabels(for cells: [HabitBoardCell]) -> [String] {
        cells.map { cell in
            String(cell.date.formatted(.dateTime.weekday(.narrow)).prefix(1))
        }
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func setScrolling(_ active: Bool) {
        guard isScrollActive != active else { return }
        isScrollActive = active
    }

    private func scheduleScrollStop() {
        scrollStopTask?.cancel()
        scrollStopTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            setScrolling(false)
            if let idleState = scrollChromeStateTracker.emitIdleIfNeeded() {
                onScrollStateChange(idleState)
            }
        }
    }

    private func handleScrollOffsetChange(_ offset: CGFloat) {
        guard isShellInteractive else { return }
        if let nextState = scrollChromeStateTracker.consume(offset: offset) {
            onScrollStateChange(nextState)
        }
    }

    nonisolated static func chromeOffset(forScrollMinY minY: CGFloat) -> CGFloat {
        max(0, -minY)
    }
}

private struct SunriseFilterChip: Identifiable {
    let model: LBFilterChip.Model
    let action: () -> Void
    var id: String { model.id }
}

enum SunriseTimelineRow: Identifiable {
    case anchor(TimelineAnchorItem)
    case item(TimelinePlanItem)
    case meetingFlock(LBMeetingFlockCard.Model, [TimelinePlanItem])
    case gap(TimelineGap)
    case now(Date)

    var id: String {
        switch self {
        case .anchor(let anchor): return "anchor-\(anchor.id)"
        case .item(let item): return "item-\(item.id)"
        case .meetingFlock(let model, _): return model.id
        case .gap(let gap): return "gap-\(gap.id)"
        case .now(let date): return "now-\(Int(date.timeIntervalSince1970 / 60))"
        }
    }

    var kind: SunriseTimelineRow {
        self
    }

    var displayDate: Date? {
        switch self {
        case .anchor(let anchor):
            return anchor.time
        case .item(let item):
            return item.startDate
        case .meetingFlock(_, let items):
            return items.compactMap(\.startDate).min()
        case .gap:
            return nil
        case .now(let date):
            return date
        }
    }

    var sortPriority: Int {
        switch self {
        case .anchor: return 0
        case .item: return 1
        case .meetingFlock: return 1
        case .now: return 2
        case .gap: return 3
        }
    }

    func sortDate(now: Date) -> Date {
        switch self {
        case .gap(let gap):
            return SunriseHomeScreen.assistantDisplayDate(for: gap, now: now) ?? gap.startDate
        default:
            return displayDate ?? now
        }
    }

    func temporalState(now: Date) -> LBTimelineTemporalState {
        switch self {
        case .now:
            return .current
        case .anchor(let anchor):
            return anchor.time < now ? .past : .future
        case .item(let item):
            if item.isActive(at: now) {
                return .current
            }
            if let endDate = item.endDate {
                return endDate <= now ? .past : .future
            }
            if let startDate = item.startDate {
                return startDate < now ? .past : .future
            }
            return .future
        case .meetingFlock(_, let items):
            let active = items.contains { $0.isActive(at: now) }
            if active {
                return .current
            }
            let latestEnd = items.compactMap(\.endDate).max()
            let earliestStart = items.compactMap(\.startDate).min()
            if let latestEnd {
                return latestEnd <= now ? .past : .future
            }
            if let earliestStart {
                return earliestStart < now ? .past : .future
            }
            return .future
        case .gap(let gap):
            if gap.startDate <= now && gap.endDate > now {
                return .current
            }
            return gap.endDate <= now ? .past : .future
        }
    }
}

private struct SunriseScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
