import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SunriseHomeScreen: View {
    let chrome: HomeChromeSnapshot
    let tasks: HomeTasksSnapshot
    let habits: HomeHabitsSnapshot
    let calendar: HomeCalendarSnapshot
    let timeline: HomeTimelineSnapshot
    let bottomInset: CGFloat
    let safeAreaTop: CGFloat
    let isShellInteractive: Bool
    let isDaySwipeEnabled: Bool
    let isDaySwipeInteractive: Bool
    let onSelectQuickView: (HomeQuickView) -> Void
    let onShowDatePicker: () -> Void
    let onShiftSelectedDay: (Int, HomeDateNavigationSource) -> Void
    let onShowAdvancedFilters: () -> Void
    let onOpenSettings: () -> Void
    let onOpenSearch: () -> Void
    let onOpenChat: () -> Void
    let onOpenHabitBoard: () -> Void
    let onAddHabit: () -> Void
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
    @State private var selectedContentScope: SunriseHomeContentScope = .all
    @State private var headerActivationID = TimeOfDayHeaderAsset.makeActivationID()
    @State private var leadingDaySunriseSwipeData = SunriseDaySwipeData(side: .leading)
    @State private var trailingDaySunriseSwipeData = SunriseDaySwipeData(side: .trailing)
    @State private var topDaySunriseSwipeSide: SunriseDaySwipeSide = .trailing
    @State private var activeDaySunriseSwipeSide: SunriseDaySwipeSide?
    @State private var isDaySunriseSwipeChromeVisible = true
    @State private var committedDaySwipeDirection: HomeDayNavigationDirection?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.lifeboard.bgCanvas
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        header
                        content
                            .id(selectedDayKey)
                            .transition(daySwipeTransition)
                            .animation(daySwipeAnimation, value: selectedDayKey)
                            .padding(.top, -headerContentOverlap)
                            .padding(.bottom, bottomInset + LBSpacingTokens.bottomDockClearance)
                    }
                    .contentShape(Rectangle())
                    .background {
                        ZStack {
                            SunriseDaySwipeGestureSurface(
                                isEnabled: isDaySwipeInteractionEnabled,
                                containerSize: daySunriseSwipeContainerSize(proxy.size),
                                restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: proxy.safeAreaInsets.top),
                                resolver: .default,
                                onInteractionStarted: {},
                                onChanged: { side, translation, location in
                                    updateDaySunriseSwipe(
                                        side: side,
                                        translation: translation,
                                        location: location,
                                        size: daySunriseSwipeContainerSize(proxy.size),
                                        restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: proxy.safeAreaInsets.top)
                                    )
                                },
                                onEnded: { side, translation, predictedEndTranslation, _ in
                                    endDaySunriseSwipe(
                                        side: side,
                                        translation: translation,
                                        predictedEndTranslation: predictedEndTranslation,
                                        size: daySunriseSwipeContainerSize(proxy.size),
                                        restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: proxy.safeAreaInsets.top)
                                    )
                                },
                                onCancelled: { side in
                                    cancelDaySunriseSwipe(
                                        side: side,
                                        size: daySunriseSwipeContainerSize(proxy.size),
                                        restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: proxy.safeAreaInsets.top)
                                    )
                                }
                            )

                            SunriseHomeScrollChromeObserver(
                                isEnabled: isDaySwipeChromeEnabled,
                                onOffsetChange: handleScrollOffsetChange,
                                onScrollIntent: handleScrollChromeState
                            )
                        }
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: SunriseScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("sunriseHomeScroll")).minY)
                        }
                    )
                }
                .coordinateSpace(name: "sunriseHomeScroll")
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("home.view")
                .ignoresSafeArea(edges: .top)
                .simultaneousGesture(scrollIntentGesture)
                .onPreferenceChange(SunriseScrollOffsetPreferenceKey.self) { offset in
                    handleScrollOffsetChange(Self.chromeOffset(forScrollMinY: offset))
                }
                .onScrollGeometryChange(
                    for: CGFloat.self,
                    of: { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    },
                    action: { _, newOffset in
                        handleScrollOffsetChange(max(0, newOffset))
                    }
                )

                daySunriseSwipeOverlay(safeAreaTop: proxy.safeAreaInsets.top)
                    .zIndex(10)
            }
            .onAppear {
                resetIdleDaySunriseSwipeHandles(
                    restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: proxy.safeAreaInsets.top),
                    size: daySunriseSwipeContainerSize(proxy.size)
                )
            }
            .onChange(of: proxy.size) { _, newSize in
                resetIdleDaySunriseSwipeHandles(
                    restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: proxy.safeAreaInsets.top),
                    size: daySunriseSwipeContainerSize(newSize)
                )
            }
            .onChange(of: proxy.safeAreaInsets.top) { _, newSafeAreaTop in
                resetIdleDaySunriseSwipeHandles(
                    restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: newSafeAreaTop),
                    size: daySunriseSwipeContainerSize(proxy.size)
                )
            }
            .contentShape(Rectangle())
            .simultaneousGesture(scrollIntentGesture)
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshHeaderActivationID()
        }
        #endif
    }

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let context = LBHeaderTimeContext.resolve(
                selectedDate: chrome.selectedDate,
                now: timeline.date,
                activationID: headerActivationID
            )
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
                        chromeGlassFill: context.foregroundStyle.glassFill.opacity(0.72),
                        chromeGlassStroke: context.foregroundStyle.glassStroke.opacity(0.72),
                        navigatorColor: context.foregroundStyle.controlColor,
                        navigatorTitle: LBHeaderTimeContext.navigatorTitle(selectedDate: chrome.selectedDate, now: timeline.date),
                        navigatorGlassFill: context.foregroundStyle.glassFill,
                        navigatorGlassStroke: context.foregroundStyle.glassStroke,
                        hasNotifications: false,
                        hasActiveFilters: chrome.activeFilterState.hasActiveFilters
                    ),
                    headerHeight: headerHeight,
                    safeAreaTop: safeAreaTop,
                    onMenu: onOpenSettings,
                    onSearch: onOpenSearch,
                    onDateTap: onShowDatePicker
                )
            }
        }
    }

    private func daySunriseSwipeOverlay(safeAreaTop: CGFloat) -> some View {
        SunriseDaySwipeOverlay(
            isEnabled: isDaySwipeChromeEnabled,
            isChromeVisible: isDaySunriseSwipeChromeVisible,
            reduceMotion: reduceMotion || isUITesting,
            restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: safeAreaTop),
            onInteractionStarted: {},
            onInteractionCancelled: {},
            onCommit: commitHomeDaySwipe,
            onHandleDragChanged: { side, translation, location, size in
                updateDaySunriseSwipe(
                    side: side,
                    translation: translation,
                    location: location,
                    size: size,
                    restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: safeAreaTop)
                )
            },
            onHandleDragEnded: { side, translation, predictedEndTranslation, _, size in
                endDaySunriseSwipe(
                    side: side,
                    translation: translation,
                    predictedEndTranslation: predictedEndTranslation,
                    size: size,
                    restingCenterY: daySunriseSwipeRestingCenterY(safeAreaTop: safeAreaTop)
                )
            },
            leadingData: $leadingDaySunriseSwipeData,
            trailingData: $trailingDaySunriseSwipeData,
            topSide: $topDaySunriseSwipeSide
        )
    }

    private func refreshHeaderActivationID() {
        headerActivationID = TimeOfDayHeaderAsset.makeActivationID()
    }

    private var headerHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? LBSpacingTokens.compactHeaderAccessibilityHeight : LBSpacingTokens.compactHeaderHeight
    }

    private var headerContentOverlap: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? LBSpacingTokens.sunriseHeaderAccessibilityContentOverlap : LBSpacingTokens.sunriseHeaderContentOverlap
    }

    private var selectedDayKey: Int {
        Int(Calendar.current.startOfDay(for: chrome.selectedDate).timeIntervalSince1970)
    }

    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-UI_TESTING")
            || ProcessInfo.processInfo.arguments.contains("-DISABLE_ANIMATIONS")
    }

    private var isDaySwipeChromeEnabled: Bool {
        isDaySwipeEnabled
    }

    private var isDaySwipeInteractionEnabled: Bool {
        isShellInteractive && isDaySwipeInteractive && isDaySunriseSwipeChromeVisible
    }

    private var daySwipeAnimation: Animation {
        if reduceMotion || isUITesting {
            return .easeOut(duration: 0.12)
        }
        return .snappy(duration: 0.22)
    }

    private var daySwipeTransition: AnyTransition {
        guard reduceMotion == false, isUITesting == false else {
            return .opacity
        }

        switch committedDaySwipeDirection {
        case .previous:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        case .next:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case nil:
            return .opacity
        }
    }

    private var filterRowTopPadding: CGFloat {
        headerContentOverlap + LBSpacingTokens.xs
    }

    private var content: some View {
        VStack(spacing: LBSpacingTokens.xxs) {
            filterRow

            stateCards

            if selectedContentScope.showsTimeline {
                timelineContent
            }

            if selectedContentScope.showsHabits {
                habitContent
            }
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
        .padding(.top, filterRowTopPadding)
    }

    @ViewBuilder
    private var stateCards: some View {
        if selectedContentScope.showsCalendarState,
           calendar.isLoading && timeline.day.plottedTimelineItems.isEmpty {
            LBLoadingSkeleton(lineCount: 3)
        }

        if selectedContentScope.showsCalendarState,
           let permission = permissionModel {
            LBPermissionCard(
                model: permission.model,
                primaryAction: permission.primaryAction,
                secondaryAction: permission.secondaryAction
            )
        }

        if selectedContentScope.showsHabitState,
           let error = syncErrorModel {
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
            let nextUpcomingCalendarItemID = Self.nextUpcomingCalendarItemID(in: rows, now: context.date)
            if rows.isEmpty {
                let emptyState = timelineEmptyStateModel
                LBEmptyState(
                    model: emptyState.model,
                    action: emptyState.action
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
                                    tintHex: nil,
                                    accessoryText: nil,
                                    temporalState: temporalState,
                                    isCompleted: false,
                                    isToggleable: false,
                                    isCurrent: temporalState == .current
                                ),
                                onTap: { onAnchorTap(anchor) }
                            )
                            .equatable()
                        }
                    case .item(let item):
                        let kind = cardKind(for: item)
                        LBTimelineItem(
                            timeText: timeText(item.startDate),
                            role: role(for: item),
                            tintHex: kind == .task ? item.tintHex : nil,
                            temporalState: temporalState
                        ) {
                            LBTimelineCard(
                                model: timelineCardModel(
                                    for: item,
                                    temporalState: temporalState,
                                    now: context.date,
                                    nextUpcomingCalendarItemID: nextUpcomingCalendarItemID
                                ),
                                onTap: { onTimelineItemTap(item) },
                                onToggleComplete: item.taskID == nil ? nil : { onTimelineItemToggleComplete(item) }
                            )
                            .equatable()
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
                        .equatable()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var habitContent: some View {
        let models = habitModels
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
                if models.isEmpty {
                    HStack(spacing: LBSpacingTokens.sm) {
                        Image(systemName: "heart")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(LBColorTokens.violetDeep)
                        Text("No habits here yet.")
                            .font(LBTypographyTokens.body)
                            .foregroundStyle(LBColorTokens.navy)
                        Spacer(minLength: LBSpacingTokens.sm)
                    }
                    .padding(.top, LBSpacingTokens.xs)
                } else {
                    ForEach(models) { model in
                        LBHabitCell(model: model)
                            .equatable()
                    }
                }
                Divider().overlay(LBColorTokens.hairline)
                addHabitFooterButton
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
        .padding(.top, LBSpacingTokens.xs)
        .padding(.bottom, LBSpacingTokens.xxl)
    }

    private var addHabitFooterButton: some View {
        Button(action: onAddHabit) {
            HStack(spacing: LBSpacingTokens.xs) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                Text("Add Habit")
                    .font(LBTypographyTokens.chip)
                Spacer(minLength: LBSpacingTokens.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(LBColorTokens.violetDeep.opacity(0.7))
            }
            .foregroundStyle(LBColorTokens.violetDeep)
            .padding(.horizontal, LBSpacingTokens.md)
            .padding(.vertical, LBSpacingTokens.sm)
            .background {
                RoundedRectangle(cornerRadius: LBRadiusTokens.iconWell, style: .continuous)
                    .fill(LBColorTokens.violetSoft.opacity(0.72))
                    .overlay {
                        RoundedRectangle(cornerRadius: LBRadiusTokens.iconWell, style: .continuous)
                            .stroke(LBColorTokens.violet.opacity(0.22), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.habits.addHabit")
        .accessibilityLabel("Add Habit")
    }

    private var filterChips: [SunriseFilterChip] {
        Self.filterChipModels(
            selectedContentScope: selectedContentScope,
            hasActiveFilters: chrome.activeFilterState.hasActiveFilters
        ).map { model in
            switch model.id {
            case "all":
                return SunriseFilterChip(
                    model: model,
                    action: {
                        selectedContentScope = .all
                    }
                )
            case "meetings":
                return SunriseFilterChip(
                    model: model,
                    action: {
                        selectedContentScope = .meetings
                    }
                )
            case "tasks":
                return SunriseFilterChip(
                    model: model,
                    action: {
                        selectedContentScope = .tasks
                    }
                )
            case "habits":
                return SunriseFilterChip(
                    model: model,
                    action: {
                        selectedContentScope = .habits
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

    private var timelineEmptyStateModel: (model: LBEmptyState.Model, action: () -> Void) {
        switch selectedContentScope {
        case .all:
            return (
                LBEmptyState.Model(
                    title: "A quiet day",
                    message: "Nothing fixed is on the board yet. Add one meaningful next step when you are ready.",
                    actionTitle: "Add to today",
                    systemImage: "sun.max"
                ),
                { onAddTask(chrome.selectedDate) }
            )
        case .meetings:
            return (
                LBEmptyState.Model(
                    title: "No meetings on this day",
                    message: "Your calendar has nothing meeting-like in this Home view.",
                    actionTitle: "Choose calendars",
                    systemImage: "calendar"
                ),
                onOpenCalendarChooser
            )
        case .tasks:
            return (
                LBEmptyState.Model(
                    title: "No tasks in this view",
                    message: "No task cards match the current day and focus filters.",
                    actionTitle: "Add to today",
                    systemImage: "checkmark.square"
                ),
                { onAddTask(chrome.selectedDate) }
            )
        case .habits:
            return (
                LBEmptyState.Model(
                    title: "No habits here yet",
                    message: "Nothing is due or tracked in Home right now. Open the Habit Board to review the full system.",
                    actionTitle: "Open Habit Board",
                    systemImage: "heart"
                ),
                onOpenHabitBoard
            )
        }
    }

    nonisolated static func filterChipModels(selectedContentScope: SunriseHomeContentScope, hasActiveFilters: Bool = false) -> [LBFilterChip.Model] {
        [
            LBFilterChip.Model(
                id: "all",
                title: "All",
                systemImage: "square.grid.2x2",
                isSelected: selectedContentScope == .all,
                accessibilityID: "home.sunrise.filter.all"
            ),
            LBFilterChip.Model(
                id: "meetings",
                title: "Meetings",
                systemImage: "calendar",
                isSelected: selectedContentScope == .meetings,
                accessibilityID: "home.sunrise.filter.meetings"
            ),
            LBFilterChip.Model(
                id: "tasks",
                title: "Tasks",
                systemImage: "checkmark.square",
                isSelected: selectedContentScope == .tasks,
                accessibilityID: "home.sunrise.filter.tasks"
            ),
            LBFilterChip.Model(
                id: "habits",
                title: "Habits",
                systemImage: "heart",
                isSelected: selectedContentScope == .habits,
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
            contentScope: selectedContentScope,
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
        contentScope: SunriseHomeContentScope = .all,
        meetingFlockModel: ([TimelinePlanItem]) -> LBMeetingFlockCard.Model
    ) -> [SunriseTimelineRow] {
        guard contentScope.showsTimeline else { return [] }

        var rows: [SunriseTimelineRow] = []
        if contentScope.includesStructuralTimelineRows {
            rows.append(.anchor(wakeAnchor))
        }

        let plotted = plottedItems.filter { contentScope.includesTimelineItem($0) }
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

        if contentScope.includesStructuralTimelineRows, isToday {
            rows.append(.now(now))
        }

        if contentScope.includesAssistantGaps,
           let gap = gaps.first(where: { Self.assistantDisplayDate(for: $0, now: now) != nil }) {
            rows.append(.gap(gap))
        }

        if contentScope.includesStructuralTimelineRows {
            rows.append(.anchor(sleepAnchor))
        }

        return Self.sortedRows(rows, now: now)
    }

    private var habitModels: [LBHabitCell.Model] {
        Array(habits.habitHomeSectionState.primaryRows.prefix(8)).map { row in
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

    private func timelineCardModel(
        for item: TimelinePlanItem,
        temporalState: LBTimelineTemporalState,
        now: Date,
        nextUpcomingCalendarItemID: String?
    ) -> LBTimelineCard.Model {
        let kind = cardKind(for: item)
        return LBTimelineCard.Model(
            id: item.id,
            title: item.title,
            subtitle: Self.timelineCardSubtitle(
                for: item,
                now: now,
                nextUpcomingCalendarItemID: nextUpcomingCalendarItemID
            ),
            timeText: "\(timeText(item.startDate))\(item.endDate == nil ? "" : " – \(timeText(item.endDate))")",
            role: role(for: item),
            kind: kind,
            systemImage: kind == .calendar ? "calendar" : item.systemImageName,
            tintHex: kind == .task ? item.tintHex : nil,
            accessoryText: nil,
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

    nonisolated static func nextUpcomingCalendarItemID(in rows: [SunriseTimelineRow], now: Date) -> String? {
        rows.compactMap { row -> TimelinePlanItem? in
            guard case .item(let item) = row,
                  item.source == .calendarEvent,
                  let startDate = item.startDate,
                  startDate > now else {
                return nil
            }
            return item
        }
        .sorted { lhs, rhs in
            guard let leftStart = lhs.startDate, let rightStart = rhs.startDate else {
                return lhs.id < rhs.id
            }
            if leftStart == rightStart {
                return lhs.id < rhs.id
            }
            return leftStart < rightStart
        }
        .first?
        .id
    }

    nonisolated static func timelineCardSubtitle(
        for item: TimelinePlanItem,
        now: Date,
        nextUpcomingCalendarItemID: String?
    ) -> String {
        guard item.source == .calendarEvent else {
            return item.subtitle ?? ""
        }
        guard item.id == nextUpcomingCalendarItemID,
              let startDate = item.startDate else {
            return ""
        }
        return calendarCountdownSubtitle(until: startDate, now: now) ?? ""
    }

    nonisolated static func calendarCountdownSubtitle(until startDate: Date, now: Date) -> String? {
        guard startDate > now else { return nil }
        let minutes = max(1, Int(ceil(startDate.timeIntervalSince(now) / 60)))
        if minutes < 60 {
            return "in \(minutes)m"
        }
        return "in \(Int(ceil(Double(minutes) / 60.0)))h"
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

    private func daySunriseSwipeContainerSize(_ size: CGSize) -> CGSize {
        CGSize(width: max(size.width, 1), height: max(size.height, 1))
    }

    private func daySunriseSwipeRestingCenterY(safeAreaTop: CGFloat) -> CGFloat {
        max(safeAreaTop, 0) + SunriseDaySwipeData.timelineHandleCenterY
    }

    private func daySunriseSwipeData(
        for side: SunriseDaySwipeSide,
        size: CGSize,
        restingCenterY: CGFloat
    ) -> SunriseDaySwipeData {
        let data = side == .leading ? leadingDaySunriseSwipeData : trailingDaySunriseSwipeData
        return data
            .resting(at: restingCenterY)
            .sized(to: daySunriseSwipeContainerSize(size))
    }

    private func setDaySunriseSwipeData(_ data: SunriseDaySwipeData) {
        switch data.side {
        case .leading:
            leadingDaySunriseSwipeData = data
        case .trailing:
            trailingDaySunriseSwipeData = data
        }
    }

    private func updateDaySunriseSwipe(
        side: SunriseDaySwipeSide,
        translation: CGSize,
        location: CGPoint,
        size: CGSize,
        restingCenterY: CGFloat
    ) {
        guard isDaySwipeInteractionEnabled else { return }
        activeDaySunriseSwipeSide = side
        topDaySunriseSwipeSide = side
        setDaySunriseSwipeData(
            daySunriseSwipeData(for: side, size: size, restingCenterY: restingCenterY)
                .drag(translation: translation, location: location)
        )
    }

    private func endDaySunriseSwipe(
        side: SunriseDaySwipeSide,
        translation: CGSize,
        predictedEndTranslation: CGSize,
        size: CGSize,
        restingCenterY: CGFloat
    ) {
        activeDaySunriseSwipeSide = nil

        guard isDaySwipeInteractionEnabled else {
            resetDaySunriseSwipe(side, size: size, restingCenterY: restingCenterY)
            return
        }

        guard let direction = HomeDaySwipeResolver.default.resolvedDirection(
            translation: translation,
            predictedEndTranslation: predictedEndTranslation
        ), direction == side.direction else {
            resetDaySunriseSwipe(side, size: size, restingCenterY: restingCenterY)
            return
        }

        commitDaySunriseSwipe(side, size: size, restingCenterY: restingCenterY)
    }

    private func cancelDaySunriseSwipe(
        side: SunriseDaySwipeSide,
        size: CGSize,
        restingCenterY: CGFloat
    ) {
        activeDaySunriseSwipeSide = nil
        resetDaySunriseSwipe(side, size: size, restingCenterY: restingCenterY)
    }

    private func resetDaySunriseSwipe(
        _ side: SunriseDaySwipeSide,
        size: CGSize,
        restingCenterY: CGFloat
    ) {
        let data = daySunriseSwipeData(for: side, size: size, restingCenterY: restingCenterY).initial()
        if reduceMotion || isUITesting {
            setDaySunriseSwipeData(data)
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                setDaySunriseSwipeData(data)
            }
        }
    }

    private func resetIdleDaySunriseSwipeHandles(restingCenterY: CGFloat, size: CGSize) {
        guard activeDaySunriseSwipeSide == nil else { return }
        let containerSize = daySunriseSwipeContainerSize(size)
        leadingDaySunriseSwipeData = leadingDaySunriseSwipeData
            .resting(at: restingCenterY)
            .sized(to: containerSize)
            .initial()
        trailingDaySunriseSwipeData = trailingDaySunriseSwipeData
            .resting(at: restingCenterY)
            .sized(to: containerSize)
            .initial()
    }

    private func commitDaySunriseSwipe(
        _ side: SunriseDaySwipeSide,
        size: CGSize,
        restingCenterY: CGFloat
    ) {
        topDaySunriseSwipeSide = side
        if reduceMotion || isUITesting {
            commitHomeDaySwipe(side.direction)
            resetDaySunriseSwipe(side, size: size, restingCenterY: restingCenterY)
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
            setDaySunriseSwipeData(
                daySunriseSwipeData(for: side, size: size, restingCenterY: restingCenterY).final()
            )
        } completion: {
            commitHomeDaySwipe(side.direction)
            resetDaySunriseSwipe(side, size: size, restingCenterY: restingCenterY)
        }
    }

    private func commitHomeDaySwipe(_ direction: HomeDayNavigationDirection) {
        guard isDaySwipeInteractionEnabled else { return }
        committedDaySwipeDirection = direction
        let dayOffset = direction == .previous ? -1 : 1
        LifeBoardFeedback.selection()
        withAnimation(daySwipeAnimation) {
            onShiftSelectedDay(dayOffset, .swipe)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if committedDaySwipeDirection == direction {
                committedDaySwipeDirection = nil
            }
        }
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
                handleScrollChromeState(idleState)
            }
        }
    }

    private var scrollIntentGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in handleScrollDragChange(value) }
            .onEnded { _ in scheduleScrollStop() }
    }

    private func handleScrollOffsetChange(_ offset: CGFloat) {
        if let nextState = scrollChromeStateTracker.consume(offset: offset) {
            handleScrollChromeState(nextState)
        }
    }

    private func handleScrollDragChange(_ value: DragGesture.Value) {
        setScrolling(true)

        let verticalTranslation = value.translation.height
        let horizontalTranslation = value.translation.width
        guard abs(verticalTranslation) >= 8,
              abs(verticalTranslation) > abs(horizontalTranslation) else { return }

        if verticalTranslation < 0 {
            handleScrollChromeState(.collapsed)
        } else if scrollChromeStateTracker.lastOffsetY == nil {
            handleScrollChromeState(.nearTop)
        }
    }

    private func handleScrollChromeState(_ state: HomeScrollChromeState) {
        updateDaySunriseSwipeChromeVisibility(for: state)
        onScrollStateChange(state)
    }

    private func updateDaySunriseSwipeChromeVisibility(for state: HomeScrollChromeState) {
        let nextVisibility = SunriseDaySwipeChromeVisibilityPolicy.nextVisibility(
            currentVisibility: isDaySunriseSwipeChromeVisible,
            for: state,
            restoresOnExpanded: false
        )
        guard nextVisibility != isDaySunriseSwipeChromeVisible else { return }
        if reduceMotion || isUITesting {
            isDaySunriseSwipeChromeVisible = nextVisibility
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                isDaySunriseSwipeChromeVisible = nextVisibility
            }
        }
        if nextVisibility == false {
            activeDaySunriseSwipeSide = nil
        }
    }

    nonisolated static func chromeOffset(forScrollMinY minY: CGFloat) -> CGFloat {
        max(0, -minY)
    }
}

#if canImport(UIKit)
private struct SunriseHomeScrollChromeObserver: UIViewRepresentable {
    let isEnabled: Bool
    let onOffsetChange: (CGFloat) -> Void
    let onScrollIntent: (HomeScrollChromeState) -> Void

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: HostView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.installIfNeeded(from: uiView)
    }

    static func dismantleUIView(_ uiView: HostView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class HostView: UIView {
        override var intrinsicContentSize: CGSize {
            CGSize(width: 1, height: 1)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: SunriseHomeScrollChromeObserver

        private weak var scrollView: UIScrollView?
        private weak var installedView: UIView?
        private weak var panRecognizer: UIPanGestureRecognizer?
        private let nearTopOffset: CGFloat = 40

        init(parent: SunriseHomeScrollChromeObserver) {
            self.parent = parent
        }

        func installIfNeeded(from hostView: UIView) {
            if let scrollView = hostView.nearestSunriseHomeSuperview(of: UIScrollView.self),
               let installView = scrollView.window ?? scrollView.superview {
                install(on: installView, observing: scrollView)
                return
            }

            DispatchQueue.main.async { [weak self, weak hostView] in
                guard let self, let hostView else { return }
                guard let scrollView = hostView.nearestSunriseHomeSuperview(of: UIScrollView.self) else { return }
                guard let installView = scrollView.window ?? scrollView.superview else { return }
                self.install(on: installView, observing: scrollView)
            }
        }

        func uninstall() {
            if let panRecognizer, let installedView {
                installedView.removeGestureRecognizer(panRecognizer)
            }
            installedView = nil
            panRecognizer = nil
            scrollView = nil
        }

        private func install(on installView: UIView, observing scrollView: UIScrollView) {
            self.scrollView = scrollView

            if installedView === installView, panRecognizer?.view === installView {
                return
            }

            uninstall()
            self.scrollView = scrollView
            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            installView.addGestureRecognizer(recognizer)
            installedView = installView
            panRecognizer = recognizer
            emitOffsetChange(from: scrollView)
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard parent.isEnabled, let scrollView else { return }
            emitOffsetChange(from: scrollView)

            let translation = recognizer.translation(in: scrollView)
            let velocity = recognizer.velocity(in: scrollView)
            let verticalMovement = abs(translation.y) > 8 ? translation.y : velocity.y
            let horizontalMovement = abs(translation.x) > 8 ? translation.x : velocity.x
            guard abs(verticalMovement) > abs(horizontalMovement) else { return }

            if verticalMovement < 0 {
                parent.onScrollIntent(.collapsed)
            } else if normalizedOffset(for: scrollView) <= nearTopOffset {
                parent.onScrollIntent(.nearTop)
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard parent.isEnabled else { return false }
            guard let recognizer = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            guard let scrollView else { return false }

            let location = recognizer.location(in: scrollView)
            let visibleBounds = CGRect(origin: .zero, size: scrollView.bounds.size)
            guard visibleBounds.contains(location) else { return false }

            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard gestureRecognizer === panRecognizer else { return false }
            guard let scrollView else { return false }
            return otherGestureRecognizer === scrollView.panGestureRecognizer
        }

        private func emitOffsetChange(from scrollView: UIScrollView) {
            guard parent.isEnabled else { return }
            parent.onOffsetChange(normalizedOffset(for: scrollView))
        }

        private func normalizedOffset(for scrollView: UIScrollView) -> CGFloat {
            max(0, scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
        }
    }
}

private extension UIView {
    func nearestSunriseHomeSuperview<T: UIView>(of type: T.Type) -> T? {
        var view = superview
        while let current = view {
            if let match = current as? T {
                return match
            }
            view = current.superview
        }
        return nil
    }
}
#endif

enum SunriseHomeContentScope: String, CaseIterable, Sendable {
    case all
    case meetings
    case tasks
    case habits

    var showsTimeline: Bool {
        self != .habits
    }

    var showsHabits: Bool {
        self == .all || self == .habits
    }

    var showsCalendarState: Bool {
        self == .all || self == .meetings
    }

    var showsHabitState: Bool {
        self == .all || self == .habits
    }

    var includesStructuralTimelineRows: Bool {
        self == .all
    }

    var includesAssistantGaps: Bool {
        self == .all
    }

    func includesTimelineItem(_ item: TimelinePlanItem) -> Bool {
        switch self {
        case .all:
            return true
        case .meetings:
            return item.source == .calendarEvent || item.isMeetingLike
        case .tasks:
            return item.source == .task && item.isMeetingLike == false
        case .habits:
            return false
        }
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
