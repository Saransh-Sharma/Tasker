import SwiftUI

/// The repair deck: one proposal at a time, four ways to answer it.
///
/// Extracted from `PlanRootView` so Home's loop spine can offer the
/// same deck for the same drift. It deliberately owns no store — the caller
/// supplies the proposals and receives the chosen action, because Plan and Home
/// resolve a repair through different paths. Plan hands the action to its
/// `PlanStore` to stage a scenario; Home has no scenario coordinator, so it
/// routes the person to Plan instead of silently doing nothing.
///
/// Drag state lives here rather than in the caller: it is deck mechanics, and
/// two hosts sharing one `@State` offset would fight over it.
struct PlanRepairDeck: View {
    let proposals: [PlanRepairProposal]
    /// Shown above the card. `nil` where the host already has a heading — the
    /// spine titles the stage "Worth a look" and a second header under it would
    /// name the same thing twice.
    var header: String?
    /// A host's own framing, which wins over the proposal's explanation.
    ///
    /// This was `proposal?.explanation ?? fallbackExplanation`, but a proposal's
    /// explanation is never nil, so a host's gentler line only ever showed on an
    /// empty deck. Home's "This one didn't get its window today." never rendered.
    var explanationOverride: String?
    let onAction: (PlanRepairAction, PlanRepairProposal?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var snapAction: PlanRepairAction?
    /// `triageSettle` is the effect `DESIGN.md` names for "Inbox, Rescue, and
    /// repair decks". Inbox and Rescue had it; this deck, which is the third
    /// one named, did not.
    @State private var triageSettleTrigger = 0
    @State private var triageSettleDirection = 1.0

    init(
        proposals: [PlanRepairProposal],
        header: String? = "Plan repair",
        explanationOverride: String? = nil,
        onAction: @escaping (PlanRepairAction, PlanRepairProposal?) -> Void
    ) {
        self.proposals = proposals
        self.header = header
        self.explanationOverride = explanationOverride
        self.onAction = onAction
    }

    private var proposal: PlanRepairProposal? { proposals.first }

    private var dragCandidates: [PlanRepairAction] {
        // With the flagship stage off the deck keeps its original two
        // directions, so the rollback is a genuine return to the previous
        // behaviour rather than a half-lit four-way pad.
        let directionCount = V2FeatureFlags.taskProjectFlagshipV1Enabled
            ? PlanRepairDeckDragResolver.Direction.allCases.count
            : 2
        return Array((proposal?.actions ?? []).filter { $0 != .askEva }.prefix(directionCount))
    }

    var body: some View {
        let candidates = dragCandidates
        VStack(alignment: .leading, spacing: 12) {
            if let header {
                SectionHeader(header, symbol: "wand.and.stars")
            }
            Text(Self.explanation(override: explanationOverride, proposal: proposal))
                .font(.subheadline).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            if candidates.isEmpty == false {
                repairDirectionPad(candidates)
            }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array((proposal?.actions ?? []).prefix(5)), id: \.self) { action in
                        Button(Self.actionTitle(action), systemImage: Self.actionSymbol(action)) {
                            onAction(action, proposal)
                        }
                        .buttonStyle(.lifeBoardChip)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        // Expanded from `foundationClayCard()`, which is fileprivate to
        // `LifeBoardPlanViews.swift` and already has one duplicate elsewhere.
        // Inlining keeps this identical without minting a third copy.
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.clear)
                .lifeboardTriageSettle(
                    trigger: triageSettleTrigger,
                    direction: triageSettleDirection
                )
                .allowsHitTesting(false)
        }
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
        // Resolving one proposal used to appear to conjure another; the deck
        // depth says up front how many are queued.
        .lifeBoardDeckDepth(remaining: proposals.count)
        // Vertical travel is no longer decorative, so it tracks the finger as
        // openly as horizontal travel does.
        .offset(x: dragOffset.width * 0.22, y: dragOffset.height * 0.22)
        .scaleEffect(dragOffset == .zero ? 1 : 1.012)
        .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: dragOffset)
        .simultaneousGesture(repairGesture(candidates: candidates))
        .modifier(
            PlanRepairAccessibilityActions(
                candidates: candidates,
                title: Self.actionTitle,
                perform: { onAction($0, proposal) }
            )
        )
        // A container first: a bare identifier here was stamped onto every
        // child and hid the buttons' own names from UI tests.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.repair")
    }

    /// Says which way each repair lives, and lights the one the current flick
    /// would commit. Without it the extra two directions are invisible: a swipe
    /// deck that mutates the plan should never rely on the user guessing.
    private func repairDirectionPad(_ candidates: [PlanRepairAction]) -> some View {
        VStack(spacing: 3) {
            repairDirectionChip(.up, candidates: candidates)
            HStack(spacing: 8) {
                repairDirectionChip(.left, candidates: candidates)
                repairDirectionChip(.right, candidates: candidates)
            }
            repairDirectionChip(.down, candidates: candidates)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func repairDirectionChip(
        _ direction: PlanRepairDeckDragResolver.Direction,
        candidates: [PlanRepairAction]
    ) -> some View {
        if let action = PlanRepairDeckDragResolver.action(for: direction, candidates: candidates) {
            let armed = snapAction == action
            HStack(spacing: 4) {
                Image(systemName: Self.directionSymbol(direction))
                Text(Self.actionTitle(action)).lineLimit(1)
            }
            .font(.caption2.weight(armed ? .bold : .regular))
            .foregroundStyle(
                Color(armed ? SemanticColorTokens.inkPrimary : SemanticColorTokens.inkSecondary)
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color(SemanticColorTokens.foundationApricotAccent)
                    .opacity(armed ? 0.30 : 0.10),
                in: Capsule()
            )
            .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: armed)
        }
    }

    private func repairGesture(candidates: [PlanRepairAction]) -> some Gesture {
        let proposal = proposal
        return DragGesture(minimumDistance: 14)
            .onChanged { value in
                dragOffset = value.translation
                let candidate = PlanRepairDeckDragResolver.action(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation,
                    candidates: candidates
                )
                if candidate != nil, snapAction == nil { Haptic.threshold.play() }
                snapAction = candidate
            }
            .onEnded { value in
                let direction = PlanRepairDeckDragResolver.direction(
                    translation: value.translation,
                    predictedEndTranslation: value.predictedEndTranslation
                )
                let action = direction.flatMap {
                    PlanRepairDeckDragResolver.action(for: $0, candidates: candidates)
                }
                snapAction = nil
                let animationsOff = LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion)
                guard let action, let direction else {
                    withAnimation(MotionProfile.directManipulation.animation(reduceMotion: reduceMotion)) {
                        dragOffset = .zero
                    }
                    return
                }
                Haptic.settle.play()
                triageSettleDirection = direction == .left ? -1 : 1
                triageSettleTrigger &+= 1
                guard animationsOff == false else {
                    dragOffset = .zero
                    onAction(action, proposal)
                    return
                }
                withAnimation(LifeBoardAnimation.panelOut) {
                    // The card leaves the way it was thrown, so the gesture and
                    // the result read as one motion.
                    dragOffset = PlanRepairDeckDragResolver.exitOffset(for: direction)
                } completion: {
                    // Commits on the animation's real completion. This was a
                    // hardcoded 0.18 s `asyncAfter`, which mutated the plan while
                    // the card was still on screen whenever the device ran slow.
                    dragOffset = .zero
                    onAction(action, proposal)
                }
            }
    }

    // MARK: - Naming

    static let emptyDeckExplanation = String(localized: "Your day changed. Pick what moves.")

    static func explanation(override: String?, proposal: PlanRepairProposal?) -> String {
        override ?? proposal?.explanation ?? emptyDeckExplanation
    }

    static func actionTitle(_ action: PlanRepairAction) -> String {
        PlanRepairCopy.title(action)
    }

    static func actionSymbol(_ action: PlanRepairAction) -> String {
        switch action {
        case .resume: "play.fill"
        case .moveLaterToday: DecisionDestination.laterToday.systemImage
        case .moveToAnotherDay: DecisionDestination.tomorrow.systemImage
        case .split: "rectangle.split.2x1"
        case .defer: "tray"
        case .leaveUnchanged: "minus.circle"
        case .askEva: "sparkles"
        }
    }

    static func directionSymbol(_ direction: PlanRepairDeckDragResolver.Direction) -> String {
        switch direction {
        case .right: "chevron.right"
        case .left: "chevron.left"
        case .up: "chevron.up"
        case .down: "chevron.down"
        }
    }
}

/// Every drag direction also has to be reachable without dragging.
struct PlanRepairAccessibilityActions: ViewModifier {
    let candidates: [PlanRepairAction]
    let title: (PlanRepairAction) -> String
    let perform: (PlanRepairAction) -> Void

    /// One VoiceOver action per *existing* candidate.
    ///
    /// This used to publish four fixed slots, so a deck offering two repairs
    /// still announced "Apply third repair" and "Apply fourth repair", both of
    /// which did nothing when chosen. `DESIGN.md` asks every gesture direction
    /// for a real VoiceOver action, not a placeholder for one.
    func body(content: Content) -> some View {
        content
            .accessibilityActions {
                ForEach(candidates, id: \.self) { candidate in
                    Button(title(candidate)) { perform(candidate) }
                }
            }
    }
}
