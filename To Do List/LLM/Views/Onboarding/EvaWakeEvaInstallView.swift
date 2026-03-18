import MLXLMCommon
import SwiftUI

struct EvaWakeEvaInstallView: View {
    private enum InstallOutcome: Equatable {
        case installing
        case success
    }

    @EnvironmentObject private var appManager: AppManager
    @Environment(LLMEvaluator.self) private var llm
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let model: ModelConfiguration
    let selectionTitle: String
    let onChooseAnotherModel: () -> Void
    let onInstallComplete: (EvaActivationInstallResult) -> Void

    @State private var hasStarted = false
    @State private var isInstallInFlight = false
    @State private var installSucceeded = false
    @State private var autoAdvanceTriggered = false
    @State private var statusIndex = 0
    @State private var statusTask: Task<Void, Never>?
    @State private var currentModelName: String
    @State private var currentSelectionTitle: String
    @State private var selectedModelRetryCount = 0
    @State private var attemptedFastFallback = false
    @State private var displayedProgress = 0.0
    @State private var progressSamples: [EvaActivationInstallSample] = []
    @State private var etaState: EvaActivationInstallETAState = .calculating

    init(
        model: ModelConfiguration,
        selectionTitle: String,
        onChooseAnotherModel: @escaping () -> Void,
        onInstallComplete: @escaping (EvaActivationInstallResult) -> Void
    ) {
        self.model = model
        self.selectionTitle = selectionTitle
        self.onChooseAnotherModel = onChooseAnotherModel
        self.onInstallComplete = onInstallComplete
        _currentModelName = State(initialValue: model.name)
        _currentSelectionTitle = State(initialValue: selectionTitle)
    }

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var installOutcome: InstallOutcome {
        installSucceeded ? .success : .installing
    }

    private var currentModel: ModelConfiguration? {
        ModelConfiguration.getModelByName(currentModelName)
    }

    private var statusMessages: [String] {
        switch currentSelectionTitle {
        case "Smarter":
            return [
                "Preparing deeper planning support…",
                "Getting ready to prioritize with you…",
                "Setting up private on-device responses…",
                "Finalizing your setup…"
            ]
        default:
            return [
                "Preparing fast daily help…",
                "Getting ready to prioritize with you…",
                "Preparing your planning workspace…",
                "Finalizing your setup…"
            ]
        }
    }

    private var titleText: String {
        installSucceeded ? "Eva is ready" : "Getting Eva ready"
    }

    private var statusText: String {
        if installSucceeded {
            return "Opening your first win…"
        }
        return statusMessages[min(statusIndex, max(statusMessages.count - 1, 0))]
    }

    private var installPresentation: EvaActivationInstallPresentation {
        EvaActivationInstallPresentation(
            modeTitle: currentSelectionTitle,
            statusText: statusText,
            progress: displayedProgress,
            percentComplete: Int((displayedProgress * 100).rounded()),
            etaState: installSucceeded ? .ready(secondsRemaining: 1) : etaState,
            transferText: installSucceeded
                ? nil
                : EvaActivationInstallEstimator.transferText(
                    for: currentModel?.modelSize,
                    progress: displayedProgress
                )
        )
    }

