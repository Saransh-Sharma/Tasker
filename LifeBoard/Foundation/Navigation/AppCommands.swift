import UIKit

/// The commands the Mac menu bar and an iPad hardware keyboard expose.
///
/// The app had none: no `buildMenu`, no key commands outside a few hidden
/// SwiftUI buttons, so a Mac window showed the stock File/Edit/Format menus and
/// ⌘N meant two different things depending on which hidden button won. Every
/// command is declared here once and received by `AppDelegate` — the end of the
/// responder chain, so it fires even with nothing focused — which forwards it
/// to the key window's scene. The iPad ⌘-hold overlay reads the same menu.
@MainActor @objc protocol AppCommandHandling {
    func lb_newCapture(_ sender: Any?)
    func lb_goToRoot(_ sender: UIKeyCommand)
    func lb_openSettings(_ sender: Any?)
    func lb_newWindow(_ sender: Any?)
    func lb_escape(_ sender: Any?)
}

enum AppCommandMenu {
    static let newIdentifier = UIMenu.Identifier("com.lifeboard.menu.new")
    static let goIdentifier = UIMenu.Identifier("com.lifeboard.menu.go")
    static let settingsIdentifier = UIMenu.Identifier("com.lifeboard.menu.settings")
    static let escapeIdentifier = UIMenu.Identifier("com.lifeboard.menu.escape")

    static let newCaptureAction = #selector(AppCommandHandling.lb_newCapture(_:))
    static let goToRootAction = #selector(AppCommandHandling.lb_goToRoot(_:))
    static let openSettingsAction = #selector(AppCommandHandling.lb_openSettings(_:))
    static let newWindowAction = #selector(AppCommandHandling.lb_newWindow(_:))
    static let escapeAction = #selector(AppCommandHandling.lb_escape(_:))

    /// File ▸ New … ⌘N. The title follows context (see `validate(_:)` in the
    /// host): New Task, New Journal Entry, New Note, New Chat.
    static func newMenu() -> UIMenu {
        UIMenu(
            title: "",
            identifier: newIdentifier,
            options: .displayInline,
            children: [
                UIKeyCommand(
                    title: String(localized: "New Task"),
                    action: newCaptureAction,
                    input: "n",
                    modifierFlags: .command
                ),
                // ⌥⌘N: ⌘N is already the app's New. Each window keeps its own
                // navigation (`FoundationCoordinator(secondaryWindowFor:)`).
                UIKeyCommand(
                    title: String(localized: "New Window"),
                    action: newWindowAction,
                    input: "n",
                    modifierFlags: [.command, .alternate]
                )
            ]
        )
    }

    /// Go ▸ Home … Eva, ⌘1–⌘5 — the Mac and iPad convention. (The hidden shell
    /// buttons used ⌥⌘1–5. Those are not kept as alternates: UIKit rejects two
    /// menu commands with the same action and property list, and throws while
    /// building the menu.)
    static func goMenu() -> UIMenu {
        UIMenu(
            title: String(localized: "Go"),
            identifier: goIdentifier,
            children: rootCommands()
        )
    }

    static func rootCommands() -> [UIKeyCommand] {
        Destination.allCases.enumerated().map { index, destination in
            let command = UIKeyCommand(
                title: destination.title,
                action: goToRootAction,
                input: String(index + 1),
                modifierFlags: .command,
                propertyList: destination.rawValue
            )
            command.wantsPriorityOverSystemBehavior = true
            return command
        }
    }

    /// Esc closes the sheet in front even while one of its fields is being
    /// edited. A focused text field takes Esc before a SwiftUI
    /// `.keyboardShortcut(.cancelAction)` sees it; a menu command with priority
    /// over system behaviour runs first. Hidden: it is a key, not a menu item.
    /// `SheetEscapeRouter` decides whether Esc is the sheet's to take, and the
    /// command is disabled otherwise so the key reaches the focused view.
    static func escapeMenu() -> UIMenu {
        let command = UIKeyCommand(
            title: String(localized: "Close"),
            action: escapeAction,
            input: UIKeyCommand.inputEscape,
            modifierFlags: []
        )
        command.attributes = .hidden
        command.wantsPriorityOverSystemBehavior = true
        return UIMenu(title: "", identifier: escapeIdentifier, options: .displayInline, children: [command])
    }

    private static var allCommands: [UIKeyCommand] {
        (newMenu().children + rootCommands() + settingsMenu().children + escapeMenu().children)
            .compactMap { $0 as? UIKeyCommand }
    }

    /// UIKit throws while building the menu if two commands share an action
    /// and a property list, so the uniqueness test checks this as well.
    static var commandIdentities: [String] {
        let commands = allCommands
        return commands.map { "\($0.action.map(NSStringFromSelector) ?? "")-\(String(describing: $0.propertyList))" }
    }

    /// LifeBoard ▸ Settings… ⌘,
    static func settingsMenu() -> UIMenu {
        UIMenu(
            title: "",
            identifier: settingsIdentifier,
            options: .displayInline,
            children: [
                UIKeyCommand(
                    title: String(localized: "Settings…"),
                    action: openSettingsAction,
                    input: ",",
                    modifierFlags: .command
                )
            ]
        )
    }

    /// The contextual title for File ▸ New.
    static func newCaptureTitle(destination: Destination, captureKind: CaptureKind) -> String {
        if destination == .eva { return String(localized: "New Chat") }
        switch captureKind {
        case .journal: return String(localized: "New Journal Entry")
        case .note: return String(localized: "New Note")
        default: return String(localized: "New Task")
        }
    }

    /// Every key equivalent the menu declares, for the uniqueness check.
    static var keyEquivalents: [String] {
        allCommands.map { "\($0.modifierFlags.rawValue)-\($0.input ?? "")" }
    }
}
