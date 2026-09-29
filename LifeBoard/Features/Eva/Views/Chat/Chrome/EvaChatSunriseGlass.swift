import SwiftUI
import UIKit

/// Eva's conversation chrome on the warm paper system: cream canvases, cocoa
/// ink, and the sun accent. Violet survives only in the assistant-evidence
/// role colors, where it encodes the assistant domain.
///
/// Every value resolves through the semantic color roles, so the chat follows
/// the canonical palette. The ink and border values also step up under
/// Increase Contrast — secondary ink becomes primary ink, and glass edges take
/// the hairline role that strengthens there.
enum EvaChatSunriseGlass {
    static let canvasTop = Color.lifeboard(.bgCanvas)
    static let canvasMid = Color.lifeboard(.bgCanvasSecondary)
    static let canvasBottom = ClayColorTokens.adaptive(light: "#F5ECC9", dark: "#0E1220")
    static let assistantSurface = ClayColorTokens.role(.assistant).softSurface
    static let assistantBorder = contrasting(ClayColorTokens.role(.assistant).border, increased: .strokeStrong)
    static let glassFill = ClayColorTokens.glassStrong
    static let glassBorder = contrasting(ClayColorTokens.glassBorder, increased: .strokeHairline)
    static let primary = Color.lifeboard(.actionPrimary)
    static let primaryDeep = Color.lifeboard(.actionPrimaryPressed)
    static let navy = Color.lifeboard(.textPrimary)
    static let navyMuted = contrasting(Color.lifeboard(.textSecondary), increased: .textPrimary)
    static let gold = Color.lifeboard(.brandHighlight)

    static var background: LinearGradient {
        LinearGradient(
            colors: [
                canvasTop,
                canvasMid,
                canvasBottom.opacity(0.74)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// `normal` everywhere except under Increase Contrast, where `increased`.
    private static func contrasting(_ normal: Color, increased: ColorRole) -> Color {
        let normalColor = UIColor(normal)
        let increasedColor = UIColor(Color.lifeboard(increased))
        return Color(uiColor: UIColor { traits in
            (traits.accessibilityContrast == .high ? increasedColor : normalColor)
                .resolvedColor(with: traits)
        })
    }
}
