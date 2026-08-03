import CryptoKit
import Foundation
import JournalSecurityKit
import Observation
import Security
import SQLite3
import SwiftUI
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Editor and mutation contracts

public enum NoteMutation: Hashable, Sendable {
    case replaceText(blockID: UUID, range: NSRange, original: String, replacement: String)
    case insertBlock(LifeBoardKnowledgeBlockValue, at: Int)
    case deleteBlock(LifeBoardKnowledgeBlockValue, at: Int)
    case moveBlock(id: UUID, from: Int, to: Int)
    case changeBlockKind(id: UUID, from: LifeBoardKnowledgeBlockKind, to: LifeBoardKnowledgeBlockKind)
    case setChecklist(id: UUID, isChecked: Bool)
    case setIndent(id: UUID, level: Int)
    case setCollapsed(id: UUID, isCollapsed: Bool)
    case setTitle(from: String, to: String)
    case replaceNote(before: LifeBoardKnowledgeNoteValue, after: LifeBoardKnowledgeNoteValue)

    public func inverse() -> NoteMutation {
        switch self {
        case let .replaceText(blockID, range, original, replacement):
            return .replaceText(
                blockID: blockID,
                range: NSRange(location: range.location, length: replacement.utf16.count),
                original: replacement,
                replacement: original
            )
        case let .insertBlock(block, index): return .deleteBlock(block, at: index)
        case let .deleteBlock(block, index): return .insertBlock(block, at: index)
        case let .moveBlock(id, from, to): return .moveBlock(id: id, from: to, to: from)
        case let .changeBlockKind(id, from, to): return .changeBlockKind(id: id, from: to, to: from)
        case let .setChecklist(id, checked): return .setChecklist(id: id, isChecked: !checked)
        case let .setIndent(id, level): return .setIndent(id: id, level: max(0, level - 1))
        case let .setCollapsed(id, collapsed): return .setCollapsed(id: id, isCollapsed: !collapsed)
        case let .setTitle(from, to): return .setTitle(from: to, to: from)
        case let .replaceNote(before, after): return .replaceNote(before: after, after: before)
        }
    }
}

public struct NoteMutationReceipt: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var mutation: NoteMutation
    public var inverse: NoteMutation
    public var createdAt: Date

    public init(id: UUID = UUID(), mutation: NoteMutation, inverse: NoteMutation? = nil, createdAt: Date = Date()) {
        self.id = id
        self.mutation = mutation
        self.inverse = inverse ?? mutation.inverse()
        self.createdAt = createdAt
    }
}

public enum NoteEditorSaveState: Equatable, Sendable {
    case idle
    case saving
    case saved(Date)
    case conflicted
    case failed(String)
}

public struct KnowledgeBlockRange: Hashable, Sendable {
    public var blockID: UUID
    public var range: NSRange

    public init(blockID: UUID, range: NSRange) {
        self.blockID = blockID
        self.range = range
    }
}

public struct KnowledgeNoteDocument: @unchecked Sendable {
    public static let blockIDKey = NSAttributedString.Key("com.lifeboard.notes.block-id")
    public static let blockKindKey = NSAttributedString.Key("com.lifeboard.notes.block-kind")
    public static let blockIndentKey = NSAttributedString.Key("com.lifeboard.notes.block-indent")
    public static let blockCheckedKey = NSAttributedString.Key("com.lifeboard.notes.block-checked")
    public static let blockCollapsedKey = NSAttributedString.Key("com.lifeboard.notes.block-collapsed")

    public var attributedString: NSAttributedString
    public var ranges: [KnowledgeBlockRange]

