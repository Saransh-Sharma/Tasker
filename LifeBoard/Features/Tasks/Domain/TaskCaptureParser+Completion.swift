import Foundation

/// Suggestions for the `#tag`, `+project`, and `@context` being typed.
///
/// Pure and caret-free: the composer types at the end of the draft, so the
/// token under completion is the trailing run after its sigil. Names are
/// inserted in the parser's own grammar (a letter, then letters, digits, `_`,
/// or `-`), with spaces written as hyphens, so what autocomplete writes is
/// always something `TaskCaptureParser` reads back.
public enum CaptureTokenCompletion {
    public enum Kind: Equatable, Sendable {
        case tag, project, context

        public var sigil: Character {
            switch self {
            case .tag: "#"
            case .project: "+"
            case .context: "@"
            }
        }
    }

    public struct ActiveToken: Equatable, Sendable {
        public let kind: Kind
        /// What has been typed after the sigil; may be empty right after it.
        public let prefix: String
    }

    public struct Suggestion: Equatable, Hashable, Sendable {
        public let name: String
        public let isNew: Bool
    }

    public static func activeToken(in text: String) -> ActiveToken? {
        guard let last = text.last, last.isWhitespace == false else { return nil }
        let trailing = text.reversed().prefix { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let prefix = String(trailing.reversed())
        let sigilIndex = text.index(text.endIndex, offsetBy: -(prefix.count + 1), limitedBy: text.startIndex)
        guard let sigilIndex else { return nil }
        let kind: Kind
        switch text[sigilIndex] {
        case "#": kind = .tag
        case "+": kind = .project
        case "@": kind = .context
        default: return nil
        }
        // A sigil glued to a word ("C#", "a+b") is not a token.
        if sigilIndex > text.startIndex {
            let before = text[text.index(before: sigilIndex)]
            guard before.isWhitespace else { return nil }
        }
        // Tokens start with a letter; "@3pm" is a time, not a context.
        if let first = prefix.first, first.isLetter == false { return nil }
        return ActiveToken(kind: kind, prefix: prefix)
    }

    /// Prefix matches first, then other substring matches, at most `limit`.
    /// Offers to create a new tag when nothing matches what was typed;
    /// projects and contexts must already exist.
    public static func suggestions(for token: ActiveToken, candidates: [String], limit: Int = 5) -> [Suggestion] {
        let query = normalized(token.prefix)
        var seen: Set<String> = []
        let unique = candidates.filter { seen.insert(normalized($0)).inserted }
        let prefixed = unique.filter { query.isEmpty || normalized($0).hasPrefix(query) }
        let contained = query.isEmpty ? [] : unique.filter {
            normalized($0).contains(query) && normalized($0).hasPrefix(query) == false
        }
        var result = (prefixed.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending } + contained)
            .prefix(limit)
            .map { Suggestion(name: $0, isNew: false) }
        if token.kind == .tag, query.isEmpty == false,
           unique.contains(where: { normalized($0) == query }) == false,
           result.count < limit {
            result.append(Suggestion(name: token.prefix, isNew: true))
        }
        return result
    }

    /// The draft with `kind`'s sigil added where the completion row reads it.
    ///
    /// `activeToken(in:)` only looks at the end of the draft and needs the
    /// sigil to start a word, so the sigil goes at the end, after a space when
    /// the draft doesn't already end in one.
    public static func insertingSigil(_ kind: Kind, into text: String) -> String {
        let separator = text.isEmpty || text.last?.isWhitespace == true ? "" : " "
        return text + separator + String(kind.sigil)
    }

    /// Replaces the trailing token with the chosen name and a space.
    public static func apply(_ name: String, kind: Kind, to text: String) -> String {
        guard let token = activeToken(in: text), token.kind == kind else { return text }
        let base = text.dropLast(token.prefix.count + 1)
        return "\(base)\(kind.sigil)\(tokenText(name)) "
    }

    public static func tokenText(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: "-")
    }

    /// Case, spacing, and hyphens ignored: "+side-project" is "Side Project".
    public static func normalized(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
