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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
                .animation(
                    reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.82),
                    value: value
                )
            if let unit, unit.isEmpty == false {
                Text(unit)
                    .lifeboardFont(.caption1)
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