    public init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
        ranges = []
    }

    public init(note: LifeBoardKnowledgeNoteValue, traitCollection: UITraitCollection = .current) {
        let output = NSMutableAttributedString(string: "")
        var blockRanges: [KnowledgeBlockRange] = []
        for (index, block) in note.blocks.sorted(by: { $0.ordinal < $1.ordinal }).enumerated() {
            let start = output.length
            let renderedText = Self.renderedText(for: block)
            let paragraph = NSMutableAttributedString(
                string: renderedText,
                attributes: Self.baseAttributes(for: block, traitCollection: traitCollection)
            )
            Self.applyRichText(block.richTextData, to: paragraph)
            paragraph.addAttributes(
                [
                    Self.blockIDKey: block.id.uuidString,
                    Self.blockKindKey: block.kind.rawValue,
                    Self.blockIndentKey: block.indentLevel ?? 0,
                    Self.blockCheckedKey: block.isChecked,
                    Self.blockCollapsedKey: block.isCollapsed ?? false
                ],
                range: NSRange(location: 0, length: paragraph.length)
            )
            output.append(paragraph)
            let length = paragraph.length
            blockRanges.append(.init(blockID: block.id, range: NSRange(location: start, length: length)))
            if index < note.blocks.count - 1 { output.append(NSAttributedString(string: "\n")) }
        }
        if output.length == 0 {
            output.append(NSAttributedString(string: "", attributes: Self.baseAttributes(for: .init(noteID: note.id), traitCollection: traitCollection)))
        }
        attributedString = output
        ranges = blockRanges
    }

    public func blocks(noteID: UUID, previous: [LifeBoardKnowledgeBlockValue]) -> [LifeBoardKnowledgeBlockValue] {
        let source = attributedString.string as NSString
        let byID = Dictionary(uniqueKeysWithValues: previous.map { ($0.id, $0) })
        var values: [LifeBoardKnowledgeBlockValue] = []
        var consumedIDs = Set<UUID>()
        let paragraphs = source.paragraphRange(for: NSRange(location: 0, length: source.length))
        var cursor = paragraphs.location
        var ordinal = 0
        while cursor < NSMaxRange(paragraphs) || (source.length == 0 && values.isEmpty) {
            let range = source.paragraphRange(for: NSRange(location: min(cursor, source.length), length: 0))
            let safeLength = max(0, min(range.length, source.length - range.location))
            let contentRange = NSRange(location: range.location, length: safeLength)
            let attributes: [NSAttributedString.Key: Any]
            if attributedString.length > 0 {
                attributes = attributedString.attributes(
                    at: min(contentRange.location, attributedString.length - 1),
                    effectiveRange: nil
                )
            } else {
                attributes = [:]
            }
            let existingID = (attributes[Self.blockIDKey] as? String).flatMap(UUID.init(uuidString:))
            let candidateID = existingID ?? UUID()
            let id = consumedIDs.insert(candidateID).inserted ? candidateID : UUID()
            var value = byID[id] ?? LifeBoardKnowledgeBlockValue(id: id, noteID: noteID)
            let raw = attributes[Self.blockKindKey] as? String
            value.kind = raw.flatMap(LifeBoardKnowledgeBlockKind.init(rawValue:)) ?? value.kind
            var text = source.substring(with: contentRange)
            if text.hasSuffix("\n") { text.removeLast() }
            text = Self.plainText(fromRenderedText: text, kind: value.kind)
            value.text = text
            value.ordinal = ordinal
            value.indentLevel = attributes[Self.blockIndentKey] as? Int
            value.isChecked = attributes[Self.blockCheckedKey] as? Bool ?? value.isChecked
            value.isCollapsed = attributes[Self.blockCollapsedKey] as? Bool
            value.richTextData = Self.richTextPayload(in: contentRange, attributedString: attributedString, kind: value.kind)
            value.updatedAt = Date()
            if value.createdAt == nil { value.createdAt = Date() }
            values.append(value)
            ordinal += 1
            guard source.length > 0 else { break }
            cursor = NSMaxRange(range)
        }
        return values.isEmpty ? [.init(noteID: noteID)] : values
    }

    public static func split(
        block: LifeBoardKnowledgeBlockValue,
        atUTF16Offset offset: Int
    ) -> (leading: LifeBoardKnowledgeBlockValue, trailing: LifeBoardKnowledgeBlockValue) {
        let text = block.text as NSString
        let safe = min(max(0, offset), text.length)
        var leading = block
        leading.text = text.substring(to: safe)
        leading.updatedAt = Date()
        var trailing = block
        trailing.id = UUID()
        trailing.text = text.substring(from: safe)
        trailing.ordinal = block.ordinal + 1
        trailing.createdAt = Date()
        trailing.updatedAt = Date()
        return (leading, trailing)
    }

    public static func merge(
        leading: LifeBoardKnowledgeBlockValue,
        trailing: LifeBoardKnowledgeBlockValue
    ) -> LifeBoardKnowledgeBlockValue {
        var merged = leading
        merged.text += trailing.text
        merged.updatedAt = Date()
        return merged
    }

    private static func renderedText(for block: LifeBoardKnowledgeBlockValue) -> String {
        switch block.kind {
        case .checklist: return "\(block.isChecked ? "☑︎" : "☐") \(block.text)"
        case .bulletedList: return "• \(block.text)"
        case .numberedList: return "\(block.ordinal + 1). \(block.text)"
        case .quote: return "“\(block.text)"
        case .divider: return "────────"
        default: return block.text
        }
    }

    private static func plainText(fromRenderedText text: String, kind: LifeBoardKnowledgeBlockKind) -> String {
        switch kind {
        case .checklist: return text.replacingOccurrences(of: #"^(☑︎|☐)\s?"#, with: "", options: .regularExpression)
        case .bulletedList: return text.replacingOccurrences(of: #"^•\s?"#, with: "", options: .regularExpression)
        case .numberedList: return text.replacingOccurrences(of: #"^\d+\.\s?"#, with: "", options: .regularExpression)
        case .quote: return text.hasPrefix("“") ? String(text.dropFirst()) : text
        case .divider: return ""
        default: return text
        }
    }

    static func baseAttributesForEditor(
        block: LifeBoardKnowledgeBlockValue,
        traitCollection: UITraitCollection = .current
    ) -> [NSAttributedString.Key: Any] {
        baseAttributes(for: block, traitCollection: traitCollection)
    }

    private static func baseAttributes(
        for block: LifeBoardKnowledgeBlockValue,
        traitCollection: UITraitCollection
    ) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.paragraphSpacing = block.kind == .heading1 ? 12 : 7
        style.lineSpacing = block.kind == .code ? 3 : 5
        style.firstLineHeadIndent = CGFloat(max(0, block.indentLevel ?? 0)) * 22
        style.headIndent = style.firstLineHeadIndent
        let font: UIFont
        switch block.kind {
        case .heading1: font = .preferredFont(forTextStyle: .largeTitle).withWeight(.bold)
        case .heading2: font = .preferredFont(forTextStyle: .title2).withWeight(.semibold)
        case .code: font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        default: font = .preferredFont(forTextStyle: .body)
        }
        return [.font: font, .foregroundColor: UIColor.label, .paragraphStyle: style]
    }

    private static func applyRichText(_ data: Data?, to value: NSMutableAttributedString) {
        guard let data,
              let payload = try? JSONDecoder().decode(KnowledgeRichTextPayload.self, from: data),
              payload.unsupportedVersion == nil else { return }
        for run in payload.runs {
            let range = NSIntersectionRange(NSRange(location: run.location, length: run.length), NSRange(location: 0, length: value.length))
            guard range.length > 0 else { continue }
            if run.marks.contains(.bold) { value.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body).withWeight(.bold), range: range) }
            if run.marks.contains(.italic) { value.addAttribute(.obliqueness, value: 0.18, range: range) }
            if run.marks.contains(.underline) { value.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
            if run.marks.contains(.strikethrough) { value.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
            if run.marks.contains(.highlight) { value.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.26), range: range) }
            if run.marks.contains(.inlineCode) { value.addAttribute(.font, value: UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular), range: range) }
            if let link = run.link { value.addAttribute(.link, value: link, range: range) }
        }
    }

    private static func richTextPayload(
        in range: NSRange,
        attributedString: NSAttributedString,
        kind: LifeBoardKnowledgeBlockKind
    ) -> Data? {
        var runs: [KnowledgeRichTextPayload.Run] = []
        attributedString.enumerateAttributes(in: range) { attributes, effective, _ in
            var marks = Set<KnowledgeRichTextPayload.Mark>()
            if let font = attributes[.font] as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) { marks.insert(.bold) }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { marks.insert(.italic) }
                if font.fontName.lowercased().contains("mono") { marks.insert(.inlineCode) }
            }
            if attributes[.underlineStyle] != nil { marks.insert(.underline) }
            if attributes[.strikethroughStyle] != nil { marks.insert(.strikethrough) }
            if attributes[.backgroundColor] != nil { marks.insert(.highlight) }
            let link = attributes[.link] as? URL
            guard !marks.isEmpty || link != nil else { return }
            runs.append(.init(location: effective.location - range.location, length: effective.length, marks: marks, link: link))
        }
        let paragraph: KnowledgeRichTextPayload.ParagraphSemantic = switch kind {
        case .heading1: .heading1
        case .heading2: .heading2
        case .quote: .quote
        case .code: .code
        case .callout: .callout
        default: .body
        }
        return try? JSONEncoder().encode(KnowledgeRichTextPayload(runs: runs, paragraph: paragraph))
    }
}

public enum KnowledgeEditorCommand: Hashable, Sendable {
    case bold
    case italic
    case underline
    case strikethrough
    case highlight
    case inlineCode
    case block(LifeBoardKnowledgeBlockKind)
    case insertBlock(LifeBoardKnowledgeBlockKind)
    case indent(Int)
    case insertWikiLink(noteID: UUID, title: String)
}

public struct KnowledgeEditorCommandInvocation: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var command: KnowledgeEditorCommand

    public init(id: UUID = UUID(), command: KnowledgeEditorCommand) {
        self.id = id
        self.command = command
    }
}

public struct LifeBoardUnifiedNoteEditor: UIViewRepresentable {
    @Binding private var note: LifeBoardKnowledgeNoteValue
    @Binding private var selection: NSRange
    @Binding private var isFocused: Bool
    private var command: KnowledgeEditorCommandInvocation?
    private var onSlashCommand: () -> Void
    private var onWikiLink: (String) -> Void

