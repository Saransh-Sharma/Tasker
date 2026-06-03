import SwiftUI

enum SunriseDecorAsset: String {
    case mountain = "sunrise_decor_mountain"
    case decisionSign = "sunrise_decor_decision_sign"
    case subtleLeaf = "sunrise_decor_subtle_leaf"
    case thinkingCup = "sunrise_decor_thinking_cup"
    case happySun = "sunrise_decor_happy_sun"
    case growthPlant = "sunrise_decor_growth_plant"
    case cloud = "sunrise_decor_cloud"
    case rescueSunrise = "rescue_decor_sunrise"
    case rescueMoonrise = "rescue_decor_moonrise"
    case rescueCup = "rescue_decor_cup"
    case rescueSparkles = "rescue_decor_sparkles"
    case rescuePlant = "rescue_decor_plant"
    case rescueShield = "rescue_decor_shield"
}

enum SunriseDecorPlacement {
    case ambient
    case header
    case emptyState
    case decisionDeck

    var defaultSize: CGFloat {
        switch self {
        case .ambient: return 170
        case .header: return 132
        case .emptyState: return 118
        case .decisionDeck: return 156
        }
    }

    var defaultOpacity: Double {
        switch self {
        case .ambient: return 0.12
        case .header: return 0.34
        case .emptyState: return 0.86
        case .decisionDeck: return 0.92
        }
    }
}

struct SunriseDecorImage: View {
    let asset: SunriseDecorAsset
    var size: CGFloat
    var opacity: Double = 1
    var rotation: Angle = .zero
    var mirrorX = false

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Image(decorative: asset.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .scaleEffect(x: mirrorX ? -1 : 1, y: 1)
            .rotationEffect(rotation)
            .opacity(reduceTransparency ? max(opacity, 0.18) : opacity)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

extension SunriseDecorImage {
    init(
        asset: SunriseDecorAsset,
        placement: SunriseDecorPlacement,
        opacity: Double? = nil,
        rotation: Angle = .zero,
        mirrorX: Bool = false
    ) {
        self.asset = asset
        self.size = placement.defaultSize
        self.opacity = opacity ?? placement.defaultOpacity
        self.rotation = rotation
        self.mirrorX = mirrorX
    }
}
