import SwiftUI

public enum InsightsAvailabilityState: Equatable, Sendable {
    case empty
    case partial
    case rich
}

public enum InsightsModuleVisibility: Equatable {
    case visible
    case empty(message: String)
    case hidden
}

public enum InsightsDetailAnchor: String, Equatable, Hashable, Sendable {
    case weeklyRhythm
    case streakResilience
}

public enum InsightsActionIntent: Equatable, Sendable {
    case addTask
    case openToday
    case startNextDecision
    case protectFocus
    case openYesterdayReview
    case openHabitCheck
    case openBacklogRecovery
    case openProjectMix
    case openWeeklyReview
    case openWeeklyPlanner
    case openReminderSettings
    case expandDetails(InsightsDetailAnchor)
}

public enum InsightsActionSource: Equatable {
    case hero(tab: InsightsViewModel.InsightsTab, availability: InsightsAvailabilityState, primaryCTAIntent: InsightsActionIntent)
    case card(tab: InsightsViewModel.InsightsTab, id: String)
}

public enum InsightsActionResolver {
    public static func intent(for source: InsightsActionSource) -> InsightsActionIntent {
        switch source {
        case .hero(_, _, let primaryCTAIntent):
            return heroIntent(primaryCTAIntent: primaryCTAIntent)
        case .card(let tab, let id):
            return cardIntent(tab: tab, id: id)
        }
    }

    private static func heroIntent(primaryCTAIntent: InsightsActionIntent) -> InsightsActionIntent {
        primaryCTAIntent
    }

    private static func cardIntent(
        tab: InsightsViewModel.InsightsTab,
        id: String
    ) -> InsightsActionIntent {
        switch (tab, id) {
        case (.today, "overdueRescue"):
            return .openBacklogRecovery
        case (.today, "nextDecision"):
            return .startNextDecision
        case (.today, "protectFocus"):
            return .protectFocus
        case (.today, "habitCheck"):
            return .openHabitCheck
        case (.today, "yesterdayReview"):
            return .openYesterdayReview
        case (.week, "weeklyMomentum"):
            return .expandDetails(.weeklyRhythm)
        case (.week, "backlogDrag"), (.week, "backlogTrack"):
            return .openBacklogRecovery
        case (.week, "projectMix"):
            return .openProjectMix
        case (.week, "recovery"):
            return .openWeeklyReview
        case (.systems, "reminderResponse"):
            return .openReminderSettings
        case (.systems, "consistency"):
            return .expandDetails(.streakResilience)
        case (.systems, "focusHealth"):
            return .protectFocus
        case (.systems, "planningQuality"):
            return .openWeeklyPlanner
        default:
            switch tab {
            case .today:
                return .openToday
            case .week:
                return .expandDetails(.weeklyRhythm)
            case .systems:
                return .openWeeklyPlanner
            }
        }
    }
}

struct InsightsDiagnosisPresentation: Equatable {
    let title: String
    let explanation: String
    let evidence: String
    let role: LBRole
    let asset: SunriseDecorAsset
    let primaryCTATitle: String
    let primaryCTAIntent: InsightsActionIntent
}

struct InsightsMetricPresentation: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let detail: String
    let role: LBRole
    let systemImage: String
}

struct InsightsActionPresentation: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let systemImage: String
    let role: LBRole
    let ctaTitle: String
}

struct InsightsDetailPresentation: Equatable {
    let title: String
    let summary: String
}

struct InsightsTabPresentation: Equatable {
    let tab: InsightsViewModel.InsightsTab
    let availability: InsightsAvailabilityState
    let attentionPillTitle: String
    let diagnosis: InsightsDiagnosisPresentation
    let metrics: [InsightsMetricPresentation]
    let actions: [InsightsActionPresentation]
    let details: InsightsDetailPresentation

    @MainActor
    static func build(
        tab: InsightsViewModel.InsightsTab,
        viewModel: InsightsViewModel,
        momentumGuidanceText: String
    ) -> InsightsTabPresentation {
        switch tab {
        case .today:
            return buildToday(viewModel.todayState, momentumGuidanceText: momentumGuidanceText)
        case .week:
            return buildWeek(viewModel.weekState)
        case .systems:
            return buildSystems(viewModel.systemsState)
        }
    }

