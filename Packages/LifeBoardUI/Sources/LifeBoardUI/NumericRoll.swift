import SwiftUI
import LifeBoardTokens
// A rolling numeric readout. Accepts a `Double` and a unit string, so it is
// admissible even though the rest of `LifeBoardCardPrimitives` is not.
/// An odometer-style numeral. Rolls only when the *value* changes, never on an
/// incidental redraw, so a scrolling dashboard stays still.
public struct NumericRoll: View {
    private let value: Double
    private let fractionDigits: Int
    private let unit: String?
    private let emphasis: Emphasis

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    /// Resolved through `MotionOverride` so the in-app "Full motion" setting can
    /// reach this component. Reading `accessibilityReduceMotion` directly is what
    /// made a whole cluster of `LifeBoardUI` components ignore that setting.
    /// `MotionOverride.resolve` is idempotent, so uses that already forward this
    /// into `MotionProfile`/`MotionPolicy` are unaffected.
    private var reduceMotion: Bool {
        MotionOverride.resolve(systemReduceMotion)
    }

    public enum Emphasis {
        /// Inline with supporting copy.
        case standard
        /// The card's single largest element.
        case hero

        var textStyle: TypographyStyle {
            switch self {
            case .standard: .metric
            case .hero: .heroDisplay
            }
        }
    }

    public init(
        value: Double,
        fractionDigits: Int = 0,
        unit: String? = nil,
        emphasis: Emphasis = .standard
    ) {
        self.value = value
        self.fractionDigits = fractionDigits
        self.unit = unit
        self.emphasis = emphasis
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(formatted)
                .lifeboardFont(emphasis.textStyle)
                .modifier(NumericRollEvidenceModifier(id: "value", copy: formatted, style: emphasis.textStyle))
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82),
                    value: value
                )
            if let unit, unit.isEmpty == false {
                Text(unit)
                    .lifeboardFont(.caption1)
                    .modifier(NumericRollEvidenceModifier(id: "unit", copy: unit, style: .caption1))
                    .foregroundStyle(.secondary)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibleValue)
    }

    private var formatted: String {
        value.formatted(
            .number
                .precision(.fractionLength(fractionDigits))
                .grouping(.automatic)
        )
    }

    private var accessibleValue: String {
        guard let unit, unit.isEmpty == false else { return formatted }
        return "\(formatted) \(unit)"
    }
}

// Debug-only SPI keeps capture plumbing out of the released component API.
#if DEBUG
@_spi(DesignEvidence) public struct NumericRollEvidenceSink: Sendable {
    public let record: @MainActor @Sendable (String, String, CGRect, TypographyStyle) -> Void
    public init(record: @escaping @MainActor @Sendable (String, String, CGRect, TypographyStyle) -> Void) {
        self.record = record
    }
}
private struct NumericRollEvidenceKey: EnvironmentKey {
    static let defaultValue: NumericRollEvidenceSink? = nil
}
extension EnvironmentValues {
    @_spi(DesignEvidence) public var numericRollEvidenceSink: NumericRollEvidenceSink? {
        get { self[NumericRollEvidenceKey.self] }
        set { self[NumericRollEvidenceKey.self] = newValue }
    }
}
#endif

private struct NumericRollEvidenceModifier: ViewModifier {
    let id: String
    let copy: String
    let style: TypographyStyle
    #if DEBUG
    @Environment(\.numericRollEvidenceSink) private var sink
    #endif

    func body(content: Content) -> some View {
        #if DEBUG
        if let sink {
            content.background {
                GeometryReader { geometry in
                    let _ = sink.record(id, copy, geometry.frame(in: .named("home.card.evidence")), style)
                    Color.clear
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        } else { content }
        #else
        content
        #endif
    }
}
