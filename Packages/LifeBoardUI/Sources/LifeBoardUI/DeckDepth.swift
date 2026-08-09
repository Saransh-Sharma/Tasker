import SwiftUI
import LifeBoardTokens
// Split out of `LifeBoardCardPrimitives`, which stays app-side because it
// accepts `HomeCardSnapshot` and friends. This modifier accepts an `Int`,
// so it is admissible and `DirectionalDeck` needs it here.
/// Shows that a triage card is the front of a queue.
///
/// Plan Repair and Overdue Rescue render one proposal at a time with no hint
/// that more are waiting, so resolving one felt like it produced another out of
/// nowhere. This is the sample project's shuffle idea reduced to the part that
/// carries information: depth. It deliberately does not take over the host's
/// gesture — Plan Repair maps swipe *direction* to distinct actions, which a
/// generic dismiss-deck would throw away.
public struct DeckDepth: ViewModifier {
    private let remaining: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Three reads as "a stack"; two reads as "one spare". Beyond three the
    /// cards stop being distinguishable and just thicken the shadow.
    ///
    /// Depth cues adapted from SwiftUI-Animations `Cards Shuffle/CardsShuffleView.swift`
    /// (Apache-2.0, © Shubham Singh) — scale falloff plus a per-level peek. The
    /// rotation and lateral scatter are additions: a perfectly concentric stack
    /// reads as a drop shadow, and the point here is that a queue of real
    /// decisions is waiting.
    private static let maximumBackingCards = 3

    public init(remaining: Int) {
        self.remaining = remaining
    }

    private var backingCount: Int {
        max(0, min(Self.maximumBackingCards, remaining - 1))
    }

    /// Deterministic, not random: the stack must not reshuffle its own geometry
    /// on every re-render.
    private func lean(_ depth: Int) -> Double {
        depth.isMultiple(of: 2) ? 1 : -1
    }

    public func body(content: Content) -> some View {
        content
            .background(alignment: .bottom) {
                if backingCount > 0 {
                    ZStack {
                        ForEach(Array((1...backingCount).reversed()), id: \.self) { depth in
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
                                }
                                .scaleEffect(1 - (CGFloat(depth) * 0.038))
                                .offset(
                                    x: CGFloat(depth) * 1.5 * lean(depth),
                                    y: CGFloat(depth) * 8
                                )
                                // Tilted away from the viewer so the stack has a
                                // top edge rather than a flat silhouette.
                                .rotation3DEffect(
                                    .degrees(Double(depth) * 1.6),
                                    axis: (x: 1, y: 0, z: 0),
                                    perspective: 0.6
                                )
                                .rotationEffect(.degrees(Double(depth) * 0.5 * lean(depth)))
                                .opacity(1 - (Double(depth) * 0.22))
                        }
                    }
                    .allowsHitTesting(false)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.84),
                        value: backingCount
                    )
                }
            }
            .accessibilityValue(
                remaining > 1 ? "1 of \(remaining)" : ""
            )
    }
}

public extension View {
    /// Renders the card as the front of a queue of `remaining` items.
    func lifeBoardDeckDepth(remaining: Int) -> some View {
        modifier(DeckDepth(remaining: remaining))
    }
}