    private static func buildToday(
        _ state: InsightsTodayState,
        momentumGuidanceText: String
    ) -> InsightsTabPresentation {
        let openCount = max(0, state.totalTasksToday - state.tasksCompletedToday)
        let availability: InsightsAvailabilityState
        if state.totalTasksToday == 0, state.dailyXP == 0 {
            availability = .empty
        } else if state.tasksCompletedToday == 0 || state.duePressureMetrics.isEmpty {
            availability = .partial
        } else {
            availability = .rich
        }

        let staleDetail = state.duePressureMetrics.first?.detail ?? String(localized: "insights.today.duePressure.fallback", defaultValue: "Open loops are ready for a decision.")
        let diagnosisTitle: String
        let diagnosisExplanation: String
        let ctaTitle: String
        let ctaIntent: InsightsActionIntent
        switch availability {
        case .empty:
            diagnosisTitle = String(localized: "insights.today.diagnosis.empty.title", defaultValue: "No signal yet")
            diagnosisExplanation = String(localized: "insights.today.diagnosis.empty.explanation", defaultValue: "Add a task, habit, or calendar connection to unlock useful progress insights.")
            ctaTitle = String(localized: "insights.today.diagnosis.empty.cta", defaultValue: "Add task")
            ctaIntent = .addTask
        case .partial:
            diagnosisTitle = String(localized: "insights.today.diagnosis.partial.title", defaultValue: "A pattern is starting")
            diagnosisExplanation = String(localized: "insights.today.diagnosis.partial.explanation", defaultValue: "LifeBoard has enough activity to guide the next move, but not enough completions to call it a trend.")
            ctaTitle = String(localized: "insights.today.diagnosis.partial.cta", defaultValue: "Open today")
            ctaIntent = .openToday
        case .rich:
            diagnosisTitle = openCount > 0
                ? String(localized: "insights.today.diagnosis.rich.pressure.title", defaultValue: "Pressure is visible.")
                : String(localized: "insights.today.diagnosis.rich.momentum.title", defaultValue: "Momentum is visible.")
            diagnosisExplanation = openCount > 0
                ? String(localized: "insights.today.diagnosis.rich.pressure.explanation", defaultValue: "Next: clear or reschedule the oldest open loop.")
                : String(localized: "insights.today.diagnosis.rich.momentum.explanation", defaultValue: "Next: protect the progress already made today.")
            ctaTitle = openCount > 0
                ? String(localized: "insights.today.diagnosis.rich.pressure.cta", defaultValue: "Review today")
                : String(localized: "insights.today.diagnosis.rich.momentum.cta", defaultValue: "Keep momentum")
            ctaIntent = openCount > 0 ? .startNextDecision : .protectFocus
        }

        let overdueCount = Int(state.duePressureMetrics.first(where: { $0.id == "overdue" })?.value ?? "") ?? 0
        let estimatedMinutes = max(2, min(12, overdueCount))
        let overdueRescueAction = overdueCount > 0
            ? [
                InsightsActionPresentation(
                    id: "overdueRescue",
                    title: String(localized: "insights.today.action.overdueRescue.title", defaultValue: "Overdue Rescue"),
                    message: String(
                        format: String(localized: "insights.today.action.overdueRescue.message", defaultValue: "Tasks need your attention · %lld overdue · Est. %lld min"),
                        locale: Locale.current,
                        overdueCount,
                        estimatedMinutes
                    ),
                    systemImage: "lifepreserver",
                    role: .warning,
                    ctaTitle: String(localized: "insights.today.action.overdueRescue.cta", defaultValue: "Start rescue")
                )
            ]
            : []
        let todayActions = overdueRescueAction + [
            InsightsActionPresentation(id: "nextDecision", title: String(localized: "insights.today.action.nextDecision.title", defaultValue: "Next decision"), message: firstDetail(from: state.duePressureMetrics, fallback: String(localized: "insights.today.action.nextDecision.fallback", defaultValue: "Choose one task to remove from today.")), systemImage: "exclamationmark.arrow.triangle.2.circlepath", role: .warning, ctaTitle: String(localized: "insights.today.action.nextDecision.cta", defaultValue: "Choose next task")),
            InsightsActionPresentation(id: "protectFocus", title: String(localized: "insights.today.action.protectFocus.title", defaultValue: "Protect focus"), message: firstDetail(from: state.focusMetrics, fallback: momentumGuidanceText), systemImage: "sparkles", role: .focus, ctaTitle: String(localized: "insights.today.action.protectFocus.cta", defaultValue: "Plan focus block")),
            InsightsActionPresentation(id: "habitCheck", title: String(localized: "insights.today.action.habitCheck.title", defaultValue: "Habit check"), message: firstDetail(from: state.recoveryMetrics, fallback: String(localized: "insights.today.action.habitCheck.fallback", defaultValue: "Update the smallest pending habit signal.")), systemImage: "checkmark.seal", role: .routine, ctaTitle: String(localized: "insights.today.action.habitCheck.cta", defaultValue: "Update habits")),
            InsightsActionPresentation(id: "yesterdayReview", title: String(localized: "insights.today.action.yesterdayReview.title", defaultValue: "Yesterday review"), message: firstDetail(from: state.momentumMetrics, fallback: String(localized: "insights.today.action.yesterdayReview.fallback", defaultValue: "Review carry-over and keep tomorrow tight.")), systemImage: "arrow.uturn.backward.circle", role: .assistant, ctaTitle: String(localized: "insights.today.action.yesterdayReview.cta", defaultValue: "Review carry-over"))
        ]

        return InsightsTabPresentation(
            tab: .today,
            availability: availability,
            attentionPillTitle: attentionPill(for: availability, count: openCount),
            diagnosis: InsightsDiagnosisPresentation(
                title: diagnosisTitle,
                explanation: diagnosisExplanation,
                evidence: String(
                    format: String(localized: "insights.today.diagnosis.evidence", defaultValue: "%lld done - %lld open - %@"),
                    locale: Locale.current,
                    state.tasksCompletedToday,
                    openCount,
                    staleDetail
                ),
                role: openCount > 0 ? .warning : .focus,
                asset: openCount > 0 ? .happySun : .growthPlant,
                primaryCTATitle: ctaTitle,
                primaryCTAIntent: ctaIntent
            ),
            metrics: [
                InsightsMetricPresentation(id: "closed", label: String(localized: "insights.today.metric.closed.label", defaultValue: "Closed"), value: "\(state.tasksCompletedToday)", detail: String(localized: "insights.today.metric.closed.detail", defaultValue: "Done today"), role: .task, systemImage: "checkmark.circle"),
                InsightsMetricPresentation(id: "focus", label: String(localized: "insights.today.metric.focus.label", defaultValue: "Focus"), value: metricValue(from: state.focusMetrics, fallback: String(localized: "insights.today.metric.focus.valueFallback", defaultValue: "0m")), detail: firstDetail(from: state.focusMetrics, fallback: momentumGuidanceText), role: .focus, systemImage: "target"),
                InsightsMetricPresentation(id: "habits", label: String(localized: "insights.today.metric.habits.label", defaultValue: "Habits"), value: "\(state.recoveryCount)", detail: String(localized: "insights.today.metric.habits.detail", defaultValue: "Recovery signals"), role: .routine, systemImage: "repeat.circle"),
                InsightsMetricPresentation(id: "open", label: String(localized: "insights.today.metric.open.label", defaultValue: "Open"), value: "\(openCount)", detail: String(localized: "insights.today.metric.open.detail", defaultValue: "Still active"), role: openCount > 0 ? .warning : .task, systemImage: "tray")
            ],
            actions: todayActions,
            details: InsightsDetailPresentation(
                title: String(localized: "insights.today.details.title", defaultValue: "Today details"),
                summary: String(localized: "insights.today.details.summary", defaultValue: "XP, pressure, recovery, and completion mix stay here when you need them.")
            )
        )
    }

