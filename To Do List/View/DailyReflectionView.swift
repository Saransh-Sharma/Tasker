import SwiftUI

public enum DailyReflectionClaimState: Equatable {
    case ready
    case submitting
    case claimed(xp: Int)
    case alreadyClaimed
    case unavailable(message: String)
}

/// Bottom sheet for daily reflection prompt.
/// Shows today's progress summary and awards XP on completion.
public struct DailyReflectionView: View {

    let tasksCompleted: Int
    let xpEarned: Int
    let streakDays: Int
    let claimState: DailyReflectionClaimState
    let onComplete: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    private var motivationalQuote: String {
        let quotes = [
            "Small steps, big momentum",
            "Progress, not perfection",
            "Every task builds the system",
            "Consistency compounds",
            "You showed up — that matters"
        ]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return quotes[dayOfYear % quotes.count]
    }

    public var body: some View {
        VStack(spacing: spacing.s16) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .top, spacing: spacing.s12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.tasker.accentWash)
                            .frame(width: 58, height: 58)

                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.tasker.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        HStack(spacing: spacing.s8) {
                            Text("Daily Reflection")
                                .font(.tasker(.title3))
                                .foregroundStyle(Color.tasker.textPrimary)
                            TaskerStatusPill(
                                text: statusBadgeText,
                                systemImage: statusBadgeSymbol,
                                tone: statusBadgeTone
                            )
                        }

