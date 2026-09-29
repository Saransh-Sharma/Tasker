import SwiftUI

public extension DaypartPalette {
    /// The fill a clay surface takes on this palette. Nocturnal compositions
    /// lift off their own layer colours so cards stay part of the scene
    /// instead of punching bright holes in it.
    func clayFill(for depth: ClayDepth) -> Color {
        switch depth {
        case .well:
            return isNocturnal
                ? color(for: .layerTwo)
                : color(for: .canvasSecondary).opacity(0.72)
        case .resting, .raised:
            return isNocturnal
                ? color(for: .layerOne)
                : Color(SemanticColorTokens.foundationSurfaceSolid).opacity(0.94)
        case .floating:
            return isNocturnal
                ? color(for: .layerOne)
                : Color(SemanticColorTokens.foundationSurfaceSolid).opacity(0.97)
        }
    }
}
