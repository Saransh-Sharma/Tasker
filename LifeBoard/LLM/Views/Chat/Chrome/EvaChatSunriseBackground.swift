import SwiftUI

struct EvaChatSunriseBackground: View {
    var isStreaming: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        ZStack {
            EvaChatSunriseGlass.background

            LinearGradient(
                colors: [
                    EvaChatSunriseGlass.gold.opacity(0.12),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .offset(y: drift ? 8 : -6)
            .opacity(drift ? 0.82 : 1)

            LinearGradient(
                colors: [
                    .clear,
                    EvaChatSunriseGlass.primary.opacity(0.05)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .offset(x: drift ? -10 : 8)
            .opacity(drift ? 1 : 0.78)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear(perform: updateDrift)
        .onChange(of: isStreaming) { _, _ in updateDrift() }
        .onChange(of: reduceMotion) { _, _ in updateDrift() }
    }

    private var motionEnabled: Bool {
        LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false && isStreaming == false
    }

    private func updateDrift() {
        guard motionEnabled else {
            drift = false
            return
        }
        withAnimation(LifeBoardAnimation.ambient.repeatForever(autoreverses: true)) {
            drift = true
        }
    }
}
