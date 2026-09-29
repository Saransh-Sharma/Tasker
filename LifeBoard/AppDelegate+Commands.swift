import UIKit

// MARK: - Main menu

extension AppDelegate: AppCommandHandling {
    /// The scene the command is for: the key window's.
    private var activeSceneDelegate: SceneDelegate? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first { scene in
            scene.activationState == .foregroundActive && scene.windows.contains(where: \.isKeyWindow)
        } ?? scenes.first { $0.activationState == .foregroundActive }
        return active?.delegate as? SceneDelegate
    }

    @objc func lb_newCapture(_ sender: Any?) {
        activeSceneDelegate?.performNewCapture()
    }

    @objc func lb_goToRoot(_ sender: UIKeyCommand) {
        guard let rawValue = sender.propertyList as? String,
              let destination = Destination(rawValue: rawValue) else { return }
        activeSceneDelegate?.performGoTo(destination)
    }

    @objc func lb_openSettings(_ sender: Any?) {
        activeSceneDelegate?.performOpenSettings()
    }

    @objc func lb_newWindow(_ sender: Any?) {
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil, errorHandler: nil)
    }

    /// Esc: the sheet in front of the key window closes through its own
    /// cancel action, even while one of its fields is being edited.
    @objc func lb_escape(_ sender: Any?) {
        SheetEscapeRouter.shared.handleEscape(in: keyWindow)
    }

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    override func validate(_ command: UICommand) {
        super.validate(command)
        if command.action == AppCommandMenu.newCaptureAction, let scene = activeSceneDelegate {
            command.title = scene.newCaptureTitle
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        switch action {
        case AppCommandMenu.newWindowAction:
            return UIApplication.shared.supportsMultipleScenes
        case AppCommandMenu.newCaptureAction, AppCommandMenu.goToRootAction, AppCommandMenu.openSettingsAction:
            return activeSceneDelegate?.acceptsAppCommands ?? false
        case AppCommandMenu.escapeAction:
            // Declining here lets Esc continue to the focused view, a menu, an
            // alert or an input method, exactly as if the command did not exist.
            return SheetEscapeRouter.shared.resolution(in: keyWindow) != .none
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }

    /// The Mac menu bar, and the iPad ⌘-hold shortcut overlay, which reads the
    /// same menu. Commands are declared in `AppCommandMenu`, received here and
    /// forwarded to the key window's `SceneDelegate`.
    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        guard builder.system == .main else { return }
        // Each anchor is checked first: the iPad menu is not the Mac's (an
        // iPad has no About item, for one), and inserting beside a menu that
        // is not there throws.
        if builder.menu(for: .format) != nil {
            // Nothing in LifeBoard formats text through the menu bar.
            builder.remove(menu: .format)
        }
        if builder.menu(for: .document) != nil {
            // Duplicate / Move / Rename / Export As are for document apps;
            // LifeBoard has no documents, so they were dead items under File.
            builder.remove(menu: .document)
        }
        if builder.menu(for: .newScene) != nil {
            // With multiple windows enabled the system adds File ▸ New Window
            // on ⌘N, which displaced LifeBoard's own ⌘N (New Task). Ours carries
            // New Window on ⌥⌘N instead.
            builder.remove(menu: .newScene)
        }
        if builder.menu(for: .file) != nil {
            builder.insertChild(AppCommandMenu.newMenu(), atStartOfMenu: .file)
            builder.insertChild(AppCommandMenu.escapeMenu(), atEndOfMenu: .file)
        } else if builder.menu(for: .application) != nil {
            builder.insertChild(AppCommandMenu.escapeMenu(), atEndOfMenu: .application)
        }
        if builder.menu(for: .view) != nil {
            builder.insertSibling(AppCommandMenu.goMenu(), afterMenu: .view)
        } else if builder.menu(for: .window) != nil {
            builder.insertSibling(AppCommandMenu.goMenu(), beforeMenu: .window)
        }
        if builder.menu(for: .about) != nil {
            builder.insertSibling(AppCommandMenu.settingsMenu(), afterMenu: .about)
        } else if builder.menu(for: .application) != nil {
            builder.insertChild(AppCommandMenu.settingsMenu(), atEndOfMenu: .application)
        }
    }
}
