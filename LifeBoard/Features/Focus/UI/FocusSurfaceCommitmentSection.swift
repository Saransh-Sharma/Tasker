import SwiftUI

/// The one thing you said you were doing.
///
/// `DESIGN.md` gives Focus a single commitment, so this section leads with the
/// intention in reading type and demotes the mode and pomodoro round to quiet
/// metadata. The old card led with a `Label("Focus in progress")` — a status the
/// dial already communicates, occupying the most valuable line on the screen.
struct FocusSurfaceCommitmentSection: View {
    let session: FocusSessionV2
    let companion: FocusSessionCompanion?

    var body: some View {
        VStack(spacing: 8) {
            Text(headline)
                .font(Typography.sectionTitle())
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .fixedSize(horizontal: false, vertical: true)

            if let context {
                Text(context)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("focus.surface.commitment")
    }

    private var headline: String {
        guard let intention = companion?.intention, intention.isEmpty == false else {
            // No stated intention is a real state, not a blank. Naming it keeps
            // the dominant line from collapsing to empty space.
            return "Focusing"
        }
        return intention
    }

    /// Mode and round, folded into one quiet line. Two separate metadata rows
    /// competed with the intention above them for no added meaning.
    private var context: String? {
        guard let companion else { return nil }
        var parts: [String] = []
        switch companion.mode {
        case .countdown:
            parts.append("Countdown")
        case .stopwatch:
            parts.append("Stopwatch")
        case .openEnded:
            parts.append("Open-ended")
        case let .pomodoro(_, _, rounds):
            if let phase = companion.pomodoroPhase {
                parts.append(phase.kind == .focus ? "Focus" : "Rest")
                parts.append("round \(phase.round) of \(rounds)")
            } else {
                parts.append("Pomodoro")
            }
        }
        if session.state == .paused {
            parts.append("paused")
        }
        return parts.joined(separator: " · ")
    }
}
