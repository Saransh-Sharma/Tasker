import SwiftUI

struct LBTimelineSpine: View {
    let role: LBRole
    var temporalState: LBTimelineTemporalState = .future

    var body: some View {
        let style = LBColorTokens.role(role)
        VStack(spacing: 0) {
            Rectangle()
                .fill(style.base.opacity(lineOpacity))
                .frame(width: temporalState == .current ? 1.5 : 1)
            Circle()
                .fill(temporalState == .current ? LBColorTokens.violet : style.base.opacity(dotOpacity))
                .frame(width: temporalState == .current ? 12 : 7, height: temporalState == .current ? 12 : 7)
                .overlay(Circle().stroke(LBColorTokens.canvas.opacity(0.92), lineWidth: temporalState == .current ? 3 : 2))
            Rectangle()
                .fill(style.base.opacity(lineOpacity))
                .frame(width: temporalState == .current ? 1.5 : 1)
        }
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
