import Foundation

public enum JournalMood: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case none, angry, sad, anxious, tired, calm, grateful, happy, excited

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    public static let dialOrder: [JournalMood] = [
        .angry, .sad, .anxious, .tired, .none, .calm, .grateful, .happy, .excited
    ]
}
