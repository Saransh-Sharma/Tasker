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
    /// Used when a proposal carries no explanation of its own, and to let a
    /// host reframe one that reads too much like a system message.
    var fallbackExplanation: String
    let onAction: (PlanRepairAction, PlanRepairProposal?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGSize = .zero
    @State private var snapAction: PlanRepairAction?

    init(
        proposals: [PlanRepairProposal],
        header: String? = "Plan repair",
        fallbackExplanation: String = "Your day has changed. Choose what should move; nothing changes automatically.",
        onAction: @escaping (PlanRepairAction, PlanRepairProposal?) -> Void
    ) {
        self.proposals = proposals
        self.header = header
        self.fallbackExplanation = fallbackExplanation
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
        VStack(alignment: .leading, spacing: 10) {
            if let header {
                Label(header, systemImage: "wand.and.stars")
                    .font(.headline)
            }
            Text(proposal?.explanation ?? fallbackExplanation)
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
                        .buttonStyle(.bordered)
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
        .accessibilityIdentifier("plan.repair")
    }

    /// Says which way each repair lives, and lights the one the current flick
    /// would commit. Without it the extra two directions are invisible: a swipe
    /// deck that mutates the plan should never rely on the user guessing.
    private func repairDirectionPad(_ candidates: [PlanRepairAction]) -> some View {
        VStack(spacing: 3) {
            repairDirectionChip(.up, candidates: candidates)
            HStack(spacing: 6) {
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
                if candidate != nil, snapAction == nil { HapticFeedback.selection() }
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
                HapticFeedback.medium()
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

    static func actionTitle(_ action: PlanRepairAction) -> String {
        switch action {
        case .resume: "Resume"
        case .moveLaterToday: "Later today"
        case .moveToAnotherDay: "Another day"
        case .split: "Split"
        case .defer: "Defer"
        // Not "Leave unchanged": the exit from a repair deck should sound like
        // a decision someone made, not like declining to fix something.
        // Deliberately not "Leave *today* as it is" — Plan can show this deck
        // for a day the person has scrolled back to, and it would be wrong there.
        case .leaveUnchanged: "Leave it as it is"
        case .askEva: "Ask Eva"
        }
    }

    static func actionSymbol(_ action: PlanRepairAction) -> String {
        switch action {
        case .resume: "play.fill"
        case .moveLaterToday: "clock.arrow.circlepath"
        case .moveToAnotherDay: "calendar.badge.plus"
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

    private func action(_ slot: Int) -> PlanRepairAction? {
        slot < candidates.count ? candidates[slot] : nil
    }

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: action(0).map { Text(title($0)) } ?? Text("Apply first repair")) {
                if let value = action(0) { perform(value) }
            }
            .accessibilityAction(named: action(1).map { Text(title($0)) } ?? Text("Apply second repair")) {
                if let value = action(1) { perform(value) }
            }
            .accessibilityAction(named: action(2).map { Text(title($0)) } ?? Text("Apply third repair")) {
                if let value = action(2) { perform(value) }
            }
            .accessibilityAction(named: action(3).map { Text(title($0)) } ?? Text("Apply fourth repair")) {
                if let value = action(3) { perform(value) }
            }
    }
}
