import Foundation
import LifeBoardDomain
import LifeBoardUI
import SwiftUI

extension KnowledgeNoteEditor {
    func commandButton(
        _ label: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .minimumHitTarget()
        }
        .accessibilityLabel(label)
    }

    func aiProposalLines(_ value: String) -> [String] {
        value
            .split(whereSeparator: \.isNewline)
            .map {
                String($0)
                    .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-•0123456789.[]")))
            }
            .filter { !$0.isEmpty }
    }

    func aiActionTitle(_ action: NoteAIAction) -> String {
        switch action {
        case .summarize: "Summarize"
        case .cleanUp: "Clean up writing"
        case .continueWriting: "Continue writing"
        case .extractTasks: "Extract checklists"
        case .suggestTags: "Suggest tags"
        case .suggestLinks: "Suggest links"
        }
    }

    func aiActionSymbol(_ action: NoteAIAction) -> String {
        switch action {
        case .summarize: "text.badge.star"
        case .cleanUp: "wand.and.sparkles"
        case .continueWriting: "text.append"
        case .extractTasks: "checklist"
        case .suggestTags: "tag"
        case .suggestLinks: "link"
        }
    }

    func kindTitle(_ kind: KnowledgeBlockKind) -> String {
        kind.displayTitle
    }

    func kindSymbol(_ kind: KnowledgeBlockKind) -> String {
        switch kind {
        case .paragraph: "text.alignleft"
        case .heading1, .heading2: "textformat.size"
        case .bulletedList: "list.bullet"
        case .numberedList: "list.number"
        case .checklist: "checklist"
        case .quote: "quote.opening"
        case .callout: "exclamationmark.bubble"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .divider: "minus"
        case .table: "tablecells"
        case .collapsible: "chevron.down.square"
        case .image: "photo"
        case .file: "doc"
        case .bookmark: "bookmark"
        case .noteLink: "link"
        }
    }
}

extension KnowledgeBlockKind {
    /// The block type as a person reads it. Raw values are storage keys
    /// ("bulletedList", "noteLink") and read as "Bulletedlist" capitalised.
    var displayTitle: String {
        switch self {
        case .paragraph: "Text"
        case .heading1: "Heading 1"
        case .heading2: "Heading 2"
        case .bulletedList: "Bulleted list"
        case .numberedList: "Numbered list"
        case .checklist: "Checklist"
        case .quote: "Quote"
        case .callout: "Callout"
        case .code: "Code"
        case .divider: "Divider"
        case .table: "Table"
        case .collapsible: "Collapsible section"
        case .image: "Image"
        case .file: "File"
        case .bookmark: "Bookmark"
        case .noteLink: "Note link"
        }
    }
}
