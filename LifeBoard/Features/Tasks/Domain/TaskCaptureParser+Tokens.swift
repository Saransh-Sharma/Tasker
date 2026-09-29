import Foundation

extension TaskCaptureParser {
    // MARK: - Explicit tokens (#tag, +project, @context)

    struct TokenMatch {
        let value: String
        let range: Range<String.Index>
    }

    struct TokenMatches {
        var tags: [TokenMatch] = []
        var project: TokenMatch?
        var context: TokenMatch?

        var all: [TokenMatch] { tags + [project, context].compactMap { $0 } }

        /// De-duplicated case-insensitively, first spelling wins. Someone who
        /// writes "#Work ... #work" meant one tag.
        var tagValues: [String] {
            var seen: Set<String> = []
            return tags.compactMap { seen.insert($0.value.lowercased()).inserted ? $0.value : nil }
        }
    }

    /// Every token must begin with a letter.
    ///
    /// This is what keeps `@home` and `@3pm` apart: the time matchers accept a
    /// leading `@` before digits, so a context pattern that allowed digits would
    /// race them for the same substring and win, turning "call mom @3pm" into a
    /// task with a context named "3pm" and no time. Requiring a letter makes the
    /// two grammars disjoint by construction rather than by pass ordering.
    static func tokenMatches(in text: String) -> TokenMatches {
        var result = TokenMatches()
        result.tags = allMatches(#"(?<![\w])#([A-Za-z][\w-]*)"#, in: text)
        result.project = allMatches(#"(?<![\w])\+([A-Za-z][\w-]*)"#, in: text).first
        result.context = allMatches(#"(?<![\w])@([A-Za-z][\w-]*)"#, in: text).first
        return result
    }

    /// All non-overlapping matches, returning capture group 1 as the value and
    /// the whole match as the range to strip.
    private static func allMatches(_ pattern: String, in text: String) -> [TokenMatch] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
            guard let full = Range(match.range, in: text),
                  match.numberOfRanges > 1,
                  let value = Range(match.range(at: 1), in: text) else { return nil }
            return TokenMatch(value: String(text[value]), range: full)
        }
    }
}

/// One recognized piece of capture text, in the order it was written. The
/// composer shows each as a chip the person can remove to take the words back.
public struct CaptureTokenPiece: Equatable, Hashable, Sendable {
    public enum Kind: String, Equatable, Hashable, Sendable {
        case date, time, duration, repeatPattern, priority, project, tag, context
    }

    public let kind: Kind
    /// Exactly as typed, e.g. "fri", "3pm", "#health".
    public let text: String
    /// UTF-16 range in the original untrimmed input.
    public var sourceRange: NSRange? = nil
}
