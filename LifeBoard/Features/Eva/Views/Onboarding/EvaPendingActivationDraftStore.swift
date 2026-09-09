import Foundation

/// Local draft only. A restored draft never restores authorization to send it.
enum EvaPendingActivationDraftStore {
    private static func key(_ threadID: UUID?) -> String { "eva.activation.draft.\(threadID?.uuidString ?? "new")" }
    static func save(_ text: String, threadID: UUID?, defaults: UserDefaults = .standard) {
        defaults.set(text, forKey: key(threadID))
    }
    static func load(threadID: UUID?, defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: key(threadID))
    }
    static func clear(threadID: UUID?, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(threadID))
    }
}
