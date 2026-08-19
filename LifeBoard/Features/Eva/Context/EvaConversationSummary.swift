import Foundation

/// A rolling summary of the turns that no longer fit in the live window.
///
/// The offline path drops old turns at an 8-message cliff and loses them — the
/// recap mechanism that would have covered it is disabled in every strategy.
/// Cloud has room for far more history, but "far more" is still finite, and
/// paying full price for a long thread on every turn is wasteful when the older
/// half rarely changes.
///
/// So: keep recent turns verbatim, and carry everything older as one summary
/// that only has to be regenerated when the window advances. It rides in its own
/// context section rather than being spliced into the message list, which keeps
/// it clearly labelled as a summary rather than as something the person said.
struct EvaConversationSummary: Encodable, Equatable, Sendable {
    let summarizedTurnCount: Int
    let summary: String

    static let maxSummaryCharacters = 4_000
    /// Below this there is nothing worth compressing — the turns still fit.
    static let minimumTurnsToSummarize = 12

    init?(summarizedTurnCount: Int, summary: String) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard summarizedTurnCount > 0, trimmed.isEmpty == false else { return nil }
        self.summarizedTurnCount = summarizedTurnCount
        self.summary = String(trimmed.prefix(Self.maxSummaryCharacters))
    }

    /// The turns that fall outside the live window and therefore need covering.
    static func overflow(_ messages: [Message], liveWindow: Int) -> [Message] {
        guard messages.count > liveWindow, messages.count >= minimumTurnsToSummarize else { return [] }
        return Array(messages.prefix(messages.count - liveWindow))
    }

    func section() -> EvaCloudContextSection {
        .init(category: .conversationSummary, payload: .encoding(self))
    }
}
