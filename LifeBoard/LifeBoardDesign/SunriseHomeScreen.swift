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
    let onCycleHabit: (HomeHabitRow) -> Void
    let onAddHabit: () -> Void
    let onAddTask: (Date?) -> Void
    let onRequestCalendarPermission: () -> Void
    let onOpenCalendarChooser: () -> Void
    let onRetryCalendar: () -> Void
    let onTimelineItemTap: (TimelinePlanItem) -> Void
    let onTimelineItemToggleComplete: (TimelinePlanItem) -> Void
    let onAnchorTap: (TimelineAnchorItem) -> Void
    let onScrollStateChange: (HomeScrollChromeState) -> Void
    let onSelectLens: (HomeLens) -> Void
    let onManageLenses: () -> Void
    let onStreamTaskTap: (TaskDefinition) -> Void
    let onStreamTaskToggleComplete: (TaskDefinition) -> Void
    let onDayCompassPrimary: (DayCompassState) -> Void
    let onDayCompassSnooze: (DayCompassFlow) -> Void
    let onOpenRescue: () -> Void
    let focusContent: AnyView?

    @State private var isScrollActive = false
    @State private var scrollStopTask: Task<Void, Never>?
    @State private var scrollChromeStateTracker = HomeScrollChromeStateTracker()
    @State private var lastScrollOffsetY: CGFloat?
    @State private var lastEmittedScrollChromeState: HomeScrollChromeState?
    @State private var selectedContentScope: SunriseHomeContentScope = .all
    @State private var headerActivationID = TimeOfDayHeaderAsset.makeActivationID()
    @State private var leadingDaySunriseSwipeData = SunriseDaySwipeData(side: .leading)
    @State private var trailingDaySunriseSwipeData = SunriseDaySwipeData(side: .trailing)
    @State private var topDaySunriseSwipeSide: SunriseDaySwipeSide = .trailing
    @State private var activeDaySunriseSwipeSide: SunriseDaySwipeSide?
    @State private var isDaySunriseSwipeChromeVisible = true
    @State private var committedDaySwipeDirection: HomeDayNavigationDirection?
    @State private var completionBurstRowID: String?
    @State private var completionBurstTrigger = 0
    @State private var pendingCompletionBurst: PendingCompletionBurst?
    @State private var pendingCompletionBurstExpiryTask: Task<Void, Never>?
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
                                onScrollIntent: handleScrollChromeState
                            )
                        }
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    }
                    .lifeboardScrollOptimizedRendering(isScrollActive)
                    .transaction { transaction in
                        if isScrollActive {
                            transaction.animation = nil
                        }
                    }
                }
                .coordinateSpace(name: "sunriseHomeScroll")
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("home.view")
                .ignoresSafeArea(edges: .top)
                .simultaneousGesture(scrollIntentGesture)
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
                        subtitle: chrome.lifeAreaLensHeader?.subtitle(referenceDate: timeline.date) ?? context.greeting,
                        heroTitleColor: context.foregroundStyle.titleColor,
                        heroSubtitleColor: context.foregroundStyle.controlColor,
                        chromeControlColor: context.foregroundStyle.controlColor,
                        chromeGlassFill: context.foregroundStyle.glassFill.opacity(0.72),
                        chromeGlassStroke: context.foregroundStyle.glassStroke.opacity(0.72),
                        navigatorColor: context.foregroundStyle.controlColor,
                        navigatorTitle: LBHeaderTimeContext.navigatorTitle(selectedDate: chrome.selectedDate, now: timeline.date),
                        navigatorGlassFill: context.foregroundStyle.glassFill,
                        navigatorGlassStroke: context.foregroundStyle.glassStroke,
                        isOnNonTodayLens: activeLens != .today,
                        backToTodayColor: LBColorTokens.sunriseGold,
                        hasNotifications: false,
                        hasActiveFilters: chrome.activeFilterState.hasActiveFilters
                    ),
                    headerHeight: headerHeight,
                    safeAreaTop: safeAreaTop,
                    onMenu: onOpenSettings,
                    onSearch: onOpenSearch,
                    onDateTap: onShowDatePicker,
                    onBackToToday: {
                        LifeBoardFeedback.selection()
                        onSelectLens(.today)
                    }
                )
            }
        }
        .onChange(of: timeline.day.plottedTimelineItems) { _, items in
            guard let pendingCompletionBurst,
                  items.contains(where: { $0.taskID == pendingCompletionBurst.taskID && $0.isComplete }) else { return }
            pendingCompletionBurstExpiryTask?.cancel()
            self.pendingCompletionBurst = nil
            completionBurstRowID = pendingCompletionBurst.rowID
            completionBurstTrigger += 1
        }
    }

    private func daySunriseSwipeOverlay(safeAreaTop: CGFloat) -> some View {
        SunriseDaySwipeOverlay(
            isEnabled: isDaySwipeChromeEnabled,
            isChromeVisible: isDaySunriseSwipeChromeVisible,
            reduceMotion: LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion),
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

    private var isDaySwipeChromeEnabled: Bool {
        isDaySwipeEnabled
    }

    private var isDaySwipeInteractionEnabled: Bool {
        isShellInteractive && isDaySwipeInteractive && isDaySunriseSwipeChromeVisible
    }

    private var daySwipeAnimation: Animation {
        if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) {
            return .easeOut(duration: 0.12)
        }
        return .snappy(duration: 0.22)
    }

    private var daySwipeTransition: AnyTransition {
        guard LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false else {
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

    /// When the day compass card is shown it carries the header clearance, so the
    /// chip row only needs a normal gap beneath it. Otherwise the chip row is the
    /// first element and must clear the header itself.
    private var chipRowTopPadding: CGFloat {
        chrome.dayCompass == nil ? filterRowTopPadding : LBSpacingTokens.xs
    }

    private var content: some View {
        VStack(spacing: LBSpacingTokens.xxs) {
            if let dayCompass = chrome.dayCompass {
                LBDayCompassCard(
                    model: dayCompass,
                    onPrimary: onDayCompassPrimary,
                    onSnooze: onDayCompassSnooze
                )
                .padding(.top, filterRowTopPadding)
                .padding(.bottom, LBSpacingTokens.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            homeChipRow
                .onChange(of: activeLens) { _, newLens in
                    if newLens == .today {
                        selectedContentScope = .all
                    }
                }

            if isStreamLens {
                streamContent
            } else {
                stateCards

                if let focusContent {
                    focusContent
                }

                if let rescueTailState {
                    rescueEntryCard(rescueTailState)
                }

                if selectedContentScope.showsTimeline {
                    timelineContent
                }

                if selectedContentScope.showsHabits {
                    habitContent
                }
            }
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
    }

    private var rescueTailState: RescueTailState? {
        tasks.agendaTailItems.lazy.compactMap { item in
            guard case .rescue(let state) = item else { return nil }
            return state
        }.first
    }

    private func rescueEntryCard(_ state: RescueTailState) -> some View {
        let style = LBColorTokens.role(.warning)
        return Button(action: onOpenRescue) {
            LBGlassCard(
                cornerRadius: LBRadiusTokens.card,
                borderColor: style.border.opacity(0.72),
                fill: style.softSurface.opacity(0.48),
                shadow: nil,
                usesMaterialBackground: false
            ) {
                HStack(spacing: LBSpacingTokens.md) {
                    Image(systemName: style.symbolName)
                        .font(LBTypographyTokens.bodyStrong)
                        .foregroundStyle(style.deep)
                        .frame(width: 34, height: 34)
                        .background(style.softSurface.opacity(0.82), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: LBSpacingTokens.xxs) {
                        Text(String(localized: "Rescue available"))
                            .font(LBTypographyTokens.cardTitle)
                            .foregroundStyle(LBColorTokens.navy)

                        Text(state.subtitle)
                            .font(LBTypographyTokens.meta)
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .accessibilityHidden(true)
                }
                .padding(LBSpacingTokens.md)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.rescue.open")
        .accessibilityLabel("Open Overdue Rescue")
        .accessibilityValue(state.subtitle)
        .accessibilityHint("Review overdue tasks that still need a decision")
    }

    // MARK: - Unified chip rail

    private var lifeAreaChips: [HomeLensChip] {
        HomeLensResolver.lifeAreaLenses(
            lifeAreas: tasks.lifeAreas,
            pinnedLifeAreaIDs: chrome.activeFilterState.pinnedLifeAreaIDs,
            activeLens: activeLens,
            activityByID: tasks.lifeAreaLensActivity
        )
    }

    private var homeChipRailItems: [HomeChipRailItem] {
        HomeChipRailBuilder.build(
            activeLens: activeLens,
            lifeAreaChips: lifeAreaChips,
            selectedContentScope: selectedContentScope,
            hasActiveFilters: chrome.activeFilterState.hasActiveFilters
        )
    }

    private var homeChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LBSpacingTokens.xs) {
                ForEach(homeChipRailItems) { item in
                    homeChipRailItemView(item)
                }
            }
            .padding(.horizontal, LBSpacingTokens.screenMargin)
        }
        .accessibilityIdentifier("home.sunrise.chipRail")
        .padding(.horizontal, -LBSpacingTokens.screenMargin)
        .padding(.top, chipRowTopPadding)
    }

    @ViewBuilder
    private func homeChipRailItemView(_ item: HomeChipRailItem) -> some View {
        switch item {
        case .lens(let chip):
            LBFilterChip(
                model: LBFilterChip.Model(
                    id: chip.id,
                    title: chip.title,
                    systemImage: chip.systemImage,
                    isSelected: chip.isSelected,
                    leadingDotHex: chip.tintHex,
                    accessibilityID: "home.sunrise.lens.\(chip.id)"
                )
            ) {
                onSelectLens(chip.lens)
            }
        case .separator:
            LBChipRailSeparator()
        case .todayFacet(let scope):
            LBFilterChip(model: HomeChipRailBuilder.todayFacetChipModel(for: scope, isSelected: selectedContentScope == scope)) {
                selectedContentScope = scope
            }
        case .manageLifeAreas:
            LBFilterChip(model: HomeChipRailBuilder.manageLifeAreasChipModel()) {
                onManageLenses()
            }
        case .advancedFilters(let hasActiveFilters):
            LBFilterChip(model: HomeChipRailBuilder.advancedFiltersChipModel(hasActiveFilters: hasActiveFilters)) {
                onShowAdvancedFilters()
            }
        }
    }

    private var activeLens: HomeLens {
        HomeLensResolver.activeLens(for: chrome.activeFilterState)
    }

    private var isStreamLens: Bool {
        chrome.activeFilterState.streamsAllForward
    }

    // MARK: - Forward stream (Upcoming / per-life-area lenses)

    @ViewBuilder
    private var streamContent: some View {
        let sections = tasks.todayAgendaSectionState.sections
        if sections.isEmpty {
            let empty = streamEmptyStateModel
            LBEmptyState(model: empty.model, action: empty.action)
                .padding(.top, LBSpacingTokens.md)
        } else {
            LazyVStack(spacing: LBSpacingTokens.sm) {
                lifeAreaTodayTimelineStrip

                ForEach(sections) { section in
                    HomeListSectionView(
                        section: section,
                        tagNameByID: tasks.tagNameByID,
                        projectsByID: tasks.projectsByID,
                        lifeAreasByID: tasks.lifeAreasByID,
                        todayXPSoFar: tasks.todayXPSoFar,
                        isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
                        isTaskDragEnabled: false,
                        highlightedTaskID: nil,
                        completedCollapsed: true,
                        layoutStyle: .edgeToEdgeHome,
                        onTaskTap: onStreamTaskTap,
                        onToggleComplete: onStreamTaskToggleComplete
                    )
                }
            }
            .padding(.top, LBSpacingTokens.sm)
        }
    }

    @ViewBuilder
    private var lifeAreaTodayTimelineStrip: some View {
        if case .lifeArea(let lifeAreaID) = activeLens {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let rows = lifeAreaTodayTimelineRows(lifeAreaID: lifeAreaID, now: context.date)
                if rows.isEmpty == false {
                    LazyVStack(spacing: LBSpacingTokens.xs) {
                        ForEach(rows.prefix(4)) { row in
                            if case .item(let item) = row.kind {
                                LBTimelineCard(
                                    model: timelineCardModel(
                                        for: item,
                                        temporalState: row.temporalState(now: context.date),
                                        now: context.date,
                                        nextUpcomingCalendarItemID: nil
                                    ),
                                    onTap: { onTimelineItemTap(item) }
                                )
                                .equatable()
                            }
                        }
                    }
                    .padding(.bottom, LBSpacingTokens.xs)
                }
            }
        }
    }

    private func lifeAreaTodayTimelineRows(lifeAreaID: UUID, now: Date) -> [SunriseTimelineRow] {
        let calendar = Calendar.current
        guard calendar.isDateInToday(chrome.selectedDate) || calendar.isDateInToday(now) else { return [] }
        let allRows = timelineRows(now: now)
        return allRows.filter { row in
            switch row.kind {
            case .item(let item):
                guard let taskID = item.taskID else { return item.source == .calendarEvent }
                return streamTaskMatchesLifeArea(taskID: taskID, lifeAreaID: lifeAreaID)
            default:
                return false
            }
        }
    }

    private func streamTaskMatchesLifeArea(taskID: UUID, lifeAreaID: UUID) -> Bool {
        for section in tasks.todayAgendaSectionState.sections {
            for row in section.rows {
                if case .task(let task) = row, task.id == taskID {
                    if task.lifeAreaID == lifeAreaID { return true }
                    if let projectLifeArea = tasks.projectsByID[task.projectID]?.lifeAreaID,
                       projectLifeArea == lifeAreaID {
                        return true
                    }
                }
            }
        }
        return false
    }

    private var streamEmptyStateModel: (model: LBEmptyState.Model, action: () -> Void) {
        let message = tasks.emptyStateMessage ?? "Nothing here yet. Add a meaningful next step when you're ready."
        let title: String
        switch activeLens {
        case .today:
            title = "Nothing here yet"
        case .upcoming:
            title = "Nothing coming up"
        case .lifeArea:
            title = "All clear in this area"
        }
        return (
            LBEmptyState.Model(
                title: title,
                message: message,
                actionTitle: "Add a task",
                systemImage: "checkmark.circle",
                actionSystemImage: "plus"
            ),
            { onAddTask(nil) }
        )
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
                    ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, row in
                        let temporalState = row.temporalState(now: context.date)
                        Group {
                    switch row.kind {
                    case .anchor(let anchor):
                        let anchorRole = role(for: anchor)
                        LBTimelineItem(
                            timeText: timeText(anchor.time),
                            role: anchorRole,
                            temporalState: temporalState,
                            spineIconSystemName: spineIconSystemName(for: anchor)
                        ) {
                            LBTimelineCard(
                                model: LBTimelineCard.Model(
                                    id: anchor.id,
                                    title: anchorTitle(for: anchor),
                                    subtitle: anchor.subtitle ?? routineSubtitle(for: LBHeaderTimeContext.resolve(selectedDate: chrome.selectedDate).period),
                                    timeText: timeText(anchor.time),
                                    role: anchorRole,
                                    kind: .anchor,
                                    tintHex: nil,
                                    accessoryText: nil,
                                    temporalState: temporalState,
                                    isCompleted: false,
                                    isCurrent: temporalState == .current
                                ),
                                onTap: { onAnchorTap(anchor) }
                            )
                            .equatable()
                        }
                    case .item(let item):
                        let kind = cardKind(for: item)
                        let taskToggleAction: (() -> Void)? = item.taskID == nil ? nil : {
                            let interval = LifeBoardPerformanceTrace.begin("HomeTimelineTaskToggle")
                            if let taskID = item.taskID, item.isComplete == false, isFirstCompletionOfDay {
                                pendingCompletionBurst = PendingCompletionBurst(rowID: row.id, taskID: taskID)
                                pendingCompletionBurstExpiryTask?.cancel()
                                pendingCompletionBurstExpiryTask = Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                                    guard Task.isCancelled == false else { return }
                                    pendingCompletionBurst = nil
                                }
                            }
                            onTimelineItemToggleComplete(item)
                            LifeBoardPerformanceTrace.end(interval)
                        }
                        LBTimelineItem(
                            timeText: timeText(item.startDate),
                            role: role(for: item),
                            tintHex: kind == .task ? item.tintHex : nil,
                            temporalState: temporalState,
                            spineIconSystemName: spineIconSystemName(for: item, kind: kind),
                            spineIconAccessibilityLabel: item.isComplete ? "Reopen \(item.title)" : "Complete \(item.title)",
                            spineIconAccessibilityValue: item.isComplete ? "Completed" : "Not completed",
                            spineIconAction: kind == .task ? taskToggleAction : nil,
                            spineIconIsCompleted: kind == .task ? item.isComplete : nil
                        ) {
                            LBTimelineCard(
                                model: timelineCardModel(
                                    for: item,
                                    temporalState: temporalState,
                                    now: context.date,
                                    nextUpcomingCalendarItemID: nextUpcomingCalendarItemID
                                ),
                                onTap: { onTimelineItemTap(item) }
                            )
                            .equatable()
                        }
                    case .meetingFlock(let model, let sourceItems):
                        LBTimelineItem(
                            timeText: model.timeRange.components(separatedBy: " – ").first ?? model.timeRange,
                            role: .meeting,
                            temporalState: temporalState,
                            spineIconSystemName: "calendar"
                        ) {
                            LBMeetingFlockCard(model: model) { meeting in
                                if let item = sourceItems.first(where: { $0.id == meeting.id }) {
                                    onTimelineItemTap(item)
                                }
                            }
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
                        .cardEntrance(index: rowIndex)
                        .lbCelebrationBurst(
                            trigger: completionBurstRowID == row.id ? completionBurstTrigger : 0
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var habitContent: some View {
        SunriseHabitGridCard(
            rows: habitRowModels,
            onOpenHabitBoard: onOpenHabitBoard,
            onCycleHabit: { model in
                onCycleHabit(model.sourceRow)
            },
            onAddHabit: onAddHabit
        )
        .equatable()
        .padding(.top, LBSpacingTokens.xs)
        .padding(.bottom, LBSpacingTokens.xxl)
        .transaction { transaction in
            // Stay static while scrolling; let check-in interactions animate.
            if isScrollActive || LifeBoardAnimation.isUITesting {
                transaction.animation = nil
            }
        }
    }

    private var timelineEmptyStateModel: (model: LBEmptyState.Model, action: () -> Void) {
        switch selectedContentScope {
        case .all:
            return (
                LBEmptyState.Model(
                    title: "A quiet day",
                    message: "Want to shape it?",
                    actionTitle: "Add task",
                    systemImage: "sun.max"
                ),
                { onAddTask(chrome.selectedDate) }
            )
        case .meetings:
            return (
                LBEmptyState.Model(
                    title: "No meetings today",
                    message: "The calendar is clear here.",
                    actionTitle: "Choose calendars",
                    systemImage: "calendar",
                    actionSystemImage: "calendar.badge.checkmark"
                ),
                onOpenCalendarChooser
            )
        case .tasks:
            return (
                LBEmptyState.Model(
                    title: "No tasks here",
                    message: "Nothing matches the current filters.",
                    actionTitle: "Add task",
                    systemImage: "checkmark.square"
                ),
                { onAddTask(chrome.selectedDate) }
            )
        case .habits:
            return (
                LBEmptyState.Model(
                    title: "No habits yet",
                    message: "Start with one small rhythm.",
                    actionTitle: "Open Habit Board",
                    systemImage: "heart",
                    actionSystemImage: "arrow.right"
                ),
                onOpenHabitBoard
            )
        }
    }

    nonisolated static func filterChipModels(selectedContentScope: SunriseHomeContentScope, hasActiveFilters: Bool = false) -> [LBFilterChip.Model] {
        SunriseHomeContentScope.allCases.map {
            HomeChipRailBuilder.todayFacetChipModel(for: $0, isSelected: selectedContentScope == $0)
        } + [HomeChipRailBuilder.advancedFiltersChipModel(hasActiveFilters: hasActiveFilters)]
    }

    nonisolated static func todayFacetChipModels(selectedContentScope: SunriseHomeContentScope) -> [LBFilterChip.Model] {
        SunriseHomeContentScope.allCases.map {
            HomeChipRailBuilder.todayFacetChipModel(for: $0, isSelected: selectedContentScope == $0)
        }
    }

    /// True while no plotted timeline item is complete yet — gates the
    /// celebration burst to the first completion of the day.
    private var isFirstCompletionOfDay: Bool {
        timeline.day.plottedTimelineItems.allSatisfy { $0.isComplete == false }
    }

    func timelineRows(now: Date) -> [SunriseTimelineRow] {
        let interval = LifeBoardPerformanceTrace.begin("HomeTimelineRowsBuild")
        defer { LifeBoardPerformanceTrace.end(interval) }
        return Self.buildTimelineRows(
            wakeAnchor: timeline.day.wakeAnchor,
            sleepAnchor: timeline.day.sleepAnchor,
            plottedItems: timeline.day.plottedTimelineItems,
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

        // Open time reads as restful, not unfinished: the assistant gap prompt
        // was removed from the timeline in the Sunrise Glass polish pass.

        if contentScope.includesStructuralTimelineRows {
            rows.append(.anchor(sleepAnchor))
        }

        return Self.sortedRows(rows, now: now)
    }

    private var visibleHabitRows: [HomeHabitRow] {
        let interval = LifeBoardPerformanceTrace.begin("HomeHabitModelsBuild")
        defer { LifeBoardPerformanceTrace.end(interval) }
        return Array(
            (
                habits.habitHomeSectionState.primaryRows
                + habits.habitHomeSectionState.recoveryRows
            ).prefix(8)
        )
    }

    private var habitRowModels: [SunriseHabitGridRowModel] {
        visibleHabitRows.map(habitRowModel(for:))
    }

    private func habitRowModel(for row: HomeHabitRow) -> SunriseHabitGridRowModel {
        let interaction = HomeHabitLastCellInteraction.resolve(for: row)
        return SunriseHabitGridRowModel(
            habitID: row.habitID,
            sourceRow: row,
            title: row.title,
            cellModel: habitCellModel(for: row),
            currentStateText: interaction.currentStateText,
            nextActionText: interaction.nextActionText,
            nextAction: interaction.action
        )
    }

    private func habitCellModel(for row: HomeHabitRow) -> LBHabitCell.Model {
        let cells = Array((row.boardCellsCompact.isEmpty ? row.boardCellsExpanded : row.boardCellsCompact).suffix(7))
        let doneCount = cells.filter { cell in
            if case .done = cell.state { return true }
            return false
        }.count
        return LBHabitCell.Model(
            id: row.habitID.uuidString,
            title: row.title,
            systemImage: row.iconSymbolName,
            color: Color(lifeboardHex: row.accentHex ?? HabitColorFamily.family(for: row.accentHex).canonicalHex),
            completionRatio: cells.isEmpty ? 0 : Double(doneCount) / Double(cells.count),
            dayLabels: Self.dayLabels(for: cells),
            cells: cells.map(LBHabitCell.CellState.init),
            allowsTwoLineTitle: true
        )
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
            tintHex: kind == .task ? item.tintHex : nil,
            accessoryText: nil,
            temporalState: temporalState,
            isCompleted: item.isComplete,
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

    private func spineIconSystemName(for anchor: TimelineAnchorItem) -> String {
        anchor.id == "sleep" ? "moon.fill" : "sun.max.fill"
    }

    private func spineIconSystemName(for item: TimelinePlanItem, kind: LBTimelineCard.Kind) -> String {
        if kind == .calendar {
            return "calendar"
        }
        return item.isComplete ? "checkmark.square.fill" : "checkmark.square"
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
        if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) {
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
        if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) {
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
        LifeBoardPerformanceTrace.event("HomeScrollActive", value: active ? 1 : 0)
        LifeBoardPerformanceTrace.event("HomeFlattenedRenderMode", value: active ? 1 : 0)
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
        guard offset.isFinite else { return }
        let normalizedOffset = max(0, offset)
        if let lastScrollOffsetY,
           normalizedOffset >= 40,
           abs(normalizedOffset - lastScrollOffsetY) < 4 {
            return
        }
        lastScrollOffsetY = normalizedOffset

        if let nextState = scrollChromeStateTracker.consume(offset: normalizedOffset) {
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
        guard lastEmittedScrollChromeState != state else { return }
        lastEmittedScrollChromeState = state
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
        if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) {
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
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard parent.isEnabled, let scrollView else { return }

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

private struct SunriseHabitGridRowModel: Identifiable, Equatable {
    let habitID: UUID
    let sourceRow: HomeHabitRow
    let title: String
    let cellModel: LBHabitCell.Model
    let currentStateText: String
    let nextActionText: String
    let nextAction: HomeHabitLastCellAction

    var id: UUID { habitID }
    var accessibilityIdentifier: String { "home.habits.row.\(habitID.uuidString)" }
    var accessibilityValue: String { "\(currentStateText). Next: \(nextActionText)." }
    var accessibilityHint: String { "Double-tap to \(nextActionText.lowercased())." }
}

private struct SunriseHabitGridCard: View, Equatable {
    let rows: [SunriseHabitGridRowModel]
    let onOpenHabitBoard: () -> Void
    let onCycleHabit: (SunriseHabitGridRowModel) -> Void
    let onAddHabit: () -> Void
    @Environment(\.lifeboardScrollOptimizedRendering) private var scrollOptimizedRendering

    nonisolated static func == (lhs: SunriseHabitGridCard, rhs: SunriseHabitGridCard) -> Bool {
        lhs.rows == rhs.rows
    }

    var body: some View {
        ZStack {
            LBGlassCard(cornerRadius: LBRadiusTokens.largeCard) {
                VStack(spacing: LBSpacingTokens.md) {
                    HStack {
                        LBSectionHeader(title: "Habits", systemImage: "chart.bar")
                        Spacer()
                        Button("View All Habits", action: onOpenHabitBoard)
                            .font(LBTypographyTokens.meta)
                            .foregroundStyle(LBColorTokens.violetDeep)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.habits.openBoard")
                    }

                    if rows.isEmpty {
                        emptyState
                    } else {
                        ForEach(rows) { row in
                            SunriseHabitGridRow(model: row, onCycleHabit: onCycleHabit)
                                .equatable()
                        }
                    }
                }
                .padding(LBSpacingTokens.lg)
            }

            Color.clear
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityIdentifier("home.habits.grid")
                .accessibilityLabel("Habits grid")
        }
        .transaction { transaction in
            // Stay static while scrolling; let check-in interactions animate.
            if scrollOptimizedRendering || LifeBoardAnimation.isUITesting {
                transaction.animation = nil
            }
        }
    }

    private var emptyState: some View {
        let style = LBColorTokens.role(.personal)
        return Button(action: onAddHabit) {
            HStack(alignment: .center, spacing: LBSpacingTokens.sm) {
                Image(systemName: "heart")
                    .font(LBTypographyTokens.bodyStrong)
                    .foregroundStyle(style.deep)
                    .frame(width: 34, height: 34)
                    .background(style.softSurface.opacity(0.8), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Start with one small rhythm.")
                        .font(LBTypographyTokens.bodyStrong)
                        .foregroundStyle(LBColorTokens.navy)
                    Text("Create habit")
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(LBColorTokens.violetDeep)
                }
                Spacer(minLength: LBSpacingTokens.sm)
            }
            .padding(LBSpacingTokens.md)
            .background(style.softSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: LBRadiusTokens.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: LBRadiusTokens.card, style: .continuous)
                    .stroke(style.border.opacity(0.68), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.habits.addHabit")
        .accessibilityLabel("Create habit")
    }
}

private struct SunriseHabitGridRow: View, Equatable {
    let model: SunriseHabitGridRowModel
    let onCycleHabit: (SunriseHabitGridRowModel) -> Void

    nonisolated static func == (lhs: SunriseHabitGridRow, rhs: SunriseHabitGridRow) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        Button {
            let interval = LifeBoardPerformanceTrace.begin("HomeHabitLastCellTap")
            // Explicit completion earns the success haptic; every other
            // cycle step stays light, per the design-doc haptic budget.
            if model.nextAction == .complete {
                LifeBoardFeedback.success()
            } else {
                LifeBoardFeedback.light()
            }
            onCycleHabit(model)
            LifeBoardPerformanceTrace.end(interval)
        } label: {
            LBHabitCell(model: model.cellModel)
                .equatable()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(model.accessibilityIdentifier)
        .accessibilityLabel(model.title)
        .accessibilityValue(model.accessibilityValue)
        .accessibilityHint(model.accessibilityHint)
    }
}

private struct PendingCompletionBurst: Equatable {
    let rowID: String
    let taskID: UUID
}

enum SunriseTimelineRow: Identifiable {
    case anchor(TimelineAnchorItem)
    case item(TimelinePlanItem)
    case meetingFlock(LBMeetingFlockCard.Model, [TimelinePlanItem])
    case now(Date)

    var id: String {
        switch self {
        case .anchor(let anchor): return "anchor-\(anchor.id)"
        case .item(let item): return "item-\(item.id)"
        case .meetingFlock(let model, _): return model.id
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
        }
    }

    func sortDate(now: Date) -> Date {
        displayDate ?? now
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
        }
    }
}
