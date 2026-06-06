import SwiftUI

struct LBTimelineSpine: View {
    let role: LBRole
    var tintHex: String?
    var temporalState: LBTimelineTemporalState = .future
    var iconSystemName: String?
    var iconAccessibilityLabel: String?
    var iconAccessibilityValue: String?
    var iconAction: (() -> Void)?

    var body: some View {
        let style = LBColorTokens.role(role)
        let baseColor = resolvedBaseColor(fallback: style.base)
        let hasTint = LifeBoardHexColor.normalized(tintHex) != nil
        VStack(spacing: 0) {
            Rectangle()
                .fill(baseColor.opacity(lineOpacity))
                .frame(width: temporalState == .current ? 1.5 : 1)
            marker(baseColor: baseColor, hasTint: hasTint)
            Rectangle()
                .fill(baseColor.opacity(lineOpacity))
                .frame(width: temporalState == .current ? 1.5 : 1)
        }
    }

    @ViewBuilder
    private func marker(baseColor: Color, hasTint: Bool) -> some View {
        if let iconSystemName {
            if let iconAction {
                Button(action: iconAction) {
                    iconMarker(systemName: iconSystemName, baseColor: baseColor)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(iconAccessibilityLabel ?? "Timeline action")
                .accessibilityValue(iconAccessibilityValue ?? "")
            } else {
                iconMarker(systemName: iconSystemName, baseColor: baseColor)
                    .accessibilityHidden(true)
            }
        } else {
            Circle()
                .fill(temporalState == .current ? (hasTint ? baseColor : LBColorTokens.violet) : baseColor.opacity(dotOpacity))
                .frame(width: temporalState == .current ? 12 : 7, height: temporalState == .current ? 12 : 7)
                .overlay(Circle().stroke(LBColorTokens.canvas.opacity(0.92), lineWidth: temporalState == .current ? 3 : 2))
        }
    }

    private func iconMarker(systemName: String, baseColor: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: iconSize(for: systemName), weight: .semibold, design: .rounded))
            .foregroundStyle(baseColor.opacity(iconOpacity))
            .frame(width: 44, height: 44)
            .background {
                Circle()
                    .fill(LBColorTokens.glassStrong.opacity(iconBackgroundOpacity))
                    .frame(width: 34, height: 34)
            }
            .overlay {
                Circle()
                    .stroke(baseColor.opacity(iconBorderOpacity), lineWidth: 1)
                    .frame(width: 34, height: 34)
            }
            .shadow(color: baseColor.opacity(temporalState == .past ? 0 : 0.18), radius: 8, y: 2)
    }

    private func resolvedBaseColor(fallback: Color) -> Color {
        LifeBoardHexColor.color(tintHex, fallback: fallback)
    }

    private func iconSize(for systemName: String) -> CGFloat {
        switch systemName {
        case "sun.max.fill", "sparkles":
            return 22
        case "moon.fill":
            return 23
        default:
            return 20
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

    private var iconOpacity: Double {
        temporalState == .past ? 0.52 : 1
    }

    private var iconBackgroundOpacity: Double {
        temporalState == .past ? 0.34 : 0.82
    }

    private var iconBorderOpacity: Double {
        temporalState == .past ? 0.24 : 0.54
    }
}
