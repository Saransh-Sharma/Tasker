import LifeBoardTokens
import SwiftUI

/// The daypart the clay material is lit by.
///
/// `DESIGN.md` says the specular rim is "angled to the current daypart".
/// `SpecularRimModifier` has always taken a `lightAngle`, but nothing ever
/// passed one, so every raised surface in the product was lit from the same
/// fixed direction all day.
///
/// This carries the daypart down to `ClaySurfaceModifier`, which resolves the
/// angle and hands it to the rim. It is optional with a `nil` default on
/// purpose: a subtree nobody has injected into keeps the rim's own neutral
/// angle rather than being forced to claim a time of day it does not know.
private struct ClayLightDaypartKey: EnvironmentKey {
    static let defaultValue: ResolvedDaypart? = nil
}

public extension EnvironmentValues {
    var lifeBoardClayLightDaypart: ResolvedDaypart? {
        get { self[ClayLightDaypartKey.self] }
        set { self[ClayLightDaypartKey.self] = newValue }
    }
}

public extension View {
    /// Light every clay surface in this subtree from the given daypart.
    ///
    /// Apply once, at the shell root, alongside the atmosphere. Applying it per
    /// card would be harmless but pointless — the whole screen shares one sun.
    func lifeBoardClayLight(_ daypart: ResolvedDaypart?) -> some View {
        environment(\.lifeBoardClayLightDaypart, daypart)
    }
}