    public init(
        note: Binding<LifeBoardKnowledgeNoteValue>,
        selection: Binding<NSRange>,
        isFocused: Binding<Bool>,
        command: KnowledgeEditorCommandInvocation?,
        onSlashCommand: @escaping () -> Void,
        onWikiLink: @escaping (String) -> Void
    ) {
        _note = note
        _selection = selection
        _isFocused = isFocused
        self.command = command
        self.onSlashCommand = onSlashCommand
        self.onWikiLink = onWikiLink
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: true)
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 80, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.keyboardDismissMode = .interactive
        view.allowsEditingTextAttributes = true
        view.smartDashesType = .yes
        view.smartQuotesType = .yes
        view.smartInsertDeleteType = .yes
        view.accessibilityIdentifier = "notes.editor.richText"
        view.accessibilityLabel = "Note body"
        view.linkTextAttributes = [.foregroundColor: UIColor.systemOrange, .underlineStyle: NSUnderlineStyle.single.rawValue]
        let document = KnowledgeNoteDocument(note: note, traitCollection: view.traitCollection)
        view.attributedText = document.attributedString
        context.coordinator.lastRenderedNote = note
        return view
    }

    public func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.lastRenderedNote != note, !context.coordinator.isApplyingTextChange {
            let selected = view.selectedRange
            view.attributedText = KnowledgeNoteDocument(note: note, traitCollection: view.traitCollection).attributedString
            view.selectedRange = NSIntersectionRange(selected, NSRange(location: 0, length: view.attributedText.length))
            context.coordinator.lastRenderedNote = note
        }
        if isFocused, !view.isFirstResponder { view.becomeFirstResponder() }
        if !isFocused, view.isFirstResponder { view.resignFirstResponder() }
        if let command, context.coordinator.lastCommandID != command.id {
            context.coordinator.lastCommandID = command.id
            context.coordinator.apply(command.command, to: view)
        }
    }

    public static func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? 680
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(220, size.height))
    }

    public final class Coordinator: NSObject, UITextViewDelegate {
        var parent: LifeBoardUnifiedNoteEditor
        var lastRenderedNote: LifeBoardKnowledgeNoteValue?
        var lastCommandID: UUID?
        var isApplyingTextChange = false

        init(parent: LifeBoardUnifiedNoteEditor) {
            self.parent = parent
        }

        public func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        public func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }

        public func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selection = textView.selectedRange
        }

        public func textViewDidChange(_ textView: UITextView) {
            isApplyingTextChange = true
            var changed = parent.note
            changed.blocks = KnowledgeNoteDocument(attributedString: textView.attributedText)
                .blocks(noteID: changed.id, previous: changed.blocks)
            changed.updatedAt = Date()
            changed.contentVersion = max(1, changed.contentVersion ?? 1) + 1
            lastRenderedNote = changed
            parent.note = changed
            normalizeBlockAttributes(in: textView, blocks: changed.blocks)
            detectCommands(in: textView)
            isApplyingTextChange = false
        }

        public func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            guard text == " " else { return true }
            let source = textView.text as NSString
            let paragraph = source.paragraphRange(for: NSRange(location: range.location, length: 0))
            let prefixRange = NSRange(location: paragraph.location, length: max(0, range.location - paragraph.location))
            let prefix = source.substring(with: prefixRange)
            let kind: LifeBoardKnowledgeBlockKind?
            switch prefix {
            case "#": kind = .heading1
            case "##": kind = .heading2
            case "-", "*": kind = .bulletedList
            case "1.": kind = .numberedList
            case ">", "“": kind = .quote
            case "```": kind = .code
            case "[]", "[ ]", "- [ ]": kind = .checklist
            default: kind = nil
            }
            guard let kind else { return true }
            textView.textStorage.deleteCharacters(in: prefixRange)
            textView.selectedRange = NSRange(location: paragraph.location, length: 0)
            apply(.block(kind), to: textView)
            textViewDidChange(textView)
            return false
        }

        func apply(_ command: KnowledgeEditorCommand, to textView: UITextView) {
            let selection = textView.selectedRange
            let textLength = textView.textStorage.length
            let safeSelection = NSIntersectionRange(selection, NSRange(location: 0, length: textLength))
            switch command {
            case .bold:
                toggleFontTrait(.traitBold, textView: textView, range: safeSelection)
            case .italic:
                toggleFontTrait(.traitItalic, textView: textView, range: safeSelection)
            case .underline:
                toggleAttribute(.underlineStyle, enabledValue: NSUnderlineStyle.single.rawValue, textView: textView, range: safeSelection)
            case .strikethrough:
                toggleAttribute(.strikethroughStyle, enabledValue: NSUnderlineStyle.single.rawValue, textView: textView, range: safeSelection)
            case .highlight:
                toggleAttribute(.backgroundColor, enabledValue: UIColor.systemYellow.withAlphaComponent(0.28), textView: textView, range: safeSelection)
            case .inlineCode:
                textView.textStorage.addAttribute(
                    .font,
                    value: UIFont.monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular),
                    range: effectiveRange(safeSelection, in: textView)
                )
            case let .block(kind):
                let paragraph = (textView.text as NSString).paragraphRange(for: NSRange(location: safeSelection.location, length: safeSelection.length))
                textView.textStorage.addAttribute(KnowledgeNoteDocument.blockKindKey, value: kind.rawValue, range: paragraph)
                let block = LifeBoardKnowledgeBlockValue(noteID: parent.note.id, kind: kind)
                for (key, value) in KnowledgeNoteDocument.baseAttributesForEditor(block: block) {
                    textView.textStorage.addAttribute(key, value: value, range: paragraph)
                }
            case let .insertBlock(kind):
                let insertion = safeSelection.location
                let prefix = insertion > 0 && (textView.text as NSString).substring(with: NSRange(location: insertion - 1, length: 1)) == "\n" ? "" : "\n"
                textView.textStorage.replaceCharacters(in: safeSelection, with: prefix)
                let location = min(textView.textStorage.length, insertion + prefix.utf16.count)
                let paragraph = (textView.text as NSString).paragraphRange(for: NSRange(location: location, length: 0))
                if paragraph.length > 0 {
                    textView.textStorage.addAttributes(
                        [
                            KnowledgeNoteDocument.blockIDKey: UUID().uuidString,
                            KnowledgeNoteDocument.blockKindKey: kind.rawValue,
                            KnowledgeNoteDocument.blockIndentKey: 0,
                            KnowledgeNoteDocument.blockCheckedKey: false,
                            KnowledgeNoteDocument.blockCollapsedKey: false
                        ],
                        range: paragraph
                    )
                } else {
                    var attributes = textView.typingAttributes
                    attributes[KnowledgeNoteDocument.blockIDKey] = UUID().uuidString
                    attributes[KnowledgeNoteDocument.blockKindKey] = kind.rawValue
                    textView.typingAttributes = attributes
                }
                textView.selectedRange = NSRange(location: location, length: 0)
            case let .indent(delta):
                let paragraph = (textView.text as NSString).paragraphRange(for: safeSelection)
                let current = textView.textStorage.attribute(KnowledgeNoteDocument.blockIndentKey, at: min(paragraph.location, max(0, textLength - 1)), effectiveRange: nil) as? Int ?? 0
                let next = max(0, current + delta)
                textView.textStorage.addAttribute(KnowledgeNoteDocument.blockIndentKey, value: next, range: paragraph)
                let style = (textView.textStorage.attribute(.paragraphStyle, at: min(paragraph.location, max(0, textLength - 1)), effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
                style.firstLineHeadIndent = CGFloat(next) * 22
                style.headIndent = style.firstLineHeadIndent
                textView.textStorage.addAttribute(.paragraphStyle, value: style, range: paragraph)
            case let .insertWikiLink(noteID, title):
                let token = NSAttributedString(
                    string: title,
                    attributes: [
                        .foregroundColor: UIColor.systemOrange,
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .link: URL(string: "lifeboard://note/\(noteID.uuidString)")!
                    ]
                )
                textView.textStorage.replaceCharacters(in: safeSelection, with: token)
                textView.selectedRange = NSRange(location: safeSelection.location + token.length, length: 0)
            }
            textViewDidChange(textView)
        }

        private func normalizeBlockAttributes(in textView: UITextView, blocks: [LifeBoardKnowledgeBlockValue]) {
            let source = textView.text as NSString
            var cursor = 0
            for block in blocks where cursor <= source.length {
                let range = source.paragraphRange(for: NSRange(location: min(cursor, source.length), length: 0))
                let safe = NSIntersectionRange(range, NSRange(location: 0, length: textView.textStorage.length))
                guard safe.location <= textView.textStorage.length else { break }
                if safe.length > 0 {
                    textView.textStorage.addAttributes(
                        [
                            KnowledgeNoteDocument.blockIDKey: block.id.uuidString,
                            KnowledgeNoteDocument.blockKindKey: block.kind.rawValue,
                            KnowledgeNoteDocument.blockIndentKey: block.indentLevel ?? 0,
                            KnowledgeNoteDocument.blockCheckedKey: block.isChecked,
                            KnowledgeNoteDocument.blockCollapsedKey: block.isCollapsed ?? false
                        ],
                        range: safe
                    )
                }
                cursor = NSMaxRange(range)
                if source.length == 0 { break }
            }
        }

        private func detectCommands(in textView: UITextView) {
            let source = textView.text as NSString
            let caret = min(textView.selectedRange.location, source.length)
            let paragraph = source.paragraphRange(for: NSRange(location: caret, length: 0))
            let prefixLength = max(0, caret - paragraph.location)
            let prefix = source.substring(with: NSRange(location: paragraph.location, length: prefixLength))
            if prefix == "/" { parent.onSlashCommand() }
            if let marker = prefix.range(of: "[[", options: .backwards) {
                let queryStart = marker.upperBound
                let query = String(prefix[queryStart...])
                if !query.contains("]]") { parent.onWikiLink(query) }
            }
        }

        private func effectiveRange(_ selection: NSRange, in textView: UITextView) -> NSRange {
            if selection.length > 0 { return selection }
            return (textView.text as NSString).paragraphRange(for: selection)
        }

        private func toggleFontTrait(
            _ trait: UIFontDescriptor.SymbolicTraits,
            textView: UITextView,
            range: NSRange
        ) {
            let target = effectiveRange(range, in: textView)
            guard textView.textStorage.length > 0, target.length > 0 else {
                var attributes = textView.typingAttributes
                let font = attributes[.font] as? UIFont ?? .preferredFont(forTextStyle: .body)
                var traits = font.fontDescriptor.symbolicTraits
                if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
                let descriptor = font.fontDescriptor.withSymbolicTraits(traits) ?? font.fontDescriptor
                attributes[.font] = UIFont(descriptor: descriptor, size: font.pointSize)
                textView.typingAttributes = attributes
                return
            }
            let font = textView.textStorage.attribute(.font, at: min(target.location, max(0, textView.textStorage.length - 1)), effectiveRange: nil) as? UIFont ?? .preferredFont(forTextStyle: .body)
            var traits = font.fontDescriptor.symbolicTraits
            if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits) ?? font.fontDescriptor
            textView.textStorage.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: target)
        }

        private func toggleAttribute(
            _ key: NSAttributedString.Key,
            enabledValue: Any,
            textView: UITextView,
            range: NSRange
        ) {
            let target = effectiveRange(range, in: textView)
            guard textView.textStorage.length > 0, target.length > 0 else {
                var attributes = textView.typingAttributes
                if attributes[key] == nil { attributes[key] = enabledValue } else { attributes.removeValue(forKey: key) }
                textView.typingAttributes = attributes
                return
            }
            if textView.textStorage.attribute(key, at: min(target.location, max(0, textView.textStorage.length - 1)), effectiveRange: nil) == nil {
                textView.textStorage.addAttribute(key, value: enabledValue, range: target)
            } else {
                textView.textStorage.removeAttribute(key, range: target)
            }
        }
    }
}

