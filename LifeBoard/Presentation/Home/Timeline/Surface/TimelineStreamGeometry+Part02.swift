import SwiftUI

extension TimelineStreamGeometry {
    static func curvatureBodies(from influences: [TimelineStreamInfluence]) -> [CurvatureBody] {
        let massInfluences = influences.filter(\.kind.contributesCurvatureMass)
        let clusterCandidates = massInfluences.filter { $0.kind == .task || $0.kind == .meeting }
            .sorted { lhs, rhs in
                if lhs.startY != rhs.startY { return lhs.startY < rhs.startY }
                return lhs.id < rhs.id
            }
        let standaloneBodies = massInfluences
            .filter { $0.kind == .routine || $0.kind == .flock }
            .map { body(from: $0, stackCount: max($0.stackCount, $0.kind == .flock ? 2 : 1)) }

        var groupedIDs = Set<String>()
        var clusterBodies: [CurvatureBody] = []
        var current: [TimelineStreamInfluence] = []

        func flushCurrent() {
            guard current.isEmpty == false else { return }
            if shouldCluster(current) {
                current.forEach { groupedIDs.insert($0.id) }
                clusterBodies.append(clusterBody(from: current))
            }
            current.removeAll()
        }

        for influence in clusterCandidates {
            guard let last = current.last else {
                current = [influence]
                continue
            }

            let gap = influence.startY - last.endY
            let overlaps = influence.startY < last.endY
            let closeEnough = gap <= clusterGapThreshold
            let denseWindow = current.count >= 2 && (influence.centerY - current[0].centerY) <= densityWindow

            if overlaps || closeEnough || denseWindow {
                current.append(influence)
            } else {
                flushCurrent()
                current = [influence]
            }
        }
        flushCurrent()

        let isolatedBodies = clusterCandidates
            .filter { groupedIDs.contains($0.id) == false }
            .map { body(from: $0, stackCount: 1) }

        return (standaloneBodies + clusterBodies + isolatedBodies).sorted { lhs, rhs in
            if lhs.centerY != rhs.centerY { return lhs.centerY < rhs.centerY }
            return lhs.id < rhs.id
        }
    }

    static func shouldCluster(_ group: [TimelineStreamInfluence]) -> Bool {
        guard group.count > 1 else { return false }
        if group.count >= 3 { return true }
        for (previous, current) in zip(group, group.dropFirst()) {
            if current.startY < previous.endY || current.startY - previous.endY <= clusterGapThreshold {
                return true
            }
        }
        return false
    }

    static func body(from influence: TimelineStreamInfluence, stackCount: Int) -> CurvatureBody {
        CurvatureBody(
            id: influence.id,
            kind: influence.kind,
            centerY: influence.centerY,
            height: max(40, influence.height),
            tintHex: influence.tintHex,
            stackCount: stackCount,
            isOverlapping: false
        )
    }

    static func clusterBody(from group: [TimelineStreamInfluence]) -> CurvatureBody {
        let startY = group.map(\.startY).min() ?? 0
        let endY = group.map(\.endY).max() ?? startY + 40
        let overlaps = zip(group, group.dropFirst()).contains { previous, current in
            current.startY < previous.endY
        }
        let tintHex = group.first(where: { $0.kind == .meeting && $0.tintHex != nil })?.tintHex
            ?? group.first(where: { $0.tintHex != nil })?.tintHex

        return CurvatureBody(
            id: "cluster:\(group.map(\.id).joined(separator: "|"))",
            kind: .flock,
            centerY: (startY + endY) / 2,
            height: max(40, endY - startY),
            tintHex: tintHex,
            stackCount: group.count,
            isOverlapping: overlaps
        )
    }

    static func itemMass(_ body: CurvatureBody) -> CGFloat {
        let durationFactor = min(1.35, 0.85 + max(40, body.height) / 180)
        let stackFactor: CGFloat = body.kind == .flock
            ? 1.0 + min(1.2, CGFloat(max(body.stackCount - 1, 0)) * 0.22)
            : 1.0
        let overlapFactor: CGFloat = body.isOverlapping ? 1.25 : 1.0
        return body.kind.baseMass * durationFactor * stackFactor * overlapFactor
    }