    private static func buildWeek(_ state: InsightsWeekState) -> InsightsTabPresentation {
        let activeDays = state.weeklyBars.filter { $0.xp > 0 }.count
        let carryOver = nonEmpty(state.weeklyOperating?.carryOverSummary) ?? state.deltaSummary
        let availability: InsightsAvailabilityState
        if state.weeklyTotalXP == 0, state.weeklyBars.isEmpty {
            availability = .empty
        } else if activeDays < 2 || state.weeklySummaryMetrics.isEmpty {
            availability = .partial
        } else {
            availability = .rich
        }

        let isBacklogVisible = carryOver.localizedCaseInsensitiveContains("carry")
            || carryOver.localizedCaseInsensitiveContains("stale")
            || carryOver.localizedCaseInsensitiveContains("overdue")
        let title: String
        let explanation: String
        switch availability {
        case .empty:
            title = String(localized: "insights.week.diagnosis.empty.title", defaultValue: "No weekly signal yet")
            explanation = String(localized: "insights.week.diagnosis.empty.explanation", defaultValue: "Use LifeBoard for a few tasks this week to reveal momentum, backlog, and recovery patterns.")
        case .partial:
            title = String(localized: "insights.week.diagnosis.partial.title", defaultValue: "A weekly pattern is forming")
            explanation = String(localized: "insights.week.diagnosis.partial.explanation", defaultValue: "A few active days are visible. More completions will make the diagnosis sharper.")
        case .rich:
            title = isBacklogVisible
                ? String(localized: "insights.week.diagnosis.rich.backlog.title", defaultValue: "Backlog drag is visible.")
                : String(localized: "insights.week.diagnosis.rich.momentum.title", defaultValue: "Weekly momentum is visible.")
            explanation = isBacklogVisible
                ? String(localized: "insights.week.diagnosis.rich.backlog.explanation", defaultValue: "Next: close, reschedule, or delete old work before it drags into next week.")
                : String(localized: "insights.week.diagnosis.rich.momentum.explanation", defaultValue: "Next: protect the days that are already working.")
        }

        return InsightsTabPresentation(
            tab: .week,
            availability: availability,
            attentionPillTitle: attentionPill(for: availability, count: max(0, state.weeklyTotalXP - state.previousWeekTotalXP)),
            diagnosis: InsightsDiagnosisPresentation(
                title: title,
                explanation: explanation,
                evidence: String(
                    format: String(localized: "insights.week.diagnosis.evidence", defaultValue: "%lld XP - %lld active days - %@"),
                    locale: Locale.current,
                    state.weeklyTotalXP,
                    activeDays,
                    nonEmpty(carryOver) ?? String(localized: "insights.week.carryOverSignal.fallback", defaultValue: "No carry-over signal yet.")
                ),
                role: isBacklogVisible ? .warning : .routine,
                asset: .mountain,
                primaryCTATitle: isBacklogVisible
                    ? String(localized: "insights.week.diagnosis.rich.backlog.cta", defaultValue: "Clean backlog")
                    : String(localized: "insights.week.diagnosis.rich.momentum.cta", defaultValue: "See momentum"),
                primaryCTAIntent: isBacklogVisible ? .openBacklogRecovery : .expandDetails(.weeklyRhythm)
            ),
            metrics: [
                InsightsMetricPresentation(id: "closed", label: String(localized: "insights.week.metric.closed.label", defaultValue: "Closed"), value: metricValue(from: state.weeklySummaryMetrics, fallback: "+\(max(0, state.weeklyTotalXP - state.previousWeekTotalXP))"), detail: String(localized: "insights.week.metric.closed.detail", defaultValue: "Weekly movement"), role: .task, systemImage: "checkmark.circle"),
                InsightsMetricPresentation(id: "activeDays", label: String(localized: "insights.week.metric.activeDays.label", defaultValue: "Active days"), value: "\(activeDays)", detail: String(localized: "insights.week.metric.activeDays.detail", defaultValue: "Days with XP"), role: .routine, systemImage: "calendar"),
                InsightsMetricPresentation(id: "carryOver", label: String(localized: "insights.week.metric.carryOver.label", defaultValue: "Carry-over"), value: state.weeklyOperating == nil ? String(localized: "insights.week.metric.carryOver.thin", defaultValue: "Thin") : String(localized: "insights.week.metric.carryOver.live", defaultValue: "Live"), detail: nonEmpty(carryOver) ?? String(localized: "insights.week.metric.carryOver.detailFallback", defaultValue: "No carry-over trend yet"), role: isBacklogVisible ? .warning : .assistant, systemImage: "arrow.clockwise"),
                InsightsMetricPresentation(id: "focus", label: String(localized: "insights.week.metric.focus.label", defaultValue: "Focus"), value: "\(state.averageDailyXP)", detail: String(localized: "insights.week.metric.focus.detail", defaultValue: "Avg daily XP"), role: .focus, systemImage: "target")
            ],
            actions: [
                InsightsActionPresentation(id: "weeklyMomentum", title: String(localized: "insights.week.action.weeklyMomentum.title", defaultValue: "Weekly momentum"), message: nonEmpty(state.patternSummary) ?? String(localized: "insights.week.action.weeklyMomentum.fallback", defaultValue: "See how this week compares with your usual rhythm."), systemImage: "chart.bar.xaxis", role: .routine, ctaTitle: String(localized: "insights.week.action.weeklyMomentum.cta", defaultValue: "See momentum")),
                InsightsActionPresentation(id: "backlogDrag", title: String(localized: "insights.week.action.backlogDrag.title", defaultValue: "Backlog drag"), message: nonEmpty(carryOver) ?? String(localized: "insights.week.action.backlogDrag.fallback", defaultValue: "Old work will appear here once carry-over is visible."), systemImage: "tray.and.arrow.down", role: .warning, ctaTitle: String(localized: "insights.week.action.backlogDrag.cta", defaultValue: "Clean backlog")),
                InsightsActionPresentation(id: "projectMix", title: String(localized: "insights.week.action.projectMix.title", defaultValue: "Project mix"), message: state.projectLeaderboard.first.map { "\($0.title): \($0.detail)" } ?? String(localized: "insights.week.action.projectMix.fallback", defaultValue: "Balance Work, Personal, Habits, Focus, and Routines."), systemImage: "folder", role: .assistant, ctaTitle: String(localized: "insights.week.action.projectMix.cta", defaultValue: "Balance week")),
                InsightsActionPresentation(id: "recovery", title: String(localized: "insights.week.action.recovery.title", defaultValue: "Recovery"), message: nonEmpty(state.weeklyOperating?.recoverySummary) ?? String(localized: "insights.week.action.recovery.fallback", defaultValue: "Run a weekly review to tighten the next plan."), systemImage: "heart", role: .personal, ctaTitle: String(localized: "insights.week.action.recovery.cta", defaultValue: "Run weekly review"))
            ],
            details: InsightsDetailPresentation(
                title: String(localized: "insights.week.details.title", defaultValue: "Week details"),
                summary: String(localized: "insights.week.details.summary", defaultValue: "Momentum bars, project mix, priority mix, and operating review.")
            )
        )
    }