@MainActor
@Observable
public final class NoteEditorSession {
    public let id = UUID()
    public private(set) var note: LifeBoardKnowledgeNoteValue
    public private(set) var saveState: NoteEditorSaveState = .idle
    public var selection = NSRange(location: 0, length: 0)
    public var isFocused = false
    public var isReadingMode = false
    public let undoManager = UndoManager()

    private let repository: any LifeBoardPhaseIIRepository
    private var baseline: LifeBoardKnowledgeNoteValue
    private var autosaveTask: Task<Void, Never>?
    private var checkpointTask: Task<Void, Never>?
    private var didCreateOpeningRevision = false
    private let sceneID: String

    public init(
        note: LifeBoardKnowledgeNoteValue,
        repository: any LifeBoardPhaseIIRepository,
        sceneID: String = UUID().uuidString
    ) {
        self.note = note
        baseline = note
        self.repository = repository
        self.sceneID = sceneID
        checkpointTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard let self else { return }
                guard self.note != self.baseline else { continue }
                await self.checkpoint(reason: "Editing checkpoint", kind: "checkpoint")
            }
        }
    }

    public func replaceDocument(_ document: KnowledgeNoteDocument) {
        note.blocks = document.blocks(noteID: note.id, previous: note.blocks)
        note.updatedAt = Date()
        note.contentVersion = max(1, note.contentVersion ?? 1) + 1
        scheduleAutosave()
    }

    public func setTitle(_ title: String) {
        let previous = note.title
        guard previous != title else { return }
        note.title = title
        note.updatedAt = Date()
        undoManager.registerUndo(withTarget: self) { target in target.setTitle(previous) }
        scheduleAutosave()
    }

    public func apply(_ mutation: NoteMutation, registerUndo: Bool = true) {
        let before = note
        switch mutation {
        case let .insertBlock(block, index):
            note.blocks.insert(block, at: min(max(0, index), note.blocks.count))
        case let .deleteBlock(block, _):
            note.blocks.removeAll { $0.id == block.id }
        case let .moveBlock(id, _, to):
            guard let source = note.blocks.firstIndex(where: { $0.id == id }) else { return }
            let value = note.blocks.remove(at: source)
            note.blocks.insert(value, at: min(max(0, to), note.blocks.count))
        case let .changeBlockKind(id, _, to):
            if let index = note.blocks.firstIndex(where: { $0.id == id }) { note.blocks[index].kind = to }
        case let .setChecklist(id, checked):
            if let index = note.blocks.firstIndex(where: { $0.id == id }) { note.blocks[index].isChecked = checked }
        case let .setIndent(id, level):
            if let index = note.blocks.firstIndex(where: { $0.id == id }) { note.blocks[index].indentLevel = max(0, level) }
        case let .setCollapsed(id, collapsed):
            if let index = note.blocks.firstIndex(where: { $0.id == id }) { note.blocks[index].isCollapsed = collapsed }
        case let .setTitle(_, to): note.title = to
        case let .replaceNote(_, after): note = after
        case let .replaceText(blockID, range, _, replacement):
            guard let index = note.blocks.firstIndex(where: { $0.id == blockID }) else { return }
            let text = NSMutableString(string: note.blocks[index].text)
            guard NSMaxRange(range) <= text.length else { return }
            text.replaceCharacters(in: range, with: replacement)
            note.blocks[index].text = text as String
        }
        for index in note.blocks.indices { note.blocks[index].ordinal = index }
        note.updatedAt = Date()
        note.contentVersion = max(1, note.contentVersion ?? 1) + 1
        if registerUndo {
            undoManager.registerUndo(withTarget: self) { target in
                target.apply(.replaceNote(before: target.note, after: before))
            }
        }
        scheduleAutosave()
    }

    public func recoverDraftIfNewer() async -> LifeBoardKnowledgeNoteValue? {
        guard let draft = try? await repository.fetchKnowledgeDraft(noteID: note.id),
              draft.updatedAt > note.updatedAt,
              (draft.baseContentVersion ?? 0) >= (note.contentVersion ?? 0),
              let recovered = try? JSONDecoder().decode(LifeBoardKnowledgeNoteValue.self, from: draft.snapshot) else {
            return nil
        }
        return recovered
    }

    public func restoreRecoveredDraft(_ recovered: LifeBoardKnowledgeNoteValue) {
        note = recovered
        scheduleAutosave()
    }

    public func discardRecoveredDraft() async {
        try? await repository.deleteKnowledgeDraft(noteID: note.id)
    }

    public func flush() async {
        autosaveTask?.cancel()
        await persist(note)
    }

    public func close() async {
        autosaveTask?.cancel()
        if note.isMeaningful || baseline.isMeaningful {
            await persist(note)
            if note != baseline { await checkpoint(reason: "Editing session", kind: "session") }
        } else {
            try? await repository.deleteKnowledgeDraft(noteID: note.id)
            try? await repository.deleteKnowledgeNote(id: note.id)
        }
    }

    public func checkpoint(reason: String, kind: String) async {
        guard note != baseline, let data = try? JSONEncoder().encode(baseline) else { return }
        try? await repository.saveKnowledgeRevision(
            .init(
                noteID: note.id,
                snapshot: data,
                reason: reason,
                baseContentVersion: baseline.contentVersion,
                contentVersion: note.contentVersion,
                sessionID: id,
                changeKind: kind
            )
        )
        baseline = note
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        let snapshot = note
        saveState = .saving
        autosaveTask = Task { [weak self] in
            guard let self else { return }
            if let data = try? JSONEncoder().encode(snapshot) {
                try? await repository.saveKnowledgeDraft(
                    .init(
                        noteID: snapshot.id,
                        snapshot: data,
                        baseContentVersion: snapshot.contentVersion,
                        sceneID: sceneID
                    )
                )
            }
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await persist(snapshot)
        }
    }

    private func persist(_ value: LifeBoardKnowledgeNoteValue) async {
        guard value.isMeaningful || baseline.isMeaningful else {
            saveState = .idle
            return
        }
        if !didCreateOpeningRevision, baseline.isMeaningful, let data = try? JSONEncoder().encode(baseline) {
            try? await repository.saveKnowledgeRevision(
                .init(
                    noteID: value.id,
                    snapshot: data,
                    reason: "Before editing",
                    baseContentVersion: baseline.contentVersion,
                    contentVersion: value.contentVersion,
                    sessionID: id,
                    changeKind: "sessionStart"
                )
            )
            didCreateOpeningRevision = true
        }
        do {
            try await repository.saveKnowledgeNote(value)
            try await repository.deleteKnowledgeDraft(noteID: value.id)
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Search index

public struct KnowledgeSearchDocument: Hashable, Sendable {
    public var noteID: UUID
    public var title: String
    public var body: String
    public var tags: String
    public var attachments: String
    public var updatedAt: Date
    public var isLocked: Bool
}

public struct KnowledgeSearchResult: Identifiable, Hashable, Sendable {
    public var id: UUID { noteID }
    public var noteID: UUID
    public var snippet: String
    public var score: Double
}

public enum KnowledgeSearchIndexStatus: Equatable, Sendable {
    case unavailable
    case ready(updatedAt: Date?)
    case rebuilding(progress: Double)
    case failed(String)
}

public protocol KnowledgeSearchIndex: Sendable {
    func upsert(_ document: KnowledgeSearchDocument) async throws
    func remove(noteID: UUID) async throws
    func search(_ terms: String, limit: Int) async throws -> [KnowledgeSearchResult]
    func rebuild(_ documents: [KnowledgeSearchDocument]) async throws
    func status() async -> KnowledgeSearchIndexStatus
}

public actor LocalKnowledgeSearchIndex: KnowledgeSearchIndex {
    private static let schemaVersion = 1
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private let url: URL
    nonisolated(unsafe) private var database: OpaquePointer?
    private var currentStatus: KnowledgeSearchIndexStatus = .unavailable

    public init(databaseURL: URL? = nil) throws {
        if let databaseURL {
            url = databaseURL
        } else {
            guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            url = support
                .appendingPathComponent("LifeBoard/KnowledgeSearchIndex", isDirectory: true)
                .appendingPathComponent("notes-search.sqlite")
        }
    }

    deinit { sqlite3_close(database) }

    public func status() -> KnowledgeSearchIndexStatus { currentStatus }

    public func upsert(_ document: KnowledgeSearchDocument) throws {
        try open()
        if document.isLocked { try remove(noteID: document.noteID); return }
        try transaction {
            try upsertRows(document)
            try setMetadata("updatedAt", String(Date().timeIntervalSince1970))
        }
        try protect()
        currentStatus = .ready(updatedAt: Date())
    }

    public func remove(noteID: UUID) throws {
        try open()
        try transaction {
            try execute("DELETE FROM notes WHERE noteID = ?;", [noteID.uuidString])
            try execute("DELETE FROM notes_fts WHERE noteID = ?;", [noteID.uuidString])
        }
    }

    public func search(_ terms: String, limit: Int) throws -> [KnowledgeSearchResult] {
        try open()
        let query = terms.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, limit > 0 else { return [] }
        let escaped = query.split(whereSeparator: \.isWhitespace).map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }.joined(separator: " AND ")
        var statement: OpaquePointer?
        let sql = """
        SELECT notes.noteID,
               snippet(notes_fts, 2, '', '', ' … ', 18),
               CASE
                 WHEN lower(notes.title) = lower(?) THEN 1000
                 WHEN lower(notes.title) LIKE lower(?) THEN 850
                 WHEN lower(notes.tags) = lower(?) THEN 700
                 WHEN lower(notes.title) LIKE lower(?) THEN 600
                 ELSE 400
               END - bm25(notes_fts, 0.0, 7.0, 2.5, 4.0, 3.0)
               + MIN(35.0, notes.updatedAt / 100000000.0)
        FROM notes_fts JOIN notes USING(noteID)
        WHERE notes_fts MATCH ?
        ORDER BY 3 DESC, notes.updatedAt DESC
        LIMIT ?;
        """
        try prepare(sql, &statement)
        defer { sqlite3_finalize(statement) }
        bind(query, statement, 1)
        bind("\(query)%", statement, 2)
        bind(query, statement, 3)
        bind("%\(query)%", statement, 4)
        bind(escaped, statement, 5)
        sqlite3_bind_int(statement, 6, Int32(limit))
        var results: [KnowledgeSearchResult] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idText = text(statement, 0), let id = UUID(uuidString: idText) else { continue }
            results.append(.init(noteID: id, snippet: text(statement, 1) ?? "", score: sqlite3_column_double(statement, 2)))
        }
        return results
    }

    public func rebuild(_ documents: [KnowledgeSearchDocument]) async throws {
        try open()
        currentStatus = .rebuilding(progress: 0)
        try transaction {
            try execute("DELETE FROM notes;")
            try execute("DELETE FROM notes_fts;")
            for (index, document) in documents.enumerated() where !document.isLocked {
                try Task.checkCancellation()
                try upsertRows(document)
                if index.isMultiple(of: 64) {
                    currentStatus = .rebuilding(
                        progress: Double(index + 1) / Double(max(1, documents.count))
                    )
                }
            }
            try setMetadata("updatedAt", String(Date().timeIntervalSince1970))
        }
        try protect()
        currentStatus = .ready(updatedAt: Date())
    }

    private func upsertRows(_ document: KnowledgeSearchDocument) throws {
        try execute("DELETE FROM notes WHERE noteID = ?;", [document.noteID.uuidString])
        try execute("DELETE FROM notes_fts WHERE noteID = ?;", [document.noteID.uuidString])
        try execute(
            "INSERT INTO notes(noteID,title,body,tags,attachments,updatedAt) VALUES(?,?,?,?,?,?);",
            [
                document.noteID.uuidString,
                document.title,
                document.body,
                document.tags,
                document.attachments,
                String(document.updatedAt.timeIntervalSince1970)
            ]
        )
        try execute(
            "INSERT INTO notes_fts(noteID,title,body,tags,attachments) VALUES(?,?,?,?,?);",
            [document.noteID.uuidString, document.title, document.body, document.tags, document.attachments]
        )
    }

    private func open() throws {
        guard database == nil else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            sqlite3_close(db)
            currentStatus = .failed(message)
            throw NSError(domain: "LifeBoardKnowledgeSearch", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        database = db
        do {
            try execute("PRAGMA journal_mode=WAL;")
            try execute("PRAGMA synchronous=NORMAL;")
            try execute("CREATE TABLE IF NOT EXISTS notes(noteID TEXT PRIMARY KEY,title TEXT NOT NULL,body TEXT NOT NULL,tags TEXT NOT NULL,attachments TEXT NOT NULL,updatedAt REAL NOT NULL);")
            try execute("CREATE TABLE IF NOT EXISTS notes_metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL);")
            try execute("CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(noteID UNINDEXED,title,body,tags,attachments,tokenize='unicode61');")
            let version = try metadata("schemaVersion").flatMap(Int.init)
            if let version, version != Self.schemaVersion {
                try execute("DELETE FROM notes;")
                try execute("DELETE FROM notes_fts;")
            }
            try setMetadata("schemaVersion", String(Self.schemaVersion))
            try protect()
            currentStatus = .ready(updatedAt: try metadata("updatedAt").flatMap(Double.init).map(Date.init(timeIntervalSince1970:)))
        } catch {
            sqlite3_close(database)
            database = nil
            throw error
        }
    }

    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE;")
        do { try body(); try execute("COMMIT;") }
        catch { try? execute("ROLLBACK;"); throw error }
    }

    private func execute(_ sql: String, _ bindings: [String] = []) throws {
        var statement: OpaquePointer?
        try prepare(sql, &statement)
        defer { sqlite3_finalize(statement) }
        for (offset, value) in bindings.enumerated() { bind(value, statement, Int32(offset + 1)) }
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw databaseError() }
    }

    private func prepare(_ sql: String, _ statement: inout OpaquePointer?) throws {
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else { throw databaseError() }
    }

    private func bind(_ value: String, _ statement: OpaquePointer?, _ index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, Self.transient)
    }

    private func text(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        sqlite3_column_text(statement, index).map { String(cString: $0) }
    }

    private func metadata(_ key: String) throws -> String? {
        var statement: OpaquePointer?
        try prepare("SELECT value FROM notes_metadata WHERE key = ? LIMIT 1;", &statement)
        defer { sqlite3_finalize(statement) }
        bind(key, statement, 1)
        return sqlite3_step(statement) == SQLITE_ROW ? text(statement, 0) : nil
    }

    private func setMetadata(_ key: String, _ value: String) throws {
        try execute("INSERT OR REPLACE INTO notes_metadata(key,value) VALUES(?,?);", [key, value])
    }

    private func databaseError() -> Error {
        NSError(domain: "LifeBoardKnowledgeSearch", code: 2, userInfo: [NSLocalizedDescriptionKey: database.map { String(cString: sqlite3_errmsg($0)) } ?? "SQLite error"])
    }

    private func protect() throws {
        for suffix in ["", "-wal", "-shm"] {
            let candidate = URL(fileURLWithPath: url.path + suffix)
            guard FileManager.default.fileExists(atPath: candidate.path) else { continue }
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: candidate.path)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutable = candidate
            try mutable.setResourceValues(values)
        }
    }
}