    var body: some View {
        EvaActivationStageView(
            footer: {
                if installSucceeded {
                    EvaFooterButtons(
                        primaryTitle: "Open chat",
                        secondaryTitle: "Choose another mode",
                        isPrimaryDisabled: false,
                        onPrimary: {
                            onInstallComplete(
                                .success(
                                    preparedModelName: currentModelName,
                                    selectedModelRetryCount: selectedModelRetryCount,
                                    attemptedFastFallback: attemptedFastFallback
                                )
                            )
                        },
                        onSecondary: onChooseAnotherModel
                    )
                }
            }
        ) {
            VStack(alignment: .leading, spacing: spacing.sectionGap) {
                EvaContentHeader(
                    title: "Getting Eva ready",
                    bodyText: "Preparing a private on-device mode for your first planning session."
                )
                .enhancedStaggeredAppearance(index: 0)

                if layoutClass.isPad {
                    HStack(alignment: .center, spacing: spacing.sectionGap) {
                        installModule
                            .frame(maxWidth: 520)
                        Spacer(minLength: spacing.sectionGap)
                    }
                } else {
                    installModule
                }
            }
        }
        .task {
            guard hasStarted == false else { return }
            await performInstallFlow()
        }
        .onDisappear {
            statusTask?.cancel()
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
        #if os(iOS)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        #endif
        .onChange(of: llm.progress) { _, newValue in
            updateProgressPresentation(for: newValue)
        }
        .onChange(of: installOutcome) { _, outcome in
            guard outcome == .success, autoAdvanceTriggered == false else { return }
            autoAdvanceTriggered = true
            Task {
                try? await Task.sleep(nanoseconds: 900_000_000)
                guard installSucceeded else { return }
                onInstallComplete(
                    .success(
                        preparedModelName: currentModelName,
                        selectedModelRetryCount: selectedModelRetryCount,
                        attemptedFastFallback: attemptedFastFallback
                    )
                )
            }
        }
        .accessibilityIdentifier("eva.activation.download")
    }

    private var installModule: some View {
        VStack(alignment: .leading, spacing: spacing.s20) {
            VStack(spacing: spacing.s16) {
                EvaInstallHeroTile(isComplete: installSucceeded, progress: installPresentation.progress)
                    .frame(maxWidth: .infinity)

                VStack(spacing: spacing.s8) {
                    Text(titleText)
                        .font(.tasker(.title1).weight(.bold))
                        .foregroundStyle(Color.tasker(.textPrimary))

                    Text(installPresentation.statusText)
                        .font(.tasker(.callout))
                        .foregroundStyle(Color.tasker(.textSecondary))
                        .multilineTextAlignment(.center)
                        .id(installPresentation.statusText)
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))

                    Text("Installing \(installPresentation.modeTitle)")
                        .font(.tasker(.caption1).weight(.semibold))
                        .foregroundStyle(Color.tasker(.accentPrimary))
                }
                .animation(reduceMotion ? nil : TaskerAnimation.quick, value: installPresentation.statusText)
                .frame(maxWidth: .infinity)
            }
            .enhancedStaggeredAppearance(index: 1)

            VStack(alignment: .leading, spacing: spacing.s12) {
                EvaInstallProgressCard(
                    title: "Install progress",
                    progress: installPresentation.progress,
                    subtitle: installPresentation.progressText
                )

                HStack(alignment: .center, spacing: spacing.s12) {
                    Text(installPresentation.progressText)
                    Spacer()
                    Text(installSucceeded ? "Ready" : installPresentation.etaText)
                }
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
                .monospacedDigit()

                if let transferText = installPresentation.transferText {
                    Text(transferText)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textTertiary))
                        .monospacedDigit()
                }
            }
            .enhancedStaggeredAppearance(index: 2)

            Text("Keep this screen open while Eva finishes getting ready.")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
                .frame(maxWidth: .infinity, alignment: layoutClass.isPad ? .leading : .center)
                .multilineTextAlignment(layoutClass.isPad ? .leading : .center)
                .enhancedStaggeredAppearance(index: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performInstallFlow() async {
        guard isInstallInFlight == false else { return }
        hasStarted = true
        isInstallInFlight = true
        installSucceeded = false
        autoAdvanceTriggered = false
        llm.progress = 0
        displayedProgress = 0
        progressSamples.removeAll()
        etaState = .calculating

        defer {
            isInstallInFlight = false
            statusTask?.cancel()
            statusTask = nil
        }

        currentModelName = model.name
        currentSelectionTitle = selectionTitle
        selectedModelRetryCount = 0
        attemptedFastFallback = false
        startCyclingStatuses()

        if await attemptInstall(modelName: model.name, title: selectionTitle) {
            return
        }

        if model.name == ModelConfiguration.qwen_3_5_0_8b_optiq_4bit.name {
            selectedModelRetryCount = 1
            if await attemptInstall(modelName: model.name, title: selectionTitle) {
                return
            }

            attemptedFastFallback = true
            let fastModelName = ModelConfiguration.qwen_3_0_6b_4bit.name
            if await attemptInstall(modelName: fastModelName, title: "Fast") {
                return
            }

            onInstallComplete(
                .failed(
                    failedModelName: fastModelName,
                    selectedModelRetryCount: selectedModelRetryCount,
                    attemptedFastFallback: attemptedFastFallback
                )
            )
            return
        }

        onInstallComplete(
            .failed(
                failedModelName: model.name,
                selectedModelRetryCount: selectedModelRetryCount,
                attemptedFastFallback: attemptedFastFallback
            )
        )
    }

    private func attemptInstall(modelName: String, title: String) async -> Bool {
        guard let workingModel = ModelConfiguration.getModelByName(modelName) else {
            return false
        }

        await MainActor.run {
            currentModelName = modelName
            currentSelectionTitle = title
            llm.progress = 0
            displayedProgress = 0
            progressSamples.removeAll()
            etaState = .calculating
            statusIndex = 0
        }

        let switched = await LLMRuntimeCoordinator.shared.switchModelIfNeeded(modelName: workingModel.name)
        guard switched else { return false }

        await MainActor.run {
            appManager.addInstalledModel(workingModel.name)
            appManager.setActiveModel(workingModel.name)
            installSucceeded = true
            displayedProgress = 1
            etaState = .ready(secondsRemaining: 1)
        }
        return true
    }

    private func updateProgressPresentation(for rawProgress: Double) {
        let clampedProgress = max(0, min(rawProgress, 1))

        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : TaskerAnimation.quick) {
            displayedProgress = clampedProgress
        }

        let now = Date().timeIntervalSinceReferenceDate
        let shouldAppendSample: Bool
        if let lastSample = progressSamples.last {
            shouldAppendSample = (now - lastSample.timestamp) >= 0.45 || abs(clampedProgress - lastSample.progress) >= 0.02
        } else {
            shouldAppendSample = true
        }

        if shouldAppendSample {
            progressSamples.append(
                EvaActivationInstallSample(
                    timestamp: now,
                    progress: clampedProgress
                )
            )
            progressSamples = Array(progressSamples.suffix(6))
        }

        etaState = EvaActivationInstallEstimator.etaState(
            for: progressSamples,
            latestProgress: clampedProgress
        )
    }

    private func startCyclingStatuses() {
        statusTask?.cancel()
        statusIndex = 0
        statusTask = Task {
            while !Task.isCancelled && installSucceeded == false {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : TaskerAnimation.quick) {
                        statusIndex = (statusIndex + 1) % max(statusMessages.count, 1)
                    }
                }
            }
        }
    }
}

