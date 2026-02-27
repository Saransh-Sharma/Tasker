import SwiftUI

/// Reusable cover-style 3D flip for swapping two surfaces.
struct CoverFlipTransition: AnimatableModifier {
    var progress: Double
    var isInsertion: Bool
    var blurStrength: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let angle = isInsertion ? (180 - 180 * progress) : (0 - 180 * progress)
        let normalized = min(abs(angle) / 90, 1)
        let blur = CGFloat(normalized) * blurStrength

        return content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .blur(radius: blur)
            .opacity(abs(angle) > 90 ? 0 : 1)
    }
}

extension AnyTransition {
    static func coverFlip(blurStrength: CGFloat = 3.5) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: CoverFlipTransition(progress: 0, isInsertion: true, blurStrength: blurStrength),
                identity: CoverFlipTransition(progress: 1, isInsertion: true, blurStrength: blurStrength)
            ),
            removal: .modifier(
                active: CoverFlipTransition(progress: 1, isInsertion: false, blurStrength: blurStrength),
                identity: CoverFlipTransition(progress: 0, isInsertion: false, blurStrength: blurStrength)
            )
        )
    }
}
