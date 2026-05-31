import SwiftUI

enum SunriseDecorAsset: String {
    case mountain = "sunrise_decor_mountain"
    case decisionSign = "sunrise_decor_decision_sign"
    case subtleLeaf = "sunrise_decor_subtle_leaf"
    case thinkingCup = "sunrise_decor_thinking_cup"
    case happySun = "sunrise_decor_happy_sun"
    case growthPlant = "sunrise_decor_growth_plant"
    case cloud = "sunrise_decor_cloud"
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
            .opacity(reduceTransparency ? min(opacity, 0.18) : opacity)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}
