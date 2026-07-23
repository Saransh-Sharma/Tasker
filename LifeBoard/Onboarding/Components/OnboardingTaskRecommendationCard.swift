import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

struct OnboardingTaskRecommendationCard: View {
    let template: StarterTaskTemplate
    let state: OnboardingTaskTemplateState
    let isGuidanceHighlighted: Bool
    let showsIdleBadge: Bool
    let accessibilityIdentifier: String
    let onAdd: () -> Void
    let onEdit: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
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
                    metaChip("\(template.durationMinutes) min")
                    metaChip("+\(XPCalculationEngine.completionXPIfCompletedNow(priorityRaw: template.priority.rawValue, estimatedDuration: TimeInterval(template.durationMinutes * 60), dueDate: template.dueDateIntent.resolvedDate(), isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled).awardedXP) XP")
                    Spacer()
                    actionButton
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        metaChip("\(template.durationMinutes) min")
                        metaChip("+\(XPCalculationEngine.completionXPIfCompletedNow(priorityRaw: template.priority.rawValue, estimatedDuration: TimeInterval(template.durationMinutes * 60), dueDate: template.dueDateIntent.resolvedDate(), isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled).awardedXP) XP")
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
                .foregroundStyle(state == .creating ? OnboardingTheme.textSecondary : OnboardingTheme.textPrimary)
                .disabled(state == .creating)
                .accessibilityIdentifier(accessibilityIdentifier)
            }
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

    var buttonBackground: Color {
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

    var buttonTitle: String {
        switch state {
        case .idle:
            return "Choose"
        case .creating:
            return "Choosing…"
        case .created:
            return "Choose"
        case .failed:
            return "Try again"
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
            return OnboardingTheme.surface
        }
    }

    var borderColor: Color {
        switch state {
        case .created:
            return OnboardingTheme.accent.opacity(0.28)
        case .failed:
            return OnboardingTheme.danger.opacity(0.7)
        default:
            return OnboardingTheme.border
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
            if showsIdleBadge {
                OnboardingInlineBadge(title: "Recommended", accent: OnboardingTheme.accent)
            }
        }
    }

    func metaChip(_ title: String) -> some View {
        Text(title)
            .lifeboardFont(.caption2)
            .foregroundStyle(OnboardingTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(OnboardingTheme.surfaceMuted, in: Capsule())
    }
}
