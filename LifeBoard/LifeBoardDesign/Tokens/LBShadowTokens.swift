import SwiftUI

struct LBShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum LBShadowTokens {
    static let card = LBShadowToken(color: LBColorTokens.navy.opacity(0.10), radius: 18, x: 0, y: 8)
    static let floating = LBShadowToken(color: LBColorTokens.violet.opacity(0.28), radius: 22, x: 0, y: 12)
    static let dock = LBShadowToken(color: LBColorTokens.navy.opacity(0.12), radius: 26, x: 0, y: -6)
}

extension View {
    func lbShadow(_ token: LBShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
