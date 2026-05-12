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

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

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
                            .fill(Color.lifeboard.accentWash)
                            .frame(width: 58, height: 58)

                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color.lifeboard.accentPrimary)
                    }

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        HStack(spacing: spacing.s8) {
                            Text("Daily Reflection")
                                .font(.lifeboard(.title3))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                            LifeBoardStatusPill(
                                text: statusBadgeText,
                                systemImage: statusBadgeSymbol,
                                tone: statusBadgeTone
                            )
                        }

                        Text(reflectionGuidance)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: spacing.s8) {
                    LifeBoardHeroMetricTile(
                        title: "Completed",
                        value: "\(tasksCompleted)",
                        detail: tasksCompleted == 0 ? "A tiny restart still counts" : "Visible wins from today",
                        tone: tasksCompleted > 0 ? .success : .neutral
                    )
                    LifeBoardHeroMetricTile(
                        title: "XP",
                        value: "\(xpEarned)",
                        detail: "Momentum earned today",
                        tone: xpEarned > 0 ? .accent : .neutral
                    )
                    LifeBoardHeroMetricTile(
                        title: "Streak",
                        value: "\(streakDays)d",
                        detail: streakDays > 0 ? "Continuity stays visible" : "Ready to restart",
                        tone: streakDays > 0 ? .warning : .neutral
                    )
                }
            }
            .padding(spacing.s16)
            .lifeboardPremiumSurface(
                cornerRadius: LifeBoardTheme.CornerRadius.card,
                fillColor: Color.lifeboard.surfacePrimary,
                accentColor: Color.lifeboard.accentSecondary,
                level: .e2
            )
            .lifeboardSuccessPulse(isActive: isCelebrating)

            VStack(alignment: .leading, spacing: spacing.s8) {
                Text("Today's signal")
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textTertiary)

                Text("\"\(motivationalQuote)\"")
                    .font(.lifeboard(.bodyEmphasis))
                    .italic()
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .multilineTextAlignment(.leading)

                if let statusMessage {
                    HStack(spacing: spacing.s8) {
                        Image(systemName: statusBadgeSymbol)
                            .font(.system(size: 12, weight: .semibold))
                        Text(statusMessage.text)
                            .font(.lifeboard(.caption1))
                    }
                    .foregroundStyle(statusMessage.color)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(spacing.s12)
            .lifeboardDenseSurface(
                cornerRadius: LifeBoardTheme.CornerRadius.card,
                fillColor: Color.lifeboard.surfacePrimary,
                strokeColor: Color.lifeboard.strokeHairline.opacity(0.72)
            )

            Button(action: {
                guard canClaim else { return }
                onComplete()
            }) {
                VStack(spacing: 2) {
                    Text(primaryCTA)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundColor(Color.lifeboard.textInverse)
                    Text(secondaryCTA)
                        .font(.lifeboard(.caption2))
                        .foregroundColor(Color.lifeboard.textInverse.opacity(0.82))
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
        .background(Color.lifeboard.bgCanvas)
        .accessibilityElement(children: .contain)
    }

    private func statRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(text)
                .font(.lifeboard(.callout))
                .foregroundColor(Color.lifeboard.textSecondary)
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
            return ("Claiming reflection reward...", Color.lifeboard.textSecondary)
        case .claimed(let xp):
            return ("Reflection claimed. +\(xp) XP awarded.", Color.lifeboard.statusSuccess)
        case .alreadyClaimed:
            return ("Reflection already completed today.", Color.lifeboard.textSecondary)
        case .unavailable(let message):
            return (message, Color.lifeboard.statusDanger)
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

    private var statusBadgeTone: LifeBoardStatusPillTone {
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
            return Color.lifeboard.accentPrimary
        case .submitting:
            return Color.lifeboard.accentPrimary.opacity(0.84)
        case .claimed, .alreadyClaimed:
            return Color.lifeboard.statusSuccess
        case .unavailable:
            return Color.lifeboard.statusDanger
        }
    }

    private var buttonStrokeColor: Color {
        switch claimState {
        case .ready, .submitting:
            return Color.lifeboard.accentPrimary.opacity(0.12)
        case .claimed, .alreadyClaimed:
            return Color.lifeboard.statusSuccess.opacity(0.2)
        case .unavailable:
            return Color.lifeboard.statusDanger.opacity(0.2)
        }
    }
}


