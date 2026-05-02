import SwiftUI

struct EvaChatNavigationChromeState {
    let title: String
    let subtitle: String
    let showsUtilityActions: Bool
    let showsHistoryAction: Bool
    let showsNewChatAction: Bool

    static var empty: EvaChatNavigationChromeState {
        EvaChatNavigationChromeState(
            title: AssistantIdentityText.currentSnapshot().displayName,
            subtitle: "Ask or use / commands",
            showsUtilityActions: true,
            showsHistoryAction: true,
            showsNewChatAction: false
        )
    }
}

struct ChatHeaderView: View {
    let identity: AssistantIdentitySnapshot
    let title: String
    let subtitle: String
    let showsNewChatAction: Bool
    let showsUtilityActions: Bool
    let onStartNewChat: () -> Void
    let onShowSettings: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: TaskerTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(identity.displayName)
                    .taskerFont(.display)
                    .foregroundStyle(Color.tasker(.textPrimary))

                Text(title)
                    .taskerFont(.caption1)
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .lineLimit(1)

                Text(subtitle)
                    .taskerFont(.caption1)
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .lineLimit(2)
            }

            Spacer(minLength: TaskerTheme.Spacing.sm)

            if showsUtilityActions {
                HStack(spacing: TaskerTheme.Spacing.xs) {
                    if showsNewChatAction {
                        newChatButton
                    }

                    iconButton(
                        systemName: "gearshape",
                        identifier: "chat.header.settings",
                        label: "Settings",
                        action: onShowSettings
                    )
                }
            }
        }
        .padding(.horizontal, TaskerTheme.Spacing.lg)
        .padding(.top, TaskerTheme.Spacing.sm)
        .padding(.bottom, TaskerTheme.Spacing.sm)
    }

    private var newChatButton: some View {
        Button(action: onStartNewChat) {
            ViewThatFits(in: .horizontal) {
                Label("New chat", systemImage: "plus.message")
                    .font(.tasker(.buttonSmall))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.tasker(.accentPrimary))
                    .lineLimit(1)
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .frame(height: 44)
                    .taskerChromeSurface(
                        cornerRadius: 22,
                        accentColor: Color.tasker(.accentSecondary),
                        level: .e1
                    )

                Image(systemName: "plus.message")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.tasker(.accentPrimary))
                    .frame(width: 44, height: 44)
                    .taskerChromeSurface(
                        cornerRadius: 22,
                        accentColor: Color.tasker(.accentSecondary),
                        level: .e1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat.header.new_chat")
        .accessibilityLabel("New chat")
        .accessibilityHint("Starts a fresh chat without deleting this one.")
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }

    private func iconButton(
        systemName: String,
        identifier: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.tasker(.textSecondary))
                .frame(width: 44, height: 44)
                .taskerChromeSurface(
                    cornerRadius: 22,
                    accentColor: Color.tasker(.accentSecondary),
                    level: .e1
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
        .accessibilityLabel(label)
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }
}

struct ChatEmptyStateView: View {
    let identity: AssistantIdentitySnapshot
    let presentationMode: ChatPresentationMode
    let starterPrompts: [EvaStarterPrompt]
    let commandSuggestions: [SlashCommandDescriptor]
    let onSelectStarterPrompt: (EvaStarterPrompt) -> Void
    let onSelectSuggestion: (SlashCommandDescriptor) -> Void
    let onOpenEvaGuide: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isActivationPresentation: Bool {
        if case .activation = presentationMode {
            return true
        }
        return false
    }

    private var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    private var activationStarterPrompts: [EvaStarterPrompt] {
        let prompts = starterPrompts
        guard let activationConfiguration else { return prompts }
        return Array(prompts.prefix(activationConfiguration.visibleStarterLimit))
    }

    private var dayOverviewStarterPrompt: EvaStarterPrompt {
        EvaStarterPrompt.dayOverviewPrompt
    }

    var body: some View {
        if V2FeatureFlags.evaStructuredComposer && isActivationPresentation == false {
            structuredPlanEmptyState
        } else {
            VStack(spacing: TaskerTheme.Spacing.lg) {
            Spacer()

            if isActivationPresentation {
                VStack(spacing: TaskerTheme.Spacing.sm) {
                    EvaLoopingLottieContainer(size: 64)
                    VStack(spacing: TaskerTheme.Spacing.xs) {
                        Text("\(identity.askAction) anything")
                            .font(.tasker(.title2))
                            .foregroundStyle(Color.tasker(.textPrimary))
                            .accessibilityIdentifier("chat.emptyState.title")
                        Text("Start with a focused prompt, or use a command for structured help.")
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.lg)
                .padding(.vertical, TaskerTheme.Spacing.lg)
                .taskerPremiumSurface(
                    cornerRadius: TaskerTheme.CornerRadius.xl,
                    fillColor: Color.tasker(.surfacePrimary),
                    strokeColor: Color.tasker(.strokeHairline),
                    accentColor: Color.tasker(.accentSecondary),
                    level: .e1,
                    useNativeGlass: false
                )
                .enhancedStaggeredAppearance(index: 0)
            } else {
                ZStack {
                    Circle()
                        .fill(Color.tasker(.accentWash))
                        .frame(width: 80, height: 80)
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Color.tasker(.accentPrimary))
                        .symbolEffect(
                            .wiggle.byLayer,
                            options: .repeat(.periodic(delay: 3.0)),
                            isActive: !reduceMotion
                        )
                }
                VStack(spacing: TaskerTheme.Spacing.xs) {
                    Text("\(identity.askAction) anything")
                        .font(.tasker(.title2))
                        .foregroundStyle(Color.tasker(.textPrimary))
                        .accessibilityIdentifier("chat.emptyState.title")
                    Text("Type / for commands")
                        .font(.tasker(.callout))
                        .foregroundStyle(Color.tasker(.textTertiary))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, TaskerTheme.Spacing.xl)
                .padding(.vertical, TaskerTheme.Spacing.lg)
                .taskerPremiumSurface(
                    cornerRadius: TaskerTheme.CornerRadius.xl,
                    fillColor: Color.tasker(.surfacePrimary),
                    strokeColor: Color.tasker(.strokeHairline),
                    accentColor: Color.tasker(.accentSecondary),
                    level: .e1
                )
                .enhancedStaggeredAppearance(index: 0)
            }

            promptCarousel
                .enhancedStaggeredAppearance(index: 2)

            Spacer()
        }
        .accessibilityIdentifier("chat.emptyState.container")
        }
    }

