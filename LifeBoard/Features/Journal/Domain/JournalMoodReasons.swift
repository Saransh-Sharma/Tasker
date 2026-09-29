import Foundation

/// Why a mood was what it was, stored on the mood block's existing `text`
/// column as a namespaced, parseable string (`reasons:work,sleep`) so no
/// schema changes. Unknown tokens survive a round trip; plain text is left
/// alone. Never counted as AI evidence unless the day permits it.
enum JournalMoodReasons {
    static let prefix = "reasons:"

    struct Reason: Identifiable, Equatable, Hashable {
        let id: String
        let title: String
        let systemImage: String
    }

    static let catalog: [Reason] = [
        Reason(id: "work", title: "Work", systemImage: "briefcase"),
        Reason(id: "sleep", title: "Sleep", systemImage: "bed.double"),
        Reason(id: "people", title: "People", systemImage: "person.2"),
        Reason(id: "health", title: "Health", systemImage: "heart"),
        Reason(id: "money", title: "Money", systemImage: "creditcard"),
        Reason(id: "weather", title: "Weather", systemImage: "cloud.sun"),
        Reason(id: "food", title: "Food", systemImage: "fork.knife"),
        Reason(id: "movement", title: "Movement", systemImage: "figure.walk"),
        Reason(id: "rest", title: "Rest", systemImage: "leaf"),
        Reason(id: "news", title: "News", systemImage: "newspaper"),
    ]

    static func reason(id: String) -> Reason? {
        catalog.first { $0.id == id }
    }

    /// `["work","sleep"]` → `"reasons:work,sleep"`; empty → `nil`.
    static func encode(_ ids: [String]) -> String? {
        let cleaned = ids.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.isEmpty == false }
        var seen: Set<String> = []
        let unique = cleaned.filter { seen.insert($0).inserted }
        return unique.isEmpty ? nil : prefix + unique.joined(separator: ",")
    }

    /// The ids in an encoded string, or `nil` for plain text (which stays a
    /// caption, not a list of reasons).
    static func decode(_ text: String?) -> [String]? {
        guard let text, text.hasPrefix(prefix) else { return nil }
        let body = text.dropFirst(prefix.count)
        let ids = body.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { $0.isEmpty == false }
        return ids
    }

    static func isEncoded(_ text: String?) -> Bool {
        decode(text) != nil
    }

    /// "Work, sleep" for a card chip row; unknown tokens are shown as typed.
    static func titles(for ids: [String]) -> [String] {
        ids.map { reason(id: $0)?.title ?? $0.capitalized }
    }
}