// MARK: - Reflect Plan UI

import SwiftUI

enum DailyReflectionEntryCardMode {
    case compact
    case full
}

struct HomeDailyReflectionEntryCard: View {
    let state: DailyReflectionEntryState
    let mode: DailyReflectionEntryCardMode
    let onOpen: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        Button {
            onOpen()
        } label: {
            content
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            mode == .compact
                ? "home.dailyReflection.entry.compact"
                : "home.dailyReflection.entry.full"
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens Reflect and Plan")
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .compact:
            compactContent
        case .full:
            fullContent
        }
    }

    private var compactContent: some View {
        HStack(alignment: .center, spacing: spacing.s12) {
            HStack(alignment: .center, spacing: spacing.s8) {
                if let badgeText = state.badgeText {
                    badge(text: badgeText)
                }

                Text(state.narrativeSummary.homeCardLine)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: spacing.s4) {
                Text("Reflect & plan")
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.accentPrimary)
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeboardPremiumSurface(
            cornerRadius: corner.card,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.82),
            accentColor: Color.lifeboard.accentSecondary,
            level: .e1
        )
    }

    private var fullContent: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s8) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(state.title)
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                    Text(state.subtitle)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: spacing.s8)

                if let badgeText = state.badgeText {
                    badge(text: badgeText)
                }
            }

            if state.closedTasks.isEmpty == false {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    ForEach(state.closedTasks.prefix(3)) { task in
                        HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                            Circle()
                                .fill(Color.lifeboard.accentSecondary.opacity(0.5))
                                .frame(width: 5, height: 5)
                            Text(task.title)
                                .font(.lifeboard(.callout))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: spacing.s4)
                        }
                    }
                }
            }

            if state.habitGrid.isEmpty == false {
                ReflectionHabitMiniGridView(
                    items: Array(state.habitGrid.prefix(4)),
                    spacing: spacing
                )
            }

            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                Text(state.narrativeSummary.homeCardLine)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: spacing.s8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.textTertiary)
            }
        }
        .padding(spacing.s16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeboardPremiumSurface(
            cornerRadius: corner.card,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.82),
            accentColor: Color.lifeboard.accentSecondary,
            level: .e1
        )
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.lifeboard(.caption1).weight(.semibold))
            .fontWeight(.semibold)
            .foregroundStyle(Color.lifeboard.statusWarning)
            .padding(.horizontal, spacing.s8)
            .padding(.vertical, spacing.s4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.lifeboard.statusWarning.opacity(0.14))
            )
    }

    private var accessibilityLabel: String {
        switch mode {
        case .compact:
            var parts: [String] = []
            if let badgeText = state.badgeText {
                parts.append(badgeText)
            }
            parts.append(state.narrativeSummary.homeCardLine)
            parts.append("Reflect and plan")
            return parts.joined(separator: ". ")
        case .full:
            return "\(state.title). \(state.subtitle). \(state.narrativeSummary.homeCardLine)"
        }
    }
}

import SwiftUI