    private var structuredPlanEmptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: TaskerTheme.Spacing.md) {
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                    HStack(alignment: .center, spacing: TaskerTheme.Spacing.sm) {
                        EvaMascotView(placement: .chatEmptyHeader, size: .avatar)
                        Text("Hi there!")
                            .taskerFont(.screenTitle)
                            .foregroundStyle(Color.tasker(.accentPrimary))
                    }

                    Text("What do you need to plan?")
                        .taskerFont(.title1)
                        .foregroundStyle(Color.tasker(.textPrimary))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: TaskerTheme.Spacing.md)

                Button(action: onOpenEvaGuide) {
                    EvaMascotView(placement: .chatHelp, size: .custom(46))
                        .padding(5)
                        .frame(width: 56, height: 56)
                        .background(Color.tasker(.surfacePrimary), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(identity.displayName) help")
                .accessibilityHint("Shows ways to use \(identity.displayName) as your chief of staff.")
                .accessibilityIdentifier("eva.structured.help")
                .taskerPressFeedback(reduceMotion: reduceMotion)
            }
            .padding(.horizontal, TaskerTheme.Spacing.xl)
            .padding(.top, TaskerTheme.Spacing.xl)

            Spacer(minLength: TaskerTheme.Spacing.xl)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TaskerTheme.Spacing.md) {
                    ForEach(EvaChiefOfStaffGuideContent.homePromptChips(for: identity)) { chip in
                        structuredExampleChip(chip)
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.xl)
                .padding(.bottom, TaskerTheme.Spacing.sm)
            }
        }
        .accessibilityIdentifier("chat.emptyState.container")
    }

    private func structuredExampleChip(_ chip: EvaHomePromptChip) -> some View {
        Button {
            onSelectStarterPrompt(chip.prompt)
        } label: {
            HStack(alignment: .top, spacing: TaskerTheme.Spacing.sm) {
                Image(systemName: chip.icon)
                    .taskerFont(.caption1)
                    .foregroundStyle(Color.tasker(.accentPrimary))
                    .frame(width: 32, height: 32)
                    .background(Color.tasker(.accentWash), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(chip.prompt.title)
                        .taskerFont(.callout)
                        .foregroundStyle(Color.tasker(.textPrimary))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(chip.prompt.submissionText)
                        .taskerFont(.caption1)
                        .foregroundStyle(Color.tasker(.textTertiary))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.md)
            .padding(.vertical, TaskerTheme.Spacing.md)
            .frame(width: 236, alignment: .leading)
            .frame(minHeight: 78, alignment: .leading)
            .taskerChromeSurface(
                cornerRadius: TaskerTheme.CornerRadius.lg,
                accentColor: Color.tasker(.accentSecondary),
                level: .e1
            )
        }
        .buttonStyle(.plain)
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }

    @ViewBuilder
    private var promptCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TaskerTheme.Spacing.sm) {
                if isActivationPresentation {
                    ForEach(activationStarterPrompts) { prompt in
                        starterPromptChip(prompt)
                    }
                } else {
                    ForEach(commandSuggestions, id: \.id) { descriptor in
                        commandSuggestionChip(for: descriptor)
                    }
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.xl)
        }
    }

    private func starterPromptChip(_ prompt: EvaStarterPrompt) -> some View {
        Button {
            onSelectStarterPrompt(prompt)
        } label: {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                Image(systemName: prompt.style == .slashCommand ? "command" : (prompt.isRecommended ? "star.fill" : "sparkle"))
                    .font(.tasker(.caption1))
                Text(prompt.title)
                    .font(.tasker(.callout))
            }
            .foregroundStyle(prompt.isRecommended ? Color.tasker(.accentOnPrimary) : Color.tasker(.accentPrimary))
            .padding(.horizontal, TaskerTheme.Spacing.md)
            .padding(.vertical, TaskerTheme.Spacing.sm)
            .background(prompt.isRecommended ? Color.tasker(.accentPrimary) : Color.tasker(.accentWash))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(prompt.isRecommended ? Color.tasker(.accentPrimary) : Color.tasker(.accentMuted), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send \(prompt.title)")
        .accessibilityIdentifier("chat.activation_starter.\(prompt.id)")
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }

    private func commandSuggestionChip(for descriptor: SlashCommandDescriptor) -> some View {
        Button {
            onSelectSuggestion(descriptor)
        } label: {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                Image(systemName: descriptor.id.icon)
                    .font(.tasker(.caption1))
                Text(descriptor.command)
                    .font(.tasker(.callout))
            }
            .foregroundStyle(Color.tasker(.accentPrimary))
            .padding(.horizontal, TaskerTheme.Spacing.md)
            .padding(.vertical, TaskerTheme.Spacing.sm)
            .background(Color.tasker(.accentWash))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.tasker(.accentMuted), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Run command \(descriptor.command)")
        .accessibilityIdentifier("chat.command_suggestion.\(descriptor.id.rawValue)")
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }
}

struct EvaChiefOfStaffGuideSection: Identifiable, Equatable {
    let id: String
    let icon: String
    let title: String
    let body: String
    let prompts: [EvaStarterPrompt]
}

struct EvaHomePromptChip: Identifiable, Equatable {
    let id: String
    let icon: String
    let prompt: EvaStarterPrompt
}