    private static func buildSystems(_ state: InsightsSystemsState) -> InsightsTabPresentation {
        let activeDays = max(state.streakDays, state.returnStreak)
        let hasReminderSignal = state.reminderResponse.totalDeliveries > 0
        let hasFocusSignal = state.focusHealthMetrics.isEmpty == false
        let availability: InsightsAvailabilityState
        if state.totalXP == 0, hasReminderSignal == false, hasFocusSignal == false {
            availability = .empty
        } else if hasReminderSignal == false || hasFocusSignal == false {
            availability = .partial
        } else {
            availability = .rich
        }

        let title: String
        let explanation: String
        switch availability {
        case .empty:
            title = String(localized: "insights.systems.diagnosis.empty.title", defaultValue: "Your system is under-instrumented.")
            explanation = String(localized: "insights.systems.diagnosis.empty.explanation", defaultValue: "Start tracking tasks, reminders, focus rituals, or reviews to make system health visible.")
        case .partial:
            title = String(localized: "insights.systems.diagnosis.partial.title", defaultValue: "Your system is coming online.")
            explanation = String(localized: "insights.systems.diagnosis.partial.explanation", defaultValue: "Tasks are visible, but reminders, focus rituals, or reviews are still thin.")
        case .rich:
            title = String(localized: "insights.systems.diagnosis.rich.title", defaultValue: "System health is visible.")
            explanation = String(localized: "insights.systems.diagnosis.rich.explanation", defaultValue: "Next: tune the weakest reminder, focus, or review loop.")
        }

        return InsightsTabPresentation(
            tab: .systems,
            availability: availability,
            attentionPillTitle: attentionPill(for: availability, count: state.reminderResponse.pendingDeliveries),
            diagnosis: InsightsDiagnosisPresentation(
                title: title,
                explanation: explanation,
                evidence: String(
                    format: String(localized: "insights.systems.diagnosis.evidence", defaultValue: "%lld reminders - %lld focus signals - %lld active days"),
                    locale: Locale.current,
                    state.reminderResponse.totalDeliveries,
                    state.focusHealthMetrics.count,
                    activeDays
                ),
                role: availability == .rich ? .assistant : .warning,
                asset: .thinkingCup,
                primaryCTATitle: hasReminderSignal
                    ? String(localized: "insights.systems.diagnosis.reminders.cta", defaultValue: "Tune reminders")
                    : String(localized: "insights.systems.diagnosis.empty.cta", defaultValue: "Set one reminder"),
                primaryCTAIntent: .openReminderSettings
            ),
            metrics: [
                InsightsMetricPresentation(id: "reminders", label: String(localized: "insights.systems.metric.reminders.label", defaultValue: "Reminders"), value: "\(state.reminderResponse.totalDeliveries)", detail: state.reminderResponse.detail, role: .assistant, systemImage: "bell.badge"),
                InsightsMetricPresentation(id: "focusRituals", label: String(localized: "insights.systems.metric.focusRituals.label", defaultValue: "Focus rituals"), value: "\(state.focusHealthMetrics.count)", detail: firstDetail(from: state.focusHealthMetrics, fallback: String(localized: "insights.systems.metric.focusRituals.detailFallback", defaultValue: "Create one protected block.")), role: .focus, systemImage: "target"),
                InsightsMetricPresentation(id: "reviews", label: String(localized: "insights.systems.metric.reviews.label", defaultValue: "Reviews"), value: "\(state.recoveryHealthMetrics.count)", detail: firstDetail(from: state.recoveryHealthMetrics, fallback: String(localized: "insights.systems.metric.reviews.detailFallback", defaultValue: "Review rhythm is thin.")), role: .personal, systemImage: "moon.stars"),
                InsightsMetricPresentation(id: "activeDays", label: String(localized: "insights.systems.metric.activeDays.label", defaultValue: "Active days"), value: "\(activeDays)", detail: String(localized: "insights.systems.metric.activeDays.detail", defaultValue: "Current operating rhythm"), role: .task, systemImage: "checkmark.seal")
            ],
            actions: [
                InsightsActionPresentation(id: "reminderResponse", title: String(localized: "insights.systems.action.reminderResponse.title", defaultValue: "Reminder response"), message: state.reminderResponse.detail, systemImage: "bell.badge", role: .assistant, ctaTitle: String(localized: "insights.systems.action.reminderResponse.cta", defaultValue: "Tune reminders")),
                InsightsActionPresentation(id: "consistency", title: String(localized: "insights.systems.action.consistency.title", defaultValue: "Consistency"), message: firstDetail(from: state.streakMetrics, fallback: String(localized: "insights.systems.action.consistency.fallback", defaultValue: "Active days and recurring completion build the rhythm.")), systemImage: "checkmark.seal", role: .task, ctaTitle: String(localized: "insights.systems.action.consistency.cta", defaultValue: "View rhythm")),
                InsightsActionPresentation(id: "focusHealth", title: String(localized: "insights.systems.action.focusHealth.title", defaultValue: "Focus health"), message: firstDetail(from: state.focusHealthMetrics, fallback: String(localized: "insights.systems.action.focusHealth.fallback", defaultValue: "Create a focus ritual to protect execution time.")), systemImage: "target", role: .focus, ctaTitle: String(localized: "insights.systems.action.focusHealth.cta", defaultValue: "Create focus ritual")),
                InsightsActionPresentation(id: "planningQuality", title: String(localized: "insights.systems.action.planningQuality.title", defaultValue: "Planning quality"), message: firstDetail(from: state.recoveryHealthMetrics, fallback: String(localized: "insights.systems.action.planningQuality.fallback", defaultValue: "Compare planned work with completed work and reschedules.")), systemImage: "list.bullet.clipboard", role: .routine, ctaTitle: String(localized: "insights.systems.action.planningQuality.cta", defaultValue: "Improve planning"))
            ],
            details: InsightsDetailPresentation(
                title: String(localized: "insights.systems.details.title", defaultValue: "System details"),
                summary: String(localized: "insights.systems.details.summary", defaultValue: "Reminder response, focus health, recovery health, streak resilience, and achievements.")
            )
        )
    }

