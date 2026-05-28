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
        let useMaterialBackground = usesMaterialBackground && scrollOptimizedRendering == false
        let effectiveShadow = scrollOptimizedRendering ? nil : shadow

        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .modifier(LBOptionalMaterialBackgroundModifier(cornerRadius: cornerRadius, isEnabled: useMaterialBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    }
            }
            .modifier(LBOptionalShadowModifier(token: effectiveShadow))
    }
}

private struct LBOptionalMaterialBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
        }
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
