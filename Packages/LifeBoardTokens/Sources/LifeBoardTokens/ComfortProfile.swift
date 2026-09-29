import Foundation

// How much motion and ornament the person has asked for. Read by every
// animated primitive, so it sits with the tokens rather than in the app's
// contracts file.
public enum ComfortProfile: String, Codable, CaseIterable, Hashable, Sendable {
    case calm
    case balanced
    case playful

    /// Display name. Matches the Look & feel motion option labels in
    /// Settings; the raw values stay the persisted keys.
    public var title: String {
        switch self {
        case .calm: String(localized: "Subtle")
        case .balanced: String(localized: "Balanced")
        case .playful: String(localized: "Playful")
        }
    }
}