    static func curvatureAmplitude(for body: CurvatureBody) -> CGFloat {
        let raw = itemMass(body) * 10
        switch body.kind {
        case .flock:
            return min(34, max(14, raw))
        case .routine:
            return 8
        case .meeting, .task:
            return min(16, max(4, raw))
        case .range, .sweep, .gap:
            return 0
        }
    }

    static func influenceRadius(for body: CurvatureBody) -> CGFloat {
        let mass = itemMass(body)
        switch body.kind {
        case .flock:
            return max(120, body.height * 0.85 + mass * 28)
        case .routine:
            return 80
        case .meeting, .task:
            return max(55, body.height * 0.55 + mass * 16)
        case .range, .sweep, .gap:
            return 0
        }
    }

    static func curvatureOffset(at y: CGFloat, bodies: [CurvatureBody]) -> CGFloat {
        bodies.reduce(CGFloat.zero) { total, body in
            let influence = gaussianInfluence(distance: abs(y - body.centerY), radius: influenceRadius(for: body))
            guard influence >= 0.04 else { return total }
            return total + curvatureAmplitude(for: body) * influence
        }
    }

    static func lineWidth(at y: CGFloat, bodies: [CurvatureBody]) -> CGFloat {
        let clusterInfluence = bodies
            .filter { $0.kind == .flock }
            .map { gaussianInfluence(distance: abs(y - $0.centerY), radius: influenceRadius(for: $0)) }
            .max() ?? 0
        return baseLineWidth + min(clusterInfluence * 1.2, 1.2)
    }

    static func tintHex(at y: CGFloat, bodies: [CurvatureBody]) -> String? {
        bodies
            .compactMap { body -> (body: CurvatureBody, influence: CGFloat)? in
                let influence = gaussianInfluence(distance: abs(y - body.centerY), radius: influenceRadius(for: body))
                guard influence >= 0.18 else { return nil }
                return (body, influence)
            }
            .max { lhs, rhs in lhs.influence < rhs.influence }?
            .body
            .tintHex
    }

    static func gaussianInfluence(distance: CGFloat, radius: CGFloat) -> CGFloat {
        guard radius > 0 else { return 0 }
        let normalized = distance / radius
        return exp(-normalized * normalized)
    }

    static func densityPreset(itemCount: Int, clusterCount: Int) -> DensityPreset {
        if itemCount >= 18 {
            return DensityPreset(multiplier: 1.10, maxOffset: 38)
        }
        if clusterCount >= 2 || itemCount >= 12 {
            return DensityPreset(multiplier: 1.0, maxOffset: 34)
        }
        if itemCount <= 7 && clusterCount == 0 {
            return DensityPreset(multiplier: 0.65, maxOffset: 18)
        }
        return DensityPreset(multiplier: 0.85, maxOffset: 28)
    }

    static func smoothOffsets(_ points: [TimelineStreamSample]) -> [TimelineStreamSample] {
        guard points.count > 4 else { return points }
        var result = points

        for index in 2..<(points.count - 2) {
            let smoothedX =
                points[index - 2].x * 0.08 +
                points[index - 1].x * 0.18 +
                points[index].x * 0.48 +
                points[index + 1].x * 0.18 +
                points[index + 2].x * 0.08
            result[index] = TimelineStreamSample(
                index: points[index].index,
                y: points[index].y,
                x: smoothedX,
                lineWidth: points[index].lineWidth,
                tintHex: points[index].tintHex,
                progress: points[index].progress
            )
        }

        return result
    }

