import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// One quiet line, the first time a root could mean something.
///
/// Clay, not glass: this is content the person reads, not a control, and
/// `DESIGN.md` keeps glass for decisions and chrome. It sits above the dock
/// rather than over the content it describes, so it never covers the thing it
/// is pointing at, and it is dismissible by tap with a real 44-point target.
struct OnboardingContextualTipCard: View {
    let tip: OnboardingContextualTip
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: tip.symbol)
                .lifeboardFont(.headline)
                .foregroundStyle(Color.lifeboard(.accentPrimary))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(tip.title)
                    .lifeboardFont(.bodyStrong)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                Text(tip.detail)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Spacing.xs)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Dismiss tip")
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.tip.\(tip.rawValue)")
    }
}

/// Shows the cue owed to the current root, once.
///
/// The tip is marked seen when it is *presented*, not when it is dismissed. A
/// person who reads it and navigates away has been told; making them find the
/// close button to stop being told again would be the modal behaviour this
/// exists to avoid.
struct OnboardingContextualTipModifier: ViewModifier {
    let destination: Destination

    @State private var activeTip: OnboardingContextualTip?
    /// Read once rather than on every body evaluation — the shell re-renders on
    /// every root change, atmosphere tick and scroll.
    @State private var hasCompletedLifeWeave = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let activeTip {
                    OnboardingContextualTipCard(tip: activeTip) {
                        withAnimation(MotionProfile.contentInsertion.animation(
                            reduceMotion: MotionOverride.effectiveReduceMotion
                        )) {
                            self.activeTip = nil
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    // Clears the dock *and* the composer capsule above it, which
                    // together own the bottom of every root. 132 cleared only
                    // the dock and left the cue sitting on the composer.
                    .padding(.bottom, 176)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .onAppear {
                hasCompletedLifeWeave = AppOnboardingStateStore.shared.load().completedLifeWeave == true
                evaluate(for: destination)
            }
            .onChange(of: destination) { _, newValue in
                activeTip = nil
                evaluate(for: newValue)
            }
    }

    private func evaluate(for destination: Destination) {
        guard let tip = OnboardingContextualTip(destination: destination),
              OnboardingContextualTipState.shouldShow(tip, hasCompletedLifeWeave: hasCompletedLifeWeave)
        else { return }
        OnboardingContextualTipState.markSeen(tip)
        withAnimation(MotionProfile.contentInsertion.animation(
            reduceMotion: MotionOverride.effectiveReduceMotion
        )) {
            activeTip = tip
        }
    }
}

extension View {
    /// Attaches the one-time root cue that replaced the v6 root tour.
    func lifeBoardOnboardingTip(destination: Destination) -> some View {
        modifier(OnboardingContextualTipModifier(destination: destination))
    }
}
