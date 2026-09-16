import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PlanDayTimeCanvas: View {
    let snapshot: PlanDaySnapshot
    let taskForID: (UUID) -> PlanningTaskSummary?
    let createBlock: (String, Date, TimeInterval, UUID?) -> Void
    let moveBlock: (InternalTimeBlock, Int) -> Void
    let resizeBlock: (InternalTimeBlock, Int) -> Void
    let resizeBlockEdges: (InternalTimeBlock, Int, Int) -> Void
    let splitBlock: (InternalTimeBlock) -> Void
    let deleteBlock: (InternalTimeBlock) -> Void
    let startFocus: (InternalTimeBlock) -> Void
    var onOpenTask: (UUID) -> Void = { _ in }
    var changeDay: (Int) -> Void = { _ in }
    @State private var landingY: CGFloat?
    @State private var daySwipeOffset: CGFloat = 0
    @State private var lastSnappedLandingMinute: Int?
    @State private var landingTrigger = 0
    @State private var landingCenter: UnitPoint = .center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var displayCommitments: [PlanningFixedCommitment] {
        let linked = Set(snapshot.blocks.compactMap(\.taskID))
        return snapshot.commitments + snapshot.plannedTasks.compactMap { task in
            guard !linked.contains(task.id), let start = task.scheduledStartAt else { return nil }
            return PlanningFixedCommitment(id: "task:" + task.id.uuidString, title: task.title,
                startAt: start, endAt: task.scheduledEndAt ?? start.addingTimeInterval(task.estimatedDuration ?? 30 * 60), source: .internalBlock)
        }
    }

    private let hourHeight: CGFloat = 66
    private let rulerWidth: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The day is named and stepped by `PlanOrientationBar`; the canvas
            // only speaks up when something on it overlaps.
            if conflictCount > 0 {
                Label("\(conflictCount) overlap\(conflictCount == 1 ? "" : "s")", systemImage: "square.stack")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                    .accessibilityHint("Overlapping commitments and LifeBoard blocks are highlighted in the timeline")
            }

            ScrollViewReader { reader in
                ScrollView {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    nonworkingLayer(width: proxy.size.width)
                    hourGrid(width: proxy.size.width)
                    // Laid out at its y, not `.offset` to it: `scrollTo` reads the
                    // layout frame, so an offset marker always scrolled to the top.
                    VStack(spacing: 0) {
                        Color.clear.frame(height: initialScrollY)
                        Color.clear.frame(height: 1).id("canvas.initial")
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    freeWindowLayer(width: proxy.size.width)
                    clusterLayer(width: proxy.size.width)
                    if let landingY {
                        // A ghost shaped like the block it will become, gliding
                        // between quarter hours, so the landing is previewed
                        // rather than guessed.
                        let date = PlanCanvasDropResolver.start(forY: landingY, timelineStart: timelineStart, hourHeight: hourHeight)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(timeLabel(date)) – \(timeLabel(date.addingTimeInterval(30 * 60)))")
                                .lifeboardFont(.caption1)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                            Text("Release to place")
                                .lifeboardFont(.caption2)
                        }
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                        .frame(
                            width: max(1, proxy.size.width - rulerWidth - 8),
                            height: blockHeight(from: date, to: date.addingTimeInterval(30 * 60)),
                            alignment: .topLeading
                        )
                        .background(
                            Color(SemanticColorTokens.foundationApricotAccent).opacity(0.2),
                            in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                                .stroke(Color(SemanticColorTokens.foundationApricotAccent), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        }
                        .offset(x: rulerWidth, y: yPosition(date))
                        .animation(InteractionMotion.dragRelease(reduceMotion: reduceMotion), value: date)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
                    if isToday {
                        nowLineLayer(width: proxy.size.width)
                    }
                }
                .frame(width: proxy.size.width, height: timelineHeight, alignment: .topLeading)
                .contentShape(Rectangle())
                // A task lands at the minute it was dropped (snapped to 15), not
                // only on an open window — busy time is allowed, and the lane
                // resolver draws the overlap honestly. Open windows keep their own
                // destination, which wins where they are.
                .onDrop(of: [UTType.text], delegate: PlanCanvasDropDelegate(
                    update: { y in
                        landingY = y
                        // One tick per quarter hour crossed, not per point moved.
                        let minute = y.map {
                            Int(PlanCanvasDropResolver.start(forY: $0, timelineStart: timelineStart, hourHeight: hourHeight)
                                .timeIntervalSince(timelineStart) / 60)
                        }
                        if let minute, minute != lastSnappedLandingMinute { Haptic.pick.play() }
                        lastSnappedLandingMinute = minute
                    },
                    perform: { id, y in
                        guard let task = taskForID(id), task.dependenciesReady else { return }
                        let start = PlanCanvasDropResolver.start(forY: y, timelineStart: timelineStart, hourHeight: hourHeight)
                        createBlock(task.title, start, task.estimatedDuration ?? 30 * 60, id)
                        landingCenter = UnitPoint(x: 0.6, y: min(1, max(0, yPosition(start) / max(1, timelineHeight))))
                        landingTrigger &+= 1
                        Haptic.settle.play()
                    }
                ))
                .lifeboardTaskLandingCaustic(trigger: landingTrigger, center: landingCenter)
            }
            .frame(height: timelineHeight)
            .accessibilityIdentifier("plan.day.canvas")
                }
                // The root already stops above the composer and dock; this
                // just keeps the last hour line off the drawer's edge.
                .contentMargins(.bottom, 24, for: .scrollContent)
                .offset(x: daySwipeOffset)
                .opacity(1 - min(0.4, abs(daySwipeOffset) / 400))
                .task(id: snapshot.day) {
                    // Glide rather than jump, and leave "now" a third of the way
                    // down so the next few hours are what fills the screen.
                    await Task.yield()
                    withAnimation(MotionProfile.route.animation(reduceMotion: reduceMotion)) {
                        reader.scrollTo("canvas.initial", anchor: PlanCanvasGeometry.initialAnchor(isToday: isToday))
                    }
                }
                .simultaneousGesture(daySwipe)
            }
        }
        .frame(maxHeight: .infinity)
    }

    /// Swipe anywhere on the canvas to change day. It only claims clearly
    /// sideways movement, so vertical scrolling and block drags (which travel
    /// in time, vertically) are left alone.
    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 24)
            .onChanged { value in
                guard landingY == nil,
                      PlanDaySwipe.isHorizontal(value.translation) else { return }
                daySwipeOffset = RubberBand.offset(value.translation.width, limit: 72)
            }
            .onEnded { value in
                let delta = landingY == nil
                    ? PlanDaySwipe.dayDelta(
                        translation: value.translation,
                        predictedEndTranslation: value.predictedEndTranslation,
                        width: UIScreen.main.bounds.width
                    )
                    : 0
                if delta != 0 {
                    Haptic.threshold.play()
                    changeDay(delta)
                }
                withAnimation(InteractionMotion.dragRelease(reduceMotion: reduceMotion)) {
                    daySwipeOffset = 0
                }
            }
    }

    private var initialScrollY: CGFloat {
        yPosition(isToday ? Date() : snapshot.workingIntervals.first?.start ?? timelineStart)
    }

    private func nonworkingLayer(width: CGFloat) -> some View {
        let span = DateInterval(start: timelineStart, duration: TimeInterval(hourSpan) * 3_600)
        let gaps = PlanCanvasGeometry.nonworkingIntervals(within: span, working: snapshot.workingIntervals)
        return ForEach(gaps, id: \.start) { gap in
            Rectangle().fill(Color(SemanticColorTokens.foundationSurfaceRecessed).opacity(0.65))
                .frame(width: max(1, width - rulerWidth), height: CGFloat(gap.duration / 3_600) * hourHeight)
                .offset(x: rulerWidth, y: yPosition(gap.start))
                .allowsHitTesting(false)
        }
    }

    private func hourGrid(width: CGFloat) -> some View {
        ForEach(0...hourSpan, id: \.self) { offset in
            let hour = startHour + offset
            HStack(spacing: 8) {
                Text(hourLabel(hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                    .frame(width: rulerWidth - 8, alignment: .trailing)
                Rectangle()
                    .fill(Color(SemanticColorTokens.foundationHairline).opacity(offset % 2 == 0 ? 0.72 : 0.42))
                    .frame(width: max(0, width - rulerWidth), height: 1)
            }
            .offset(y: CGFloat(offset) * hourHeight)
        }
    }

    private func freeWindowLayer(width: CGFloat) -> some View {
        ForEach(snapshot.freeWindows) { window in
            Button {
                createBlock("Focus block", window.startAt, min(window.duration, 60 * 60), nil)
            } label: {
                // Open time stays quiet: short gaps carry no words at all.
                VStack(alignment: .leading, spacing: 4) {
                    if PlanCanvasGeometry.labelsOpenWindow(duration: window.duration) {
                        Text("Open · \(durationLabel(window.duration))")
                            .lifeboardFont(.caption2)
                            .padding(.top, 4)
                    }
                }
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                .padding(.horizontal, 9)
                .frame(width: max(1, width - rulerWidth - 8), height: blockHeight(from: window.startAt, to: window.endAt), alignment: .topLeading)
                .background(Color(SemanticColorTokens.foundationSageAccent).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(SemanticColorTokens.foundationSageAccent).opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
            }
            .buttonStyle(.plain)
            .offset(x: rulerWidth, y: yPosition(window.startAt))

            .accessibilityLabel("Open window, \(timeLabel(window.startAt)) to \(timeLabel(window.endAt))")
            .accessibilityHint("Tap to reserve it as a focus block, or drop a task here.")
            .accessibilityIdentifier("plan.canvas.freeWindow.\(window.id)")
        }
    }

    /// Every scheduled thing on the spine, as intervals the lane resolver can
    /// pack. Commitments and blocks share one lane space because they overlap
    /// each other, not just their own kind.
    private var lanePlacements: [String: PlanTimelineLaneResolver.Placement] {
        let items = displayCommitments.map {
            PlanTimelineLaneResolver.Item(id: "commitment:\($0.id)", start: $0.startAt, end: $0.endAt)
        } + snapshot.blocks.map {
            PlanTimelineLaneResolver.Item(id: "block:\($0.id.uuidString)", start: $0.startAt, end: $0.endAt)
        }
        return PlanTimelineLaneResolver.placements(for: items)
    }

    /// One horizontally scrollable strip per overlapping cluster.
    ///
    /// Concurrent items used to be drawn at the same x, so a busy hour rendered
    /// as an unreadable pile. Each cluster now gets its own lane space: two
    /// abreast share the width, and anything denser keeps a readable lane width
    /// and scrolls sideways inside its own time band, so the vertical position
    /// still tells the truth about when things happen.
    private func clusterLayer(width: CGFloat) -> some View {
        let placements = lanePlacements
        let contentWidth = max(1, width - rulerWidth - 18)
        let clusters = timelineClusters(placements: placements)
        return ForEach(clusters) { cluster in
            let metrics = PlanTimelineLaneResolver.laneMetrics(
                laneCount: cluster.laneCount,
                availableWidth: contentWidth,
                spacing: laneSpacing
            )
            // Sizing happens inside `clusterBody`. A second frame out here used
            // to wrap the scrolling case, and the pair of them left the
            // ScrollView free to size itself to its content: nothing scrolled,
            // and the lanes past the edge were merely clipped by the card.
            clusterBody(cluster, metrics: metrics, contentWidth: contentWidth)
                .offset(x: rulerWidth + 6, y: cluster.top)
        }
    }

    @ViewBuilder
    private func clusterBody(
        _ cluster: TimelineCluster,
        metrics: (laneWidth: CGFloat, scrolls: Bool),
        contentWidth: CGFloat
    ) -> some View {
        if metrics.scrolls {
            PlanClusterStrip(
                contentWidth: contentWidth,
                laneCount: cluster.laneCount,
                laneWidth: metrics.laneWidth,
                spacing: laneSpacing,
                height: cluster.height
            ) {
                clusterLanes(cluster, laneWidth: metrics.laneWidth)
            }
            .accessibilityLabel("\(cluster.laneCount) overlapping items, swipe sideways to see the rest")
        } else {
            clusterLanes(cluster, laneWidth: metrics.laneWidth)
                .frame(width: contentWidth, height: cluster.height, alignment: .topLeading)
        }
    }

    private func clusterLanes(_ cluster: TimelineCluster, laneWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(cluster.commitments) { entry in
                PlanCanvasCommitmentCard(
                    commitment: entry.commitment,
                    width: laneWidth,
                    height: blockHeight(from: entry.commitment.startAt, to: entry.commitment.endAt),
                    conflict: conflicts(
                        start: entry.commitment.startAt,
                        end: entry.commitment.endAt,
                        excludingCommitmentID: entry.commitment.id,
                        excludingBlockID: UUID(uuidString: entry.commitment.id)
                    )
                )
                    .offset(
                        x: CGFloat(entry.lane) * (laneWidth + laneSpacing),
                        y: yPosition(entry.commitment.startAt) - cluster.top
                    )
            }
            ForEach(cluster.blocks) { entry in
                blockCard(entry.block, width: laneWidth)
                    .offset(
                        x: CGFloat(entry.lane) * (laneWidth + laneSpacing),
                        y: yPosition(entry.block.startAt) - cluster.top
                    )
            }
        }
        .frame(
            width: CGFloat(cluster.laneCount) * laneWidth + CGFloat(max(0, cluster.laneCount - 1)) * laneSpacing,
            alignment: .topLeading
        )
    }

    private func blockCard(_ block: InternalTimeBlock, width: CGFloat) -> some View {
        PlanCanvasBlock(
                block: block,
                width: max(1, width),
                height: blockHeight(from: block.startAt, to: block.endAt),
                hourHeight: hourHeight,
                hasConflict: conflicts(
                    start: block.startAt,
                    end: block.endAt,
                    excludingCommitmentID: block.id.uuidString,
                    excludingBlockID: block.id
                ),
                // Evaluated against the snapped candidate slot while dragging,
                // so a conflict is shown on the spine before the drop rather
                // than reported afterwards.
                conflictAt: { minutesDelta in
                    conflicts(
                        start: block.startAt.addingTimeInterval(TimeInterval(minutesDelta * 60)),
                        end: block.endAt.addingTimeInterval(TimeInterval(minutesDelta * 60)),
                        excludingCommitmentID: block.id.uuidString,
                        excludingBlockID: block.id
                    )
                },
                minuteBounds: minuteBounds(for: block),
                boundaryDates: boundaryDates(excluding: block.id),
                move: { moveBlock(block, $0) },
                resize: { resizeBlock(block, $0) },
                resizeEdges: { resizeBlockEdges(block, $0, $1) },
                split: { splitBlock(block) },
                delete: { deleteBlock(block) },
                focus: { startFocus(block) }
        )
    }

    private func boundaryDates(excluding blockID: UUID) -> [Date] {
        displayCommitments.flatMap { [$0.startAt, $0.endAt] }
            + snapshot.blocks
                .filter { $0.id != blockID }
                .flatMap { [$0.startAt, $0.endAt] }
    }

    private var laneSpacing: CGFloat { 6 }

    /// A group of items that overlap each other, positioned as one band.
    struct TimelineCluster: Identifiable {
        struct CommitmentEntry: Identifiable {
            let commitment: PlanningFixedCommitment
            let lane: Int
            var id: String { commitment.id }
        }

        struct BlockEntry: Identifiable {
            let block: InternalTimeBlock
            let lane: Int
            var id: UUID { block.id }
        }

        let id: Int
        let laneCount: Int
        let top: CGFloat
        let height: CGFloat
        let commitments: [CommitmentEntry]
        let blocks: [BlockEntry]
    }

    private func timelineClusters(
        placements: [String: PlanTimelineLaneResolver.Placement]
    ) -> [TimelineCluster] {
        var commitmentsByCluster: [Int: [TimelineCluster.CommitmentEntry]] = [:]
        var blocksByCluster: [Int: [TimelineCluster.BlockEntry]] = [:]
        var laneCounts: [Int: Int] = [:]
        var spans: [Int: (top: CGFloat, bottom: CGFloat)] = [:]

        func extend(_ clusterID: Int, start: Date, end: Date) {
            let top = yPosition(start)
            let bottom = top + blockHeight(from: start, to: end)
            let current = spans[clusterID]
            spans[clusterID] = (
                min(current?.top ?? top, top),
                max(current?.bottom ?? bottom, bottom)
            )
        }

        for commitment in displayCommitments {
            guard let placement = placements["commitment:\(commitment.id)"] else { continue }
            commitmentsByCluster[placement.clusterID, default: []].append(
                .init(commitment: commitment, lane: placement.lane)
            )
            laneCounts[placement.clusterID] = placement.laneCount
            extend(placement.clusterID, start: commitment.startAt, end: commitment.endAt)
        }
        for block in snapshot.blocks {
            guard let placement = placements["block:\(block.id.uuidString)"] else { continue }
            blocksByCluster[placement.clusterID, default: []].append(
                .init(block: block, lane: placement.lane)
            )
            laneCounts[placement.clusterID] = placement.laneCount
            extend(placement.clusterID, start: block.startAt, end: block.endAt)
        }

        return laneCounts.keys.sorted().compactMap { clusterID in
            guard let span = spans[clusterID] else { return nil }
            return TimelineCluster(
                id: clusterID,
                laneCount: laneCounts[clusterID] ?? 1,
                top: span.top,
                height: max(1, span.bottom - span.top),
                commitments: commitmentsByCluster[clusterID] ?? [],
                blocks: blocksByCluster[clusterID] ?? []
            )
        }
    }

    private var timelineStart: Date {
        let base = snapshot.day.startDate() ?? Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: base) ?? base
    }

    private var isToday: Bool {
        snapshot.day.startDate().map { Calendar.current.isDateInToday($0) } ?? false
    }

    /// Today's canvas always reaches the present, so "now" is on it.
    private var nowAnchor: [Date] { isToday ? [Date()] : [] }

    /// A hairline at the current minute, the one live element on the canvas.
    private func nowLineLayer(width: CGFloat) -> some View {
        TimelineView(.everyMinute) { context in
            let y = yPosition(context.date)
            if y > 0, y < timelineHeight {
                HStack(spacing: 0) {
                    // Hour and minute only: "7:19 PM" wraps inside the ruler, and
                        // the ruler beside it already says which half of the day.
                        Text(PlanCanvasGeometry.nowLabel(context.date))
                        .lifeboardFont(.caption2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .frame(width: rulerWidth - 4, alignment: .trailing)
                        .padding(.trailing, 4)
                    Circle()
                        .fill(Color(SemanticColorTokens.foundationApricotAccent))
                        .frame(width: 8, height: 8)
                        // The one live element on the canvas breathes, inside the
                        // ambient budget, so "now" reads as happening.
                        .lifeBoardAmbientBreath(role: .liveIndicator)
                    Rectangle()
                        .fill(Color(SemanticColorTokens.foundationApricotAccent))
                        .frame(width: max(0, width - rulerWidth - 7), height: 1.5)
                }
                .offset(y: y - 6)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Now, \(context.date.formatted(date: .omitted, time: .shortened))")
                .accessibilityIdentifier("plan.canvas.nowLine")
            }
        }
    }

    private var startHour: Int {
        let dates = displayCommitments.map(\.startAt) + snapshot.blocks.map(\.startAt) + snapshot.freeWindows.map(\.startAt) + snapshot.workingIntervals.map(\.start) + nowAnchor
        guard let first = dates.min() else { return 8 }
        return max(0, Calendar.current.component(.hour, from: first) - 2)
    }

    private var endHour: Int {
        let dates = displayCommitments.map(\.endAt) + snapshot.blocks.map(\.endAt) + snapshot.freeWindows.map(\.endAt) + snapshot.workingIntervals.map(\.end) + nowAnchor
        guard let last = dates.max() else { return 18 }
        let components = Calendar.current.dateComponents([.hour, .minute], from: last)
        return min(24, max(startHour + 4, (components.hour ?? 17) + ((components.minute ?? 0) > 0 ? 2 : 1)))
    }

    private var hourSpan: Int { max(4, endHour - startHour) }
    private var timelineHeight: CGFloat { CGFloat(hourSpan) * hourHeight + 1 }

    /// How far a block may travel, in minutes, before it would leave the drawn
    /// day. The drag rubber-bands past these rather than stopping dead, so the
    /// edge of the canvas is felt instead of just refusing to move.
    private func minuteBounds(for block: InternalTimeBlock) -> ClosedRange<Int> {
        let timelineEnd = timelineStart.addingTimeInterval(TimeInterval(hourSpan) * 3_600)
        let earliest = Int(timelineStart.timeIntervalSince(block.startAt) / 60)
        let latest = Int(timelineEnd.timeIntervalSince(block.endAt) / 60)
        guard earliest <= latest else { return 0...0 }
        return earliest...latest
    }

    private func yPosition(_ date: Date) -> CGFloat {
        max(0, CGFloat(date.timeIntervalSince(timelineStart) / 3_600) * hourHeight)
    }

    private func blockHeight(from start: Date, to end: Date) -> CGFloat {
        max(30, CGFloat(max(0, end.timeIntervalSince(start)) / 3_600) * hourHeight - 3)
    }

    private var conflictCount: Int {
        let commitments = displayCommitments.filter {
            conflicts(start: $0.startAt, end: $0.endAt, excludingCommitmentID: $0.id, excludingBlockID: UUID(uuidString: $0.id))
        }.count
        let blocks = snapshot.blocks.filter {
            conflicts(start: $0.startAt, end: $0.endAt, excludingCommitmentID: $0.id.uuidString, excludingBlockID: $0.id)
        }.count
        return commitments + blocks
    }

    private func conflicts(start: Date, end: Date, excludingCommitmentID: String?, excludingBlockID: UUID?) -> Bool {
        let overlapsCommitment = displayCommitments.contains { value in
            value.id != excludingCommitmentID && value.startAt < end && value.endAt > start
        }
        let overlapsBlock = snapshot.blocks.contains { value in
            value.id != excludingBlockID && value.startAt < end && value.endAt > start
        }
        return overlapsCommitment || overlapsBlock
    }

    private func hourLabel(_ hour: Int) -> String { PlanCanvasGeometry.hourLabel(hour) }

    private func timeLabel(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func durationLabel(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int((interval / 60).rounded()))
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h\(minutes % 60 == 0 ? "" : " \(minutes % 60)m")"
    }
}

/// A horizontally pannable band of overlapping lanes.
///
/// This does by hand what a `ScrollView(.horizontal)` should have done. Nested
/// inside the canvas — a `GeometryReader` holding a `ZStack` of `.offset` layers,
/// itself inside the page's vertical scroll — the scroll view never received a
/// pan: it sized itself to its content and the lanes past the edge were simply
/// clipped, unreachable. Owning the offset makes the behaviour explicit and
/// testable instead of dependent on how SwiftUI arbitrates nested scrolling.
///
/// The gesture is attached simultaneously so a vertical drag still scrolls the
/// page underneath; only the horizontal component is consumed here.
/// One VoiceOver action per repair the deck offers.
///
/// Written as a modifier because `accessibilityAction` cannot be applied in a
/// loop over a variable-length list; each direction needs its own named action
/// so a flick and a rotor selection reach exactly the same set of repairs.
struct PlanClusterStrip<Content: View>: View {
    let contentWidth: CGFloat
    let laneCount: Int
    let laneWidth: CGFloat
    let spacing: CGFloat
    let height: CGFloat
    @ViewBuilder var content: Content

    @State private var committed: CGFloat = 0
    @GestureState private var live: CGFloat = 0

    private var totalWidth: CGFloat {
        PlanTimelineLaneResolver.stripWidth(
            laneCount: laneCount, laneWidth: laneWidth, spacing: spacing
        )
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        PlanTimelineLaneResolver.clampedStripOffset(
            value, contentWidth: contentWidth, stripWidth: totalWidth
        )
    }

    var body: some View {
        content
            .frame(width: totalWidth, alignment: .topLeading)
            .offset(x: clamp(committed + live))
            .frame(width: contentWidth, height: height, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .updating($live) { value, state, _ in
                        // Vertical intent belongs to the page, not the strip.
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        state = value.translation.width
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        committed = clamp(committed + value.translation.width)
                    }
            )
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.86), value: committed)
    }
}

