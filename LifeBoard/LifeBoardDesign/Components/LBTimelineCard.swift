import SwiftUI

enum LBTimelineTemporalState: String, Equatable {
    case past
    case current
    case future
}

/// Shared pressed feedback for tappable Sunrise cards: a subtle settle rather
/// than a button-like bounce, per the design-language pressed spec (0.985).
struct LBPressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && reduceMotion == false ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
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
        let tintHex: String?
        let accessoryText: String?
        let temporalState: LBTimelineTemporalState
        let isCompleted: Bool
        let isCurrent: Bool
    }

    let model: Model
    let onTap: () -> Void

    nonisolated static func == (lhs: LBTimelineCard, rhs: LBTimelineCard) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        if let routineStyle {
            TimelineRoutineAnchorCard(
                style: routineStyle,
                timeText: model.timeText,
                onTap: onTap,
                minimumHeight: 96,
                leadingArtworkReserve: 96
            )
            .accessibilityIdentifier(accessibilityIdentifier)
        } else {
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
                    .frame(minHeight: minimumHeight, alignment: .center)
                }
            }
            .buttonStyle(LBPressableCardStyle())
            .animation(.easeOut(duration: 0.22), value: model.isCompleted)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier(accessibilityIdentifier)
        }
    }

    private var routineStyle: TimelineRoutineAnchorVisualStyle? {
        guard model.kind == .anchor else { return nil }
        return TimelineRoutineAnchorVisualStyle.resolve(
            anchorID: model.id,
            title: model.title,
            subtitle: model.subtitle
        )
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

    private var accessibilityLabel: String {
        [
            accessibilityKind,
            model.title,
            model.subtitle.isEmpty ? model.timeText : "\(model.timeText), \(model.subtitle)"
        ]
        .filter { $0.isEmpty == false }
        .joined(separator: ", ")
    }

    private var accessibilityKind: String {
        switch model.kind {
        case .anchor: return "Routine"
        case .calendar: return "Meeting"
        case .task: return "Task"
        }
    }

    private var accessibilityValue: String {
        model.kind == .task ? (model.isCompleted ? "Completed" : "Not completed") : ""
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

    /// Non-anchor cards keep the 66pt design-language minimum so short titles
    /// still read as substantial, tappable day blocks.
    private var minimumHeight: CGFloat? {
        model.kind == .anchor ? nil : 66
    }

    private var titleColor: Color {
        if model.isCompleted && model.kind == .task {
            return LBColorTokens.navyMuted
        }
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
