import SwiftUI

struct TimelineRoutineAnchorVisualStyle: Equatable {
    enum Variant: Equatable {
        case morning
        case evening
    }

    let anchorID: String
    let variant: Variant
    let assetName: String
    let displayTitle: String
    let fallbackSubtitle: String

    var borderColor: Color {
        switch variant {
        case .morning:
            return LBColorTokens.adaptive(light: "#F2C077", dark: "#8B6131", darkHighContrast: "#DDA65E")
        case .evening:
            return LBColorTokens.adaptive(light: "#D7C4FF", dark: "#6D5B9C", darkHighContrast: "#AA98E0")
        }
    }

    var titleColor: Color {
        switch variant {
        case .morning:
            return Color(lifeboardHex: "#10264F")
        case .evening:
            return Color(lifeboardHex: "#FFF7E8")
        }
    }

    var subtitleColor: Color {
        switch variant {
        case .morning:
            return Color(lifeboardHex: "#3E5576")
        case .evening:
            return Color(lifeboardHex: "#F7EACF").opacity(0.88)
        }
    }

    var scrimColor: Color {
        switch variant {
        case .morning:
            return Color(lifeboardHex: "#FFF8EA")
        case .evening:
            return Color(lifeboardHex: "#241646")
        }
    }

    static func resolve(anchorID: String, title: String, subtitle: String?) -> TimelineRoutineAnchorVisualStyle? {
        switch anchorID.lowercased() {
        case "wake":
            return TimelineRoutineAnchorVisualStyle(
                anchorID: anchorID,
                variant: .morning,
                assetName: "routine_morning_strip",
                displayTitle: trimmed(title, fallback: "Rise and shine"),
                fallbackSubtitle: trimmed(subtitle, fallback: "Start the day")
            )
        case "sleep":
            return TimelineRoutineAnchorVisualStyle(
                anchorID: anchorID,
                variant: .evening,
                assetName: "routine_evening_strip",
                displayTitle: "Wind Down",
                fallbackSubtitle: trimmed(subtitle, fallback: "Close the day")
            )
        default:
            return nil
        }
    }

    func subtitleText(timeText: String) -> String {
        "\(timeText) • \(fallbackSubtitle)"
    }

    func accessibilityLabel(timeText: String) -> String {
        "Routine, \(timeText), \(displayTitle), \(fallbackSubtitle)."
    }

    private static func trimmed(_ value: String?, fallback: String) -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.isEmpty == false else {
            return fallback
        }
        return value
    }
}
