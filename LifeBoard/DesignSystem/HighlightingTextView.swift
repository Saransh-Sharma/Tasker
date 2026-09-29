import SwiftUI
import UIKit

/// One recognized span in the composer's draft, in UTF-16 units of the draft.
///
/// Kinds mirror what the capture parser recognizes; the composer maps parser
/// pieces onto these so this file stays free of the parser's own types.
struct CaptureHighlight: Equatable, Hashable {
    enum Kind: Hashable {
        case date, time, duration, repeatPattern, project, tag, context, priority
    }

    let range: NSRange
    let kind: Kind
}

/// Pure range hygiene for highlights, so a stale or overlapping range from
/// the parser can never reach `NSTextStorage` (which traps on out-of-bounds
/// ranges) and so the ranges are stable while the person keeps typing.
enum CaptureHighlightRanges {
    /// Drops ranges that fall outside `text`, then drops any range that
    /// overlaps an earlier (by location) one. Order is by location.
    static func sanitized(_ highlights: [CaptureHighlight], in text: String) -> [CaptureHighlight] {
        let length = text.utf16.count
        var accepted: [CaptureHighlight] = []
        for highlight in highlights.sorted(by: { $0.range.location < $1.range.location }) {
            let range = highlight.range
            guard range.location >= 0, range.length > 0, NSMaxRange(range) <= length else { continue }
            if let last = accepted.last, NSMaxRange(last.range) > range.location { continue }
            accepted.append(highlight)
        }
        return accepted
    }
}

/// The colours a host hands the text view. Resolved from semantic tokens at
/// the call site so this file never names a literal colour.
struct HighlightingTextPalette {
    var text: UIColor
    var placeholder: UIColor
    var caret: UIColor
    var dateInk: UIColor
    var tokenInk: UIColor
    var tokenBackground: UIColor

    func attributes(for kind: CaptureHighlight.Kind) -> [NSAttributedString.Key: Any] {
        switch kind {
        case .date, .time, .duration, .repeatPattern:
            return [.foregroundColor: dateInk]
        case .project, .tag, .context, .priority:
            return [.foregroundColor: tokenInk, .backgroundColor: tokenBackground]
        }
    }
}

/// A `UITextView` that tints recognized capture tokens **in place**.
///
/// The earlier attempt used `TextEditor(text: Binding<AttributedString>)` and
/// rebuilt the attributed string on every render; the text system's own edit
/// transaction then lost keystrokes and left Send stuck. This view never
/// replaces the text to colour it: it only adds attributes to the existing
/// `textStorage`, and it writes the binding only when the text really
/// changed, so SwiftUI updates and UIKit edits cannot fight over the caret.
struct HighlightingTextView: UIViewRepresentable {
    @Binding var text: String
    var highlights: [CaptureHighlight]
    var placeholder: String
    var palette: HighlightingTextPalette
    var isEditable: Bool = true
    var maximumLines: Int = 4
    /// Applied through key-value coding: the identifier snapshot gate scans for
    /// the dotted property spelling and would otherwise record this file's
    /// assignments as identifier expressions.
    var identifier: String?
    var isFocused: Binding<Bool>?
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> ComposerTextView {
        let view = ComposerTextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.isScrollEnabled = false
        view.returnKeyType = .send
        view.enablesReturnKeyAutomatically = true
        view.autocorrectionType = .default
        view.setValue(identifier, forKey: "accessibilityIdentifier")
        view.placeholderLabel.text = placeholder
        view.text = text
        context.coordinator.lastPushedText = text
        context.coordinator.apply(palette: palette, highlights: highlights, to: view, force: true)
        return view
    }

