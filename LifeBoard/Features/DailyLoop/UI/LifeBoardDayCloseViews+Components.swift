import SwiftUI

extension DayCloseRoute {
    // MARK: - Backdrop

    var backdrop: some View {
        Color(SemanticColorTokens.foundationCanvas)
            .lifeboardPaperGrain()
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    func factLine(_ text: String) -> some View {
        Text(text)
            .font(Typography.metric())
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
    }

    /// Deterministic per-row lean, so the loose stack does not reshuffle itself
    /// on every re-render. Small enough to read as "not yet filed" rather than
    /// as a layout bug.
    func proposalLean(_ index: Int) -> CGFloat {
        let magnitudes: [CGFloat] = [6, -4, 9, -7, 3]
        return magnitudes[index % magnitudes.count]
    }

    // MARK: - Shared

    func sectionHeader(_ title: String) -> some View {
        // The shared header, so the loop's acts carry the same heading trait and
        // accessibility-size stacking as every other section in the product.
        SectionHeader(title)
    }
}

// MARK: - Ribbon strip

/// The day as a horizontal band: three stacked tracks, drawn in on appear.
///
/// Scrolls rather than compressing. A twelve-hour day squeezed into 350 points
/// makes a twenty-minute block one pixel wide, which is a chart that cannot be
/// read and therefore is not worth drawing.
struct DayCloseRibbonStrip: View {
    let ribbon: DayCloseRibbon

    @State private var reveal: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let pointsPerHour: CGFloat = 64
    private static let laneHeight: CGFloat = 22

    private var width: CGFloat {
        max(CGFloat(ribbon.duration / 3_600) * Self.pointsPerHour, 320)
    }

    var body: some View {
        ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                ForEach(ribbon.segments) { segment in
                    segmentView(segment)
                }
                ForEach(ribbon.completionMarks) { mark in
                    completionView(mark)
                }
            }
            .frame(
                width: width,
                height: CGFloat(max(ribbon.laneCount, 1)) * (Self.laneHeight + 6) + 18,
                alignment: .topLeading
            )
            .lifeboardChartRevealSweep(progress: reveal)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your day, hour by hour")
        .accessibilityValue(prose)
        .onAppear {
            guard let animation = MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion) else {
                return reveal = 1
            }
            withAnimation(animation) { reveal = 1 }
        }
    }

    /// Charts always ship a prose equivalent.
    private var prose: String {
        let planned = ribbon.segments.count { $0.kind == .planned }
        let focused = ribbon.segments.count { $0.kind == .focused }
        func count(_ value: Int, _ singular: String, _ plural: String) -> String {
            "\(value) \(value == 1 ? singular : plural)"
        }
        return [
            count(planned, "planned block", "planned blocks"),
            count(focused, "focus session", "focus sessions"),
            count(ribbon.completionMarks.count, "finished task", "finished tasks")
        ].joined(separator: ", ") + "."
    }

    private func segmentView(_ segment: DayCloseRibbonSegment) -> some View {
        let start = ribbon.position(of: segment.startAt) ?? 0
        let end = ribbon.position(of: segment.endAt) ?? start
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(fill(for: segment.kind))
            .frame(
                width: max(CGFloat(end - start) * width, 3),
                height: Self.laneHeight
            )
            .offset(
                x: CGFloat(start) * width,
                y: CGFloat(segment.lane) * (Self.laneHeight + 6)
            )
    }

    private func completionView(_ mark: DayCloseCompletionMark) -> some View {
        Circle()
            .fill(Color(SemanticColorTokens.foundationSunAccent))
            .frame(width: 7, height: 7)
            .offset(
                x: CGFloat(ribbon.position(of: mark.completedAt) ?? 0) * width,
                y: CGFloat(max(ribbon.laneCount, 1)) * (Self.laneHeight + 6) + 4
            )
    }

    /// External commitments read differently from authored blocks — the ribbon
    /// must never imply LifeBoard scheduled someone else's meeting.
    private func fill(for kind: DayCloseRibbonSegment.Kind) -> Color {
        switch kind {
        case .planned: Color(SemanticColorTokens.foundationApricotAccent)
        case .commitment: Color(SemanticColorTokens.foundationSageAccent)
        case .focused: Color(SemanticColorTokens.foundationSunAccent)
        }
    }
}

// MARK: - Deck card

struct DayCloseCard: View {
    let task: PlanningTaskSummary
    let armedDirection: DeckDirection?

