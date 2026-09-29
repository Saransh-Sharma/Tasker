import SwiftUI

private struct FocusTaskSyncSignature: Equatable {
    let id: UUID
    let isComplete: Bool

    init(_ task: TaskDefinition) {
        id = task.id
        isComplete = task.isComplete
    }
}

struct EvaFocusWhySheet: View {
    let focusTasks: [TaskDefinition]
    let shuffleCandidates: [TaskDefinition]
    let insightProvider: (UUID) -> EvaFocusTaskInsight?
    let isStartingFocus: Bool
    let onToggleComplete: (TaskDefinition) -> Void
    let onStartFocus: ([TaskDefinition], TaskDefinition, Int) -> Void
    let onShuffleCandidates: () -> Void
    let onReplaceFocusTask: (TaskDefinition, TaskDefinition) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lifeboardTokens) private var tokens
    @State private var draftState = FocusNowDraftState()
    @State private var detailTask: TaskDefinition?
    @State private var timerTask: TaskDefinition?
    @State private var replacementCandidate: TaskDefinition?
    @State private var selectedDurationSeconds: Int = FocusDurationStore.lastUsedDurationSeconds()
    @State private var toastMessage: String?
    @State private var showDiscardConfirmation = false
    @State private var showRefineSheet = false

    private var spacing: SemanticSpacingTokens { ThemeStore.shared.currentTheme.tokens.spacing }
    private var activeTask: TaskDefinition? { draftState.activeTask }
    private var hasDraftChanges: Bool { draftState.hasUnsavedChanges(comparedTo: focusTasks) }

    var body: some View {
        rootScreen
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onAppear(perform: syncInitialState)
            .onChange(of: focusTasks.map(FocusTaskSyncSignature.init)) { _, _ in
                guard hasDraftChanges == false else { return }
                syncDraftFocusTasks(focusTasks)
            }
            .onChange(of: shuffleCandidates.map(\.id)) { _, _ in
                syncCandidates(shuffleCandidates)
            }
            .onChange(of: isStartingFocus) { _, newValue in
                draftState.isStartingFocus = newValue
            }
            .sheet(item: $detailTask, content: detailSheet)
            .sheet(item: $timerTask, content: durationSheet)
            .sheet(isPresented: $showRefineSheet, content: refineSheet)
            .confirmationDialog(
                "Replace which task?",
                isPresented: Binding(
                    get: { replacementCandidate != nil },
                    set: { if !$0 { replacementCandidate = nil } }
                ),
                titleVisibility: .visible,
                actions: replacementDialogActions
            )
            .confirmationDialog(
                "Discard focus changes?",
                isPresented: $showDiscardConfirmation,
                titleVisibility: .visible,
                actions: {
                    Button("Discard", role: .destructive) {
                        dismiss()
                    }
                    Button("Keep editing", role: .cancel) {}
                },
                message: {
                    Text("Changes to this set will be lost.")
                }
            )
    }

    private var rootScreen: some View {
        NavigationStack {
            ZStack {
                EvaClayStyle.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        FocusNowHeader(
                            selectedCount: draftState.draftFocusTasks.count,
                            onClose: attemptClose
                        )

                        if draftState.draftFocusTasks.isEmpty {
                            FocusNowEmptyState()
                        } else {
                            FocusCardDeck(
                                tasks: draftState.draftFocusTasks,
                                activeTaskID: draftState.activeFocusTaskID ?? draftState.draftFocusTasks.first?.id,
                                flippedTaskID: draftState.flippedFocusTaskID,
                                selectedCardForSwapID: draftState.selectedCardForSwapID,
                                assignedHeroImagesByTaskID: draftState.assignedHeroImagesByTaskID,
                                insightProvider: insightProvider,
                                reduceMotion: reduceMotion,
                                onCardTap: handleCardTap,
                                onFlipBack: { draftState.flippedFocusTaskID = nil },
                                onQuickSwap: quickSwap,
                                onViewDetails: { detailTask = $0 },
                                onStartTimer: presentDurationPicker
                            )
                            .accessibilityIdentifier("focusNow.deck")

                            FocusModeSegmentedControl(selectedMode: $draftState.selectedMode)

                            CandidateSection(
                                candidates: draftState.candidateTasks,
                                selectedMode: draftState.selectedMode,
                                isShuffling: draftState.isShuffling,
                                insightProvider: insightProvider,
                                onCandidateTap: handleCandidateTap,
                                onSwapTap: handleCandidateTap
                            )
                        }

                        ShuffleAgainCard(
                            isShuffling: draftState.isShuffling,
                            isDisabled: draftState.isShuffling,
                            onShuffle: shuffleAgain
                        )

                        FocusBottomActions(
                            canStart: activeTask != nil,
                            isStarting: draftState.isStartingFocus,
                            onStartFocus: {
                                guard let activeTask else { return }
                                presentDurationPicker(for: activeTask)
                            },
                            onRefineSet: {
                                draftState.flippedFocusTaskID = nil
                                showRefineSheet = true
                            }
                        )

                        if let toastMessage {
                            Button {
                                if draftState.undoState != nil {
                                    undoLastChange()
                                }
                            } label: {
                                Text(toastMessage)
                                    .font(.lifeboard(.caption1).weight(.semibold))
                                    .foregroundStyle(ClayColorTokens.navyMuted)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(EvaClayStyle.cream, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(draftState.undoState == nil)
                            .transition(.opacity)
                            .accessibilityIdentifier("focusNow.toast")
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, spacing.s16)
                .padding(.top, 8)
                .padding(.bottom, spacing.s24)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("focusNow.detail.sheet")
    }

    private func detailSheet(for task: TaskDefinition) -> some View {
        FocusTaskDetailSheet(
            task: task,
            insight: insightProvider(task.id),
            onStartTimer: {
                detailTask = nil
                presentDurationPicker(for: task)
            },
            onSwapTask: {
                detailTask = nil
                quickSwap(task)
            }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func refineSheet() -> some View {
        RefineFocusSheet(
            selectedTasks: draftState.draftFocusTasks,
            candidateTasks: draftState.candidateTasks,
            insightProvider: insightProvider,
            onApply: { refinedTasks in
                draftState.applyRefinedTasks(refinedTasks)
                showRefineSheet = false
                showToast(String(localized: "Set updated · Undo"))
            }
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func durationSheet(for task: TaskDefinition) -> some View {
        FocusDurationPickerSheet(
            task: task,
            selectedDurationSeconds: $selectedDurationSeconds,
            isStarting: draftState.isStartingFocus,
            onStart: { duration in
                FocusDurationStore.saveLastUsedDurationSeconds(duration)
                draftState.pendingTimerDuration = duration
                timerTask = nil
                onStartFocus(draftState.draftFocusTasks, task, duration)
            }
        )
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func replacementDialogActions() -> some View {
        if let replacementCandidate {
            ForEach(draftState.draftFocusTasks, id: \.id) { focusTask in
                Button(focusTask.title) {
                    replace(focusTask, with: replacementCandidate)
                    self.replacementCandidate = nil
                }
            }
        }
        Button("Cancel", role: .cancel) {
            replacementCandidate = nil
        }
    }

    private func syncInitialState() {
        syncDraftFocusTasks(focusTasks)
        syncCandidates(shuffleCandidates)
        draftState.isStartingFocus = isStartingFocus
    }

    private func syncDraftFocusTasks(_ tasks: [TaskDefinition]) {
        draftState.syncFocusTasks(tasks)
    }

    private func syncCandidates(_ tasks: [TaskDefinition]) {
        draftState.syncCandidates(tasks)
    }

    private func handleCardTap(_ task: TaskDefinition) {
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            draftState.selectAndFlip(task)
        }
    }

    private func quickSwap(_ task: TaskDefinition) {
        guard draftState.quickSwap(task) else {
            showToast(String(localized: "No other tasks"))
            return
        }
        showToast(String(localized: "Task swapped · Undo"))
    }

    private func handleCandidateTap(_ candidate: TaskDefinition) {
        guard let target = draftState.selectedTaskForSwap else {
            replacementCandidate = candidate
            return
        }
        replace(target, with: candidate)
        showToast(String(localized: "Task swapped · Undo"))
    }

    private func replace(_ oldTask: TaskDefinition, with newTask: TaskDefinition) {
        draftState.replace(oldTask, with: newTask)
    }

    private func presentDurationPicker(for task: TaskDefinition) {
        draftState.flippedFocusTaskID = nil
        selectedDurationSeconds = FocusDurationStore.defaultDurationSeconds(for: task)
        draftState.pendingTimerDuration = selectedDurationSeconds
        timerTask = task
    }

    private func shuffleAgain() {
        withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
            draftState.beginShuffle()
        }
        onShuffleCandidates()
        showToast(String(localized: "Shuffled"))
        _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(nanoseconds: 420_000_000)
            draftState.endShuffle()
        }
    }

    private func showToast(_ message: String) {
        withAnimation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion)) {
            toastMessage = message
        }
    }

    private func undoLastChange() {
        draftState.undoLastChange()
        showToast(String(localized: "Set restored"))
    }

    private func attemptClose() {
        if hasDraftChanges {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }
}

enum FocusNowMode: String, CaseIterable, Identifiable {
    case currentSet
    case shuffleView

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentSet: return String(localized: "Current set")
        case .shuffleView: return String(localized: "Shuffle view")
        }
    }

    var systemImage: String {
        switch self {
        case .currentSet: return "list.bullet"
        case .shuffleView: return "sparkles"
        }
    }
}

struct FocusUndoState {
    let tasks: [TaskDefinition]
    let candidates: [TaskDefinition]
    let assignedHeroImagesByTaskID: [UUID: TaskHeroImage]
    let activeFocusTaskID: UUID?
    let selectedCardForSwapID: UUID?
}

struct FocusNowDraftState {
    var draftFocusTasks: [TaskDefinition] = []
    var candidateTasks: [TaskDefinition] = []
    var activeFocusTaskID: UUID?
    var flippedFocusTaskID: UUID?
    var selectedCardForSwapID: UUID?
    var selectedMode: FocusNowMode = .currentSet
    var assignedHeroImagesByTaskID: [UUID: TaskHeroImage] = [:]
    var originalFocusTaskIDs: [UUID] = []
    var pendingTimerDuration: Int?
    var undoState: FocusUndoState?
    var isShuffling = false
    var isStartingFocus = false

    var activeTask: TaskDefinition? {
        if let activeFocusTaskID, let active = draftFocusTasks.first(where: { $0.id == activeFocusTaskID }) {
            return active
        }
        return draftFocusTasks.first
    }

    var selectedTaskForSwap: TaskDefinition? {
        guard let selectedCardForSwapID else { return nil }
        return draftFocusTasks.first(where: { $0.id == selectedCardForSwapID })
    }

    mutating func syncFocusTasks(_ tasks: [TaskDefinition]) {
        draftFocusTasks = Array(tasks.filter { !$0.isComplete }.prefix(3))
        originalFocusTaskIDs = draftFocusTasks.map(\.id)
        activeFocusTaskID = draftFocusTasks.first?.id
        selectedCardForSwapID = nil
        flippedFocusTaskID = nil
        assignHeroImages()
    }

    mutating func syncCandidates(_ tasks: [TaskDefinition]) {
        let selectedIDs = Set(draftFocusTasks.map(\.id))
        candidateTasks = Array(tasks.filter { !selectedIDs.contains($0.id) }.prefix(6))
    }

    func hasUnsavedChanges(comparedTo tasks: [TaskDefinition]) -> Bool {
        draftFocusTasks.map(\.id) != Array(tasks.filter { !$0.isComplete }.prefix(3)).map(\.id)
    }

    mutating func selectAndFlip(_ task: TaskDefinition) {
        moveTaskToFront(task)
        activeFocusTaskID = task.id
        selectedCardForSwapID = task.id
        flippedFocusTaskID = flippedFocusTaskID == task.id ? nil : task.id
    }

    mutating func quickSwap(_ task: TaskDefinition) -> Bool {
        guard let candidate = candidateTasks.first else { return false }
        replace(task, with: candidate)
        return true
    }

    mutating func replace(_ oldTask: TaskDefinition, with newTask: TaskDefinition) {
        guard let index = draftFocusTasks.firstIndex(where: { $0.id == oldTask.id }) else { return }
        saveUndoState()
        draftFocusTasks[index] = newTask
        draftFocusTasks = deduplicatedTopThree(draftFocusTasks)
        activeFocusTaskID = newTask.id
        selectedCardForSwapID = newTask.id
        flippedFocusTaskID = nil
        candidateTasks.removeAll { $0.id == newTask.id }
        if !candidateTasks.contains(where: { $0.id == oldTask.id }) {
            candidateTasks.insert(oldTask, at: 0)
        }
        assignedHeroImagesByTaskID[newTask.id] = nil
        assignHeroImages()
    }

    mutating func applyRefinedTasks(_ tasks: [TaskDefinition]) {
        saveUndoState()
        let previousDraft = draftFocusTasks
        draftFocusTasks = deduplicatedTopThree(tasks)
        activeFocusTaskID = draftFocusTasks.first?.id
        selectedCardForSwapID = draftFocusTasks.first?.id
        flippedFocusTaskID = nil
        let selectedIDs = Set(draftFocusTasks.map(\.id))
        let returnedCandidates = previousDraft.filter { !selectedIDs.contains($0.id) }
        candidateTasks = Array((candidateTasks + returnedCandidates).filter { !selectedIDs.contains($0.id) }.prefix(6))
        assignHeroImages()
    }

    mutating func beginShuffle() {
        flippedFocusTaskID = nil
        isShuffling = true
    }

    mutating func endShuffle() {
        isShuffling = false
    }

    mutating func undoLastChange() {
        guard let undoState else { return }
        draftFocusTasks = undoState.tasks
        candidateTasks = undoState.candidates
        assignedHeroImagesByTaskID = undoState.assignedHeroImagesByTaskID
        activeFocusTaskID = undoState.activeFocusTaskID ?? draftFocusTasks.first?.id
        selectedCardForSwapID = undoState.selectedCardForSwapID
        flippedFocusTaskID = nil
        self.undoState = nil
        assignHeroImages()
    }

    mutating func assignHeroImages() {
        var resolver = TaskHeroImageResolver(existingAssignments: assignedHeroImagesByTaskID)
        assignedHeroImagesByTaskID = resolver.assignImages(for: draftFocusTasks)
    }

    private mutating func moveTaskToFront(_ task: TaskDefinition) {
        guard let index = draftFocusTasks.firstIndex(where: { $0.id == task.id }), index > 0 else { return }
        draftFocusTasks.remove(at: index)
        draftFocusTasks.insert(task, at: 0)
        assignHeroImages()
    }

    private mutating func saveUndoState() {
        undoState = FocusUndoState(
            tasks: draftFocusTasks,
            candidates: candidateTasks,
            assignedHeroImagesByTaskID: assignedHeroImagesByTaskID,
            activeFocusTaskID: activeFocusTaskID,
            selectedCardForSwapID: selectedCardForSwapID
        )
    }
}

func deduplicatedTopThree(_ tasks: [TaskDefinition]) -> [TaskDefinition] {
    var seen = Set<UUID>()
    var unique: [TaskDefinition] = []
    for task in tasks where seen.insert(task.id).inserted {
        unique.append(task)
    }
    return Array(unique.prefix(3))
}

struct FocusNowHeader: View {
    let selectedCount: Int
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("Back", systemImage: "chevron.left", action: onClose)
                    .labelStyle(.iconOnly)
                    .font(.lifeboard(.caption1).weight(.bold))
                    .foregroundStyle(ClayColorTokens.navy)
                    .frame(width: 44, height: 44)
                    .background(EvaClayStyle.cream, in: Circle())
                    .lbShadow(ShadowTokens.card)
                    .accessibilityIdentifier("focusNow.back")

                Spacer()
            }

            Text("Focus Now")
                .font(.lifeboard(.title1).weight(.bold))
                .foregroundStyle(ClayColorTokens.navy)
                .multilineTextAlignment(.center)
                .padding(.top, -4)

            SelectedCountPill(count: selectedCount)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus Now, \(selectedCount) selected")
    }
}