enum EvaChiefOfStaffGuideContent {
    static func sections(for identity: AssistantIdentitySnapshot = AssistantIdentityText.currentSnapshot()) -> [EvaChiefOfStaffGuideSection] {
        [
            EvaChiefOfStaffGuideSection(
                id: "how_eva_helps",
                icon: "sparkles",
                title: "How \(identity.displayName) helps",
                body: "\(identity.displayName) is your private, on-device chief of staff. They read your current task context, summarize what matters, help you decide what to do next, and propose changes before anything is applied.",
                prompts: [
                    guidePrompt(
                        id: "how_is_my_day",
                        title: "How is my day?",
                        submissionText: "How is my day looking today?"
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "command_your_day",
                icon: "sun.max",
                title: "Command your day",
                body: "\(identity.askAction) for a quick operating brief, a focus recommendation, or a recovery view when overdue work is crowding the day.",
                prompts: [
                    guidePrompt(
                        id: "focus_first",
                        title: "Focus first",
                        submissionText: "What should I focus on first today?"
                    ),
                    guidePrompt(
                        id: "recover_overdue",
                        title: "Recover overdue",
                        submissionText: "Show me what is overdue and what I should recover first."
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "plan_and_repair",
                icon: "arrow.triangle.2.circlepath",
                title: "Plan and repair",
                body: "Use \(identity.displayName) when the day needs structure. They can turn your existing tasks and habits into a realistic plan, then explain what should move, wait, or stay protected.",
                prompts: [
                    guidePrompt(
                        id: "plan_today_existing",
                        title: "Plan today",
                        submissionText: "Help me plan today around my existing tasks and habits."
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "reschedule_open_tasks",
                icon: "calendar.badge.clock",
                title: "Reschedule open tasks",
                body: "\(identity.askAction) to carry unfinished work to another day, shift scheduled tasks, or rebuild the order. \(identity.displayName) shows review cards before applying changes.",
                prompts: [
                    guidePrompt(
                        id: "reschedule_unfinished_tasks",
                        title: "Reschedule unfinished tasks",
                        submissionText: "Reschedule my unfinished tasks"
                    ),
                    guidePrompt(
                        id: "carry_today_to_tomorrow",
                        title: "Carry today to tomorrow",
                        submissionText: "Move all my unfinished tasks from today to tomorrow"
                    ),
                    guidePrompt(
                        id: "push_by_20_minutes",
                        title: "Push by 20 minutes",
                        submissionText: "Move all my unfinished tasks from today forward by 20 minutes"
                    ),
                    guidePrompt(
                        id: "start_tomorrow_morning",
                        title: "Start tomorrow morning",
                        submissionText: "Move my open tasks to tomorrow morning"
                    ),
                    guidePrompt(
                        id: "overdue_to_today",
                        title: "Overdue to today",
                        submissionText: "Move overdue tasks to today"
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "break_work_down",
                icon: "checklist",
                title: "Break work down",
                body: "Bring \(identity.displayName) a vague priority, messy note, or large task. Ask for next steps so the first action is obvious instead of another decision.",
                prompts: [
                    guidePrompt(
                        id: "break_top_priority",
                        title: "Break down priority",
                        submissionText: "Help me break down my top priority into next steps."
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "structured_context",
                icon: "command",
                title: "Use structured context",
                body: "Type commands when you want \(identity.displayName) to pull a specific slice of your system. Commands like /today, /week, /project, /area, /recent, and /overdue can also pin context into the current chat.",
                prompts: [
                    guidePrompt(id: "slash_today", title: "/today", submissionText: "/today", style: .slashCommand),
                    guidePrompt(id: "slash_week", title: "/week", submissionText: "/week", style: .slashCommand),
                    guidePrompt(id: "slash_project_inbox", title: "/project Inbox", submissionText: "/project Inbox", style: .slashCommand),
                    guidePrompt(id: "slash_recent", title: "/recent", submissionText: "/recent", style: .slashCommand)
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "review_before_apply",
                icon: "checkmark.shield",
                title: "Review before apply",
                body: "For task changes, \(identity.displayName) should show proposal cards first. You choose what to apply, use selected apply for safe batches, and undo where the applied action supports it.",
                prompts: [
                    guidePrompt(
                        id: "plan_today_for_review",
                        title: "Make a reviewable plan",
                        submissionText: "Help me plan today around my existing tasks and habits."
                    )
                ]
            )
        ]
    }

    static func homePromptChips(for identity: AssistantIdentitySnapshot = AssistantIdentityText.currentSnapshot()) -> [EvaHomePromptChip] {
        var seenIDs = Set<String>()
        var seenSubmissionTexts = Set<String>()
        var chips: [EvaHomePromptChip] = []

        func append(_ chip: EvaHomePromptChip) {
            guard seenIDs.insert(chip.prompt.id).inserted else { return }
            guard seenSubmissionTexts.insert(chip.prompt.submissionText).inserted else { return }
            chips.append(chip)
        }

        curatedHomePromptChips.forEach(append)
        guideHomePromptChips(for: identity).forEach(append)

        return chips
    }

    private static var curatedHomePromptChips: [EvaHomePromptChip] {
        [
            homePromptChip(
                id: "home_how_is_my_day",
                icon: "sparkles",
                title: "How is my day?",
                submissionText: "How is my day looking today?"
            ),
            homePromptChip(
                id: "home_plan_today",
                icon: "arrow.triangle.2.circlepath",
                title: "Plan today",
                submissionText: "Help me plan today around my existing tasks and habits."
            ),
            homePromptChip(
                id: "home_recover_overdue",
                icon: "sun.max",
                title: "Recover overdue",
                submissionText: "Show me what is overdue and what I should recover first."
            ),
            homePromptChip(
                id: "home_carry_todays_overdues_to_tomorrow",
                icon: "calendar.badge.clock",
                title: "Carry today's overdues to tomorrow",
                submissionText: "Move today's overdue tasks to tomorrow."
            ),
            homePromptChip(
                id: "home_overdue_today_first_then_rest",
                icon: "calendar.badge.clock",
                title: "Overdue today first and then the rest",
                submissionText: "Plan today with overdue tasks first, then the rest."
            )
        ]
    }

    private static func guideHomePromptChips(for identity: AssistantIdentitySnapshot) -> [EvaHomePromptChip] {
        sections(for: identity).flatMap { section in
            section.prompts.map { prompt in
                EvaHomePromptChip(
                    id: "home_\(prompt.id)",
                    icon: section.icon,
                    prompt: prompt
                )
            }
        }
    }

    private static func guidePrompt(
        id: String,
        title: String,
        submissionText: String,
        style: EvaStarterPrompt.Style = .naturalLanguage
    ) -> EvaStarterPrompt {
        EvaStarterPrompt(
            id: "eva_guide_\(id)",
            title: title,
            submissionText: submissionText,
            style: style,
            isRecommended: false
        )
    }

    private static func homePromptChip(
        id: String,
        icon: String,
        title: String,
        submissionText: String,
        style: EvaStarterPrompt.Style = .naturalLanguage
    ) -> EvaHomePromptChip {
        let prompt = EvaStarterPrompt(
            id: id,
            title: title,
            submissionText: submissionText,
            style: style,
            isRecommended: false
        )
        return EvaHomePromptChip(id: id, icon: icon, prompt: prompt)
    }
}

struct EvaChiefOfStaffGuideView: View {
    let onSelectPrompt: (EvaStarterPrompt) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    private var sections: [EvaChiefOfStaffGuideSection] {
        EvaChiefOfStaffGuideContent.sections(for: assistantIdentity.snapshot)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.lg) {
                    hero

                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        sectionCard(section)
                            .enhancedStaggeredAppearance(index: index + 1)
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.lg)
                .padding(.vertical, TaskerTheme.Spacing.lg)
            }
            .background(Color.tasker(.bgElevated))
            .navigationTitle("\(assistantIdentity.snapshot.displayName) guide")
            #if os(iOS) || os(visionOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityIdentifier("eva.guide.close")
                }
            }
        }
        .accessibilityIdentifier("eva.guide.sheet")
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.sm) {
            HStack(spacing: TaskerTheme.Spacing.sm) {
                EvaMascotView(placement: .chiefOfStaffGuide, size: .custom(42))
                    .frame(width: 48, height: 48)
                    .background(Color.tasker(.accentWash), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(assistantIdentity.snapshot.displayName) as Chief of Staff")
                        .font(.tasker(.title2))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    Text("Plan, triage, and apply with confirmation.")
                        .font(.tasker(.callout))
                        .foregroundStyle(Color.tasker(.textSecondary))
                }
            }

            Text("Start with one of these prompts, or read the examples to learn when \(assistantIdentity.snapshot.displayName) is strongest.")
                .font(.tasker(.body))
                .foregroundStyle(Color.tasker(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TaskerTheme.Spacing.lg)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.xl,
            fillColor: Color.tasker(.surfacePrimary),
            strokeColor: Color.tasker(.strokeHairline),
            accentColor: Color.tasker(.accentSecondary),
            level: .e1
        )
        .enhancedStaggeredAppearance(index: 0)
    }

    private func sectionCard(_ section: EvaChiefOfStaffGuideSection) -> some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.md) {
            HStack(alignment: .top, spacing: TaskerTheme.Spacing.sm) {
                Image(systemName: section.icon)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.accentPrimary))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                    Text(section.title)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    Text(section.body)
                        .font(.tasker(.callout))
                        .foregroundStyle(Color.tasker(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            FlowPromptChipsView(
                prompts: section.prompts,
                reduceMotion: reduceMotion,
                onSelectPrompt: { prompt in
                    dismiss()
                    onSelectPrompt(prompt)
                }
            )
        }
        .padding(TaskerTheme.Spacing.md)
        .taskerChromeSurface(
            cornerRadius: TaskerTheme.CornerRadius.lg,
            accentColor: Color.tasker(.accentSecondary),
            level: .e1
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("eva.guide.section.\(section.id)")
    }

}

private struct FlowPromptChipsView: View {
    let prompts: [EvaStarterPrompt]
    let reduceMotion: Bool
    let onSelectPrompt: (EvaStarterPrompt) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 138), spacing: TaskerTheme.Spacing.xs, alignment: .leading)],
            alignment: .leading,
            spacing: TaskerTheme.Spacing.xs
        ) {
            ForEach(prompts) { prompt in
                Button {
                    onSelectPrompt(prompt)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: prompt.style == .slashCommand ? "command" : "arrow.up.message")
                            .font(.tasker(.caption2))
                        Text(prompt.title)
                            .font(.tasker(.caption1))
                            .fontWeight(.semibold)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color.tasker(.accentPrimary))
                    .padding(.horizontal, TaskerTheme.Spacing.sm)
                    .padding(.vertical, TaskerTheme.Spacing.xs)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.tasker(.accentWash))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.tasker(.accentMuted), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Send prompt: \(prompt.submissionText)")
                .accessibilityIdentifier("eva.guide.prompt.\(prompt.id)")
                .taskerPressFeedback(reduceMotion: reduceMotion)
            }
        }
    }
}

