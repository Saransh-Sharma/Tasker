import SwiftUI
import WidgetKit
#if canImport(AppIntents)
import AppIntents
#endif

#if os(iOS)
/// Control Center's "Start focus". The widget target cannot reach the app's
/// shortcut handoff store, so the control opens the app through the focus
/// deep link; `AppRouter` turns `lifeboard://focus/start` into the same pending
/// launch action Siri uses, and a session starts.
@available(iOS 18.0, *)
struct StartFocusControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Focus"
    static let description = IntentDescription("Starts a focus session.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "lifeboard://focus/start")!))
    }
}

@available(iOS 18.0, *)
public struct FocusControl: ControlWidget {
    public init() {}

    public var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.lifeboard.control.focus") {
            ControlWidgetButton(action: StartFocusControlIntent()) {
                Label("Start Focus", systemImage: "scope")
            }
        }
        .displayName("Start Focus")
        .description("Starts a focus session.")
    }
}
#endif
