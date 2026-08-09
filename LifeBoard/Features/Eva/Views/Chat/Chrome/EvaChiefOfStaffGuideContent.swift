import SwiftUI

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

    static var curatedHomePromptChips: [EvaHomePromptChip] {
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
