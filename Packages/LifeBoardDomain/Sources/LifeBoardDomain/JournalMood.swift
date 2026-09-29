import Foundation

public enum JournalMood: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case none, angry, sad, anxious, tired, calm, grateful, happy, excited

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    /// The name a person sees. `.none` is the middle of the dial — a neutral
    /// mood, not an absence — so it reads "Neutral" rather than "None".
    public var displayName: String {
        switch self {
        case .none: String(localized: "Neutral")
        case .angry: String(localized: "Angry")
        case .sad: String(localized: "Sad")
        case .anxious: String(localized: "Anxious")
        case .tired: String(localized: "Tired")
        case .calm: String(localized: "Calm")
        case .grateful: String(localized: "Grateful")
        case .happy: String(localized: "Happy")
        case .excited: String(localized: "Excited")
        }
    }

    public static let dialOrder: [JournalMood] = [
        .angry, .sad, .anxious, .tired, .none, .calm, .grateful, .happy, .excited
    ]
}
