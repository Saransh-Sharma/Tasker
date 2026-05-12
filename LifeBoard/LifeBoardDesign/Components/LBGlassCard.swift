import SwiftUI

struct LBGlassCard<Content: View>: View {
    var cornerRadius: CGFloat = LBRadiusTokens.card
    var borderColor: Color = LBColorTokens.glassBorder
    var fill: Color = LBColorTokens.glass
    var shadow: LBShadowToken? = LBShadowTokens.card
    var usesMaterialBackground = true
    @ViewBuilder let content: Content

    var body: some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .modifier(LBOptionalMaterialBackgroundModifier(cornerRadius: cornerRadius, isEnabled: usesMaterialBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    }
            }
            .modifier(LBOptionalShadowModifier(token: shadow))
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
