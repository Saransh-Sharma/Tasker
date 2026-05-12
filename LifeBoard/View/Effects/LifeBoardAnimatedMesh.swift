import SwiftUI

struct LifeBoardAnimatedMesh: View {
    let role: LifeBoardMeshRole
    var intensity: LifeBoardMeshIntensity = LifeBoardMeshTuning.defaultIntensity
    var isAnimating: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @State private var animatedPhase = false
    @State private var hueShifted = false

    var body: some View {
        let spec = LifeBoardMeshSpec.make(role: role, intensity: intensity)
        let shouldAnimate = isAnimating && !reduceMotion

        mesh(spec: spec, phase: shouldAnimate ? animatedPhase : false)
            .hueRotation(.degrees(shouldAnimate
                                  ? (hueShifted ? spec.hueRotation : -spec.hueRotation * 0.22)
                                  : 0))
            .opacity(reduceTransparency ? spec.reduceTransparencyOpacity : spec.opacity)
            .blendMode(spec.blendMode)
            .overlay {
                if reduceTransparency {
                    Color.lifeboard(.bgCanvas).opacity(spec.reduceTransparencyOpacity * 0.72)
                }
            }
            .onAppear {
                guard shouldAnimate else { return }
                withAnimation(spec.animation) {
                    animatedPhase = true
                }
                withAnimation(.easeInOut(duration: spec.hueRotationDuration).repeatForever(autoreverses: true)) {
                    hueShifted = true
                }
            }
            .onChange(of: shouldAnimate) { _, newValue in
                guard newValue else {
                    animatedPhase = false
                    hueShifted = false
                    return
                }
                withAnimation(spec.animation) {
                    animatedPhase = true
                }
                withAnimation(.easeInOut(duration: spec.hueRotationDuration).repeatForever(autoreverses: true)) {
                    hueShifted = true
                }
            }
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func mesh(spec: LifeBoardMeshSpec, phase: Bool) -> some View {
        if #available(iOS 18.0, *) {
            MeshGradient(
                width: spec.width,
                height: spec.height,
                points: phase ? spec.activePoints : spec.idlePoints,
                colors: phase ? spec.activeColors : spec.idleColors
            )
        } else {
            LinearGradient(
                colors: [Color.lifeboard(.accentPrimary), Color.lifeboard(.accentSecondary)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
