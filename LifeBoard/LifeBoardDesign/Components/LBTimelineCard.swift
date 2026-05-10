import SwiftUI

enum LBTimelineTemporalState: String, Equatable {
    case past
    case current
    case future
}

struct LBTimelineCard: View {
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
        let accessoryText: String?
        let temporalState: LBTimelineTemporalState
        let isCompleted: Bool
        let isToggleable: Bool
        let isCurrent: Bool
    }

    let model: Model
    let onTap: () -> Void
    var onToggleComplete: (() -> Void)?

    var body: some View {
        let style = LBColorTokens.role(model.role)
        Button(action: onTap) {
            LBGlassCard(cornerRadius: cornerRadius, borderColor: borderColor(style), fill: fillColor(style)) {
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
    }

    @ViewBuilder
    private func leadingControl(style: LBRoleStyle) -> some View {
        if model.kind == .task {
            Button(action: { onToggleComplete?() }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(model.isCompleted ? style.base : Color.white.opacity(model.temporalState == .past ? 0.52 : 0.92))
                        .frame(width: 34, height: 34)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(model.isCompleted ? style.base : style.base.opacity(model.temporalState == .past ? 0.42 : 0.85), lineWidth: 2)
                        }
                    Image(systemName: model.isCompleted ? "checkmark" : "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(model.isCompleted ? Color.white : style.base.opacity(0.0))
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
        return style.softSurface.opacity(model.temporalState == .past ? baseOpacity * 0.58 : baseOpacity)
    }

    private func borderColor(_ style: LBRoleStyle) -> Color {
        model.temporalState == .past ? style.border.opacity(0.48) : style.border
    }

    private func accessoryColor(_ style: LBRoleStyle) -> Color {
        model.temporalState == .past ? style.deep.opacity(0.62) : style.deep
    }

    private func accessoryFill(_ style: LBRoleStyle) -> Color {
        model.temporalState == .past ? style.softSurface.opacity(0.48) : style.softSurface
    }
}
