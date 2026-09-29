import SwiftUI

/// Reflection where the session ended, instead of a card that waits on Plan.
///
/// The ending is already persisted when this appears — `FocusSurface` mounts
/// it from `handleCommitted` — so every beat here is success motion after the
/// write, never before it. The sequence: the dial closes (the parent's
/// concern), the tick draws, the minutes roll in against the task, then one
/// energy choice and one optional line. Done saves through the same
/// `PlanStore.saveFocusReflection` the Plan card uses, so the fallback card
/// and this section can never disagree about what a reflection is.
///
/// `PlanFocusReflectionCard` stays for sessions that end elsewhere — a Live
/// Activity's End button, a deep link, the app killed mid-session — where no
/// surface was on screen to ask.
struct FocusReflectionSection: View {
    let store: PlanStore
    let receipt: FocusExecutionReceipt
    let taskTitle: String?
    /// Called after Done or Skip; the parent then offers the way back.
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeBoardMotionContext) private var motion
    @State private var tickProgress: Double = 0
    @State private var showsNumber = false
    @State private var showsPrompt = false
    /// Unselected until chosen: a pre-set 3 was saved as the person's answer
    /// whenever they tapped Done without touching the rail.
    @State private var energy: EnergyChoice = .unset
    @State private var note = ""

    private var timeline: FocusReflectionTimeline {
        FocusReflectionTimeline.resolve(comfort: motion.comfortProfile, reduceMotion: reduceMotion || motion.effectiveReduceMotion)
    }

    private var focusedMinutes: Double {
        (receipt.actualFocusedDuration / 60).rounded(.down)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                CompletionMark(progress: tickProgress)
                    .stroke(
                        Color(SemanticColorTokens.foundationApricotInk),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        NumericRoll(value: focusedMinutes, unit: "min", emphasis: .standard)
                        if let taskTitle, taskTitle.isEmpty == false {
                            Text("on \(taskTitle)")
                                .lifeboardFont(.body)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                                .lineLimit(2)
                        }
                    }
                    if receipt.interruptionCount > 0 {
                        Text(receipt.interruptionCount == 1 ? "1 interruption" : "\(receipt.interruptionCount) interruptions")
                            .lifeboardFont(.caption1)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                }
                .opacity(showsNumber ? 1 : 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(Int(focusedMinutes)) minutes focused" + (taskTitle.map { " on \($0)" } ?? ""))

            VStack(alignment: .leading, spacing: 12) {
                Text("How's your energy now?")
                    .lifeboardFont(.headline)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                // The same value control the Plan card uses, so the two never
                // drift: one selection, per-value identifiers, reflow at
                // accessibility sizes.
                OptionRail(
                    "Energy after focus",
                    selection: $energy,
                    values: EnergyChoice.levels,
                    identifierPrefix: "focus.reflection.energy",
                    title: { $0.rawValue },
                    showsLabel: false
                )
                .accessibilityValue(energy.level.map { "\($0) out of 5" } ?? "Not chosen")
                TextField("Note", text: $note, prompt: Text("Note").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    // Clay well, not the system rounded border: that drew a pure white
                    // box on warm paper and a pure black one in dark appearance.
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                    .accessibilityIdentifier("focus.reflection.note")
                HStack(spacing: 12) {
                    Button("Skip") {
                        Haptic.pick.play()
                        store.dismissFocusReflection()
                        onFinished()
                    }
                    .font(.body.weight(.semibold))
                    .frame(minHeight: 44)
                    .buttonStyle(.lifeBoardChip)
                    .accessibilityIdentifier("focus.reflection.skip")
                    CommitControl(
                        title: "Done",
                        runningTitle: String(localized: "Saving…"),
                        successTitle: "Saved",
                        phase: store.focusReflectionCommitPhase
                    ) {
                        let energy = energy.level
                        let note = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        Task {
                            await store.saveFocusReflection(energy: energy, note: note.isEmpty ? nil : note)
                            if store.pendingFocusReflection == nil {
                                // Let "Saved" settle before the section folds;
                                // finishing on the same frame meant the
                                // success state was never seen.
                                try? await Task.sleep(for: .milliseconds(reduceMotion ? 300 : 600))
                                onFinished()
                            }
                        }
                    }
                    .accessibilityIdentifier("focus.reflection.commit")
                }
            }
            .opacity(showsPrompt ? 1 : 0)
            // Invisible controls must not be reachable either: VoiceOver
            // used to land on a prompt that had not appeared yet.
            .accessibilityHidden(showsPrompt == false)
            .allowsHitTesting(showsPrompt)
        }
        .padding(16)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("focus.reflection")
        .task { await play() }
    }

    /// Plays the beats once. The prompt becomes interactive as it appears.
    private func play() async {
        let timeline = timeline
        if timeline.total == 0 {
            withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                tickProgress = 1
                showsNumber = true
                showsPrompt = true
            }
            return
        }
        try? await Task.sleep(for: .seconds(timeline.tickDelay))
        withAnimation(MotionProfile.celebration.animation(reduceMotion: reduceMotion)) { tickProgress = 1 }
        try? await Task.sleep(for: .seconds(timeline.numberDelay - timeline.tickDelay))
        withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { showsNumber = true }
        try? await Task.sleep(for: .seconds(timeline.promptDelay - timeline.numberDelay))
        withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) { showsPrompt = true }
    }
}

/// An energy answer that can be "not given". Raw values are the digits, so
/// the rail's per-value identifiers stay `focus.reflection.energy.1`…`5`.
private enum EnergyChoice: String, Hashable {
    case unset = "", one = "1", two = "2", three = "3", four = "4", five = "5"

    static let levels: [EnergyChoice] = [.one, .two, .three, .four, .five]

    var level: Int? { Int(rawValue) }
}
