import SwiftUI
import UIKit
import LifeBoardTokens

// MARK: - Keyboard contract
//
// `DESIGN.md` → "Keyboard contract". Every raised keyboard needs a way down
// that keeps the person on the screen and keeps their draft, and every Return
// key has to do what its label says. These are the pieces that make that the
// default rather than something each field has to remember.

// MARK: Return key

/// What a text change on a multi-line field means for its Return key.
///
/// A vertical-axis `TextField` spends Return on a newline and never fires
/// `onSubmit`, so a field that wants Return to act has to recognise the
/// keystroke in the text itself. The only evidence is the value before and
/// after the change, so this compares the two:
///
/// - A lone inserted `"\n"`, anywhere in the text, is the Return key.
/// - A short replacement ending in one `"\n"` is too: autocorrect commits its
///   correction and the newline in the same update ("dont" → "don't\n").
/// - Any other insertion carrying a newline is a paste. It keeps its lines;
///   only a newline left at the very end is trimmed, so a copied line does not
///   send itself.
///
/// Known limit: the keyboard's own dictation "new line" command inserts a lone
/// newline and so reads as Return.
public enum ReturnKeyPolicy {
    public enum Change: Equatable, Sendable {
        /// Ordinary editing. Leave the text alone.
        case edit
        /// The Return key. Replace the text with this (the newline removed), then act.
        case returnKey(String)
        /// A paste that ended in a newline. Replace the text with this; don't act.
        case trimmed(String)
    }

    /// Autocorrect replaces a word at a time. Anything longer arriving with a
    /// newline in one update was pasted over a selection, not typed.
    static let maximumCorrectionLength = 32

    public static func classify(old: String, new: String) -> Change {
        guard old != new, new.contains("\n") else { return .edit }
        let before = Array(old)
        let after = Array(new)
        var prefix = 0
        while prefix < before.count, prefix < after.count, before[prefix] == after[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < before.count - prefix,
              suffix < after.count - prefix,
              before[before.count - 1 - suffix] == after[after.count - 1 - suffix] {
            suffix += 1
        }
        let inserted = after[prefix ..< after.count - suffix]
        let removed = before[prefix ..< before.count - suffix]
        let newlines = inserted.filter { $0 == "\n" }.count
        guard newlines > 0 else { return .edit }

        if newlines == 1, inserted.last == "\n" {
            let typed = inserted.dropLast()
            if typed.isEmpty || (removed.isEmpty == false && typed.count <= maximumCorrectionLength) {
                var text = after
                text.remove(at: after.count - suffix - 1)
                return .returnKey(String(text))
            }
        }

        guard suffix == 0, new.hasSuffix("\n") else { return .edit }
        var text = new
        while text.hasSuffix("\n") { text.removeLast() }
        return .trimmed(text)
    }
}

/// Recognises Return on a multi-line field and runs `action` instead of
/// keeping the newline. See `ReturnKeyPolicy`.
///
/// There is deliberately no `onSubmit` here: a vertical-axis field never fires
/// it for the software keyboard, and a path that did would run `action` twice.
struct ReturnKeyModifier: ViewModifier {
    @Binding var text: String
    let label: SubmitLabel
    let isSuppressed: Bool
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .submitLabel(label)
            .onChange(of: text) { oldValue, newValue in
                guard isSuppressed == false else { return }
                switch ReturnKeyPolicy.classify(old: oldValue, new: newValue) {
                case .edit:
                    break
                case .trimmed(let trimmed):
                    text = trimmed
                case .returnKey(let cleaned):
                    text = cleaned
                    action()
                }
            }
    }
}

// MARK: Keyboard bar

/// Done above the keyboard, for the field that owns it, plus the exit that has
/// no button: VoiceOver's escape gesture.
///
/// A pad keyboard has no Return key and a multi-line field spends Return on a
/// newline, so for those fields this bar is the one way down that doesn't mean
/// leaving the screen.
///
/// The item draws only while *this* field is focused. SwiftUI can gather
/// `.keyboard` toolbar items from across the hierarchy, and an unconditional
/// item would then put a second Done on another field's keyboard — one that
/// clears a field nobody is editing.
struct KeyboardBar<Leading: View>: ViewModifier {
    /// Read in the caller's body from whichever focus it owns — a `Bool`, one
    /// case of an enum, or its own — so every flavour shares this one bar.
    let isFocused: Bool
    let endEditing: () -> Void
    let doneIdentifier: String?
    let leading: Leading
    /// False for a field whose Return key already closes the keyboard: it still
    /// answers VoiceOver's escape, but a Done bar over it would only cost height.
    var showsDone = true

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if isFocused, showsDone {
                        leading
                        Spacer()
                        Button("Done", action: endEditing)
                            .font(.lifeboard(.callout))
                            // The accessible name matches the visible text so
                            // Voice Control's "Tap Done" works; the hint says
                            // what it does.
                            .accessibilityHint("Closes the keyboard")
                            .modifier(FieldIdentity(identifier: doneIdentifier))
                    }
                }
            }
            // VoiceOver's two-finger scrub. (A hardware Esc cannot be added
            // here: the focused text field consumes Escape before `onKeyPress`
            // or a key command sees it.)
            .accessibilityAction(.escape, endEditing)
    }
}

/// Return on a multi-line field that should never hold a newline — a title, a
/// one-line intention — for a field with no focus binding of its own: the key
/// says "done" and closes the keyboard.
struct OwnedReturnKeyDone: ViewModifier {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    init(text: Binding<String>) {
        _text = text
    }

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .modifier(ReturnKeyModifier(text: $text, label: .done, isSuppressed: false) { isFocused = false })
    }
}

