import SwiftUI

enum TimelineStreamPalette {
    struct Stop {
        let progress: CGFloat
        let red: Double
        let green: Double
        let blue: Double
    }

    static let stops: [Stop] = [
        Stop(progress: 0.0, red: 0.22, green: 0.56, blue: 0.55),
        Stop(progress: 0.38, red: 0.45, green: 0.57, blue: 0.36),
        Stop(progress: 0.72, red: 0.48, green: 0.45, blue: 0.58),
        Stop(progress: 1.0, red: 0.38, green: 0.39, blue: 0.50)
    ]

    static func color(progress: CGFloat) -> Color {
        let clampedProgress = min(max(progress, 0), 1)
        guard let first = stops.first else { return Color(red: 0.22, green: 0.56, blue: 0.55) }
        guard let last = stops.last else { return Color(red: 0.22, green: 0.56, blue: 0.55) }
        guard clampedProgress > first.progress else {
            return Color(red: first.red, green: first.green, blue: first.blue)
        }
        guard clampedProgress < last.progress else {
            return Color(red: last.red, green: last.green, blue: last.blue)
        }

        let upperIndex = stops.firstIndex { $0.progress >= clampedProgress } ?? (stops.count - 1)
        let lower = stops[max(upperIndex - 1, 0)]
        let upper = stops[upperIndex]
        let span = max(upper.progress - lower.progress, 0.001)
        let ratio = (clampedProgress - lower.progress) / span
        return Color(
            red: lower.red + ((upper.red - lower.red) * Double(ratio)),
            green: lower.green + ((upper.green - lower.green) * Double(ratio)),
            blue: lower.blue + ((upper.blue - lower.blue) * Double(ratio))
        )
    }
}