struct EvaActivationRecoveryView: View {
    let failedModelTitle: String
    let onRetry: () -> Void
    let onSwitchToFast: () -> Void
    let onOpenModels: () -> Void

    var body: some View {
        EvaActivationStageView(
            footer: { EmptyView() }
        ) {
            VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xl) {
                EvaContentHeader(
                    title: "Eva couldn’t finish getting ready",
                    bodyText: "The selected mode did not prepare correctly. Try again, or switch to Fast for a lighter setup."
                )
                .enhancedStaggeredAppearance(index: 0)

                EvaRecoveryCard(
                    title: "Recovery options",
                    bodyText: "Retry the same setup, switch to Fast, or return to model selection.",
                    footerText: "Your setup and saved memory are still intact.",
                    primaryTitle: "Retry",
                    secondaryTitle: "Switch to Fast",
                    tertiaryTitle: "Open Models",
                    onPrimary: onRetry,
                    onSecondary: onSwitchToFast,
                    onTertiary: onOpenModels
                )
                .enhancedStaggeredAppearance(index: 1)

                Text("Last attempted mode: \(failedModelTitle)")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .enhancedStaggeredAppearance(index: 2)
            }
        }
        .accessibilityIdentifier("eva.activation.recovery")
    }
}

struct EvaActivationStageView<Content: View, Footer: View>: View {
    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let showsAmbientBackground: Bool
    let footer: () -> Footer
    let content: () -> Content

