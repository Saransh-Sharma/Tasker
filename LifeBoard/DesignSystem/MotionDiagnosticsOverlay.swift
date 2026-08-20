import SwiftUI

@MainActor
final class MotionDiagnosticsState: ObservableObject {
    static let shared = MotionDiagnosticsState()
    @Published private(set) var lastSemanticTrigger = "launch"

    func record(_ trigger: String) {
        lastSemanticTrigger = trigger
    }
}

private struct MotionDiagnosticsOverlay: View {
    let preferences: PresentationPreferences
    @StateObject private var state = MotionDiagnosticsState.shared
    @State private var readiness = ShaderReadinessStore.shared
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-MOTION_DIAGNOSTICS") {
            VStack(alignment: .leading, spacing: 2) {
                Text("MOTION").font(.caption2.bold())
                Text("full \(preferences.fullMotionEnabled ? "on" : "off") · reduce \(MotionOverride.resolve(systemReduceMotion) ? "on" : "off")")
                Text("transparency \(reduceTransparency ? "reduced" : "live") · \(preferences.comfortProfile.rawValue)")
                Text("tier \(preferences.renderingTier.rawValue) · scene \(String(describing: scenePhase))")
                Text("shader \(shaderStatus)")
                // The published verdict, separate from the preload state above.
                // These two disagreeing is the signature of a gate bug rather
                // than a compile failure — e.g. preload ready but rendering
                // still blocked by comfort, Low Power, or thermal.
                Text("render \(readiness.allowsShaderRendering ? "on" : "off")\(readiness.unavailabilityReason.map { " (\($0.prefix(24)))" } ?? "")")
                Text("last \(state.lastSemanticTrigger)")
            }
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(8)
            .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 10))
            .padding(.top, 54)
            .padding(.leading, 8)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        #endif
    }

    private var shaderStatus: String {
        switch SignatureShaders.preloadState {
        case .idle: "idle"
        case .loading: "loading"
        case .ready(let count, _): "ready(\(count))"
        case .unavailable(let reason): "off: \(reason.prefix(28))"
        }
    }
}

extension View {
    func lifeBoardMotionDiagnostics(preferences: PresentationPreferences) -> some View {
        overlay(alignment: .topLeading) {
            MotionDiagnosticsOverlay(preferences: preferences)
        }
    }
}