// MARK: - Secure note envelopes

public struct KnowledgeSecureEnvelope: Codable, Hashable, Sendable {
    public var noteID: UUID
    public var keyIdentifier: String
    public var algorithmVersion: Int
    public var contentVersion: Int
    public var ciphertext: Data
    public var attachmentCiphertexts: [UUID: Data]
}

public struct KnowledgeUnlockedNoteSession: Hashable, Sendable {
    public var note: LifeBoardKnowledgeNoteValue
    public var attachments: [LifeBoardKnowledgeAttachmentValue]
    public var links: [LifeBoardKnowledgeLinkValue]
    public var keyIdentifier: String

    public init(
        note: LifeBoardKnowledgeNoteValue,
        attachments: [LifeBoardKnowledgeAttachmentValue],
        links: [LifeBoardKnowledgeLinkValue] = [],
        keyIdentifier: String
    ) {
        self.note = note
        self.attachments = attachments
        self.links = links
        self.keyIdentifier = keyIdentifier
    }
}

public protocol KnowledgeSecureNoteService: Sendable {
    func lock(
        note: LifeBoardKnowledgeNoteValue,
        attachments: [LifeBoardKnowledgeAttachmentValue],
        links: [LifeBoardKnowledgeLinkValue],
        reason: String
    ) async throws -> KnowledgeSecureEnvelope
    func unlock(_ envelope: KnowledgeSecureEnvelope, reason: String) async throws
        -> (LifeBoardKnowledgeNoteValue, [LifeBoardKnowledgeAttachmentValue], [LifeBoardKnowledgeLinkValue])
    func reseal(
        note: LifeBoardKnowledgeNoteValue,
        attachments: [LifeBoardKnowledgeAttachmentValue],
        links: [LifeBoardKnowledgeLinkValue],
        keyIdentifier: String
    ) async throws -> KnowledgeSecureEnvelope
    func deleteKey(identifier: String) async throws
}

