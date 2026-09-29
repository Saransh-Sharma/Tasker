import Foundation
import LifeBoardDomain

/// The app's side of `FocusPreset`: what a preset means as a `FocusMode`, and
/// how a preset id from Siri, a deep link or Control Center is resolved
/// against the person's own list.
extension FocusPreset {
    var focusMode: FocusMode {
        switch kind {
        case .countdown:
            .countdown(duration: TimeInterval(minutes * 60))
        case .stopwatch:
            .stopwatch
        case .pomodoro:
            .pomodoro(
                focus: TimeInterval(minutes * 60),
                breakDuration: TimeInterval(breakMinutes * 60),
                rounds: rounds
            )
        case .openEnded:
            .openEnded
        }
    }

    /// The person's presets, never empty; `id` nil or unknown resolves to the
    /// first one so a stale Shortcut still starts *something* sensible.
    static func resolve(id: String?, in preferences: WorkspacePreferences) -> FocusPreset {
        let presets = preferences.focusPresets.isEmpty ? FocusPreset.defaults : preferences.focusPresets
        if let id, let match = presets.first(where: { $0.id == id }) { return match }
        return presets[0]
    }
}
