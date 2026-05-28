import SwiftUI

struct LBTimelineSpine: View {
    let role: LBRole
    var tintHex: String?
    var temporalState: LBTimelineTemporalState = .future

    var body: some View {
        let style = LBColorTokens.role(role)
        let baseColor = resolvedBaseColor(fallback: style.base)
        let hasTint = LifeBoardHexColor.normalized(tintHex) != nil
        VStack(spacing: 0) {
            Rectangle()
                .fill(baseColor.opacity(lineOpacity))
                .frame(width: temporalState == .current ? 1.5 : 1)
            Circle()
                .fill(temporalState == .current ? (hasTint ? baseColor : LBColorTokens.violet) : baseColor.opacity(dotOpacity))
                .frame(width: temporalState == .current ? 12 : 7, height: temporalState == .current ? 12 : 7)
                .overlay(Circle().stroke(LBColorTokens.canvas.opacity(0.92), lineWidth: temporalState == .current ? 3 : 2))
            Rectangle()
                .fill(baseColor.opacity(lineOpacity))
                .frame(width: temporalState == .current ? 1.5 : 1)
        }
    }

    private func resolvedBaseColor(fallback: Color) -> Color {
        LifeBoardHexColor.color(tintHex, fallback: fallback)
    }

    private var lineOpacity: Double {
        switch temporalState {
        case .past: return 0.10
        case .current: return 0.30
        case .future: return 0.18
        }
    }

    private var dotOpacity: Double {
        switch temporalState {
        case .past: return 0.42
        case .current: return 1
        case .future: return 0.86
        }
    }
}
