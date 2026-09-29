import SwiftUI

enum WeeklyCopy {
    static let plannerSubtitle = String(localized: "Pick goals and place tasks.")
    static let reviewTitle = String(localized: "Review week")
    static let reviewSubtitle = String(localized: "See what got done and sort what’s left.")
    static let reflectionTitle = String(localized: "Add note")

    static let reviewErrorTitle = String(localized: "Couldn’t load review.")
    static let reflectionErrorTitle = String(localized: "Couldn’t save note.")

    static let plannerSaveSuccess = String(localized: "Plan saved")
    static let reviewSaveSuccess = String(localized: "Review saved")
    static let reflectionSaveSuccess = String(localized: "Note added")
    static let evaApplySuccess = String(localized: "Suggestion added to plan")

    static let planningPlacementLabel = String(localized: "When")
    static let weeklyOutcomeLabel = String(localized: "Weekly goal")
    static let intentionalWeekLabel = String(localized: "Light week")
    static let getAISuggestion = String(localized: "Get suggestion")
    static let addReflection = String(localized: "Add note")
    static let savePlan = String(localized: "Save plan")
    static let finishReview = String(localized: "Finish review")
    static let back = String(localized: "Back")
    static let edit = String(localized: "Edit")
    static let editHabits = String(localized: "Edit habits")
    static let continueToOutcomes = String(localized: "Continue to goals")
    static let continueToTasks = String(localized: "Continue to tasks")
    static let reviewPlan = String(localized: "Review plan")
    static let chooseTasks = String(localized: "Choose tasks")
    static let findMoreTasks = String(localized: "Find more tasks")
    static let addTaskToReview = String(localized: "Add to review")
    static let addedToReview = String(localized: "Added")
    static let attachOutcomeQuestion = String(localized: "Link to a goal?")
    static let noOutcome = String(localized: "No goal")
    static let tasksCompleteTitle = String(localized: "All tasks placed")
    /// Empty on purpose: the finished state needs no subtitle.
    static let tasksCompleteSubtitle = ""
    static let includedThisWeek = String(localized: "Habits")
    static let weeklyCandidates = String(localized: "Weekly candidates")
    static let suggestedTasks = String(localized: "Suggested")
    static let allOpenTasks = String(localized: "All open")
    static let directionPrompt = String(localized: "Focus this week")
    static let outcomesPrompt = String(localized: "Pick up to 3 goals")
    static let tasksPrompt = String(localized: "Place each task")
    static let reviewPrompt = String(localized: "Check the plan")
    static let reviewDirectionFallback = String(localized: "No focus set")
    static let noTasksQueuedForReview = String(localized: "All sorted")
    static let noTasksInPlan = String(localized: "No tasks")
    static let reviewDirectionTitle = String(localized: "Focus")
    static let reviewHabitsTitle = String(localized: "Habits")
    static let reviewPlacedWorkTitle = String(localized: "Planned tasks")
    static let currentlyPlacedIn = String(localized: "Currently in")

    static let noHabits = String(localized: "No active habits")
    static let noTasksInLane = String(localized: "No tasks")
    static let noOutcomes = String(localized: "No goals yet")
    static let noCompletedWork = String(localized: "Nothing done yet")
    static let noUnfinishedWork = String(localized: "Nothing left")
    static let noWeeklyNotes = String(localized: "No notes yet")
    static let noProjectTasks = String(localized: "No open tasks")

    static let thisWeek = String(localized: "This week")
    static let nextWeek = String(localized: "Next week")
    static let later = String(localized: "Later")

    static let keepInThisWeek = String(localized: "Keep this week")
    static let moveToNextWeek = String(localized: "Move to next week")
    static let moveToLater = String(localized: "Move to Later")
    static let removeFromThisWeek = String(localized: "Remove from week")

    static let plannerSteps = [
        String(localized: "Set focus"),
        String(localized: "Choose goals"),
        String(localized: "Place tasks"),
        String(localized: "Review plan")
    ]

    static let reviewSteps = [
        String(localized: "Look back"),
        String(localized: "Update goals"),
        String(localized: "Sort what’s left"),
        String(localized: "Add notes")
    ]
}

extension WeeklyCopy {
    static func plannerTitle(for presentation: WeeklyPlannerPresentationMode) -> String {
        switch presentation {
        case .thisWeek:
            return String(localized: "Plan this week")
        case .upcomingWeek:
            return String(localized: "Plan next week")
        }
    }

    static func plannerErrorTitle(for presentation: WeeklyPlannerPresentationMode) -> String {
        switch presentation {
        case .thisWeek:
            return String(localized: "Couldn’t load this week.")
        case .upcomingWeek:
            return String(localized: "Couldn’t load next week.")
        }
    }

