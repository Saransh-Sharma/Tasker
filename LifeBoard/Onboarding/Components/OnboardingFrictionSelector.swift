import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingFrictionSelector: View {
    let selectedProfile: OnboardingFrictionProfile?
    let onSelect: (OnboardingFrictionProfile) -> Void
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @State private var availableWidth: CGFloat = 0

    let columns = [
        GridItem(.flexible(minimum: 0), spacing: 10),
        GridItem(.flexible(minimum: 0), spacing: 10)
    ]

    var body: some View {
        let layout = OnboardingFrictionSelectorLayout.preferredLayout(
            for: availableWidth,
            dynamicTypeSize: dynamicTypeSize
        )
        VStack(alignment: .leading, spacing: 14) {
            if layout == .stacked {
                VStack(alignment: .leading, spacing: 10) {
                    optionCards
                }
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    optionCards
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: OnboardingFrictionSelectorWidthPreferenceKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(OnboardingFrictionSelectorWidthPreferenceKey.self) { width in
            availableWidth = width
        }
    }

    @ViewBuilder
    var optionCards: some View {
        let layout = OnboardingFrictionSelectorLayout.preferredLayout(
            for: availableWidth,
            dynamicTypeSize: dynamicTypeSize
        )

        ForEach(OnboardingFrictionProfile.allCases) { profile in
            OnboardingFrictionOptionCard(
                title: profile.title,
                symbolName: profile.symbolName,
                helperCopy: profile.helperCopy,
                isSelected: selectedProfile == profile,
                layout: layout,
                action: {
                    onSelect(profile)
                }
            )
            .accessibilityHint(profile.helperCopy)
        }
    }
}