    static func limitSlope(
        _ points: [TimelineStreamSample],
        baseX: CGFloat,
        maxOffset: CGFloat,
        maxDeltaX: CGFloat = maxSlopeDelta
    ) -> [TimelineStreamSample] {
        guard points.count > 1 else { return points }
        var result = points

        for index in 1..<result.count {
            let dx = result[index].x - result[index - 1].x
            let clampedDx = min(max(dx, -maxDeltaX), maxDeltaX)
            let x = min(max(result[index - 1].x + clampedDx, baseX), baseX + maxOffset)
            result[index] = TimelineStreamSample(
                index: result[index].index,
                y: result[index].y,
                x: x,
                lineWidth: result[index].lineWidth,
                tintHex: result[index].tintHex,
                progress: result[index].progress
            )
        }

        return result
    }

    static func compositeAnchor(from anchors: [TimelineStreamAnchor]) -> TimelineStreamAnchor {
        let dominant = anchors.max { lhs, rhs in
            if lhs.kind.priority != rhs.kind.priority {
                return lhs.kind.priority < rhs.kind.priority
            }
            return lhs.strength < rhs.strength
        } ?? anchors[0]
        let totalWeight = anchors.reduce(CGFloat.zero) { partial, anchor in
            partial + max(CGFloat(anchor.kind.priority), 1)
        }
        let weightedY = anchors.reduce(CGFloat.zero) { partial, anchor in
            partial + (anchor.y * max(CGFloat(anchor.kind.priority), 1))
        } / max(totalWeight, 1)
        let maxStrength = anchors.map(\.strength).max() ?? dominant.strength
        let maxThickness = anchors.map(\.thickness).max() ?? dominant.thickness
        let tintHex = anchors.first(where: { $0.kind == dominant.kind && $0.tintHex != nil })?.tintHex
            ?? anchors.first(where: { $0.tintHex != nil })?.tintHex

        return TimelineStreamAnchor(
            id: "composite:\(anchors.map(\.id).joined(separator: "|"))",
            kind: dominant.kind,
            y: weightedY,
            strength: maxStrength,
            thickness: maxThickness,
            tintHex: tintHex,
            direction: .center
        )
    }

    func interpolatedSample(atY y: CGFloat) -> TimelineStreamSample? {
        let clamped = clampedY(y)
        let allSamples = samplePoints
        guard allSamples.isEmpty == false else { return nil }
        guard let first = allSamples.first else { return nil }
        guard let last = allSamples.last else { return nil }
        if clamped <= first.y { return first }
        if clamped >= last.y { return last }

        guard let upperIndex = allSamples.firstIndex(where: { $0.y >= clamped }), upperIndex > 0 else {
            return first
        }
        let lower = allSamples[upperIndex - 1]
        let upper = allSamples[upperIndex]
        let span = max(upper.y - lower.y, 0.001)
        let ratio = (clamped - lower.y) / span
        return TimelineStreamSample(
            index: lower.index,
            y: clamped,
            x: interpolate(lower.x, upper.x, t: ratio),
            lineWidth: interpolate(lower.lineWidth, upper.lineWidth, t: ratio),
            tintHex: ratio < 0.5 ? lower.tintHex : upper.tintHex,
            progress: interpolate(lower.progress, upper.progress, t: ratio)
        )
    }

    func nearestAnchorWeight(atY y: CGFloat, kind: TimelineStreamInfluenceKind) -> CGFloat {
        anchors
            .filter { $0.kind == kind }
            .map { max(0, 1 - (abs($0.y - y) / Self.minimumClusterDistance)) }
            .max() ?? 0
    }

    static func cubicPoint(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        let x = (uuu * start.x)
            + (3 * uu * t * control1.x)
            + (3 * u * tt * control2.x)
            + (ttt * end.x)
        let y = (uuu * start.y)
            + (3 * uu * t * control1.y)
            + (3 * u * tt * control2.y)
            + (ttt * end.y)
        return CGPoint(x: x, y: y)
    }

    static func interpolate(_ start: CGFloat, _ end: CGFloat, t: CGFloat) -> CGFloat {
        start + ((end - start) * min(max(t, 0), 1))
    }

    func interpolate(_ start: CGFloat, _ end: CGFloat, t: CGFloat) -> CGFloat {
        Self.interpolate(start, end, t: t)
    }
}
