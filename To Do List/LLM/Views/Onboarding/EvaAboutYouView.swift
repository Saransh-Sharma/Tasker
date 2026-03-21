import SwiftUI

struct EvaAboutYouView: View {
    @Environment(\.taskerLayoutClass) private var layoutClass

    @Binding var draft: EvaProfileDraft

    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var isWorkingStyleNoteExpanded = false
    @State private var isMomentumNoteExpanded = false

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var canContinue: Bool {
        draft.selectedWorkingStyleIDs.isEmpty == false
            || draft.selectedMomentumBlockerIDs.isEmpty == false
            || (draft.customWorkingStyleNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            || (draft.customMomentumNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    var body: some View {
        EvaActivationStageView(
            footer: {
                EvaFooterButtons(
                    primaryTitle: "Continue",
                    secondaryTitle: "Back",
                    isPrimaryDisabled: !canContinue,
                    onPrimary: onContinue,
                    onSecondary: onBack
                )
            }
        ) {
            mainContent
        }
        .accessibilityIdentifier("eva.activation.about_you")
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            EvaContentHeader(
                title: "How should Eva help you?",
                bodyText: "A quick setup so Eva can support your working style and protect your momentum from the start."
            )
            .enhancedStaggeredAppearance(index: 0)

            EvaSectionCard(
                title: "Working style",
                subtitle: "Choose up to 3",
                accessibilityIdentifier: "eva.activation.about_you.working_style"
            ) {
                EvaFlowLayout(spacing: spacing.s8, rowSpacing: spacing.s8) {
                    ForEach(Array(EvaWorkingStyleID.allCases.enumerated()), id: \.element.id) { _, style in
                        EvaSelectionChip(
                            title: style.title,
                            isSelected: draft.selectedWorkingStyleIDs.contains(style.rawValue),
                            accessibilityIdentifier: "eva.activation.style.\(style.rawValue)"
                        ) {
                            toggle(style.rawValue, in: &draft.selectedWorkingStyleIDs, limit: 3)
                        }
                    }
                }

                EvaCollapsedNoteField(
                    title: "Anything else about how Eva should help?",
                    collapsedTitle: "Add a note",
                    placeholder: "Example: Push me toward the highest-leverage task first",
                    accessibilityIdentifier: "eva.activation.about_you.working_style_note",
                    text: Binding(
                        get: { draft.customWorkingStyleNote ?? "" },
                        set: { draft.customWorkingStyleNote = $0 }
                    ),
                    isExpanded: $isWorkingStyleNoteExpanded
                )
            }
            .enhancedStaggeredAppearance(index: 1)

            EvaSectionCard(
                title: "Momentum blockers",
                subtitle: "Choose up to 3",
                accessibilityIdentifier: "eva.activation.about_you.blockers"
            ) {
                EvaFlowLayout(spacing: spacing.s8, rowSpacing: spacing.s8) {
                    ForEach(Array(EvaMomentumBlockerID.allCases.enumerated()), id: \.element.id) { _, blocker in
                        EvaSelectionChip(
                            title: blocker.title,
                            isSelected: draft.selectedMomentumBlockerIDs.contains(blocker.rawValue),
                            accessibilityIdentifier: "eva.activation.blocker.\(blocker.rawValue)"
                        ) {
                            toggle(blocker.rawValue, in: &draft.selectedMomentumBlockerIDs, limit: 3)
                        }
                    }
                }

                EvaCollapsedNoteField(
                    title: "Anything Eva should watch for?",
                    collapsedTitle: "Add a note",
                    placeholder: "Example: I avoid the hardest task until late in the day",
                    accessibilityIdentifier: "eva.activation.about_you.momentum_note",
                    text: Binding(
                        get: { draft.customMomentumNote ?? "" },
                        set: { draft.customMomentumNote = $0 }
                    ),
                    isExpanded: $isMomentumNoteExpanded
                )
            }
            .enhancedStaggeredAppearance(index: 2)

            Text("Saved locally. You can edit this later.")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
                .enhancedStaggeredAppearance(index: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ rawValue: String, in values: inout [String], limit: Int) {
        if values.contains(rawValue) {
            values.removeAll { $0 == rawValue }
            return
        }

        guard values.count < limit else { return }
        values.append(rawValue)
    }
}
