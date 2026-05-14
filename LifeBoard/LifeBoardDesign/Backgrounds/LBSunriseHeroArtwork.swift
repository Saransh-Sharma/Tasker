import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LBSunriseHeroArtwork: View {
    struct Model: Equatable {
        let selectedDate: Date
        let asset: TimeOfDayHeaderAsset
        let isScrollActive: Bool
    }

    let model: Model
    var height: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var displayedAsset: TimeOfDayHeaderAsset?
    @State private var deferredAsset: TimeOfDayHeaderAsset?

    var body: some View {
        ZStack(alignment: .bottom) {
            if reduceTransparency {
                fallbackGradient
            } else if let image = resolvedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: height)
                    .clipped()
            } else {
                fallbackGradient
            }

            if colorScheme == .dark {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.16),
                        Color.black.opacity(0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }

            LinearGradient(
                colors: [
                    LBColorTokens.canvas.opacity(0),
                    LBColorTokens.canvas.opacity(0.10),
                    LBColorTokens.canvas
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: height * 0.11)
            .allowsHitTesting(false)
        }
        .frame(height: height)
        .clipped()
        .onAppear {
            displayedAsset = model.asset
        }
        .onChange(of: model.asset) { _, newValue in
            if model.isScrollActive {
                deferredAsset = newValue
            } else {
                displayedAsset = newValue
            }
        }
        .onChange(of: model.isScrollActive) { _, isActive in
            guard !isActive, let deferredAsset else { return }
            displayedAsset = deferredAsset
            self.deferredAsset = nil
        }
        .accessibilityHidden(true)
    }

    private var activeAsset: TimeOfDayHeaderAsset {
        displayedAsset ?? model.asset
    }

    private var resolvedImage: UIImage? {
        TimeOfDayHeaderAsset.image(named: activeAsset.name)
    }

    private var fallbackGradient: some View {
        LinearGradient(
            colors: fallbackColors(for: activeAsset.period),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func fallbackColors(for period: TimeOfDayHeaderAsset.Period) -> [Color] {
        switch period {
        case .morning:
            return [
                LBColorTokens.adaptive(light: "#DFF5FF", dark: "#13243B"),
                LBColorTokens.adaptive(light: "#FFF1D9", dark: "#2A2217"),
                LBColorTokens.canvas
            ]
        case .afternoon:
            return [
                LBColorTokens.adaptive(light: "#DFF0FF", dark: "#10263F"),
                LBColorTokens.adaptive(light: "#FFF8E7", dark: "#2A2517"),
                LBColorTokens.canvas
            ]
        case .evening:
            return [
                LBColorTokens.adaptive(light: "#EBDFFF", dark: "#211A38"),
                LBColorTokens.adaptive(light: "#FFDDBF", dark: "#352016"),
                LBColorTokens.canvas
            ]
        case .night:
            return [
                Color(lifeboardHex: "#071B52"),
                LBColorTokens.adaptive(light: "#28326F", dark: "#151C3F"),
                LBColorTokens.canvas
            ]
        }
    }
}