    static func prompt(for step: WeeklyPlannerStep, presentation: WeeklyPlannerPresentationMode) -> String {
        switch (step, presentation) {
        case (.direction, .thisWeek):
            return directionPrompt
        case (.direction, .upcomingWeek):
            return String(localized: "Focus next week")
        case (.outcomes, .thisWeek):
            return outcomesPrompt
        case (.outcomes, .upcomingWeek):
            return String(localized: "Pick up to 3 goals for next week")
        case (.tasks, .thisWeek):
            return tasksPrompt
        case (.tasks, .upcomingWeek):
            return String(localized: "Place each task for next week")
        case (.review, .thisWeek):
            return reviewPrompt
        case (.review, .upcomingWeek):
            return String(localized: "Check next week’s plan")
        }
    }

    static func weekRangeText(for weekStartDate: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? weekStartDate
        let formatter = DateIntervalFormatter()
        formatter.calendar = calendar
        formatter.locale = .autoupdatingCurrent
        formatter.dateTemplate = "MMM d"
        return formatter.string(from: weekStartDate, to: weekEnd)
    }

    static func capacityHelper(target: Int, estimate: Int) -> String {
        if target < estimate {
            return String(localized: "Lighter than your usual week.")
        } else if target > estimate {
            return String(localized: "More than your usual week.")
        } else {
            return String(localized: "About your usual week.")
        }
    }

    static func overloadHelper(count: Int) -> String {
        count == 1
            ? String(localized: "1 task over your pace")
            : String(localized: "\(count) tasks over your pace")
    }

    static func cleanupHelper(for disposition: WeeklyReviewTaskDisposition) -> String {
        switch disposition {
        case .carry:
            return String(localized: "Stays this week")
        case .later:
            return String(localized: "Moves to Later")
        case .drop:
            return String(localized: "Moves to Someday")
        }
    }
}

struct WeeklyWizardScaffold<Content: View, Footer: View>: View {
    let weekRange: String
    let currentStep: WeeklyPlannerStep
    let currentPrompt: String
    let showsBack: Bool
    let onBack: (() -> Void)?
    let content: Content
    let footer: Footer

    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    init(
        weekRange: String,
        currentStep: WeeklyPlannerStep,
        currentPrompt: String,
        showsBack: Bool,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.weekRange = weekRange
        self.currentStep = currentStep
        self.currentPrompt = currentPrompt
        self.showsBack = showsBack
        self.onBack = onBack
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing.s20) {
                WeeklyWizardHeader(
                    weekRange: weekRange,
                    currentStep: currentStep,
                    currentPrompt: currentPrompt,
                    showsBack: showsBack,
                    onBack: onBack
                )

                content
            }
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s40)
            .lifeboardReadableContent()
        }
        .scrollIndicators(.hidden)
        .background(Color.lifeboard.bgCanvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s8)
                .background(Color.lifeboard.bgCanvas.opacity(0.96))
        }
    }
}

private struct WeeklyWizardHeader: View {
    let weekRange: String
    let currentStep: WeeklyPlannerStep
    let currentPrompt: String
    let showsBack: Bool
    let onBack: (() -> Void)?

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .center, spacing: spacing.s12) {
                if showsBack, let onBack {
                    Button(action: onBack) {
                        Label(WeeklyCopy.back, systemImage: "chevron.left")
                            .font(.lifeboard(.buttonSmall))
                    }
                    .buttonStyle(.lifeBoardChip)
                }

                Spacer()

                StatusPill(
                    text: weekRange,
                    systemImage: "calendar",
                    tone: .quiet
                )
            }

            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(currentStep.stepLabel)
                    .font(.lifeboard(.eyebrow))
                    .tracking(0.8)
                    .foregroundStyle(Color.lifeboard.textSecondary)

                Text(currentStep.title)
                    .font(.lifeboard(.title1))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                Text(currentPrompt)
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: spacing.s8) {
                ForEach(WeeklyPlannerStep.allCases) { step in
                    Capsule(style: .continuous)
                        .fill(step.rawValue <= currentStep.rawValue ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                }
            }
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
    let messageTone: StatusPillTone
    /// Painted behind the ritual's hero. Root headers sit on the moving
    /// atmosphere, where a scene reads as noise; a pushed ritual sits on the
    /// calm canvas, which is where this artwork can actually be seen.
    let headerScene: FeatureHeaderScene?
    let content: Content
    let footer: Footer

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        weekRange: String,
        steps: [WeeklyRitualStep],
        message: String?,
        messageTone: StatusPillTone,
        headerScene: FeatureHeaderScene? = nil,
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
        self.headerScene = headerScene
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
                    steps: steps,
                    scene: headerScene
                )

                if let message, message.isEmpty == false {
                    WeeklyInlineMessage(text: message, tone: messageTone)
                }

                content
            }
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.top, spacing.s20)
            .padding(.bottom, spacing.s40)
            .lifeboardReadableContent()
        }
        .scrollIndicators(.hidden)
        .background(Color.lifeboard.bgCanvas.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s12)
                .background(Color.lifeboard.bgCanvas.opacity(0.96))
        }
    }
}

