import SwiftUI

enum EvaChiefOfStaffGuideContent {
    static func sections(for identity: AssistantIdentitySnapshot = AssistantIdentityText.currentSnapshot()) -> [EvaChiefOfStaffGuideSection] {
        [
            EvaChiefOfStaffGuideSection(
                id: "how_eva_helps",
                icon: "sparkles",
                title: String(localized: "How \(identity.displayName) helps"),
                body: String(localized: "Ask \(identity.displayName) to plan your day, break down a task, or move things around. \(identity.displayName) sees your tasks, habits, and calendar."),
                prompts: [
                    guidePrompt(
                        id: "how_is_my_day",
                        title: String(localized: "How is my day?"),
                        submissionText: "How is my day looking today?"
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "command_your_day",
                icon: "sun.max",
                title: String(localized: "Your day"),
                body: String(localized: "\(identity.askAction) what to do first or what’s left from earlier."),
                prompts: [
                    guidePrompt(
                        id: "focus_first",
                        title: String(localized: "What’s first?"),
                        submissionText: "What should I focus on first today?"
                    ),
                    guidePrompt(
                        id: "recover_overdue",
                        title: String(localized: "Review earlier tasks"),
                        submissionText: "Show me what is overdue and what I should recover first."
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "plan_and_repair",
                icon: "arrow.triangle.2.circlepath",
                title: String(localized: "Plan your day"),
                body: String(localized: "\(identity.displayName) builds a plan from your tasks and habits."),
                prompts: [
                    guidePrompt(
                        id: "plan_today_existing",
                        title: String(localized: "Plan today"),
                        submissionText: "Help me plan today around my existing tasks and habits."
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "reschedule_open_tasks",
                icon: "calendar.badge.clock",
                title: String(localized: "Reschedule open tasks"),
                body: String(localized: "Move unfinished tasks to another day. \(identity.displayName) shows review cards first."),
                prompts: [
                    guidePrompt(
                        id: "reschedule_unfinished_tasks",
                        title: String(localized: "Reschedule unfinished tasks"),
                        submissionText: "Reschedule my unfinished tasks"
                    ),
                    guidePrompt(
                        id: "carry_today_to_tomorrow",
                        title: String(localized: "Move to Tomorrow"),
                        submissionText: "Move all my unfinished tasks from today to tomorrow"
                    ),
                    guidePrompt(
                        id: "push_by_20_minutes",
                        title: String(localized: "Delay 20 min"),
                        submissionText: "Move all my unfinished tasks from today forward by 20 minutes"
                    ),
                    guidePrompt(
                        id: "start_tomorrow_morning",
                        title: String(localized: "Start tomorrow morning"),
                        submissionText: "Move my open tasks to tomorrow morning"
                    ),
                    guidePrompt(
                        id: "overdue_to_today",
                        title: String(localized: "Earlier tasks to Today"),
                        submissionText: "Move overdue tasks to today"
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "break_work_down",
                icon: "checklist",
                title: String(localized: "Break work down"),
                body: String(localized: "Give \(identity.displayName) a big task to turn into next steps."),
                prompts: [
                    guidePrompt(
                        id: "break_top_priority",
                        title: String(localized: "Break down priority"),
                        submissionText: "Help me break down my top priority into next steps."
                    )
                ]
            ),
            EvaChiefOfStaffGuideSection(
                id: "structured_context",
                icon: "command",
                title: String(localized: "Commands"),
                body: String(localized: "Type / for commands like /today, /week, or /project."),
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
                title: String(localized: "Review changes"),
                body: String(localized: "\(identity.displayName) shows changes as cards first. Apply what you want."),
                prompts: [
                    guidePrompt(
                        id: "plan_today_for_review",
                        title: String(localized: "Draft a plan"),
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

    static var curatedHomePromptChips: [EvaHomePromptChip] {
        [
            homePromptChip(
                id: "home_how_is_my_day",
                icon: "sparkles",
                title: String(localized: "How is my day?"),
                submissionText: "How is my day looking today?"
            ),
            homePromptChip(
                id: "home_plan_today",
                icon: "arrow.triangle.2.circlepath",
                title: String(localized: "Plan today"),
                submissionText: "Help me plan today around my existing tasks and habits."
            ),
            homePromptChip(
                id: "home_recover_overdue",
                icon: "sun.max",
                title: String(localized: "Review earlier tasks"),
                submissionText: "Show me what is overdue and what I should recover first."
            ),
            homePromptChip(
                id: "home_carry_todays_overdues_to_tomorrow",
                icon: "calendar.badge.clock",
                title: String(localized: "Earlier tasks to Tomorrow"),
                submissionText: "Move today's overdue tasks to tomorrow."
            ),
            homePromptChip(
                id: "home_overdue_today_first_then_rest",
                icon: "calendar.badge.clock",
                title: String(localized: "Earlier tasks first"),
                submissionText: "Plan today with overdue tasks first, then the rest."
            )
        ]
    }

    static func guideHomePromptChips(for identity: AssistantIdentitySnapshot) -> [EvaHomePromptChip] {
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

    static func guidePrompt(
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

    static func homePromptChip(
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
