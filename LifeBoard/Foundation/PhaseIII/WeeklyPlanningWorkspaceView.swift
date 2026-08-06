import SwiftUI

/// One line of "here is what just happened", with its own identity.
///
/// Identity rather than message text: two identical consecutive receipts used to
/// cancel each other's dismissal timer.
struct WorkspaceReceipt: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let undoToken: WeeklyWorkspaceUndoToken?
}

/// "This week" — one surface for placing work across the days of a week.
///
/// Replaces both halves of a split that made weekly planning impossible: a Week
/// tab with seven day cards you could not put anything into, and a four-step
/// wizard that sorted tasks into `thisWeek`/`nextWeek`/`later` and never knew
/// what a Wednesday was.
///
/// The ribbon sits in the *middle* of the screen rather than the top. It is the
/// day selector, the drop target and the load gauge all at once, so it and the
/// tray rows that feed it both have to fall under the thumb. A ribbon at the top
/// puts the two halves of every single interaction at opposite ends of the
/// phone, which is what makes a placement flow feel like work.
///
/// Nothing here stages. Every placement is written immediately through
/// `PlanStore`'s receipt path and is one Undo away, so there is no draft to
/// recover, no commit to forget, and no state where a task exists but its
/// placement does not.
struct WeeklyPlanningWorkspaceView: View {
    @Bindable var store: PlanStore
    var onClose: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var lane: WeeklyWorkspaceLane = .inbox
    @State private var composerText = ""
    @State private var selection: Set<UUID> = []
    @State private var isSelecting = false
    @State private var showsBriefing: Bool
    @State private var showsIntention = false
    @State private var showsSoftDays = false
    @State private var receipt: WorkspaceReceipt?
    @State private var receiptDismissal: Task<Void, Never>?
    @State private var pulsedDay: PlanningDay?
    @State private var pulseDismissal: Task<Void, Never>?
    @State private var pendingBankruptcy = false
    @State private var meetingOverrides: [String: WeeklyMeetingIntent] = [:]
    @State private var shelfDetent: WeeklyWorkspaceShelfDetent = .medium
    @State private var shelfDragOffset: CGFloat = 0
    @State private var traySearch = ""
    @State private var showsCompletion = false
    @State private var calendarHandoff: CalendarEventHandoff?
    @State private var sessionSummary = WeeklyWorkspaceSessionSummary()
    @State private var motionEvent: WeeklyWorkspaceMotionEvent = .workspaceEntered
    @State private var landingTrigger = 0
    @State private var triageTrigger = 0
    @State private var completionTrigger = 0
    @State private var ribbonRefractStrength = 0.0
    @State private var pendingPlacements: [UUID: PlanningDay] = [:]
    @State private var pendingMutationIDs: Set<UUID> = []
    @State private var composerRetryIDs: [String: UUID] = [:]
    @State private var hoveredTaskID: UUID?
    @State private var dropHoverTask: Task<Void, Never>?
    @State private var targetedDay: PlanningDay?
    @State private var mutationCoordinator = WeeklyWorkspaceMutationCoordinator()
    @FocusState private var composerFocused: Bool
    @Namespace private var placementNamespace
    /// The weekly plan's own focus statement and outcomes.
    ///
    /// Reuses `WeeklyPlannerViewModel` rather than reimplementing the weekly
    /// plan's persistence. What the wizard actually owned that was worth keeping
    /// was this model, not its four steps — so the steps go and the model stays.
    @StateObject private var intention: WeeklyPlannerViewModel

    private let decisions = WeeklyMeetingDecisionStore()