struct PlanCanvasBlock: View {
    let block: InternalTimeBlock
    let width: CGFloat
    let height: CGFloat
    let hourHeight: CGFloat
    let hasConflict: Bool
    let conflictAt: (Int) -> Bool
    let minuteBounds: ClosedRange<Int>
    let boundaryDates: [Date]
    let move: (Int) -> Void
    let resize: (Int) -> Void
    let resizeEdges: (Int, Int) -> Void
    let split: () -> Void
    let delete: () -> Void
    let focus: () -> Void

    /// The snapped candidate, in minutes from the block's current start. Held as
    /// gesture state so an interrupted drag cannot strand the block off-grid.
    @GestureState private var draggedMinutes: Int = 0
    @GestureState private var topResizeMinutes: Int = 0
    @GestureState private var bottomResizeMinutes: Int = 0
    /// Mirrors `draggedMinutes` outside the gesture so the detent haptic fires
    /// exactly once per crossing rather than on every touch sample.
    @State private var lastDetent: Int = 0

    private func snapped(_ translation: CGFloat) -> Int {
        PlanBlockSnapResolver.snappedMinutes(
            translation: translation,
            hourHeight: hourHeight,
            bounds: minuteBounds
        )
    }

    /// A lane is this narrow as soon as anything overlaps, since two lanes split
    /// the canvas. At that width the chrome costs more than it says: the accent
    /// bar, the inline conflict triangle and a full-size menu button together
    /// squeeze the title down to "Foc…". Conflict still reads from the card's
    /// tint and border and from the count in the canvas header, so the
    /// decoration goes and the name stays.
    private var isCompact: Bool { width < 140 }

