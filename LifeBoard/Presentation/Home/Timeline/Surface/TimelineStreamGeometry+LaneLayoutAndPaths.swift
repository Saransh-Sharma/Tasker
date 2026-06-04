import SwiftUI

extension TimelineStreamGeometry {
    static func make(
        plan: TimelineCanvasLayoutPlan,
        baseX: CGFloat,
        laneHalfWidth: CGFloat
    ) -> TimelineStreamGeometry {
        TimelineStreamGeometry(
            baseX: baseX,
            laneHalfWidth: laneHalfWidth,
            startY: plan.spineExtent.startY,
            endY: plan.spineExtent.fadeEndY,
            influences: plan.visualElements.compactMap(Self.influence)
        )
    }

    static func laneMetrics(
        totalWidth: CGFloat,
        labelRightX: CGFloat,
        trailingReservedWidth: CGFloat,
        layoutClass: LifeBoardLayoutClass
    ) -> LaneMetrics {
        let preferred: CGFloat
        let minimum: CGFloat
        let contentGap: CGFloat
        switch layoutClass {
        case .phone:
            if totalWidth <= 390 {
                minimum = 34
                preferred = 36
                contentGap = 8
            } else if totalWidth <= 430 {
                minimum = 36
                preferred = 38
                contentGap = 8
            } else {
                minimum = 40
                preferred = 42
                contentGap = 8
            }
        case .padCompact:
            minimum = 72
            preferred = 78
            contentGap = contentGapAfterLane
        case .padRegular, .padExpanded:
            minimum = 76
            preferred = 84
            contentGap = contentGapAfterLane
        }

        let available = totalWidth
            - labelRightX
            - trailingReservedWidth
            - contentGap
            - minimumPhoneContentWidth
        let laneWidth = min(preferred, max(minimum, available))
        let leadingX = labelRightX
        let centerX = leadingX + (laneWidth / 2)
        let contentX = leadingX + laneWidth + contentGap
        return LaneMetrics(width: laneWidth, leadingX: leadingX, centerX: centerX, contentX: contentX)
    }