    init(
        showsAmbientBackground: Bool = true,
        @ViewBuilder footer: @escaping () -> Footer,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showsAmbientBackground = showsAmbientBackground
        self.footer = footer
        self.content = content
    }

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    private var horizontalPadding: CGFloat {
        layoutClass.isPad ? max(spacing.screenHorizontal, 32) : spacing.screenHorizontal
    }

    var body: some View {
        ZStack {
            Color.tasker(.bgCanvas)
                .ignoresSafeArea()

            if showsAmbientBackground {
                LinearGradient(
                    colors: [
                        Color.tasker(.bgCanvas),
                        Color.tasker(.accentWash).opacity(layoutClass.isPad ? 0.12 : 0.08),
                        Color.tasker(.bgCanvas)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: spacing.sectionGap) {
                    content()
                }
                .frame(maxWidth: layoutClass.isPad ? 1080 : .infinity, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, spacing.s4)
                .padding(.bottom, footerIsEmpty ? spacing.s24 : 144)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if footerIsEmpty == false {
                VStack(spacing: 0) {
                    footer()
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s12)
                .padding(.bottom, spacing.s12)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.tasker(.surfacePrimary).opacity(0.001))
                        .taskerChromeSurface(
                            cornerRadius: 28,
                            accentColor: Color.tasker(.accentSecondary),
                            level: .e2
                        )
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s8)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : TaskerAnimation.gentle, value: footerIsEmpty)
    }

    private var footerIsEmpty: Bool {
        Footer.self == EmptyView.self
    }
}

struct EvaFooterButtons: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let primaryTitle: String
    let secondaryTitle: String
    let isPrimaryDisabled: Bool
    let onPrimary: () -> Void
    let onSecondary: () -> Void

    var body: some View {
        VStack(spacing: TaskerTheme.Spacing.sm) {
            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(.tasker(.button))
                    .foregroundStyle(isPrimaryDisabled ? Color.tasker(.textSecondary) : Color.tasker(.accentOnPrimary))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isPrimaryDisabled ? Color.tasker(.surfaceTertiary) : Color.tasker(.accentPrimary))
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous))
                    .opacity(isPrimaryDisabled ? 0.72 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isPrimaryDisabled)
            .taskerPressFeedback(reduceMotion: reduceMotion)
            .animation(reduceMotion ? nil : TaskerAnimation.quick, value: isPrimaryDisabled)

            Button(action: onSecondary) {
                Text(secondaryTitle)
                    .font(.tasker(.button))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.tasker(.surfaceSecondary))
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.pill, style: .continuous)
                            .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .taskerPressFeedback(reduceMotion: reduceMotion)
        }
    }
}

private struct EvaInstallHeroTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isComplete: Bool
    let progress: Double

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.tasker(.surfacePrimary),
                            Color.tasker(.accentWash).opacity(0.78),
                            Color.tasker(.surfacePrimary)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.tasker(.strokeHairline), lineWidth: 1)
                )

            VStack(spacing: TaskerTheme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(Color.tasker(.bgCanvas).opacity(0.78))
                        .frame(width: 92, height: 92)
                        .overlay(
                            Circle()
                                .stroke(Color.tasker(.accentMuted).opacity(0.34), lineWidth: 1)
                        )
                        .shadow(color: Color.tasker(.accentPrimary).opacity(0.12), radius: 16, y: 8)

                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(Color.tasker(.statusSuccess))
                    } else {
                        EvaLoopingLottieContainer(size: 72)
                    }
                }
                    .breathingPulse(min: reduceMotion ? 1 : 0.84, max: 1, duration: 2.3)

                Text(isComplete ? "Ready" : "Private mode")
                    .font(.tasker(.caption1).weight(.semibold))
                    .foregroundStyle(Color.tasker(.accentPrimary))
            }
        }
        .frame(width: 168, height: 168)
        .shadow(color: Color.tasker(.accentPrimary).opacity(0.10), radius: 18, y: 10)
    }
}