    private var armed: DayCloseDirection? {
        armedDirection.flatMap {
            DeckPhysics.action(for: $0, candidates: DayCloseDirection.allCases)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(task.title)
                .font(Typography.sectionTitle())
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .multilineTextAlignment(.leading)

            if let estimate = task.estimatedDuration {
                Text("\(Int(estimate / 60)) min planned")
                    .font(Typography.metadata())
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }

            // The armed direction has to be visible before the finger lifts. A
            // gesture that mutates the plan and cannot be seen resolving is a
            // guess, not a decision.
            Label(armed?.title ?? "Flick to decide", systemImage: armed?.symbolName ?? "hand.draw")
                .font(Typography.metric())
                .foregroundStyle(
                    armed == nil
                        ? Color(SemanticColorTokens.inkTertiary)
                        : Color(SemanticColorTokens.inkPrimary)
                )
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(18)
        .lifeBoardClaySurface(armedDepth, cornerRadius: Radius.largeCard)
        // Preview the consequence while the finger is still down.
        //
        // All four directions used to differ only by a label. Letting the card
        // *behave* like the decision — receding when it is being put off,
        // starting to erode when it is being let go — means you feel what you
        // are choosing before you commit to it, and can back out by returning
        // to centre. Nothing here is persisted; the deck still commits only on
        // release, and success feedback still waits for the batch.
        .scaleEffect(previewScale, anchor: .center)
        .opacity(previewOpacity)
        .lifeboardDissolveAway(progress: erosionPreview, tint: releaseTint)
        .lifeBoardMotion(.deckSettle, value: armed)
    }

    /// Warm rather than alarming: releasing something is a legitimate outcome,
    /// not a failure, and the anti-guilt law puts no punitive red on this path.
    private var releaseTint: Color {
        Color(SemanticColorTokens.foundationApricotAccent)
    }

    /// A hint of erosion, never enough to hide the title being decided about.
    private var erosionPreview: Double {
        armed == .release ? 0.22 : 0
    }

    private var previewScale: CGFloat {
        switch armed {
        // Being put off — the card steps back.
        case .someday: 0.955
        // Being carried forward — it leans in.
        case .tomorrow: 1.012
        default: 1
        }
    }

    private var previewOpacity: Double {
        armed == .someday ? 0.82 : 1
    }

    /// `.doneAnyway` was the one direction with no feeling, because it is the
    /// one that is not a *change*: the work already happened and only the record
    /// is catching up. Nothing should move, so instead of leaning, receding or
    /// eroding, the card stops floating — the drop shadow shrinks from radius 10
    /// to 4 and it settles onto the canvas, which reads as "already landed".
    ///
    /// Deliberately not `CompletionMark`: that is success feedback, and
    /// DESIGN.md requires a persisted-state boundary before success. Arming is
    /// not a persisted state — the deck still commits one batch at the end, and
    /// returning to centre must be able to take this back.
    private var armedDepth: ClayDepth {
        armed == .doneAnyway ? .resting : .raised
    }
}

// MARK: - Direction pad

/// The four directions, always visible and always tappable.
///
/// The deck's flick is an accelerator. This is the equal path, and it is what
/// makes the gesture legible in the first place — nobody discovers four
/// directions by guessing.
struct DayCloseDirectionPad: View {
    let armed: DayCloseDirection?
    let onSelect: (DayCloseDirection) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Four labelled chips in one row cannot hold their labels at
        // accessibility sizes, and these buttons *are* the accessible path to
        // the deck's gesture — so they fold into a 2×2 grid rather than
        // truncating. `DESIGN.md`: collapse grids before truncating.
        if dynamicTypeSize.isAccessibilitySize {
            let pairs = stride(from: 0, to: DayCloseDirection.allCases.count, by: 2).map {
                Array(DayCloseDirection.allCases[$0..<min($0 + 2, DayCloseDirection.allCases.count)])
            }
            VStack(spacing: 8) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { direction in
                            directionButton(direction)
                        }
                    }
                }
            }
        } else {
            HStack(spacing: 8) {
                ForEach(DayCloseDirection.allCases, id: \.self) { direction in
                    directionButton(direction)
                }
            }
        }
    }

    private func directionButton(_ direction: DayCloseDirection) -> some View {
        Button { onSelect(direction) } label: {
            VStack(spacing: 4) {
                Image(systemName: direction.symbolName)
                Text(direction.title)
                    .font(Typography.metadata())
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lifeBoardChip)
        .accessibilityIdentifier("dayClose.direction.\(direction.rawValue)")
    }
}
