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
/// The `source` label is surfaced verbatim in the Inbox as "Captured from X",
/// so it names the surface a person recognizes rather than an internal id.
@available(iOS 16.0, *)
public struct CaptureToInboxIntent: AppIntent {
    public static let title: LocalizedStringResource = "Capture to LifeBoard"
    public static let description = IntentDescription(
        "Saves a thought to your LifeBoard inbox to sort out later."
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
        return .result(dialog: IntentDialog("Saved to your inbox to review."))
    }
}

@available(iOS 18.0, *)
public struct LifeBoardCaptureControl: ControlWidget {
    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.lifeboard.control.capture") {
            ControlWidgetButton(action: CaptureToInboxIntent(text: "", source: "control")) {
                Label("Capture", systemImage: "tray.and.arrow.down.fill")
            }
        }
        .displayName("Capture to Inbox")
        .description("Save a thought to review later.")
    }
}
#endif