/// The same bar for a field with no focus binding of its own; it brings one.
struct OwnedKeyboardBar: ViewModifier {
    let doneIdentifier: String?
    @FocusState private var isFocused: Bool

    init(doneIdentifier: String?) {
        self.doneIdentifier = doneIdentifier
    }

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .modifier(KeyboardBar(
                isFocused: isFocused,
                endEditing: { isFocused = false },
                doneIdentifier: doneIdentifier,
                leading: EmptyView()
            ))
    }
}

// MARK: Typing over content

public extension EnvironmentValues {
    /// True while a composer above this content has the keyboard.
    ///
    /// One-tap commit controls — task completion, habit rings — read it and let
    /// that tap only put the keyboard away. A tap meant to dismiss must not
    /// complete a task or log a habit step; holds and scrubs are deliberate and
    /// are unaffected.
    @Entry var lifeBoardTextEntryActive: Bool = false
}

/// Whether a tap on a one-tap commit control is really the tap that puts the
/// keyboard away. True while a composer above holds the keyboard; the control
/// should do nothing, and the next tap commits.
///
/// Never true under VoiceOver or Switch Control. Their activation is
/// deliberate and doesn't go through the touch that dismisses the keyboard, so
/// swallowing it would leave the control dead for as long as the composer kept
/// focus.
@propertyWrapper
public struct TapIsKeyboardDismissal: DynamicProperty {
    @Environment(\.lifeBoardTextEntryActive) private var textEntryActive
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilitySwitchControlEnabled) private var switchControlEnabled

    public init() {}

    public var wrappedValue: Bool {
        textEntryActive && voiceOverEnabled == false && switchControlEnabled == false
    }
}

public extension View {
    /// Makes Return act on a multi-line field instead of breaking the line,
    /// and labels the key to say so. See `ReturnKeyPolicy`.
    func returnKey(
        _ label: SubmitLabel,
        text: Binding<String>,
        isSuppressed: Bool = false,
        perform action: @escaping () -> Void
    ) -> some View {
        modifier(ReturnKeyModifier(text: text, label: label, isSuppressed: isSuppressed, action: action))
    }

    /// Return closes the keyboard on a multi-line field that should never hold
    /// a newline, for a field with no focus binding of its own.
    func returnKeyEndsEditing(text: Binding<String>) -> some View {
        modifier(OwnedReturnKeyDone(text: text))
    }

    /// Done and VoiceOver escape for the field bound to `isFocused`.
    func keyboardBar(isFocused: FocusState<Bool>.Binding, doneIdentifier: String? = nil) -> some View {
        keyboardBar(isFocused: isFocused, doneIdentifier: doneIdentifier) { EmptyView() }
    }

    /// The keyboard bar with extra keys ahead of Done.
    func keyboardBar<Leading: View>(
        isFocused: FocusState<Bool>.Binding,
        doneIdentifier: String? = nil,
        @ViewBuilder leading: () -> Leading
    ) -> some View {
        modifier(KeyboardBar(
            isFocused: isFocused.wrappedValue,
            endEditing: { isFocused.wrappedValue = false },
            doneIdentifier: doneIdentifier,
            leading: leading()
        ))
    }

    /// The keyboard bar for one field of a form whose focus is an enum.
    func keyboardBar<Value: Hashable>(
        focus: FocusState<Value?>.Binding,
        equals value: Value,
        doneIdentifier: String? = nil
    ) -> some View {
        modifier(KeyboardBar(
            isFocused: focus.wrappedValue == value,
            endEditing: { focus.wrappedValue = nil },
            doneIdentifier: doneIdentifier,
            leading: EmptyView()
        ))
    }

    /// The keyboard bar for a field that has no focus binding of its own.
    func keyboardBar(doneIdentifier: String? = nil) -> some View {
        modifier(OwnedKeyboardBar(doneIdentifier: doneIdentifier))
    }

    /// A keyboard without a Return key, and the Done that has to come with it.
    ///
    /// `.decimalPad`, `.numberPad` and `.phonePad` have no Return, so the
    /// keyboard type and its way down are one decision.
    /// `scripts/check-keyboard-exits.rb` rejects those types anywhere else.
    func padKeyboard(_ type: UIKeyboardType, doneIdentifier: String? = nil) -> some View {
        keyboardType(type).keyboardBar(doneIdentifier: doneIdentifier)
    }

    /// `padKeyboard` for a field that already has a focus binding.
    func padKeyboard(
        _ type: UIKeyboardType,
        isFocused: FocusState<Bool>.Binding,
        doneIdentifier: String? = nil
    ) -> some View {
        keyboardType(type).keyboardBar(isFocused: isFocused, doneIdentifier: doneIdentifier)
    }

    /// Content under a composer. While `isFocused`, a tap anywhere in it puts
    /// the keyboard away *and* still reaches what was tapped, and scrolling
    /// keeps working. It also publishes `lifeBoardTextEntryActive` so one-tap
    /// commit controls hold off.
    ///
    /// A layer over the content does neither: Eva's was one, and it ate every
    /// scroll and every card tap until the keyboard was down.
    func dismissesKeyboardOnTap(_ isFocused: FocusState<Bool>.Binding) -> some View {
        simultaneousGesture(
            TapGesture().onEnded { isFocused.wrappedValue = false },
            including: isFocused.wrappedValue ? .all : .subviews
        )
        .environment(\.lifeBoardTextEntryActive, isFocused.wrappedValue)
    }
}