struct ChatComposerView: View {
    let identity: AssistantIdentitySnapshot
    let presentationMode: ChatPresentationMode
    let slashDraft: SlashCommandInvocation?
    let activeAttachments: [ThreadContextAttachmentRecord]
    let commandFeedback: String?
    let hasCurrentThread: Bool
    @Binding var prompt: String
    @FocusState.Binding var isPromptFocused: Bool
    @FocusState.Binding var isProjectFieldFocused: Bool
    let projectQuery: Binding<String>
    let commandSuggestions: [SlashCommandDescriptor]
    let starterPrompts: [EvaStarterPrompt]
    let isGenerationInFlight: Bool
    let canSubmit: Bool
    let llmCancelled: Bool
    let hasActivationAssistantReply: Bool
    let onOpenSlashPicker: () -> Void
    let onSelectStarterPrompt: (EvaStarterPrompt) -> Void
    let onSelectSuggestion: (SlashCommandDescriptor) -> Void
    let onCancelDraft: () -> Void
    let onRemoveAttachment: (ThreadContextAttachmentRecord) -> Void
    let onGenerate: () -> Void
    let onStop: () -> Void
    let onSubmitPrompt: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var structuredDeferredFeedback: String?

    private var isActivationPresentation: Bool {
        if case .activation = presentationMode {
            return true
        }
        return false
    }

