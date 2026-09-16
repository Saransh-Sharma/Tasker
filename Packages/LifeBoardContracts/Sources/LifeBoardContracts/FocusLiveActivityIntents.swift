import Foundation

#if os(iOS) && !targetEnvironment(macCatalyst)
import AppIntents

/// The app installs this at launch; a Live Activity button's intent runs in
/// the app's process and hands its command here.
///
/// A bridge rather than a direct call because this package is shared with the
/// widget extension, which cannot see the app's planning store. The command is
/// the same `lifeboard://focus/...` URL the old Link buttons opened, so the app
/// executes it through the one path it already had — only without opening.
public enum FocusLiveActivityIntentBridge {
    nonisolated(unsafe) public static var perform: (@Sendable (URL) async -> Void)?
}

/// Pause, resume, or end a focus session from its Live Activity, in place.
public struct FocusLiveActivityCommandIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Change focus session"
    public static let isDiscoverable = false

    @Parameter(title: "Session")
    public var sessionID: String

    @Parameter(title: "Command")
    public var command: String

    @Parameter(title: "Token")
    public var token: String

    public init() {}

    public init(sessionID: UUID, command: String, token: UUID) {
        self.sessionID = sessionID.uuidString
        self.command = command
        self.token = token.uuidString
    }

    public func perform() async throws -> some IntentResult {
        guard let session = UUID(uuidString: sessionID),
              let commandToken = UUID(uuidString: token),
              let perform = FocusLiveActivityIntentBridge.perform else {
            return .result()
        }
        await perform(FocusActivityLink.url(sessionID: session, command: command, token: commandToken))
        return .result()
    }
}
#endif
