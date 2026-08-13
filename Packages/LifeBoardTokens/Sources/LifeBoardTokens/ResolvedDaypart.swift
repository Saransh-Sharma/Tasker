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

    public var greeting: String {
        switch self {
        case .morning: return "Good morning!"
        case .afternoon: return "Good afternoon!"
        case .evening: return "Good evening!"
        case .night: return "Good night!"
        }
    }
}
