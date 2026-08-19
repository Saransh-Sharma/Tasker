import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// One beat per application root, in dock order.
///
/// Deliberately not a generic five-card carousel. The orbit the user has been
/// looking at for the whole flow already draws these five roots in its inner
/// ring, so the tour lights each one in turn and names it — the orientation is
/// tied to the map they just built rather than bolted on beside it. The copy is
/// `LifeMapRootCopy`, the same sentences the inspect-a-root sheet shows, so the
/// tour cannot drift from the previews.
struct LifeMapTourStep: View {
    let destination: Destination
    let index: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            LifeMapEyebrow("\(index + 1) OF \(total)")
            Text(destination.title)
                .font(.lifeboard(.heroDisplay))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .minimumScaleFactor(0.75)
            Text(LifeMapRootCopy.subtitle(for: destination))
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(LifeMapRootCopy.rows(for: destination)) { row in
                    Label(row.text, systemImage: row.symbol)
                        .font(.lifeboard(.body))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: 22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(destination.title). Step \(index + 1) of \(total).")
        .accessibilityIdentifier(LifeMapAccessibilityID.tourBeat(destination.rawValue))
    }
}

/// The hand-off.
///
/// Whether EVA was connected decides what this screen leads with, but never
/// whether it appears: the prompts are staged either way, so a user who
/// declined cloud EVA finds them waiting the moment they connect.
struct LifeMapFirstWinStep: View {
    let isCloudReady: Bool
    let prompts: [EvaStarterPrompt]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            LifeMapEyebrow(isCloudReady ? "ONE LAST THING" : "WHEN YOU'RE READY")
            Text(isCloudReady ? "Ask EVA where to start." : "EVA is waiting when you are.")
                .font(.lifeboard(.heroDisplay))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            Text(isCloudReady
                 ? "These are built from what you just told us. Pick one and EVA answers using your areas, your capacity, and your calendar."
                 : "Connect EVA from its tab whenever you like. These openers will be waiting.")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ForEach(prompts) { prompt in
                    HStack(spacing: Theme.Spacing.md) {
                        Image(systemName: prompt.isRecommended ? "sparkles" : "arrow.turn.down.right")
                            .foregroundStyle(Color.lifeboard(prompt.isRecommended ? .accentPrimary : .textTertiary))
                            .frame(width: 24)
                        Text(prompt.title)
                            .font(.lifeboard(prompt.isRecommended ? .bodyStrong : .body))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(Theme.Spacing.md + 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lifeBoardClaySurface(prompt.isRecommended ? .raised : .resting, cornerRadius: 16)
                    .accessibilityIdentifier(LifeMapAccessibilityID.firstWinPrompt(prompt.id))
                }
            }
            .accessibilityIdentifier(LifeMapAccessibilityID.firstWinPrompts)

            Text("Nothing is sent until you tap one.")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textTertiary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.firstWin))
    }
}