    private static func attentionPill(for availability: InsightsAvailabilityState, count: Int) -> String {
        switch availability {
        case .empty:
            return String(localized: "insights.attention.empty", defaultValue: "No signal yet")
        case .partial:
            return String(localized: "insights.attention.partial", defaultValue: "Thin signal")
        case .rich:
            return count == 1
                ? String(localized: "insights.attention.rich.singular", defaultValue: "1 item needs attention")
                : String(
                    format: String(localized: "insights.attention.rich.plural", defaultValue: "%lld items need attention"),
                    locale: Locale.current,
                    max(0, count)
                )
        }
    }

    private static func firstDetail(from metrics: [InsightsMetricTile], fallback: String) -> String {
        guard let metric = metrics.first else { return fallback }
        return "\(metric.title): \(metric.value). \(metric.detail)"
    }

    private static func metricValue(from metrics: [InsightsMetricTile], fallback: String) -> String {
        metrics.first?.value ?? fallback
    }

    private static func nonEmpty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}

struct SunriseInsightsContentView: View {
    @ObservedObject var viewModel: InsightsViewModel
    let homeProgress: HomeProgressState
    let homeCompletionRate: Double
    let reflectionEligible: Bool
    let dailyReflectionEntryState: DailyReflectionEntryState?
    let momentumGuidanceText: String
    let animateMomentumCard: Bool
    let onOpenReflection: () -> Void
    let onPerformInsightAction: (InsightsActionIntent) -> Void
    @Binding var pendingDetailAnchor: InsightsDetailAnchor?
    @Binding var isWeekDetailsExpanded: Bool
    @Binding var isSystemsDetailsExpanded: Bool

    var body: some View {
        switch viewModel.selectedTab {
        case .today:
            SunriseInsightsTodayView(
                viewModel: viewModel,
                homeProgress: homeProgress,
                homeCompletionRate: homeCompletionRate,
                reflectionEligible: reflectionEligible,
                dailyReflectionEntryState: dailyReflectionEntryState,
                momentumGuidanceText: momentumGuidanceText,
                animateMomentumCard: animateMomentumCard,
                onOpenReflection: onOpenReflection,
                onPerformInsightAction: onPerformInsightAction,
                pendingDetailAnchor: $pendingDetailAnchor
            )
            .accessibilityIdentifier("home.insights.content.today")
        case .week:
            SunriseInsightsWeekView(
                viewModel: viewModel,
                onPerformInsightAction: onPerformInsightAction,
                pendingDetailAnchor: $pendingDetailAnchor,
                isDetailsExpanded: $isWeekDetailsExpanded
            )
                .accessibilityIdentifier("home.insights.content.week")
        case .systems:
            SunriseInsightsSystemsView(
                viewModel: viewModel,
                onPerformInsightAction: onPerformInsightAction,
                pendingDetailAnchor: $pendingDetailAnchor,
                isDetailsExpanded: $isSystemsDetailsExpanded
            )
                .accessibilityIdentifier("home.insights.content.systems")
        }
    }
}

private struct SunriseInsightsTodayView: View {
    @ObservedObject var viewModel: InsightsViewModel
    let homeProgress: HomeProgressState
    let homeCompletionRate: Double
    let reflectionEligible: Bool
    let dailyReflectionEntryState: DailyReflectionEntryState?
    let momentumGuidanceText: String
    let animateMomentumCard: Bool
    let onOpenReflection: () -> Void
    let onPerformInsightAction: (InsightsActionIntent) -> Void
    @Binding var pendingDetailAnchor: InsightsDetailAnchor?

    @State private var showDetails = false
    private var state: InsightsTodayState { viewModel.todayState }
    private var presentation: InsightsTabPresentation {
        InsightsTabPresentation.build(
            tab: .today,
            viewModel: viewModel,
            momentumGuidanceText: momentumGuidanceText
        )
    }

