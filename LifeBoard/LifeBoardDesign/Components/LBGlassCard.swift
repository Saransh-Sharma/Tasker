import SwiftUI

struct LBGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = LBRadiusTokens.card
    var borderColor: Color = LBColorTokens.glassBorder
    var fill: Color = LBColorTokens.glass
    var shadow: LBShadowToken? = LBShadowTokens.card
    var usesMaterialBackground = true
    @ViewBuilder let content: Content
    @Environment(\.lifeboardScrollOptimizedRendering) private var scrollOptimizedRendering

    var body: some View {
        let effectiveShadow = scrollOptimizedRendering ? nil : shadow

        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(usesMaterialBackground ? Color.lifeboard(.surfacePrimary) : fill)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                usesMaterialBackground ? Color.lifeboard(.borderDefault) : borderColor,
                                lineWidth: 1
                            )
                    }
            }
            .modifier(LBOptionalShadowModifier(token: effectiveShadow))
    }
}

private struct LBOptionalShadowModifier: ViewModifier {
    let token: LBShadowToken?

    func body(content: Content) -> some View {
        if let token {
            content.lbShadow(token)
        } else {
            content
        }
    }
}
