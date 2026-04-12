import SwiftUI

enum WeeklyCopy {
    static let plannerTitle = "Plan this week"
    static let plannerSubtitle = "Set direction, choose a few real outcomes, and place work where it belongs."
    static let reviewTitle = "Review this week"
    static let reviewSubtitle = "Look at what happened, resolve unfinished work, and capture what future-you should remember."
    static let reflectionTitle = "Add reflection"

    static let plannerErrorTitle = "We couldn't load this week"
    static let reviewErrorTitle = "We couldn't load this review"
    static let reflectionErrorTitle = "We couldn't save that reflection"

    static let plannerSaveSuccess = "Plan saved"
    static let reviewSaveSuccess = "Review saved"
    static let reflectionSaveSuccess = "Reflection added"
    static let evaApplySuccess = "AI suggestion added to your plan"

    static let planningPlacementLabel = "When should you do this?"
    static let weeklyOutcomeLabel = "Weekly outcome"
    static let intentionalWeekLabel = "Keep this week intentionally light"
    static let getAISuggestion = "Get AI suggestion"
    static let addReflection = "Add reflection"
    static let savePlan = "Save plan"
    static let finishReview = "Finish review"

    static let noHabits = "No active habits are available right now. You can still plan the week without them."
    static let noTasksInLane = "Nothing is placed here yet."
    static let noOutcomes = "No weekly outcomes are saved yet."
    static let noCompletedWork = "Nothing from This Week is marked done yet."
    static let noUnfinishedWork = "Everything in This Week is already resolved."
    static let noWeeklyNotes = "Add a short reflection so this review is easier to trust later."
    static let noProjectTasks = "Tasks in this project will show up here when they can be moved into the weekly flow."

    static let thisWeek = "This Week"
    static let nextWeek = "Next Week"
    static let later = "Later"

    static let keepInThisWeek = "Keep in This Week"
    static let moveToNextWeek = "Move to Next Week"
    static let moveToLater = "Move to Later"
    static let removeFromThisWeek = "Remove from This Week"

    static let plannerSteps = [
        "Set direction",
        "Choose weekly outcomes",
        "Place work",
        "Review plan"
    ]

    static let reviewSteps = [
        "See how the week went",
        "Update outcomes",
        "Resolve unfinished work",
        "Capture what to carry forward"
    ]

    static func weekRangeText(for weekStartDate: Date) -> String {
        let calendar = XPCalculationEngine.mondayCalendar()
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        formatter.dateTemplate = "MMM d"
        return formatter.string(from: weekStartDate, to: weekEnd)
    }

    static func capacityHelper(target: Int, estimate: Int) -> String {
        if target < estimate {
            return "You are planning lighter than your usual pace. Good for a constrained week."
        } else if target > estimate {
            return "This is above your recent pace. Keep only work you would still choose midweek."
        } else {
            return "This matches your recent pace. Keep This Week focused enough to stay believable."
        }
    }

    static func overloadHelper(count: Int) -> String {
        count == 1
            ? "One task is still stretching this week past the pace you set."
            : "\(count) tasks are still stretching this week past the pace you set."
    }

    static func cleanupHelper(for disposition: WeeklyReviewTaskDisposition) -> String {
        switch disposition {
        case .carry:
            return "Keep it active in This Week if it still deserves immediate attention."
        case .later:
            return "Move it out of the active week without losing it."
        case .drop:
            return "Use this when the work should stop creating pressure."
        }
    }
}

struct WeeklyRitualStep: Identifiable {
    let id: Int
    let title: String
    let isComplete: Bool
}

struct WeeklyRitualScaffold<Content: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let weekRange: String
    let steps: [WeeklyRitualStep]
    let message: String?
    let messageTone: TaskerStatusPillTone
    let content: Content
    let footer: Footer

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        weekRange: String,
        steps: [WeeklyRitualStep],
        message: String?,
        messageTone: TaskerStatusPillTone,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.weekRange = weekRange
        self.steps = steps
        self.message = message
        self.messageTone = messageTone
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                WeeklyRitualHero(
                    eyebrow: eyebrow,
                    title: title,
                    subtitle: subtitle,
                    weekRange: weekRange,
                    steps: steps
                )

                if let message, message.isEmpty == false {
                    WeeklyInlineMessage(text: message, tone: messageTone)
                }

                content
            }
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.top, spacing.s20)
            .padding(.bottom, spacing.s40)
            .taskerReadableContent()
        }
        .scrollIndicators(.hidden)
        .background(Color.tasker.bgCanvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s12)
                .background(Color.tasker.bgCanvas.opacity(0.96))
        }
    }
}

