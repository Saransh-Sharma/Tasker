import SwiftUI

struct EvaGoalsView: View {
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var draft: EvaProfileDraft

    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var draftGoalText = ""

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var normalizedGoals: [String] {
        draft.goals
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private var trimmedDraftGoal: String {
        draftGoalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canAddGoal: Bool {
        trimmedDraftGoal.isEmpty == false && normalizedGoals.count < 3
    }

    var body: some View {
        EvaActivationStageView(
            footer: {
                EvaFooterButtons(
                    primaryTitle: "Continue",
                    secondaryTitle: "Back",
                    isPrimaryDisabled: normalizedGoals.isEmpty,
                    onPrimary: onContinue,
                    onSecondary: onBack
                )
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                mainColumn
                EvaReviewCard(draft: sanitizedDraft)
                    .enhancedStaggeredAppearance(index: 2)
            }
        }
        .onAppear(perform: normalizeDraftGoals)
        .accessibilityIdentifier("eva.activation.goals")
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            EvaContentHeader(
                title: "What matters most this week?",
                bodyText: "Add 1 to 3 outcomes, not tasks. Eva will keep these in view when helping you decide what to do next."
            )
            .enhancedStaggeredAppearance(index: 0)

            EvaSectionCard(
                title: "Outcomes",
                subtitle: "Add 1 to 3 outcomes. Keep them clear and directional.",
                accessibilityIdentifier: "eva.activation.goals.card"
            ) {
                if normalizedGoals.isEmpty {
                    Text("No goals added yet")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
                } else {
                    EvaFlowLayout(spacing: spacing.s8, rowSpacing: spacing.s8) {
                        ForEach(Array(normalizedGoals.enumerated()), id: \.offset) { index, goal in
                            EvaGoalChip(
                                title: goal,
                                accessibilityIdentifier: "eva.activation.goal_chip.\(index)"
                            ) {
                                removeGoal(goal)
                            }
                        }
                    }
                }

                if normalizedGoals.count < 3 {
                    EvaGoalComposer(
                        placeholder: "Example: Finish the client handoff plan",
                        accessibilityIdentifier: "eva.activation.goals.composer",
                        draftText: $draftGoalText,
                        isDisabled: !canAddGoal
                    ) {
                        addGoal()
                    }
                    .animation(reduceMotion ? nil : TaskerAnimation.quick, value: canAddGoal)
                }
            }
            .enhancedStaggeredAppearance(index: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onSubmit(of: .text, addGoal)
    }

    private var sanitizedDraft: EvaProfileDraft {
        var copy = draft
        copy.goals = normalizedGoals
        return copy
    }

    private func normalizeDraftGoals() {
        if draft.goals != normalizedGoals {
            draft.goals = normalizedGoals
        }
    }

    private func addGoal() {
        guard canAddGoal else { return }

        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : TaskerAnimation.quick) {
            draft.goals = normalizedGoals + [trimmedDraftGoal]
            draftGoalText = ""
        }
    }

    private func removeGoal(_ goal: String) {
        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : TaskerAnimation.quick) {
            draft.goals = normalizedGoals.filter { $0 != goal }
        }
    }
}
