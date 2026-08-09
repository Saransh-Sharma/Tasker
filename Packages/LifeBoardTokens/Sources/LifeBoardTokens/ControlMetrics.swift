import CoreFoundation

// Control sizing that the token adapters need.
//
// `TextFieldTokens` moved here from the app's UIKit adapters: it is a
// token, and `SwiftUI+TokenAdapters` — which is now in this package — sizes
// text fields with it.
@MainActor
public struct TextFieldTokens {
    public static let singleLineHeight: CGFloat = 48
    public static let multilineMinHeight: CGFloat = 96
    public static let multilineMaxHeight: CGFloat = 120
}

/// Minimum hit targets for token-styled controls.
///
/// The chip style previously sized itself from `SettingsMetrics`, a
/// constant owned by the Settings *feature* — a design system reaching upward
/// into a feature for its own metric. The value is the HIG minimum tap target
/// and belongs here; Settings keeps its own copy for its own layout.
public enum ControlMetrics {
    public static let chipMinHeight: CGFloat = 44
}