private struct WeeklyRitualHero: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let weekRange: String
    let steps: [WeeklyRitualStep]

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(eyebrow.uppercased())
                    .font(.tasker(.eyebrow))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .tracking(0.8)

                Text(title)
                    .font(.tasker(.screenTitle))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.tasker(.body))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                TaskerStatusPill(
                    text: weekRange,
                    systemImage: "calendar",
                    tone: .quiet
                )
            }

            WeeklyProgressRow(steps: steps)
        }
        .padding(spacing.cardPadding)
        .taskerPremiumSurface(
            cornerRadius: 28,
            fillColor: Color.tasker.surfacePrimary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.82),
            accentColor: Color.tasker.accentSecondary,
            level: .e2
        )
    }
}

private struct WeeklyProgressRow: View {
    let steps: [WeeklyRitualStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(steps) { step in
                    Circle()
                        .fill(step.isComplete ? Color.tasker.accentPrimary : Color.tasker.surfaceTertiary)
                        .frame(width: 8, height: 8)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(step.isComplete ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                        Text(step.title)
                            .font(.tasker(.caption1))
                            .foregroundStyle(step.isComplete ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

struct WeeklySectionCard<Content: View>: View {
    let title: String
    let detail: String?
    let accent: Color
    let content: Content

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    init(
        title: String,
        detail: String? = nil,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.accent = accent ?? Color.tasker.accentSecondary
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(title)
                    .font(.tasker(.title2))
                    .foregroundStyle(Color.tasker.textPrimary)
                if let detail, detail.isEmpty == false {
                    Text(detail)
                        .font(.tasker(.support))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(spacing.cardPadding)
        .taskerPremiumSurface(
            cornerRadius: 24,
            fillColor: Color.tasker.surfacePrimary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.78),
            accentColor: accent,
            level: .e2
        )
    }
}

struct WeeklyInlineMessage: View {
    let text: String
    let tone: TaskerStatusPillTone

    var body: some View {
        let symbolName: String = {
            switch tone {
            case .warning:
                return "exclamationmark.triangle.fill"
            default:
                return "checkmark.circle.fill"
            }
        }()

        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(tone.textColor)
            Text(text)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.fillColor)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tone.strokeColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct WeeklyStickyActionBar<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing.s12) {
            leading
            Spacer(minLength: spacing.s12)
            trailing
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s12)
        .taskerPremiumSurface(
            cornerRadius: 22,
            fillColor: Color.tasker.surfacePrimary.opacity(0.98),
            strokeColor: Color.tasker.strokeHairline.opacity(0.82),
            accentColor: Color.tasker.accentSecondary,
            level: .e2
        )
    }
}

struct WeeklyCapacityCard: View {
    @Binding var targetCapacity: Int
    let estimatedCapacity: Int
    let overloadCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planned pace")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                    Text("\(targetCapacity)")
                        .font(.tasker(.metric))
                        .foregroundStyle(Color.tasker.textPrimary)
                    Text("tasks you still want to own this week")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                Spacer()

                HStack(spacing: 10) {
                    Button {
                        targetCapacity = max(1, targetCapacity - 1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .taskerDenseSurface(cornerRadius: 14, fillColor: Color.tasker.surfaceSecondary)

                    Button {
                        targetCapacity = min(30, targetCapacity + 1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .taskerDenseSurface(cornerRadius: 14, fillColor: Color.tasker.surfaceSecondary)
                }
            }

            Text(WeeklyCopy.capacityHelper(target: targetCapacity, estimate: estimatedCapacity))
                .font(.tasker(.support))
                .foregroundStyle(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                TaskerStatusPill(text: "Suggested pace \(estimatedCapacity)", systemImage: "figure.walk", tone: .quiet)
                if overloadCount > 0 {
                    TaskerStatusPill(text: "\(overloadCount) over pace", systemImage: "exclamationmark.triangle.fill", tone: .warning)
                }
            }
        }
    }
}

struct WeeklyTaskLaneView: View {
    let title: String
    let detail: String
    let bucket: TaskPlanningBucket
    let tasks: [TaskDefinition]
    let outcomeTitlesByID: [UUID: String]
    let emptyText: String
    let onMove: (UUID, TaskPlanningBucket) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)
                Text(detail)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if tasks.isEmpty {
                Text(emptyText)
                    .font(.tasker(.support))
                    .foregroundStyle(Color.tasker.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(tasks, id: \.id) { task in
                        WeeklyTaskPlannerRow(
                            task: task,
                            sourceBucket: bucket,
                            outcomeTitle: task.weeklyOutcomeID.flatMap { outcomeTitlesByID[$0] },
                            onMove: onMove
                        )
                    }
                }
            }
        }
    }
}

private struct WeeklyTaskPlannerRow: View {
    let task: TaskDefinition
    let sourceBucket: TaskPlanningBucket
    let outcomeTitle: String?
    let onMove: (UUID, TaskPlanningBucket) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if let dueDate = task.dueDate {
                            TaskerStatusPill(
                                text: dueDate.formatted(date: .abbreviated, time: .omitted),
                                systemImage: "calendar",
                                tone: .quiet
                            )
                        }