                        Text(reflectionGuidance)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: spacing.s8) {
                    TaskerHeroMetricTile(
                        title: "Completed",
                        value: "\(tasksCompleted)",
                        detail: tasksCompleted == 0 ? "A tiny restart still counts" : "Visible wins from today",
                        tone: tasksCompleted > 0 ? .success : .neutral
                    )
                    TaskerHeroMetricTile(
                        title: "XP",
                        value: "\(xpEarned)",
                        detail: "Momentum earned today",
                        tone: xpEarned > 0 ? .accent : .neutral
                    )
                    TaskerHeroMetricTile(
                        title: "Streak",
                        value: "\(streakDays)d",
                        detail: streakDays > 0 ? "Continuity stays visible" : "Ready to restart",
                        tone: streakDays > 0 ? .warning : .neutral
                    )
                }
            }
            .padding(spacing.s16)
            .taskerPremiumSurface(
                cornerRadius: TaskerTheme.CornerRadius.card,
                fillColor: Color.tasker.surfacePrimary,
                accentColor: Color.tasker.accentSecondary,
                level: .e2
            )
            .taskerSuccessPulse(isActive: isCelebrating)

            VStack(alignment: .leading, spacing: spacing.s8) {
                Text("Today's signal")
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker.textTertiary)

                Text("\"\(motivationalQuote)\"")
                    .font(.tasker(.bodyEmphasis))
                    .italic()
                    .foregroundStyle(Color.tasker.textPrimary)
                    .multilineTextAlignment(.leading)

                if let statusMessage {
                    HStack(spacing: spacing.s8) {
                        Image(systemName: statusBadgeSymbol)
                            .font(.system(size: 12, weight: .semibold))
                        Text(statusMessage.text)
                            .font(.tasker(.caption1))
                    }
                    .foregroundStyle(statusMessage.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(spacing.s12)
            .taskerDenseSurface(
                cornerRadius: TaskerTheme.CornerRadius.card,
                fillColor: Color.tasker.surfacePrimary,
                strokeColor: Color.tasker.strokeHairline.opacity(0.72)
            )

            Button(action: {
                guard canClaim else { return }
                onComplete()
            }) {
                VStack(spacing: 2) {
                    Text(primaryCTA)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundColor(Color.tasker.textInverse)
                    Text(secondaryCTA)
                        .font(.tasker(.caption2))
                        .foregroundColor(Color.tasker.textInverse.opacity(0.82))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(buttonFillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(buttonStrokeColor, lineWidth: 1)
                )
            }
            .disabled(!canClaim)
            .opacity(canClaim ? 1.0 : 0.7)
        }
        .padding(.horizontal, spacing.screenHorizontal)
        .padding(.vertical, spacing.s16)
        .background(Color.tasker.bgCanvas)
        .accessibilityElement(children: .contain)
    }

    private func statRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(text)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textSecondary)
        }
    }

    private var canClaim: Bool {
        if case .ready = claimState {
            return true
        }
        if case .unavailable = claimState {
            return true
        }
        return false
    }

    private var primaryCTA: String {
        switch claimState {
        case .ready:
            return "Complete Reflection"
        case .submitting:
            return "Claiming Reflection..."
        case .claimed:
            return "Reflection Claimed"
        case .alreadyClaimed:
            return "Reflection Already Claimed"
        case .unavailable:
            return "Try Again"
        }
    }

    private var secondaryCTA: String {
        switch claimState {
        case .ready:
            return "+10 XP"
        case .submitting:
            return "Applying reward"
        case .claimed(let xp):
            return "+\(xp) XP secured"
        case .alreadyClaimed:
            return "Already completed today"
        case .unavailable:
            return "Claim unavailable"
        }
    }

    private var statusMessage: (text: String, color: Color)? {
        switch claimState {
        case .ready:
            return nil
        case .submitting:
            return ("Claiming reflection reward...", Color.tasker.textSecondary)
        case .claimed(let xp):
            return ("Reflection claimed. +\(xp) XP awarded.", Color.tasker.statusSuccess)
        case .alreadyClaimed:
            return ("Reflection already completed today.", Color.tasker.textSecondary)
        case .unavailable(let message):
            return (message, Color.tasker.statusDanger)
        }
    }

    private var statusBadgeText: String {
        switch claimState {
        case .ready:
            return "Ready"
        case .submitting:
            return "Claiming"
        case .claimed:
            return "Claimed"
        case .alreadyClaimed:
            return "Complete"
        case .unavailable:
            return "Retry"
        }
    }

    private var statusBadgeTone: TaskerStatusPillTone {
        switch claimState {
        case .ready:
            return .accent
        case .submitting:
            return .warning
        case .claimed, .alreadyClaimed:
            return .success
        case .unavailable:
            return .danger
        }
    }

    private var statusBadgeSymbol: String {
        switch claimState {
        case .ready:
            return "sparkles"
        case .submitting:
            return "hourglass"
        case .claimed, .alreadyClaimed:
            return "checkmark.circle.fill"
        case .unavailable:
            return "arrow.clockwise"
        }
    }

    private var reflectionGuidance: String {
        if tasksCompleted == 0 {
            return "Use reflection to reset the loop without turning today into a verdict."
        }
        return "Close the day by noticing progress, not chasing perfection."
    }

    private var isCelebrating: Bool {
        if case .claimed = claimState {
            return true
        }
        return false
    }

    private var buttonFillColor: Color {
        switch claimState {
        case .ready:
            return Color.tasker.accentPrimary
        case .submitting:
            return Color.tasker.accentPrimary.opacity(0.84)
        case .claimed, .alreadyClaimed:
            return Color.tasker.statusSuccess
        case .unavailable:
            return Color.tasker.statusDanger
        }
    }

    private var buttonStrokeColor: Color {
        switch claimState {
        case .ready, .submitting:
            return Color.tasker.accentPrimary.opacity(0.12)
        case .claimed, .alreadyClaimed:
            return Color.tasker.statusSuccess.opacity(0.2)
        case .unavailable:
            return Color.tasker.statusDanger.opacity(0.2)
        }
    }
}


// MARK: - Reflect Plan UI

import SwiftUI

struct HomeDailyReflectionEntryCard: View {
    let state: DailyReflectionEntryState
    let onOpen: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        Button {
            onOpen()
        } label: {
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(alignment: .top, spacing: spacing.s8) {
                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text(state.title)
                            .font(.tasker(.headline))
                            .foregroundStyle(Color.tasker.textPrimary)
                        Text(state.subtitle)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: spacing.s8)

                    if let badgeText = state.badgeText {
                        Text(badgeText)
                            .font(.tasker(.caption2))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.tasker.statusWarning)
                            .padding(.horizontal, spacing.s8)
                            .padding(.vertical, spacing.s4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.tasker.statusWarning.opacity(0.14))
                            )
                    }
                }

                Text(state.summaryText)
                    .font(.tasker(.body))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .multilineTextAlignment(.leading)

                HStack(spacing: spacing.s8) {
                    Label("Open flow", systemImage: "arrow.up.right")
                        .font(.tasker(.caption1))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.tasker.accentPrimary)
                    Spacer()
                }
            }
            .padding(spacing.s16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .taskerPremiumSurface(
                cornerRadius: corner.card,
                fillColor: Color.tasker.surfacePrimary,
                strokeColor: Color.tasker.strokeHairline.opacity(0.82),
                accentColor: Color.tasker.accentSecondary,
                level: .e2
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.dailyReflection.entry")
        .accessibilityLabel("\(state.title). \(state.subtitle). \(state.summaryText)")
    }
}

