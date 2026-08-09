import Foundation

// The resolved motion budget: what the device, the accessibility settings
// and the comfort profile between them allow right now. A pure value type
// with no feature or flag dependency, read by every animated primitive, so
// it belongs with the tokens rather than inside the shader file.
public struct MotionPolicy: Equatable, Sendable {
    public let allowsCustomShaders: Bool
    public let allowsIdleMotion: Bool
    public let allowsSpatialMotion: Bool
    public let allowsHaptics: Bool
    public let usesOpaqueSurfaces: Bool
    public let transitionDuration: TimeInterval
    public let springDamping: Double
    public let comfortProfile: ComfortProfile
    public let isFocusedPresentation: Bool

    public static func resolve(
        reduceMotion: Bool,
        reduceTransparency: Bool,
        lowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled,
        thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState,
        sceneIsActive: Bool,
        supportsCustomShaders: Bool = true,
        isCatalyst: Bool = ProcessInfo.processInfo.isMacCatalystApp,
        comfortProfile: ComfortProfile = .balanced,
        isFocusedPresentation: Bool = false
    ) -> MotionPolicy {
        let thermallyConstrained = thermalState == .serious || thermalState == .critical
        let energyConstrained = lowPowerMode || thermallyConstrained
        let allowsSpatialMotion = sceneIsActive && reduceMotion == false && energyConstrained == false
        let allowsIdleMotion = allowsSpatialMotion
            && isFocusedPresentation == false
            && comfortProfile != .calm
        let allowsShaders = allowsSpatialMotion
            && reduceTransparency == false
            && supportsCustomShaders
            && isCatalyst == false
            && isFocusedPresentation == false
            && comfortProfile != .calm
        return MotionPolicy(
            allowsCustomShaders: allowsShaders,
            allowsIdleMotion: allowsIdleMotion,
            allowsSpatialMotion: allowsSpatialMotion,
            allowsHaptics: sceneIsActive && isCatalyst == false,
            usesOpaqueSurfaces: reduceTransparency,
            transitionDuration: reduceMotion ? 0 : (energyConstrained ? 0.12 : 0.28),
            springDamping: reduceMotion ? 1 : (comfortProfile == .playful ? 0.78 : 0.86),
            comfortProfile: comfortProfile,
            isFocusedPresentation: isFocusedPresentation
        )
    }
}
