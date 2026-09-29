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
/// The app installs these at launch, next to the focus bridge, so fasting and
/// routine Live Activity buttons act in place instead of opening the app.
///
/// Each receives the same `lifeboard://fasting/...` / `lifeboard://routine/...`
/// command URL the old Link buttons opened, so the app can run it through the
/// handler it already has (`FastingLiveActivityDeepLink` /
/// `RoutineLiveActivityDeepLink`). It returns whether the command was applied.
///
/// Until the app installs a bridge, the intent does nothing rather than
/// guessing; the Live Activity keeps showing the unchanged state.
public enum FastingLiveActivityIntentBridge {
    nonisolated(unsafe) public static var perform: (@Sendable (URL) async -> Bool)?
}

public enum RoutineLiveActivityIntentBridge {
    nonisolated(unsafe) public static var perform: (@Sendable (URL) async -> Bool)?
}

/// Finish a fast from its Live Activity, in place. Finishing keeps the
/// session's record; there is deliberately no one-tap cancel on the Lock
/// Screen, because cancelling discards the fast.
public struct FastingLiveActivityCommandIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "End fast"
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
              let perform = FastingLiveActivityIntentBridge.perform else {
            return .result()
        }
        _ = await perform(FastingActivityLink.url(sessionID: session, command: command, token: commandToken))
        return .result()
    }
}

/// Pause, resume, or stop a routine run from its Live Activity, in place.
public struct RoutineLiveActivityCommandIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Change routine"
    public static let isDiscoverable = false

    @Parameter(title: "Run")
    public var runID: String

    @Parameter(title: "Command")
    public var command: String

    @Parameter(title: "Token")
    public var token: String

    public init() {}

    public init(runID: UUID, command: String, token: UUID) {
        self.runID = runID.uuidString
        self.command = command
        self.token = token.uuidString
    }

    public func perform() async throws -> some IntentResult {
        guard let run = UUID(uuidString: runID),
              let commandToken = UUID(uuidString: token),
              let perform = RoutineLiveActivityIntentBridge.perform else {
            return .result()
        }
        _ = await perform(RoutineActivityLink.url(runID: run, command: command, token: commandToken))
        return .result()
    }
}
#endif