    var body: some View {
        HStack(alignment: .top, spacing: isCompact ? 4 : 7) {
            if isCompact == false {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(SemanticColorTokens.foundationApricotAccent))
                    .frame(width: 5)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(block.title).lineLimit(1)
                    if showsConflict, isCompact == false {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                }
                .font(.caption.weight(.semibold))
                // While dragging, the row reads out the slot it would land in,
                // so the commitment is legible before the finger lifts.
                Text("\(candidateStart.formatted(date: .omitted, time: .shortened))–\(candidateEnd.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).lineLimit(1)
                    .monospacedDigit()
            }
            Spacer(minLength: 2)
            Menu {
                Button("Start focus", systemImage: "timer", action: focus)
                // The drag snaps to five minutes for small corrections, so the
                // menu has to offer the same granularity or the pointer and
                // keyboard paths cannot reach every slot the finger can.
                Button("Move 5 minutes earlier", systemImage: "arrow.up") { move(-5) }
                Button("Move 5 minutes later", systemImage: "arrow.down") { move(5) }
                Button("Move 15 minutes earlier", systemImage: "arrow.up.to.line") { move(-15) }
                Button("Move 15 minutes later", systemImage: "arrow.down.to.line") { move(15) }
                Button("Add 15 minutes", systemImage: "plus") { resize(15) }
                Button("Remove 15 minutes", systemImage: "minus") { resize(-15) }
                Button("Split", systemImage: "rectangle.split.2x1", action: split)
                Button("Remove", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: isCompact ? 22 : 30, height: 30)
            }
        }
        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
        .padding(.leading, isCompact ? 5 : 7)
        .padding(.trailing, isCompact ? 2 : 5)
        .frame(
            width: width,
            height: max(
                16,
                height + CGFloat(bottomResizeMinutes - topResizeMinutes) / 60 * hourHeight
            ),
            alignment: .topLeading
        )
        .background(
            showsConflict
                ? Color(SemanticColorTokens.foundationApricotAccent).opacity(0.34)
                : Color(SemanticColorTokens.foundationSurfaceSelected),
            in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    Color(SemanticColorTokens.foundationApricotAccent)
                        .opacity(isDragging ? 0.9 : 0.48),
                    lineWidth: isDragging ? 2 : 1
                )
        }
        .offset(y: CGFloat(draggedMinutes + topResizeMinutes) / 60 * hourHeight)
        .contentShape(Rectangle())
        // Press and hold before moving, the way the system calendar does.
        //
        // A plain drag here used to claim every touch that landed on a block,
        // and blocks cover nearly all of a crowded cluster — so the horizontal
        // scroll that reaches the lanes past the second one could never win the
        // gesture, and those items were unreachable. Requiring the press frees
        // ordinary drags to scroll the strip and keeps the move deliberate.
        .gesture(
            LongPressGesture(minimumDuration: 0.28)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .updating($draggedMinutes) { value, state, _ in
                    guard case .second(true, let drag?) = value else { return }
                    state = PlanBlockSnapResolver.snappedMinutes(
                        translation: drag.translation.height,
                        hourHeight: hourHeight,
                        bounds: minuteBounds
                    )
                }
                .onChanged { value in
                    switch value {
                    case .second(true, nil):
                        // The hold registered: say so, or the block feels dead
                        // until the finger has already moved.
                        Haptic.settle.play()
                    case .second(true, let drag?):
                        let snapped = snapped(drag.translation.height)
                        guard snapped != lastDetent else { return }
                        lastDetent = snapped
                        Haptic.pick.play()
                    default:
                        break
                    }
                }
                .onEnded { value in
                    lastDetent = 0
                    guard case .second(true, let drag?) = value else { return }
                    let snapped = snapped(drag.translation.height)
                    // The lift is a settle; the commit haptic follows the write
                    // from `PlanStore`, so a move that fails no longer feels
                    // like one that succeeded.
                    if snapped != 0 {
                        Haptic.settle.play()
                        move(snapped)
                    } else if abs(drag.translation.height) > 8 {
                        Haptic.settle.play()
                    }
                }
        )
        .overlay(alignment: .top) {
            resizeHandle(
                label: "Resize start",
                identifier: "plan.canvas.block.\(block.id.uuidString).resizeStart"
            )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($topResizeMinutes) { value, state, _ in
                            state = resizeSnap(
                                value.translation.height,
                                bounds: -1_440...max(0, Int(block.duration / 60) - 15),
                                movingEdgeAt: block.startAt
                            )
                        }
                        .onEnded { value in
                            let delta = resizeSnap(
                                value.translation.height,
                                bounds: -1_440...max(0, Int(block.duration / 60) - 15),
                                movingEdgeAt: block.startAt
                            )
                            guard delta != 0 else { return }
                            Haptic.settle.play()
                            resizeEdges(delta, 0)
                        }
                )
        }
        .overlay(alignment: .bottom) {
            resizeHandle(
                label: "Resize end",
                identifier: "plan.canvas.block.\(block.id.uuidString).resizeEnd"
            )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($bottomResizeMinutes) { value, state, _ in
                            state = resizeSnap(
                                value.translation.height,
                                bounds: min(0, 15 - Int(block.duration / 60))...1_440,
                                movingEdgeAt: block.endAt
                            )
                        }
                        .onEnded { value in
                            let delta = resizeSnap(
                                value.translation.height,
                                bounds: min(0, 15 - Int(block.duration / 60))...1_440,
                                movingEdgeAt: block.endAt
                            )
                            guard delta != 0 else { return }
                            Haptic.settle.play()
                            resizeEdges(0, delta)
                        }
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(block.startAt.formatted(date: .omitted, time: .shortened)) to \(block.endAt.formatted(date: .omitted, time: .shortened))\(hasConflict ? ", conflicts with another item" : "")")
        .accessibilityAdjustableAction { direction in move(direction == .increment ? 15 : -15) }
        .accessibilityAction(named: "Move 5 minutes earlier") { move(-5) }
        .accessibilityAction(named: "Move 5 minutes later") { move(5) }
        .accessibilityAction(named: "Add 15 minutes") { resize(15) }
        .accessibilityAction(named: "Remove 15 minutes") { resize(-15) }
        .accessibilityAction(named: "Start focus", focus)
        .accessibilityIdentifier("plan.canvas.block.\(block.id.uuidString)")
    }

    private var isDragging: Bool {
        draggedMinutes != 0 || topResizeMinutes != 0 || bottomResizeMinutes != 0
    }

    private var candidateStart: Date {
        block.startAt.addingTimeInterval(TimeInterval((draggedMinutes + topResizeMinutes) * 60))
    }

    private var candidateEnd: Date {
        block.endAt.addingTimeInterval(TimeInterval((draggedMinutes + bottomResizeMinutes) * 60))
    }

    private func resizeSnap(
        _ translation: CGFloat,
        bounds: ClosedRange<Int>,
        movingEdgeAt: Date
    ) -> Int {
        PlanBlockSnapResolver.boundaryAwareSnappedMinutes(
            translation: translation,
            hourHeight: hourHeight,
            movingEdgeAt: movingEdgeAt,
            boundaries: boundaryDates,
            bounds: bounds
        )
    }

    private func resizeHandle(label: String, identifier: String) -> some View {
        Capsule()
            .fill(Color(SemanticColorTokens.foundationApricotAccent))
            .frame(width: 30, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(label)
            .accessibilityHint("Drag, or use the duration actions in the menu")
            .accessibilityIdentifier(identifier)
    }

    /// During a drag the block reports the candidate slot's conflict, not its
    /// current one — otherwise dragging *out* of a clash keeps showing the
    /// warning and dragging *into* one shows nothing until the drop.
    private var showsConflict: Bool {
        isDragging ? conflictAt(draggedMinutes) : hasConflict
    }
}

