import SwiftUI

struct EvaChatSunriseBackground: View {
    var isStreaming: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var drift = false
    @State private var driftTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            LifeBoardScenicBackdrop(
                scene: .secondary,
                daypart: LifeBoardDaypartResolver.resolve(selection: .automatic),
                requestedTier: .ambient2D,
                comfortProfile: .balanced,
                showsSun: false
            )

            LinearGradient(
                colors: [
                    EvaChatSunriseGlass.canvasTop.opacity(0.72),
                    EvaChatSunriseGlass.gold.opacity(0.10),
                    .clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            .offset(y: drift ? 8 : -6)
            .opacity(drift ? 0.82 : 1)

            LinearGradient(
                colors: [
                    .clear,
                    EvaChatSunriseGlass.canvasBottom.opacity(0.70)
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
        .onChange(of: scenePhase) { _, _ in updateDrift() }
        .onDisappear { driftTask?.cancel() }
    }

    private var motionEnabled: Bool {
        LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion) == false
            && isStreaming == false
            && scenePhase == .active
    }

    private func updateDrift() {
        driftTask?.cancel()
        guard motionEnabled else {
            withAnimation(nil) { drift = false }
            return
        }
        withAnimation(LifeBoardAnimation.ambient) {
            drift = true
        }
        driftTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard Task.isCancelled == false else { return }
            withAnimation(LifeBoardAnimation.ambient) { drift = false }
        }
    }
}