struct SelectedCountPill: View {
    let count: Int

    var body: some View {
        Label("^[\(count) task](inflect: true) selected", systemImage: "checkmark.circle.fill")
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(ClayColorTokens.navySoft)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(EvaClayStyle.cream, in: Capsule())
            .overlay {
                Capsule().stroke(EvaClayStyle.peachBorder.opacity(0.72), lineWidth: 1)
            }
            .lbShadow(ShadowTokens.card)
    }
}

struct FocusNowEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ClayLayoutMetrics.sm) {
            Text("No tasks selected")
                .font(.lifeboard(.headline))
                .foregroundStyle(ClayColorTokens.navy)
            Text("Shuffle for suggestions.")
                .font(.lifeboard(.callout))
                .foregroundStyle(ClayColorTokens.navyMuted)
        }
        .padding(ClayLayoutMetrics.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EvaClayStyle.cream, in: RoundedRectangle(cornerRadius: 24))
        .accessibilityIdentifier("focusNow.empty")
    }
}

struct FocusCardDeck: View {
    let tasks: [TaskDefinition]
    let activeTaskID: UUID?
    let flippedTaskID: UUID?
    let selectedCardForSwapID: UUID?
    let assignedHeroImagesByTaskID: [UUID: TaskHeroImage]
    let insightProvider: (UUID) -> EvaFocusTaskInsight?
    let reduceMotion: Bool
    let onCardTap: (TaskDefinition) -> Void
    let onFlipBack: () -> Void
    let onQuickSwap: (TaskDefinition) -> Void
    let onViewDetails: (TaskDefinition) -> Void
    let onStartTimer: (TaskDefinition) -> Void

