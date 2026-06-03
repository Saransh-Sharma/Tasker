import SwiftUI

struct EvaChatSunriseBackground: View {
    var body: some View {
        ZStack {
            EvaChatSunriseGlass.background

            LinearGradient(
                colors: [
                    EvaChatSunriseGlass.gold.opacity(0.12),
                    .clear
                ],
                startPoint: .top,
                endPoint: .center
            )

            LinearGradient(
                colors: [
                    .clear,
                    EvaChatSunriseGlass.primary.opacity(0.05)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
