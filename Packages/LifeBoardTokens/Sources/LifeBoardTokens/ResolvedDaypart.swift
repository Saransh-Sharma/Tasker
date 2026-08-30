import Foundation

// The daypart the app has settled on, after the user's atmosphere choice
// and the clock are both taken into account. `DaypartPalette` is
// keyed on it, so it has to sit at the same level as the palette rather
// than in the app's contracts file.
public enum ResolvedDaypart: String, Codable, CaseIterable, Hashable, Sendable {
    case morning
    case afternoon
    case evening
    case night

    /// Where the light is coming from, in degrees, for the specular rim on
    /// raised clay.
    ///
    /// `DESIGN.md` requires the lit edge to be "angled to the current daypart";
    /// without this every surface in the product is lit from a fixed ten
    /// o'clock at dawn and at dusk alike. The values trace a sun arc across the
    /// composition — low from one side in the morning, high through the
    /// afternoon, low from the other side at dusk — and settle overhead at
    /// night, where the light is a moon rather than a sun and has no side.
    ///
    /// Degrees rather than `Angle` so this stays free of a SwiftUI import;
    /// `LifeBoardUI` converts at the point of use.
    public var specularLightAngleDegrees: Double {
        switch self {
        case .morning: return -150
        case .afternoon: return -60
        case .evening: return -20
        case .night: return -90
        }
    }

    public var greeting: String {
        switch self {
        case .morning: return "Good morning!"
        case .afternoon: return "Good afternoon!"
        case .evening: return "Good evening!"
        case .night: return "Good night!"
        }
    }
}
