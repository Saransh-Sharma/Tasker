//
//  HomeDailySummaryModalView.swift
//  LifeBoard
//

import SwiftUI

struct DailySummaryModalView: View {
    let summary: DailySummaryModalData
    let onDismiss: () -> Void
    let onStartToday: () -> Void
    let onCompleteMorningRoutine: () -> Void
    let onStartTriage: () -> Void
    let onRescueOverdue: () -> Void
    let onAddTask: () -> Void
    let onPlanTomorrow: () -> Void
    let onReviewDone: () -> Void
    let onRescheduleOverdue: () -> Void
    let onOpenRescue: () -> Void

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        VStack(spacing: 0) {
            headerCard
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()
                .background(Color.lifeboard.strokeHairline)

            ScrollView {
                scrollableContent
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }

            Divider()
                .background(Color.lifeboard.strokeHairline)

            ctaBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(Color.lifeboard.surfacePrimary)
        }
        .background(Color.lifeboard.bgCanvas)
        .accessibilityIdentifier("home.dailySummaryModal")
    }

    @ViewBuilder
    private var scrollableContent: some View {
        switch summary {
        case .morning(let value):
            morningContent(value)
        case .nightly(let value):
            nightlyContent(value)
        }
    }

    private var headerCard: some View {
        let title: String
        let subtitle: String
        switch summary {
        case .morning(let value):
            title = "Morning Plan"
            subtitle = headerDateText(value.date)
        case .nightly(let value):
            title = "Day Retrospective"
            subtitle = headerDateText(value.date)
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.lifeboard(.title3))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        LifeBoardStatusPill(
                            text: summaryBadgeText,
                            systemImage: summaryBadgeSymbol,
                            tone: summaryBadgeTone
                        )
                    }
                    Text(summaryNarrative)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                    Text(subtitle)
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color.lifeboard.textTertiary)
                }
                Spacer(minLength: 8)
                Button("Close") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
            }
            summaryHeroMetrics
        }
        .padding(16)
        .lifeboardPremiumSurface(
            cornerRadius: 16,
            fillColor: Color.lifeboard.surfacePrimary,
            accentColor: headerAccentColor,
            level: .e2
        )
    }

    private var summaryHeroMetrics: some View {
        switch summary {
        case .morning(let value):
            return AnyView(
                HStack(spacing: 10) {
                    metricChip(
                        title: "Open",
                        value: "\(value.openTodayCount)",
                        id: "home.dailySummary.hero.openCount",
                        numericValue: value.openTodayCount
                    )
                    metricChip(
                        title: "High",
                        value: "\(value.highPriorityCount)",
                        id: "home.dailySummary.hero.highCount",
                        numericValue: value.highPriorityCount
                    )
                    metricChip(
                        title: "Overdue",
                        value: "\(value.overdueCount)",
                        id: "home.dailySummary.hero.overdueCount",
                        numericValue: value.overdueCount
                    )
                    metricChip(
                        title: "XP",
                        value: "\(value.potentialXP)",
                        id: "home.dailySummary.hero.potentialXP",
                        numericValue: value.potentialXP
                    )
                }
            )
        case .nightly(let value):
            return AnyView(
                HStack(spacing: 10) {
                    metricChip(
                        title: "Done",
                        value: "\(value.completedCount)/\(value.totalCount)",
                        id: "home.dailySummary.hero.completed",
                        detail: value.totalCount > 0 ? "\(Int((value.completionRate * 100).rounded()))% completion" : "No schedule recorded"
                    )
                    metricChip(
                        title: "XP",
                        value: "\(value.xpEarned)",
                        id: "home.dailySummary.hero.xp",
                        numericValue: value.xpEarned
                    )
                    metricChip(
                        title: "Rate",
                        value: "\(Int((value.completionRate * 100).rounded()))%",
                        id: "home.dailySummary.hero.rate",
                        numericValue: Int((value.completionRate * 100).rounded()),
                        numericSuffix: "%"
                    )
                    metricChip(
                        title: "Streak",
                        value: "\(value.streakCount)d",
                        id: "home.dailySummary.hero.streak",
                        numericValue: value.streakCount,
                        numericSuffix: "d"
                    )
                }
            )
        }
    }

    private func morningContent(_ summary: MorningPlanSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(title: "Focus Now") {
                if summary.focusTasks.isEmpty {
                    Text("No tasks queued. Capture one meaningful win.")
                        .font(.lifeboard(.body))
                        .foregroundColor(Color.lifeboard.textSecondary)
                } else {
                    ForEach(summary.focusTasks) { row in
                        taskRow(row)
                    }
                }
            }

            sectionCard(title: "Risk & Friction") {
                VStack(alignment: .leading, spacing: 8) {
                    riskLine(title: "Overdue tasks", value: summary.overdueCount)
                    riskLine(title: "Blocked tasks", value: summary.blockedCount)
                    riskLine(title: "Long tasks (60m+)", value: summary.longTaskCount)
                }
            }

            sectionCard(title: "Agenda Split") {
                HStack(spacing: 12) {
                    agendaPill(title: "Morning", value: summary.morningPlannedCount)
                    agendaPill(title: "Evening", value: summary.eveningPlannedCount)
                }
            }
        }
    }

    private func nightlyContent(_ summary: NightlyRetrospectiveSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionCard(title: "Biggest Wins") {
                if summary.biggestWins.isEmpty {
                    Text("No completions today. Pick one tiny restart for tomorrow.")
                        .font(.lifeboard(.body))
                        .foregroundColor(Color.lifeboard.textSecondary)
                } else {
                    ForEach(summary.biggestWins) { row in
                        taskRow(row)
                    }
                }
            }

            sectionCard(title: "Carry-over") {
                VStack(alignment: .leading, spacing: 8) {
                    riskLine(title: "Open due today", value: summary.carryOverDueTodayCount)
                    riskLine(title: "Still overdue", value: summary.carryOverOverdueCount)
                }
            }

            sectionCard(title: "Tomorrow Preview") {
                if summary.tomorrowPreview.isEmpty {
                    Text("No tasks due tomorrow yet.")
                        .font(.lifeboard(.body))
                        .foregroundColor(Color.lifeboard.textSecondary)
                } else {
                    ForEach(summary.tomorrowPreview) { row in
                        taskRow(row)
                    }
                }
            }

            sectionCard(title: "Reflection Insight") {
                HStack(spacing: 12) {
                    agendaPill(title: "Morning Done", value: summary.morningCompletedCount)
                    agendaPill(title: "Evening Done", value: summary.eveningCompletedCount)
                }
            }
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
            content()
        }
        .padding(14)
        .lifeboardDenseSurface(
            cornerRadius: 14,
            fillColor: Color.lifeboard.surfaceSecondary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
        )
    }

    private func taskRow(_ row: SummaryTaskRow) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(priorityColor(row.priority))
                .frame(width: 8, height: 8)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.title)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundColor(Color.lifeboard.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    priorityBadge(row.priority)
                    if row.isOverdue {
                        statusBadge(
                            text: "Overdue",
                            foreground: Color.lifeboard.statusDanger,
                            background: Color.lifeboard.statusDanger.opacity(0.14)
                        )
                    }
                    if row.isBlocked {
                        statusBadge(
                            text: "Blocked",
                            foreground: Color.lifeboard.statusWarning,
                            background: Color.lifeboard.statusWarning.opacity(0.16)
                        )
                    }
                }
                HStack(spacing: 8) {
                    if let dueLabel = dueLabel(for: row) {
                        Text(dueLabel)
                            .font(.lifeboard(.caption2))
                            .foregroundColor(row.isOverdue ? Color.lifeboard.statusDanger : Color.lifeboard.textSecondary)
                    }
                    if let estimatedDuration = row.estimatedDuration {
                        Text(durationLabel(seconds: estimatedDuration))
                            .font(.lifeboard(.caption2))
                            .foregroundColor(Color.lifeboard.textTertiary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityIdentifier("home.dailySummary.taskRow.\(row.taskID.uuidString)")
    }

    private func riskLine(title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(.lifeboard(.body))
                .foregroundColor(Color.lifeboard.textSecondary)
            Spacer()
            Text("\(value)")
                .font(.lifeboard(.bodyEmphasis))
                .foregroundColor(Color.lifeboard.textPrimary)
        }
    }

    private func agendaPill(title: String, value: Int) -> some View {
        LifeBoardHeroMetricTile(
            title: title,
            value: "\(value)",
            detail: value == 0 ? "Quiet" : "Visible progress",
            tone: value == 0 ? .neutral : .accent
        )
    }

    private func metricChip(
        title: String,
        value: String,
        id: String,
        numericValue: Int? = nil,
        numericSuffix: String = "",
        detail: String? = nil
    ) -> some View {
        return LifeBoardHeroMetricTile(
            title: title,
            value: numericValue != nil ? "\(numericValue ?? 0)\(numericSuffix)" : value,
            detail: detail,
            tone: title == "Overdue" ? .warning : (title == "XP" ? .accent : .neutral),
            accessibilityIdentifier: id
        )
    }

    private var ctaBar: some View {
        let primaryCTAIdentifier = LifeBoardCTABezelResolver.dailySummaryPrimaryCTAIdentifier(for: summary)

        return VStack(alignment: .leading, spacing: 10) {
            switch summary {
            case .morning(let value):
                Button("Start Today") { onStartToday() }
                    .buttonStyle(.borderedProminent)
                    .lifeboardCTABezel(
                        style: .summaryPrimary,
                        idleMotion: .slowLoop,
                        isEnabled: primaryCTAIdentifier == "home.dailySummary.cta.startToday"
                    )
                    .lifeboardSuccessPulse(isActive: primaryCTAIdentifier == "home.dailySummary.cta.startToday")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.startToday")

                HStack(spacing: 10) {
                    Button("Complete Morning Routine") { onCompleteMorningRoutine() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.completeMorning")
                    Button("Start Triage") { onStartTriage() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.startTriage")
                }

                if value.overdueCount > 0 {
                    Button("Rescue Overdue") { onRescueOverdue() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.rescueOverdue")
                }

                Button("Add Task") { onAddTask() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.addTask")

            case .nightly(let value):
                Button("Plan Tomorrow") { onPlanTomorrow() }
                    .buttonStyle(.borderedProminent)
                    .lifeboardCTABezel(
                        style: .summaryPrimary,
                        idleMotion: .slowLoop,
                        isEnabled: primaryCTAIdentifier == "home.dailySummary.cta.planTomorrow"
                    )
                    .lifeboardSuccessPulse(isActive: primaryCTAIdentifier == "home.dailySummary.cta.planTomorrow")
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.planTomorrow")

                Button("Review Done") { onReviewDone() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("home.dailySummary.cta.reviewDone")

                if value.carryOverOverdueCount > 0 {
                    Button("Reschedule Overdue") { onRescheduleOverdue() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.rescheduleOverdue")
                }

                if value.carryOverOverdueCount > 0 {
                    Button("Open Rescue") { onOpenRescue() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("home.dailySummary.cta.openRescue")
                }
            }
        }
    }

    private var summaryBadgeText: String {
        switch summary {
        case .morning:
            return "Plan"
        case .nightly:
            return "Reflect"
        }
    }

    private var summaryBadgeSymbol: String {
        switch summary {
        case .morning:
            return "sun.max.fill"
        case .nightly:
            return "moon.stars.fill"
        }
    }

    private var summaryBadgeTone: LifeBoardStatusPillTone {
        switch summary {
        case .morning:
            return .accent
        case .nightly:
            return .success
        }
    }

    private var summaryNarrative: String {
        switch summary {
        case .morning(let value):
            return value.openTodayCount == 0
                ? "You can start with one meaningful win."
                : "Shape the day before the backlog sets the agenda."
        case .nightly(let value):
            return value.completedCount == 0
                ? "Close the loop with a realistic reset for tomorrow."
                : "Notice what moved today before deciding what rolls forward."
        }
    }

    private var headerAccentColor: Color {
        switch summary {
        case .morning:
            return Color.lifeboard.accentSecondary
        case .nightly:
            return Color.lifeboard.statusSuccess
        }
    }

    private func dueLabel(for row: SummaryTaskRow) -> String? {
        guard let dueDate = row.dueDate else { return nil }
        return relativeFormatter.localizedString(for: dueDate, relativeTo: Date())
    }

    private func durationLabel(seconds: TimeInterval) -> String {
        let minutes = Int(round(seconds / 60))
        if minutes >= 60 {
            if minutes % 60 == 0 {
                return "\(minutes / 60)h"
            }
            return String(format: "%.1fh", Double(minutes) / 60.0)
        }
        return "\(minutes)m"
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        if priority == .max {
            return Color.lifeboard.statusDanger
        }
        if priority == .high {
            return Color.lifeboard.statusWarning
        }
        if priority == .low {
            return Color.lifeboard.accentPrimary
        }
        return Color.lifeboard.textTertiary
    }

    private func priorityBadge(_ priority: TaskPriority) -> some View {
        statusBadge(
            text: priority.displayName,
            foreground: priorityColor(priority),
            background: priorityColor(priority).opacity(0.14)
        )
    }

    private func statusBadge(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.lifeboard(.caption2))
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(background)
            )
    }

    private func headerDateText(_ date: Date) -> String {
        headerDateFormatter.string(from: date)
    }
}
