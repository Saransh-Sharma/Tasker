import SwiftUI

extension AdaptiveAtmosphere {
    func starField(
        descriptor: AtmosphereDescriptor,
        layout: ScenicLayout,
        size: CGSize,
        time: TimeInterval,
        paused: Bool
    ) -> some View {
        let count = size.width >= 700 ? descriptor.regularStarCount : descriptor.compactStarCount
        let visibleCount = reduceTransparency ? max(4, count / 2) : count
        return Canvas(rendersAsynchronously: true) { graphics, canvasSize in
            for index in 0..<visibleCount {
                let x = layout.minX + pseudoRandom(index * 41 + 7) * layout.width
                let y = 18 + pseudoRandom(index * 67 + 19) * canvasSize.height * 0.40
                let base = 0.8 + pseudoRandom(index * 23 + 3) * 1.4
                let cycle = 2.2 + pseudoRandom(index * 13 + 2) * 3.4
                let wave = paused ? 0.72 : 0.52 + 0.46 * sin((time / cycle + Double(index)) * .pi * 2)
                let opacity = reduceTransparency ? max(0.58, wave) : wave
                let rect = CGRect(x: x, y: y, width: base, height: base)
                let color = index.isMultiple(of: 3)
                    ? Color(lifeboardHex: SceneHex.starCool)
                    : Color(lifeboardHex: SceneHex.starWarm)
                graphics.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
            }
        }
    }
}