    var body: some View {
        LazyVStack(spacing: LBSpacingTokens.sm) {
            SunriseInsightsDiagnosisCard(
                presentation: presentation.diagnosis,
                action: { performHeroAction() }
            )

            SunriseInsightsMetricStrip(metrics: presentation.metrics)

            ForEach(presentation.actions) { action in
                SunriseInsightActionCard(
                    presentation: action,
                    action: { performActionCard(action) }
                )
            }

            if let dailyReflectionEntryState {
                SunriseInsightsReflectionCard(
                    state: dailyReflectionEntryState,
                    onOpen: onOpenReflection
                )
            }

            SunriseInsightDisclosureCard(
                title: presentation.details.title,
                summary: presentation.details.summary,
                isExpanded: $showDetails,
                accessibilityIdentifier: "home.insights.disclosure.todayDetails"
            ) {
                VStack(spacing: LBSpacingTokens.sm) {
                    HomeMomentumSummaryCard(
                        progress: homeProgress,
                        completionRate: homeCompletionRate,
                        reflectionEligible: reflectionEligible,
                        momentumGuidanceText: momentumGuidanceText,
                        animate: animateMomentumCard,
                        onOpenReflection: onOpenReflection
                    )
                    SunriseMetricSection(title: "Due pressure", metrics: state.duePressureMetrics)
                    SunriseMetricSection(title: "Focus pulse", metrics: state.focusMetrics)
                    SunriseMetricSection(title: "Momentum", metrics: state.momentumMetrics)
                    SunriseMetricSection(title: "Recovery", metrics: state.recoveryMetrics)
                    SunriseDistributionSections(title: "Completion mix", sections: state.completionMixSections)
                }
            }
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
        .padding(.bottom, LBSpacingTokens.xl)
    }

    private var primaryAction: () -> Void {
        if reflectionEligible {
            return onOpenReflection
        }
        return { LifeBoardFeedback.selection() }
    }

    private func performHeroAction() {
        let intent = InsightsActionResolver.intent(
                for: .hero(
                    tab: .today,
                    availability: presentation.availability,
                    primaryCTAIntent: presentation.diagnosis.primaryCTAIntent
                )
            )
        if intent == .openToday, reflectionEligible {
            onOpenReflection()
            return
        }
        perform(intent)
    }

    private func performActionCard(_ action: InsightsActionPresentation) {
        let intent = InsightsActionResolver.intent(for: .card(tab: .today, id: action.id))
        perform(intent)
    }

    private func perform(_ intent: InsightsActionIntent) {
        switch intent {
        case .expandDetails(let anchor):
            withAnimation(LifeBoardAnimation.snappy) {
                showDetails = true
            }
            LifeBoardFeedback.success()
            pendingDetailAnchor = anchor
        default:
            onPerformInsightAction(intent)
        }
    }

    private func firstDetail(from metrics: [InsightsMetricTile]) -> String? {
        guard let metric = metrics.first else { return nil }
        return "\(metric.title): \(metric.value). \(metric.detail)"
    }
}

private struct SunriseInsightsWeekView: View {
    @ObservedObject var viewModel: InsightsViewModel
    let onPerformInsightAction: (InsightsActionIntent) -> Void
    @Binding var pendingDetailAnchor: InsightsDetailAnchor?
    @Binding var isDetailsExpanded: Bool
    private var state: InsightsWeekState { viewModel.weekState }
    private var presentation: InsightsTabPresentation {
        InsightsTabPresentation.build(tab: .week, viewModel: viewModel, momentumGuidanceText: "")
    }

    var body: some View {
        LazyVStack(spacing: LBSpacingTokens.sm) {
            SunriseInsightsDiagnosisCard(
                presentation: presentation.diagnosis,
                accessibilityIdentifier: "home.insights.weekHero",
                action: { performHeroAction() }
            )

            SunriseInsightsMetricStrip(metrics: presentation.metrics)

            ForEach(presentation.actions) { action in
                SunriseInsightActionCard(
                    presentation: action,
                    action: { performActionCard(action) }
                )
            }

            SunriseInsightDisclosureCard(
                title: presentation.details.title,
                summary: presentation.details.summary,
                isExpanded: $isDetailsExpanded,
                accessibilityIdentifier: "home.insights.disclosure.weekDetails"
            ) {
                VStack(spacing: LBSpacingTokens.sm) {
                    SunriseWeekBarsCard(state: state, scaleMode: viewModel.weekScaleMode)
                        .id(InsightsDetailAnchor.weeklyRhythm)
                        .accessibilityIdentifier("home.insights.weeklyRhythm")
                    SunriseMetricSection(
                        title: "Week summary",
                        metrics: state.weeklySummaryMetrics,
                        accessibilityIdentifier: "home.insights.weekSummary"
                    )
                    SunriseLeaderboardCard(rows: state.projectLeaderboard)
                    SunriseDistributionItems(title: "Priority mix", items: state.priorityMix)
                    SunriseDistributionItems(title: "Task-type mix", items: state.taskTypeMix)
                    if let weeklyOperating = state.weeklyOperating {
                        SunriseNarrativeCard(title: "Operating review", message: weeklyOperating.momentumNarrative)
                        SunriseNarrativeCard(title: "Carry-over", message: weeklyOperating.carryOverSummary)
                    }
                }
            }
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
        .padding(.bottom, LBSpacingTokens.xl)
    }

    private func performHeroAction() {
        let intent = InsightsActionResolver.intent(
                for: .hero(
                    tab: .week,
                    availability: presentation.availability,
                    primaryCTAIntent: presentation.diagnosis.primaryCTAIntent
                )
            )
        perform(intent)
    }

    private func performActionCard(_ action: InsightsActionPresentation) {
        let intent = InsightsActionResolver.intent(for: .card(tab: .week, id: action.id))
        perform(intent)
    }

    private func perform(_ intent: InsightsActionIntent) {
        switch intent {
        case .expandDetails(let anchor):
            withAnimation(LifeBoardAnimation.snappy) {
                isDetailsExpanded = true
            }
            LifeBoardFeedback.success()
            pendingDetailAnchor = anchor
        default:
            onPerformInsightAction(intent)
        }
    }
}

private struct SunriseInsightsSystemsView: View {
    @ObservedObject var viewModel: InsightsViewModel
    let onPerformInsightAction: (InsightsActionIntent) -> Void
    @Binding var pendingDetailAnchor: InsightsDetailAnchor?
    @Binding var isDetailsExpanded: Bool
    private var state: InsightsSystemsState { viewModel.systemsState }
    private var presentation: InsightsTabPresentation {
        InsightsTabPresentation.build(tab: .systems, viewModel: viewModel, momentumGuidanceText: "")
    }

