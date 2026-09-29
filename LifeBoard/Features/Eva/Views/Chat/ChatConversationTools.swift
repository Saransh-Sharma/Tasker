import Foundation
import Observation

/// The standard chat verbs, as pure functions over plain values so they can
/// be tested without SwiftData: which messages an edit-and-resend removes,
/// how search finds a line across chats, and what an exported chat reads as.
struct ChatMessageSnapshot: Equatable, Identifiable, Sendable {
    enum Role: String, Sendable { case user, assistant, system }
    let id: UUID
    let threadID: UUID
    let role: Role
    let content: String
    let timestamp: Date
}

/// Editing a user message replaces it and everything after it in the thread.
/// The removed tail is returned so a receipt can offer Undo for a while.
enum ChatEditResendPolicy {
    struct Plan: Equatable {
        let editedID: UUID
        /// The edited message and every later one, oldest first.
        let removed: [ChatMessageSnapshot]
        /// Messages that stay, oldest first.
        let kept: [ChatMessageSnapshot]
    }

    static func plan(thread messages: [ChatMessageSnapshot], editedID: UUID) -> Plan? {
        let ordered = messages.sorted { $0.timestamp < $1.timestamp }
        guard let index = ordered.firstIndex(where: { $0.id == editedID }), ordered[index].role == .user else { return nil }
        return Plan(editedID: editedID, removed: Array(ordered[index...]), kept: Array(ordered[..<index]))
    }
}

/// Case-insensitive search across every chat, with a ±40 character snippet.
enum ChatSearchIndex {
    struct Hit: Equatable, Identifiable {
        let threadID: UUID
        let messageID: UUID
        let role: ChatMessageSnapshot.Role
        let timestamp: Date
        let snippet: String
        var id: UUID { messageID }
    }

    static let snippetRadius = 40

    static func search(_ query: String, in messages: [ChatMessageSnapshot], limit: Int = 50) -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return [] }
        var hits: [Hit] = []
        for message in messages.sorted(by: { $0.timestamp > $1.timestamp }) {
            guard let range = message.content.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) else { continue }
            hits.append(Hit(
                threadID: message.threadID,
                messageID: message.id,
                role: message.role,
                timestamp: message.timestamp,
                snippet: snippet(of: message.content, around: range)
            ))
            if hits.count >= limit { break }
        }
        return hits
    }

    static func snippet(of text: String, around range: Range<String.Index>) -> String {
        let start = text.index(range.lowerBound, offsetBy: -snippetRadius, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: snippetRadius, limitedBy: text.endIndex) ?? text.endIndex
        var piece = String(text[start..<end]).replacingOccurrences(of: "\n", with: " ")
        if start > text.startIndex { piece = "…" + piece }
        if end < text.endIndex { piece += "…" }
        return piece
    }
}

/// The query, in bold, inside a search snippet.
enum ChatSearchHighlight {
    static func attributed(_ snippet: String, query: String) -> AttributedString {
        var attributed = AttributedString(snippet)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return attributed }
        var searchStart = attributed.startIndex
        while searchStart < attributed.endIndex,
              let range = attributed[searchStart...].range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[range].inlinePresentationIntent = .stronglyEmphasized
            searchStart = range.upperBound
        }
        return attributed
    }
}

/// The message a thread should open at, set by a search hit and consumed once
/// by the conversation. Opening from search used to land at the bottom of the
/// thread, leaving the person to find the match themselves.
@MainActor
@Observable
final class EvaChatScrollTarget {
    static let shared = EvaChatScrollTarget()
    var messageID: UUID?

    /// Returns the pending target once and clears it.
    func consume() -> UUID? {
        defer { messageID = nil }
        return messageID
    }
}

/// A chat as Markdown, for sharing. Plain text only; no model names, no
/// context receipts, nothing the person did not see in the transcript.
enum ChatTranscriptExporter {
    static func markdown(title: String?, messages: [ChatMessageSnapshot], now: Date = Date()) -> String {
        var lines: [String] = []
        lines.append("# \(title?.isEmpty == false ? title! : "Chat with Eva")")
        lines.append("")
        lines.append("_Exported \(now.formatted(date: .abbreviated, time: .shortened))_")
        lines.append("")
        for message in messages.sorted(by: { $0.timestamp < $1.timestamp }) where message.role != .system {
            let speaker = message.role == .user ? "You" : "Eva"
            lines.append("**\(speaker)** · \(message.timestamp.formatted(date: .omitted, time: .shortened))")
            lines.append("")
            lines.append(message.content.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
