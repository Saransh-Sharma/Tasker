import SwiftUI
import LifeBoardTokens
/// The four ways a card can leave the hand.
///
/// Declaration order is slot order: a surface offering fewer actions than the
/// deck has directions fills right, left, up, down and leaves the rest inert
/// rather than doubling anything up.
public enum DeckDirection: CaseIterable, Hashable, Sendable {
    case right, left, up, down

    /// Where a committed card leaves the screen.
    public func exitOffset(distance: CGFloat = DeckPhysics.exitDistance) -> CGSize {
        switch self {
        case .right: CGSize(width: distance, height: 0)
        case .left: CGSize(width: -distance, height: 0)
        case .up: CGSize(width: 0, height: -distance)
        case .down: CGSize(width: 0, height: distance)
        }
    }
}

/// Shared flick physics for every card deck in the app.
///
/// Plan Repair proved the numbers; the Inbox needs the identical feel, so the
/// resolver moved here rather than being copied. `PlanRepairDeckDragResolver`
/// now forwards to this, which is why its own tests still pass unchanged.
///
/// A flick has to commit to an axis. Diagonals resolve to nothing rather than
/// guessing, because picking wrong here mutates the user's plan or files their
/// capture somewhere they did not choose.
public enum DeckPhysics {
    public static let threshold: CGFloat = 96
    public static let minimumIntent: CGFloat = 24
    /// How far the dominant axis must beat the other before the flick counts as
    /// pointing that way at all.
    public static let dominance: CGFloat = 1.15
    public static let exitDistance: CGFloat = 420

    public static func direction(
        translation: CGSize,
        predictedEndTranslation: CGSize
    ) -> DeckDirection? {
        guard max(abs(translation.width), abs(translation.height)) >= minimumIntent else { return nil }
        let dx = predictedEndTranslation.width
        let dy = predictedEndTranslation.height
        if abs(dx) > abs(dy) * dominance {
            guard abs(dx) >= threshold else { return nil }
            return dx > 0 ? .right : .left
        }
        if abs(dy) > abs(dx) * dominance {
            guard abs(dy) >= threshold else { return nil }
            return dy > 0 ? .down : .up
        }
        return nil
    }

    /// The action a direction carries, or nil when the surface offers fewer ways
    /// out than the deck has directions.
    ///
    /// Generic over the action type so Plan Repair's `PlanRepairAction` and the
    /// Inbox's triage decisions share one implementation without this layer
    /// importing either domain.
    public static func action<Action>(
        for direction: DeckDirection,
        candidates: [Action]
    ) -> Action? {
        guard let slot = DeckDirection.allCases.firstIndex(of: direction),
              slot < candidates.count else { return nil }
        return candidates[slot]
    }

    public static func action<Action>(
        translation: CGSize,
        predictedEndTranslation: CGSize,
        candidates: [Action]
    ) -> Action? {
        guard candidates.isEmpty == false,
              let direction = direction(
                  translation: translation,
                  predictedEndTranslation: predictedEndTranslation
              ) else { return nil }
        return action(for: direction, candidates: candidates)
    }

    /// Live tilt while dragging, clamped so a fast flick can never spin the card
    /// to an unreadable angle.
    public static func tiltDegrees(for translation: CGSize) -> Double {
        Double(max(-3, min(3, translation.width / 34)))
    }
}

/// A card deck whose flick *direction* selects between distinct actions.
///
/// The deliberate difference from a dismiss-deck: direction carries meaning, so
/// the front card reports the armed direction back to its content closure. A
/// gesture the user cannot see resolving is a guess, and this deck commits real
/// mutations.
///
/// Accessibility contract: the deck contributes a named VoiceOver action per
/// available direction, and callers are still expected to render visible button
/// equivalents — the gesture is an accelerator, never the only path.
public struct DirectionalDeck<Item: Identifiable, Action, SurfaceCard: View>: View {
    private let items: [Item]
    private let candidates: (Item) -> [Action]
    private let actionLabel: (Action) -> String
    private let onCommit: (Item, Action) -> Void
    private let card: (Item, DeckDirection?) -> SurfaceCard

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragTranslation: CGSize = .zero
    @State private var armedDirection: DeckDirection?
    @State private var exitOffset: CGSize = .zero
    @State private var committingID: Item.ID?

    public init(
        items: [Item],
        candidates: @escaping (Item) -> [Action],
        actionLabel: @escaping (Action) -> String,
        onCommit: @escaping (Item, Action) -> Void,
        @ViewBuilder card: @escaping (Item, DeckDirection?) -> SurfaceCard
    ) {
        self.items = items
        self.candidates = candidates
        self.actionLabel = actionLabel
        self.onCommit = onCommit
        self.card = card
    }