                        if let outcomeTitle, outcomeTitle.isEmpty == false {
                            TaskerStatusPill(
                                text: outcomeTitle,
                                systemImage: "scope",
                                tone: .accent
                            )
                        }
                    }
                }

                Spacer()

                Menu {
                    ForEach(plannerMoves, id: \.self) { move in
                        Button(move.copyLabel) {
                            onMove(task.id, move)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.tasker.textSecondary)
                }
                .accessibilityLabel("Move \(task.title)")
            }
        }
        .padding(14)
        .taskerDenseSurface(cornerRadius: 18, fillColor: Color.tasker.surfaceSecondary.opacity(0.84))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            ForEach(trailingMoves, id: \.self) { move in
                Button(move.copyLabel) {
                    onMove(task.id, move)
                }
                .tint(move.tintColor)
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            ForEach(leadingMoves, id: \.self) { move in
                Button(move.copyLabel) {
                    onMove(task.id, move)
                }
                .tint(move.tintColor)
            }
        }
        .accessibilityAction(named: Text(WeeklyCopy.keepInThisWeek)) {
            onMove(task.id, .thisWeek)
        }
        .accessibilityAction(named: Text(WeeklyCopy.moveToNextWeek)) {
            onMove(task.id, .nextWeek)
        }
        .accessibilityAction(named: Text(WeeklyCopy.moveToLater)) {
            onMove(task.id, .later)
        }
    }

    private var plannerMoves: [TaskPlanningBucket] {
        [.thisWeek, .nextWeek, .later].filter { $0 != sourceBucket }
    }

    private var leadingMoves: [TaskPlanningBucket] {
        switch sourceBucket {
        case .thisWeek:
            return []
        case .nextWeek:
            return [.thisWeek]
        case .later:
            return [.thisWeek, .nextWeek]
        default:
            return []
        }
    }

    private var trailingMoves: [TaskPlanningBucket] {
        switch sourceBucket {
        case .thisWeek:
            return [.nextWeek, .later]
        case .nextWeek:
            return [.later]
        case .later:
            return []
        default:
            return []
        }
    }
}

