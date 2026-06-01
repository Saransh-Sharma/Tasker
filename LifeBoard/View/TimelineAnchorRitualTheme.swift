import SwiftUI

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
                accentSoft: Color(lifeboardHex: "#FFF0E4"),
                accentMist: Color(lifeboardHex: "#FFE5D4"),
                surface: Color(lifeboardHex: "#FFFDFC"),
                title: Color(lifeboardHex: "#071B52"),
                subtitle: Color(lifeboardHex: "#5D5C64"),
                cardBorder: Color(lifeboardHex: "#F5E6DA"),
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
                accentSoft: Color(lifeboardHex: "#F0E8FF"),
                accentMist: Color(lifeboardHex: "#E7DCFF"),
                surface: Color(lifeboardHex: "#FFFDFC"),
                title: Color(lifeboardHex: "#071B52"),
                subtitle: Color(lifeboardHex: "#5D5C64"),
                cardBorder: Color(lifeboardHex: "#E9E0F7"),
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
}