    private var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    private var activationStarterPrompts: [EvaStarterPrompt] {
        let prompts = starterPrompts
        guard let activationConfiguration else { return prompts }
        return Array(prompts.prefix(activationConfiguration.visibleStarterLimit))
    }

    private var dayOverviewStarterPrompt: EvaStarterPrompt {
        EvaStarterPrompt.dayOverviewPrompt
    }

    var body: some View {
        if V2FeatureFlags.evaStructuredComposer && isActivationPresentation == false {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                if shouldShowComposerSuggestionStrip {
                    composerSuggestionStrip
                }
                structuredComposer
            }
        } else {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            if activeAttachments.isEmpty == false {
                activeAttachmentRow
            }

            if let slashDraft {
                commandDraftRow(slashDraft)
            }

            if let commandFeedback, !commandFeedback.isEmpty {
                Text(commandFeedback)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.statusDanger))
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .accessibilityIdentifier("chat.command_feedback")
                    .transition(.opacity)
            }

            if isActivationPresentation {
                Text(activationConfiguration?.helperCopy ?? "Type / for structured help like today, week, or project.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .accessibilityIdentifier("chat.activation.slash_helper")
            }

            if shouldShowComposerSuggestionStrip {
                composerSuggestionStrip
            }

            HStack(alignment: .bottom, spacing: 0) {
                slashButton

                TextField(composerPlaceholder, text: $prompt, axis: .vertical)
                    .focused($isPromptFocused)
                    .textFieldStyle(.plain)
                    .font(.tasker(.body))
                    .foregroundStyle(Color.tasker(.textPrimary))
                #if os(iOS) || os(visionOS)
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                #elseif os(macOS)
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .onSubmit(onSubmitPrompt)
                    .submitLabel(.send)
                #endif
                    .padding(.vertical, TaskerTheme.Spacing.sm)
                #if os(iOS) || os(visionOS)
                    .frame(minHeight: 48)
                    .onSubmit(onSubmitPrompt)
                #elseif os(macOS)
                    .frame(minHeight: 32)
                #endif

                if isGenerationInFlight {
                    stopButton
                } else {
                    generateButton
                }
            }
        }
        #if os(iOS) || os(visionOS)
        .padding(.vertical, TaskerTheme.Spacing.sm)
        .padding(.horizontal, 2)
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.xl,
            fillColor: Color.tasker(.surfaceSecondary),
            strokeColor: Color.tasker(.strokeHairline),
            accentColor: Color.tasker(.accentSecondary),
            level: .e2
        )
        #elseif os(macOS)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.tasker(.surfaceSecondary))
        )
        #endif
        .accessibilityIdentifier("chat.composer.container")
        .contentShape(Rectangle())
        .onTapGesture {
            isPromptFocused = true
        }
        }
    }

    private var structuredComposer: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            if activeAttachments.isEmpty == false {
                activeAttachmentRow
            }

            if let commandFeedback, !commandFeedback.isEmpty {
                Text(commandFeedback)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.statusDanger))
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .accessibilityIdentifier("chat.command_feedback")
                    .transition(.opacity)
            }

            HStack(alignment: .bottom, spacing: TaskerTheme.Spacing.xs) {
                TextField("Tell me your plans...", text: $prompt, axis: .vertical)
                    .focused($isPromptFocused)
                    .textFieldStyle(.plain)
                    .taskerFont(.body)
                    .foregroundStyle(Color.tasker(.textPrimary))
                    .tint(Color.tasker(.accentPrimary))
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .padding(.vertical, TaskerTheme.Spacing.sm)
                    .frame(minHeight: 52)
                    .onSubmit(onSubmitPrompt)

                if V2FeatureFlags.evaVoiceDeferred {
                    structuredDeferredIcon(systemName: "mic.fill", label: "Voice planning")
                }
                if V2FeatureFlags.evaScanDeferred {
                    structuredDeferredIcon(systemName: "viewfinder", label: "Scan planning")
                }

                if isGenerationInFlight {
                    stopButton
                        .padding(.leading, 0)
                } else {
                    generateButton
                        .padding(.leading, 0)
                }
            }

            if let structuredDeferredFeedback {
                Text(structuredDeferredFeedback)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .padding(.horizontal, TaskerTheme.Spacing.md)
                    .accessibilityIdentifier("eva.structured.deferred.feedback")
            }
        }
        .padding(.vertical, TaskerTheme.Spacing.xs)
        .background(Color.tasker(.surfacePrimary))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isPromptFocused ? Color.tasker(.accentRing) : Color.tasker(.strokeHairline),
                    lineWidth: isPromptFocused ? 1.2 : 1
                )
        )
        .shadow(
            color: isPromptFocused ? Color.tasker(.accentPrimary).opacity(0.12) : Color.tasker(.textPrimary).opacity(0.04),
            radius: isPromptFocused ? 8 : 4,
            y: isPromptFocused ? 2 : 1
        )
        .animation(reduceMotion ? nil : TaskerAnimation.quick, value: isPromptFocused)
        .accessibilityIdentifier("eva.structured.composer")
        .contentShape(Rectangle())
        .onTapGesture {
            isPromptFocused = true
        }
    }

    private func structuredDeferredIcon(systemName: String, label: String) -> some View {
        Button {
            structuredDeferredFeedback = "\(label) is coming later."
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.tasker(.accentPrimary).opacity(0.82))
                .frame(width: 36, height: 44)
                .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) coming later")
        .accessibilityHint("No permission will be requested.")
        .accessibilityIdentifier("eva.structured.deferred.\(systemName)")
    }

    private var composerSuggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                if isActivationPresentation {
                    ForEach(Array(activationStarterPrompts.enumerated()), id: \.element.id) { index, prompt in
                        Button {
                            onSelectStarterPrompt(prompt)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: prompt.style == .slashCommand ? "command" : (prompt.isRecommended ? "star.fill" : "sparkle"))
                                    .font(.tasker(.caption2))
                                Text(prompt.title)
                                    .font(.tasker(.caption1))
                            }
                            .foregroundStyle(prompt.isRecommended ? Color.tasker(.accentOnPrimary) : Color.tasker(.accentPrimary))
                            .padding(.horizontal, TaskerTheme.Spacing.sm)
                            .padding(.vertical, TaskerTheme.Spacing.xs)
                            .background(prompt.isRecommended ? Color.tasker(.accentPrimary) : Color.tasker(.accentWash))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Send \(prompt.title)")
                        .accessibilityIdentifier("chat.activation.composer_starter.\(prompt.id)")
                        .overlay(
                            Capsule()
                                .stroke(prompt.isRecommended ? Color.tasker(.accentPrimary) : Color.tasker(.accentMuted), lineWidth: 1)
                        )
                        .taskerPressFeedback(reduceMotion: reduceMotion)
                        .enhancedStaggeredAppearance(index: index)
                    }
                } else {
                    Button {
                        onSelectStarterPrompt(dayOverviewStarterPrompt)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle")
                                .font(.tasker(.caption2))
                            Text(dayOverviewStarterPrompt.title)
                                .font(.tasker(.caption1))
                        }
                        .foregroundStyle(Color.tasker(.accentOnPrimary))
                        .padding(.horizontal, TaskerTheme.Spacing.sm)
                        .padding(.vertical, TaskerTheme.Spacing.xs)
                        .background(Color.tasker(.accentPrimary))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Send \(dayOverviewStarterPrompt.title)")
                    .accessibilityIdentifier("chat.command_composer_starter.\(dayOverviewStarterPrompt.id)")
                    .overlay(
                        Capsule()
                            .stroke(Color.tasker(.accentPrimary), lineWidth: 1)
                    )
                    .taskerPressFeedback(reduceMotion: reduceMotion)

                    ForEach(commandSuggestions, id: \.id) { descriptor in
                        Button {
                            onSelectSuggestion(descriptor)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: descriptor.id.icon)
                                    .font(.tasker(.caption2))
                                Text(descriptor.command)
                                    .font(.tasker(.caption1))
                            }
                            .foregroundStyle(Color.tasker(.accentPrimary))
                            .padding(.horizontal, TaskerTheme.Spacing.sm)
                            .padding(.vertical, TaskerTheme.Spacing.xs)
                            .background(Color.tasker(.accentWash))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Insert \(descriptor.command)")
                        .accessibilityIdentifier("chat.command_composer_suggestion.\(descriptor.id.rawValue)")
                        .taskerPressFeedback(reduceMotion: reduceMotion)
                    }
                }
            }
            .padding(.horizontal, TaskerTheme.Spacing.sm)
        }
        .transition(.opacity)
    }

    private var composerPlaceholder: String {
        isActivationPresentation ? "\(identity.askAction) what to focus on..." : "\(identity.askAction) anything"
    }

    private var activeAttachmentRow: some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            Text("Using context")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
                .padding(.horizontal, TaskerTheme.Spacing.sm)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TaskerTheme.Spacing.xs) {
                    ForEach(activeAttachments) { attachment in
                        HStack(spacing: 6) {
                            Image(systemName: attachment.commandID.icon)
                                .font(.tasker(.caption2))
                            Text(attachment.commandLabel)
                                .font(.tasker(.caption1))
                                .lineLimit(1)
                            Button {
                                onRemoveAttachment(attachment)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.tasker(.caption2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove \(attachment.commandLabel)"))
                            .accessibilityHint(Text("Removes this pinned context from the current chat."))
                        }
                        .foregroundStyle(Color.tasker(.accentPrimary))
                        .padding(.horizontal, TaskerTheme.Spacing.sm)
                        .padding(.vertical, TaskerTheme.Spacing.xs)
                        .background(Color.tasker(.accentWash))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.tasker(.accentMuted), lineWidth: 1))
                        .accessibilityIdentifier("chat.attachment_chip.\(attachment.id.uuidString)")
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.sm)
            }
        }
        .transition(.opacity)
    }

    private var shouldShowComposerSuggestionStrip: Bool {
        guard slashDraft == nil else { return false }
        guard hasCurrentThread else { return false }
        guard prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }

        if isActivationPresentation,
           activationConfiguration?.collapsesCoachingAfterFirstAssistantReply == true,
           hasActivationAssistantReply {
            return false
        }

        return true
    }

    private var slashButton: some View {
        Button(action: onOpenSlashPicker) {
            Text("/")
                .font(.tasker(.callout))
                .fontWeight(.semibold)
                .foregroundStyle(Color.tasker(.accentPrimary))
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.tasker(.accentWash))
                )
                .overlay(
                    Circle()
                        .stroke(Color.tasker(.accentMuted), lineWidth: 1)
                )
        }
        .padding(.leading, TaskerTheme.Spacing.sm)
        .padding(.bottom, TaskerTheme.Spacing.xs)
        .accessibilityLabel("Commands")
        .accessibilityHint("Open slash commands")
        .accessibilityIdentifier("chat.slash_button")
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }

    @ViewBuilder
    private func commandDraftRow(_ invocation: SlashCommandInvocation) -> some View {
        VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
            HStack(spacing: TaskerTheme.Spacing.xs) {
                Label(invocation.id.canonicalCommand, systemImage: invocation.id.icon)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.accentPrimary))
                    .padding(.horizontal, TaskerTheme.Spacing.sm)
                    .padding(.vertical, TaskerTheme.Spacing.xs)
                    .background(Color.tasker(.accentWash))
                    .clipShape(Capsule())
                    .accessibilityIdentifier("chat.command_chip.\(invocation.id.rawValue)")

                Button(action: onCancelDraft) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))
                }
                .buttonStyle(.plain)

                Spacer()
            }

            if invocation.id.requiresArgument {
                HStack(spacing: TaskerTheme.Spacing.xs) {
                    Image(systemName: invocation.id.icon)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))

                    TextField(invocation.id.argumentPlaceholder ?? "Pick value", text: projectQuery)
                        .font(.tasker(.caption1))
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .focused($isProjectFieldFocused)
                        .accessibilityIdentifier("chat.command_argument_field")

                    if let resolvedArgument = invocation.resolvedArgument, !resolvedArgument.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.tasker(.statusSuccess))
                            Text(resolvedArgument)
                                .font(.tasker(.caption1))
                                .foregroundStyle(Color.tasker(.statusSuccess))
                        }
                    }
                }
                .padding(.horizontal, TaskerTheme.Spacing.sm)
                .padding(.vertical, TaskerTheme.Spacing.sm)
                .background(Color.tasker(.surfaceTertiary))
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                        .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
                )
                .padding(.horizontal, TaskerTheme.Spacing.sm)
            }
        }
        .transition(.opacity)
    }

    private var generateButton: some View {
        Button(action: onGenerate) {
            Image(systemName: "arrow.up")
                .font(.tasker(.buttonSmall))
                .fontWeight(.semibold)
                .foregroundStyle(canSubmit ? Color.tasker(.accentOnPrimary) : Color.tasker(.textQuaternary))
            #if os(iOS) || os(visionOS)
                .frame(width: 32, height: 32)
            #else
                .frame(width: 24, height: 24)
            #endif
                .background(
                    Circle()
                        .fill(canSubmit ? Color.tasker(.accentPrimary) : Color.tasker(.surfaceTertiary))
                )
        }
        .disabled(!canSubmit)
        .accessibilityIdentifier("chat.send_button")
        #if os(iOS) || os(visionOS)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.bottom, TaskerTheme.Spacing.xs)
        #else
            .padding(.trailing, TaskerTheme.Spacing.sm)
            .padding(.bottom, TaskerTheme.Spacing.sm)
        #endif
        .animation(reduceMotion ? nil : TaskerAnimation.quick, value: canSubmit)
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }

    private var stopButton: some View {
        Button(action: onStop) {
            Image(systemName: "stop.fill")
                .font(.caption)
                .foregroundStyle(Color.tasker(.accentOnPrimary))
            #if os(iOS) || os(visionOS)
                .frame(width: 32, height: 32)
            #else
                .frame(width: 24, height: 24)
            #endif
                .background(
                    Circle()
                        .fill(Color.tasker(.statusDanger))
                )
        }
        .disabled(llmCancelled)
        .accessibilityIdentifier("chat.stop_button")
        #if os(iOS) || os(visionOS)
            .padding(.trailing, TaskerTheme.Spacing.md)
            .padding(.bottom, TaskerTheme.Spacing.xs)
        #else
            .padding(.trailing, TaskerTheme.Spacing.sm)
            .padding(.bottom, TaskerTheme.Spacing.sm)
        #endif
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
        .taskerPressFeedback(reduceMotion: reduceMotion)
    }
}

