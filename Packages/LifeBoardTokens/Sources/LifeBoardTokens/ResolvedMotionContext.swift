import Foundation

/// A diagnostic-friendly snapshot of every gate that can change presentation.
/// Feature code should derive animation decisions from this value instead of
/// branching on raw accessibility state independently.
public struct ResolvedMotionContext: Equatable, Sendable {
    public let fullMotionEnabled: Bool
    public let effectiveReduceMotion: Bool
    public let reduceTransparency: Bool
    public let comfortProfile: ComfortProfile
    public let requestedAmbientTierID: String
    public let sceneIsActive: Bool
    public let lowPowerMode: Bool
    public let thermalState: ProcessInfo.ThermalState

    public var isEnergyConstrained: Bool {
        lowPowerMode || thermalState == .serious || thermalState == .critical
    }

    public var allowsSpatialMotion: Bool {
        sceneIsActive && effectiveReduceMotion == false && isEnergyConstrained == false
    }

    public static func resolve(
        systemReduceMotion: Bool,
        reduceTransparency: Bool,
        comfortProfile: ComfortProfile,
        requestedAmbientTierID: String,
        sceneIsActive: Bool,
        lowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    ) -> Self {
        Self(
            fullMotionEnabled: MotionOverride.fullMotionEnabled,
            effectiveReduceMotion: MotionOverride.resolve(systemReduceMotion),
            reduceTransparency: reduceTransparency,
            comfortProfile: comfortProfile,
            requestedAmbientTierID: requestedAmbientTierID,
            sceneIsActive: sceneIsActive,
            lowPowerMode: lowPowerMode,
            thermalState: thermalState
        )
    }
}
