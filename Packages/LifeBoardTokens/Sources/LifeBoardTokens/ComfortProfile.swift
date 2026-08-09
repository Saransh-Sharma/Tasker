import Foundation

// How much motion and ornament the person has asked for. Read by every
// animated primitive, so it sits with the tokens rather than in the app's
// contracts file.
public enum ComfortProfile: String, Codable, CaseIterable, Hashable, Sendable {
    case calm
    case balanced
    case playful

    public var title: String { rawValue.capitalized }
}