    var body: some View {
        GeometryReader { proxy in
            let visibleTasks = Array(tasks.prefix(3))
            let availableWidth = proxy.size.width
            let cardWidth = min(max(availableWidth * 0.58, 214), 308)
            let cardHeight = min(max(cardWidth * 1.42, 304), 354)
            let offsets = [0, cardWidth * 0.44, cardWidth * 0.82]

            if visibleTasks.isEmpty {
                EmptyView()
            } else {
                let totalWidth = offsets[min(visibleTasks.count - 1, 2)] + cardWidth
                let leadingInset = max(0, (availableWidth - totalWidth) / 2)

                ZStack(alignment: .topLeading) {
                    ForEach(Array(visibleTasks.enumerated()).reversed(), id: \.element.id) { index, task in
                        let hero = assignedHeroImagesByTaskID[task.id] ?? .genericClouds
                        FocusTaskCard(
                            task: task,
                            insight: insightProvider(task.id),
                            heroImage: hero,
                            isActive: activeTaskID == task.id || (activeTaskID == nil && index == 0),
                            isSelectedForSwap: selectedCardForSwapID == task.id,
                            isFlipped: flippedTaskID == task.id,
                            reduceMotion: reduceMotion,
                            onTap: { onCardTap(task) },
                            onFlipBack: onFlipBack,
                            onQuickSwap: { onQuickSwap(task) },
                            onViewDetails: { onViewDetails(task) },
                            onStartTimer: { onStartTimer(task) }
                        )
                        .frame(width: cardWidth, height: cardHeight)
                        .offset(x: leadingInset + offsets[index], y: CGFloat(index) * 10)
                        .scaleEffect(1 - CGFloat(index) * 0.032, anchor: .topLeading)
                        .zIndex(Double(10 - index))
                        .accessibilityIdentifier("focusNow.card.\(index)")
                    }
                }
            }
        }
        .frame(height: 372)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

struct FocusTaskCard: View {
    let task: TaskDefinition
    let insight: EvaFocusTaskInsight?
    let heroImage: TaskHeroImage
    let isActive: Bool
    let isSelectedForSwap: Bool
    let isFlipped: Bool
    let reduceMotion: Bool
    let onTap: () -> Void
    let onFlipBack: () -> Void
    let onQuickSwap: () -> Void
    let onViewDetails: () -> Void
    let onStartTimer: () -> Void

    var body: some View {
        FocusCardFlipView(
            isFlipped: isFlipped,
            reduceMotion: reduceMotion,
            perspective: 0.62,
            duration: 0.42
        ) {
            FocusTaskCardFront(
                task: task,
                insight: insight,
                heroImage: heroImage,
                onTap: onTap,
                onQuickSwap: onQuickSwap
            )
        } back: {
            FocusTaskCardBack(
                task: task,
                heroImage: heroImage,
                onFlipBack: onFlipBack,
                onViewDetails: onViewDetails,
                onStartTimer: onStartTimer
            )
        }
        .lbShadow(isActive ? ShadowTokens.floating : ShadowTokens.card)
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(isSelectedForSwap ? heroImage.accentColor.opacity(0.56) : ClayColorTokens.whiteStroke.opacity(0.46), lineWidth: isSelectedForSwap ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
        .scaleEffect(isActive ? 1 : 0.992)
        .lifeBoardMotion(.selection, value: isActive)
    }
}

struct FocusTaskCardFront: View {
    let task: TaskDefinition
    let insight: EvaFocusTaskInsight?
    let heroImage: TaskHeroImage
    let onTap: () -> Void
    let onQuickSwap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let topHeight = proxy.size.height * 0.52
            let heroHeight = proxy.size.height * 0.34
            let stripHeight = max(48, proxy.size.height * 0.14)

            VStack(alignment: .leading, spacing: 0) {
                Button(action: onTap) {
                    VStack(alignment: .leading, spacing: 0) {
                        topContent
                            .frame(height: topHeight, alignment: .topLeading)

                        ZStack(alignment: .top) {
                            Image(decorative: heroImage.assetName)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: heroHeight)
                                .clipped()

                            LinearGradient(
                                colors: [heroImage.surfaceColor.opacity(0.75), Color.clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(task.title). \(task.projectName ?? String(localized: "Inbox")). \(summaryText).")
                .accessibilityIdentifier("focusNow.card.front.\(task.id.uuidString)")

                Button(action: onQuickSwap) {
                    HStack {
                        Text("Swap")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(ClayColorTokens.navyMuted)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.lifeboard(.caption1).weight(.bold))
                            .foregroundStyle(heroImage.accentColor)
                            .frame(width: 42, height: 42)
                            .background(EvaClayStyle.cream.opacity(0.94), in: Circle())
                            .lbShadow(ShadowTokens.card)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: stripHeight)
                    .background(EvaClayStyle.cream.opacity(0.82))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap task")
                .accessibilityIdentifier("focusNow.card.swap")
            }
        }
        .background(heroImage.surfaceColor, in: RoundedRectangle(cornerRadius: 28))
        .background(.white.opacity(0.34), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(heroImage.borderColor.opacity(0.85), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private var topContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: task.iconSymbolName ?? heroImage.symbolName)
                .font(.lifeboard(.callout).weight(.semibold))
                .foregroundStyle(heroImage.accentColor)
                .frame(width: 44, height: 44)
                .background(heroImage.tokenColor, in: Circle())
                .accessibilityHidden(true)

                Text(task.title)
                    .font(.lifeboard(.headline).weight(.bold))
                    .foregroundStyle(ClayColorTokens.navy)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("focusNow.card.title.\(task.id.uuidString)")

            Text(summaryText)
                .font(.lifeboard(.caption1))
                .foregroundStyle(ClayColorTokens.navyMuted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(task.projectName ?? String(localized: "Inbox"))
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(heroImage.accentColor)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(heroImage.pillColor, in: Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryText: String {
        FocusTaskReasonResolver.reason(for: task, insight: insight)
    }
}

struct FocusTaskCardBack: View {
    let task: TaskDefinition
    let heroImage: TaskHeroImage
    let onFlipBack: () -> Void
    let onViewDetails: () -> Void
    let onStartTimer: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button(action: onFlipBack) {
                    Image(systemName: "chevron.left")
                        .font(.lifeboard(.caption1).weight(.bold))
                        .foregroundStyle(heroImage.accentColor)
                        .frame(width: 44, height: 44)
                        .background(EvaClayStyle.cream, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                .accessibilityIdentifier("focusNow.card.back")
                Spacer()
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text("Start focus?")
                    .font(.lifeboard(.title2).weight(.bold))
                    .foregroundStyle(ClayColorTokens.navy)
            }

            VStack(spacing: 12) {
                Button("View details", systemImage: "doc.text.magnifyingglass", action: onViewDetails)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(ClayColorTokens.navy)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(EvaClayStyle.cream, in: RoundedRectangle(cornerRadius: 16))

                Button("Start focus", systemImage: "play.fill", action: onStartTimer)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(ClayColorTokens.navy, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("focusNow.card.startTimer")
            }

            Image(heroImage.assetName)
                .resizable()
                .scaledToFill()
                .frame(height: 112)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .opacity(0.72)
                .accessibilityHidden(true)
        }
        .padding(18)
        .background(heroImage.surfaceColor, in: RoundedRectangle(cornerRadius: 28))
        .background(.white.opacity(0.36), in: RoundedRectangle(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(heroImage.borderColor.opacity(0.85), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

struct FocusModeSegmentedControl: View {
    @Binding var selectedMode: FocusNowMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FocusNowMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Label(mode.title, systemImage: mode.systemImage)
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(selectedMode == mode ? ClayColorTokens.navy : ClayColorTokens.navyMuted)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                        .background(selectedMode == mode ? EvaClayStyle.cream : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedMode == mode ? [.isSelected] : [])
            }
        }
        .padding(5)
        .background(EvaClayStyle.peachSurfaceStrong, in: Capsule())
        .overlay {
            Capsule().stroke(EvaClayStyle.peachBorder.opacity(0.68), lineWidth: 1)
        }
    }
}

struct CandidateSection: View {
    let candidates: [TaskDefinition]
    let selectedMode: FocusNowMode
    let isShuffling: Bool
    let insightProvider: (UUID) -> EvaFocusTaskInsight?
    let onCandidateTap: (TaskDefinition) -> Void
    let onSwapTap: (TaskDefinition) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Other tasks")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(ClayColorTokens.navy)
                Text(selectedMode == .shuffleView ? "New suggestions." : "Tap one to swap it in.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(ClayColorTokens.navyMuted)
            }

            if candidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No other tasks")
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(ClayColorTokens.navy)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(EvaClayStyle.cream, in: RoundedRectangle(cornerRadius: Radius.card))
                .accessibilityIdentifier("focusNow.candidates.empty")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(candidates.prefix(3).enumerated()), id: \.element.id) { index, candidate in
                        CandidateTaskRow(
                            task: candidate,
                            insight: insightProvider(candidate.id),
                            onTap: { onCandidateTap(candidate) },
                            onSwapTap: { onSwapTap(candidate) }
                        )
                        if index < min(3, candidates.count) - 1 {
                            Divider().overlay(EvaClayStyle.peachBorder.opacity(0.68))
                        }
                    }
                }
                .redacted(reason: isShuffling ? .placeholder : [])
                .opacity(isShuffling ? 0.74 : 1)
                .lifeBoardMotion(.localState, value: isShuffling)
                .background(EvaClayStyle.cream.opacity(0.9), in: RoundedRectangle(cornerRadius: Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.card).stroke(EvaClayStyle.peachBorder.opacity(0.58), lineWidth: 1)
                }
            }
        }
        .accessibilityIdentifier("focusNow.candidates.section")
    }
}

struct CandidateTaskRow: View {
    let task: TaskDefinition
    let insight: EvaFocusTaskInsight?
    let onTap: () -> Void
    let onSwapTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    iconToken

                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.lifeboard(.callout).weight(.semibold))
                            .foregroundStyle(ClayColorTokens.navy)
                            .lineLimit(2)
                        Text(summaryText)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(ClayColorTokens.navyMuted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(task.title). \(summaryText).")
            .accessibilityHint("Swaps into Focus Now")
            .accessibilityIdentifier("focusNow.candidate.row.\(task.id.uuidString)")

            Button("Swap in", systemImage: "arrow.triangle.2.circlepath", action: onSwapTap)
                .labelStyle(.iconOnly)
                .font(.lifeboard(.caption1).weight(.bold))
                .foregroundStyle(ClayColorTokens.navyMuted)
                .frame(width: 44, height: 44)
                .background(EvaClayStyle.blueSurface.opacity(0.52), in: Circle())
                .accessibilityLabel("Swap in")
                .accessibilityIdentifier("focusNow.candidate.swap.\(task.id.uuidString)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var iconToken: some View {
        Group {
            let hero = TaskHeroImageResolver().preferredImages(for: task).first ?? .genericClouds
            Image(systemName: task.iconSymbolName ?? hero.symbolName)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(hero.accentColor)
                .frame(width: 38, height: 38)
                .background(hero.tokenColor, in: Circle())
                .accessibilityHidden(true)
        }
    }

    private var summaryText: String {
        FocusTaskReasonResolver.reason(for: task, insight: insight)
    }
}

struct ShuffleAgainCard: View {
    let isShuffling: Bool
    let isDisabled: Bool
    let onShuffle: () -> Void

    var body: some View {
        Button(action: onShuffle) {
            HStack(spacing: 14) {
                Image(systemName: "shuffle")
                    .font(.lifeboard(.callout).weight(.bold))
                    .foregroundStyle(ClayColorTokens.violetDeep)
                    .frame(width: 48, height: 48)
                    .background(EvaClayStyle.cream.opacity(0.9), in: Circle())
                    .rotationEffect(.degrees(isShuffling ? 360 : 0))
                    .lifeBoardMotion(.controlMorph, value: isShuffling)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Shuffle")
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(ClayColorTokens.navy)
                }

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        EvaClayStyle.cream.opacity(0.94),
                        // Hero surfaces rather than fixed pastels, so the cream
                        // dark-appearance ink above keeps its contrast.
                        Color(TaskHeroAccentRole.sunrise.surface).opacity(0.86),
                        Color(TaskHeroAccentRole.lake.surface).opacity(0.78)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: Radius.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Radius.card).stroke(EvaClayStyle.peachBorder.opacity(0.58), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier("home.focus.detail.shuffle")
    }
}

struct FocusBottomActions: View {
    let canStart: Bool
    let isStarting: Bool
    let onStartFocus: () -> Void
    let onRefineSet: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onStartFocus) {
                HStack(spacing: 12) {
                    Image(systemName: isStarting ? "hourglass" : "play.fill")
                        .font(.lifeboard(.callout).weight(.bold))
                        .frame(width: 48, height: 48)
                        .background(ClayColorTokens.whiteStroke.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isStarting ? "Starting\u{2026}" : "Start focus")
                            .font(.lifeboard(.bodyEmphasis))
                    }

                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 74)
                .background(ClayColorTokens.navy, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .disabled(!canStart || isStarting)
            .accessibilityLabel("Start focus")
            .accessibilityIdentifier("focusNow.startFocus")

            Button(action: onRefineSet) {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.lifeboard(.callout).weight(.semibold))
                        .frame(width: 48, height: 48)
                        .background(EvaClayStyle.peachSurfaceStrong, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Edit set")
                            .font(.lifeboard(.bodyEmphasis))
                    }

                    Spacer(minLength: 0)
                }
                .foregroundStyle(ClayColorTokens.navy)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 74)
                .background(EvaClayStyle.cream, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .disabled(isStarting)
            .accessibilityIdentifier("focusNow.refine.open")
        }
    }
}

struct RefineFocusSheet: View {
    let selectedTasks: [TaskDefinition]
    let candidateTasks: [TaskDefinition]
    let insightProvider: (UUID) -> EvaFocusTaskInsight?
    let onApply: ([TaskDefinition]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: [UUID]
    @State private var pendingReplacementTask: TaskDefinition?

    private var allTasks: [TaskDefinition] {
        var seen = Set<UUID>()
        return (selectedTasks + candidateTasks).filter { seen.insert($0.id).inserted }
    }

    init(
        selectedTasks: [TaskDefinition],
        candidateTasks: [TaskDefinition],
        insightProvider: @escaping (UUID) -> EvaFocusTaskInsight?,
        onApply: @escaping ([TaskDefinition]) -> Void
    ) {
        self.selectedTasks = selectedTasks
        self.candidateTasks = candidateTasks
        self.insightProvider = insightProvider
        self.onApply = onApply
        _selectedIDs = State(initialValue: selectedTasks.map(\.id))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Edit set")
                            .font(.lifeboard(.title2).weight(.bold))
                            .foregroundStyle(ClayColorTokens.navy)
                        Text("Pick up to 3 tasks.")
                            .font(.lifeboard(.callout))
                            .foregroundStyle(ClayColorTokens.navyMuted)
                        SelectedCountPill(count: selectedIDs.count)
                            .padding(.top, 4)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(allTasks.enumerated()), id: \.element.id) { index, task in
                            refineRow(task)
                            if index < allTasks.count - 1 {
                                Divider().overlay(EvaClayStyle.peachBorder.opacity(0.68))
                            }
                        }
                    }
                    .background(EvaClayStyle.cream.opacity(0.92), in: RoundedRectangle(cornerRadius: Radius.card))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.card).stroke(EvaClayStyle.peachBorder.opacity(0.58), lineWidth: 1)
                    }
                }
                .padding(18)
            }
            .background(EvaClayStyle.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(ClayColorTokens.navy)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background(EvaClayStyle.cream, in: RoundedRectangle(cornerRadius: Radius.card))

                    Button("Done") {
                        let selectedTasks = selectedIDs.compactMap { id in
                            allTasks.first(where: { $0.id == id })
                        }
                        onApply(selectedTasks)
                    }
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background(selectedIDs.isEmpty ? ClayColorTokens.navyMuted.opacity(0.48) : ClayColorTokens.navy, in: RoundedRectangle(cornerRadius: Radius.card))
                    .disabled(selectedIDs.isEmpty)
                    .accessibilityIdentifier("focusNow.refine.done")
                }
                .padding(16)
                .background(EvaClayStyle.canvas)
            }
            .confirmationDialog(
                "Replace which task?",
                isPresented: Binding(
                    get: { pendingReplacementTask != nil },
                    set: { if !$0 { pendingReplacementTask = nil } }
                ),
                titleVisibility: .visible,
                actions: {
                    if let pendingReplacementTask {
                        ForEach(selectedIDs, id: \.self) { selectedID in
                            if let selectedTask = allTasks.first(where: { $0.id == selectedID }) {
                                Button(selectedTask.title) {
                                    replace(selectedTask, with: pendingReplacementTask)
                                }
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        pendingReplacementTask = nil
                    }
                }
            )
        }
        .accessibilityIdentifier("focusNow.refine.sheet")
    }

    private func refineRow(_ task: TaskDefinition) -> some View {
        let isSelected = selectedIDs.contains(task.id)
        let isDisabled = !isSelected && selectedIDs.count >= 3 && pendingReplacementTask == nil

        return Button {
            toggle(task)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(isSelected ? ClayColorTokens.role(.focus).deep : ClayColorTokens.navyMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(ClayColorTokens.navy)
                        .lineLimit(2)
                    Text(insightProvider(task.id)?.rationale.first?.label ?? task.projectName ?? String(localized: "Inbox"))
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(ClayColorTokens.navyMuted)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .opacity(isDisabled ? 0.48 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier("focusNow.refine.row.\(task.id.uuidString)")
    }

    private func toggle(_ task: TaskDefinition) {
        if let index = selectedIDs.firstIndex(of: task.id) {
            selectedIDs.remove(at: index)
        } else if selectedIDs.count < 3 {
            selectedIDs.append(task.id)
        } else {
            pendingReplacementTask = task
        }
    }

    private func replace(_ oldTask: TaskDefinition, with newTask: TaskDefinition) {
        guard let index = selectedIDs.firstIndex(of: oldTask.id) else { return }
        selectedIDs[index] = newTask.id
        pendingReplacementTask = nil
    }
}

struct FocusTaskDetailSheet: View {
    let task: TaskDefinition
    let insight: EvaFocusTaskInsight?
    let onStartTimer: () -> Void
    let onSwapTask: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(task.title)
                        .font(.lifeboard(.title2).weight(.bold))
                        .foregroundStyle(ClayColorTokens.navy)
                        .fixedSize(horizontal: false, vertical: true)

                    detailGrid

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why?")
                            .font(.lifeboard(.headline))
                            .foregroundStyle(ClayColorTokens.navy)
                        Text(insight?.rationale.first?.label ?? String(localized: "Part of your focus set."))
                            .font(.lifeboard(.callout))
                            .foregroundStyle(ClayColorTokens.navyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(EvaClayStyle.blueSurfaceStrong, in: RoundedRectangle(cornerRadius: Radius.card))

                    if let details = task.details, details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.lifeboard(.headline))
                                .foregroundStyle(ClayColorTokens.navy)
                            Text(details)
                                .font(.lifeboard(.callout))
                                .foregroundStyle(ClayColorTokens.navyMuted)
                        }
                    }
                }
                .padding(18)
            }
            .background(EvaClayStyle.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button("Start focus", systemImage: "play.fill", action: onStartTimer)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(ClayColorTokens.navy, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("focusNow.taskDetail.startTimer")

                    Button("Swap task", systemImage: "arrow.triangle.2.circlepath", action: onSwapTask)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(ClayColorTokens.navy)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(EvaClayStyle.cream, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("focusNow.taskDetail.swap")
                }
                .padding(16)
                .background(EvaClayStyle.canvas)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("focusNow.taskDetail.sheet")
    }

    private var detailGrid: some View {
        VStack(spacing: 8) {
            detailRow(String(localized: "Project"), value: task.projectName ?? String(localized: "Inbox"), systemImage: "folder")
            detailRow(String(localized: "Due date"), value: dueDateText, systemImage: "calendar")
            detailRow(String(localized: "Duration"), value: durationText, systemImage: "clock")
            detailRow(String(localized: "Priority"), value: task.priority.displayName, systemImage: "flag")
            detailRow(String(localized: "Subtasks"), value: "\(task.subtasks.count)", systemImage: "checklist")
        }
        .padding(14)
        .background(EvaClayStyle.cream, in: RoundedRectangle(cornerRadius: Radius.card))
    }

    private func detailRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(ClayColorTokens.navyMuted)
                .frame(width: 24)
            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundStyle(ClayColorTokens.navyMuted)
            Spacer()
            Text(value)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(ClayColorTokens.navy)
                .multilineTextAlignment(.trailing)
        }
    }

    private var dueDateText: String {
        guard let dueDate = task.dueDate else { return String(localized: "Not set") }
        return dueDate.formatted(date: .abbreviated, time: task.isAllDay ? .omitted : .shortened)
    }

    private var durationText: String {
        guard let duration = task.estimatedDuration else { return String(localized: "Not set") }
        return FocusDurationStore.label(for: max(60, Int(duration.rounded())))
    }
}

