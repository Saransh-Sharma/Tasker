import SwiftUI

/// Setup Center uses the same privacy prompt as every contextual Health flow.
/// Existing write preferences are restored; first-time write-back starts off.
struct SetupCenterHealthDisclosureSheet: View {
    let initialWritableDomains: Set<HealthDomain>
    let onCancel: () -> Void
    let onConfirm: (Set<HealthDomain>) -> Void

    var body: some View {
        HealthConnectPromptSheet(
            leadDomain: .activity,
            initialWritableDomains: initialWritableDomains,
            onConnect: onConfirm,
            onDecline: onCancel
        )
        .accessibilityIdentifier("setupCenter.health.disclosure")
    }
}
