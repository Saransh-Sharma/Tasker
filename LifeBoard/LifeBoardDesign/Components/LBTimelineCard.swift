import SwiftUI

enum LBTimelineTemporalState: String, Equatable {
    case past
    case current
    case future
}

struct LBTimelineCard: View, Equatable {
    enum Kind: String, Equatable {
        case anchor
        case calendar
        case task
    }

    struct Model: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        let timeText: String
        let role: LBRole
        let kind: Kind
        let systemImage: String
        let tintHex: String?
        let accessoryText: String?
        let temporalState: LBTimelineTemporalState
        let isCompleted: Bool
        let isToggleable: Bool
        let isCurrent: Bool
    }

    let model: Model
    let onTap: () -> Void
    var onToggleComplete: (() -> Void)?

    nonisolated static func == (lhs: LBTimelineCard, rhs: LBTimelineCard) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        let style = LBColorTokens.role(model.role)
        Button(action: onTap) {
            LBGlassCard(
                cornerRadius: cornerRadius,
                borderColor: borderColor(style),
                fill: fillColor(style),
                shadow: nil,
                usesMaterialBackground: false
            ) {
                HStack(spacing: LBSpacingTokens.sm) {
                    leadingControl(style: style)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.title)
                            .font(LBTypographyTokens.cardTitle)
                            .foregroundStyle(titleColor)
                            .lineLimit(2)
                            .strikethrough(model.isCompleted && model.kind == .task, color: LBColorTokens.navyMuted.opacity(0.65))
                        Text(model.subtitle.isEmpty ? model.timeText : "\(model.timeText)  •  \(model.subtitle)")
                            .font(LBTypographyTokens.meta)
                            .foregroundStyle(metaColor)
                            .lineLimit(2)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: LBSpacingTokens.xs)
                    if let accessoryText = model.accessoryText {
                        Text(accessoryText)
                            .font(LBTypographyTokens.meta)
                            .foregroundStyle(accessoryColor(style))
                            .padding(.horizontal, LBSpacingTokens.sm)
                            .padding(.vertical, LBSpacingTokens.xs)
                            .background(accessoryFill(style), in: Capsule())
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var accessibilityIdentifier: String {
        if model.id.hasPrefix("event:") {
            return "home.timeline.event.\(String(model.id.dropFirst("event:".count)))"
        }
        if model.id.hasPrefix("task:") {
            return "home.timeline.task.\(String(model.id.dropFirst("task:".count)))"
        }
        return "home.timeline.\(model.kind.rawValue).\(model.id)"
    }

    @ViewBuilder
    private func leadingControl(style: LBRoleStyle) -> some View {
        if model.kind == .task {
            let accentColor = taskAccentColor(fallback: style.base)
            Button(action: { onToggleComplete?() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(model.isCompleted ? accentColor : LBColorTokens.glassStrong.opacity(model.temporalState == .past ? 0.58 : 0.94))
                        .frame(width: 34, height: 34)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(model.isCompleted ? accentColor : accentColor.opacity(model.temporalState == .past ? 0.42 : 0.85), lineWidth: 2)
                        }
                    Image(systemName: model.isCompleted ? "checkmark" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(model.isCompleted ? Color.white : accentColor.opacity(0.0))
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.isToggleable)
            .accessibilityLabel(model.isCompleted ? "Reopen task" : "Complete task")
        } else {
            LBIconBadge(systemName: model.systemImage, role: model.role)
                .opacity(model.temporalState == .past ? 0.62 : 1)
        }
    }

    private var cornerRadius: CGFloat {
        model.kind == .anchor ? 18 : LBRadiusTokens.card
    }

    private var horizontalPadding: CGFloat {
        model.kind == .anchor ? LBSpacingTokens.sm : LBSpacingTokens.md
    }

    private var verticalPadding: CGFloat {
        model.kind == .anchor ? 10 : LBSpacingTokens.sm
    }

    private var titleColor: Color {
        if model.temporalState == .past {
            return LBColorTokens.navyMuted
        }
        return LBColorTokens.navy
    }

    private var metaColor: Color {
        model.temporalState == .past ? LBColorTokens.textTertiary : LBColorTokens.navyMuted
    }

    private func fillColor(_ style: LBRoleStyle) -> Color {
        let baseOpacity: Double
        switch model.kind {
        case .anchor:
            baseOpacity = 0.58
        case .calendar:
            baseOpacity = 0.62
        case .task:
            baseOpacity = model.isCompleted ? 0.36 : 0.68
        }
        if model.kind == .task, hasTaskTint {
            let tintOpacity = model.isCompleted ? 0.12 : 0.18
            return taskAccentColor(fallback: style.base).opacity(model.temporalState == .past ? tintOpacity * 0.58 : tintOpacity)
        }
        return style.softSurface.opacity(model.temporalState == .past ? baseOpacity * 0.58 : baseOpacity)
    }

    private func borderColor(_ style: LBRoleStyle) -> Color {
        if model.kind == .task, hasTaskTint {
            return taskAccentColor(fallback: style.border).opacity(model.temporalState == .past ? 0.20 : 0.38)
        }
        return model.temporalState == .past ? style.border.opacity(0.48) : style.border
    }

    private var hasTaskTint: Bool {
        model.kind == .task && LifeBoardHexColor.normalized(model.tintHex) != nil
    }

    private func taskAccentColor(fallback: Color) -> Color {
        LifeBoardHexColor.color(model.tintHex, fallback: fallback)
    }

    private func accessoryColor(_ style: LBRoleStyle) -> Color {
        model.temporalState == .past ? style.deep.opacity(0.62) : style.deep
    }

    private func accessoryFill(_ style: LBRoleStyle) -> Color {
        model.temporalState == .past ? style.softSurface.opacity(0.48) : style.softSurface
    }
}
