import SwiftUI
import UIKit

// MARK: - Esc closes the sheet in front, even while a field is being edited
//
// `.keyboardShortcut(.cancelAction)` on a sheet's Cancel button covers Esc only
// while nothing is being edited: a focused text field takes the key first, so
// on the Mac and on an iPad keyboard the sheet stayed open until the pointer
// found Cancel. The app menu declares one hidden Esc command with priority over
// text editing (`AppCommandMenu.escapeMenu()`), and this router answers it.

/// What Esc does in a window right now.
public enum SheetEscapeResolution: Equatable {
    /// Run the frontmost sheet's own cancel action.
    case cancel
    /// The frontmost sheet did not register, but a field in it is focused: end
    /// editing, so the next Esc reaches that sheet's `.cancelAction` button.
    case endEditing
    /// Not ours. Let the key continue to the focused view or the system (an
    /// alert, a menu, an input method composing text).
    case none
}

/// Routes the app's Esc command to the sheet in front of the key window.
///
/// A sheet registers with `.escapeCancels(perform:)`, passing the same closure
/// as its Cancel button — so a sheet with unsaved changes still asks before
/// discarding. The router only acts on a sheet that is the topmost presented
/// controller of the key window: a nested sheet, an alert or a confirmation
/// dialog in front of it, or a sheet in another window, is never closed by an
/// Esc meant for something else.
@MainActor
public final class SheetEscapeRouter {
    public static let shared = SheetEscapeRouter()

    private final class Entry {
        let id: UUID
        weak var anchor: UIView?
        let action: () -> Void

        init(id: UUID, anchor: UIView, action: @escaping () -> Void) {
            self.id = id
            self.anchor = anchor
            self.action = action
        }
    }

    private var entries: [Entry] = []

    init() {}

    func register(id: UUID, anchor: UIView, action: @escaping () -> Void) {
        entries.removeAll { $0.id == id || $0.anchor == nil }
        entries.append(Entry(id: id, anchor: anchor, action: action))
    }

    func unregister(id: UUID) {
        entries.removeAll { $0.id == id || $0.anchor == nil }
    }

    /// What Esc should do in `window`.
    public func resolution(in window: UIWindow?) -> SheetEscapeResolution {
        guard let window, let front = Self.frontmostPresentedController(in: window) else { return .none }
        let focused = Self.focusedTextInput(in: front)
        // An input method composing text (Japanese, Chinese, …) spends Esc on
        // cancelling the composition.
        if let focused, focused.markedTextRange != nil { return .none }
        if registeredAction(in: front) != nil { return .cancel }
        return focused == nil ? .none : .endEditing
    }

    /// Handles Esc for `window`. Returns false when Esc was not the router's.
    @discardableResult
    public func handleEscape(in window: UIWindow?) -> Bool {
        guard let window, let front = Self.frontmostPresentedController(in: window) else { return false }
        switch resolution(in: window) {
        case .cancel:
            guard let action = registeredAction(in: front) else { return false }
            front.view.endEditing(true)
            action()
            return true
        case .endEditing:
            front.view.endEditing(true)
            return true
        case .none:
            return false
        }
    }

    /// The registration inside `front`. When a sheet nests one registered view
    /// inside another (a composer inside a capture host), the deepest one is
    /// the most specific.
    private func registeredAction(in front: UIViewController) -> (() -> Void)? {
        entries
            .compactMap { entry -> (depth: Int, action: () -> Void)? in
                guard let anchor = entry.anchor, anchor.isDescendant(of: front.view) else { return nil }
                return (Self.depth(of: anchor), entry.action)
            }
            .max { $0.depth < $1.depth }?
            .action
    }

    /// The topmost presented controller, or nil when nothing is presented (a
    /// root screen owns Esc then, not a sheet).
    static func frontmostPresentedController(in window: UIWindow) -> UIViewController? {
        var front: UIViewController?
        var next = window.rootViewController?.presentedViewController
        while let controller = next {
            if controller.isBeingDismissed { break }
            front = controller
            next = controller.presentedViewController
        }
        return front
    }

    static func focusedTextInput(in front: UIViewController) -> UITextInput? {
        FirstResponderProbe.found = nil
        UIApplication.shared.sendAction(#selector(UIResponder.lifeBoardCaptureFirstResponder(_:)), to: nil, from: nil, for: nil)
        defer { FirstResponderProbe.found = nil }
        guard let view = FirstResponderProbe.found as? UIView,
              view.isDescendant(of: front.view),
              let input = view as? UITextInput else { return nil }
        return input
    }

    private static func depth(of view: UIView) -> Int {
        var depth = 0
        var current = view.superview
        while let parent = current {
            depth += 1
            current = parent.superview
        }
        return depth
    }
}

/// `sendAction(_:to: nil, …)` delivers to the first responder; that is the only
/// public way to ask UIKit which view it is.
@MainActor
private enum FirstResponderProbe {
    static weak var found: UIResponder?
}

extension UIResponder {
    @objc func lifeBoardCaptureFirstResponder(_ sender: Any?) {
        FirstResponderProbe.found = self
    }
}

// MARK: - Registration

private struct EscapeCancels: ViewModifier {
    let isEnabled: Bool
    let action: () -> Void
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content.background {
            if isEnabled {
                EscapeAnchor(id: id, action: action)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// A zero-size UIKit view that places the registration in the window's view
/// hierarchy, which is how the router tells which sheet it belongs to.
private struct EscapeAnchor: UIViewRepresentable {
    let id: UUID
    let action: () -> Void

    func makeUIView(context: Context) -> AnchorView {
        let view = AnchorView()
        view.id = id
        view.action = action
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: AnchorView, context: Context) {
        // The registration calls through the view, so it always runs the
        // latest closure (the sheet's state changes between renders).
        view.action = action
    }

    static func dismantleUIView(_ view: AnchorView, coordinator: ()) {
        if let id = view.id {
            SheetEscapeRouter.shared.unregister(id: id)
        }
    }

    final class AnchorView: UIView {
        var id: UUID?
        var action: () -> Void = {}

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let id else { return }
            if window == nil {
                SheetEscapeRouter.shared.unregister(id: id)
            } else {
                SheetEscapeRouter.shared.register(id: id, anchor: self) { [weak self] in self?.action() }
            }
        }
    }
}

public extension View {
    /// Esc closes this sheet through `action` — the same closure as its Cancel
    /// button — even while one of its fields is being edited. Put it on a
    /// sheet's root content. Keep `.keyboardShortcut(.cancelAction)` on the
    /// Cancel button as well; it still owns Esc when nothing is focused.
    func escapeCancels(isEnabled: Bool = true, perform action: @escaping () -> Void) -> some View {
        modifier(EscapeCancels(isEnabled: isEnabled, action: action))
    }
}
