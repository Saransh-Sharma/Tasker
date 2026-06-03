import SwiftUI

struct SunriseReflectPlanScreen: View {
    @ObservedObject var viewModel: DailyReflectPlanViewModel
    let onClose: () -> Void
    var onAddTask: (() -> Void)?
    var onChooseFocusWindow: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isContextExpanded = false

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        ZStack {
            ReflectPlanStyle.canvas.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .bottom) {
            StickySaveButton(
                title: viewModel.isSaving ? "Saving..." : "Save reflection & plan",
                isEnabled: viewModel.canSave,
                isSaving: viewModel.isSaving,
                statusMessage: footerStatusMessage,
                action: { viewModel.save() }
            )
        }
        .sheet(isPresented: Binding(
            get: { viewModel.activeSwapSlot != nil },
            set: { if !$0 { viewModel.activeSwapSlot = nil } }
        )) {
            if let slot = viewModel.activeSwapSlot {
                SwapTaskPicker(
                    slotIndex: slot,
                    currentTask: viewModel.editablePlan?.topTasks[safeReflectPlan: slot],
                    planningDate: viewModel.editablePlan?.planningDate ?? Date(),
                    options: viewModel.swapOptions(for: slot),
                    onUse: { option in viewModel.swapTask(slotIndex: slot, with: option) },
                    onCancel: { viewModel.activeSwapSlot = nil }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .confirmationDialog(
            "Discard reflection?",
            isPresented: Binding(
                get: { viewModel.closeAttempted },
                set: { if !$0 { viewModel.clearCloseAttempt() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                viewModel.discardChanges()
                close()
            }
            Button("Keep editing", role: .cancel) {
                viewModel.clearCloseAttempt()
            }
        } message: {
            Text("Your changes have not been saved.")
        }
        .onDisappear {
            viewModel.cancelLoading()
        }
        .accessibilityIdentifier("reflection.plan.screen")
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .loadingCore:
            loadingState
        case .idle where viewModel.isCompleteStateVisible:
            completeState
        case .coreFailed:
            failureState
        default:
            loadedState
        }
    }

    private var loadedState: some View {
        VStack(spacing: 0) {
            ReflectPlanHeader(
                isCatchUp: viewModel.target?.mode == .catchUpYesterday,
                onClose: attemptClose
            )

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: spacing.s16) {
                        if let coreSnapshot = viewModel.coreSnapshot {
                            YesterdaySummaryCard(snapshot: coreSnapshot)
                                .accessibilityIdentifier("reflection.plan.yesterday")
                        }

                        if let plan = viewModel.editablePlan {
                            TodayPlanCard(
                                plan: plan,
                                focusWindowText: viewModel.focusWindowLabel(for: plan),
                                protectedHabitText: viewModel.protectedHabitLabel(for: plan),
                                clearFirstText: viewModel.clearFirstLabel(for: plan),
                                planningStatusMessage: viewModel.planningStatusMessage,
                                onSwap: viewModel.requestSwap,
                                onAddTask: onAddTask,
                                onChooseFocusWindow: onChooseFocusWindow
                            )
                            .accessibilityIdentifier("reflection.plan.today")
                        } else {
                            TodayPlanCard(
                                plan: nil,
                                focusWindowText: "Not set yet",
                                protectedHabitText: "Not set yet",
                                clearFirstText: "Clear yesterday's carryover first so today doesn't stack.",
                                planningStatusMessage: viewModel.planningStatusMessage ?? "Building the smaller plan now.",
                                onSwap: viewModel.requestSwap,
                                onAddTask: onAddTask,
                                onChooseFocusWindow: onChooseFocusWindow
                            )
                        }

                        AddContextCard(
                            isExpanded: $isContextExpanded,
                            noteText: $viewModel.noteText,
                            selectedMood: viewModel.selectedMood,
                            selectedEnergy: viewModel.selectedEnergy,
                            selectedFrictionTags: viewModel.selectedFrictionTags,
                            onToggleMood: viewModel.toggleMood,
                            onToggleEnergy: viewModel.toggleEnergy,
                            onToggleFriction: viewModel.toggleFriction
                        )
                        .id("addContext")

                        if let successMessage = viewModel.successMessage {
                            feedbackText(successMessage, color: Color.lifeboard.textSecondary)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            feedbackText(errorMessage, color: Color.lifeboard.statusWarning)
                        }
                    }
                    .padding(.horizontal, spacing.s16)
                    .padding(.top, spacing.s8)
                    .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 132 : 104)
                }
                .scrollIndicators(.hidden)
                .onChange(of: isContextExpanded) { _, isExpanded in
                    LifeBoardFeedback.selection()
                    guard isExpanded else { return }
                    DispatchQueue.main.async {
                        withAnimation(reduceMotion ? nil : LifeBoardAnimation.snappy) {
                            proxy.scrollTo("addContext", anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            ReflectPlanHeader(isCatchUp: false, onClose: attemptClose)
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text("Preparing your reflection context")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text("Tasks and habits load first. Calendar details are added in the background.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, spacing.s16)
            Spacer()
        }
        .accessibilityIdentifier("reflection.plan.loading")
    }

    private var completeState: some View {
        VStack(spacing: spacing.s16) {
            ReflectPlanHeader(isCatchUp: false, onClose: attemptClose)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(Color.lifeboard.statusSuccess)
            Text("You're already closed out.")
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
            Text("There isn't an open reflection day right now.")
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, spacing.s24)
        .accessibilityIdentifier("reflection.plan.complete")
    }

    private var failureState: some View {
        VStack(spacing: spacing.s16) {
            ReflectPlanHeader(isCatchUp: false, onClose: attemptClose)
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color.lifeboard.statusWarning)
            Text(viewModel.errorMessage ?? "The reflection flow couldn't load.")
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: viewModel.load)
                .font(.lifeboard(.bodyEmphasis))
                .buttonStyle(.plain)
                .foregroundStyle(Color.lifeboard.accentPrimary)
                .frame(minWidth: 44, minHeight: 44)
            Spacer()
        }
        .padding(.horizontal, spacing.s24)
        .accessibilityIdentifier("reflection.plan.failure")
    }

    private var footerStatusMessage: String? {
        if let planningStatusMessage = viewModel.planningStatusMessage {
            return planningStatusMessage
        }
        if viewModel.isPlanningPlaceholderVisible {
            return "Building the smaller plan now."
        }
        if dynamicTypeSize.isAccessibilitySize {
            return "No typing is required."
        }
        return nil
    }

    private func feedbackText(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.lifeboard(.caption1))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(text)
    }

    private func attemptClose() {
        if viewModel.hasUnsavedChanges {
            viewModel.requestClose()
        } else {
            close()
        }
    }

    private func close() {
        onClose()
        dismiss()
    }
}

private extension Array {
    subscript(safeReflectPlan index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