    var body: some View {
        LazyVStack(spacing: LBSpacingTokens.sm) {
            SunriseInsightsDiagnosisCard(
                presentation: presentation.diagnosis,
                action: { performHeroAction() }
            )

            SunriseInsightsMetricStrip(metrics: presentation.metrics)

            ForEach(presentation.actions) { action in
                SunriseInsightActionCard(
                    presentation: action,
                    action: { performActionCard(action) }
                )
            }

            SunriseInsightDisclosureCard(
                title: presentation.details.title,
                summary: presentation.details.summary,
                isExpanded: $isDetailsExpanded
            ) {
                VStack(spacing: LBSpacingTokens.sm) {
                    SunriseReminderResponseCard(state: state.reminderResponse)
                    SunriseMetricSection(title: "Focus health", metrics: state.focusHealthMetrics)
                    SunriseMetricSection(title: "Recovery health", metrics: state.recoveryHealthMetrics)
                    SunriseMetricSection(title: "Streak resilience", metrics: state.streakMetrics)
                        .id(InsightsDetailAnchor.streakResilience)
                        .accessibilityIdentifier("home.insights.streakResilience")
                    SunriseMetricSection(title: "Achievement velocity", metrics: state.achievementVelocityMetrics)
                    SunriseNarrativeCard(
                        title: "Achievements",
                        message: "\(state.unlockedAchievements.count) unlocked. \(state.nextMilestone.map { "Next: \($0.name)." } ?? "Top milestone reached.")"
                    )
                }
            }
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
        .padding(.bottom, LBSpacingTokens.xl)
    }

    private func firstDetail(from metrics: [InsightsMetricTile]) -> String? {
        guard let metric = metrics.first else { return nil }
        return "\(metric.title): \(metric.value). \(metric.detail)"
    }

    private func performHeroAction() {
        let intent = InsightsActionResolver.intent(
                for: .hero(
                    tab: .systems,
                    availability: presentation.availability,
                    primaryCTAIntent: presentation.diagnosis.primaryCTAIntent
                )
            )
        perform(intent)
    }

    private func performActionCard(_ action: InsightsActionPresentation) {
        let intent = InsightsActionResolver.intent(for: .card(tab: .systems, id: action.id))
        perform(intent)
    }

    private func perform(_ intent: InsightsActionIntent) {
        switch intent {
        case .expandDetails(let anchor):
            withAnimation(LifeBoardAnimation.snappy) {
                isDetailsExpanded = true
            }
            LifeBoardFeedback.success()
            pendingDetailAnchor = anchor
        default:
            onPerformInsightAction(intent)
        }
    }
}

private struct SunriseInsightHeroCard: View {
    let eyebrow: String
    let title: String
    let answer: String
    let metric: String
    let role: LBRole
    let primaryActionTitle: String?
    let primaryAction: () -> Void

    private var style: LBRoleStyle { LBColorTokens.role(role) }

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            Label(eyebrow, systemImage: style.symbolName)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(style.deep)

            Text(title)
                .font(.lifeboard(.title2))
                .foregroundStyle(LBColorTokens.navy)
                .fixedSize(horizontal: false, vertical: true)

            Text(answer)
                .font(.lifeboard(.headline))
                .foregroundStyle(LBColorTokens.navySoft)
                .fixedSize(horizontal: false, vertical: true)

            Text(metric)
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let primaryActionTitle {
                Button(primaryActionTitle, systemImage: "arrow.right", action: primaryAction)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, LBSpacingTokens.md)
                    .frame(minHeight: 44)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: LBColorTokens.actionGradient(for: role),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LBSpacingTokens.lg)
        .sunriseInsightSurface(role: role, cornerRadius: 28)
    }
}

private struct SunriseInsightsDiagnosisCard: View {
    let presentation: InsightsDiagnosisPresentation
    var accessibilityIdentifier: String = "home.insights.hero"
    let action: () -> Void

    private var style: LBRoleStyle { LBColorTokens.role(presentation.role) }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
                    Label("Primary diagnosis", systemImage: style.symbolName)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(style.deep)

                    Text(presentation.title)
                        .font(.lifeboard(.title2).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(presentation.explanation)
                        .font(.lifeboard(.headline))
                        .foregroundStyle(LBColorTokens.navySoft)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(presentation.evidence)
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(style.deep)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("home.insights.hero.metric")

                    Text(presentation.primaryCTATitle)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(LBColorTokens.violetDeep)
                        .padding(.horizontal, LBSpacingTokens.sm)
                        .frame(minHeight: 32)
                        .background(LBColorTokens.glassStrong, in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(LBSpacingTokens.md)
                .padding(.trailing, 92)

                SunriseDecorImage(asset: presentation.asset, size: 116, opacity: 0.92)
                    .offset(x: 18, y: 14)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 158, alignment: .leading)
        }
        .buttonStyle(.plain)
        .secondaryInsightSurface(role: presentation.role, cornerRadius: 28)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct SunriseInsightsMetricStrip: View {
    let metrics: [InsightsMetricPresentation]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: LBSpacingTokens.xs) {
                metricCards
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LBSpacingTokens.xs) {
                metricCards
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.insights.metricStrip")
    }

    private var metricCards: some View {
        ForEach(metrics) { metric in
            SunriseInsightsMetricCard(metric: metric)
        }
    }
}

private struct SunriseInsightsMetricCard: View {
    let metric: InsightsMetricPresentation
    private var style: LBRoleStyle { LBColorTokens.role(metric.role) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(style.deep)
                Text(metric.label)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(LBColorTokens.textTertiary)
                    .lineLimit(1)
            }

            Text(metric.value)
                .font(.lifeboard(.title3).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(metric.detail)
                .font(.lifeboard(.caption1))
                .foregroundStyle(LBColorTokens.navyMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
        .padding(LBSpacingTokens.sm)
        .secondaryInsightSurface(role: metric.role, cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(metric.label), \(metric.value), \(metric.detail)")
    }
}

private struct SunriseInsightActionCard: View {
    let presentation: InsightsActionPresentation
    let action: () -> Void

    private var style: LBRoleStyle { LBColorTokens.role(presentation.role) }

    var body: some View {
        HStack(alignment: .center, spacing: LBSpacingTokens.sm) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(style.deep)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(style.softSurface.opacity(0.92))
                        .overlay(Circle().stroke(style.border.opacity(0.48), lineWidth: 1))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.title)
                    .font(.lifeboard(.headline).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                Text(presentation.message)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(presentation.ctaTitle)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(style.deep)
            }

            Spacer(minLength: LBSpacingTokens.sm)

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(LBColorTokens.textTertiary)
        }
        .padding(LBSpacingTokens.md)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .secondaryInsightSurface(role: presentation.role, cornerRadius: 24)
        .onTapGesture(perform: action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text(presentation.ctaTitle), action)
        .accessibilityIdentifier("home.insights.action.\(presentation.id)")
    }
}

private struct SunriseInsightDisclosureCard<Content: View>: View {
    let title: String
    let summary: String
    @Binding var isExpanded: Bool
    var accessibilityIdentifier: String? = nil
    @ViewBuilder let content: () -> Content

