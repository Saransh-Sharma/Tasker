import SwiftUI

/// Recording what pulled you away, without leaving the session.
///
/// This is the one place in the Focus surface where a gesture earns its keep: an
/// interruption is by definition something you log *while distracted*, so it has
/// to be reachable without reading a menu. Swiping the strip right past the
/// detent records the most common reason directly.
///
/// `DESIGN.md` requires gesture parity — "Every gesture has a visible control and
/// VoiceOver action" — so the three reasons stay visible as buttons the moment
/// the strip is expanded, and `lifeBoardMagneticToggle` contributes its own
/// VoiceOver custom action. The gesture is an accelerator for something already
/// on screen, never the only way in.
struct FocusInterruptionControl: View {
    let store: PlanStore

    @State private var isExpanded = false
    @State private var lastRecorded: String?

    /// Ordered by how often each actually happens, because the swipe commits the
    /// first one and the cheapest gesture should map to the likeliest reason.
    private static let reasons = ["Call or message", "Someone needed me", "Lost focus"]

    var body: some View {
        VStack(spacing: 10) {
            strip
            if isExpanded {
                reasonButtons
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if let lastRecorded {
                Text("Noted: \(lastRecorded)")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .transition(.opacity)
            }
        }
        .lifeBoardMotion(.localState, value: isExpanded)
        .accessibilityIdentifier("focus.surface.interruption")
    }

    private var strip: some View {
        Button {
            isExpanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "bell.slash")
                Text(isExpanded ? "Hide interruptions" : "Something interrupted me")
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .font(.subheadline)
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .frame(minHeight: 44)
            .padding(.horizontal, 14)
            .lifeBoardClaySurface(.well, cornerRadius: Radius.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .lifeBoardMagneticToggle(
            threshold: 96,
            actionLabel: "Record interruption: \(Self.reasons[0])"
        ) {
            record(Self.reasons[0])
        }
        .accessibilityIdentifier("focus.surface.interruption.strip")
    }

    private var reasonButtons: some View {
        VStack(spacing: 8) {
            ForEach(Self.reasons, id: \.self) { reason in
                Button(reason) { record(reason) }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("focus.surface.interruption.reason")
            }
        }
    }

    /// The confirmation line appears only after the store's write returns.
    /// `DESIGN.md`: success feedback begins after persistence, never on a timer.
    private func record(_ reason: String) {
        Task {
            await store.recordInterruption(reason: reason)
            lastRecorded = reason
            isExpanded = false
        }
    }
}
