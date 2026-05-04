import SwiftUI

extension View {
    func taskerMeshBackground(
        _ role: TaskerMeshRole,
        intensity: TaskerMeshIntensity = TaskerMeshTuning.defaultIntensity,
        isAnimating: Bool = true
    ) -> some View {
        background {
            TaskerAnimatedMesh(role: role, intensity: intensity, isAnimating: isAnimating)
        }
    }

    func taskerMeshCardOverlay(
        _ role: TaskerMeshRole,
        cornerRadius: CGFloat,
        intensity: TaskerMeshIntensity = TaskerMeshTuning.defaultIntensity,
        isAnimating: Bool = true
    ) -> some View {
        overlay {
            TaskerAnimatedMesh(role: role, intensity: intensity, isAnimating: isAnimating)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    func taskerMeshCTA(
        _ role: TaskerMeshRole,
        cornerRadius: CGFloat,
        intensity: TaskerMeshIntensity = TaskerMeshTuning.defaultIntensity,
        isAnimating: Bool = true
    ) -> some View {
        background {
            TaskerAnimatedMesh(role: role, intensity: intensity, isAnimating: isAnimating)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    func taskerMeshCTA(
        _ role: TaskerMeshRole,
        intensity: TaskerMeshIntensity = TaskerMeshTuning.defaultIntensity,
        isAnimating: Bool = true
    ) -> some View {
        background {
            TaskerAnimatedMesh(role: role, intensity: intensity, isAnimating: isAnimating)
                .clipShape(Capsule(style: .continuous))
        }
    }
}
