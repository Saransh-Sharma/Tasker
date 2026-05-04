import SwiftUI

extension View {
    func lifeboardMeshBackground(
        _ role: LifeBoardMeshRole,
        intensity: LifeBoardMeshIntensity = LifeBoardMeshTuning.defaultIntensity,
        isAnimating: Bool = true
    ) -> some View {
        background {
            LifeBoardAnimatedMesh(role: role, intensity: intensity, isAnimating: isAnimating)
        }
    }

    func lifeboardMeshCardOverlay(
        _ role: LifeBoardMeshRole,
        cornerRadius: CGFloat,
        intensity: LifeBoardMeshIntensity = LifeBoardMeshTuning.defaultIntensity,
        isAnimating: Bool = true
    ) -> some View {
        overlay {
            LifeBoardAnimatedMesh(role: role, intensity: intensity, isAnimating: isAnimating)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    func lifeboardMeshCTA(
        _ role: LifeBoardMeshRole,
        cornerRadius: CGFloat,
        intensity: LifeBoardMeshIntensity = LifeBoardMeshTuning.defaultIntensity,
        isAnimating: Bool = true
    ) -> some View {
        background {
            LifeBoardAnimatedMesh(role: role, intensity: intensity, isAnimating: isAnimating)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    func lifeboardMeshCTA(
        _ role: LifeBoardMeshRole,
        intensity: LifeBoardMeshIntensity = LifeBoardMeshTuning.defaultIntensity,
        isAnimating: Bool = true
    ) -> some View {
        background {
            LifeBoardAnimatedMesh(role: role, intensity: intensity, isAnimating: isAnimating)
                .clipShape(Capsule(style: .continuous))
        }
    }
}