struct FocusDurationPickerSheet: View {
    let task: TaskDefinition
    @Binding var selectedDurationSeconds: Int
    let isStarting: Bool
    let onStart: (Int) -> Void

    // Countdown presets from the person's own list (Deep work / Pomodoro /
    // Quick by default), with the historic quick picks as a floor so the
    // sheet never shows fewer than three choices.
    private let presets: [Int] = {
        let fromPreferences = WorkspacePreferencesStore.shared.load().focusPresets
            .filter { $0.kind == .countdown || $0.kind == .pomodoro }
            .map(\.minutes)
        return Array(Set(fromPreferences + [15, 25, 45, 60])).sorted()
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("How long?")
                        .font(.lifeboard(.title2).weight(.bold))
                        .foregroundStyle(ClayColorTokens.navy)

                    Text(task.title)
                        .font(.lifeboard(.callout))
                        .foregroundStyle(ClayColorTokens.navyMuted)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { minutes in
                            Button("\(minutes) min") {
                                selectedDurationSeconds = minutes * 60
                            }
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(selectedDurationSeconds == minutes * 60 ? Color.lifeboard(.accentOnPrimary) : ClayColorTokens.navy)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                        .background(selectedDurationSeconds == minutes * 60 ? Color.lifeboard(.actionPrimary) : EvaClayStyle.cream, in: Capsule())
                            .accessibilityIdentifier("focusNow.timer.preset.\(minutes)")
                        }
                    }