struct WeeklyPlanningPlacementSection: View {
    @Binding var selectedPlanningBucket: TaskPlanningBucket
    @Binding var selectedWeeklyOutcomeID: UUID?
    let availableWeeklyOutcomes: [WeeklyOutcome]
    var labelStyle: Font = .tasker(.caption1)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AddTaskEnumChipRow(
                label: WeeklyCopy.planningPlacementLabel,
                displayName: { $0.displayName },
                icon: { $0.systemImageName },
                selected: $selectedPlanningBucket
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(WeeklyCopy.weeklyOutcomeLabel)
                    .font(labelStyle)
                    .foregroundStyle(Color.tasker.textSecondary)

                Menu {
                    Button("None") {
                        selectedWeeklyOutcomeID = nil
                    }
                    ForEach(availableWeeklyOutcomes, id: \.id) { outcome in
                        Button(outcome.title) {
                            selectedWeeklyOutcomeID = outcome.id
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "scope")
                            .foregroundStyle(Color.tasker.accentPrimary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedOutcomeTitle)
                                .font(.tasker(.callout))
                                .foregroundStyle(Color.tasker.textPrimary)
                            Text("Choose the outcome this work supports. Outcome links stay active only in This Week.")
                                .font(.tasker(.caption2))
                                .foregroundStyle(Color.tasker.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.tasker.textTertiary)
                    }
                    .padding(12)
                    .taskerDenseSurface(cornerRadius: 16, fillColor: Color.tasker.surfaceSecondary)
                }
                .buttonStyle(.plain)
                .disabled(availableWeeklyOutcomes.isEmpty)
            }
        }
    }

    private var selectedOutcomeTitle: String {
        guard let selectedWeeklyOutcomeID else {
            return availableWeeklyOutcomes.isEmpty ? "No weekly outcomes yet" : "No weekly outcome"
        }
        return availableWeeklyOutcomes.first(where: { $0.id == selectedWeeklyOutcomeID })?.title ?? "No weekly outcome"
    }
}

struct WeeklyDecisionRow: View {
    let task: TaskDefinition
    let selectedDisposition: WeeklyReviewTaskDisposition
    let onSelect: (WeeklyReviewTaskDisposition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(task.title)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(WeeklyReviewTaskDisposition.allCases, id: \.self) { disposition in
                    Button {
                        onSelect(disposition)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(disposition.displayTitle)
                                .font(.tasker(.caption1).weight(.semibold))
                            Text(WeeklyCopy.cleanupHelper(for: disposition))
                                .font(.tasker(.caption2))
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .foregroundStyle(selectedDisposition == disposition ? disposition.tintColor : Color.tasker.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedDisposition == disposition ? disposition.tintColor.opacity(0.12) : Color.tasker.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selectedDisposition == disposition ? disposition.tintColor.opacity(0.22) : Color.tasker.strokeHairline.opacity(0.82), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .taskerDenseSurface(cornerRadius: 18, fillColor: Color.tasker.surfacePrimary)
    }
}

@MainActor
private extension TaskPlanningBucket {
    var copyLabel: String {
        switch self {
        case .thisWeek:
            return WeeklyCopy.keepInThisWeek
        case .nextWeek:
            return WeeklyCopy.moveToNextWeek
        case .later:
            return WeeklyCopy.moveToLater
        case .today:
            return "Move to Today"
        case .someday:
            return "Move to Someday"
        }
    }

    var tintColor: Color {
        switch self {
        case .today:
            return Color.tasker.statusSuccess
        case .thisWeek:
            return Color.tasker.accentPrimary
        case .nextWeek:
            return Color.tasker.accentSecondary
        case .later, .someday:
            return Color.tasker.textSecondary
        }
    }
}

@MainActor
extension WeeklyReviewTaskDisposition {
    var displayTitle: String {
        switch self {
        case .carry:
            return "Carry"
        case .later:
            return "Move later"
        case .drop:
            return "Drop"
        }
    }

    var tintColor: Color {
        switch self {
        case .carry:
            return Color.tasker.accentPrimary
        case .later:
            return Color.tasker.accentSecondary
        case .drop:
            return Color.tasker.statusWarning
        }
    }
}

@MainActor
extension WeeklyOutcomeStatus {
    var displayTitle: String {
        switch self {
        case .planned:
            return "Planned"
        case .inProgress:
            return "In progress"
        case .completed:
            return "Completed"
        case .dropped:
            return "Dropped"
        }
    }

    var tintColor: Color {
        switch self {
        case .planned:
            return Color.tasker.textSecondary
        case .inProgress:
            return Color.tasker.accentPrimary
        case .completed:
            return Color.tasker.statusSuccess
        case .dropped:
            return Color.tasker.statusWarning
        }
    }
}