private struct WeeklyRitualHero: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let weekRange: String
    let steps: [WeeklyRitualStep]
    var scene: FeatureHeaderScene?

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(eyebrow)
                    .font(.lifeboard(.eyebrow))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .tracking(0.8)

                Text(title)
                    .font(.lifeboard(.screenTitle))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.lifeboard(.body))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                StatusPill(
                    text: weekRange,
                    systemImage: "calendar",
                    tone: .quiet
                )
            }

            WeeklyProgressRow(steps: steps)
        }
        .padding(spacing.cardPadding)
        // 24 is the hero radius `DESIGN.md` calls "the continuity"; 28 belongs
        // to sheets and modal presentations.
        .featureHeaderArtwork(scene ?? .plan, enabled: scene != nil, cornerRadius: Radius.hero)
        .lifeboardPremiumSurface(
            cornerRadius: Radius.hero,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.82),
            accentColor: Color.lifeboard.accentSecondary,
            level: .e2
        )
    }
}

private struct WeeklyProgressRow: View {
    let steps: [WeeklyRitualStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(steps) { step in
                    Circle()
                        .fill(step.isComplete ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceTertiary)
                        .frame(width: 8, height: 8)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: step.isComplete ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(step.isComplete ? Color.lifeboard.accentPrimary : Color.lifeboard.textTertiary)
                        Text(step.title)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(step.isComplete ? Color.lifeboard.textPrimary : Color.lifeboard.textSecondary)
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

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

    init(
        title: String,
        detail: String? = nil,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.accent = accent ?? Color.lifeboard.accentSecondary
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(title)
                    .font(.lifeboard(.title2))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                if let detail, detail.isEmpty == false {
                    Text(detail)
                        .font(.lifeboard(.support))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(spacing.cardPadding)
        .lifeboardPremiumSurface(
            cornerRadius: 24,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.78),
            accentColor: accent,
            level: .e2
        )
    }
}

struct WeeklyInlineMessage: View {
    let text: String
    let tone: StatusPillTone

    var body: some View {
        let symbolName: String = {
            switch tone {
            case .warning:
                return "exclamationmark.triangle.fill"
            default:
                return "checkmark.circle.fill"
            }
        }()

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(tone.textColor)
            Text(text)
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textPrimary)
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

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.lifeboardTokens) private var tokens

    private var spacing: SemanticSpacingTokens { tokens.spacing }

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
        .padding(.vertical, spacing.s8)
        .lifeboardPremiumSurface(
            cornerRadius: Radius.card,
            fillColor: Color.lifeboard.surfacePrimary.opacity(0.98),
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.82),
            accentColor: Color.lifeboard.accentSecondary,
            level: .e2
        )
    }
}

struct WeeklyCapacityCard: View {
    @Binding var targetCapacity: Int
    let estimatedCapacity: Int
    let overloadCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Planned")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(targetCapacity)")
                            .font(.lifeboard(.title1))
                            .foregroundStyle(Color.lifeboard.textPrimary)
                        Text("tasks")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        targetCapacity = max(1, targetCapacity - 1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .lifeboardDenseSurface(cornerRadius: Radius.field, fillColor: Color.lifeboard.surfaceSecondary)
                    .accessibilityLabel("Decrease pace")

                    Button {
                        targetCapacity = min(30, targetCapacity + 1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .lifeboardDenseSurface(cornerRadius: Radius.field, fillColor: Color.lifeboard.surfaceSecondary)
                    .accessibilityLabel("Increase pace")
                }
            }

            Text(WeeklyCopy.capacityHelper(target: targetCapacity, estimate: estimatedCapacity))
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                StatusPill(text: "Suggested \(estimatedCapacity)", systemImage: "figure.walk", tone: .quiet)
                if overloadCount > 0 {
                    StatusPill(text: "\(overloadCount) over pace", systemImage: "exclamationmark.triangle.fill", tone: .warning)
                }
            }
        }
    }
}