                    // Any other length. The number pad this replaced had no
                    // Return and no Done, so its keyboard could only be put away
                    // by starting or closing the sheet. The drum scrubs in
                    // 5-minute detents and its readout still takes typing.
                    ValueDrum(
                        "Custom length",
                        value: customMinutes,
                        in: 1...180,
                        step: 1,
                        coarseStep: 5,
                        unit: "min",
                        fractionDigits: 0,
                        identifier: "focusNow.timer.customMinutes",
                        keyboardPrompt: "Minutes"
                    )
                }
                .padding(18)
            }
            // Pinned, so Start stays on screen at the medium detent on a small
            // phone now that the drum is taller than the field it replaced.
            .safeAreaInset(edge: .bottom) {
                Button(startTitle) {
                    onStart(selectedDurationSeconds)
                }
                .font(.lifeboard(.bodyEmphasis))
                .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .background(ClayColorTokens.navy, in: RoundedRectangle(cornerRadius: Radius.card))
                .disabled(isStarting)
                .accessibilityIdentifier("focusNow.timer.start")
                .padding([.horizontal, .bottom], 18)
            }
            .background(EvaClayStyle.canvas.ignoresSafeArea())
        }
        .accessibilityLabel("Focus length")
        .accessibilityIdentifier("focusNow.timer.sheet")
    }

    /// The drum speaks minutes; the selection is kept in seconds.
    private var customMinutes: Binding<Double> {
        Binding(
            get: { Double(selectedDurationSeconds / 60) },
            set: { selectedDurationSeconds = min(max(Int($0.rounded()), 1), 180) * 60 }
        )
    }

    private var startTitle: String {
        isStarting ? String(localized: "Starting\u{2026}") : String(localized: "Start \(FocusDurationStore.label(for: selectedDurationSeconds)) focus")
    }
}

