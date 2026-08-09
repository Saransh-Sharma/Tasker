import SwiftUI
import UIKit

struct TimelineAnchorRitualTheme {
    let heroAssetName: String
    let tokenSystemImageName: String
    let pillSystemImageName: String
    let accent: Color
    let accentDeep: Color
    let accentSoft: Color
    let accentMist: Color
    let surface: Color
    let title: Color
    let subtitle: Color
    let cardBorder: Color
    let ctaGradient: LinearGradient

    static func theme(for selection: TimelineAnchorSelection) -> TimelineAnchorRitualTheme {
        switch selection {
        case .wake:
            return TimelineAnchorRitualTheme(
                heroAssetName: "routine_morning_strip",
                tokenSystemImageName: "alarm.fill",
                pillSystemImageName: "sun.max",
                accent: Color(lifeboardHex: "#F16A35"),
                accentDeep: Color(lifeboardHex: "#D94E22"),
                accentSoft: adaptiveColor(light: "#FFF0E4", dark: "#241812"),
                accentMist: adaptiveColor(light: "#FFE5D4", dark: "#33211A"),
                surface: adaptiveColor(light: "#FFFDFC", dark: "#15161D"),
                title: LBColorTokens.navy,
                subtitle: LBColorTokens.navyMuted,
                cardBorder: adaptiveColor(light: "#F5E6DA", dark: "#2C2620"),
                ctaGradient: LinearGradient(
                    colors: [
                        Color(lifeboardHex: "#F66B36"),
                        Color(lifeboardHex: "#EA5A2C")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        case .windDown:
            return TimelineAnchorRitualTheme(
                heroAssetName: "routine_evening_strip",
                tokenSystemImageName: "moon.fill",
                pillSystemImageName: "moon.fill",
                accent: Color(lifeboardHex: "#6A35E8"),
                accentDeep: Color(lifeboardHex: "#5529D5"),
                accentSoft: adaptiveColor(light: "#F0E8FF", dark: "#1C1630"),
                accentMist: adaptiveColor(light: "#E7DCFF", dark: "#281E42"),
                surface: adaptiveColor(light: "#FFFDFC", dark: "#15151E"),
                title: LBColorTokens.navy,
                subtitle: LBColorTokens.navyMuted,
                cardBorder: adaptiveColor(light: "#E9E0F7", dark: "#262233"),
                ctaGradient: LinearGradient(
                    colors: [
                        Color(lifeboardHex: "#6732E8"),
                        Color(lifeboardHex: "#5121D6")
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    /// Resolves the warm/violet pastel in light mode and a deep same-hue tone in
    /// dark mode, so the ritual sheet renders as a native dark surface instead of
    /// a forced-light card.
    private static func adaptiveColor(light: String, dark: String) -> Color {
        let lightColor = UIColor(lifeboardHex: light)
        let darkColor = UIColor(lifeboardHex: dark)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }
}
