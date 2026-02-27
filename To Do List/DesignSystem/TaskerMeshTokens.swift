import SwiftUI

public enum TaskerMeshRole {
    case homeBackdrop
    case chatBackdrop
    case ctaPrimary
    case cardSubtle
}

public enum TaskerMeshIntensity: CaseIterable {
    case subtle
    case balanced
    case vivid
}

public enum TaskerMeshTuning {
    // Single global knob to tune mesh motion intensity post-testing.
    public static var defaultIntensity: TaskerMeshIntensity = .vivid
}

public struct TaskerMeshSpec {
    public let width: Int
    public let height: Int
    public let idlePoints: [SIMD2<Float>]
    public let activePoints: [SIMD2<Float>]
    public let idleColors: [Color]
    public let activeColors: [Color]
    public let animation: Animation
    public let opacity: Double
    public let hueRotation: Double
    public let hueRotationDuration: Double
    public let blendMode: BlendMode
    public let reduceTransparencyOpacity: Double

    /// Initializes a new instance.
    public init(
        width: Int,
        height: Int,
        idlePoints: [SIMD2<Float>],
        activePoints: [SIMD2<Float>],
        idleColors: [Color],
        activeColors: [Color],
        animation: Animation,
        opacity: Double,
        hueRotation: Double,
        hueRotationDuration: Double,
        blendMode: BlendMode,
        reduceTransparencyOpacity: Double
    ) {
        self.width = width
        self.height = height
        self.idlePoints = idlePoints
        self.activePoints = activePoints
        self.idleColors = idleColors
        self.activeColors = activeColors
        self.animation = animation
        self.opacity = opacity
        self.hueRotation = hueRotation
        self.hueRotationDuration = hueRotationDuration
        self.blendMode = blendMode
        self.reduceTransparencyOpacity = reduceTransparencyOpacity
    }

