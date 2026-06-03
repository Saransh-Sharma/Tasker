import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingCinematicBackdrop: View {
    enum Mode {
        case intro(WelcomeIntroPhase)
        case steady(OnboardingStepVisualTheme)

        var grainAmount: Int {
            switch self {
            case .intro(let phase):
                phase.videoGrainAmount
            case .steady:
                100
            }
        }

        func dimOpacity(colorScheme: ColorScheme, colorSchemeContrast: ColorSchemeContrast) -> Double {
            switch self {
            case .intro(let phase):
                let base = phase.showsTitle
                    ? (colorScheme == .dark ? 0.28 : 0.24)
                    : (colorScheme == .dark ? 0.12 : 0.10)
                return max(phase.backdropDimOpacity, base + contrastBoost(colorSchemeContrast))
            case .steady:
                return (colorScheme == .dark ? 0.48 : 0.40) + contrastBoost(colorSchemeContrast)
            }
        }

        func blurOpacity(colorScheme: ColorScheme, colorSchemeContrast: ColorSchemeContrast) -> Double {
            switch self {
            case .intro(let phase):
                let base = phase.showsTitle
                    ? (colorScheme == .dark ? 0.11 : 0.09)
                    : (colorScheme == .dark ? 0.04 : 0.03)
                return max(phase.backdropBlurOpacity, base + contrastBoost(colorSchemeContrast) * 0.5)
            case .steady:
                return (colorScheme == .dark ? 0.24 : 0.20) + contrastBoost(colorSchemeContrast) * 0.5
            }
        }

        func topGradientOpacity(colorScheme: ColorScheme, colorSchemeContrast: ColorSchemeContrast) -> Double {
            switch self {
            case .intro(let phase):
                let base = phase.showsTitle
                    ? (colorScheme == .dark ? 0.24 : 0.20)
                    : (colorScheme == .dark ? 0.10 : 0.08)
                return base + contrastBoost(colorSchemeContrast)
            case .steady:
                return (colorScheme == .dark ? 0.44 : 0.38) + contrastBoost(colorSchemeContrast)
            }
        }

        func bottomGradientOpacity(colorScheme: ColorScheme, colorSchemeContrast: ColorSchemeContrast) -> Double {
            switch self {
            case .intro(let phase):
                let base = phase.showsTitle
                    ? (colorScheme == .dark ? 0.30 : 0.26)
                    : (colorScheme == .dark ? 0.14 : 0.12)
                return base + contrastBoost(colorSchemeContrast)
            case .steady:
                return (colorScheme == .dark ? 0.54 : 0.48) + contrastBoost(colorSchemeContrast)
            }
        }

        var accentWash: Color {
            switch self {
            case .intro:
                return .clear
            case .steady(let theme):
                return theme.backdrop
            }
        }

        func accentWashOpacity(colorScheme: ColorScheme, colorSchemeContrast: ColorSchemeContrast) -> Double {
            switch self {
            case .intro:
                return 0
            case .steady:
                return (colorScheme == .dark ? 0.20 : 0.16) + contrastBoost(colorSchemeContrast) * 0.5
            }
        }

        func materialDimmingOpacity(colorScheme: ColorScheme, colorSchemeContrast: ColorSchemeContrast) -> Double {
            switch self {
            case .intro(let phase):
                let base = phase.showsTitle
                    ? (colorScheme == .dark ? 0.07 : 0.06)
                    : (colorScheme == .dark ? 0.03 : 0.025)
                return base + contrastBoost(colorSchemeContrast) * 0.5
            case .steady:
                return (colorScheme == .dark ? 0.16 : 0.13) + contrastBoost(colorSchemeContrast) * 0.5
            }
        }

        func contrastBoost(_ colorSchemeContrast: ColorSchemeContrast) -> Double {
            colorSchemeContrast == .increased ? 0.04 : 0
        }
    }

    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.colorSchemeContrast) var colorSchemeContrast
    @Environment(\.colorScheme) var colorScheme

    let mode: Mode
    let includeWelcomeAccessibilityMarkers: Bool

    var shouldExposeGrainMarkerForUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-UI_TESTING")
    }

    var body: some View {
        ZStack {
            OnboardingHeroVideoView(
                videoName: OnboardingHeroMediaAsset.welcomeVideoName,
                accessibilityIdentifier: "onboarding.backdrop.video.host"
            )
            .ignoresSafeArea()

            LifeBoardBackdropNoiseOverlay(amount: mode.grainAmount)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .ignoresSafeArea()

            Rectangle()
                .fill(Color.black.opacity(mode.dimOpacity(colorScheme: colorScheme, colorSchemeContrast: colorSchemeContrast)))
                .ignoresSafeArea()

            Rectangle()
                .fill(mode.accentWash.opacity(mode.accentWashOpacity(colorScheme: colorScheme, colorSchemeContrast: colorSchemeContrast)))
                .ignoresSafeArea()

            if reduceTransparency {
                Rectangle()
                    .fill(OnboardingTheme.canvas.opacity(mode.blurOpacity(colorScheme: colorScheme, colorSchemeContrast: colorSchemeContrast) * 1.15))
                    .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(mode.blurOpacity(colorScheme: colorScheme, colorSchemeContrast: colorSchemeContrast))
                    .ignoresSafeArea()
            }

            Rectangle()
                .fill(Color.black.opacity(mode.materialDimmingOpacity(colorScheme: colorScheme, colorSchemeContrast: colorSchemeContrast)))
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(mode.topGradientOpacity(colorScheme: colorScheme, colorSchemeContrast: colorSchemeContrast)),
                    Color.clear,
                    Color.black.opacity(mode.bottomGradientOpacity(colorScheme: colorScheme, colorSchemeContrast: colorSchemeContrast))
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            if shouldExposeGrainMarkerForUITests {
                OnboardingAccessibilityMarker(
                    identifier: AppOnboardingAccessibilityID.backdropGrain,
                    label: "Onboarding cinematic backdrop grain",
                    value: "\(mode.grainAmount)%"
                )
                    .allowsHitTesting(false)
                    .frame(width: 1, height: 1)

                OnboardingAccessibilityMarker(
                    identifier: AppOnboardingAccessibilityID.backdropVideo,
                    label: "Onboarding cinematic backdrop video",
                    value: nil
                )
                .allowsHitTesting(false)
                .frame(width: 1, height: 1)

                if includeWelcomeAccessibilityMarkers {
                    OnboardingAccessibilityMarker(
                        identifier: AppOnboardingAccessibilityID.welcomeHeroVideo,
                        label: "Welcome video",
                        value: nil
                    )
                    .allowsHitTesting(false)
                    .frame(width: 1, height: 1)

                    OnboardingAccessibilityMarker(
                        identifier: AppOnboardingAccessibilityID.welcomeVideoGrain,
                        label: "Onboarding welcome video grain",
                        value: "\(mode.grainAmount)%"
                    )
                    .allowsHitTesting(false)
                    .frame(width: 1, height: 1)
                }
            }
        }
    }
}
