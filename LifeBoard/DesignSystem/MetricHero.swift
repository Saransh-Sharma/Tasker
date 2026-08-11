import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// What is actually known about a recorded value.
///
/// `DESIGN.md`: "Unknown data is not zero." Six states, six presentations —
/// collapsing any pair of them tells the person something untrue about their own
/// record. The distinction that matters most is `explicitZero` against
/// `noRecord`: "you drank no water today" and "we have no idea whether you drank
/// water today" render identically the moment someone reaches for `?? 0`.
public enum MetricReading: Equatable, Sendable {
    /// A real measurement.
    case recorded(value: String, unit: String?)
    /// Genuinely zero, and known to be.
    case explicitZero(unit: String?)
    /// Nothing recorded for this timeframe.
    case noRecord
    /// Last known value, but older than the timeframe claims.
    case stale(value: String, unit: String?, age: String)
    /// Permission exists but was refused.
    case denied
    /// The source cannot answer right now — offline, unsupported, failed.
    case unavailable
}

/// One recorded value at reading scale: label, value, unit, provenance.
///
/// The single component for every "what is this number right now" moment. It
/// replaced six hand-rolled variants that had drifted apart — two of which
/// rendered the screen's most important number in a *recessed* well, and three
/// of which used a fixed point size that could not answer Dynamic Type.
public struct MetricHero: View {
    private let label: String
    private let reading: MetricReading
    private let provenance: String?
    private let timeframe: String?
    private let trend: String?
    private let accessibilityID: String?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        label: String,
        reading: MetricReading,
        provenance: String? = nil,
        timeframe: String? = nil,
        trend: String? = nil,
        accessibilityID: String? = nil
    ) {
        self.label = label
        self.reading = reading
        self.provenance = provenance
        self.timeframe = timeframe
        self.trend = trend
        self.accessibilityID = accessibilityID
        }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .lifeboardFont(.eyebrow)
                .foregroundStyle(Color.lifeboard(.textSecondary))

            valueLine

            if let footnote {
                Text(footnote)
                    .lifeboardFont(.caption2)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityID ?? "lifeboard.metric")
    }

    @ViewBuilder
    private var valueLine: some View {
        switch reading {
        case let .recorded(value, unit):
            numeral(value, unit: unit, tint: Color.lifeboard(.textPrimary))
        case let .explicitZero(unit):
            numeral("0", unit: unit, tint: Color.lifeboard(.textPrimary))
        case let .stale(value, unit, _):
            numeral(value, unit: unit, tint: Color.lifeboard(.textSecondary))
        case .noRecord:
            absence("Not recorded")
        case .denied:
            absence("Not shared")
        case .unavailable:
            absence("Unavailable")
        }
    }

    /// The numeral and its unit, on one baseline.
    ///
    /// `monospacedDigit` matters more than it looks: without it a value ticking
    /// from 9 to 10, or a column of times, reflows on every change.
    private func numeral(_ value: String, unit: String?, tint: Color) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 4))

        return layout {
            Text(value)
                .lifeboardFont(.metric)
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            if let unit {
                Text(unit)
                    .lifeboardFont(.meta)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            if let trend, dynamicTypeSize.isAccessibilitySize == false {
                Text(trend)
                    .lifeboardFont(.caption2)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
        }
    }

    /// Absence is set in text, never as a zero and never as a dash. A dash reads
    /// as a value the same way `0` does.
    private func absence(_ text: String) -> some View {
        Text(text)
            .lifeboardFont(.bodyEmphasis)
            .foregroundStyle(Color.lifeboard(.textTertiary))
    }

    private var footnote: String? {
        var parts: [String] = []
        if case let .stale(_, _, age) = reading { parts.append(age) }
        if let timeframe { parts.append(timeframe) }
        if let provenance { parts.append(provenance) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var accessibilityValue: String {
        var spoken: String
        switch reading {
        case let .recorded(value, unit):
            spoken = [value, unit].compactMap { $0 }.joined(separator: " ")
        case let .explicitZero(unit):
            spoken = ["0", unit].compactMap { $0 }.joined(separator: " ")
        case let .stale(value, unit, age):
            spoken = [value, unit].compactMap { $0 }.joined(separator: " ") + ", recorded \(age)"
        case .noRecord:
            spoken = "Not recorded"
        case .denied:
            spoken = "Not shared"
        case .unavailable:
            spoken = "Unavailable"
        }
        if let timeframe { spoken += ", \(timeframe)" }
        if let provenance { spoken += ", from \(provenance)" }
        if let trend { spoken += ", \(trend)" }
        return spoken
    }
}

/// A metric in its own clay well — the supporting presentation, for grids and
/// rows of facts beneath a hero.
public struct MetricHeroWell: View {
    private let metric: MetricHero

    public init(_ metric: MetricHero) {
        self.metric = metric
    }

    public var body: some View {
        metric
            .padding(12)
            .lifeBoardClaySurface(.well)
    }
}
