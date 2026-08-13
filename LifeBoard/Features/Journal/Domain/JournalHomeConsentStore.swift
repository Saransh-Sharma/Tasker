import Foundation

/// Whether the user has agreed to let the Journal card show anything on Home.
///
/// The Home journal card was hard-coded to a degraded state with no way to grant
/// consent anywhere in the app, so it could never become useful — it simply
/// occupied a slot in the default layout forever. Consent is off by default and
/// is granted explicitly in Journal privacy settings; nothing about the journal
/// reaches Home until it is.
///
/// Stored in the App Group so Home, widgets, and the system-surface projections
/// all agree on one answer.
public enum JournalHomeConsentStore {
    private static let key = "feature.life_os.journal.home_consent"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
    }

    public static var isGranted: Bool {
        get { defaults.bool(forKey: key) }
        set { defaults.set(newValue, forKey: key) }
    }

    /// Test hook.
    public static func reset() {
        defaults.removeObject(forKey: key)
    }
}