public actor DefaultKnowledgeSecureNoteService: KnowledgeSecureNoteService {
    private struct CanonicalPayload: Codable {
        var note: LifeBoardKnowledgeNoteValue
        var attachmentMetadata: [LifeBoardKnowledgeAttachmentValue]
        var links: [LifeBoardKnowledgeLinkValue]?
    }

    public enum SecureNoteError: LocalizedError {
        case authenticationFailed
        case malformedPayload
        case keyUnavailable
        case keychain(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .authenticationFailed: "LifeBoard could not verify your identity."
            case .malformedPayload: "This locked note could not be decoded safely."
            case .keyUnavailable: "The key for this note is unavailable on this device."
            case let .keychain(status): "Secure storage failed with status \(status)."
            }
        }
    }

    private let service = "com.lifeboard.notes.secure-key.v1"

    public func lock(
        note: LifeBoardKnowledgeNoteValue,
        attachments: [LifeBoardKnowledgeAttachmentValue],
        links: [LifeBoardKnowledgeLinkValue],
        reason: String
    ) async throws -> KnowledgeSecureEnvelope {
        guard await BiometricAppLock().authenticate(reason: reason) else { throw SecureNoteError.authenticationFailed }
        let key = SymmetricKey(size: .bits256)
        let identifier = note.id.uuidString
        try store(key, identifier: identifier)
        return try seal(
            note: note,
            attachments: attachments,
            links: links,
            key: key,
            keyIdentifier: identifier
        )
    }

    public func reseal(
        note: LifeBoardKnowledgeNoteValue,
        attachments: [LifeBoardKnowledgeAttachmentValue],
        links: [LifeBoardKnowledgeLinkValue],
        keyIdentifier: String
    ) async throws -> KnowledgeSecureEnvelope {
        try seal(
            note: note,
            attachments: attachments,
            links: links,
            key: load(identifier: keyIdentifier),
            keyIdentifier: keyIdentifier
        )
    }

    private func seal(
        note: LifeBoardKnowledgeNoteValue,
        attachments: [LifeBoardKnowledgeAttachmentValue],
        links: [LifeBoardKnowledgeLinkValue],
        key: SymmetricKey,
        keyIdentifier: String
    ) throws -> KnowledgeSecureEnvelope {
        let redactedAttachments = attachments.map {
            var value = $0
            value.payload = Data()
            value.thumbnail = nil
            value.ocrText = nil
            value.transcript = nil
            return value
        }
        let canonical = try JSONEncoder().encode(
            CanonicalPayload(note: note, attachmentMetadata: redactedAttachments, links: links)
        )
        let content = try AES.GCM.seal(canonical, using: key).combined!
        var attachmentCiphertexts: [UUID: Data] = [:]
        for attachment in attachments {
            attachmentCiphertexts[attachment.id] = try AES.GCM.seal(attachment.payload, using: key).combined!
        }
        let envelope = KnowledgeSecureEnvelope(
            noteID: note.id,
            keyIdentifier: keyIdentifier,
            algorithmVersion: 1,
            contentVersion: note.contentVersion ?? 1,
            ciphertext: content,
            attachmentCiphertexts: attachmentCiphertexts
        )
        _ = try decryptWithoutAuthentication(envelope)
        return envelope
    }

    public func unlock(
        _ envelope: KnowledgeSecureEnvelope,
        reason: String
    ) async throws -> (LifeBoardKnowledgeNoteValue, [LifeBoardKnowledgeAttachmentValue], [LifeBoardKnowledgeLinkValue]) {
        guard await BiometricAppLock().authenticate(reason: reason) else { throw SecureNoteError.authenticationFailed }
        return try decryptWithoutAuthentication(envelope)
    }

    public func deleteKey(identifier: String) throws {
        let status = SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: identifier, kSecAttrSynchronizable: kSecAttrSynchronizableAny] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw SecureNoteError.keychain(status) }
    }

    private func decryptWithoutAuthentication(
        _ envelope: KnowledgeSecureEnvelope
    ) throws -> (LifeBoardKnowledgeNoteValue, [LifeBoardKnowledgeAttachmentValue], [LifeBoardKnowledgeLinkValue]) {
        let key = try load(identifier: envelope.keyIdentifier)
        let box = try AES.GCM.SealedBox(combined: envelope.ciphertext)
        let data = try AES.GCM.open(box, using: key)
        guard let payload = try? JSONDecoder().decode(CanonicalPayload.self, from: data) else { throw SecureNoteError.malformedPayload }
        var attachments = payload.attachmentMetadata
        for index in attachments.indices {
            guard let encrypted = envelope.attachmentCiphertexts[attachments[index].id] else { continue }
            attachments[index].payload = try AES.GCM.open(try AES.GCM.SealedBox(combined: encrypted), using: key)
        }
        return (payload.note, attachments, payload.links ?? [])
    }

    private func store(_ key: SymmetricKey, identifier: String) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: identifier,
            kSecAttrSynchronizable: true,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlocked,
            kSecValueData: data
        ]
        SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service, kSecAttrAccount: identifier, kSecAttrSynchronizable: kSecAttrSynchronizableAny] as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureNoteError.keychain(status) }
    }

    private func load(identifier: String) throws -> SymmetricKey {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: identifier,
            kSecAttrSynchronizable: kSecAttrSynchronizableAny,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status == errSecItemNotFound { throw SecureNoteError.keyUnavailable }
            throw SecureNoteError.keychain(status)
        }
        return SymmetricKey(data: data)
    }
}

