import SwiftUI

// MARK: - Metric ring

/// The shared circular signal used by Home, Track, and Insights. Values
/// animate only when they change; empty and setup states stay visually and
/// semantically distinct from an honest zero.
public struct MetricRing: View {
    public enum RingState: Equatable, Sendable {
        case loading
        /// Authorized, but nothing recorded yet. Tapping can add a value.
        case setupRequired
        /// Never authorized, so there is nothing to show and nothing to add.
        /// Distinct from `setupRequired`: the way forward is a permission, not
        /// an entry.
        case permissionRequired
        case unavailable
        case stale(progress: Double, centerText: String)
        case zero(centerText: String)
        case value(progress: Double, centerText: String)
        case complete(centerText: String)
    }

    private let label: String
    private let state: RingState
    private let diameter: CGFloat
    private let palette: DaypartPalette
    /// When set, the interior renders a rising liquid surface (hydration,
    /// fasting) instead of staying empty — the ported wave fill.
    private let liquidTint: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        label: String,
        state: RingState,
        diameter: CGFloat = 60,
        palette: DaypartPalette,
        liquidTint: Color? = nil
    ) {
        self.label = label
        self.state = state
        self.diameter = diameter
        self.palette = palette
        self.liquidTint = liquidTint
    }

    private var progress: Double {
        switch state {
        case .loading, .setupRequired, .permissionRequired, .unavailable, .zero: 0
        case .stale(let progress, _), .value(let progress, _): min(1, max(0, progress))
        case .complete: 1
        }
    }

    private var centerText: String? {
        switch state {
        case .loading, .setupRequired, .permissionRequired, .unavailable: nil
        case .stale(_, let text), .zero(let text), .value(_, let text), .complete(let text): text
        }
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(
                        Color(trackIsTheSignal
                            ? SemanticColorTokens.metricRingTrackProminent
                            : SemanticColorTokens.metricRingTrack),
                        style: StrokeStyle(
                            lineWidth: trackIsTheSignal ? 3 : 5,
                            dash: usesDashedTrack ? [3, 5] : []
                        )
                    )
                if let liquidTint, permitsProgressLayer {
                    LiquidFill(level: progress, tint: liquidTint)
                        .clipShape(Circle().inset(by: 4))
                        .allowsHitTesting(false)
                }
                if case .loading = state {
                    ProgressView().controlSize(.small)
                } else if permitsProgressLayer {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(
                            MotionProfile.localState.animation(reduceMotion: reduceMotion),
                            value: progress
                        )
                }
                if let centerText {
                    Text(centerText)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                } else if let statusSymbol {
                    Image(systemName: statusSymbol)
                        .lifeboardFont(.meta)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
            }
            .frame(width: diameter, height: diameter)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValueText)
    }

    private var ringColor: Color {
        if case .complete = state {
            return Color(SemanticColorTokens.foundationSageAccent)
        }
        if case .stale = state {
            return Color(SemanticColorTokens.foundationApricotAccent)
        }
        return Color(SemanticColorTokens.metricRingFill)
    }

    private var usesDashedTrack: Bool {
        switch state {
        case .setupRequired, .permissionRequired, .unavailable, .stale: true
        default: false
        }
    }

    /// True when there is no progress arc, so the track is the only thing
    /// communicating state and has to carry full non-text contrast.
    private var trackIsTheSignal: Bool {
        switch state {
        case .setupRequired, .permissionRequired, .unavailable: true
        default: false
        }
    }

    private var permitsProgressLayer: Bool {
        switch state {
        case .stale, .value, .complete: true
        case .loading, .setupRequired, .permissionRequired, .unavailable, .zero: false
        }
    }

    private var statusSymbol: String? {
        switch state {
        case .setupRequired: "plus"
        // Not "plus": a "+" promises that tapping adds a value, which is
        // exactly what a declined permission cannot do.
        case .permissionRequired: "hand.raised"
        case .unavailable: "slash"
        default: nil
        }
    }

    private var accessibilityValueText: String {
        switch state {
        case .loading: "Loading"
        case .setupRequired: "Set up"
        case .permissionRequired: "Not shared"
        case .unavailable: "Unavailable"
        case .stale(let progress, let text): "\(text), out of date, \(Int((min(1, max(0, progress)) * 100).rounded())) percent"
        case .zero(let text): "\(text), no progress recorded"
        case .value(let progress, let text): "\(text), \(Int((min(1, max(0, progress)) * 100).rounded())) percent"
        case .complete(let text): "\(text), complete"
        }
    }
}
