import SwiftUI

struct EvaGoalsView: View {
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var draft: EvaProfileDraft

    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var draftGoalText = ""
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var normalizedGoals: [String] {
        normalizedStoredGoals(from: draft.goals)
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
                bodyText: "Add 1 to 3 outcomes, not tasks. \(assistantIdentity.snapshot.displayName) will keep these in view when helping you decide what to do next."
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
                                removeGoal(at: index)
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
        mutateGoals {
            draft.goals = normalizedStoredGoals(from: draft.goals + [trimmedDraftGoal])
            draftGoalText = ""
        }
    }

    private func removeGoal(at index: Int) {
        guard normalizedGoals.indices.contains(index) else { return }
        mutateGoals {
            var updatedGoals = normalizedGoals
            updatedGoals.remove(at: index)
            draft.goals = updatedGoals
        }
    }

    private func mutateGoals(_ mutation: () -> Void) {
        if reduceMotion {
            mutation()
        } else {
            withAnimation(TaskerAnimation.quick, mutation)
        }
    }

    private func normalizedStoredGoals(from goals: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for goal in goals {
            let trimmed = goal.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { continue }

            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }

            normalized.append(trimmed)
            if normalized.count == 3 {
                break
            }
        }

        return normalized
    }
}
