import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingMascotCarousel: View {
    let selectedID: AssistantMascotID
    let personas: [AssistantMascotPersona]
    let onSelect: (AssistantMascotID) -> Void

    @Environment(\.lifeboardLayoutClass) var layoutClass

    var body: some View {
        TabView(
            selection: Binding(
                get: { selectedID },
                set: { onSelect($0) }
            )
        ) {
            ForEach(personas) { persona in
                VStack(spacing: 16) {
                    Spacer(minLength: 0)

                    EvaMascotView(
                        placement: .chatHelp,
                        size: .custom(layoutClass.isPad ? 260 : 214),
                        decorative: false,
                        accessibilityLabel: persona.displayName,
                        mascotID: persona.id
                    )

                    VStack(spacing: 6) {
                        Text(persona.displayName)
                            .lifeboardFont(.title1)
                            .foregroundStyle(OnboardingTheme.marigold)
                        Text(persona.shortDescription)
                            .lifeboardFont(.body)
                            .foregroundStyle(OnboardingTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(AppOnboardingAccessibilityID.mascotPersona(persona.id.rawValue))
                .tag(persona.id)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .accessibilityLabel("Chief of staff mascot carousel")
    }
}
