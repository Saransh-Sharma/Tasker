import SwiftUI

/// Full-screen overlay for milestone celebrations (Spark, Flywheel, etc.).
/// Extended duration compared to level-up, with milestone-specific icon.
public struct MilestoneCelebrationView: View {

    let milestone: XPCalculationEngine.Milestone
    @Binding var isPresented: Bool

    @State private var iconScale: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var overlayOpacity: Double = 0
    @State private var glowOpacity: Double = 0

    public var body: some View {
        if isPresented {
            ZStack {
                Color.tasker.bgCanvas
                    .opacity(overlayOpacity * 0.85)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.tasker.statusWarning.opacity(glowOpacity * 0.2))
                            .frame(width: 120, height: 120)

                        Image(systemName: milestone.sfSymbol)
                            .font(.system(size: 48))
                            .foregroundColor(Color.tasker.statusWarning)
                            .scaleEffect(iconScale)
                    }

                    Text(milestone.name)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color.tasker.accentPrimary)
                        .opacity(textOpacity)

                    Text("Milestone Reached")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textSecondary)
                        .opacity(textOpacity)

                    Text("\(milestone.xpThreshold) XP")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.tasker.textTertiary)
                        .opacity(textOpacity)
                }
            }
            .onAppear { performAnimation() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Milestone reached! \(milestone.name) at \(milestone.xpThreshold) XP")
            .accessibilityAddTraits(.isModal)
        }
    }

    private func performAnimation() {
        let reduceMotion = UIAccessibility.isReduceMotionEnabled

        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .spring(
            response: GamificationTokens.SpringConfig.levelUp.response,
            dampingFraction: GamificationTokens.SpringConfig.levelUp.dampingFraction
        )) {
            overlayOpacity = 1.0
            iconScale = reduceMotion ? 1.0 : 1.2
        }

        if !reduceMotion {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) {
                iconScale = 1.0
            }
        }

        withAnimation(.easeInOut(duration: 0.5).delay(0.3)) {
            textOpacity = 1.0
        }

        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            glowOpacity = 1.0
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let second = UINotificationFeedbackGenerator()
            second.notificationOccurred(.success)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + GamificationTokens.milestoneDuration) {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            overlayOpacity = 0
            iconScale = 0
            textOpacity = 0
            glowOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }
}