    private var resolvedAccessibilityIdentifier: String {
        accessibilityIdentifier ?? "home.insights.disclosure.\(title.lifeboardAccessibilitySlug)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? LBSpacingTokens.md : 0) {
            Button {
                withAnimation(LifeBoardAnimation.snappy) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: LBSpacingTokens.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.lifeboard(.headline))
                            .foregroundStyle(LBColorTokens.navy)
                        Text(summary)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LBColorTokens.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(resolvedAccessibilityIdentifier)
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")

            if isExpanded {
                content()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(LBSpacingTokens.md)
        .sunriseInsightSurface(role: .neutral, cornerRadius: 22)
    }
}

private extension String {
    var lifeboardAccessibilitySlug: String {
        lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

private struct SunriseMetricSection: View {
    let title: String
    let metrics: [InsightsMetricTile]
    var accessibilityIdentifier: String?

    var body: some View {
        if metrics.isEmpty == false {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text(title)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                    .accessibilityIdentifier(accessibilityIdentifier ?? "home.insights.metric.\(title.lifeboardAccessibilitySlug)")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LBSpacingTokens.xs) {
                    ForEach(metrics) { metric in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(metric.title)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(LBColorTokens.textTertiary)
                            Text(metric.value)
                                .font(.lifeboard(.headline))
                                .foregroundStyle(color(for: metric.tone))
                            Text(metric.detail)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(LBColorTokens.navyMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
                        .padding(LBSpacingTokens.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(LBColorTokens.glassStrong)
                        )
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .accessibilityIdentifier(accessibilityIdentifier ?? "home.insights.metric.\(title.lifeboardAccessibilitySlug)")
        }
    }

    private func color(for tone: InsightsMetricTone) -> Color {
        switch tone {
        case .accent:
            return LBColorTokens.violet
        case .success:
            return LBColorTokens.leaf
        case .warning:
            return LBColorTokens.sunriseGold
        case .neutral:
            return LBColorTokens.navy
        }
    }
}

private struct SunriseDistributionSections: View {
    let title: String
    let sections: [InsightsDistributionSection]

    var body: some View {
        if sections.isEmpty == false {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text(title)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                ForEach(sections) { section in
                    SunriseDistributionItems(title: section.title, items: section.items)
                }
            }
        }
    }
}

private struct SunriseDistributionItems: View {
    let title: String
    let items: [InsightsDistributionItem]

    var body: some View {
        if items.isEmpty == false {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text(title)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navyMuted)
                ForEach(items) { item in
                    HStack(spacing: LBSpacingTokens.xs) {
                        Text(item.label)
                            .font(.lifeboard(.callout))
                            .foregroundStyle(LBColorTokens.navy)
                        Spacer()
                        Text(item.valueText)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(LBColorTokens.navyMuted)
                    }
                    .padding(LBSpacingTokens.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LBColorTokens.glassStrong)
                    )
                }
            }
        }
    }
}

private struct SunriseLeaderboardCard: View {
    let rows: [InsightsLeaderboardRow]

    var body: some View {
        if rows.isEmpty == false {
            VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                Text("Project movement")
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(LBColorTokens.navy)
                ForEach(rows.prefix(5)) { row in
                    HStack(spacing: LBSpacingTokens.xs) {
                        Text(row.subtitle)
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(LBColorTokens.textTertiary)
                        Text(row.title)
                            .font(.lifeboard(.callout))
                            .foregroundStyle(LBColorTokens.navy)
                        Spacer()
                        Text(row.value)
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(LBColorTokens.violet)
                    }
                    .padding(LBSpacingTokens.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LBColorTokens.glassStrong)
                    )
                }
            }
            .accessibilityIdentifier("home.insights.projectLeaderboard")
        }
    }
}

private struct SunriseWeekBarsCard: View {
    let state: InsightsWeekState
    let scaleMode: InsightsWeekScaleMode

    private var maxBarXP: Int {
        let personalMax = max(state.weeklyBars.map(\.xp).max() ?? 1, 1)
        switch scaleMode {
        case .goal:
            return personalMax
        case .personalMax:
            return personalMax
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
            Text("Weekly rhythm")
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)

            if state.weeklyBars.isEmpty {
                Text("Close a few tasks this week and LifeBoard will map the days that carry your momentum.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(LBSpacingTokens.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LBColorTokens.glassStrong)
                    )
            } else {
                HStack(alignment: .bottom, spacing: LBSpacingTokens.xs) {
                    ForEach(state.weeklyBars) { bar in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(bar.isToday ? LBColorTokens.violet : LBColorTokens.sunriseGold.opacity(0.64))
                                .frame(height: max(8, 76 * CGFloat(bar.xp) / CGFloat(maxBarXP)))
                            Text(bar.label)
                                .font(.lifeboard(.caption1))
                                .foregroundStyle(bar.isToday ? LBColorTokens.navy : LBColorTokens.navyMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 108, alignment: .bottom)
            }
        }
    }
}

private struct SunriseReminderResponseCard: View {
    let state: InsightsReminderResponseState

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
            Text(state.headline)
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)
            Text(state.detail)
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
            ForEach(state.statusItems) { item in
                HStack {
                    Text(item.label)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navy)
                    Spacer()
                    Text(item.valueText)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(LBColorTokens.violet)
                }
                .padding(LBSpacingTokens.sm)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LBColorTokens.glassStrong)
                )
            }
        }
    }
}

private struct SunriseNarrativeCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)
            Text(message)
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LBSpacingTokens.sm)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LBColorTokens.glassStrong)
        )
    }
}

private extension View {
    func sunriseInsightSurface(role: LBRole, cornerRadius: CGFloat) -> some View {
        modifier(SunriseInsightSurfaceModifier(role: role, cornerRadius: cornerRadius))
    }

    func secondaryInsightSurface(role: LBRole, cornerRadius: CGFloat) -> some View {
        modifier(SunriseInsightSurfaceModifier(role: role, cornerRadius: cornerRadius))
    }
}

private struct SunriseInsightSurfaceModifier: ViewModifier {
    let role: LBRole
    let cornerRadius: CGFloat

    private var style: LBRoleStyle { LBColorTokens.role(role) }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(
                        LinearGradient(
                            colors: [style.softSurface, LBColorTokens.glassStrong],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                shape.stroke(style.border.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: LBColorTokens.elevationShadow, radius: 16, x: 0, y: 9)
    }
}