/// Where a drop on the day canvas lands, in time.
enum PlanCanvasDropResolver {
    static let snapMinutes = 15

    static func start(
        forY y: CGFloat,
        timelineStart: Date,
        hourHeight: CGFloat,
        snapMinutes: Int = snapMinutes
    ) -> Date {
        let minutes = max(0, Double(y / hourHeight) * 60)
        let snapped = (minutes / Double(snapMinutes)).rounded() * Double(snapMinutes)
        return timelineStart.addingTimeInterval(snapped * 60)
    }
}

private struct PlanCanvasDropDelegate: DropDelegate {
    let update: (CGFloat?) -> Void
    let perform: (UUID, CGFloat) -> Void
    func dropUpdated(info: DropInfo) -> DropProposal? {
        update(info.location.y)
        return DropProposal(operation: .copy)
    }
    func dropExited(info: DropInfo) { update(nil) }
    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else { return false }
        let y = info.location.y
        update(nil)
        _ = provider.loadObject(ofClass: String.self) { value, _ in
            guard let value, let id = UUID(uuidString: value) else { return }
            Task { @MainActor in perform(id, y) }
        }
        return true
    }
}

/// Pure geometry and wording for the day canvas, kept out of the view so the
/// rules are testable.
enum PlanCanvasGeometry {
    /// "6 AM", "Noon", "6 PM": the ruler only needs the hour.
    static func hourLabel(_ hour: Int) -> String {
        switch hour % 24 {
        case 0: return "12 AM"
        case 12: return "Noon"
        case let value where value < 12: return "\(value) AM"
        case let value: return "\(value - 12) PM"
        }
    }

