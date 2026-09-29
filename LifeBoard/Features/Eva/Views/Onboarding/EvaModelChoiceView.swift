import MLXLMCommon
import SwiftUI

struct EvaModelChoiceView: View {
    @Environment(\.lifeboardTokens) private var tokens
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    let selectedModelName: String?
    let onBack: () -> Void
    let onSelect: (String) -> Void
    let onContinue: () -> Void

    private let fastModel = ModelConfiguration.qwen_3_0_6b_4bit
    private let smarterModel = ModelConfiguration.qwen_3_5_0_8b_optiq_4bit

    private var spacing: SemanticSpacingTokens {
        tokens.spacing
    }

    private var resolvedSelection: String {
        selectedModelName ?? fastModel.name
    }

    private var primaryCTA: String {
        String(localized: "Download model")
    }

    var body: some View {
        EvaActivationStageView(
            footer: {
                EvaFooterButtons(
                    primaryTitle: primaryCTA,
                    secondaryTitle: String(localized: "Back"),
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
                    title: String(localized: "Choose a model"),
                    bodyText: String(localized: "Runs on \(DeviceNoun.this). Change it anytime in Settings.")
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

                Text("More models are in Settings.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
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
            badge: String(localized: "Recommended"),
            title: String(localized: "Fast"),
            descriptionText: String(localized: "Quick answers for daily planning and triage."),
            meta: "Qwen3 0.6B 4bit",
            note: String(localized: "Best for most people."),
            isSelected: resolvedSelection == fastModel.name,
            accessibilityID: "eva.activation.mode.fast",
            action: { onSelect(fastModel.name) }
        )
    }

    private var smarterCard: some View {
        EvaModeCard(
            badge: String(localized: "Deeper planning"),
            title: String(localized: "Smarter"),
            descriptionText: String(localized: "Better at tradeoffs and complex planning."),
            meta: "Qwen3.5 0.8B OptiQ 4bit",
            note: String(localized: "Uses more memory."),
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let badge {
                            Text(badge)
                                .font(.lifeboard(.caption1).weight(.semibold))
                                .foregroundStyle(Color.lifeboard(.accentPrimary))
                                .padding(.horizontal, Theme.Spacing.sm)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(Color.lifeboard(.surfacePrimary).opacity(0.9))
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.lifeboard(.accentMuted), lineWidth: 1)
                                )
                        }

                        Text(title)
                            .font(.lifeboard(.title3).weight(.semibold))
                            .foregroundStyle(Color.lifeboard(.textPrimary))
                    }

                    Spacer(minLength: Theme.Spacing.sm)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .lifeboardFont(.display)
                        .foregroundStyle(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.textTertiary))
                }

                Text(descriptionText)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                Text(meta)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))

                Text(note)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
            .background(isSelected ? Color.lifeboard(.accentWash) : Color.lifeboard(.surfacePrimary))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(isSelected ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.strokeHairline), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityID)
        .lifeboardPressFeedback()
        .animation(reduceMotion ? nil : LifeBoardAnimation.feedbackFast, value: isSelected)
    }
}