@MainActor
extension TaskPlanningBucket {
    var conciseDisplayTitle: String {
        switch self {
        case .today:
            return String(localized: "Today")
        case .thisWeek:
            return WeeklyCopy.thisWeek
        case .nextWeek:
            return WeeklyCopy.nextWeek
        case .later:
            return WeeklyCopy.later
        case .someday:
            return String(localized: "Someday")
        }
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
            return String(localized: "Move to Today")
        case .someday:
            return String(localized: "Move to Someday")
        }
    }

    var tintColor: Color {
        switch self {
        case .today:
            return Color.lifeboard.statusSuccess
        case .thisWeek:
            return Color.lifeboard.accentPrimary
        case .nextWeek:
            return Color.lifeboard.accentSecondary
        case .later, .someday:
            return Color.lifeboard.textSecondary
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
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text(detail)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if tasks.isEmpty {
                Text(emptyText)
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            } else {
                VStack(spacing: 12) {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if let dueDate = task.dueDate {
                            StatusPill(
                                text: dueDate.formatted(date: .abbreviated, time: .omitted),
                                systemImage: "calendar",
                                tone: .quiet
                            )
                        }

                        if let outcomeTitle, outcomeTitle.isEmpty == false {
                            StatusPill(
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
                        .lifeboardFont(.title2)
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .minimumHitTarget()
                }
                .accessibilityLabel("Move \(task.title)")
            }
        }
        .padding(14)
        .lifeboardDenseSurface(cornerRadius: Radius.card, fillColor: Color.lifeboard.surfaceSecondary.opacity(0.84))
        // The same moves on a right-click or long-press anywhere on the row.
        .contextMenu {
            ForEach(plannerMoves, id: \.self) { move in
                Button(move.copyLabel) { onMove(task.id, move) }
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
}

struct WeeklyPlanningPlacementSection: View {
    @Binding var selectedPlanningBucket: TaskPlanningBucket
    @Binding var selectedWeeklyOutcomeID: UUID?
    let availableWeeklyOutcomes: [WeeklyOutcome]
    var labelStyle: Font = .lifeboard(.caption1)

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
                    .foregroundStyle(Color.lifeboard.textSecondary)

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
                            .foregroundStyle(Color.lifeboard.accentPrimary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedOutcomeTitle)
                                .font(.lifeboard(.callout))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                        }

                        Spacer()

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textTertiary)
                    }
                    .padding(12)
                    .lifeboardDenseSurface(cornerRadius: 16, fillColor: Color.lifeboard.surfaceSecondary)
                }
                .buttonStyle(.plain)
                .disabled(availableWeeklyOutcomes.isEmpty)
            }
        }
    }

    private var selectedOutcomeTitle: String {
        guard let selectedWeeklyOutcomeID else {
            return availableWeeklyOutcomes.isEmpty ? String(localized: "No goals yet") : WeeklyCopy.noOutcome
        }
        return availableWeeklyOutcomes.first(where: { $0.id == selectedWeeklyOutcomeID })?.title ?? WeeklyCopy.noOutcome
    }
}

struct WeeklyDecisionRow: View {
    let task: TaskDefinition
    let selectedDisposition: WeeklyReviewTaskDisposition
    let onSelect: (WeeklyReviewTaskDisposition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(task.title)
                .font(.lifeboard(.bodyEmphasis))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(WeeklyReviewTaskDisposition.allCases, id: \.self) { disposition in
                    Button {
                        onSelect(disposition)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(disposition.displayTitle)
                                .font(.lifeboard(.caption1).weight(.semibold))
                            Text(WeeklyCopy.cleanupHelper(for: disposition))
                                .font(.lifeboard(.caption2))
                                .multilineTextAlignment(.leading)
                                .lineLimit(3)
                        }
                        .foregroundStyle(selectedDisposition == disposition ? disposition.tintColor : Color.lifeboard.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(selectedDisposition == disposition ? disposition.tintColor.opacity(0.12) : Color.lifeboard.surfaceSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(selectedDisposition == disposition ? disposition.tintColor.opacity(0.22) : Color.lifeboard.strokeHairline.opacity(0.82), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .lifeboardDenseSurface(cornerRadius: Radius.card, fillColor: Color.lifeboard.surfacePrimary)
    }
}

@MainActor
extension WeeklyReviewTaskDisposition {
    var displayTitle: String {
        switch self {
        case .carry:
            return String(localized: "Keep")
        case .later:
            return String(localized: "Later")
        case .drop:
            return String(localized: "Someday")
        }
    }

    var tintColor: Color {
        switch self {
        case .carry:
            return Color.lifeboard.accentPrimary
        case .later:
            return Color.lifeboard.accentSecondary
        case .drop:
            return Color.lifeboard.statusWarning
        }
    }
}

@MainActor
extension WeeklyOutcomeStatus {
    var displayTitle: String {
        switch self {
        case .planned:
            return String(localized: "Planned")
        case .inProgress:
            return String(localized: "In progress")
        case .completed:
            return String(localized: "Done")
        case .dropped:
            return String(localized: "Let go")
        }
    }

    var tintColor: Color {
        switch self {
        case .planned:
            return Color.lifeboard.textSecondary
        case .inProgress:
            return Color.lifeboard.accentPrimary
        case .completed:
            return Color.lifeboard.statusSuccess
        case .dropped:
            return Color.lifeboard.statusWarning
        }
    }
}