    /// Today opens with now a third of the way down; other days open at their
    /// first item, at the top.
    static func initialAnchor(isToday: Bool) -> UnitPoint {
        isToday ? UnitPoint(x: 0.5, y: 0.33) : .top
    }

    /// "7:25": no leading zero, no AM/PM (the ruler beside it already says).
    static func nowLabel(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour = (parts.hour ?? 0) % 12 == 0 ? 12 : (parts.hour ?? 0) % 12
        return String(format: "%d:%02d", hour, parts.minute ?? 0)
    }

    /// The parts of the drawn span outside working hours, to the minute. It
    /// used to shade whole hours by testing each hour's start, and because
    /// `DateInterval.contains` includes its end, 6 PM counted as working.
    static func nonworkingIntervals(within span: DateInterval, working: [DateInterval]) -> [DateInterval] {
        var gaps: [DateInterval] = []
        var cursor = span.start
        for interval in working.sorted(by: { $0.start < $1.start }) where interval.end > cursor && interval.start < span.end {
            if interval.start > cursor { gaps.append(DateInterval(start: cursor, end: interval.start)) }
            cursor = max(cursor, interval.end)
        }
        if cursor < span.end { gaps.append(DateInterval(start: cursor, end: span.end)) }
        return gaps
    }

    static func labelsOpenWindow(duration: TimeInterval) -> Bool {
        duration >= 45 * 60
    }
}

/// When a sideways drag on the canvas becomes a day change.
enum PlanDaySwipe {
    static func isHorizontal(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height) * 2
    }

    /// +1 for the next day (swipe left), -1 for the previous, 0 to spring back.
    /// Commits past 30% of the width, or on a flick that would carry that far.
    static func dayDelta(translation: CGSize, predictedEndTranslation: CGSize, width: CGFloat) -> Int {
        guard width > 0, isHorizontal(translation), abs(translation.width) >= 24 else { return 0 }
        let threshold = width * 0.3
        let travel = abs(translation.width) >= threshold ? translation.width
            : abs(predictedEndTranslation.width) >= threshold * 1.5 ? predictedEndTranslation.width
            : 0
        guard travel != 0, travel.sign == translation.width.sign else { return 0 }
        return travel < 0 ? 1 : -1
    }
}
