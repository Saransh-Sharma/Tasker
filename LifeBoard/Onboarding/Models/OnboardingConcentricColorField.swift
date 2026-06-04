import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingConcentricColorField: View {
    let theme: OnboardingStepVisualTheme
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorSchemeContrast) var colorSchemeContrast

    var body: some View {
        ZStack {
            if reduceTransparency {
                colorField
            } else {
                liquidGlassField
            }

            Rectangle()
                .fill(Color.black.opacity(darkContrastOpacity))
        }
        .animation(.easeInOut(duration: 0.34), value: theme.id)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    var liquidGlassField: some View {
        if #available(iOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.clear, in: Rectangle())
                .overlay(colorField)
                .overlay(
                    Rectangle()
                        .fill(.regularMaterial)
                        .opacity(materialVeilOpacity)
                )
        } else {
            colorField
                .overlay(
                    Rectangle()
                        .fill(.regularMaterial)
                        .opacity(materialVeilOpacity)
                )
        }
    }

    var colorField: some View {
        ZStack {
            LinearGradient(
                colors: [
                    theme.backdrop.opacity(backdropOpacity),
                    theme.accent.opacity(accentOpacity),
                    Color.black.opacity(gradientFloorOpacity)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    theme.accent.opacity(accentGlowOpacity),
                    theme.backdrop.opacity(backdropGlowOpacity),
                    Color.clear
                ],
                center: .bottom,
                startRadius: 18,
                endRadius: 720
            )
            .blendMode(.screen)
        }
    }

    var backdropOpacity: Double {
        if reduceTransparency { return 0.90 }
        return colorSchemeContrast == .increased ? 0.38 : 0.30
    }

    var accentOpacity: Double {
        if reduceTransparency { return 0.46 }
        return colorSchemeContrast == .increased ? 0.23 : 0.18
    }

    var accentGlowOpacity: Double {
        if reduceTransparency { return 0.30 }
        return colorSchemeContrast == .increased ? 0.28 : 0.24
    }

    var backdropGlowOpacity: Double {
        reduceTransparency ? 0.34 : 0.18
    }

    var gradientFloorOpacity: Double {
        if reduceTransparency { return 0.24 }
        return colorSchemeContrast == .increased ? 0.14 : 0.08
    }

    var materialVeilOpacity: Double {
        if reduceTransparency { return 0.12 }
        return colorSchemeContrast == .increased ? 0.08 : 0.04
    }

    var darkContrastOpacity: Double {
        if reduceTransparency { return 0.30 }
        return colorSchemeContrast == .increased ? 0.13 : 0.07
    }
}