// MARK: - EVA proposal and attachment contracts

public enum NoteAIAction: String, Codable, CaseIterable, Sendable {
    case summarize
    case cleanUp
    case continueWriting
    case extractTasks
    case suggestTags
    case suggestLinks
}

public struct NoteAIProposal: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var baseContentVersion: Int
    public var action: NoteAIAction
    public var explanation: String
    public var preview: String
    public var mutations: [NoteMutation]

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        baseContentVersion: Int,
        action: NoteAIAction,
        explanation: String,
        preview: String,
        mutations: [NoteMutation]
    ) {
        self.id = id
        self.noteID = noteID
        self.baseContentVersion = baseContentVersion
        self.action = action
        self.explanation = explanation
        self.preview = preview
        self.mutations = mutations
    }

    public func isStale(for note: LifeBoardKnowledgeNoteValue) -> Bool {
        note.id != noteID || (note.contentVersion ?? 1) != baseContentVersion
    }
}

public protocol NoteAIProposalService: Sendable {
    func propose(
        action: NoteAIAction,
        note: LifeBoardKnowledgeNoteValue,
        selectedText: String?
    ) async throws -> NoteAIProposal
}

public struct FoundationModelsNoteAIProposalService: NoteAIProposalService {
    public enum ProposalError: LocalizedError {
        case unavailable

        public var errorDescription: String? {
            "On-device writing assistance is unavailable right now. Your note was not changed."
        }
    }

    public init() {}

    public func propose(
        action: NoteAIAction,
        note: LifeBoardKnowledgeNoteValue,
        selectedText: String?
    ) async throws -> NoteAIProposal {
        #if canImport(FoundationModels)
        guard SystemLanguageModel.default.availability == .available else { throw ProposalError.unavailable }
        let source = selectedText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? selectedText!
            : note.plainText
        let instruction = switch action {
        case .summarize: "Summarize the supplied note in a warm, precise paragraph."
        case .cleanUp: "Improve clarity and structure without adding any facts. Return only the revised text."
        case .continueWriting: "Continue naturally with one concise paragraph. Do not invent specific facts."
        case .extractTasks: "List only concrete next actions already supported by the note, one per line."
        case .suggestTags: "Suggest up to five short tags, separated by commas."
        case .suggestLinks: "List the concepts that would be most useful to connect to other notes."
        }
        let session = LanguageModelSession(
            model: .default,
            instructions: """
            You are Eva inside LifeBoard Notes. Operate only on the note text explicitly supplied in this request.
            Never retrieve Journal content or claim access to other private data. Do not add facts.
            """
        )
        let response = try await session.respond(
            to: """
            Action: \(instruction)

            Note text:
            \(source)
            """,
            options: GenerationOptions(temperature: 0.15, maximumResponseTokens: 520)
        )
        let output = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        var after = note
        switch action {
        case .summarize:
            after.blocks.insert(
                .init(noteID: note.id, kind: .callout, text: output, ordinal: 0),
                at: 0
            )
        case .cleanUp:
            var block = note.blocks.first ?? .init(noteID: note.id)
            block.kind = .paragraph
            block.text = output
            block.richTextData = nil
            after.blocks = [block]
        case .continueWriting:
            after.blocks.append(.init(noteID: note.id, kind: .paragraph, text: output, ordinal: note.blocks.count))
        case .extractTasks, .suggestTags, .suggestLinks:
            break
        }
        for index in after.blocks.indices { after.blocks[index].ordinal = index }
        after.updatedAt = Date()
        after.contentVersion = max(1, note.contentVersion ?? 1) + 1
        let mutations: [NoteMutation] = after == note ? [] : [.replaceNote(before: note, after: after)]
        return .init(
            noteID: note.id,
            baseContentVersion: note.contentVersion ?? 1,
            action: action,
            explanation: "Eva used only this note\(selectedText == nil ? "" : " selection") and prepared a reviewable proposal.",
            preview: output,
            mutations: mutations
        )
        #else
        throw ProposalError.unavailable
        #endif
    }
}

// MARK: - Loss-conscious Markdown import and export

