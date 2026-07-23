import SwiftUI

/// Full-screen overlay for milestone celebrations (Spark, Flywheel, etc.).
/// Extended duration compared to level-up, with milestone-specific icon.
public struct MilestoneCelebrationView: View {

    let milestone: XPCalculationEngine.Milestone
    let awardedXP: Int
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeBoardTransitionCoordinator) private var transitionCoordinator

    @State private var iconScale: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var overlayOpacity: Double = 0
    @State private var glowOpacity: Double = 0

    public var body: some View {
        if isPresented {
            ZStack {
                Color.lifeboard.bgCanvas
                    .opacity(overlayOpacity * 0.85)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                LifeBoardCard(active: true, elevated: true) {
                    VStack(spacing: 20) {
                        ZStack {
                            Circle()
                                .fill(Color.lifeboard.statusWarning.opacity(glowOpacity * 0.2))
                                .frame(width: 120, height: 120)

                            Image(systemName: milestone.sfSymbol)
                                .font(.largeTitle.weight(.semibold))
                                .foregroundColor(Color.lifeboard.statusWarning)
                                .scaleEffect(iconScale)
                        }

                        Text(milestone.name)
                            .font(.lifeboard(.title1))
                            .foregroundColor(Color.lifeboard.accentPrimary)
                            .opacity(textOpacity)

                        Text("Milestone reached")
                            .font(.lifeboard(.body))
                            .foregroundColor(Color.lifeboard.textSecondary)
                            .opacity(textOpacity)

                        Text("\(milestone.xpThreshold) XP")
                            .font(.lifeboard(.bodyEmphasis))
                            .foregroundColor(Color.lifeboard.textSecondary)
                            .contentTransition(.numericText())
                            .opacity(textOpacity)

                        if awardedXP > 0 {
                            Text("+\(awardedXP) XP")
                                .font(.lifeboard(.headline))
                                .foregroundColor(Color.lifeboard.accentSecondary)
                                .contentTransition(.numericText())
                                .opacity(textOpacity)
                        }
                    }
                }
                .frame(maxWidth: 380)
                .padding(.horizontal, 24)
            }
            .onAppear {
                let key = "milestone.\(milestone.name).\(milestone.xpThreshold)"
                guard transitionCoordinator?.claimOneShot(key) != false else {
                    isPresented = false
                    return
                }
                performAnimation()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Milestone reached! \(milestone.name) at \(milestone.xpThreshold) XP. \(awardedXP > 0 ? "+\(awardedXP) XP awarded." : "")"
            )
            .accessibilityAddTraits(.isModal)
        }
    }

    private func performAnimation() {
        withAnimation(reduceMotion ? LifeBoardAnimation.feedbackFast : LifeBoardAnimation.celebration) {
            overlayOpacity = 1.0
            iconScale = reduceMotion ? 1.0 : 1.2
        }

        if !reduceMotion {
            withAnimation(LifeBoardAnimation.stateChange.delay(0.12)) {
                iconScale = 1.0
            }
        }

        withAnimation(LifeBoardAnimation.stateChange.delay(0.14)) {
            textOpacity = 1.0
        }

        withAnimation(LifeBoardAnimation.celebration.delay(0.16)) {
            glowOpacity = 1.0
        }

        LifeBoardFeedback.success()

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.65 : 0.88)) {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(LifeBoardAnimation.panelOut) {
            overlayOpacity = 0
            iconScale = 0
            textOpacity = 0
            glowOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            isPresented = false
        }
    }
}
