import Foundation

/// A named way to start focus: the rhythm and its lengths, chosen once and
/// reused from the setup sheet, Siri, and Control Center. Lives in the domain
/// package so `WorkspacePreferences` can carry it; the app maps `kind` onto
/// its own focus mode.
public struct FocusPreset: Codable, Equatable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case countdown
        case stopwatch
        case pomodoro
        case openEnded
    }

    public let id: String
    public var name: String
    public var kind: Kind
    /// Countdown length, or the focus phase of a Pomodoro, in minutes.
    public var minutes: Int
    /// Pomodoro rest, in minutes. Ignored for other kinds.
    public var breakMinutes: Int
    /// Pomodoro rounds. Ignored for other kinds.
    public var rounds: Int
    public var systemImage: String

    public init(
        id: String,
        name: String,
        kind: Kind,
        minutes: Int = 25,
        breakMinutes: Int = 5,
        rounds: Int = 4,
        systemImage: String = "timer"
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.minutes = max(1, min(240, minutes))
        self.breakMinutes = max(1, min(60, breakMinutes))
        self.rounds = max(1, min(12, rounds))
        self.systemImage = systemImage
    }

    /// "25 min", "50 / 10 × 2", "Stopwatch", "Open-ended".
    public var summary: String {
        switch kind {
        case .countdown: return String(localized: "\(minutes) min")
        case .pomodoro: return "\(minutes) / \(breakMinutes) × \(rounds)"
        case .stopwatch: return String(localized: "Stopwatch")
        case .openEnded: return String(localized: "Open-ended")
        }
    }

    /// The three shipped presets. Stable ids, so a Shortcut that names one
    /// keeps working after the person renames or retunes it.
    public static let defaults: [FocusPreset] = [
        FocusPreset(id: "deep-work", name: "Deep work", kind: .pomodoro, minutes: 50, breakMinutes: 10, rounds: 2, systemImage: "brain.head.profile"),
        FocusPreset(id: "pomodoro", name: "Pomodoro", kind: .pomodoro, minutes: 25, breakMinutes: 5, rounds: 4, systemImage: "timer"),
        FocusPreset(id: "quick", name: "Quick", kind: .countdown, minutes: 15, systemImage: "bolt"),
    ]
}
