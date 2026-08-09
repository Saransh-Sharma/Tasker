import SwiftUI

struct ShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

enum ShadowTokens {
    static let card = ShadowToken(color: LBColorTokens.elevationShadow, radius: 18, x: 0, y: 8)
    static let floating = ShadowToken(color: LBColorTokens.floatingShadow, radius: 22, x: 0, y: 12)
    static let dock = ShadowToken(color: LBColorTokens.dockShadow, radius: 26, x: 0, y: -6)

    // MARK: - Expressive, bounded elevations

    // These named roles preserve the tactile depth of the rescue and ritual
    // moments without allowing their screens to invent shadow geometry.
    static let rescueTile = ShadowToken(
        color: LBColorTokens.elevationShadow.opacity(0.45),
        radius: 14,
        x: 0,
        y: 8
    )
    static let rescueCompletionTile = ShadowToken(
        color: LBColorTokens.elevationShadow.opacity(0.4),
        radius: 14,
        x: 0,
        y: 8
    )
    static let rescueOverlay = ShadowToken(
        color: LBColorTokens.floatingShadow,
        radius: 30,
        x: 0,
        y: 16
    )
    static let rescueLauncher = ShadowToken(
        color: LBColorTokens.floatingShadow,
        radius: 28,
        x: 0,
        y: 18
    )
    static let ritualClose = ShadowToken(
        color: LBColorTokens.elevationShadow.opacity(0.8),
        radius: 14,
        x: 0,
        y: 8
    )
    static let ritualCard = ShadowToken(
        color: LBColorTokens.elevationShadow.opacity(0.8),
        radius: 18,
        x: 0,
        y: 10
    )

    static func rescueStack(depth: Int) -> ShadowToken {
        let boundedDepth = min(max(depth, 0), 3)
        return ShadowToken(
            color: LBColorTokens.elevationShadow.opacity(0.45 + Double(boundedDepth) * 0.12),
            radius: 16 + CGFloat(boundedDepth) * 4,
            x: 0,
            y: 8 + CGFloat(boundedDepth) * 2
        )
    }

    static func rescueReveal(progress: Double) -> ShadowToken {
        ShadowToken(
            color: LBColorTokens.elevationShadow.opacity(0.8 * min(max(progress, 0), 1)),
            radius: 22,
            x: 0,
            y: 12
        )
    }

    static func ritualOption(isSelected: Bool, accent: Color) -> ShadowToken {
        ShadowToken(
            color: isSelected ? accent.opacity(0.12) : LBColorTokens.elevationShadow.opacity(0.35),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: 3
        )
    }
}

extension View {
    func lbShadow(_ token: ShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