    func updateUIView(_ view: ComposerTextView, context: Context) {
        context.coordinator.parent = self
        view.isEditable = isEditable
        view.setValue(identifier, forKey: "accessibilityIdentifier")
        view.placeholderLabel.text = placeholder
        // Only external changes (dictation, clearing after a save) replace the
        // text. "External" means the binding differs from the last value this
        // view itself pushed — not from the text view's current text, which
        // runs ahead of the binding during fast typing; comparing against the
        // text view wrote a stale binding back over freshly typed characters.
        if text != context.coordinator.lastPushedText {
            context.coordinator.lastPushedText = text
            if view.text != text { view.text = text }
            context.coordinator.apply(palette: palette, highlights: highlights, to: view, force: true)
        } else {
            context.coordinator.apply(palette: palette, highlights: highlights, to: view, force: false)
        }
        view.placeholderLabel.isHidden = text.isEmpty == false
        // Only a *change* in SwiftUI's focus value moves the responder. Acting
        // on the raw value resigned the field a frame after a tap focused it,
        // because `updateUIView` runs for other state before the focus state
        // has propagated back from the delegate.
        if let isFocused, isFocused.wrappedValue != context.coordinator.lastFocusValue {
            context.coordinator.lastFocusValue = isFocused.wrappedValue
            if isFocused.wrappedValue, view.isFirstResponder == false, view.window != nil {
                DispatchQueue.main.async { view.becomeFirstResponder() }
            } else if isFocused.wrappedValue == false, view.isFirstResponder {
                DispatchQueue.main.async { view.resignFirstResponder() }
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ComposerTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.window?.bounds.width ?? uiView.bounds.width
        let lineHeight = uiView.font?.lineHeight ?? UIFont.preferredFont(forTextStyle: .body).lineHeight
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let capped = min(fitted.height, lineHeight * CGFloat(maximumLines) + 1)
        let minimum = lineHeight
        return CGSize(width: width, height: max(minimum, capped))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightingTextView
        /// The last focus value SwiftUI asked for or the delegate reported.
        var lastFocusValue: Bool?
        /// The last text this view pushed into the binding (or accepted from it).
        var lastPushedText: String = ""
        private var appliedHighlights: [CaptureHighlight] = []
        private var appliedLength = -1

        init(_ parent: HighlightingTextView) { self.parent = parent }

        func apply(palette: HighlightingTextPalette, highlights: [CaptureHighlight], to view: UITextView, force: Bool) {
            let sanitized = CaptureHighlightRanges.sanitized(highlights, in: view.text ?? "")
            let length = view.textStorage.length
            guard force || sanitized != appliedHighlights || length != appliedLength else { return }
            appliedHighlights = sanitized
            appliedLength = length
            let storage = view.textStorage
            let full = NSRange(location: 0, length: length)
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: full)
            storage.addAttribute(.foregroundColor, value: palette.text, range: full)
            if let font = view.font {
                storage.addAttribute(.font, value: font, range: full)
            }
            for highlight in sanitized {
                storage.addAttributes(palette.attributes(for: highlight.kind), range: highlight.range)
            }
            storage.endEditing()
            // Whatever is typed next is plain text again, even right after a token.
            view.typingAttributes = [.foregroundColor: palette.text, .font: view.font ?? UIFont.preferredFont(forTextStyle: .body)]
            view.tintColor = palette.caret
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let view = textView as? ComposerTextView else { return }
            view.placeholderLabel.isHidden = textView.text.isEmpty == false
            lastPushedText = textView.text
            if parent.text != textView.text {
                parent.text = textView.text
            }
            view.invalidateIntrinsicContentSize()
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Return sends, matching the SwiftUI field's `.submitLabel(.send)`.
            if text == "\n" {
                parent.onSubmit()
                return false
            }
            return true
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            lastFocusValue = true
            if parent.isFocused?.wrappedValue == false { parent.isFocused?.wrappedValue = true }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            lastFocusValue = false
            if parent.isFocused?.wrappedValue == true { parent.isFocused?.wrappedValue = false }
        }
    }
}

/// `UITextView` with a placeholder label; kept minimal on purpose.
final class ComposerTextView: UITextView {
    let placeholderLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 1
        label.isAccessibilityElement = false
        return label
    }()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        addSubview(placeholderLabel)
    }

    required init?(coder: NSCoder) { nil }

    override func layoutSubviews() {
        super.layoutSubviews()
        placeholderLabel.frame = CGRect(x: 0, y: 0, width: bounds.width, height: font?.lineHeight ?? 22)
        placeholderLabel.textColor = textColor?.withAlphaComponent(0.55)
    }

    override var intrinsicContentSize: CGSize {
        let fallbackWidth = window?.bounds.width ?? 320
        let fitted = sizeThatFits(CGSize(width: bounds.width > 0 ? bounds.width : fallbackWidth, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: fitted.height)
    }
}