    init(store: PlanStore, entry: WeeklyPlanningEntry, onClose: (() -> Void)? = nil) {
        self.store = store
        self.onClose = onClose
        _showsBriefing = State(initialValue: entry == .overdue)
        _lane = State(initialValue: entry == .overdue ? .overdue : .inbox)
        _intention = StateObject(
            wrappedValue: PresentationDependencyContainer.shared.makeWeeklyPlannerViewModel()
        )
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if usesWideWeekBoard(width: geometry.size.width) {
                    wideWeekLayout
                } else if usesSideBySideLayout {
                    focusedPadLayout
                } else {
                    phoneLayout(availableHeight: geometry.size.height)
                }
            }
        }
        // Paper grain belongs to the canvas plane only. Applying a layer effect
        // to the whole workspace asks Metal to flatten seven columns, text,
        // controls and scrolling content into one oversized render surface; on
        // iPad that can fail to present while the accessibility tree remains
        // alive. Keeping it behind content is both cheaper and guarantees the
        // shader can never soften type or controls.
        .background {
            Color(LifeBoardColorTokens.foundationCanvas)
                .ignoresSafeArea()
                .lifeboardPaperGrain(intensity: 0.18)
        }
        .navigationTitle(WeeklyWorkspaceCopy.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("plan.week.workspace")
        .toolbar {
            if onClose != nil {
                ToolbarItem(placement: .confirmationAction) {
                    // Not a Save. Everything on this screen is already written;
                    // this ends the ritual and says what the week now looks
                    // like. A commit button here would imply the placements
                    // were provisional, which they never were.
                    Button("Done") {
                        showsCompletion = true
                    }
                    .accessibilityHint(ritualSummary)
                    .accessibilityIdentifier("plan.week.workspace.done")
                }
            }
        }
        .overlay(alignment: .bottom) { receiptToast }
        .sheet(isPresented: $showsBriefing) { briefingSheet }
        .sheet(isPresented: $showsCompletion) { completionSheet }
        .sheet(item: $calendarHandoff) { handoff in
            EventKitEventDetailView(
                eventID: handoff.eventID,
                onDismiss: { calendarHandoff = nil }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(LifeBoardColorTokens.foundationCanvas))
        }
        .confirmationDialog(
            WeeklyWorkspaceCopy.bankruptcyConfirmation(count: briefing.count),
            isPresented: $pendingBankruptcy,
            titleVisibility: .visible
        ) {
            Button(WeeklyWorkspaceCopy.bankruptcyAction, role: .destructive) {
                Task { await releaseOverdue() }
            }
            Button("Keep them", role: .cancel) {}
        }
        .task {
            meetingOverrides = decisions.intents(weekStart: weekStart)
            decisions.prune()
            if intention.hasLoadedInitialData == false { intention.load() }
            motionEvent = .workspaceEntered
        }
    }

    // MARK: Layout decisions

    /// iPad and Catalyst get the Todoist arrangement — a persistent source pane
    /// beside the week. At accessibility sizes the columns cannot hold readable
    /// rows, so the phone layout is used at any width.
    private var usesSideBySideLayout: Bool {
        horizontalSizeClass == .regular && dynamicTypeSize.isAccessibilitySize == false
    }

    private func usesWideWeekBoard(width: CGFloat) -> Bool {
        usesSideBySideLayout && width >= 1_100
    }

    private var focusedPadLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            tray
                .frame(width: 280)
            verticalHairline
            VStack(spacing: 0) {
                header
                ribbon
                dayLane
            }
        }
    }

    private var wideWeekLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            tray
                .frame(width: 280)
            verticalHairline
            VStack(spacing: 0) {
                header
                wideWeekBoard
            }
        }
        .accessibilityIdentifier("plan.week.workspace.wideBoardLayout")
    }

    private func phoneLayout(availableHeight: CGFloat) -> some View {
        let maximum = max(210, min(CGFloat(WeeklyWorkspaceShelfDetent.expanded.height), availableHeight * 0.58))
        let target = min(maximum, CGFloat(shelfDetent.height) + shelfDragOffset)
        return VStack(spacing: 0) {
            header
            dayLane
            ribbon
            tray
                .frame(height: max(154, target))
                .animation(
                    LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion)
                        ? nil
                        : LifeBoardAnimation.directManipulation,
                    value: shelfDetent
                )
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(weekRangeLabel)
                        .lifeboardFont(.title2)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                if briefing.isEmpty == false {
                    Button {
                        showsBriefing = true
                    } label: {
                        Label("\(briefing.count)", systemImage: "clock.badge.exclamationmark")
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(briefing.headline)
                    .accessibilityIdentifier("plan.week.workspace.overdueBadge")
                }
            }
            intentionDisclosure
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    /// The wizard's first two steps — direction and outcomes — reduced to one
    /// optional disclosure.
    ///
    /// Available, never in the way. The wizard made these a gate: you answered
    /// "what matters this week?" before you were allowed to touch a task. They
    /// are worth writing and worth nobody being forced to.
    private var intentionDisclosure: some View {
        DisclosureGroup(isExpanded: $showsIntention) {
            WeeklyIntentionSection(viewModel: intention)
                .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Text("What matters this week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                if showsIntention == false, let summary = intentionSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityIdentifier("plan.week.workspace.intention")
    }

    /// Collapsed, the disclosure still says whether there is anything in it —
    /// otherwise a week's stated focus is invisible unless you go looking.
    private var intentionSummary: String? {
        let focus = intention.trimmedFocusStatement
        if focus.isEmpty == false { return "· \(focus)" }
        let outcomes = intention.activeOutcomeDraftCount
        guard outcomes > 0 else { return nil }
        return outcomes == 1 ? "· 1 outcome" : "· \(outcomes) outcomes"
    }

    // MARK: Ribbon

    private var ribbon: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    ribbonContent
                }
            } else {
                ribbonContent
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Days of the week")
        .accessibilityIdentifier("plan.week.workspace.ribbon")
    }

    private var ribbonContent: some View {
        VStack(spacing: 5) {
            HStack(spacing: 4) {
                ForEach(visibleDays, id: \.self) { day in ribbonChip(day) }
            }
            if softDays.isEmpty == false {
                Button {
                    withAnimation(reduceMotion ? nil : LifeBoardAnimation.roleLocalState) {
                        showsSoftDays.toggle()
                    }
                } label: {
                    Label(
                        showsSoftDays ? "Show fewer days" : "Later this week (\(softDays.count))",
                        systemImage: showsSoftDays ? "chevron.up" : "chevron.down"
                    )
                    .font(.caption2.weight(.medium))
                    .frame(minHeight: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .accessibilityIdentifier("plan.week.workspace.softDaysToggle")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(reduceTransparency ? 1 : 0.08))
                .lifeboardLiquidGlassRefract(
                    center: ribbonSelectionCenter,
                    radius: 0.24,
                    strength: ribbonRefractStrength
                )
        }
        .lifeBoardSystemGlass(
            .regular,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous),
            interactive: false
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var ribbonSelectionCenter: UnitPoint {
        guard let index = visibleDays.firstIndex(of: store.selectedDay), visibleDays.isEmpty == false else {
            return .center
        }
        return UnitPoint(x: (CGFloat(index) + 0.5) / CGFloat(visibleDays.count), y: 0.42)
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color(LifeBoardColorTokens.foundationHairline))
            .frame(height: 0.5)
    }

    private var verticalHairline: some View {
        Rectangle()
            .fill(Color(LifeBoardColorTokens.foundationHairline))
            .frame(width: 0.5)
            .frame(maxHeight: .infinity)
    }

    private func ribbonChip(_ day: PlanningDay) -> some View {
        let metrics = self.metrics(for: day)
        let isSelected = day == store.selectedDay
        let canReceive = WeeklyPlanningHorizon.canReceivePlacement(day, today: store.todayPlanningDay())
        return Button {
            select(day)
        } label: {
            VStack(spacing: 3) {
                Text(weekdayInitial(day))
                    .font(.caption2.weight(.semibold))
                Text("\(day.day)")
                    .lifeboardFont(isSelected ? .bodyStrong : .body)
                loadBar(metrics)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        isSelected
                            ? Color(LifeBoardColorTokens.foundationSurfaceSelected)
                            : Color.clear
                    )
            }
            .overlay {
                if metrics.isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(LifeBoardColorTokens.foundationApricotAccent), lineWidth: 1.5)
                }
            }
            .foregroundStyle(
                canReceive
                    ? Color(LifeBoardColorTokens.inkPrimary)
                    : Color(LifeBoardColorTokens.inkTertiary)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .scaleEffect(pulsedDay == day && reduceMotion == false ? 1.08 : 1)
        .lifeBoardMotion(.deckSettle, value: pulsedDay)
        .dropDestination(for: String.self) { items, _ in
            guard canReceive else { return false }
            let ids = items.compactMap(UUID.init(uuidString:))
            guard ids.isEmpty == false else { return false }
            Task { await place(Set(ids), on: day) }
            return true
        } isTargeted: { targeted in
            updateDropHover(day: day, isTargeted: targeted && canReceive)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(dayAccessibilityLabel(day, metrics: metrics))
        .accessibilityHint(canReceive ? "Selects this day" : "This day has already passed")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("plan.week.workspace.day.\(day.year)-\(day.month)-\(day.day)")
    }

    /// The load bar. Colour carries no information on its own — every state it
    /// can be in is also in `metrics.summary`, which is what VoiceOver reads and
    /// what survives greyscale.
    private func loadBar(_ metrics: DayMetrics) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(LifeBoardColorTokens.metricRingTrack).opacity(0.5))
                Capsule()
                    .fill(
                        metrics.isOverCapacity
                            ? Color(LifeBoardColorTokens.foundationApricotAccent)
                            : Color(LifeBoardColorTokens.foundationSageAccent)
                    )
                    .frame(
                        width: min(
                            geometry.size.width,
                            geometry.size.width * metrics.drawnFraction
                        )
                    )
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 4)
        .accessibilityHidden(true)
    }

    // MARK: Wide week board

    private var wideWeekBoard: some View {
        GeometryReader { geometry in
            let columnWidth = max(110, (geometry.size.width - 48) / 7)
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(allDays, id: \.self) { day in
                        wideDayColumn(day)
                            .frame(width: columnWidth)
                    }
                }
                .frame(minHeight: max(520, geometry.size.height), alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .accessibilityIdentifier("plan.week.workspace.wideBoard")
    }

    private func wideDayColumn(_ day: PlanningDay) -> some View {
        let dayMetrics = metrics(for: day)
        let selected = day == store.selectedDay
        let canReceive = WeeklyPlanningHorizon.canReceivePlacement(
            day,
            today: store.todayPlanningDay()
        )
        let tasks = workspacePlannedTasks(on: day)
        let dayMeetings = meetings(on: day)
        return VStack(alignment: .leading, spacing: 0) {
            Button { select(day) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(shortDayName(day))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                    Text("\(day.day)")
                        .lifeboardFont(.title3)
                    loadBar(dayMetrics)
                    Text(dayMetrics.summary)
                        .font(.caption2)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minHeight: 92, alignment: .top)
            .padding(.horizontal, 10)
            .padding(.top, 10)

            if dayMeetings.isEmpty == false {
                hairline.padding(.horizontal, 8)
                ForEach(dayMeetings, id: \.occurrenceKey) { meeting in
                    wideMeetingRow(meeting)
                }
            }

            if tasks.isEmpty && dayMeetings.isEmpty {
                Text("Room to breathe")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 18)
            } else {
                ForEach(tasks) { task in
                    hairline.padding(.leading, 10)
                    wideTaskRow(task, day: day)
                }
            }

            if canReceive {
                Button {
                    select(day)
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(80))
                        composerFocused = true
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .accessibilityLabel("Add to \(shortDayName(day))")
            }
            Spacer(minLength: 12)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: targetedDay == day ? 24 : 18, style: .continuous)
                .fill(
                    selected
                        ? Color(LifeBoardColorTokens.foundationSurfaceSelected).opacity(0.72)
                        : Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.72)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: targetedDay == day ? 24 : 18, style: .continuous)
                .stroke(
                    targetedDay == day
                        ? Color(LifeBoardColorTokens.foundationApricotAccent)
                        : Color(LifeBoardColorTokens.foundationHairline),
                    lineWidth: targetedDay == day ? 1.5 : 0.7
                )
        }
        .padding(.vertical, targetedDay == day ? 0 : 6)
        .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: targetedDay)
        .dropDestination(for: String.self) { items, _ in
            guard canReceive else { return false }
            let ids = Set(items.compactMap(UUID.init(uuidString:)))
            guard ids.isEmpty == false else { return false }
            Task { await place(ids, on: day) }
            return true
        } isTargeted: { targeted in
            targetedDay = targeted && canReceive ? day : nil
            updateDropHover(day: day, isTargeted: targeted && canReceive)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.week.workspace.column.\(day.year)-\(day.month)-\(day.day)")
    }

    private func wideTaskRow(_ task: PlanningTaskSummary, day: PlanningDay) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "circle")
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                .padding(.top, 2)
            Text(task.title)
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .matchedGeometryEffect(id: task.id, in: placementNamespace, isSource: false)
        .draggable(task.id.uuidString)
        .accessibilityLabel(task.title)
    }

    private func wideMeetingRow(_ meeting: DayMeeting) -> some View {
        HStack(alignment: .top, spacing: 5) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeLabel(meeting.commitment))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                Text(meeting.commitment.title)
                    .font(.caption)
                    .foregroundStyle(
                        meeting.intent == .skipping
                            ? Color(LifeBoardColorTokens.inkTertiary)
                            : Color(LifeBoardColorTokens.inkPrimary)
                    )
                    .strikethrough(meeting.intent == .skipping)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Menu {
                Button("In my week") { chooseMeetingIntent(.attending, for: meeting) }
                Button("Skip this week") { chooseMeetingIntent(.skipping, for: meeting) }
                if WeeklyMeetingPolicy.offersCalendarHandoff(
                    participation: meeting.commitment.participation ?? .unknown
                ), let eventID = meeting.commitment.seriesID {
                    Button("Respond in Calendar") {
                        calendarHandoff = CalendarEventHandoff(
                            eventID: eventID,
                            title: meeting.commitment.title
                        )
                    }
                }
            } label: {
                Image(systemName: meeting.intent == .skipping ? "minus.circle" : "checkmark.circle")
                    .font(.caption)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
    }

    // MARK: Day lane

    private var dayLane: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let metrics = self.metrics(for: store.selectedDay)
                HStack(alignment: .firstTextBaseline) {
                    Text(longDayLabel(store.selectedDay))
                        .lifeboardFont(.title3)
                    Spacer()
                    Text(metrics.summary)
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .multilineTextAlignment(.trailing)
                }
                if let hint = metrics.overloadHint {
                    Label(hint, systemImage: "exclamationmark.circle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                        .accessibilityIdentifier("plan.week.workspace.overloadHint")
                        .padding(.top, 8)
                }

                let meetings = dayMeetings
                if meetings.isEmpty == false {
                    ForEach(meetings, id: \.commitment.id) { meeting in
                        meetingRow(meeting)
                        hairline.padding(.leading, 34)
                    }
                }

                let placed = workspacePlannedTasks(on: store.selectedDay)
                if placed.isEmpty && meetings.isEmpty {
                    Text("\(shortDayName(store.selectedDay)) still has room.")
                        .font(.subheadline)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .padding(.vertical, 18)
                } else {
                    ForEach(placed) { task in
                        placedRow(task)
                        if task.id != placed.last?.id {
                            hairline.padding(.leading, 34)
                        }
                    }
                }

                composer
                    .padding(.top, 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.86))
                    Color.clear
                        .lifeboardTaskLandingCaustic(trigger: landingTrigger)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.interactively)
        .dropDestination(for: String.self) { items, _ in
            let ids = items.compactMap(UUID.init(uuidString:))
            guard ids.isEmpty == false else { return false }
            Task { await place(Set(ids), on: store.selectedDay) }
            return true
        }
        .accessibilityIdentifier("plan.week.workspace.dayLane")
    }

    private func placedRow(_ task: PlanningTaskSummary) -> some View {
        HStack(spacing: 12) {
            Button {
                Task { await store.setCompletion(task, to: true) }
            } label: {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(task.title)")

            Text(task.title)
                .font(.subheadline)
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            Spacer(minLength: 8)
            if let estimate = task.estimatedDuration, estimate > 0 {
                Text(WeeklyWorkspaceLoad.durationPhrase(Int(estimate / 60)))
                    .font(.caption2)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    hoveredTaskID == task.id
                        ? Color(LifeBoardColorTokens.foundationSurfaceSelected).opacity(0.55)
                        : Color.clear
                )
        }
        .opacity(pendingMutationIDs.contains(task.id) ? 0.68 : 1)
        .matchedGeometryEffect(id: task.id, in: placementNamespace, isSource: false)
        .draggable(task.id.uuidString)
        .onHover { hovering in hoveredTaskID = hovering ? task.id : nil }
        // Dropping onto a row means "put it here", which is reorder when the
        // dragged task is already on this day and placement when it is not.
        // One gesture, two readings, both the obvious one.
        .dropDestination(for: String.self) { items, _ in
            guard let dropped = items.compactMap(UUID.init(uuidString:)).first, dropped != task.id else {
                return false
            }
            Task { await drop(dropped, before: task.id) }
            return true
        }
        .contextMenu {
            if selectedDayAvailability.freeWindows.isEmpty == false {
                Button("Time-box it", systemImage: "calendar.badge.clock") {
                    Task { await timeBox(task) }
                }
            }
            Button("Back to the tray", systemImage: "tray.and.arrow.up") {
                Task { await unplace(task) }
            }
            Divider()
            moveActions(for: [task.id])
        }
        .accessibilityActions {
            moveActions(for: [task.id])
            Button("Move up") { Task { await nudge(task, by: -1) } }
            Button("Move down") { Task { await nudge(task, by: 1) } }
            if selectedDayAvailability.freeWindows.isEmpty == false {
                Button("Time-box it") { Task { await timeBox(task) } }
            }
        }
        .accessibilityIdentifier("plan.week.workspace.placed.\(task.id.uuidString)")
    }

    /// The composer stays on screen and stays focused: return commits the line
    /// and clears the field without dismissing the keyboard, so a burst of five
    /// tasks is five lines and not five round trips through a sheet.
    private var composer: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            TextField(
                WeeklyWorkspaceCopy.placementHint(dayName: shortDayName(store.selectedDay)),
                text: $composerText,
                axis: .vertical
            )
            .font(.subheadline)
            .focused($composerFocused)
            .submitLabel(.done)
            .onSubmit { Task { await commitComposer() } }
            .accessibilityIdentifier("plan.week.workspace.composer")
            if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button("Add") { Task { await commitComposer() } }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.well)
    }

    // MARK: Meetings

    private struct DayMeeting {
        let commitment: CalendarCommitment
        let intent: WeeklyMeetingIntent
        let occurrenceKey: String
    }

    private var dayMeetings: [DayMeeting] {
        meetings(on: store.selectedDay)
    }

    private func meetings(on day: PlanningDay) -> [DayMeeting] {
        store.commitments(on: day).compactMap { commitment in
            let key = commitment.occurrenceKey(
                calendar: store.workspaceCalendar,
                timeZone: store.workspaceCalendar.timeZone
            )
            guard let intent = WeeklyMeetingPolicy.resolvedIntent(
                participation: commitment.participation ?? .unknown,
                state: commitment.eventState ?? .unspecified,
                isBusy: commitment.isBusy,
                override: meetingOverrides[key]
            ) else { return nil }
            return DayMeeting(commitment: commitment, intent: intent, occurrenceKey: key)
        }
    }

    private func meetingRow(_ meeting: DayMeeting) -> some View {
        let commitment = meeting.commitment
        let badge = (commitment.participation ?? .unknown).badge
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timeLabel(commitment))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                Text(commitment.title)
                    .font(.subheadline)
                    .foregroundStyle(
                        meeting.intent == .skipping
                            ? Color(LifeBoardColorTokens.inkTertiary)
                            : Color(LifeBoardColorTokens.inkPrimary)
                    )
                    .strikethrough(meeting.intent == .skipping)
                if badge.isEmpty == false {
                    // The real RSVP, stated as fact. It is never a control:
                    // EventKit exposes attendee status read-only, so a button
                    // here would promise a reply LifeBoard cannot send.
                    Text(badge)
                        .font(.caption2)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                }
            }
            Spacer(minLength: 8)
            Menu {
                Button {
                    chooseMeetingIntent(.attending, for: meeting)
                } label: {
                    Label("In my week", systemImage: "checkmark.circle")
                }
                Button {
                    chooseMeetingIntent(.skipping, for: meeting)
                } label: {
                    Label("Skip this week", systemImage: "minus.circle")
                }
                if WeeklyMeetingPolicy.offersCalendarHandoff(
                    participation: commitment.participation ?? .unknown
                ), let eventID = commitment.seriesID {
                    Divider()
                    Button {
                        calendarHandoff = CalendarEventHandoff(
                            eventID: eventID,
                            title: commitment.title
                        )
                    } label: {
                        Label("Respond in Calendar", systemImage: "calendar.badge.clock")
                    }
                }
            } label: {
                Label(meetingDecisionLabel(meeting.intent), systemImage: meetingDecisionSymbol(meeting.intent))
                .font(.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .frame(minHeight: 36)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("plan.week.workspace.meetingIntent.\(meeting.occurrenceKey)")
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(commitment.title), \(timeLabel(commitment)), \(badge.isEmpty ? "no reply status" : badge), \(meeting.intent.title)")
    }

    private func chooseMeetingIntent(_ next: WeeklyMeetingIntent, for meeting: DayMeeting) {
        let participation = meeting.commitment.participation ?? .unknown
        let derived = WeeklyMeetingPolicy.defaultIntent(
            participation: participation,
            state: meeting.commitment.eventState ?? .unspecified,
            isBusy: meeting.commitment.isBusy
        )
        let storedIntent: WeeklyMeetingIntent? = next == derived ? nil : next
        let decisionReceipt = decisions.setIntent(
            storedIntent,
            weekStart: weekStart,
            occurrenceKey: meeting.occurrenceKey,
            titleSnapshot: meeting.commitment.title
        )
        if let storedIntent {
            meetingOverrides[meeting.occurrenceKey] = storedIntent
        } else {
            meetingOverrides.removeValue(forKey: meeting.occurrenceKey)
        }
        sessionSummary.recordMeetingDecision()
        motionEvent = .meetingDecided(meeting.occurrenceKey)
        show(
            next == .skipping
                ? "\(meeting.commitment.title) is out of this week"
                : "\(meeting.commitment.title) is in your week",
            undoToken: .meeting(decisionReceipt)
        )
        LifeBoardHaptic.settle.play()
    }

    // MARK: Tray

    private var tray: some View {
        VStack(spacing: 0) {
            shelfHandle
            laneSwitcher

            if shelfDetent == .expanded && usesSideBySideLayout == false {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                    TextField("Find something to place", text: $traySearch)
                        .font(.subheadline)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(false)
                        .accessibilityIdentifier("plan.week.workspace.search")
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(
                    Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.72),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
            }

            if isSelecting { selectionBar }

            let rows = trayTasks
            if rows.isEmpty {
                Text(emptyTrayMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                Spacer(minLength: 0)
            } else {
                List {
                    ForEach(rows) { task in
                        trayRow(task)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 12))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // The floating dock overlays the bottom of the tray, and a
                // `List` inside a fixed-height container does not inherit the
                // shell's chrome inset. Without this the last row can be
                // scrolled to but never tapped.
                .contentMargins(.bottom, 96, for: .scrollContent)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: usesSideBySideLayout ? 0 : 24, style: .continuous)
                .fill(Color(LifeBoardColorTokens.foundationCanvasSoft))
                .overlay(alignment: .top) { hairline }
                .ignoresSafeArea(edges: .bottom)
        }
        .lifeboardTriageSettle(trigger: triageTrigger, direction: 1)
        .accessibilityIdentifier("plan.week.workspace.tray")
    }

    private var shelfHandle: some View {
        VStack(spacing: 5) {
            if usesSideBySideLayout == false {
                Capsule()
                    .fill(Color(LifeBoardColorTokens.inkTertiary).opacity(0.34))
                    .frame(width: 36, height: 4)
            }
            HStack {
                Text("Choose what deserves a place")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Spacer()
                if usesSideBySideLayout == false {
                    Image(systemName: shelfDetent == .expanded ? "chevron.down" : "chevron.up")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, usesSideBySideLayout ? 12 : 7)
        .padding(.bottom, 5)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard usesSideBySideLayout == false else { return }
                    shelfDragOffset = -value.translation.height
                }
                .onEnded { value in
                    guard usesSideBySideLayout == false else { return }
                    let travel = -value.predictedEndTranslation.height
                    settleShelf(travel: travel)
                }
        )
        .onTapGesture {
            guard usesSideBySideLayout == false else { return }
            settleShelf(travel: shelfDetent == .expanded ? -120 : 120)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Planning shelf")
        .accessibilityValue(String(describing: shelfDetent))
        .accessibilityAction(named: "Expand") { shelfDetent = .expanded }
        .accessibilityAction(named: "Collapse") { shelfDetent = .compact }
    }

    private var laneSwitcher: some View {
        HStack(spacing: 2) {
            ForEach(WeeklyWorkspaceLane.allCases) { value in
                Button {
                    withAnimation(reduceMotion ? nil : LifeBoardAnimation.selection) {
                        lane = value
                    }
                } label: {
                    Text(trayTitle(value))
                        .font(.caption.weight(lane == value ? .semibold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if lane == value {
                                Capsule()
                                    .fill(Color(LifeBoardColorTokens.foundationSurfaceSelected))
                                    .matchedGeometryEffect(id: "weekly-lane", in: placementNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(lane == value ? .isSelected : [])
            }
        }
        .padding(3)
        .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .accessibilityIdentifier("plan.week.workspace.lane")
    }

    private func trayRow(_ task: PlanningTaskSummary) -> some View {
        let isSelected = selection.contains(task.id)
        return HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                if let waited = waitingLabel(task) {
                    Text(waited)
                        .font(.caption2)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                }
            }
            Spacer(minLength: 8)
            if isSelecting == false {
                // The whole throughput story. One tap, no dialog, no target
                // picker: the ribbon already says where it is going.
                Button {
                    Task { await place([task.id], on: store.selectedDay) }
                } label: {
                    if pendingMutationIDs.contains(task.id) {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                    }
                }
                .buttonStyle(.plain)
                .disabled(pendingMutationIDs.contains(task.id))
                .accessibilityLabel(WeeklyWorkspaceCopy.moveAction(dayName: shortDayName(store.selectedDay)))
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isSelecting else { return }
            if isSelected { selection.remove(task.id) } else { selection.insert(task.id) }
        }
        .onLongPressGesture {
            guard isSelecting == false else { return }
            isSelecting = true
            selection = [task.id]
            LifeBoardHaptic.settle.play()
        }
        .matchedGeometryEffect(id: task.id, in: placementNamespace, isSource: true)
        .opacity(pendingMutationIDs.contains(task.id) ? 0.55 : 1)
        .draggable(task.id.uuidString)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Someday") {
                Task { await releaseToSomeday([task.id]) }
            }
            .tint(Color(LifeBoardColorTokens.inkSecondary))
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Today") {
                Task { await place([task.id], on: store.todayPlanningDay()) }
            }
            .tint(Color(LifeBoardColorTokens.foundationApricotAccent))
        }
        .accessibilityActions { moveActions(for: [task.id]) }
        .accessibilityIdentifier("plan.week.workspace.tray.\(task.id.uuidString)")
    }

    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text(selection.count == 1 ? "1 selected" : "\(selection.count) selected")
                .font(.caption.weight(.semibold))
            Spacer()
            Button("Place on \(shortDayName(store.selectedDay))") {
                Task { await place(selection, on: store.selectedDay) }
            }
            .font(.caption.weight(.semibold))
            .disabled(selection.isEmpty)
            Button("Done") {
                isSelecting = false
                selection = []
            }
            .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSelected))
        .accessibilityIdentifier("plan.week.workspace.selectionBar")
    }

    /// Drag is never the only way to move something. These are the same moves,
    /// reachable by VoiceOver rotor, Switch Control and Full Keyboard Access.
    @ViewBuilder
    private func moveActions(for ids: Set<UUID>) -> some View {
        ForEach(placeableDays, id: \.self) { day in
            Button(WeeklyWorkspaceCopy.moveAction(dayName: shortDayName(day))) {
                Task { await place(ids, on: day) }
            }
        }
        Button(WeeklyWorkspaceCopy.bankruptcyAction) {
            Task { await releaseToSomeday(ids) }
        }
    }

    // MARK: Briefing

    private var briefingSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(briefing.headline)
                .lifeboardFont(.title2)
            if let detail = briefing.detail() {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Text("Bringing everything forward only works if the week can hold it, so spreading stops when the days are full and tells you what is left.")
                .font(.footnote)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))

            VStack(spacing: 10) {
                Button {
                    Task { await spreadOverdue() }
                } label: {
                    Text(WeeklyWorkspaceCopy.spreadAction)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("plan.week.workspace.spread")

                Button {
                    showsBriefing = false
                    pendingBankruptcy = true
                } label: {
                    Text(WeeklyWorkspaceCopy.bankruptcyAction)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("plan.week.workspace.bankruptcy")

                Button {
                    showsBriefing = false
                    lane = .overdue
                } label: {
                    Text(WeeklyWorkspaceCopy.manualAction)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .font(.subheadline)
            }
            Spacer()
        }
        .padding(24)
        .background(Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea())
        .presentationDetents([.medium])
        .accessibilityIdentifier("plan.week.workspace.briefing")
    }

    private var completionSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your week has shape.")
                    .lifeboardFont(.title2)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                Text(ritualSummary)
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                    .lifeboardFirstLight(
                        trigger: completionTrigger,
                        tint: Color(LifeBoardColorTokens.foundationApricotAccent)
                    )
            }

            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 10) { completionActions }
            } else {
                completionActions
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .background(Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea())
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(300)])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("plan.week.workspace.completion")
    }

    private var completionActions: some View {
        VStack(spacing: 10) {
            Button {
                finishPlanning()
            } label: {
                Text("Finish")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            .lifeBoardSystemGlass(
                .regular,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                interactive: true
            )
            .tint(Color(LifeBoardColorTokens.foundationApricotAccent))
            .accessibilityIdentifier("plan.week.workspace.finish")

            Button("Keep planning") { showsCompletion = false }
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 44)
                .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var receiptToast: some View {
        if let receipt {
            HStack(spacing: 12) {
                Text(receipt.message)
                    .font(.footnote)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                Spacer(minLength: 8)
                if let undoToken = receipt.undoToken {
                    Button("Undo") {
                        Task { await undo(undoToken) }
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("plan.week.workspace.receipt")
        }
    }

    // MARK: Actions

    /// Changes the day through the store rather than assigning `selectedDay`.
    ///
    /// Assigning it directly left `daySnapshot` pointing at whichever day was
    /// last *loaded*, so everything derived from it — free windows, and
    /// therefore time-boxing — answered about the wrong day. `select(day:)`
    /// re-points the snapshot synchronously when the day is inside the loaded
    /// week, so this stays a tap-speed interaction.
    private func select(_ day: PlanningDay) {
        guard day != store.selectedDay else { return }
        LifeBoardHaptic.pick.play()
        motionEvent = .daySelected(day)
        ribbonRefractStrength = 0.72
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(210))
            withAnimation(reduceMotion ? nil : LifeBoardAnimation.selection) {
                ribbonRefractStrength = 0
            }
        }
        Task { await store.select(day: day) }
    }

    private func place(_ ids: Set<UUID>, on day: PlanningDay) async {
        guard ids.isEmpty == false else { return }
        let resolved = ids.compactMap(store.task(for:))
        guard resolved.isEmpty == false else { return }
        withAnimation(reduceMotion ? nil : LifeBoardAnimation.cardReflow) {
            for id in ids { pendingPlacements[id] = day }
            pendingMutationIDs.formUnion(ids)
        }
        motionEvent = resolved.count == 1 ? .taskPickedUp(resolved[0].id) : .shelfChanged(shelfDetent)

        await mutationCoordinator.acquire()
        let placed: Bool
        if resolved.count == 1, let task = resolved.first {
            placed = await store.place(task, on: day)
        } else {
            placed = await store.placeAll(ids, on: day)
        }
        await mutationCoordinator.release()

        withAnimation(reduceMotion ? nil : LifeBoardAnimation.cardReflow) {
            ids.forEach {
                pendingPlacements.removeValue(forKey: $0)
                pendingMutationIDs.remove($0)
            }
        }
        guard placed else {
            motionEvent = .taskPlacementFailed(resolved[0].id)
            show(store.errorMessage ?? "That could not be placed. It is still in the tray.", undoToken: nil)
            LifeBoardHaptic.fail.play()
            return
        }

        sessionSummary.recordPlaced(ids.count)
        motionEvent = .taskPlaced(resolved[0].id, day)
        landingTrigger &+= 1
        triageTrigger &+= 1
        if resolved.count == 1, let task = resolved.first {
            show(
                WeeklyWorkspaceCopy.placedAnnouncement(
                    title: task.title,
                    dayName: shortDayName(day)
                ),
                undoToken: .planMutation
            )
        } else {
            show("\(ids.count) moved to \(shortDayName(day))", undoToken: .planMutation)
        }
        selection = []
        isSelecting = false
        pulse(day)
    }

    /// A drop onto a row: reorder within the day, or place onto the day first.
    private func drop(_ id: UUID, before target: UUID) async {
        let day = store.selectedDay
        guard let task = store.task(for: id) else { return }
        if task.metadata.planningDay != day {
            await place([id], on: day)
            guard store.task(for: id)?.metadata.planningDay == day else { return }
        }
        if await store.reorder(on: day, moving: id, before: target) {
            LifeBoardHaptic.settle.play()
        }
    }

    /// Keyboard and VoiceOver equivalent of a reorder drag.
    private func nudge(_ task: PlanningTaskSummary, by offset: Int) async {
        let ordered = store.orderedPlannedTasks(on: store.selectedDay).map(\.id)
        guard let index = ordered.firstIndex(of: task.id) else { return }
        let destination = index + offset
        guard destination >= 0, destination <= ordered.count - 1 else { return }
        // Moving down means landing *before* the row after the target, which is
        // one further along than the naive index.
        let target: UUID? = offset > 0
            ? (destination + 1 < ordered.count ? ordered[destination + 1] : nil)
            : ordered[destination]
        guard await store.reorder(on: store.selectedDay, moving: task.id, before: target) else { return }
        LifeBoardHaptic.pick.play()
    }

    private func timeBox(_ task: PlanningTaskSummary) async {
        guard let start = await store.timeBox(
            task,
            on: store.selectedDay,
            skippingCommitmentIDs: skippedCommitmentIDs(on: store.selectedDay)
        ) else {
            show("No gap on \(shortDayName(store.selectedDay)) long enough for that.", undoToken: nil)
            return
        }
        let formatter = DateFormatter()
        formatter.calendar = store.workspaceCalendar
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        show("\(task.title) at \(formatter.string(from: start))", undoToken: .planMutation)
        LifeBoardHaptic.commit.play()
    }

    /// Returns a placed task to the tray without deciding anything else about
    /// it. Taking a day off a task is a normal planning move, and the only way
    /// back was previously Someday, which says something much stronger.
    private func unplace(_ task: PlanningTaskSummary) async {
        guard await store.unplace(task) else { return }
        show("\(task.title) is back in the tray")
    }

    private func releaseToSomeday(_ ids: Set<UUID>) async {
        guard await store.releaseToSomeday(ids) else { return }
        sessionSummary.recordReleased(ids.count)
        show(
            ids.count == 1 ? "Moved to Someday" : "\(ids.count) moved to Someday",
            undoToken: .planMutation
        )
        selection = []
        isSelecting = false
    }

    private func spreadOverdue() async {
        let candidates = store.workspaceTasks(in: .overdue).map {
            WeeklySpreadCandidate(
                taskID: $0.id,
                estimatedMinutes: $0.estimatedDuration.map { Int($0 / 60) }
            )
        }
        let plan = WeeklyBacklogSpread.plan(candidates: candidates, days: spreadDays)
        showsBriefing = false
        guard await store.applySpread(plan) else {
            show("The week has no room left.", undoToken: nil)
            return
        }
        sessionSummary.recordPlaced(plan.placements.count)
        landingTrigger &+= 1
        triageTrigger &+= 1
        show(plan.summary, undoToken: .planMutation)
        LifeBoardHaptic.commit.play()
    }

    private func releaseOverdue() async {
        let ids = Set(store.workspaceTasks(in: .overdue).map(\.id))
        await releaseToSomeday(ids)
    }

    private func commitComposer() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        // Multi-line paste becomes one task per line, in one pass, rather than
        // a single task with newlines in its title.
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
        // The field is *not* cleared yet. It used to be emptied before the first
        // await, so any write failure — a missing repository, a throwing store —
        // took the user's typing with it and said nothing, because this view
        // never reads `store.errorMessage`. Clear only what actually persisted.
        composerFocused = true
        let today = store.todayPlanningDay()
        var created = 0
        var failed: [String] = []
        var lastDay = store.selectedDay
        var redirected = false
        for line in lines {
            let parsed = WeeklyComposerPlacement.resolve(
                TaskCaptureParser.parse(line),
                rawText: line,
                today: today,
                calendar: store.workspaceCalendar,
                timeZone: store.workspaceCalendar.timeZone
            )
            guard let parsed else { continue }
            let day = parsed.day ?? store.selectedDay
            if let retryID = composerRetryIDs[line], let task = store.task(for: retryID) {
                guard await store.place(task, on: day) else {
                    failed.append(line)
                    continue
                }
                composerRetryIDs.removeValue(forKey: line)
            } else {
                guard let outcome = await store.createWorkspaceTask(
                    titled: parsed.title,
                    on: day,
                    estimatedMinutes: parsed.estimatedMinutes
                ) else {
                    failed.append(line)
                    continue
                }
                guard outcome.wasPlaced else {
                    composerRetryIDs[line] = outcome.taskID
                    failed.append(line)
                    continue
                }
            }
            created += 1
            if parsed.day != nil, day != store.selectedDay { redirected = true }
            lastDay = day
        }
        // Anything that failed stays in the field so it can be retried. Silence
        // plus an empty box is the worst possible outcome for typed text.
        composerText = failed.joined(separator: "\n")
        guard created > 0 else {
            show(
                store.errorMessage ?? "That could not be saved. Your text is still here.",
                undoToken: nil
            )
            LifeBoardHaptic.fail.play()
            return
        }
        if failed.isEmpty == false {
            show("\(created) added · \(failed.count) still in the box", undoToken: nil)
            pulse(lastDay)
            return
        }
        // Say where it went whenever the typed phrase overrode the composer's
        // own day, so a task that leaves the visible lane is never a surprise.
        if created == 1 {
            show(
                redirected ? "Added to \(shortDayName(lastDay))" : "Added to \(shortDayName(store.selectedDay))",
                undoToken: nil
            )
        } else {
            show("\(created) added", undoToken: nil)
        }
        sessionSummary.recordPlaced(created)
        landingTrigger &+= 1
        pulse(lastDay)
    }

    private func pulse(_ day: PlanningDay) {
        pulsedDay = day
        LifeBoardHaptic.settle.play()
        pulseDismissal?.cancel()
        pulseDismissal = Task {
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard Task.isCancelled == false else { return }
            pulsedDay = nil
        }
    }

    /// Shows a receipt, replacing any receipt already on screen.
    ///
    /// The dismissal used to compare the message *text* after sleeping, so two
    /// identical consecutive receipts — place a task, undo, place it again —
    /// meant the first timer tore down the second toast almost as soon as it
    /// appeared, taking Undo with it. Identity and a cancellable handle, not
    /// value equality.
    private func show(
        _ message: String,
        undoToken: WeeklyWorkspaceUndoToken? = .planMutation
    ) {
        receiptDismissal?.cancel()
        receipt = WorkspaceReceipt(message: message, undoToken: undoToken)
        let id = receipt?.id
        receiptDismissal = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard Task.isCancelled == false, receipt?.id == id else { return }
            receipt = nil
        }
    }

    private func undo(_ token: WeeklyWorkspaceUndoToken) async {
        switch token {
        case .planMutation:
            await store.undoLastMutation()
        case .meeting(let decisionReceipt):
            decisions.restore(decisionReceipt)
            if let previous = decisionReceipt.previousIntent {
                meetingOverrides[decisionReceipt.occurrenceKey] = previous
            } else {
                meetingOverrides.removeValue(forKey: decisionReceipt.occurrenceKey)
            }
        }
        receiptDismissal?.cancel()
        receipt = nil
        LifeBoardHaptic.pick.play()
    }

    private func finishPlanning() {
        motionEvent = .weekCommitted
        completionTrigger &+= 1
        LifeBoardHaptic.commit.play()
        Task { @MainActor in
            if LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false {
                try? await Task.sleep(for: .milliseconds(620))
            }
            showsCompletion = false
            onClose?()
        }
    }

    private func settleShelf(travel: CGFloat) {
        shelfDragOffset = 0
        let current = shelfDetent.rawValue
        let nextRaw: Int
        if travel > 56 {
            nextRaw = min(WeeklyWorkspaceShelfDetent.expanded.rawValue, current + 1)
        } else if travel < -56 {
            nextRaw = max(WeeklyWorkspaceShelfDetent.compact.rawValue, current - 1)
        } else {
            nextRaw = current
        }
        guard let next = WeeklyWorkspaceShelfDetent(rawValue: nextRaw) else { return }
        withAnimation(reduceMotion ? nil : LifeBoardAnimation.directManipulation) {
            shelfDetent = next
        }
        motionEvent = .shelfChanged(next)
        LifeBoardHaptic.pick.play()
    }

    private func updateDropHover(day: PlanningDay, isTargeted: Bool) {
        dropHoverTask?.cancel()
        guard isTargeted, day != store.selectedDay else { return }
        dropHoverTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            guard Task.isCancelled == false else { return }
            select(day)
        }
    }

    // MARK: Derived state

    private struct DayMetrics {
        let placedCount: Int
        let plannedMinutes: Int
        let usableMinutes: Int
        let isToday: Bool

        var drawnFraction: Double {
            WeeklyWorkspaceLoad.drawnFraction(plannedMinutes: plannedMinutes, usableMinutes: usableMinutes)
        }
        var isOverCapacity: Bool {
            WeeklyWorkspaceLoad.isOverCapacity(plannedMinutes: plannedMinutes, usableMinutes: usableMinutes)
        }
        var summary: String {
            WeeklyWorkspaceLoad.summary(
                plannedMinutes: plannedMinutes,
                usableMinutes: usableMinutes,
                placedCount: placedCount
            )
        }
        var overloadHint: String? {
            WeeklyWorkspaceLoad.overloadHint(plannedMinutes: plannedMinutes, usableMinutes: usableMinutes)
        }
    }

    private func metrics(for day: PlanningDay) -> DayMetrics {
        let availability = store.workspaceAvailability(
            on: day,
            skippingCommitmentIDs: skippedCommitmentIDs(on: day)
        )
        let tasks = workspacePlannedTasks(on: day)
        let planned = tasks.reduce(0) { total, task in
            guard let estimate = task.estimatedDuration, estimate > 0 else {
                return total + WeeklyWorkspaceLoad.assumedTaskMinutes
            }
            return total + Int(estimate / 60)
        }
        return DayMetrics(
            placedCount: tasks.count,
            plannedMinutes: planned,
            usableMinutes: availability.usableMinutes,
            isToday: day == store.todayPlanningDay()
        )
    }

    private var selectedDayAvailability: WeeklyWorkspaceAvailability {
        store.workspaceAvailability(
            on: store.selectedDay,
            skippingCommitmentIDs: skippedCommitmentIDs(on: store.selectedDay)
        )
    }

    private func workspacePlannedTasks(on day: PlanningDay) -> [PlanningTaskSummary] {
        let movingAway = Set(pendingPlacements.compactMap { id, destination in
            destination == day ? nil : id
        })
        var result = store.orderedPlannedTasks(on: day).filter { movingAway.contains($0.id) == false }
        let existing = Set(result.map(\.id))
        let arriving = pendingPlacements.compactMap { id, destination -> PlanningTaskSummary? in
            guard destination == day, existing.contains(id) == false, var task = store.task(for: id) else {
                return nil
            }
            task.metadata.planningDay = day
            return task
        }
        result.append(contentsOf: arriving.sorted { $0.title < $1.title })
        return result
    }

    /// Meetings on a day the user has chosen to skip.
    ///
    /// Identified rather than summed: the store removes them from the capacity
    /// *calculation*, so the time handed back is exactly the time that was
    /// charged. Summing raw durations credited meetings that fell outside
    /// working hours, double-credited overlaps, and gave an overnight event's
    /// whole length back to both days it touched.
    private func skippedCommitmentIDs(on day: PlanningDay) -> Set<String> {
        var result: Set<String> = []
        for commitment in store.commitments(on: day) {
            let key = commitment.occurrenceKey(
                calendar: store.workspaceCalendar,
                timeZone: store.workspaceCalendar.timeZone
            )
            if meetingOverrides[key] == .skipping { result.insert(commitment.id) }
        }
        return result
    }

    private var allDays: [PlanningDay] { store.weekDays(containing: store.selectedDay) }

    private var visibleDays: [PlanningDay] {
        guard showsSoftDays == false else { return allDays }
        let today = store.todayPlanningDay()
        let past = WeeklyPlanningHorizon.pastDays(in: allDays, today: today)
        let concrete = WeeklyPlanningHorizon.concreteDays(in: allDays, today: today)
        return past + concrete
    }

    private var softDays: [PlanningDay] {
        WeeklyPlanningHorizon.softDays(in: allDays, today: store.todayPlanningDay())
    }

    private var placeableDays: [PlanningDay] {
        let today = store.todayPlanningDay()
        return allDays.filter { WeeklyPlanningHorizon.canReceivePlacement($0, today: today) }
    }

    private var spreadDays: [WeeklySpreadDay] {
        placeableDays.map { day in
            let usable = store.usableMinutes(on: day, skippingCommitmentIDs: skippedCommitmentIDs(on: day))
            return WeeklySpreadDay(
                day: day,
                remainingMinutes: usable > 0
                    ? WeeklyWorkspaceLoad.remainingMinutes(
                        plannedMinutes: store.plannedMinutes(on: day),
                        usableMinutes: usable
                    )
                    : nil,
                placedCount: workspacePlannedTasks(on: day).count
            )
        }
    }

    private var briefing: WeeklyOverdueBriefing { store.overdueBriefing() }

    /// What the week looks like now, said once at the end.
    private var ritualSummary: String {
        let days = placeableDays
        let placed = days.reduce(0) { $0 + workspacePlannedTasks(on: $1).count }
        let free = days.reduce(0) { total, day in
            let usable = store.usableMinutes(on: day, skippingCommitmentIDs: skippedCommitmentIDs(on: day))
            return total + WeeklyWorkspaceLoad.remainingMinutes(
                plannedMinutes: store.plannedMinutes(on: day),
                usableMinutes: usable
            )
        }
        let meetingsReleased = allDays.reduce(0) { count, day in
            count + meetings(on: day).filter { $0.intent == .skipping }.count
        }
        return WeeklyWorkspaceCopy.closingSummary(
            placed: placed,
            tasksReleased: sessionSummary.tasksReleased,
            meetingsReleased: meetingsReleased,
            freeMinutes: free
        )
    }

    private var trayTasks: [PlanningTaskSummary] {
        let query = traySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.workspaceTasks(in: lane)
            .filter { pendingPlacements[$0.id] == nil }
            .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func trayTitle(_ value: WeeklyWorkspaceLane) -> String {
        let count = store.workspaceTasks(in: value).count
        return count > 0 ? "\(value.title) \(count)" : value.title
    }

    private var emptyTrayMessage: String {
        switch lane {
        case .overdue: "Nothing is overdue. "
        case .inbox: "The inbox is clear."
        case .anytime: "Everything open already has a day."
        }
    }

    private func meetingDecisionLabel(_ intent: WeeklyMeetingIntent) -> String {
        switch intent {
        case .attending: "In my week"
        case .skipping: "Skip this week"
        case .undecided: "Decide"
        }
    }

    private func meetingDecisionSymbol(_ intent: WeeklyMeetingIntent) -> String {
        switch intent {
        case .attending: "checkmark.circle"
        case .skipping: "minus.circle"
        case .undecided: "circle.dashed"
        }
    }

    private var weekStart: Date {
        store.selectedDay.startDate(calendar: store.workspaceCalendar).map {
            store.workspaceCalendar.dateInterval(of: .weekOfYear, for: $0)?.start ?? $0
        } ?? Date()
    }

    private var headerSubtitle: String {
        let toPlace = store.workspaceTasks(in: .anytime).count
        var parts: [String] = []
        parts.append(toPlace == 1 ? "1 waiting for a home" : "\(toPlace) waiting for a home")
        if briefing.count > 0 {
            parts.append(briefing.count == 1 ? "1 carried forward" : "\(briefing.count) carried forward")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Formatting

    private var weekRangeLabel: String {
        guard let first = allDays.first?.startDate(calendar: store.workspaceCalendar),
              let last = allDays.last?.startDate(calendar: store.workspaceCalendar) else {
            return WeeklyWorkspaceCopy.title
        }
        let formatter = DateFormatter()
        formatter.calendar = store.workspaceCalendar
        formatter.dateFormat = "d MMM"
        let start = formatter.string(from: first)
        let end = formatter.string(from: last)
        return "\(start) – \(end)"
    }

    private func weekdayInitial(_ day: PlanningDay) -> String {
        guard let date = day.startDate(calendar: store.workspaceCalendar) else { return "" }
        let index = store.workspaceCalendar.component(.weekday, from: date) - 1
        let symbols = store.workspaceCalendar.veryShortStandaloneWeekdaySymbols
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    private func shortDayName(_ day: PlanningDay) -> String {
        if day == store.todayPlanningDay() { return "Today" }
        guard let date = day.startDate(calendar: store.workspaceCalendar) else { return "that day" }
        let formatter = DateFormatter()
        formatter.calendar = store.workspaceCalendar
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func longDayLabel(_ day: PlanningDay) -> String {
        guard let date = day.startDate(calendar: store.workspaceCalendar) else { return "" }
        let formatter = DateFormatter()
        formatter.calendar = store.workspaceCalendar
        formatter.dateFormat = "EEEE d"
        let base = formatter.string(from: date)
        return day == store.todayPlanningDay() ? "\(base) · Today" : base
    }

    private func timeLabel(_ commitment: CalendarCommitment) -> String {
        guard commitment.isAllDay == false else { return "All day" }
        let formatter = DateFormatter()
        formatter.calendar = store.workspaceCalendar
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: commitment.startAt)
    }

    private func waitingLabel(_ task: PlanningTaskSummary) -> String? {
        guard lane == .overdue, let date = store.workspaceOverdueDate(task) else { return nil }
        let days = store.workspaceCalendar.dateComponents(
            [.day],
            from: store.workspaceCalendar.startOfDay(for: date),
            to: store.workspaceCalendar.startOfDay(for: Date())
        ).day ?? 0
        guard days > 0 else { return nil }
        return days == 1 ? "Waiting since yesterday" : "Waiting \(days) days"
    }

    private func dayAccessibilityLabel(_ day: PlanningDay, metrics: DayMetrics) -> String {
        "\(longDayLabel(day)). \(metrics.summary)"
    }
}

/// The week's direction and outcomes, as a section rather than two wizard steps.
///
/// The wizard asked for a focus statement on step one and outcomes on step two,
/// each behind a Continue button, before any task could be touched. Everything
/// here is the same data and the same persistence — `WeeklyPlannerViewModel` is
/// reused verbatim — with the sequencing removed. Saving is explicit because
/// unlike a task placement this is prose, and autosaving half-typed prose on
/// every keystroke is how you get a week whose stated focus is "Ship the".
private struct WeeklyIntentionSection: View {
    @ObservedObject var viewModel: WeeklyPlannerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var savedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("This week is about")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                TextField("One line is enough", text: $viewModel.focusStatement, axis: .vertical)
                    .font(.subheadline)
                    .lineLimit(1...3)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .lifeBoardClaySurface(.well)
                    .accessibilityIdentifier("plan.week.workspace.focusStatement")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Outcomes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    Spacer()
                    if viewModel.canAddOutcome {
                        Button("Add", systemImage: "plus") { viewModel.addOutcomeDraft() }
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleOnly)
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("plan.week.workspace.addOutcome")
                    }
                }
                if viewModel.outcomeDrafts.isEmpty {
                    Text("Three at most. A week with nine outcomes has none.")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                }
                ForEach($viewModel.outcomeDrafts) { $draft in
                    HStack(spacing: 10) {
                        TextField("What would make the week good?", text: $draft.title, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(1...2)
                        Button {
                            viewModel.removeOutcomeDraft(id: draft.id)
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove outcome")
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .lifeBoardClaySurface(.well)
                }
            }

            Toggle(isOn: $viewModel.minimumViableWeekEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Minimum viable week")
                        .font(.subheadline)
                    Text("Name the smallest version that still counts.")
                        .font(.caption2)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                }
            }
            .accessibilityIdentifier("plan.week.workspace.minimumViableWeek")

            HStack(spacing: 12) {
                Button {
                    viewModel.save { }
                    savedAt = Date()
                    LifeBoardHaptic.settle.play()
                } label: {
                    if viewModel.isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Save intention")
                    }
                }
                .buttonStyle(.bordered)
                .font(.subheadline.weight(.semibold))
                .disabled(viewModel.isSaving)
                .accessibilityIdentifier("plan.week.workspace.saveIntention")

                if let message = viewModel.saveMessage, savedAt != nil {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .lifeBoardMotion(.localState, value: viewModel.saveMessage)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationDanger))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