struct HomeDailyPlanDraftCard: View {
    let draft: DailyPlanDraft
    let onTaskTap: (UUID) -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Text("Plan draft")
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)

            VStack(alignment: .leading, spacing: spacing.s8) {
                ForEach(Array(draft.topTasks.indices), id: \.self) { index in
                    let task = draft.topTasks[index]
                    Button {
                        onTaskTap(task.id)
                    } label: {
                        HStack(alignment: .top, spacing: spacing.s8) {
                            Text("\(index + 1)")
                                .font(.tasker(.caption1))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.tasker.textTertiary)
                            VStack(alignment: .leading, spacing: spacing.s2) {
                                Text(task.title)
                                    .font(.tasker(.bodyEmphasis))
                                    .foregroundStyle(Color.tasker.textPrimary)
                                if let projectName = task.projectName, projectName.isEmpty == false {
                                    Text(projectName)
                                        .font(.tasker(.caption1))
                                        .foregroundStyle(Color.tasker.textSecondary)
                                }
                            }
                            Spacer(minLength: spacing.s8)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Top task \(index + 1). \(task.title)")
                }
            }

            if let focus = draft.suggestedFocusBlock {
                detailRow(title: "Focus window", value: timeRange(focus))
            }
            if let habitTitle = draft.protectedHabitTitle {
                detailRow(title: "Protected habit", value: habitTitle)
            }
            if let risk = draft.primaryRisk {
                detailRow(title: "Clear first", value: draft.primaryRiskDetail ?? risk.title)
            }
        }
        .padding(spacing.s16)
        .taskerPremiumSurface(
            cornerRadius: corner.card,
            fillColor: Color.tasker.surfacePrimary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.82),
            accentColor: Color.tasker.accentSecondary,
            level: .e2
        )
        .accessibilityIdentifier("home.dailyPlanDraft.card")
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: spacing.s2) {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textTertiary)
            Text(value)
                .font(.tasker(.caption1))
                        .fontWeight(.semibold)
                .foregroundStyle(Color.tasker.textPrimary)
        }
    }

    private func timeRange(_ interval: DateInterval) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: interval.start, to: interval.end)
    }
}


import SwiftUI