struct ReflectPlanScreen: View {
    @ObservedObject var viewModel: DailyReflectPlanViewModel
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isContextExpanded = false

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .overlay(Color.lifeboard.strokeHairline)
            content
            stickyFooter
        }
        .background(Color.lifeboard.bgCanvas.ignoresSafeArea())
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
        .accessibilityIdentifier("reflection.plan.screen")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(viewModel.screenTitle)
                    .font(.lifeboard(.title3).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                if let target = viewModel.target {
                    Text("Reflect on \(viewModel.reflectionDateLabel). Plan for \(viewModel.planningDateLabel).")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .accessibilityLabel(
                            "Reflect on \(viewModel.reflectionDateLabel). Plan for \(viewModel.planningDateLabel)."
                        )

                    if target.mode == .catchUpYesterday {
                        Text("Catch-up")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.lifeboard.statusWarning)
                            .padding(.horizontal, spacing.s8)
                            .padding(.vertical, spacing.s4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.lifeboard.statusWarning.opacity(0.14))
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
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.lifeboard.surfaceSecondary)
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
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Preparing your reflection context")
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text("Tasks and habits load first. Calendar details are added in the background.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(spacing.s16)
        } else if viewModel.isCompleteStateVisible {
            VStack(spacing: spacing.s12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.accentSecondary)
                Text("You're already closed out.")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                Text("There isn't an open reflection day right now.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(spacing.s24)
        } else if let coreSnapshot = viewModel.coreSnapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: spacing.s16) {
                    recapSurface(snapshot: coreSnapshot)

                    if let editablePlan = viewModel.editablePlan {
                        planningCard(plan: editablePlan, narrativeLine: coreSnapshot.narrativeSummary.planCardLine)
                    } else {
                        planningPlaceholderCard
                    }

                    contextDisclosureCard

                    if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.textSecondary)
                            .padding(.horizontal, spacing.s4)
                            .accessibilityLabel(successMessage)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(Color.lifeboard.statusWarning)
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
                    .foregroundStyle(Color.lifeboard.statusWarning)
                Text(viewModel.errorMessage ?? "The reflection flow couldn't load.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    viewModel.load()
                }
                .font(.lifeboard(.button))
                .buttonStyle(.plain)
                .foregroundStyle(Color.lifeboard.accentPrimary)
                .frame(minWidth: 44, minHeight: 44)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(spacing.s24)
        }
    }

    private var stickyFooter: some View {
        VStack(spacing: spacing.s8) {
            Divider()
                .overlay(Color.lifeboard.strokeHairline)
            Button {
                viewModel.save()
            } label: {
                HStack(spacing: spacing.s8) {
                    Text(viewModel.isSaving ? "Saving..." : "Save reflection & plan")
                        .font(.lifeboard(.button))
                }
                .foregroundStyle(Color.lifeboard.accentOnPrimary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.lifeboard.accentPrimary)
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSaving || !viewModel.canSave)
            .accessibilityHint("Saves the reflection and the next-day plan.")

            if let planningStatusMessage = viewModel.planningStatusMessage {
                Text(planningStatusMessage)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.center)
            } else if viewModel.isPlanningPlaceholderVisible {
                Text("Building the smaller plan now.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .multilineTextAlignment(.center)
            } else if dynamicTypeSize.isAccessibilitySize {
                Text("No typing is required.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.top, spacing.s8)
        .padding(.bottom, max(spacing.s12, layoutClass.isPad ? spacing.s16 : spacing.s8))
        .background(.ultraThinMaterial)
    }

    private func recapSurface(snapshot: DailyReflectionCoreSnapshot) -> some View {
        sectionCard(title: viewModel.target?.mode == .catchUpYesterday ? "Yesterday" : "Today") {
            VStack(alignment: .leading, spacing: spacing.s12) {
                if let pulseNote = snapshot.pulseNote, pulseNote.isEmpty == false {
                    Text(pulseNote)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if snapshot.closedTasks.isEmpty == false {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text("Closed tasks")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textTertiary)
                        VStack(alignment: .leading, spacing: spacing.s8) {
                            ForEach(snapshot.closedTasks.prefix(3)) { task in
                                HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                    Circle()
                                        .fill(Color.lifeboard.accentSecondary.opacity(0.55))
                                        .frame(width: 5, height: 5)
                                    VStack(alignment: .leading, spacing: spacing.s2) {
                                        Text(task.title)
                                            .font(.lifeboard(.callout))
                                            .foregroundStyle(Color.lifeboard.textPrimary)
                                            .lineLimit(1)
                                        if let projectName = task.projectName, projectName.isEmpty == false {
                                            Text(projectName)
                                                .font(.lifeboard(.caption1))
                                                .foregroundStyle(Color.lifeboard.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if snapshot.habitGrid.isEmpty == false {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text("Habit streaks")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textTertiary)
                        ReflectionHabitMiniGridView(items: snapshot.habitGrid, spacing: spacing)
                    }
                }

                if snapshot.closedTasks.isEmpty && snapshot.habitGrid.isEmpty {
                    Text("No recap items were captured for this day yet.")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                }
            }
        }
    }

    private var planningPlaceholderCard: some View {
        sectionCard(title: viewModel.target?.mode == .catchUpYesterday ? "Today" : "Tomorrow") {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text("Building plan suggestions...")
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                Text(viewModel.planningStatusMessage ?? "Tasks and habits are ready. Calendar context is still loading.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func planningCard(plan: EditableDailyPlan, narrativeLine: String) -> some View {
        sectionCard(title: viewModel.target?.mode == .catchUpYesterday ? "Today" : "Tomorrow") {
            VStack(alignment: .leading, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: spacing.s8) {
                    ForEach(Array(plan.topTasks.indices), id: \.self) { index in
                        let task = plan.topTasks[index]
                        HStack(alignment: .top, spacing: spacing.s8) {
                            Text("\(index + 1)")
                                .font(.lifeboard(.caption1).weight(.semibold))
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.lifeboard.textTertiary)
                                .frame(width: 20, alignment: .leading)

                            VStack(alignment: .leading, spacing: spacing.s2) {
                                Text(task.title)
                                    .font(.lifeboard(.callout).weight(.semibold))
                                    .foregroundStyle(Color.lifeboard.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let projectName = task.projectName, projectName.isEmpty == false {
                                    Text(projectName)
                                        .font(.lifeboard(.caption1))
                                        .foregroundStyle(Color.lifeboard.textSecondary)
                                }
                            }

                            Spacer(minLength: spacing.s8)

                            Button("Swap") {
                                viewModel.activeSwapSlot = index
                            }
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.lifeboard.accentPrimary)
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("Swap task \(index + 1)")
                        }
                    }
                }

                Text(narrativeLine)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: spacing.s8) {
                    if let focusWindow = plan.focusWindow {
                        planDetailRow(title: "Focus window", value: timeRangeLabel(focusWindow))
                    }

                    if let habitTitle = plan.protectedHabitTitle {
                        let value = plan.protectedHabitStreak.map { "\(habitTitle) · \($0)d streak" } ?? habitTitle
                        planDetailRow(title: "Protected habit", value: value)
                    }

                    if let risk = plan.primaryRisk {
                        planDetailRow(title: "Clear first", value: plan.primaryRiskDetail ?? risk.title)
                    }
                }

                if let planningStatusMessage = viewModel.planningStatusMessage {
                    Text(planningStatusMessage)
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var contextDisclosureCard: some View {
        sectionCard(title: "Add context") {
            DisclosureGroup(isExpanded: $isContextExpanded) {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text("One-line note")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textTertiary)
                        TextField("What mattered most?", text: $viewModel.noteText, axis: .vertical)
                            .font(.lifeboard(.callout))
                            .lineLimit(1...2)
                            .textFieldStyle(.plain)
                            .padding(spacing.s12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.lifeboard.surfaceSecondary)
                            )
                            .accessibilityLabel("Optional note")
                    }

                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text("Mood")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textTertiary)
                        chipRow(ReflectionMood.allCases, selection: viewModel.selectedMood) { mood in
                            viewModel.toggleMood(mood)
                        }
                    }

                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text("Energy")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textTertiary)
                        chipRow(ReflectionEnergy.allCases, selection: viewModel.selectedEnergy) { energy in
                            viewModel.toggleEnergy(energy)
                        }
                    }

                    VStack(alignment: .leading, spacing: spacing.s8) {
                        Text("Friction")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(Color.lifeboard.textTertiary)
                        frictionChipGrid
                    }
                }
                .padding(.top, spacing.s8)
            } label: {
                HStack(spacing: spacing.s8) {
                    Text("Mood, energy, friction, and note")
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                    Spacer(minLength: spacing.s8)
                    Text(isContextExpanded ? "Hide" : "Optional")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textTertiary)
                }
            }
            .tint(Color.lifeboard.textPrimary)
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
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .fontWeight(.semibold)
                    .foregroundStyle(selection == value ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                    .padding(.horizontal, spacing.s12)
                    .padding(.vertical, spacing.s8)
                    .frame(minHeight: 44)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selection == value ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
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
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? Color.lifeboard.accentOnPrimary : Color.lifeboard.textPrimary)
                    .padding(.horizontal, spacing.s12)
                    .padding(.vertical, spacing.s8)
                    .frame(minHeight: 44)
                    .background(
                        Capsule(style: .continuous)
                            .fill(isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.surfaceSecondary)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tag.title)
        }
    }

    private func planDetailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
            Text(title)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textTertiary)
            Text(value)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text(title)
                .font(.lifeboard(.title3).weight(.semibold))
                .foregroundStyle(Color.lifeboard.textPrimary)
            content()
        }
        .padding(spacing.s16)
        .lifeboardPremiumSurface(
            cornerRadius: corner.card,
            fillColor: Color.lifeboard.surfacePrimary,
            strokeColor: Color.lifeboard.strokeHairline.opacity(0.72),
            accentColor: Color.lifeboard.accentSecondary,
            level: .e1
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
                                .font(.lifeboard(.bodyEmphasis))
                                .foregroundStyle(Color.lifeboard.textPrimary)
                            if let projectName = option.projectName, projectName.isEmpty == false {
                                Text(projectName)
                                    .font(.lifeboard(.caption1))
                                    .foregroundStyle(Color.lifeboard.textSecondary)
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

@MainActor
private struct ReflectionHabitMiniGridView: View {
    let items: [ReflectionHabitMiniRow]
    let spacing: LifeBoardSpacingTokens

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: spacing.s8),
                GridItem(.flexible(), spacing: spacing.s8)
            ],
            alignment: .leading,
            spacing: spacing.s8
        ) {
            ForEach(items.prefix(4)) { habit in
                ReflectionHabitMiniTileView(habit: habit, spacing: spacing)
            }
        }
    }
}

@MainActor
private struct ReflectionHabitMiniTileView: View {
    let habit: ReflectionHabitMiniRow
    let spacing: LifeBoardSpacingTokens

    private var cells: [HabitBoardCell] {
        let referenceDate = habit.last7Days.last?.date ?? Date()
        return HabitBoardPresentationBuilder.buildCells(
            marks: habit.last7Days,
            cadence: .daily(),
            referenceDate: referenceDate,
            dayCount: max(7, habit.last7Days.count)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                Text(habit.title)
                    .font(.lifeboard(.caption1).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: spacing.s4)
                if habit.currentStreak > 0 {
                    Text("\(habit.currentStreak)d")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color.lifeboard.textTertiary)
                }
            }

            HabitBoardStripView(
                cells: Array(cells.suffix(7)),
                family: habit.colorFamily,
                mode: .compact,
                cellSizeOverride: 10,
                cellWidthOverride: 10,
                cellHeightOverride: 10
            )
        }
        .padding(spacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.lifeboard.surfaceSecondary.opacity(0.72))
        )
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
