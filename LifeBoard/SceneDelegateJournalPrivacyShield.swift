import UIKit

/// When the Journal privacy shield covers the window.
///
/// iPhone and iPad: as the scene resigns active, which is when the app-switcher
/// snapshot is taken. Mac: only when the app is hidden, minimized or the screen
/// locks — a Mac window resigns active on every click into another app, and
/// blanking it then made LifeBoard unusable beside anything else. On every
/// platform only while Journal content is on screen, which is what the setting
/// ("Hide Journal in the app switcher") has always said.
enum JournalPrivacyShieldPolicy {
    enum Event: Equatable {
        case willResignActive
        case didEnterBackground
    }

    static var isMacCatalyst: Bool {
        #if targetEnvironment(macCatalyst)
        true
        #else
        false
        #endif
    }

    static func shouldShield(
        event: Event,
        isMacCatalyst: Bool,
        shieldsAppSwitcher: Bool,
        journalIsVisible: Bool
    ) -> Bool {
        guard shieldsAppSwitcher, journalIsVisible else { return false }
        return isMacCatalyst ? event == .didEnterBackground : event == .willResignActive
    }
}

extension SceneDelegate {
    func installJournalPrivacyShieldIfNeeded(for event: JournalPrivacyShieldPolicy.Event) {
        let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
        let policy = JournalPrivacyPolicyPersistence.load(from: defaults)
        guard JournalPrivacyShieldPolicy.shouldShield(
            event: event,
            isMacCatalyst: JournalPrivacyShieldPolicy.isMacCatalyst,
            shieldsAppSwitcher: policy.shieldsAppSwitcher,
            journalIsVisible: JournalContentVisibility.isVisible
        ), journalPrivacyShield == nil, let window else { return }

        let shield = UIView(frame: window.bounds)
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shield.backgroundColor = SemanticColorTokens.foundationCanvas
        shield.isAccessibilityElement = true
        shield.accessibilityLabel = "LifeBoard content hidden for privacy"

        let symbol = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        symbol.tintColor = SemanticColorTokens.foundationApricotAccent
        symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        symbol.translatesAutoresizingMaskIntoConstraints = false
        shield.addSubview(symbol)
        NSLayoutConstraint.activate([
            symbol.centerXAnchor.constraint(equalTo: shield.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: shield.centerYAnchor)
        ])
        window.addSubview(shield)
        journalPrivacyShield = shield
    }

    func removeJournalPrivacyShield() {
        journalPrivacyShield?.removeFromSuperview()
        journalPrivacyShield = nil
    }
}