public enum KnowledgeMarkdownCodec {
    public static func render(_ note: LifeBoardKnowledgeNoteValue, includeTitle: Bool = true) -> String {
        var lines: [String] = []
        if includeTitle {
            lines.append("# \(note.displayTitle)")
            lines.append("")
        }
        for block in note.blocks.sorted(by: { $0.ordinal < $1.ordinal }) {
            switch block.kind {
            case .heading1: lines.append("# \(block.text)")
            case .heading2: lines.append("## \(block.text)")
            case .bulletedList: lines.append("- \(block.text)")
            case .numberedList: lines.append("\(max(1, block.ordinal + 1)). \(block.text)")
            case .checklist: lines.append("- [\(block.isChecked ? "x" : " ")] \(block.text)")
            case .quote: lines.append("> \(block.text)")
            case .callout: lines.append("> [!NOTE]\n> \(block.text)")
            case .code: lines.append("```\n\(block.text)\n```")
            case .divider: lines.append("---")
            case .bookmark:
                let bookmark = KnowledgeBlockPayload.decode(from: block).bookmark
                let url = bookmark?.url?.absoluteString ?? block.text
                lines.append("[\(bookmark?.title ?? block.text)](\(url))")
            case .noteLink:
                let title = KnowledgeBlockPayload.decode(from: block).noteLink?.cachedTitle ?? block.text
                lines.append("[[\(title)]]")
            case .table:
                let rows = KnowledgeBlockPayload.decode(from: block).table?.rows ?? []
                if let first = rows.first {
                    lines.append("| \(first.joined(separator: " | ")) |")
                    lines.append("| \(first.map { _ in "---" }.joined(separator: " | ")) |")
                    for row in rows.dropFirst() {
                        lines.append("| \(row.joined(separator: " | ")) |")
                    }
                } else if !block.text.isEmpty {
                    lines.append(block.text)
                }
            case .image, .file:
                let name = KnowledgeBlockPayload.decode(from: block).attachment?.fileName ?? block.text
                lines.append("[\(name)](attachments/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name))")
            case .collapsible:
                lines.append("<details><summary>\(block.text)</summary></details>")
            case .paragraph:
                lines.append(block.text)
            }
            lines.append("")
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    public static func parse(
        _ markdown: String,
        noteID: UUID,
        startingOrdinal: Int = 0
    ) -> [LifeBoardKnowledgeBlockValue] {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [LifeBoardKnowledgeBlockValue] = []
        var codeLines: [String] = []
        var isInCodeFence = false

        func append(_ kind: LifeBoardKnowledgeBlockKind, _ text: String, checked: Bool = false) {
            blocks.append(
                .init(
                    noteID: noteID,
                    kind: kind,
                    text: text,
                    ordinal: startingOrdinal + blocks.count,
                    isChecked: checked,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            )
        }

        for line in lines {
            if line.hasPrefix("```") {
                if isInCodeFence {
                    append(.code, codeLines.joined(separator: "\n"))
                    codeLines.removeAll(keepingCapacity: true)
                }
                isInCodeFence.toggle()
                continue
            }
            if isInCodeFence {
                codeLines.append(line)
                continue
            }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if trimmed == "---" || trimmed == "***" {
                append(.divider, "")
            } else if trimmed.hasPrefix("## ") {
                append(.heading2, String(trimmed.dropFirst(3)))
            } else if trimmed.hasPrefix("# ") {
                append(.heading1, String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("- [ ] ") {
                append(.checklist, String(trimmed.dropFirst(6)))
            } else if trimmed.lowercased().hasPrefix("- [x] ") {
                append(.checklist, String(trimmed.dropFirst(6)), checked: true)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                append(.bulletedList, String(trimmed.dropFirst(2)))
            } else if trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                let content = trimmed.replacingOccurrences(of: #"^\d+\.\s+"#, with: "", options: .regularExpression)
                append(.numberedList, content)
            } else if trimmed.hasPrefix("> [!NOTE]") {
                continue
            } else if trimmed.hasPrefix("> ") {
                append(.quote, String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
                append(.noteLink, String(trimmed.dropFirst(2).dropLast(2)))
            } else {
                // Unsupported syntax remains recoverable as plaintext instead of being discarded.
                append(.paragraph, line)
            }
        }
        if isInCodeFence, !codeLines.isEmpty {
            append(.code, codeLines.joined(separator: "\n"))
        }
        return blocks
    }
}

public enum KnowledgeAttachmentProcessingState: String, Codable, CaseIterable, Sendable {
    case queued
    case running
    case available
    case failedRetryable
    case failedTerminal
    case cancelled
    case unavailable
}

public struct KnowledgeAttachmentProgress: Identifiable, Hashable, Sendable {
    public var id: UUID { attachmentID }
    public var attachmentID: UUID
    public var state: KnowledgeAttachmentProcessingState
    public var fractionCompleted: Double
    public var message: String?
}

public protocol KnowledgeAttachmentPipeline: Sendable {
    func ingest(
        data: Data,
        fileName: String,
        contentType: String?,
        sourceKind: String,
        noteID: UUID
    ) async throws -> LifeBoardKnowledgeAttachmentValue
    func retry(attachmentID: UUID) async
    func cancel(attachmentID: UUID) async
    func progress(attachmentID: UUID) async -> KnowledgeAttachmentProgress?
}

public actor LocalKnowledgeAttachmentPipeline: KnowledgeAttachmentPipeline {
    private let repository: any LifeBoardPhaseIIRepository
    private let files: any KnowledgeAttachmentFileRepository
    private var states: [UUID: KnowledgeAttachmentProgress] = [:]

    public init(repository: any LifeBoardPhaseIIRepository, files: any KnowledgeAttachmentFileRepository) {
        self.repository = repository
        self.files = files
    }

    public func ingest(
        data: Data,
        fileName: String,
        contentType: String?,
        sourceKind: String,
        noteID: UUID
    ) async throws -> LifeBoardKnowledgeAttachmentValue {
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let existing = try await repository.fetchKnowledgeAttachments(noteID: noteID)
        if let duplicate = existing.first(where: { $0.checksum == digest }) { return duplicate }
        var attachment = LifeBoardKnowledgeAttachmentValue(
            noteID: noteID,
            kind: URL(fileURLWithPath: fileName).pathExtension.lowercased(),
            fileName: fileName,
            payload: data,
            contentType: contentType,
            checksum: digest,
            byteCount: Int64(data.count),
            availability: "available",
            modifiedAt: Date(),
            sourceKind: sourceKind,
            processingState: KnowledgeAttachmentProcessingState.queued.rawValue
        )
        states[attachment.id] = .init(attachmentID: attachment.id, state: .queued, fractionCompleted: 0, message: "Saving original")
        let protectedURL = try await files.persist(attachment)
        attachment.protectedRelativePath = protectedURL.lastPathComponent
        attachment.processingState = KnowledgeAttachmentProcessingState.available.rawValue
        try await repository.saveKnowledgeAttachment(attachment)
        states[attachment.id] = .init(attachmentID: attachment.id, state: .available, fractionCompleted: 1, message: nil)
        return attachment
    }

    public func retry(attachmentID: UUID) {
        guard var state = states[attachmentID], state.state == .failedRetryable else { return }
        state.state = .queued
        state.fractionCompleted = 0
        state.message = "Queued"
        states[attachmentID] = state
    }

    public func cancel(attachmentID: UUID) {
        guard var state = states[attachmentID], state.state != .available else { return }
        state.state = .cancelled
        state.message = "Cancelled"
        states[attachmentID] = state
    }

    public func progress(attachmentID: UUID) -> KnowledgeAttachmentProgress? { states[attachmentID] }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        UIFont.systemFont(ofSize: pointSize, weight: weight)
    }
}