struct ChatScaffoldView: View {
    @EnvironmentObject private var appManager: AppManager
    @Environment(LLMEvaluator.self) private var llm
    @Environment(\.taskerLayoutClass) private var layoutClass
    @State private var showEvaGuide = false
    @StateObject private var assistantIdentity = AssistantIdentityModel()

    @Binding var currentThread: Thread?
    let transcriptSnapshot: ChatTranscriptSnapshot
    let liveOutput: ChatLiveOutputState
    let presentationMode: ChatPresentationMode
    let prompt: Binding<String>
    let isPromptFocused: FocusState<Bool>.Binding
    let isProjectFieldFocused: FocusState<Bool>.Binding
    let showChats: Binding<Bool>
    let showSettings: Binding<Bool>
    let showSlashPicker: Binding<Bool>
    let showClearConfirmation: Binding<Bool>
    let slashDraft: Binding<SlashCommandInvocation?>
    let slashPickerQuery: Binding<String>
    let commandFeedback: String?
    let projectQuery: Binding<String>
    let commandSuggestions: [SlashCommandDescriptor]
    let recentCommands: [SlashCommandDescriptor]
    let popularCommands: [SlashCommandDescriptor]
    let allCommands: [SlashCommandDescriptor]
    let isGenerationInFlight: Bool
    let canSubmit: Bool
    let llmCancelled: Bool
    let chatTitle: String
    let showsHistoryAction: Bool
    let onOpenTaskDetail: ((TaskDefinition) -> Void)?
    let onOpenHabitDetail: ((UUID) -> Void)?
    let onPerformDayTaskAction: EvaDayTaskActionHandler?
    let onPerformDayHabitAction: EvaDayHabitActionHandler?
    let starterPrompts: [EvaStarterPrompt]
    let activeAttachments: [ThreadContextAttachmentRecord]
    let onOpenSlashPicker: () -> Void
    let onSelectStarterPrompt: (EvaStarterPrompt) -> Void
    let onSelectSuggestion: (SlashCommandDescriptor) -> Void
    let onStartNewChat: () -> Void
    let onCancelDraft: () -> Void
    let onRemoveAttachment: (ThreadContextAttachmentRecord) -> Void
    let onGenerate: () -> Void
    let onStop: () -> Void
    let onSubmitPrompt: () -> Void
    let onClearCurrentThread: () -> Void
    let onNavigationChromeChange: ((EvaChatNavigationChromeState) -> Void)?

