import LifeBoardTokens
import SwiftUI

/// What a signal actually knows right now.
///
/// This enum is the whole point of the type. `DESIGN.md` is emphatic that
/// "unknown data is not zero" and that "loading, no record, explicit zero,
/// stale, denied, unavailable, and error are separate states" — but when every
/// signal is a `Double?`, a screen has one shape for "you walked 0 steps", one
/// for "Health access was denied", and one for "we haven't asked yet", and they
/// all render as an empty ring. Home does exactly that today.
///
/// Making the distinction a type means a call site cannot collapse the states by
/// accident; it has to say which one it means.
public enum SignalReading: Equatable, Sendable {
    /// A recorded value. `unit` is rendered quieter than the number.
    case value(String, unit: String? = nil)
    /// A recorded zero. Genuinely different from `noRecord`: the person did the
    /// thing zero times, and we know that.
    case zero(String)
    /// Nothing has been recorded. Not a failure, and never shown as "0".
    case noRecord
    case loading
    /// Last known value, with how old it is.
    case stale(String, age: String)
    /// Permission refused. Actionable — the row offers the way back.
    case denied
    /// Not supported on this device or in this region.
    case unavailable
    case failed

    /// Whether this reading carries a number the eye should land on.
    var isRecorded: Bool {
        switch self {
        case .value, .zero, .stale: true
        case .noRecord, .loading, .denied, .unavailable, .failed: false
        }
    }
}

public struct SignalStripItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let systemImage: String
    public let reading: SignalReading
    /// The timeframe the reading covers — "today", "this week". Kept beside the
    /// value because `DESIGN.md` requires a metric to carry its timeframe.
    public let timeframe: String?

    public init(
        id: String,
        label: String,
        systemImage: String,
        reading: SignalReading,
        timeframe: String? = nil
    ) {
        self.id = id
        self.label = label
        self.systemImage = systemImage
        self.reading = reading
        self.timeframe = timeframe
    }
}

/// Zero to three signals, chosen by relevance, each with a direct destination.
///
/// Hard-capped at three rather than trusting call sites to pass three: the cap
/// *is* the design contract ("zero to three relevance-ranked supporting
/// signals"), and Home currently shows four. A cap that lives in the type cannot
/// drift the way a code-review convention does.
public struct SignalStrip: View {
    private let items: [SignalStripItem]
    private let identifierPrefix: String
    private let onOpen: (SignalStripItem.ID) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// - Parameter identifierPrefix: Accessibility identifiers are emitted as
    ///   `"\(identifierPrefix).\(item.id)"`. It is a parameter because adopting
    ///   this primitive must not rename a screen's existing identifiers — Home's
    ///   UI tests query `home.signal.hydration` and `home.signal.fasting`
    ///   directly, and the identifier, not the view type, is the contract they
    ///   are written against.
    public init(
        items: [SignalStripItem],
        identifierPrefix: String = "lifeboard.signal",
        onOpen: @escaping (SignalStripItem.ID) -> Void
    ) {
        self.items = Array(items.prefix(3))
        self.identifierPrefix = identifierPrefix
        self.onOpen = onOpen
    }

    public var body: some View {
        if items.isEmpty {
            // A genuinely empty strip draws nothing at all. An empty rail with
            // placeholder rings is how a screen ends up looking broken rather
            // than quiet.
            EmptyView()
        } else if dynamicTypeSize.isAccessibilitySize {
            // Signals stack at accessibility sizes rather than scrolling
            // horizontally: a horizontal rail of wrapped multi-line labels is
            // effectively unusable with VoiceOver's swipe order.
            VStack(spacing: 8) {
                ForEach(items) { item in
                    SignalTile(item: item, isWide: true, identifierPrefix: identifierPrefix, onOpen: { onOpen(item.id) })
                }
            }
        } else {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    SignalTile(item: item, isWide: false, identifierPrefix: identifierPrefix, onOpen: { onOpen(item.id) })
                }
            }
        }
    }
}

private struct SignalTile: View {
    let item: SignalStripItem
    let isWide: Bool
    let identifierPrefix: String
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.systemImage)
                        .font(.caption)
                    Text(item.label)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))

                SignalValue(reading: item.reading)

                if let timeframe = item.timeframe, item.reading.isRecorded {
                    Text(timeframe)
                        .font(.caption2)
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: isWide ? .infinity : nil, alignment: .leading)
            .frame(minWidth: isWide ? nil : 96, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .lifeBoardPressResponse(.card, haptic: nil)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.label), \(item.reading.accessibilityDescription)")
        .accessibilityIdentifier("\(identifierPrefix).\(item.id)")
    }
}

/// The reading itself, in the one place the state-to-appearance mapping lives.
private struct SignalValue: View {
    let reading: SignalReading

    var body: some View {
        switch reading {
        case .value(let value, let unit):
            valueText(value, unit: unit, tone: Color(SemanticColorTokens.inkPrimary))
        case .zero(let value):
            valueText(value, unit: nil, tone: Color(SemanticColorTokens.inkPrimary))
        case .stale(let value, let age):
            valueText(value, unit: age, tone: Color(SemanticColorTokens.inkSecondary))
        case .loading:
            ProgressView().controlSize(.mini)
        case .noRecord:
            // An em dash, not a zero and not a blank ring. It reads as
            // "nothing recorded" without implying a measurement was taken.
            quiet("—")
        case .denied:
            quiet("Not shared")
        case .unavailable:
            quiet("Unavailable")
        case .failed:
            Text("Didn't load")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(SemanticColorTokens.foundationDanger))
        }
    }

    private func valueText(_ value: String, unit: String?, tone: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tone)
            if let unit {
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
            }
        }
        .lineLimit(1)
    }

    private func quiet(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
            .lineLimit(1)
    }
}

private extension SignalReading {
    /// VoiceOver must hear the distinction the visual makes. "Blank" is not an
    /// acceptable announcement for four different states.
    var accessibilityDescription: String {
        switch self {
        case .value(let value, let unit): unit.map { "\(value) \($0)" } ?? value
        case .zero(let value): value
        case .stale(let value, let age): "\(value), \(age) old"
        case .loading: "Loading"
        case .noRecord: "Nothing recorded"
        case .denied: "Not shared"
        case .unavailable: "Unavailable"
        case .failed: "Didn't load"
        }
    }
}
