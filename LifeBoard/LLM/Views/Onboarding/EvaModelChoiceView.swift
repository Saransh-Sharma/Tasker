import MLXLMCommon
import SwiftUI

struct EvaModelChoiceView: View {
    @Environment(\.taskerLayoutClass) private var layoutClass
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    let selectedModelName: String?
    let onBack: () -> Void
    let onSelect: (String) -> Void
    let onContinue: () -> Void

    private let fastModel = ModelConfiguration.qwen_3_0_6b_4bit
    private let smarterModel = ModelConfiguration.qwen_3_5_0_8b_optiq_4bit

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var resolvedSelection: String {
        selectedModelName ?? fastModel.name
    }

    private var primaryCTA: String {
        resolvedSelection == smarterModel.name ? "Install Smarter" : "Install Fast"
    }

    var body: some View {
        EvaActivationStageView(
            footer: {
                EvaFooterButtons(
                    primaryTitle: primaryCTA,
                    secondaryTitle: "Back",
                    isPrimaryDisabled: false,
                    onPrimary: {
                        onSelect(resolvedSelection)
                        onContinue()
                    },
                    onSecondary: onBack
                )
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                EvaContentHeader(
                    title: "Choose how \(assistantIdentity.snapshot.displayName) works",
                    bodyText: "Pick a default mode for your private assistant. You can change this later in Models."
                )
                .enhancedStaggeredAppearance(index: 0)

                Group {
                    if layoutClass.isPad {
                        HStack(alignment: .top, spacing: spacing.sectionGap) {
                            fastCard
                            smarterCard
                        }
                    } else {
                        VStack(spacing: spacing.s12) {
                            fastCard
                            smarterCard
                        }
                    }
                }
                .enhancedStaggeredAppearance(index: 1)

                Text("Other models stay available later in Settings.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .enhancedStaggeredAppearance(index: 2)
            }
        }
        .onAppear {
            if selectedModelName == nil {
                onSelect(fastModel.name)
            }
        }
        .accessibilityIdentifier("eva.activation.model_choice")
    }

    private var fastCard: some View {
        EvaModeCard(
            badge: "Recommended",
            title: "Fast",
            descriptionText: "Quickest startup. Best for daily planning, task triage, and fast help.",
            meta: "Qwen3 0.6B 4bit",
            note: "Best default for most people.",
            isSelected: resolvedSelection == fastModel.name,
            accessibilityID: "eva.activation.mode.fast",
            action: { onSelect(fastModel.name) }
        )
    }

    private var smarterCard: some View {
        EvaModeCard(
            badge: "Deeper planning",
            title: "Smarter",
            descriptionText: "More thoughtful answers for deeper planning, tradeoffs, and complex prioritization.",
            meta: "Qwen3.5 0.8B OptiQ 4bit",
            note: "Uses slightly more memory.",
            isSelected: resolvedSelection == smarterModel.name,
            accessibilityID: "eva.activation.mode.smarter",
            action: { onSelect(smarterModel.name) }
        )
    }
}

private struct EvaModeCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let badge: String?
    let title: String
    let descriptionText: String
    let meta: String
    let note: String
    let isSelected: Bool
    let accessibilityID: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: TaskerTheme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let badge {
                            Text(badge)
                                .font(.tasker(.caption1).weight(.semibold))
                                .foregroundStyle(Color.tasker(.accentPrimary))
                                .padding(.horizontal, TaskerTheme.Spacing.sm)
                                .padding(.vertical, TaskerTheme.Spacing.xs)
                                .background(Color.tasker(.surfacePrimary).opacity(0.9))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.tasker(.accentMuted), lineWidth: 1)
                                )
                        }

                        Text(title)
                            .font(.tasker(.title3).weight(.semibold))
                            .foregroundStyle(Color.tasker(.textPrimary))
                    }

                    Spacer(minLength: TaskerTheme.Spacing.sm)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.textTertiary))
                }

                Text(descriptionText)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                Text(meta)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))

                Text(note)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
            .background(isSelected ? Color.tasker(.accentWash) : Color.tasker(.surfacePrimary))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.strokeHairline), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
        .taskerPressFeedback(reduceMotion: reduceMotion)
        .animation(reduceMotion ? nil : TaskerAnimation.quick, value: isSelected)
    }
}