    private var isActivationPresentation: Bool {
        if case .activation = presentationMode {
            return true
        }
        return false
    }

    private var activationConfiguration: EvaActivationChatConfiguration? {
        guard case .activation(let config) = presentationMode else { return nil }
        return config
    }

    private var hasActivationAssistantReply: Bool {
        transcriptSnapshot.messages.contains { $0.role == .assistant }
    }

    private var navigationChromeState: EvaChatNavigationChromeState {
        EvaChatNavigationChromeState(
            title: assistantIdentity.snapshot.displayName,
            subtitle: currentThread == nil ? "Ask or use / commands" : chatTitle,
            showsUtilityActions: activationConfiguration?.hideUtilityActions != true,
            showsHistoryAction: showsHistoryAction && isActivationPresentation == false,
            showsNewChatAction: currentThread != nil && isActivationPresentation == false
        )
    }

    private func publishNavigationChromeState() {
        onNavigationChromeChange?(navigationChromeState)
    }

    var body: some View {
        VStack(spacing: 0) {
                if transcriptSnapshot.threadID != nil {
                    ConversationView(
                        snapshot: transcriptSnapshot,
                        liveOutput: liveOutput,
                        onOpenTaskFromCard: { task in
                            onOpenTaskDetail?(task)
                        },
                        onOpenHabitFromCard: onOpenHabitDetail,
                        onPerformDayTaskAction: onPerformDayTaskAction,
                        onPerformDayHabitAction: onPerformDayHabitAction
                    )
                } else {
                    ChatEmptyStateView(
                        identity: assistantIdentity.snapshot,
                        presentationMode: presentationMode,
                        starterPrompts: starterPrompts,
                        commandSuggestions: commandSuggestions,
                        onSelectStarterPrompt: onSelectStarterPrompt,
                        onSelectSuggestion: onSelectSuggestion,
                        onOpenEvaGuide: {
                            appManager.playHaptic()
                            showEvaGuide = true
                        }
                    )
                }

                HStack(alignment: .bottom, spacing: TaskerTheme.Spacing.md) {
                    ChatComposerView(
                        identity: assistantIdentity.snapshot,
                        presentationMode: presentationMode,
                        slashDraft: slashDraft.wrappedValue,
                        activeAttachments: activeAttachments,
                        commandFeedback: commandFeedback,
                        hasCurrentThread: currentThread != nil,
                        prompt: prompt,
                        isPromptFocused: isPromptFocused,
                        isProjectFieldFocused: isProjectFieldFocused,
                        projectQuery: projectQuery,
                        commandSuggestions: commandSuggestions,
                        starterPrompts: starterPrompts,
                        isGenerationInFlight: isGenerationInFlight,
                        canSubmit: canSubmit,
                        llmCancelled: llmCancelled,
                        hasActivationAssistantReply: hasActivationAssistantReply,
                        onOpenSlashPicker: onOpenSlashPicker,
                        onSelectStarterPrompt: onSelectStarterPrompt,
                        onSelectSuggestion: onSelectSuggestion,
                        onCancelDraft: onCancelDraft,
                        onRemoveAttachment: onRemoveAttachment,
                        onGenerate: onGenerate,
                        onStop: onStop,
                        onSubmitPrompt: onSubmitPrompt
                    )
                }
                .padding(.horizontal, TaskerTheme.Spacing.lg)
                .padding(.bottom, TaskerTheme.Spacing.md)
                .padding(.top, isActivationPresentation ? TaskerTheme.Spacing.xs : TaskerTheme.Spacing.sm)
                .background(
                    Color.tasker(.bgCanvas)
                        .shadow(color: Color.tasker(.textPrimary).opacity(0.04), radius: 8, y: -4)
                )
            }
            .background(Color.tasker(.bgCanvas))
                .onAppear {
                    publishNavigationChromeState()
                }
                .onChange(of: currentThread?.id) { _ in
                    publishNavigationChromeState()
                }
                .onChange(of: chatTitle) { _ in
                    publishNavigationChromeState()
                }
                .onChange(of: showsHistoryAction) { _ in
                    publishNavigationChromeState()
                }
                .onChange(of: presentationMode) { _ in
                    publishNavigationChromeState()
                }
                .onChange(of: assistantIdentity.snapshot) { _ in
                    publishNavigationChromeState()
                }
                .sheet(isPresented: showSettings) {
                    NavigationStack {
                        LLMSettingsView(currentThread: $currentThread, showsCloseButton: true)
                            .environment(llm)
                        #if os(visionOS)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Button(action: { showSettings.wrappedValue.toggle() }) {
                                        Image(systemName: "xmark")
                                    }
                                }
                            }
                        #endif
                    }
                    #if os(iOS)
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationCornerRadius(TaskerTheme.CornerRadius.xl)
                    .presentationDragIndicator(.visible)
                    .presentationDetents(layoutClass == .phone ? [.large] : [.large])
                    #elseif os(macOS)
                    .toolbar {
                        ToolbarItem(placement: .destructiveAction) {
                            Button(action: { showSettings.wrappedValue.toggle() }) {
                                Text("close")
                            }
                        }
                    }
                    #endif
                }
                .sheet(isPresented: showSlashPicker) {
                    SlashCommandPickerView(
                        query: slashPickerQuery,
                        recentCommands: recentCommands,
                        popularCommands: popularCommands,
                        allCommands: allCommands,
                        onSelect: onSelectSuggestion
                    )
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationDragIndicator(.visible)
                    .presentationDetents(layoutClass == .phone ? [.medium, .large] : [.large])
                }
                .sheet(isPresented: $showEvaGuide) {
                    EvaChiefOfStaffGuideView { prompt in
                        onSelectStarterPrompt(prompt)
                    }
                    #if os(iOS)
                    .presentationBackground(Color.tasker(.bgElevated))
                    .presentationCornerRadius(TaskerTheme.CornerRadius.xl)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
                    #endif
                }
                .alert("Clear this chat?", isPresented: showClearConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        onClearCurrentThread()
                    }
                } message: {
                    Text("This deletes all messages in the current thread.")
                }
                .toolbar {
                    #if os(macOS)
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: {
                            appManager.playHaptic()
                            showSettings.wrappedValue.toggle()
                        }) {
                            Label("settings", systemImage: "gear")
                        }
                    }
                    #endif
                }
    }
}