    public var body: some View {
        ZStack {
            if let front = items.first {
                cardLayer(item: front)
            }
        }
        .lifeBoardMotion(.cardReflow, value: items.first?.id)
    }

    /// Only the front card is a real card.
    ///
    /// Rendering the next two items as live siblings looked right until the deck
    /// held cards of different heights — a tall backing card then poked out from
    /// behind a short front one and leaked its content. `lifeBoardDeckDepth`
    /// already draws abstract backing shapes sized to the *front* card, which is
    /// the only thing the stack needs to communicate, so depth comes from there
    /// and never from a second card's geometry.
    ///
    /// Every geometry value is hoisted into a local before the modifier chain;
    /// inline ternaries here put this past the Swift type-checker's budget.
    private func cardLayer(item: Item) -> some View {
        let isLeaving: Bool = committingID == item.id
        let voiceOver = DeckVoiceOverActions(
            pairs: availablePairs(for: item),
            label: actionLabel,
            perform: { action in commit(item: item, action: action, direction: nil) }
        )

        return card(item, armedDirection)
            .lifeBoardDeckDepth(remaining: items.count)
            .rotationEffect(.degrees(liveTilt))
            .offset(liveOffset)
            .opacity(isLeaving ? 0 : 1)
            .gesture(dragGesture(for: item))
            .accessibilityElement(children: .contain)
            .modifier(voiceOver)
            .transition(.opacity)
    }

    /// Reduce Motion keeps the card square and still under the finger: the
    /// position still tracks the drag, because that is the content following the
    /// gesture rather than decoration, but the tilt and the throw are dropped.
    private var liveTilt: Double {
        guard reduceMotion == false else { return 0 }
        return DeckPhysics.tiltDegrees(for: dragTranslation)
    }

    private var liveOffset: CGSize {
        if exitOffset != .zero { return exitOffset }
        return dragTranslation
    }

    private func availablePairs(for item: Item) -> [(DeckDirection, Action)] {
        let available = candidates(item)
        return DeckDirection.allCases.compactMap { direction in
            DeckPhysics.action(for: direction, candidates: available)
                .map { (direction, $0) }
        }
    }

    private func dragGesture(for item: Item) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                dragTranslation = value.translation
                let resolved = DeckPhysics.direction(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation
                )
                let reachable = resolved.flatMap { direction in
                    DeckPhysics.action(for: direction, candidates: candidates(item))
                        .map { _ in direction }
                }
                if reachable != armedDirection {
                    armedDirection = reachable
                    // Only when a direction actually arms, so the hand feels the
                    // moment the decision becomes available rather than buzzing
                    // continuously through the drag.
                    if reachable != nil { HapticFeedback.selection() }
                }
            }
            .onEnded { value in
                let resolved = DeckPhysics.direction(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation
                )
                guard let direction = resolved,
                      let action = DeckPhysics.action(
                          for: direction,
                          candidates: candidates(item)
                      ) else {
                    armedDirection = nil
                    withAnimation(MotionProfile.directManipulation.animation(reduceMotion: reduceMotion)) {
                        dragTranslation = .zero
                    }
                    return
                }
                commit(item: item, action: action, direction: direction)
            }
    }

    /// Throws the card out along its committed direction, then applies the
    /// mutation on the animation's real completion rather than a guessed delay,
    /// so a slower device cannot commit against a card still on screen.
    private func commit(item: Item, action: Action, direction: DeckDirection?) {
        armedDirection = nil
        guard let direction, reduceMotion == false else {
            dragTranslation = .zero
            onCommit(item, action)
            return
        }
        committingID = item.id
        withAnimation(
            MotionProfile.directManipulation.animation(reduceMotion: reduceMotion)
        ) {
            exitOffset = direction.exitOffset()
        } completion: {
            exitOffset = .zero
            dragTranslation = .zero
            committingID = nil
            onCommit(item, action)
        }
    }
}

/// Attaches one named VoiceOver action per reachable direction.
///
/// Split into its own modifier because `accessibilityAction(named:)` cannot be
/// applied from a loop inside a `ViewBuilder` without collapsing the element.
private struct DeckVoiceOverActions<Action>: ViewModifier {
    let pairs: [(DeckDirection, Action)]
    let label: (Action) -> String
    let perform: (Action) -> Void

    func body(content: Content) -> some View {
        pairs.reduce(AnyView(content)) { partial, pair in
            AnyView(
                partial.accessibilityAction(named: Text(label(pair.1))) {
                    perform(pair.1)
                }
            )
        }
    }
}
