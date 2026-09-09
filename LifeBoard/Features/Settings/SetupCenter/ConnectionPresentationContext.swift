import Foundation

/// Presentation history is independent of authorization and connection state.
struct ConnectionPresentationContext: Identifiable, Equatable {
    enum Surface: String { case onboarding, track, health, nutrition, wellness, settings, eva, home }
    let id = UUID()
    let integration: SetupCenterIntegration
    let origin: Surface
    let returnDestination: Surface

    init(_ integration: SetupCenterIntegration, from origin: Surface, returningTo: Surface? = nil) {
        self.integration = integration
        self.origin = origin
        self.returnDestination = returningTo ?? origin
    }
}

/// Only an actual interrupted operation creates a Home reminder. Explicit
/// deferrals remain in permission memory and do not create setup debt.
enum ConnectionResumeStore {
    static let key = "connections.interrupted"
    static let didChange = Notification.Name("LifeBoardConnectionsInterruptedChanged")
    static var pending: Set<SetupCenterIntegration> {
        Set((UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap(SetupCenterIntegration.init(rawValue:)))
    }
    static func setPending(_ integration: SetupCenterIntegration, _ value: Bool) {
        var next = pending
        if value { next.insert(integration) } else { next.remove(integration) }
        UserDefaults.standard.set(next.map(\.rawValue).sorted(), forKey: key)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
