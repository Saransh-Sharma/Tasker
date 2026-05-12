import SwiftUI

struct AgendaRowBadgeView: View {
    let badge: AgendaRowStateBadge

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage = badge.systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(badge.text)
                .font(.lifeboard(.caption2).weight(.semibold))
        }
        .foregroundStyle(textColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(fillColor)
        .overlay(
            Capsule(style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    private var textColor: Color {
        switch badge.tone {
        case .neutral, .quiet:
            return Color.lifeboard.textSecondary
        case .accent:
            return Color.lifeboard.accentPrimary
        case .success:
            return Color.lifeboard.statusSuccess
        case .warning:
            return Color.lifeboard.statusWarning
        case .danger:
            return Color.lifeboard.statusDanger
        }
    }

    private var fillColor: Color {
        switch badge.tone {
        case .neutral, .quiet:
            return Color.lifeboard.surfacePrimary
        case .accent:
            return Color.lifeboard.accentWash
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.14)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.14)
        case .danger:
            return Color.lifeboard.statusDanger.opacity(0.14)
        }
    }

    private var strokeColor: Color {
        switch badge.tone {
        case .neutral, .quiet:
            return Color.lifeboard.strokeHairline.opacity(0.85)
        case .accent:
            return Color.lifeboard.accentPrimary.opacity(0.24)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.24)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.26)
        case .danger:
            return Color.lifeboard.statusDanger.opacity(0.28)
        }
    }
}

struct AgendaRowScaffold: View {
    let presentationModel: AgendaRowPresentationModel
    let fillColor: Color
    let borderColor: Color
    let accentColor: Color
    let isResolved: Bool
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityHint: String
    let leading: AnyView
    var supplementary: AnyView? = nil
    var footer: AnyView? = nil
    var actions: AnyView? = nil

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                leading

                VStack(alignment: .leading, spacing: spacing.titleSubtitleGap) {
                    Text(presentationModel.title)
                        .font(.lifeboard(.body))
                        .foregroundStyle(Color.lifeboard.textPrimary.opacity(isResolved ? 0.88 : 1.0))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if let metadataLine = presentationModel.metadataLine {
                        Text(metadataLine)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: spacing.s8) {
                        AgendaRowBadgeView(badge: presentationModel.primaryBadge)
                        if let secondaryBadge = presentationModel.secondaryBadge {
                            AgendaRowBadgeView(badge: secondaryBadge)
                        }
                    }

                    if let secondaryLine = presentationModel.secondaryLine {
                        Text(secondaryLine)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let supplementary {
                    supplementary
                }
            }

            if let footer {
                footer
            }

            if let actions, isResolved == false {
                actions
            }
        }
        .padding(spacing.s12)
        .background(fillColor)
        .overlay(
            RoundedRectangle(cornerRadius: corner.card, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: corner.card, style: .continuous))
        .overlay(alignment: .topLeading) {
            Capsule(style: .continuous)
                .fill(accentColor.opacity(isResolved ? 0.55 : 0.92))
                .frame(width: isResolved ? 36 : 48, height: 3)
                .padding(.horizontal, spacing.s16)
                .padding(.top, 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(accessibilityHint)
        .animation(reduceMotion ? .linear(duration: 0.01) : LifeBoardAnimation.stateChange, value: presentationModel)
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}
