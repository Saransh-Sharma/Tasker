import SwiftUI
import UIKit
import Combine
import CoreHaptics
import AVFoundation
import Network
import MLXLMCommon

extension AppOnboardingJourneyView {
    var homeDemoStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.HomeDemo.title,
                subtitle: OnboardingCopy.HomeDemo.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.homeDemo)

            OnboardingSelectionSummaryCard(
                title: "\(viewModel.selectedMascotPersona.displayName) will point at the next move",
                message: "Try the two gestures you will use most: complete one task and mark one habit done.",
                mascotPlacement: .onboardingCaptureSetup
            )

            OnboardingHomeDemoPreview(
                assistantName: viewModel.selectedMascotPersona.displayName,
                selectedMascotID: viewModel.selectedMascotID,
                taskDone: viewModel.didCompleteHomeDemoTask,
                habitDone: viewModel.didCompleteHomeDemoHabit,
                onTaskDone: {
                    feedbackController.successSignature()
                    viewModel.markHomeDemoTaskDone()
                    continueHomeDemoAfterDemoAction()
                },
                onHabitDone: {
                    feedbackController.successSignature()
                    viewModel.markHomeDemoHabitDone()
                    continueHomeDemoAfterDemoAction()
                }
            )
        }
    }

    var focusRoomStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            if let presentation = viewModel.starterHabitBoardPresentation {
                OnboardingCompactHabitRail(presentation: presentation, evaState: viewModel.evaPreparationState)
            }

            if let parent = viewModel.parentFocusTask {
                HStack(spacing: spacing.s8) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundStyle(OnboardingTheme.textSecondary)
                    Text("From: \(parent.title)")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(OnboardingTheme.textSecondary)
                }
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s8)
                .background(OnboardingTheme.surfaceMuted, in: Capsule())
            }

            if let task = viewModel.focusTask {
                OnboardingFocusHeroCard(
                    task: task,
                    projectName: viewModel.resolvedProjects.first(where: { $0.project.id == task.projectID })?.project.name ?? task.projectName ?? "Project",
                    xpAward: XPCalculationEngine.completionXPIfCompletedNow(
                        priorityRaw: task.priority.rawValue,
                        estimatedDuration: task.estimatedDuration,
                        dueDate: task.dueDate,
                        isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled
                    ).awardedXP,
                    isActive: viewModel.focusIsActive,
                    startedAt: viewModel.focusStartedAt,
                    onPrimary: {
                        if viewModel.focusIsActive {
                            Task { await viewModel.completeFocusTask() }
                        } else {
                            feedbackController.medium()
                            viewModel.startFocusNow()
                        }
                    },
                    onBreakDown: {
                        feedbackController.light()
                        Task { await viewModel.generateBreakdownSuggestions() }
                    }
                )
            }
        }
    }

    var habitCheckInStep: some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.HabitCheckIn.title,
                subtitle: OnboardingCopy.HabitCheckIn.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.habitCheckIn)

            if let presentation = viewModel.starterHabitBoardPresentation {
                OnboardingHabitStreakPreviewCard(presentation: presentation)
            }

            if let habit = viewModel.starterHabit {
                OnboardingSelectionSummaryCard(
                    title: habit.kind == .positive ? "Build \(habit.title)" : "Protect \(habit.title)",
                    message: habit.kind == .positive
                        ? "Mark it done now or skip today and keep the board honest."
                        : "Mark a clean day now or log a lapse honestly. The board updates either way.",
                    mascotPlacement: habit.kind == .positive ? .habitStreakWin : .habitRecovery
                )
            }
        }
    }

    var calendarPermissionStep: some View {
        VStack(alignment: .center, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.Calendar.title,
                subtitle: OnboardingCopy.Calendar.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.calendarPermission)
            .multilineTextAlignment(.center)

            OnboardingPermissionHeroIcon(
                systemName: "calendar.badge.checkmark",
                primaryColor: OnboardingTheme.marigold,
                secondaryColor: OnboardingTheme.accentSecondary,
                accessibilityLabel: "Calendar access",
                accessibilityIdentifier: AppOnboardingAccessibilityID.calendarPermissionHero
            )

            OnboardingSelectionSummaryCard(
                title: "Why it matters",
                message: "When LifeBoard can see your schedule, your tasks and habits can fit around the day you actually have.",
                mascotPlacement: .onboardingCalendarPermission
            )
        }
    }

    var notificationPermissionStep: some View {
        VStack(alignment: .center, spacing: spacing.sectionGap) {
            OnboardingSectionHeader(
                title: OnboardingCopy.Notifications.title,
                subtitle: OnboardingCopy.Notifications.subtitle
            )
            .accessibilityIdentifier(AppOnboardingAccessibilityID.notificationPermission)
            .multilineTextAlignment(.center)

            OnboardingPermissionHeroIcon(
                systemName: "bell.badge.fill",
                primaryColor: OnboardingTheme.marigold,
                secondaryColor: OnboardingTheme.accent,
                accessibilityLabel: "Reminder notifications",
                accessibilityIdentifier: AppOnboardingAccessibilityID.notificationPermissionHero
            )

            OnboardingSelectionSummaryCard(
                title: "What you will get",
                message: "Reminders for your first task, starter habit, and missed check-ins.",
                mascotPlacement: .onboardingNotificationPermission
            )
        }
    }

    func successView(summary: AppOnboardingSummary) -> some View {
        VStack(alignment: .leading, spacing: spacing.sectionGap) {
            OnboardingSuccessHero()
                .accessibilityIdentifier(AppOnboardingAccessibilityID.success)

            OnboardingSuccessSummaryCard(
                areaNames: viewModel.resolvedLifeAreas.map(\.lifeArea.name),
                projectNames: viewModel.resolvedProjects.map(\.project.name),
                habitTitles: summary.createdHabitTitles,
                completedTaskTitle: summary.completedTaskTitle
            )

            if let presentation = viewModel.starterHabitBoardPresentation {
                OnboardingHabitStreakPreviewCard(presentation: presentation)
            }

            OnboardingEvaStatusCard(state: summary.evaState, assistantName: viewModel.selectedMascotPersona.displayName)

            if summary.evaState.isReady {
                Button(AssistantIdentityText.askAction(for: viewModel.selectedMascotID)) {
                    viewModel.finishOnboarding()
                    onDismissFlow()
                }
                .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
            }
        }
    }

    func onboardingProjectName(for template: StarterHabitTemplate) -> String? {
        guard let projectTemplateID = template.projectTemplateID else { return nil }
        return viewModel.resolvedProjects.first(where: { $0.draft.templateID == projectTemplateID })?.project.name
    }

    func onboardingHabitPrefill() -> AddHabitPrefillTemplate? {
        if let template = viewModel.primaryHabitSuggestions.first,
           let resolvedLifeArea = viewModel.resolvedLifeAreas.first(where: { $0.templateID == template.lifeAreaTemplateID }) {
            let projectID = template.projectTemplateID.flatMap { projectTemplateID in
                viewModel.resolvedProjects.first(where: { $0.draft.templateID == projectTemplateID })?.project.id
            }
            return template.makePrefill(lifeAreaID: resolvedLifeArea.lifeArea.id, projectID: projectID)
        }

        guard let lifeArea = viewModel.resolvedLifeAreas.first?.lifeArea else { return nil }
        let projectID = viewModel.resolvedProjects.first?.project.id
        return AddHabitPrefillTemplate(
            title: "",
            lifeAreaID: lifeArea.id,
            projectID: projectID
        )
    }

    var breakdownSheet: some View {
        NavigationStack {
            List {
                if let banner = viewModel.breakdownRouteBanner, banner.isEmpty == false {
                    Section {
                        Text(banner)
                            .lifeboardFont(.caption1)
                            .foregroundStyle(OnboardingTheme.textSecondary)
                    }
                }

                Section("Ask your AI coach") {
                    ForEach(viewModel.breakdownSteps) { step in
                        Button {
                            viewModel.toggleBreakdownStep(step.id)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: step.isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(step.isSelected ? OnboardingTheme.accent : OnboardingTheme.textSecondary)
                                Text(step.title)
                                    .foregroundStyle(OnboardingTheme.textPrimary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.breakdownIsLoading {
                    Section {
                        ProgressView("Refining steps…")
                            .tint(OnboardingTheme.accent)
                    }
                }
            }
            .navigationTitle("AI coach")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.breakdownSheetPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add selected") {
                        Task { await viewModel.applySelectedBreakdownSteps() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    var downloadChrome: some View {
        if viewModel.evaPreparationState.phase == .downloading ||
            viewModel.evaPreparationState.phase == .waitingForCellularConsent ||
            viewModel.evaPreparationState.phase == .deferred {
            if viewModel.step == .evaValue {
                OnboardingDownloadStatusPill(
                    state: viewModel.evaPreparationState,
                    assistantName: viewModel.selectedMascotPersona.displayName
                )
            } else {
                OnboardingDownloadStatusStrip(
                    state: viewModel.evaPreparationState,
                    assistantName: viewModel.selectedMascotPersona.displayName
                )
            }
        }
    }

    var bottomDock: some View {
        let dockContent = VStack(spacing: spacing.s12) {
            if let errorMessage = viewModel.errorMessage, errorMessage.isEmpty == false {
                Text(errorMessage)
                    .lifeboardFont(.caption1)
                    .foregroundStyle(OnboardingTheme.danger)
                    .multilineTextAlignment(.center)
            }

            if viewModel.step == .lifeAreas {
                dockSecondaryContent
                    .frame(maxWidth: layoutClass.isPad ? 520 : .infinity, alignment: .center)
            }

            if isKeyboardEditing == false, let action = floatingPrimaryAction {
                OnboardingFloatingNextButton(
                    action: action,
                    theme: currentVisualTheme
                )
            } else if viewModel.step == .processing {
                ProgressView()
                    .tint(currentVisualTheme.next)
                    .padding(18)
                    .background(.regularMaterial, in: Circle())
                    .accessibilityLabel("Preparing setup")
            }

            if viewModel.step != .lifeAreas {
                dockSecondaryContent
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }

        return dockContent
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, spacing.s12)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.18)
                    .ignoresSafeArea()
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, spacing.s12)
            .padding(.bottom, max(spacing.s8, 8))
    }

    @ViewBuilder
    var dockSecondaryContent: some View {
        switch viewModel.step {
        case .lifeAreas:
            Text(OnboardingCopy.LifeAreas.helper)
                .lifeboardFont(.caption1)
                .foregroundStyle(OnboardingTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .processing where viewModel.evaPreparationState.phase == .waitingForCellularConsent:
            Button("Wait for Wi-Fi") {
                feedbackController.light()
                viewModel.deferEvaDownload()
            }
            .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
        case .habitCheckIn:
            Button(viewModel.starterHabit?.kind == .positive ? "Skip today" : "Lapsed") {
                feedbackController.light()
                Task { await viewModel.performStarterHabitSecondaryAction() }
            }
            .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
        case .calendarPermission:
            Button("Skip for now") {
                feedbackController.light()
                Task { await viewModel.continueFromCalendarPermission(skipped: true) }
            }
            .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
        case .notificationPermission:
            Button("Skip for now") {
                feedbackController.light()
                Task { await viewModel.continueFromNotificationPermission(skipped: true) }
            }
            .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
        case .success where viewModel.evaPreparationState.isReady:
            Button(AssistantIdentityText.askAction(for: viewModel.selectedMascotID)) {
                feedbackController.light()
                viewModel.finishOnboarding()
                onDismissFlow()
            }
            .onboardingSecondaryButtonStyle(accent: OnboardingTheme.accent)
            .accessibilityIdentifier(AppOnboardingAccessibilityID.breakdownNext)
        default:
            EmptyView()
        }
    }
}
