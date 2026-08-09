import SwiftUI

// The values the stream is built from: anchors, direction, influence,
// samples, segments, and the palette and layer specs it draws with.

// MARK: - TimelineStreamAnchor

struct TimelineStreamAnchor: Equatable, Identifiable {
    let id: String
    let kind: TimelineStreamInfluenceKind
    let y: CGFloat
    let strength: CGFloat
    let thickness: CGFloat
    let tintHex: String?
    let direction: TimelineStreamDirection

    var xDirection: CGFloat { direction.rawValue }
}

// MARK: - TimelineStreamDirection

enum TimelineStreamDirection: CGFloat, Equatable {
    case leading = -1
    case center = 0
    case trailing = 1

    var inverted: TimelineStreamDirection {
        switch self {
        case .leading:
            return .trailing
        case .trailing:
            return .leading
        case .center:
            return .trailing
        }
    }
}

// MARK: - TimelineStreamGlintPresentation

struct TimelineStreamGlintPresentation: Equatable {
    static let halfLength: CGFloat = 16
    static let blurRadius: CGFloat = 3
    static let opacity: Double = 0.36
    static let extraLineWidth: CGFloat = 0.75

    static func visibleAnchorIDs(
        anchors: [TimelineStreamAnchor],
        currentY: CGFloat?,
        currentDistanceThreshold: CGFloat = 64
    ) -> Set<String> {
        let candidates = anchors
            .filter { $0.kind == .task || $0.kind == .meeting || $0.kind == .flock }
            .sorted { lhs, rhs in
                if lhs.y != rhs.y { return lhs.y < rhs.y }
                return lhs.id < rhs.id
            }
        var visible = Set(candidates.filter { $0.kind == .flock }.map(\.id))

        guard let currentY else {
            return visible
        }

        if let current = candidates.min(by: { abs($0.y - currentY) < abs($1.y - currentY) }),
           abs(current.y - currentY) <= currentDistanceThreshold {
            visible.insert(current.id)
        }

        if let next = candidates.first(where: { $0.y > currentY + 8 }) {
            visible.insert(next.id)
        }

        return visible
    }
}

// MARK: - TimelineStreamInfluence

struct TimelineStreamInfluence: Equatable, Identifiable {
    let id: String
    let kind: TimelineStreamInfluenceKind
    let centerY: CGFloat
    let height: CGFloat
    let tintHex: String?
    let stackCount: Int

    init(
        id: String,
        kind: TimelineStreamInfluenceKind,
        centerY: CGFloat,
        height: CGFloat,
        tintHex: String? = nil,
        stackCount: Int = 1
    ) {
        self.id = id
        self.kind = kind
        self.centerY = centerY
        self.height = height
        self.tintHex = tintHex
        self.stackCount = stackCount
    }
}

// MARK: - TimelineStreamInfluenceExtension

extension TimelineStreamInfluence {
    var startY: CGFloat { centerY - (max(height, 40) / 2) }
    var endY: CGFloat { centerY + (max(height, 40) / 2) }
}

// MARK: - TimelineStreamInfluenceKind

enum TimelineStreamInfluenceKind: Equatable {
    case range
    case sweep
    case routine
    case meeting
    case task
    case gap
    case flock

    var priority: Int {
        switch self {
        case .flock:
            return 6
        case .meeting:
            return 5
        case .task:
            return 4
        case .routine:
            return 3
        case .gap:
            return 2
        case .range:
            return 0
        case .sweep:
            return 1
        }
    }

    var baseStrength: CGFloat {
        switch self {
        case .range:
            return 0
        case .sweep:
            return 0
        case .routine:
            return 8
        case .task:
            return 5
        case .gap:
            return 0
        case .meeting:
            return 9
        case .flock:
            return 18
        }
    }

    var baseMass: CGFloat {
        switch self {
        case .routine:
            return 0.65
        case .meeting:
            return 0.75
        case .task:
            return 0.45
        case .flock:
            return 1.40
        case .range, .sweep, .gap:
            return 0
        }
    }

    var contributesCurvatureMass: Bool {
        switch self {
        case .routine, .meeting, .task, .flock:
            return true
        case .range, .sweep, .gap:
            return false
        }
    }

    var thicknessBonus: CGFloat {
        switch self {
        case .flock:
            return 1
        case .meeting:
            return 0.5
        case .gap:
            return 0.35
        case .task:
            return 0.25
        case .range, .sweep, .routine:
            return 0
        }
    }

    var overshoot: CGFloat {
        switch self {
        case .flock:
            return 0
        case .meeting:
            return 0
        case .sweep:
            return 0
        case .task:
            return 0
        case .range, .routine, .gap:
            return 0
        }
    }
}

// MARK: - TimelineStreamLayerSpec

struct TimelineStreamLayerSpec: Equatable {
    let glowLineWidth: CGFloat
    let bodyLineWidth: CGFloat
    let coreLineWidth: CGFloat
    let usesRoundedCapsAndJoins: Bool

    static let expressive = TimelineStreamLayerSpec(
        glowLineWidth: TimelineStreamGeometry.glowLineWidth,
        bodyLineWidth: TimelineStreamGeometry.baseLineWidth,
        coreLineWidth: TimelineStreamGeometry.coreLineWidth,
        usesRoundedCapsAndJoins: true
    )
}

// MARK: - TimelineStreamPalette

enum TimelineStreamPalette {
    struct Stop {
        let progress: CGFloat
        let red: Double
        let green: Double
        let blue: Double
    }

    static let stops: [Stop] = [
        Stop(progress: 0.0, red: 0.22, green: 0.56, blue: 0.55),
        Stop(progress: 0.38, red: 0.45, green: 0.57, blue: 0.36),
        Stop(progress: 0.72, red: 0.48, green: 0.45, blue: 0.58),
        Stop(progress: 1.0, red: 0.38, green: 0.39, blue: 0.50)
    ]

    static func color(progress: CGFloat) -> Color {
        let clampedProgress = min(max(progress, 0), 1)
        guard let first = stops.first else { return Color(red: 0.22, green: 0.56, blue: 0.55) }
        guard let last = stops.last else { return Color(red: 0.22, green: 0.56, blue: 0.55) }
        guard clampedProgress > first.progress else {
            return Color(red: first.red, green: first.green, blue: first.blue)
        }
        guard clampedProgress < last.progress else {
            return Color(red: last.red, green: last.green, blue: last.blue)
        }

        let upperIndex = stops.firstIndex { $0.progress >= clampedProgress } ?? (stops.count - 1)
        let lower = stops[max(upperIndex - 1, 0)]
        let upper = stops[upperIndex]
        let span = max(upper.progress - lower.progress, 0.001)
        let ratio = (clampedProgress - lower.progress) / span
        return Color(
            red: lower.red + ((upper.red - lower.red) * Double(ratio)),
            green: lower.green + ((upper.green - lower.green) * Double(ratio)),
            blue: lower.blue + ((upper.blue - lower.blue) * Double(ratio))
        )
    }
}

// MARK: - TimelineStreamSample

struct TimelineStreamSample: Equatable, Identifiable {
    let index: Int
    let y: CGFloat
    let x: CGFloat
    let lineWidth: CGFloat
    let tintHex: String?
    let progress: CGFloat

    var id: Int { index }
}

// MARK: - TimelineStreamSegment

struct TimelineStreamSegment: Equatable, Identifiable {
    let index: Int
    let start: TimelineStreamAnchor
    let end: TimelineStreamAnchor
    let control1: CGPoint
    let control2: CGPoint

    var id: Int { index }
}
