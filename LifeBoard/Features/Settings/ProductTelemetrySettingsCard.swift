import SwiftUI

struct ProductTelemetrySettingsCard: View {
    @Binding var isEnabled: Bool

    var body: some View {
        SettingsCard {
            SettingsToggleRow(
                iconName: "chart.bar.xaxis",
                title: "Product improvement events",
                subtitle: "Share content-free flow events and error codes. Never includes titles, messages, memory, Health data, or record identifiers.",
                isOn: Binding(
                    get: { isEnabled },
                    set: {
                        isEnabled = $0
                        ProductTelemetry.isEnabled = $0
                    }
                ),
                accessibilityIdentifier: "settings.privacy.productTelemetry.toggle"
            )
        }
    }
}