    @MainActor
    public static func make(role: TaskerMeshRole, intensity: TaskerMeshIntensity) -> TaskerMeshSpec {
        let width = 3
        let height = 3

        let profile: MotionProfile
        switch intensity {
        case .subtle:
            profile = MotionProfile(
                backdropDuration: 12.0,
                ctaDuration: 6.0,
                cardDuration: 10.0,
                displacementScale: 0.35,
                opacityBoost: 0.0,
                hueRotation: 10,
                hueDuration: 8.5
            )
        case .balanced:
            profile = MotionProfile(
                backdropDuration: 8.0,
                ctaDuration: 4.5,
                cardDuration: 8.0,
                displacementScale: 0.65,
                opacityBoost: 0.06,
                hueRotation: 16,
                hueDuration: 6.0
            )
        case .vivid:
            profile = MotionProfile(
                backdropDuration: 6.0,
                ctaDuration: 3.4,
                cardDuration: 7.0,
                displacementScale: 1.0,
                opacityBoost: 0.12,
                hueRotation: 22,
                hueDuration: 4.2
            )
        }

        let basePoints: [SIMD2<Float>] = [
            SIMD2<Float>(0.00, 0.00), SIMD2<Float>(0.50, 0.00), SIMD2<Float>(1.00, 0.00),
            SIMD2<Float>(0.00, 0.50), SIMD2<Float>(0.50, 0.50), SIMD2<Float>(1.00, 0.50),
            SIMD2<Float>(0.00, 1.00), SIMD2<Float>(0.50, 1.00), SIMD2<Float>(1.00, 1.00),
        ]

        func displaced(_ points: [SIMD2<Float>], _ factor: Float) -> [SIMD2<Float>] {
            let deltas: [SIMD2<Float>] = [
                SIMD2<Float>( 0.03,  0.02), SIMD2<Float>( 0.10, -0.08), SIMD2<Float>( 0.04,  0.06),
                SIMD2<Float>(-0.05,  0.08), SIMD2<Float>(-0.06, -0.05), SIMD2<Float>( 0.09, -0.07),
                SIMD2<Float>( 0.04,  0.03), SIMD2<Float>( 0.07, -0.09), SIMD2<Float>(-0.02,  0.05),
            ]

            return zip(points, deltas).map { point, delta in
                SIMD2<Float>(point.x + (delta.x * factor), point.y + (delta.y * factor))
            }
        }

        let accentPrimary = Color.tasker(.accentPrimary)
        let accentSecondary = Color.tasker(.accentSecondary)
        let accentMuted = Color.tasker(.accentMuted)
        let accentWash = Color.tasker(.accentWash)
        let statusWarning = Color.tasker(.statusWarning)
        let statusSuccess = Color.tasker(.statusSuccess)
        let statusDanger = Color.tasker(.statusDanger)
        let canvas = Color.tasker(.bgCanvas)

        switch role {
        case .homeBackdrop:
            return TaskerMeshSpec(
                width: width,
                height: height,
                idlePoints: basePoints,
                activePoints: displaced(basePoints, 1.0 * profile.displacementScale),
                idleColors: [
                    accentPrimary.opacity(0.96), accentSecondary.opacity(0.84), accentWash.opacity(0.78),
                    statusWarning.opacity(0.60), accentMuted.opacity(0.72), statusSuccess.opacity(0.56),
                    accentWash.opacity(0.60), accentSecondary.opacity(0.70), canvas.opacity(0.90),
                ],
                activeColors: [
                    accentSecondary.opacity(0.92), statusDanger.opacity(0.50), accentWash.opacity(0.72),
                    accentPrimary.opacity(0.90), statusWarning.opacity(0.56), accentMuted.opacity(0.74),
                    statusSuccess.opacity(0.52), accentPrimary.opacity(0.80), canvas.opacity(0.88),
                ],
                animation: .easeInOut(duration: profile.backdropDuration).repeatForever(autoreverses: true),
                opacity: min(1.0, 0.62 + profile.opacityBoost),
                hueRotation: profile.hueRotation * 0.85,
                hueRotationDuration: profile.hueDuration,
                blendMode: .normal,
                reduceTransparencyOpacity: 0.18
            )

        case .chatBackdrop:
            return TaskerMeshSpec(
                width: width,
                height: height,
                idlePoints: basePoints,
                activePoints: displaced(basePoints, 0.85 * profile.displacementScale),
                idleColors: [
                    accentSecondary.opacity(0.84), accentPrimary.opacity(0.78), accentWash.opacity(0.70),
                    accentMuted.opacity(0.64), canvas.opacity(0.90), statusSuccess.opacity(0.42),
                    accentWash.opacity(0.62), statusWarning.opacity(0.44), canvas.opacity(0.94),
                ],
                activeColors: [
                    accentPrimary.opacity(0.82), accentSecondary.opacity(0.86), statusWarning.opacity(0.44),
                    accentMuted.opacity(0.66), canvas.opacity(0.92), accentWash.opacity(0.68),
                    statusSuccess.opacity(0.46), accentSecondary.opacity(0.72), canvas.opacity(0.96),
                ],
                animation: .easeInOut(duration: profile.backdropDuration * 1.05).repeatForever(autoreverses: true),
                opacity: min(1.0, 0.54 + profile.opacityBoost),
                hueRotation: profile.hueRotation * 0.70,
                hueRotationDuration: profile.hueDuration * 1.1,
                blendMode: .normal,
                reduceTransparencyOpacity: 0.16
            )

        case .ctaPrimary:
            return TaskerMeshSpec(
                width: width,
                height: height,
                idlePoints: basePoints,
                activePoints: displaced(basePoints, 1.25 * profile.displacementScale),
                idleColors: [
                    accentPrimary.opacity(1.00), statusWarning.opacity(0.80), accentSecondary.opacity(0.88),
                    accentSecondary.opacity(0.94), accentPrimary.opacity(0.98), statusSuccess.opacity(0.66),
                    accentPrimary.opacity(0.94), statusDanger.opacity(0.54), accentSecondary.opacity(0.86),
                ],
                activeColors: [
                    accentSecondary.opacity(0.96), accentPrimary.opacity(1.00), statusWarning.opacity(0.70),
                    statusSuccess.opacity(0.70), accentSecondary.opacity(0.95), accentPrimary.opacity(0.94),
                    statusDanger.opacity(0.60), accentPrimary.opacity(0.96), accentSecondary.opacity(0.94),
                ],
                animation: .easeInOut(duration: profile.ctaDuration).repeatForever(autoreverses: true),
                opacity: min(1.0, 0.90 + profile.opacityBoost),
                hueRotation: profile.hueRotation,
                hueRotationDuration: profile.hueDuration * 0.75,
                blendMode: .plusLighter,
                reduceTransparencyOpacity: 0.28
            )

        case .cardSubtle:
            return TaskerMeshSpec(
                width: width,
                height: height,
                idlePoints: basePoints,
                activePoints: displaced(basePoints, 0.55 * profile.displacementScale),
                idleColors: [
                    accentWash.opacity(0.48), accentMuted.opacity(0.42), canvas.opacity(0.96),
                    accentSecondary.opacity(0.36), canvas.opacity(0.98), accentPrimary.opacity(0.30),
                    canvas.opacity(0.96), accentWash.opacity(0.42), canvas.opacity(0.98),
                ],
                activeColors: [
                    accentMuted.opacity(0.46), accentWash.opacity(0.45), canvas.opacity(0.97),
                    accentPrimary.opacity(0.34), canvas.opacity(0.98), accentSecondary.opacity(0.34),
                    canvas.opacity(0.98), accentWash.opacity(0.40), canvas.opacity(0.99),
                ],
                animation: .easeInOut(duration: profile.cardDuration).repeatForever(autoreverses: true),
                opacity: min(1.0, 0.46 + (profile.opacityBoost * 0.65)),
                hueRotation: profile.hueRotation * 0.55,
                hueRotationDuration: profile.hueDuration * 1.2,
                blendMode: .normal,
                reduceTransparencyOpacity: 0.14
            )
        }
    }
}

private struct MotionProfile {
    let backdropDuration: Double
    let ctaDuration: Double
    let cardDuration: Double
    let displacementScale: Float
    let opacityBoost: Double
    let hueRotation: Double
    let hueDuration: Double
}
