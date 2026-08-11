import SwiftUI
import UIKit

// The sheet's own chrome: root, background, progress, and the completion
// and error states.

// MARK: - EvaOverdueRescueSheetV2Root

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct EvaOverdueRescueSheetV2: View {


    let plan: EvaRescuePlan?

    let tasksByID: [UUID: TaskDefinition]

    let projectsByID: [UUID: Project]

    let referenceDate: Date

    let lastBatchRunID: UUID?

    let bottomInset: CGFloat

    let launchContext: OverdueRescueLaunchContext

    let onClose: () -> Void

    let onExit: () -> Void

    let onUpdate: @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void

    let onDelete: @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void

    let onRestore: @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void

    let onApply: @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void

    let onUndo: @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void

    let onSavePlanningMetadata: @Sendable (
        [PlanningTaskMetadata],
        @escaping @Sendable (Result<Void, Error>) -> Void
    ) -> Void

    let onTrack: (String, [String: Any]) -> Void

    @StateObject var viewModel: OverdueRescueViewModel

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(
        plan: EvaRescuePlan?,
        tasksByID: [UUID: TaskDefinition],
        projectsByID: [UUID: Project],
        referenceDate: Date = Date(),
        lastBatchRunID: UUID?,
        bottomInset: CGFloat = 0,
        launchContext: OverdueRescueLaunchContext? = nil,
        onClose: @escaping () -> Void = {},
        onExit: @escaping () -> Void = {},
        onUpdate: @escaping @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onDelete: @escaping @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void,
        onRestore: @escaping @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void,
        onApply: @escaping @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onUndo: @escaping @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void,
        onSavePlanningMetadata: @escaping @Sendable (
            [PlanningTaskMetadata],
            @escaping @Sendable (Result<Void, Error>) -> Void
        ) -> Void = { _, completion in completion(.success(())) },
        onTrack: @escaping (String, [String: Any]) -> Void
    ) {
        let resolvedLaunchContext = launchContext ?? .home(referenceDate: referenceDate)
        self.plan = plan
        self.tasksByID = tasksByID
        self.projectsByID = projectsByID
        self.referenceDate = referenceDate
        self.lastBatchRunID = lastBatchRunID
        self.bottomInset = bottomInset
        self.launchContext = resolvedLaunchContext
        self.onClose = onClose
        self.onExit = onExit
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.onRestore = onRestore
        self.onApply = onApply
        self.onUndo = onUndo
        self.onSavePlanningMetadata = onSavePlanningMetadata
        self.onTrack = onTrack
        _viewModel = StateObject(wrappedValue: OverdueRescueViewModel(
            plan: plan,
            tasksByID: tasksByID,
            projectsByID: projectsByID,
            referenceDate: referenceDate,
            launchContext: resolvedLaunchContext,
            sessionScope: resolvedLaunchContext.sessionScope(),
            onUpdate: onUpdate,
            onDelete: onDelete,
            onRestore: onRestore,
            onApplyBulk: onApply,
            onUndoBulk: onUndo,
            onSavePlanningMetadata: onSavePlanningMetadata,
            onTrack: onTrack
        ))
    }

    var body: some View {
        ZStack {
            OverdueRescueBackground()

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Overdue Rescue")
                .accessibilityIdentifier("home.rescue.sheet")
                .allowsHitTesting(false)

            switch viewModel.state {
            case .paused:
                OverdueRescuePauseView(viewModel: viewModel, bottomInset: bottomInset, onDismiss: onClose)
            case .completed:
                OverdueRescueCompletionView(
                    summary: viewModel.summary,
                    remaining: viewModel.totalRemainingCount,
                    bottomInset: bottomInset,
                    viewToday: {
                        viewModel.finishAndClearSession()
                        onExit()
                    },
                    reviewRemaining: {
                        viewModel.startManualReview()
                    },
                    launchOrigin: launchContext.origin,
                    startedEmpty: viewModel.startedEmpty
                )
            case .error:
                OverdueRescueErrorView(message: viewModel.errorMessage ?? "Something went wrong while updating the rescue deck.") {
                    viewModel.startManualReview()
                } close: {
                    onExit()
                }
            default:
                OverdueRescueDeckView(viewModel: viewModel, bottomInset: bottomInset, close: {
                    viewModel.pause()
                    onClose()
                })
            }
        }
        .overlay {
            if viewModel.state == .confirmingDelete {
                OverdueRescueDeleteOverlay(
                    taskTitle: viewModel.currentCard?.task.title,
                    onConfirm: { viewModel.confirmDelete() },
                    onCancel: { viewModel.cancelDelete() }
                )
                .transition(.opacity)
                .zIndex(60)
            }
        }
        .animation(reduceMotion ? nil : LifeBoardAnimation.stateChange, value: viewModel.state == .confirmingDelete)
        .lifeboardSnackbar($viewModel.snackbar, bottomPadding: bottomInset + 20)
        .sheet(isPresented: Binding(
            get: { viewModel.state == .editing },
            set: { if !$0 { viewModel.cancelEdit() } }
        )) {
            if let card = viewModel.currentCard {
                OverdueRescueQuickEditSheet(
                    card: card,
                    projects: Array(projectsByID.values).sorted { $0.name < $1.name },
                    save: { viewModel.saveEdit(draft: $0) },
                    cancel: { viewModel.cancelEdit() }
                )
            }
        }
        .sheet(isPresented: $viewModel.showSafeFixesConfirmation) {
            OverdueRescueSafeFixesView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showLargeStackPreflight) {
            OverdueRescueLargeStackView(
                count: viewModel.allCount,
                safeCount: viewModel.safeFixes.count,
                applySafeFixes: {
                    viewModel.showLargeStackPreflight = false
                    viewModel.showSafeFixesConfirmation = true
                },
                startManualReview: viewModel.startManualReview
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            viewModel.pause()
        }
    }
}

/// Canonical rescue presentation boundary shared by Home and Day Rescue.
/// Launcher failure/empty/loading state lives with the rescue feature rather
/// than a particular app shell, so every entry point preserves the same retry,
/// dismissal, apply, compensation, and Undo behavior.
struct OverdueRescuePresentationHost: View {
    @Bindable var coordinator: OverdueRescueLaunchCoordinator
    let projectsByID: [UUID: Project]
    let bottomInset: CGFloat
    let onRetry: () -> Void
    let onUpdate: @Sendable (UpdateTaskDefinitionRequest, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    let onDelete: @Sendable (UUID, @escaping @Sendable (Result<Void, Error>) -> Void) -> Void
    let onRestore: @Sendable (TaskDefinition, @escaping @Sendable (Result<TaskDefinition, Error>) -> Void) -> Void
    let onApply: @Sendable ([EvaBatchMutationInstruction], @escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onUndo: @Sendable (@escaping @Sendable (Result<AssistantActionRunDefinition, Error>) -> Void) -> Void
    let onSavePlanningMetadata: @Sendable ([PlanningTaskMetadata], @escaping @Sendable (Result<Void, Error>) -> Void) -> Void
    let onTrack: (String, [String: Any]) -> Void
    var onDismiss: () -> Void = {}

    var body: some View {
        ZStack {
            launcherOverlay
            deckOverlay
        }
    }

    @ViewBuilder
    private var launcherOverlay: some View {
        switch coordinator.launcherState {
        case .loading:
            OverdueRescueLauncherOverlayView(
                title: "Preparing rescue",
                message: "Finding tasks that still need a decision.",
                showsProgress: true,
                primaryTitle: nil,
                secondaryTitle: nil,
                onPrimary: nil,
                onSecondary: nil
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .zIndex(45)
            .accessibilityIdentifier("home.rescue.launcher.loading")
        case .failed(let message):
            OverdueRescueLauncherOverlayView(
                title: "Rescue could not start",
                message: message,
                showsProgress: false,
                primaryTitle: "Try again",
                secondaryTitle: "Dismiss",
                onPrimary: onRetry,
                onSecondary: onDismiss
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .zIndex(45)
            .accessibilityIdentifier("home.rescue.launcher.failed")
        case .idle, .ready:
            EmptyView()
        }
    }

    @ViewBuilder
    private var deckOverlay: some View {
        if coordinator.isPresented, let launchContext = coordinator.presentation {
            EvaOverdueRescueSheetV2(
                plan: coordinator.plan,
                tasksByID: coordinator.presentedTasksByID,
                projectsByID: projectsByID,
                referenceDate: coordinator.referenceDate ?? launchContext.referenceDate,
                lastBatchRunID: coordinator.lastBatchRunID,
                bottomInset: bottomInset,
                launchContext: launchContext,
                onClose: onDismiss,
                onExit: onDismiss,
                onUpdate: onUpdate,
                onDelete: onDelete,
                onRestore: onRestore,
                onApply: onApply,
                onUndo: onUndo,
                onSavePlanningMetadata: onSavePlanningMetadata,
                onTrack: onTrack
            )
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
            .zIndex(46)
        }
    }
}

private struct OverdueRescueLauncherOverlayView: View {
    let title: String
    let message: String
    let showsProgress: Bool
    let primaryTitle: String?
    let secondaryTitle: String?
    let onPrimary: (() -> Void)?
    let onSecondary: (() -> Void)?

    var body: some View {
        ZStack {
            Color.lifeboard(.overlayScrim)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(OverdueRescuePalette.accentGradient.opacity(0.18))
                        .frame(width: 76, height: 76)

                    Image(systemName: showsProgress ? "lifepreserver" : "exclamationmark.triangle")
                        .font(.lifeboard(.display))
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.lifeboard(.title3).weight(.bold))
                        .foregroundStyle(Color.lifeboard.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showsProgress {
                    ProgressView()
                        .tint(Color.lifeboard.accentPrimary)
                        .accessibilityLabel("Preparing rescue")
                } else if primaryTitle != nil || secondaryTitle != nil {
                    HStack(spacing: 12) {
                        if let secondaryTitle, let onSecondary {
                            rescueButton(title: secondaryTitle, filled: false, action: onSecondary)
                        }
                        if let primaryTitle, let onPrimary {
                            rescueButton(title: primaryTitle, filled: true, action: onPrimary)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.lifeboard(.surfacePrimary).opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.lifeboard(.borderSubtle), lineWidth: 1)
                    )
                    .lbShadow(ShadowTokens.rescueLauncher)
            )
            .padding(.horizontal, 28)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(title)
            .accessibilityHint(message)
        }
    }

    private func rescueButton(title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(filled ? Color.lifeboard(.accentOnPrimary) : Color.lifeboard.accentPrimary)
                .frame(minWidth: filled ? 112 : 96, minHeight: 44)
                .padding(.horizontal, filled ? 14 : 12)
                .background {
                    if filled {
                        Capsule().fill(Color.lifeboard.accentPrimary)
                    } else {
                        Capsule().stroke(Color.lifeboard.accentPrimary.opacity(0.35), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OverdueRescueBackground

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                OverdueRescuePalette.backgroundTop,
                OverdueRescuePalette.backgroundMid,
                OverdueRescuePalette.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - OverdueRescueCompletionView

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueCompletionView: View {
    let summary: OverdueRescueSummary
    let remaining: Int
    let bottomInset: CGFloat
    let viewToday: () -> Void
    let reviewRemaining: () -> Void
    /// The launch origin that produced this completion view. When the
    /// day-rescue deck was launched today with no replan candidates, the
    /// empty-at-launch copy differs from a user-driven clean-up.
    var launchOrigin: OverdueRescueLaunchContext.Origin = .home
    /// True when the deck transitioned straight to `.completed` because it
    /// was empty at launch (no candidates were ever acted on).
    var startedEmpty: Bool = false

    private var isDayRescueEmpty: Bool {
        launchOrigin == .universalInputDayRescue && startedEmpty
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 25) {
                HStack {
                    Button("Close", systemImage: "xmark", action: viewToday)
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(OverdueRescuePalette.ink)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(OverdueRescuePalette.glassFill))
                        .shadow(color: OverdueRescuePalette.softShadow.opacity(0.7), radius: 14, y: 8)
                    Spacer()
                    Button("More", systemImage: "ellipsis") {}
                        .labelStyle(.iconOnly)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(OverdueRescuePalette.ink)
                        .frame(width: 58, height: 58)
                        .background(Circle().fill(OverdueRescuePalette.glassFill))
                        .shadow(color: OverdueRescuePalette.softShadow.opacity(0.7), radius: 14, y: 8)
                }
                .padding(.horizontal, 28)
                .padding(.top, 32)

                OverdueRescueSunriseHero()
                    .frame(width: 294, height: 256)
                    .padding(.top, 6)
                Text(isDayRescueEmpty ? "Nothing needs rescuing today" : "Board cleaned up")
                    .font(.lifeboard(.title1))
                    .fontWeight(.bold)
                    .foregroundStyle(OverdueRescuePalette.ink)
                Text(isDayRescueEmpty ? "Your day is already in good shape." : "You sorted what still matters.")
                    .font(.lifeboard(.title3))
                    .foregroundStyle(OverdueRescuePalette.secondaryInk)

                if isDayRescueEmpty == false {
                    HStack(spacing: 14) {
                        statCard(icon: "checkmark.circle", value: summary.kept, label: "kept", color: Color.lifeboard.statusSuccess)
                        statCard(icon: "clock", value: summary.moved, label: "moved later", color: Color.lifeboard.statusWarning)
                        statCard(icon: "trash", value: summary.deleted, label: "deleted", color: Color.lifeboard.statusDanger)
                    }
                    .padding(.horizontal, 28)
                }

                Text(isDayRescueEmpty ? "You're all caught up for the day." : "Your board should feel lighter now.")
                    .font(.lifeboard(.body))
                    .foregroundStyle(OverdueRescuePalette.secondaryInk)

                Button("View today", action: viewToday)
                    .font(.lifeboard(.button))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                    .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.primaryButtonHeight)
                    .background(OverdueRescueVisualSpec.primaryButtonBackground())
                    .padding(.horizontal, 42)
                    .accessibilityIdentifier("home.rescue.completion.viewToday")

                if remaining > 0 {
                    Button("Review remaining", systemImage: "list.bullet", action: reviewRemaining)
                        .font(.lifeboard(.button))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .frame(maxWidth: .infinity, minHeight: OverdueRescueVisualSpec.secondaryButtonHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.lifeboard.accentPrimary.opacity(0.32), lineWidth: 1.2)
                        )
                        .padding(.horizontal, 42)
                }

                Color.clear.frame(height: max(28, bottomInset))
            }
            .frame(maxWidth: OverdueRescueVisualSpec.sheetMaxWidth)
            .frame(maxWidth: .infinity)
        }
    }

    func statCard(icon: String, value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title.weight(.semibold))
            Text("\(value)")
                .font(.lifeboard(.title2))
                .fontWeight(.bold)
            Text(label)
                .font(.lifeboard(.caption1))
                .fontWeight(.semibold)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, minHeight: 126)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(color.opacity(0.065))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(color.opacity(0.10), lineWidth: 1)
                )
                .lbShadow(ShadowTokens.rescueCompletionTile)
        )
    }
}

// MARK: - OverdueRescueErrorView

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct OverdueRescueErrorView: View {
    let message: String
    let retry: () -> Void
    let close: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .lifeboardFont(.heroDisplay)
                .foregroundStyle(Color.lifeboard.statusWarning)
            Text("Rescue paused")
                .font(.lifeboard(.title2))
                .fontWeight(.bold)
                .foregroundStyle(Color.lifeboard.textPrimary)
            Text(message)
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again", action: retry)
                .buttonStyle(.borderedProminent)
            Button("Close", action: close)
            Spacer()
        }
        .padding(28)
    }
}

// MARK: - ProgressBar

//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//


struct ProgressBar: View {
    let progress: Double
    let colors: [Color]
    var trackColor: Color = Color.lifeboard.surfaceSecondary
    var height: CGFloat = 6
    var animate: Bool = true

    var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(trackColor)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(x: clampedProgress, y: 1, anchor: .leading)
                    .animation(animate ? LifeBoardAnimation.stateChange : .linear(duration: 0.01), value: clampedProgress)
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent")
    }
}