struct FocusTaskReasonResolver {
    static func reason(for task: TaskDefinition, insight: EvaFocusTaskInsight?) -> String {
        if let label = insight?.rationale.first?.label.trimmingCharacters(in: .whitespacesAndNewlines),
           label.isEmpty == false,
           label != "Make progress on what matters." {
            return label
        }

        let text = searchableText(for: task)
        if text.containsAny(["read", "book", "study", "learn", "pages"]) {
            return String(localized: "Learning")
        }
        if text.containsAny(["run", "walk", "workout", "exercise", "movement", "move", "wellness", "body", "stretch", "gym"]) {
            return String(localized: "Movement")
        }
        if text.containsAny(["meditate", "mindful", "calm", "breathe", "breathing", "journal"]) {
            return String(localized: "Mindfulness")
        }
        if text.containsAny(["cool off", "recover", "recovery", "break", "pause", "recharge", "decompress", "breather"]) {
            return String(localized: "Break")
        }
        if text.containsAny(["plan", "schedule", "calendar", "tomorrow", "morning", "setup"]) {
            return String(localized: "Planning")
        }
        if text.containsAny(["write", "draft", "admin", "paper", "note", "review", "document", "investor", "update", "meeting"]) {
            return String(localized: "Writing and admin")
        }
        if text.containsAny(["deep work", "focus", "block", "ship", "build", "code"]) {
            return String(localized: "Deep work")
        }
        return String(localized: "Up next")
    }

