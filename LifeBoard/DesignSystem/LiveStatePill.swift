import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// A compact glass capsule reporting state that is genuinely running right now.
///
/// `DESIGN.md`: "A live-state pill must never be used for state that is merely
/// recent, merely selected, or merely important. If it is animating, something
/// is happening right now."
///
/// That sentence is the whole design. The pill is one of the few places the
/// product makes a promise about *the present tense*, so `isLive` is a required
/// parameter rather than something inferred from the presence of a value — a
/// finished fast and a running one both have a duration, and only one of them
/// should breathe.
public struct LiveStatePill: View {
    private let label: String
    private let value: String?
    private let symbol: String
    private let isLive: Bool
    private let progress: Double?
    private let accessibilityID: String?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        label: String,
        value: String? = nil,
        symbol: String,
        isLive: Bool,
        progress: Double? = nil,
        accessibilityID: String? = nil
    ) {
        self.label = label
        self.value = value
        self.symbol = symbol
        self.isLive = isLive
        self.progress = progress
        self.accessibilityID = accessibilityID
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.footnote)
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .accessibilityHidden(true)

            Text(label)
                .lifeboardFont(.meta)
                .foregroundStyle(Color.lifeboard(.textSecondary))

            if let value {
                Text(value)
                    .lifeboardFont(.meta)
                    .monospacedDigit()
                    .foregroundStyle(Color.lifeboard(.textPrimary))
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(capsuleMaterial)
        .modifier(EmberRing(isLive: isLive, progress: progress ?? 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(spokenValue)
        .accessibilityIdentifier(accessibilityID ?? "lifeboard.livepill")
    }

    /// A pill is chrome, so glass is legitimate here without spending the
    /// screen's one hero claim.
    @ViewBuilder
    private var capsuleMaterial: some View {
        if reduceTransparency {
            Capsule(style: .continuous)
                .fill(Color.lifeboard(.bgElevated))
                .overlay(Capsule(style: .continuous).stroke(Color.lifeboard(.strokeStrong), lineWidth: 1))
        } else {
            Color.clear.lifeBoardSystemGlass(.regular, in: Capsule(style: .continuous))
        }
    }

    private var spokenValue: String {
        let state = isLive ? "in progress" : "not running"
        return [value, state].compactMap { $0 }.joined(separator: ", ")
    }
}

/// The ember only burns while the state is actually live.
///
/// Split into its own modifier so the shader call site has one unambiguous
/// condition. Folding it into an inline `if` inside `body` had the effect of
/// re-running the shader's entry animation on unrelated state changes.
private struct EmberRing: ViewModifier {
    let isLive: Bool
    let progress: Double

    func body(content: Content) -> some View {
        if isLive {
            content.lifeboardFastingEmberRing(
                progress: min(1, max(0, progress)),
                tint: Color.lifeboard(.accentPrimary)
            )
        } else {
            content
        }
    }
}
