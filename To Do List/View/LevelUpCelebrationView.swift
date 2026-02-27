import SwiftUI

/// Full-screen overlay for level-up celebrations.
public struct LevelUpCelebrationView: View {

    let level: Int
    @Binding var isPresented: Bool

    @State private var badgeScale: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var overlayOpacity: Double = 0

    public var body: some View {
        if isPresented {
            ZStack {
                Color.tasker.bgCanvas
                    .opacity(overlayOpacity * 0.85)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: 16) {
                    Text("\(level)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(Color.tasker.accentPrimary)
                        .scaleEffect(badgeScale)

                    Text("Level \(level)")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.tasker.accentPrimary)
                        .opacity(textOpacity)

                    Text("Keep building momentum")
                        .font(.tasker(.body))
                        .foregroundColor(Color.tasker.textSecondary)
                        .opacity(textOpacity)
                }
            }
            .onAppear { performAnimation() }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Level up! You reached level \(level)")
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
            badgeScale = reduceMotion ? 1.0 : 1.2
        }

        if !reduceMotion {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.15)) {
                badgeScale = 1.0
            }
        }

        withAnimation(.easeInOut(duration: 0.4).delay(0.3)) {
            textOpacity = 1.0
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + GamificationTokens.levelUpDuration) {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            overlayOpacity = 0
            badgeScale = 0
            textOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isPresented = false
        }
    }
}