    static func influence(
        for positioned: TimelineCanvasLayoutPlan.PositionedVisualTimelineElement
    ) -> TimelineStreamInfluence? {
        switch positioned.element {
        case .routineMarker:
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .routine,
                centerY: positioned.centerY,
                height: positioned.height,
                tintHex: nil
            )
        case .meetingCard(let model):
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .meeting,
                centerY: positioned.centerY,
                height: positioned.height,
                tintHex: model.item.tintHex
            )
        case .taskMarker(let model), .taskCard(let model):
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .task,
                centerY: positioned.centerY,
                height: positioned.height,
                tintHex: model.item.tintHex
            )
        case .flock(let model):
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .flock,
                centerY: positioned.centerY,
                height: positioned.height,
                tintHex: model.block.items.first(where: { $0.source == .task })?.tintHex
                    ?? model.block.items.first?.tintHex,
                stackCount: max(model.block.items.count, 2)
            )
        case .gapPrompt(let model):
            return TimelineStreamInfluence(
                id: positioned.id,
                kind: .gap,
                centerY: positioned.centerY,
                height: max(positioned.height, CGFloat(model.gap.duration / 60) * 0.35),
                tintHex: nil
            )
        case .emptyState:
            return nil
        }
    }

    func clampedY(_ y: CGFloat) -> CGFloat {
        min(max(y, startY), endY)
    }

    func x(atY y: CGFloat) -> CGFloat {
        xOffset(atY: y) + baseX
    }

    func xOffset(atY y: CGFloat) -> CGFloat {
        guard let sample = interpolatedSample(atY: y) else { return 0 }
        return sample.x - baseX
    }

    func effectiveLaneHalfWidth(atY y: CGFloat) -> CGFloat {
        let clusterBreath = min(nearestAnchorWeight(atY: y, kind: .flock) * 3, 3)
        return min(laneHalfWidth + clusterBreath, laneHalfWidth + 3)
    }

    func lineWidth(atY y: CGFloat) -> CGFloat {
        interpolatedSample(atY: y)?.lineWidth ?? Self.baseLineWidth
    }

    func tintHex(atY y: CGFloat) -> String? {
        interpolatedSample(atY: y)?.tintHex
    }

    func path() -> Path {
        var path = Path()
        let points = samplePoints
        guard points.count > 1, let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x, y: first.y))

        for (previous, current) in zip(points, points.dropFirst()) {
            let midY = (previous.y + current.y) / 2
            path.addCurve(
                to: CGPoint(x: current.x, y: current.y),
                control1: CGPoint(x: previous.x, y: midY),
                control2: CGPoint(x: current.x, y: midY)
            )
        }
        return path
    }

    func samples(stride: CGFloat = Self.sampleStride) -> [TimelineStreamSample] {
        guard abs(stride - Self.sampleStride) > 0.001 else { return samplePoints }
        return Self.buildSamples(
            bodies: curvatureBodies,
            baseX: baseX,
            laneHalfWidth: laneHalfWidth,
            startY: startY,
            endY: endY,
            stride: stride
        )
    }

    static func rawAnchors(
        influences: [TimelineStreamInfluence],
        startY: CGFloat,
        endY: CGFloat,
        laneHalfWidth: CGFloat
    ) -> [TimelineStreamAnchor] {
        let maximumStrength = max(laneHalfWidth, 0)
        let startAnchor = TimelineStreamAnchor(
            id: "range:start",
            kind: .range,
            y: startY,
            strength: 0,
            thickness: baseLineWidth,
            tintHex: nil,
            direction: .center
        )
        let endAnchor = TimelineStreamAnchor(
            id: "range:end",
            kind: .range,
            y: endY,
            strength: 0,
            thickness: baseLineWidth,
            tintHex: nil,
            direction: .center
        )

        let densityPreset = densityPreset(itemCount: influences.filter(\.kind.contributesCurvatureMass).count, clusterCount: influences.filter { $0.kind == .flock }.count)
        let semanticAnchors = curvatureBodies(from: influences).map { body in
            return TimelineStreamAnchor(
                id: body.id,
                kind: body.kind,
                y: body.centerY,
                strength: min(curvatureAmplitude(for: body) * densityPreset.multiplier, maximumStrength),
                thickness: baseLineWidth + body.kind.thicknessBonus,
                tintHex: body.tintHex,
                direction: .center
            )
        }
        return ([startAnchor] + semanticAnchors + [endAnchor]).sorted { $0.y < $1.y }
    }

    static func compositeAnchors(
        from anchors: [TimelineStreamAnchor],
        minimumDistance: CGFloat
    ) -> [TimelineStreamAnchor] {
        var composites: [TimelineStreamAnchor] = []
        var currentGroup: [TimelineStreamAnchor] = []

        func flushGroup() {
            guard currentGroup.isEmpty == false else { return }
            if currentGroup.count == 1, let only = currentGroup.first {
                composites.append(only)
            } else {
                composites.append(compositeAnchor(from: currentGroup))
            }
            currentGroup.removeAll()
        }

        for anchor in anchors.sorted(by: { $0.y < $1.y }) {
            guard anchor.kind != .range else {
                flushGroup()
                composites.append(anchor)
                continue
            }

            if let last = currentGroup.last, anchor.y - last.y < minimumDistance {
                currentGroup.append(anchor)
            } else {
                flushGroup()
                currentGroup = [anchor]
            }
        }
        flushGroup()

        return composites.sorted { lhs, rhs in
            if lhs.y != rhs.y { return lhs.y < rhs.y }
            return lhs.kind.priority < rhs.kind.priority
        }
    }

    static func directedAnchors(
        from anchors: [TimelineStreamAnchor],
        laneHalfWidth: CGFloat
    ) -> [TimelineStreamAnchor] {
        let sorted = anchors.sorted { $0.y < $1.y }

        return sorted.map { anchor in
            let direction: TimelineStreamDirection
            switch anchor.kind {
            case .task, .meeting, .flock, .routine:
                direction = .trailing
            case .range, .sweep, .gap:
                direction = .center
            }

            let clampedStrength = min(anchor.strength, max(laneHalfWidth, 0))
            return TimelineStreamAnchor(
                id: anchor.id,
                kind: anchor.kind,
                y: anchor.y,
                strength: clampedStrength,
                thickness: anchor.thickness,
                tintHex: anchor.tintHex,
                direction: direction
            )
        }
    }

    static func segments(
        from anchors: [TimelineStreamAnchor],
        baseX: CGFloat,
        laneHalfWidth: CGFloat
    ) -> [TimelineStreamSegment] {
        guard anchors.count > 1 else { return [] }
        return zip(anchors, anchors.dropFirst()).enumerated().map { index, pair in
            let start = pair.0
            let end = pair.1
            let startPoint = point(for: start, baseX: baseX)
            let endPoint = point(for: end, baseX: baseX)
            let height = max(end.y - start.y, 1)
            let control1 = CGPoint(
                x: startPoint.x,
                y: start.y + (height * 0.5)
            )
            let control2 = CGPoint(
                x: endPoint.x,
                y: end.y - (height * 0.5)
            )
            return TimelineStreamSegment(
                index: index,
                start: start,
                end: end,
                control1: control1,
                control2: control2
            )
        }
    }

    static func point(for anchor: TimelineStreamAnchor, baseX: CGFloat) -> CGPoint {
        CGPoint(x: baseX + (anchor.xDirection * anchor.strength), y: anchor.y)
    }

    func point(for anchor: TimelineStreamAnchor) -> CGPoint {
        Self.point(for: anchor, baseX: baseX)
    }

    static func buildSamples(
        bodies: [CurvatureBody],
        baseX: CGFloat,
        laneHalfWidth: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        stride: CGFloat
    ) -> [TimelineStreamSample] {
        let clampedStartY = min(startY, endY)
        let clampedEndY = max(startY, endY)
        let span = max(clampedEndY - clampedStartY, 1)
        let step = max(stride, 4)
        let preset = densityPreset(
            itemCount: bodies.reduce(0) { $0 + max($1.stackCount, 1) },
            clusterCount: bodies.filter { $0.kind == .flock }.count
        )
        let maxOffset = min(preset.maxOffset, laneHalfWidth)
        var raw: [TimelineStreamSample] = []
        var index = 0
        var y = clampedStartY

        while y <= clampedEndY + 0.001 {
            let offset = min(curvatureOffset(at: y, bodies: bodies) * preset.multiplier, maxOffset)
            raw.append(TimelineStreamSample(
                index: index,
                y: min(y, clampedEndY),
                x: baseX + offset,
                lineWidth: lineWidth(at: y, bodies: bodies),
                tintHex: tintHex(at: y, bodies: bodies),
                progress: min(max((y - clampedStartY) / span, 0), 1)
            ))
            index += 1
            y += step
        }

        if raw.last?.y != clampedEndY {
            let offset = min(curvatureOffset(at: clampedEndY, bodies: bodies) * preset.multiplier, maxOffset)
            raw.append(TimelineStreamSample(
                index: index,
                y: clampedEndY,
                x: baseX + offset,
                lineWidth: lineWidth(at: clampedEndY, bodies: bodies),
                tintHex: tintHex(at: clampedEndY, bodies: bodies),
                progress: 1
            ))
        }

        return limitSlope(smoothOffsets(raw), baseX: baseX, maxOffset: maxOffset)
    }
}
