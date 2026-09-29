#if canImport(AppIntents)
import AppIntents
import SwiftUI
import WidgetKit

/// Out-of-process capture entry points.
///
/// Each writes the *raw* text to the App Group `PendingCapture` queue and stops
/// there. Parsing and committing happen in the app, where the Inbox can show the
/// proposal as review chips and the user can disagree with it — the roadmap's
/// rule that nothing uncertain commits silently. An extension has no UI to
/// review in, so it must not decide.
///
/// `source` is a storage id ("control", "widget", "share-extension"); the Inbox
/// turns it into words a person recognizes ("Control Center") through
/// `InboxCaptureSourceCopy`, so only ids that table knows should be sent.
@available(iOS 16.0, *)
public struct CaptureToInboxIntent: AppIntent {
    public static let title: LocalizedStringResource = "Capture to LifeBoard"
    public static let description = IntentDescription(
        "Saves text to your LifeBoard Inbox."
    )
    public static let openAppWhenRun = false

    @Parameter(title: "Text", requestValueDialog: IntentDialog("What do you want to capture?"))
    public var text: String

    /// Which surface queued this, for the Inbox's provenance line.
    @Parameter(title: "Source")
    public var source: String

    public init() {
        self.text = ""
        self.source = "widget"
    }

    public init(text: String, source: String) {
        self.text = text
        self.source = source
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw $text.needsValueError(IntentDialog("What do you want to capture?"))
        }

        PendingCaptureInbox.append(PendingCapture(rawText: trimmed, source: source))

        // Refresh so a badge or count reflects the new item without waiting for
        // the next timeline reload.
        WidgetCenter.shared.reloadAllTimelines()

        // States what happened, not what it became. Claiming it was scheduled
        // would be the silent-commit problem in a friendlier sentence.
        return .result(dialog: IntentDialog("Saved to Inbox."))
    }
}

/// Control Center's Capture opens the app's capture composer.
///
/// It used to run `CaptureToInboxIntent` with empty text. Control Center can't
/// ask for a value, so the intent's "What do you want to capture?" prompt had
/// nowhere to appear and the tap did nothing useful. Opening the composer lets
/// the person type or dictate with the full keyboard.
@available(iOS 18.0, *)
struct OpenCaptureControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture"
    static let description = IntentDescription("Opens LifeBoard to capture a thought.")
    static let openAppWhenRun = true
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "lifeboard://quickadd")!))
    }
}

@available(iOS 18.0, *)
public struct CaptureControl: ControlWidget {
    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.lifeboard.control.capture") {
            ControlWidgetButton(action: OpenCaptureControlIntent()) {
                Label("Capture", systemImage: "square.and.pencil")
            }
        }
        .displayName("Capture")
        .description("Opens LifeBoard to capture a thought.")
    }
}
#endif
