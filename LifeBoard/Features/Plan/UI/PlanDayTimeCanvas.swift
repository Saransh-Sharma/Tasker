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
    /// The canvas's own width. The swipe threshold is a fraction of it; the
    /// screen's width was wrong in Split View, Stage Manager and on the Mac.
    @State private var canvasWidth: CGFloat = 390
    @State private var lastSnappedLandingMinute: Int?
    @State private var landingTrigger = 0
    @State private var landingCenter: UnitPoint = .center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var displayCommitments: [PlanningFixedCommitment] {
        let linked = Set(snapshot.blocks.compactMap(\.taskID))
        return snapshot.commitments + snapshot.plannedTasks.compactMap { task in
            guard !linked.contains(task.id), let start = task.scheduledStartAt else { return nil }
            return PlanningFixedCommitment(id: "task:" + task.id.uuidString, title: task.title,
                startAt: start, endAt: task.scheduledEndAt ?? start.addingTimeInterval(task.estimatedDuration ?? 30 * 60), source: .internalBlock)
        }
    }

    let hourHeight: CGFloat = 66
    let rulerWidth: CGFloat = 48

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The day is named and stepped by `PlanOrientationBar`; the canvas
            // only speaks up when something on it overlaps.
            if conflictCount > 0 {
                Label(
                    conflictCount == 1 ? String(localized: "1 overlap") : String(localized: "\(conflictCount) overlaps"),
                    systemImage: "square.stack"
                )
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                    .accessibilityHint("Highlighted in the timeline")
            }

            ScrollViewReader { reader in
                ScrollView {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    nonworkingLayer(width: proxy.size.width)
                    overloadLayer(width: proxy.size.width)
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
                                .stroke(Color(SemanticColorTokens.foundationApricotInk), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
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
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { canvasWidth = $0 }
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
                        width: canvasWidth
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

    /// The planned time that does not fit the working window, drawn where it
    /// would spill: a soft band past the end of the day, in the same attention
    /// colour as the orientation bar's "over" reading, with the same words.
    @ViewBuilder
    private func overloadLayer(width: CGFloat) -> some View {
        if let band = overloadBand {
            let height = CGFloat(band.duration / 3_600) * hourHeight
            ZStack(alignment: .topLeading) {
                Rectangle()
                    // 0.16, not the free windows' 0.12: the band sits on the
                    // recessed non-working shade and at 0.10 it vanished into it.
                    .fill(Color(SemanticColorTokens.foundationApricotAccent).opacity(0.16))
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0.5))
                    path.addLine(to: CGPoint(x: max(1, width - rulerWidth), y: 0.5))
                }
                .stroke(Color(SemanticColorTokens.foundationApricotInk).opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                Text(PlanCapacityCopy.openLabel(snapshot.capacity))
                    .lifeboardFont(.caption2)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
            }
            .frame(width: max(1, width - rulerWidth), height: max(12, height), alignment: .topLeading)
            .offset(x: rulerWidth, y: yPosition(band.start))
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(PlanCapacityCopy.overloadAccessibilityLabel(snapshot.capacity))
            .accessibilityIdentifier("plan.canvas.overload")
        }
    }

    private var overloadBand: DateInterval? {
        PlanCanvasGeometry.overloadBand(working: snapshot.workingIntervals, overload: snapshot.capacity.overloadDuration)
    }

    private func hourGrid(width: CGFloat) -> some View {
        ForEach(0...hourSpan, id: \.self) { offset in
            let hour = startHour + offset
            HStack(spacing: 8) {
                // The ruler sits straight on the daypart scene, not a card. The
                // sky runs 0.3–0.8 luminance across phases; tertiary ink measured
                // 1.9:1 at night and 3.2:1 at morning in light appearance, and
                // only primary ink clears 4.5:1 across the whole range.
                Text(hourLabel(hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
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
                createBlock(String(localized: "Focus"), window.startAt, min(window.duration, 60 * 60), nil)
            } label: {
                // Open time stays quiet: short gaps carry no words at all.
                VStack(alignment: .leading, spacing: 4) {
                    if PlanCanvasGeometry.labelsOpenWindow(duration: window.duration) {
                        Text("Open · \(durationLabel(window.duration))")
                            .lifeboardFont(.caption2)
                            .padding(.top, 4)
                    } else if PlanCanvasGeometry.labelsOpenWindowBriefly(duration: window.duration) {
                        Text(durationLabel(window.duration))
                            .lifeboardFont(.caption2)
                            .padding(.top, 4)
                    }
                }
                // A 12% sage wash over the scene is not a surface; see the ruler.
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .padding(.horizontal, 9)
                .frame(width: max(1, width - rulerWidth - 8), height: blockHeight(from: window.startAt, to: window.endAt), alignment: .topLeading)
                .background(Color(SemanticColorTokens.foundationSageAccent).opacity(0.12), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: Radius.field, style: .continuous).stroke(Color(SemanticColorTokens.foundationSageInk).opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
            }
            .buttonStyle(.plain)
            .offset(x: rulerWidth, y: yPosition(window.startAt))

            .accessibilityLabel("Free time, \(timeLabel(window.startAt)) to \(timeLabel(window.endAt))")
            .accessibilityHint("Adds a time block")
            .accessibilityIdentifier("plan.canvas.freeWindow.\(window.id)")
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

    private var startHour: Int {
        let dates = displayCommitments.map(\.startAt) + snapshot.blocks.map(\.startAt) + snapshot.freeWindows.map(\.startAt) + snapshot.workingIntervals.map(\.start) + nowAnchor
        guard let first = dates.min() else { return 8 }
        return max(0, Calendar.current.component(.hour, from: first) - 2)
    }

    private var endHour: Int {
        let dates = displayCommitments.map(\.endAt) + snapshot.blocks.map(\.endAt) + snapshot.freeWindows.map(\.endAt) + snapshot.workingIntervals.map(\.end) + nowAnchor
            + [overloadBand?.end].compactMap { $0 }
        guard let last = dates.max() else { return 18 }
        let components = Calendar.current.dateComponents([.hour, .minute], from: last)
        return min(24, max(startHour + 4, (components.hour ?? 17) + ((components.minute ?? 0) > 0 ? 2 : 1)))
    }

    private var hourSpan: Int { max(4, endHour - startHour) }
    var timelineHeight: CGFloat { CGFloat(hourSpan) * hourHeight + 1 }

    /// How far a block may travel, in minutes, before it would leave the drawn
    /// day. The drag rubber-bands past these rather than stopping dead, so the
    /// edge of the canvas is felt instead of just refusing to move.
    func minuteBounds(for block: InternalTimeBlock) -> ClosedRange<Int> {
        let timelineEnd = timelineStart.addingTimeInterval(TimeInterval(hourSpan) * 3_600)
        let earliest = Int(timelineStart.timeIntervalSince(block.startAt) / 60)
        let latest = Int(timelineEnd.timeIntervalSince(block.endAt) / 60)
        guard earliest <= latest else { return 0...0 }
        return earliest...latest
    }

    /// Positioned by wall-clock hour and minute, as the ruler is labelled.
    func yPosition(_ date: Date) -> CGFloat {
        max(0, CGFloat(PlanCanvasGeometry.wallClockHours(from: timelineStart, to: date)) * hourHeight)
    }

    func blockHeight(from start: Date, to end: Date) -> CGFloat {
        let hours = PlanCanvasGeometry.wallClockHours(from: start, to: end)
        return max(30, CGFloat(max(0, hours)) * hourHeight - 3)
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

    func conflicts(start: Date, end: Date, excludingCommitmentID: String?, excludingBlockID: UUID?) -> Bool {
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
        LifeBoardDuration.text(seconds: max(0, interval))
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
            .animation(MotionProfile.directManipulation.animation(reduceMotion: reduceMotion), value: committed)
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
                Button("5 min earlier", systemImage: "arrow.up") { move(-5) }
                Button("5 min later", systemImage: "arrow.down") { move(5) }
                Button("15 min earlier", systemImage: "arrow.up.to.line") { move(-15) }
                Button("15 min later", systemImage: "arrow.down.to.line") { move(15) }
                Button("Add 15 min", systemImage: "plus") { resize(15) }
                Button("Remove 15 min", systemImage: "minus") { resize(-15) }
                Button("Split", systemImage: "rectangle.split.2x1", action: split)
                Button("Remove", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: isCompact ? 22 : 30, height: 30)
                    .contentShape(Rectangle())
            }
            .hoverEffect(.highlight)
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
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
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
                blockHeight: height,
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
                blockHeight: height,
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
        .accessibilityLabel("\(block.title), \(block.startAt.formatted(date: .omitted, time: .shortened)) to \(block.endAt.formatted(date: .omitted, time: .shortened))\(hasConflict ? ", overlaps another block" : "")")
        .accessibilityAdjustableAction { direction in move(direction == .increment ? 15 : -15) }
        .accessibilityAction(named: "5 min earlier") { move(-5) }
        .accessibilityAction(named: "5 min later") { move(5) }
        .accessibilityAction(named: "Add 15 min") { resize(15) }
        .accessibilityAction(named: "Remove 15 min") { resize(-15) }
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

    /// A resize grip whose hit area never swallows the block.
    ///
    /// Each handle was a full-width, 44-point overlay. On a block under 88
    /// points (anything shorter than about 80 minutes) the two covered the
    /// whole block, so press-and-drag resized instead of moving, and the top
    /// one sat on the "…" menu, which could not be tapped. The grip now takes
    /// at most a quarter of the block's height and stops short of the menu.
    private func resizeHandle(label: String, blockHeight: CGFloat, identifier: String) -> some View {
        Capsule()
            .fill(Color(SemanticColorTokens.foundationApricotAccent))
            .frame(width: 30, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: min(44, max(12, blockHeight / 4)))
            .contentShape(Rectangle())
            .padding(.trailing, 44)
            .accessibilityLabel(label)
            .accessibilityHint("Drag to resize")
            .accessibilityIdentifier(identifier)
    }

    /// During a drag the block reports the candidate slot's conflict, not its
    /// current one — otherwise dragging *out* of a clash keeps showing the
    /// warning and dragging *into* one shows nothing until the drop.
    private var showsConflict: Bool {
        isDragging ? conflictAt(draggedMinutes) : hasConflict
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

