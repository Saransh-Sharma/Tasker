import Foundation

// Persisted in user settings and referenced by `NotificationServiceProtocol`, so
// it outlives the view that rendered it. It was declared inside EvaMediaView.
public enum AssistantMascotID: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case eva
    case cloudlet
    case dude
    case elon
    case friday
    case johnny
    case maddie
    case paperclip
    case punch
    case retriever
    case sato
    case steve
    case theo
    case yesman

    public var id: String { rawValue }
}