struct ReflectPlanScreen: View {
    @ObservedObject var viewModel: DailyReflectPlanViewModel
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .overlay(Color.tasker.strokeHairline)
            content
            stickyFooter
        }
        .background(Color.tasker.bgCanvas.ignoresSafeArea())
        .sheet(isPresented: Binding(
            get: { viewModel.activeSwapSlot != nil },
            set: { if !$0 { viewModel.activeSwapSlot = nil } }
        )) {
            if let slot = viewModel.activeSwapSlot {
                swapSheet(slotIndex: slot)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onDisappear {
            viewModel.cancelLoading()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(viewModel.screenTitle)
                    .font(.tasker(.title3))
                    .foregroundStyle(Color.tasker.textPrimary)

                if let target = viewModel.target {
                    Text("Reflect on \(viewModel.reflectionDateLabel). Plan for \(viewModel.planningDateLabel).")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .accessibilityLabel(
                            "Reflect on \(viewModel.reflectionDateLabel). Plan for \(viewModel.planningDateLabel)."
                        )

                    if target.mode == .catchUpYesterday {
                        Text("Catch-up")
                            .font(.tasker(.caption2))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.tasker.statusWarning)
                            .padding(.horizontal, spacing.s8)
                            .padding(.vertical, spacing.s4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.tasker.statusWarning.opacity(0.14))
                            )
                    }
                }
            }

            Spacer()

            Button {
                dismissIfPossible()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.tasker.surfaceSecondary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Reflect and Plan")
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s16)
        .padding(.bottom, spacing.s12)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.loadState == .loadingCore {
            VStack(spacing: spacing.s12) {
                ProgressView()
                Text("Loading reflection context...")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.isCompleteStateVisible {
            VStack(spacing: spacing.s12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.tasker.accentSecondary)
                Text("You're already closed out.")
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)
                Text("There isn't an open reflection day right now.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(spacing.s24)
        } else if let coreSnapshot = viewModel.coreSnapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    if let pulseNote = coreSnapshot.pulseNote, pulseNote.isEmpty == false {
                        infoCard(title: "LifeBoard note", body: pulseNote)
                    }

                    recapGrid(snapshot: coreSnapshot)

                    if coreSnapshot.biggestWins.isEmpty == false {
                        sectionCard(title: "Biggest wins") {
                            VStack(alignment: .leading, spacing: spacing.s8) {
                                ForEach(coreSnapshot.biggestWins) { highlight in
                                    VStack(alignment: .leading, spacing: spacing.s2) {
                                        Text(highlight.title)
                                            .font(.tasker(.bodyEmphasis))
                                            .foregroundStyle(Color.tasker.textPrimary)
                                        if let detail = highlight.detail, detail.isEmpty == false {
                                            Text(detail)
                                                .font(.tasker(.caption1))
                                                .foregroundStyle(Color.tasker.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    chipSection(title: "Mood", subtitle: "Optional. Pick one that fits.") {
                        chipRow(ReflectionMood.allCases, selection: viewModel.selectedMood) { mood in
                            viewModel.toggleMood(mood)
                        }
                    }

                    chipSection(title: "Energy", subtitle: "Optional. Pick one.") {
                        chipRow(ReflectionEnergy.allCases, selection: viewModel.selectedEnergy) { energy in
                            viewModel.toggleEnergy(energy)
                        }
                    }

                    chipSection(title: "Friction", subtitle: "Optional. Pick any blockers that mattered.") {
                        frictionChipGrid
                    }

                    sectionCard(title: "One-line note") {
                        TextField("Optional. What mattered most?", text: $viewModel.noteText, axis: .vertical)
                            .font(.tasker(.body))
                            .lineLimit(1...2)
                            .textFieldStyle(.plain)
                            .padding(spacing.s12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.tasker.surfaceSecondary)
                            )
                            .accessibilityLabel("Optional note")
                    }

                    if let editablePlan = viewModel.editablePlan {
                        planningCard(plan: editablePlan)
                    } else {
                        planningPlaceholderCard
                    }

                    if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textSecondary)
                            .padding(.horizontal, spacing.s4)
                            .accessibilityLabel(successMessage)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.statusWarning)
                            .padding(.horizontal, spacing.s4)
                            .accessibilityLabel(errorMessage)
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s16)
                .padding(.bottom, spacing.s24)
            }
        } else {
            VStack(spacing: spacing.s12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.tasker.statusWarning)
                Text(viewModel.errorMessage ?? "The reflection flow couldn't load.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    viewModel.load()
                }
                .font(.tasker(.button))
                .buttonStyle(.plain)
                .foregroundStyle(Color.tasker.accentPrimary)
                .frame(minWidth: 44, minHeight: 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(spacing.s24)
        }
    }

    private var stickyFooter: some View {
        VStack(spacing: spacing.s8) {
            Divider()
                .overlay(Color.tasker.strokeHairline)
            Button {
                viewModel.save()
            } label: {
                HStack(spacing: spacing.s8) {
                    if viewModel.isSaving {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.tasker.accentOnPrimary)
                    }
                    Text(viewModel.isSaving ? "Saving..." : "Save reflection & plan")
                        .font(.tasker(.button))
                }
                .foregroundStyle(Color.tasker.accentOnPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.tasker.accentPrimary)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSaving || !viewModel.canSave)
            .accessibilityHint("Saves the reflection and the next-day plan.")

            if let planningStatusMessage = viewModel.planningStatusMessage {
                Text(planningStatusMessage)
                    .font(.tasker(.caption2))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .multilineTextAlignment(.center)
            } else if viewModel.isPlanningPlaceholderVisible {
                Text("Building plan suggestions. Reflection inputs are already ready.")
                    .font(.tasker(.caption2))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .multilineTextAlignment(.center)
            } else if dynamicTypeSize.isAccessibilitySize {
                Text("No typing is required. Chips and suggested tasks are enough.")
                    .font(.tasker(.caption2))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s8)
        .padding(.bottom, max(spacing.s12, layoutClass.isPad ? spacing.s16 : spacing.s8))
        .background(.ultraThinMaterial)
    }

    private func recapGrid(snapshot: DailyReflectionCoreSnapshot) -> some View {
        VStack(spacing: spacing.s12) {
            sectionCard(title: "Recap") {
                VStack(spacing: spacing.s8) {
                    recapRow(
                        title: "Tasks",
                        summary: "\(snapshot.tasksSummary.completedCount) completed | \(snapshot.tasksSummary.carryOverCount) carryover",
                        accessibilityLabel: "Tasks. \(snapshot.tasksSummary.completedCount) completed. \(snapshot.tasksSummary.carryOverCount) carryover."
                    )

                    if let habits = snapshot.habitsSummary {
                        recapRow(
                            title: "Habits",
                            summary: "\(habits.keptCount) kept | \(habits.missedCount) missed",
                            accessibilityLabel: "Habits. \(habits.keptCount) kept. \(habits.missedCount) missed."
                        )
                    }

                    if let calendarSummary = viewModel.optionalContext?.calendarSummary {
                        recapRow(
                            title: "Calendar",
                            summary: "\(calendarSummary.eventCount) events | \(calendarSummary.meetingMinutes)m busy",
                            accessibilityLabel: "Calendar. \(calendarSummary.eventCount) events. \(calendarSummary.meetingMinutes) minutes busy."
                        )
                    }
                }
            }
        }
    }

    private var planningPlaceholderCard: some View {
        sectionCard(title: "Plan for \(viewModel.planningDateLabel)") {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(spacing: spacing.s8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Building plan suggestions...")
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker.textPrimary)
                }

                Text(viewModel.planningStatusMessage ?? "Tasks and habits are ready. Calendar context is still loading.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func planningCard(plan: EditableDailyPlan) -> some View {
        sectionCard(title: "Plan for \(viewModel.planningDateLabel)") {
            VStack(alignment: .leading, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    ForEach(Array(plan.topTasks.indices), id: \.self) { index in
                        let task = plan.topTasks[index]
                        HStack(alignment: .top, spacing: spacing.s8) {
                            Text("\(index + 1)")
                                .font(.tasker(.caption1))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.tasker.textTertiary)
                                .frame(width: 20, alignment: .leading)

                            VStack(alignment: .leading, spacing: spacing.s2) {
                                Text(task.title)
                                    .font(.tasker(.bodyEmphasis))
                                    .foregroundStyle(Color.tasker.textPrimary)
                                if let projectName = task.projectName, projectName.isEmpty == false {
                                    Text(projectName)
                                        .font(.tasker(.caption1))
                                        .foregroundStyle(Color.tasker.textSecondary)
                                }
                            }

                            Spacer(minLength: spacing.s8)

                            Button("Swap") {
                                viewModel.activeSwapSlot = index
                            }
                            .font(.tasker(.caption1))
                        .fontWeight(.semibold)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.tasker.accentPrimary)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Swap task \(index + 1)")
                        }
                    }
                }

                if let focusWindow = plan.focusWindow {
                    detailPill(title: "Focus window", value: timeRangeLabel(focusWindow))
                }

                if let habitTitle = plan.protectedHabitTitle {
                    detailPill(title: "Protected habit", value: habitTitle)
                }

                if let risk = plan.primaryRisk {
                    detailPill(title: "Clear first", value: plan.primaryRiskDetail ?? risk.title)
                }

                if let planningStatusMessage = viewModel.planningStatusMessage {
                    Text(planningStatusMessage)
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func chipSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        sectionCard(title: title) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                Text(subtitle)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                content()
            }
        }
    }

    private func chipRow<Value: Hashable & CaseIterable>(
        _ values: Value.AllCases,
        selection: Value?,
        onTap: @escaping (Value) -> Void
    ) -> some View where Value: RawRepresentable, Value.RawValue == String {
        FlexibleChipFlow(items: Array(values)) { value in
            Button {
                onTap(value)
            } label: {
                Text(String(describing: value).capitalized)
                    .font(.tasker(.caption1))
                    .fontWeight(.semibold)
                    .foregroundStyle(selection == value ? Color.tasker.accentOnPrimary : Color.tasker.textPrimary)
                    .padding(.horizontal, spacing.s12)
                    .padding(.vertical, spacing.s8)
                    .frame(minHeight: 44)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selection == value ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var frictionChipGrid: some View {
        FlexibleChipFlow(items: ReflectionFrictionTag.allCases) { tag in
            let isSelected = viewModel.selectedFrictionTags.contains(tag)
            Button {
                viewModel.toggleFriction(tag)
            } label: {
                Text(tag.title)
                    .font(.tasker(.caption1))
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? Color.tasker.accentOnPrimary : Color.tasker.textPrimary)
                    .padding(.horizontal, spacing.s12)
                    .padding(.vertical, spacing.s8)
                    .frame(minHeight: 44)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.tasker.accentPrimary : Color.tasker.surfaceSecondary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tag.title)
        }
    }

    private func recapRow(title: String, summary: String, accessibilityLabel: String) -> some View {
        HStack(alignment: .top, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: spacing.s2) {
                Text(title)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker.textPrimary)
                Text(summary)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func infoCard(title: String, body: String) -> some View {
        sectionCard(title: title) {
            Text(body)
                .font(.tasker(.body))
                .foregroundStyle(Color.tasker.textPrimary)
        }
    }

    private func detailPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: spacing.s2) {
            Text(title)
                .font(.tasker(.caption2))
                .foregroundStyle(Color.tasker.textTertiary)
            Text(value)
                .font(.tasker(.caption1))
                .fontWeight(.semibold)
                .foregroundStyle(Color.tasker.textPrimary)
        }
        .padding(spacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.tasker.surfaceSecondary)
        )
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text(title)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
            content()
        }
        .padding(spacing.s16)
        .taskerPremiumSurface(
            cornerRadius: corner.card,
            fillColor: Color.tasker.surfacePrimary,
            strokeColor: Color.tasker.strokeHairline.opacity(0.84),
            accentColor: Color.tasker.accentSecondary,
            level: .e2
        )
    }

    private func timeRangeLabel(_ interval: DateInterval) -> String {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: interval.start, to: interval.end)
    }

    private func swapSheet(slotIndex: Int) -> some View {
        NavigationStack {
            List {
                ForEach(viewModel.swapOptions(for: slotIndex)) { option in
                    Button {
                        viewModel.swapTask(slotIndex: slotIndex, with: option)
                    } label: {
                        VStack(alignment: .leading, spacing: spacing.s2) {
                            Text(option.title)
                                .font(.tasker(.bodyEmphasis))
                                .foregroundStyle(Color.tasker.textPrimary)
                            if let projectName = option.projectName, projectName.isEmpty == false {
                                Text(projectName)
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Use \(option.title)")
                }
            }
            .navigationTitle("Swap task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        viewModel.activeSwapSlot = nil
                    }
                }
            }
        }
    }

    private func dismissIfPossible() {
        onClose()
        dismiss()
    }
}

private struct FlexibleChipFlow<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            AnyLayout(WrappingHStackLayout(horizontalSpacing: 8, verticalSpacing: 8)) {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    content(item)
                }
            }
        }
    }
}

private struct WrappingHStackLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + verticalSpacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }

        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var cursor = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursor.x + size.width > bounds.maxX, cursor.x > bounds.minX {
                cursor.x = bounds.minX
                cursor.y += lineHeight + verticalSpacing
                lineHeight = 0
            }

            subview.place(
                at: cursor,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            cursor.x += size.width + horizontalSpacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

extension ReflectionMood: Identifiable {
    public var id: String { rawValue }
}

extension ReflectionEnergy: Identifiable {
    public var id: String { rawValue }
}

extension ReflectionFrictionTag: Identifiable {
    public var id: String { rawValue }
}
