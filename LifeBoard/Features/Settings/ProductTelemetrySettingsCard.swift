import SwiftUI

struct ProductTelemetrySettingsCard: View {
    @Binding var isEnabled: Bool

    var body: some View {
        SettingsCard {
            SettingsToggleRow(
                iconName: "chart.bar.xaxis",
                title: "Share usage data",
                subtitle: "Screens and error codes only. Never your content.",
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