    private static func searchableText(for task: TaskDefinition) -> String {
        [
            task.title,
            task.projectName ?? "",
            task.details ?? "",
            String(describing: task.category),
            String(describing: task.context),
            String(describing: task.energy)
        ]
        .joined(separator: " ")
        .lowercased()
    }
}

enum TaskHeroImage: String, CaseIterable, Hashable {
    case meditation = "TaskCard01"
    case genericClouds = "TaskCard02"
    case recoveryLake = "TaskCard03"
    case greenPath = "TaskCard04"
    case sunrisePath = "TaskCard05"
    case deskNotebook = "TaskCard06"

    var assetName: String { rawValue }

    var symbolName: String {
        switch self {
        case .meditation: return "leaf.fill"
        case .genericClouds: return "sparkles"
        case .recoveryLake: return "moon.stars.fill"
        case .greenPath: return "figure.walk"
        case .sunrisePath: return "sunrise.fill"
        case .deskNotebook: return "pencil.and.outline"
        }
    }

    /// Adaptive per-hero palette; see `TaskHeroAccentRole` for why these are
    /// not fixed pastels.
    var accentRole: TaskHeroAccentRole {
        switch self {
        case .meditation: return .meditation
        case .genericClouds: return .clouds
        case .recoveryLake: return .lake
        case .greenPath: return .greenPath
        case .sunrisePath: return .sunrise
        case .deskNotebook: return .desk
        }
    }

    var surfaceColor: Color { Color(accentRole.surface) }
    var borderColor: Color { Color(accentRole.border) }
    var accentColor: Color { Color(accentRole.accent) }

    var tokenColor: Color { surfaceColor.opacity(0.92) }
    var pillColor: Color { surfaceColor.opacity(0.78) }
    var shadowColor: Color { accentColor }
}

struct TaskHeroImageResolver {
    private var assignments: [UUID: TaskHeroImage]

    init(existingAssignments: [UUID: TaskHeroImage] = [:]) {
        self.assignments = existingAssignments
    }

    mutating func assignImages(for tasks: [TaskDefinition]) -> [UUID: TaskHeroImage] {
        var used = Set<TaskHeroImage>()
        var resolved: [UUID: TaskHeroImage] = [:]

        for task in tasks.prefix(3) {
            if let assigned = assignments[task.id], !used.contains(assigned) {
                resolved[task.id] = assigned
                used.insert(assigned)
                continue
            }

            let selected = preferredImages(for: task).first(where: { !used.contains($0) }) ?? TaskHeroImage.allCases.first(where: { !used.contains($0) }) ?? .genericClouds
            resolved[task.id] = selected
            assignments[task.id] = selected
            used.insert(selected)
        }

        return assignments.merging(resolved) { _, new in new }
    }

    func preferredImages(for task: TaskDefinition) -> [TaskHeroImage] {
        let text = [
            task.title,
            task.projectName ?? "",
            task.details ?? "",
            String(describing: task.category),
            String(describing: task.context),
            String(describing: task.energy)
        ]
        .joined(separator: " ")
        .lowercased()

        if text.containsAny(["run", "walk", "workout", "exercise", "movement", "move", "wellness", "body", "stretch", "gym", "hike"]) {
            return [.greenPath, .meditation, .genericClouds]
        }
        if text.containsAny(["plan", "schedule", "calendar", "tomorrow", "morning", "setup"]) {
            return [.sunrisePath, .deskNotebook, .genericClouds]
        }
        if text.containsAny(["write", "draft", "admin", "paper", "note", "review", "document", "inbox", "meeting", "investor", "update"]) {
            return [.deskNotebook, .sunrisePath, .genericClouds]
        }
        if text.containsAny(["meditate", "mindful", "calm", "breathe", "breathing", "reflect", "journal"]) {
            return [.meditation, .recoveryLake, .genericClouds]
        }
        if text.containsAny(["recover", "cool", "cool off", "break", "pause", "recharge", "decompress", "breather"]) {
            return [.recoveryLake, .meditation, .genericClouds]
        }
        if text.containsAny(["deep work", "focus", "block", "ship", "build", "code"]) {
            return [.meditation, .deskNotebook, .genericClouds]
        }
        return [.genericClouds, .sunrisePath, .deskNotebook, .greenPath, .meditation, .recoveryLake]
    }
}

enum FocusDurationStore {
    private static let key = "lifeboard.focusNow.lastDurationSeconds"
    private static let fallbackDuration = 25 * 60
    private static let validRange = (60...(180 * 60))

