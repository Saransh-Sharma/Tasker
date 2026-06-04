import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingHabitRecommendationCard: View {
    let template: StarterHabitTemplate
    let projectName: String?
    let state: OnboardingHabitTemplateState
    let isGuidanceHighlighted: Bool
    let isSelectionEnabled: Bool
    let onAdd: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: template.icon.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconAccent)
                    .frame(width: 32, height: 32)
                    .background(iconAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(template.title)
                        .lifeboardFont(.bodyEmphasis)
                        .foregroundStyle(titleColor)
                    Text(template.reason)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                badge
                    .transition(.opacity)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    infoChip(ownershipLine)
                    infoChip(cadenceLine)
                    Spacer(minLength: 8)
                    actionButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        infoChip(ownershipLine)
                        infoChip(cadenceLine)
                    }
                    actionButton
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor, lineWidth: stateBorderWidth)
        )
        .animation(reduceMotion ? .none : .easeOut(duration: 0.25), value: state)
    }

    var actionButton: some View {
        Group {
            switch state {
            case .created:
                EmptyView()
            default:
                Button {
                    onAdd()
                } label: {
                    Label(buttonTitle, systemImage: buttonIcon)
                        .labelStyle(.titleAndIcon)
                        .lifeboardFont(.buttonSmall)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 12)
                        .background(buttonBackground, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(buttonBorder, lineWidth: 1)
                        }
                }
                .buttonStyle(OnboardingPressScaleButtonStyle())
                .foregroundStyle(state == .creating || isSelectionEnabled == false ? OnboardingTheme.textSecondary : OnboardingTheme.textPrimary)
                .disabled(state == .creating || isSelectionEnabled == false)
            }
        }
    }

    func infoChip(_ title: String) -> some View {
        Text(title)
            .lifeboardFont(.caption2)
            .foregroundStyle(OnboardingTheme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(OnboardingTheme.surfaceMuted, in: Capsule())
    }

    var ownershipLine: String {
        if let projectName, projectName.isEmpty == false {
            return "\(lifeAreaName) · \(projectName)"
        }
        return lifeAreaName
    }

    var lifeAreaName: String {
        StarterWorkspaceCatalog.lifeAreaTemplate(id: template.lifeAreaTemplateID)?.name ?? "Habit"
    }

    var cadenceLine: String {
        switch template.cadence {
        case .daily:
            return template.isPositive ? "Daily" : "Daily check-in"
        case .weekly(let daysOfWeek, _, _):
            return daysOfWeek.count > 1 ? "Weekdays" : "Weekly"
        }
    }

    var buttonIcon: String {
        switch state {
        case .idle:
            return "plus"
        case .creating:
            return "hourglass"
        case .created:
            return "checkmark"
        case .failed:
            return "arrow.clockwise"
        }
    }

    var buttonTitle: String {
        switch state {
        case .idle:
            return isSelectionEnabled ? "Add" : "Added 2"
        case .creating:
            return "Adding…"
        case .created:
            return "Added"
        case .failed:
            return isSelectionEnabled ? "Try again" : "Added 2"
        }
    }

    var buttonBackground: Color {
        if isSelectionEnabled == false {
            return OnboardingTheme.surfaceMuted
        }
        switch state {
        case .creating:
            return OnboardingTheme.surfaceMuted
        case .failed:
            return OnboardingTheme.danger.opacity(0.10)
        default:
            return OnboardingTheme.accent.opacity(0.12)
        }
    }

    var buttonBorder: Color {
        switch state {
        case .failed:
            return OnboardingTheme.danger.opacity(0.6)
        case .creating:
            return OnboardingTheme.borderSoft
        default:
            return isGuidanceHighlighted ? OnboardingTheme.accent.opacity(0.42) : OnboardingTheme.borderSoft
        }
    }

    var titleColor: Color {
        switch state {
        case .failed:
            return OnboardingTheme.danger
        default:
            return OnboardingTheme.textPrimary
        }
    }

    var backgroundColor: Color {
        switch state {
        case .created:
            return OnboardingTheme.accent.opacity(0.10)
        case .failed:
            return OnboardingTheme.danger.opacity(0.08)
        default:
            return isSelectionEnabled ? OnboardingTheme.surface : OnboardingTheme.surfaceMuted
        }
    }

    var borderColor: Color {
        switch state {
        case .created:
            return OnboardingTheme.accent.opacity(0.28)
        case .failed:
            return OnboardingTheme.danger.opacity(0.7)
        default:
            return isSelectionEnabled ? OnboardingTheme.border : OnboardingTheme.borderSoft
        }
    }

    var stateBorderWidth: CGFloat {
        switch state {
        case .created, .failed:
            return 1.5
        default:
            return 1
        }
    }

    var iconAccent: Color {
        template.isPositive ? OnboardingTheme.accent : OnboardingTheme.textPrimary
    }

    @ViewBuilder
    var badge: some View {
        switch state {
        case .created:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(OnboardingTheme.accent)
        case .creating:
            OnboardingInlineBadge(title: "Saving", accent: OnboardingTheme.accent)
        case .failed:
            OnboardingInlineBadge(title: "Needs retry", accent: OnboardingTheme.danger)
        case .idle:
            EmptyView()
        }
    }
}