    static func lastUsedDurationSeconds(defaults: UserDefaults = .standard) -> Int {
        let stored = defaults.integer(forKey: key)
        guard validRange.contains(stored) else { return fallbackDuration }
        return stored
    }

    static func saveLastUsedDurationSeconds(_ seconds: Int, defaults: UserDefaults = .standard) {
        defaults.set(min(max(seconds, validRange.lowerBound), validRange.upperBound), forKey: key)
    }

    static func defaultDurationSeconds(for task: TaskDefinition, defaults: UserDefaults = .standard) -> Int {
        if let duration = task.estimatedDuration, validRange.contains(Int(duration)) {
            return Int(duration)
        }
        return lastUsedDurationSeconds(defaults: defaults)
    }

    static func label(for seconds: Int) -> String {
        let minutes = max(1, Int((Double(seconds) / 60.0).rounded()))
        return LifeBoardDuration.text(minutes: minutes)
    }
}

private extension String {
    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}

private struct EvaOverdueRescueSheet: View {
    let plan: EvaRescuePlan?
    let tasksByID: [UUID: TaskDefinition]
    let lastBatchRunID: UUID?
    let onApply: ([EvaBatchMutationInstruction]) -> Void
    let onUndo: () -> Void
    let onSplitTask: (UUID) -> Void

    @State private var selectedActionByTaskID: [UUID: EvaRescueActionType] = [:]
    @State private var showDropConfirm = false
    @State private var pendingMutations: [EvaBatchMutationInstruction] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if let plan {
                    HStack {
                        Text(plan.debtLevel.rescueTitle)
                            .font(.lifeboard(.headline))
                        Spacer()
                        Text(String(format: "%.1f", plan.debtScore))
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.textSecondary)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            rescueRows(title: actionTitle(for: .doToday), items: plan.doToday)
                            rescueRows(title: actionTitle(for: .move), items: plan.move)
                            rescueRows(title: actionTitle(for: .split), items: plan.split)
                            rescueRows(title: actionTitle(for: .dropCandidate), items: plan.dropCandidate)
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Apply plan") {
                            let mutations = buildMutations(plan: plan)
                            if hasDropSelection(plan: plan) {
                                pendingMutations = mutations
                                showDropConfirm = true
                            } else {
                                onApply(mutations)
                                dismiss()
                            }
                        }
                        .buttonStyle(.lifeBoardPrimaryCompact)

                        if lastBatchRunID != nil {
                            Button("Undo") {
                                onUndo()
                            }
                            .buttonStyle(.lifeBoardChip)
                        }
                    }
                } else {
                    Text("Nothing from earlier")
                        .font(.lifeboard(.body))
                        .foregroundColor(Color.lifeboard.textSecondary)
                }
                Spacer()
            }
            .padding(16)
            .navigationTitle("Rescue")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                guard let plan else { return }
                var defaults: [UUID: EvaRescueActionType] = [:]
                for item in plan.doToday { defaults[item.taskID] = .doToday }
                for item in plan.move { defaults[item.taskID] = .move }
                for item in plan.split { defaults[item.taskID] = .split }
                for item in plan.dropCandidate { defaults[item.taskID] = .dropCandidate }
                selectedActionByTaskID = defaults
            }
            .alert("Move selected tasks to Inbox?", isPresented: $showDropConfirm) {
                Button("Move to Inbox", role: .destructive) {
                    onApply(pendingMutations)
                    pendingMutations = []
                    dismiss()
                }
                Button("Cancel", role: .cancel) {
                    pendingMutations = []
                }
            } message: {
                Text("Their due dates will be cleared.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func rescueRows(title: String, items: [EvaRescueRecommendation]) -> some View {
        if items.isEmpty == false {
            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textTertiary)

            ForEach(items, id: \.taskID) { item in
                HStack(spacing: 8) {
                    Text(tasksByID[item.taskID]?.title ?? String(localized: "Task"))
                        .font(.lifeboard(.body))
                        .foregroundColor(Color.lifeboard.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    Menu {
                        Button(actionTitle(for: .doToday)) { selectedActionByTaskID[item.taskID] = .doToday }
                        Button(actionTitle(for: .move)) { selectedActionByTaskID[item.taskID] = .move }
                        Button(actionTitle(for: .split)) { selectedActionByTaskID[item.taskID] = .split }
                        Button(actionTitle(for: .dropCandidate)) { selectedActionByTaskID[item.taskID] = .dropCandidate }
                    } label: {
                        Text(actionTitle(for: selectedActionByTaskID[item.taskID] ?? item.action))
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.accentPrimary)
                    }
                    .frame(minHeight: 44)
                }
                .padding(.vertical, 8)
                if (selectedActionByTaskID[item.taskID] ?? item.action) == .split {
                    Button("Split task") {
                        onSplitTask(item.taskID)
                    }
                    .buttonStyle(.plain)
                    .font(.lifeboard(.caption2))
                    .foregroundColor(Color.lifeboard.textSecondary)
                }
            }
        }
    }

    private func actionTitle(for action: EvaRescueActionType) -> String {
        switch action {
        case .doToday: return DecisionDestination.today.title
        case .move: return String(localized: "Move")
        case .split: return String(localized: "Split")
        case .dropCandidate: return String(localized: "Inbox")
        }
    }

    private func buildMutations(plan: EvaRescuePlan) -> [EvaBatchMutationInstruction] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        let recommendations = plan.doToday + plan.move + plan.split + plan.dropCandidate

        return recommendations.compactMap { item in
            let selected = selectedActionByTaskID[item.taskID] ?? item.action
            guard let expectedUpdatedAt = tasksByID[item.taskID]?.updatedAt else { return nil }
            switch selected {
            case .doToday:
                return EvaBatchMutationInstruction(
                    taskID: item.taskID,
                    expectedUpdatedAt: expectedUpdatedAt,
                    dueDate: today
                )
            case .move:
                return EvaBatchMutationInstruction(
                    taskID: item.taskID,
                    expectedUpdatedAt: expectedUpdatedAt,
                    dueDate: item.toDate ?? tomorrow
                )
            case .dropCandidate:
                return EvaBatchMutationInstruction(
                    taskID: item.taskID,
                    expectedUpdatedAt: expectedUpdatedAt,
                    projectID: ProjectConstants.inboxProjectID,
                    clearDueDate: true
                )
            case .split:
                return nil
            }
        }
    }

    private func hasDropSelection(plan: EvaRescuePlan) -> Bool {
        let recommendations = plan.doToday + plan.move + plan.split + plan.dropCandidate
        return recommendations.contains { item in
            (selectedActionByTaskID[item.taskID] ?? item.action) == .dropCandidate
        }
    }
}

/// Rescue's header in plain words. The raw level ("High") read as a verdict.
private extension EvaDebtLevel {
    var rescueTitle: String {
        switch self {
        case .none: String(localized: "Nothing from earlier")
        case .low: String(localized: "A few from earlier")
        case .medium: String(localized: "Some from earlier")
        case .high: String(localized: "Many from earlier")
        }
    }
}
