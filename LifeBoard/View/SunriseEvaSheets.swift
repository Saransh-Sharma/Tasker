import SwiftUI

private struct FocusTaskSyncSignature: Equatable {
    let id: UUID
    let isComplete: Bool

    init(_ task: TaskDefinition) {
        id = task.id
        isComplete = task.isComplete
    }
}

struct SunriseEvaFocusWhySheet: View {
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
    @State private var draftState = FocusNowDraftState()
    @State private var detailTask: TaskDefinition?
    @State private var timerTask: TaskDefinition?
    @State private var replacementCandidate: TaskDefinition?
    @State private var selectedDurationSeconds: Int = FocusDurationStore.lastUsedDurationSeconds()
    @State private var toastMessage: String?
    @State private var showDiscardConfirmation = false
    @State private var showRefineSheet = false

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
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
                actions: replacementDialogActions,
                message: {
                    Text("Choose the focus task to swap out.")
                }
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
                    Text("Your current Focus Now set has not been saved.")
                }
            )
    }

    private var rootScreen: some View {
        NavigationStack {
            ZStack {
                ReflectPlanStyle.canvas.ignoresSafeArea()

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
                                    .foregroundStyle(LBColorTokens.navyMuted)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(ReflectPlanStyle.cream, in: Capsule())
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
                .padding(.top, 6)
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
                showToast("Focus set updated · Undo")
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
        .presentationDetents([.medium])
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
        withAnimation(reduceMotion ? .easeInOut(duration: 0.18) : .easeInOut(duration: 0.42)) {
            draftState.selectAndFlip(task)
        }
    }

    private func quickSwap(_ task: TaskDefinition) {
        guard draftState.quickSwap(task) else {
            showToast("No better fits right now")
            return
        }
        showToast("Swapped into Focus Now · Undo")
    }

    private func handleCandidateTap(_ candidate: TaskDefinition) {
        guard let target = draftState.selectedTaskForSwap else {
            replacementCandidate = candidate
            return
        }
        replace(target, with: candidate)
        showToast("Swapped into Focus Now · Undo")
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
        withAnimation(reduceMotion ? .easeInOut(duration: 0.14) : .easeOut(duration: 0.24)) {
            draftState.beginShuffle()
        }
        onShuffleCandidates()
        showToast("Fresh picks ready")
        _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(nanoseconds: 420_000_000)
            draftState.endShuffle()
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.easeInOut(duration: 0.16)) {
            toastMessage = message
        }
    }

    private func undoLastChange() {
        draftState.undoLastChange()
        showToast("Restored previous Focus Now set")
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
        case .currentSet: return "Current set"
        case .shuffleView: return "Shuffle view"
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
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LBColorTokens.navy)
                    .frame(width: 44, height: 44)
                    .background(ReflectPlanStyle.cream, in: Circle())
                    .shadow(color: ReflectPlanStyle.shadow, radius: 12, x: 0, y: 6)
                    .accessibilityIdentifier("focusNow.back")

                Spacer()
            }

            Text("Focus Now")
                .font(.lifeboard(.title1).weight(.bold))
                .foregroundStyle(LBColorTokens.navy)
                .multilineTextAlignment(.center)
                .padding(.top, -4)

            Text("Tap or swap until this set feels right.")
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
                .multilineTextAlignment(.center)

            SelectedCountPill(count: selectedCount)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Focus Now. Tap or swap until this set feels right. \(selectedCount) tasks selected.")
    }
}

struct SelectedCountPill: View {
    let count: Int

    var body: some View {
        Label("^[\(count) task](inflect: true) selected", systemImage: "checkmark.circle.fill")
            .font(.lifeboard(.caption1).weight(.semibold))
            .foregroundStyle(LBColorTokens.navySoft)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(ReflectPlanStyle.cream, in: Capsule())
            .overlay {
                Capsule().stroke(ReflectPlanStyle.peachBorder.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: ReflectPlanStyle.shadow, radius: 12, x: 0, y: 7)
    }
}

struct FocusNowEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            Text("No focus set yet")
                .font(.lifeboard(.headline))
                .foregroundStyle(LBColorTokens.navy)
            Text("Add one task to anchor your next focus block.")
                .font(.lifeboard(.callout))
                .foregroundStyle(LBColorTokens.navyMuted)
        }
        .padding(LBSpacingTokens.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 24))
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
            let availableWidth = proxy.size.width
            let cardWidth = min(max(availableWidth * 0.58, 214), 308)
            let cardHeight = min(max(cardWidth * 1.42, 304), 354)
            let offsets = [0, cardWidth * 0.44, cardWidth * 0.82]
            let totalWidth = offsets[min(tasks.prefix(3).count - 1, 2)] + cardWidth
            let leadingInset = max(0, (availableWidth - totalWidth) / 2)

            ZStack(alignment: .topLeading) {
                ForEach(Array(tasks.prefix(3).enumerated()).reversed(), id: \.element.id) { index, task in
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
        .shadow(color: heroImage.shadowColor.opacity(isActive ? 0.26 : 0.14), radius: isActive ? 28 : 18, x: 0, y: isActive ? 18 : 12)
        .shadow(color: Color.black.opacity(isActive ? 0.08 : 0.045), radius: isActive ? 18 : 12, x: 0, y: isActive ? 16 : 10)
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(isSelectedForSwap ? heroImage.accentColor.opacity(0.56) : Color.white.opacity(0.46), lineWidth: isSelectedForSwap ? 2 : 1)
        }
        .accessibilityElement(children: .contain)
        .scaleEffect(isActive ? 1 : 0.992)
        .animation(.easeInOut(duration: 0.2), value: isActive)
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
                .accessibilityLabel("Task. \(task.title). \(task.projectName ?? "Inbox"). \(summaryText). Double tap for focus options.")
                .accessibilityIdentifier("focusNow.card.front.\(task.id.uuidString)")

                Button(action: onQuickSwap) {
                    HStack {
                        Text("Tap to swap")
                            .font(.lifeboard(.caption1).weight(.semibold))
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(heroImage.accentColor)
                            .frame(width: 42, height: 42)
                            .background(ReflectPlanStyle.cream.opacity(0.94), in: Circle())
                            .shadow(color: ReflectPlanStyle.shadow.opacity(0.7), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: stripHeight)
                    .background(ReflectPlanStyle.cream.opacity(0.82))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap this task.")
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(heroImage.accentColor)
                .frame(width: 44, height: 44)
                .background(heroImage.tokenColor, in: Circle())
                .accessibilityHidden(true)

                Text(task.title)
                    .font(.lifeboard(.headline).weight(.bold))
                    .foregroundStyle(LBColorTokens.navy)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("focusNow.card.title.\(task.id.uuidString)")

            Text(summaryText)
                .font(.lifeboard(.caption1))
                .foregroundStyle(LBColorTokens.navyMuted)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(task.projectName ?? "Inbox")
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(heroImage.accentColor)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
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
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(heroImage.accentColor)
                        .frame(width: 44, height: 44)
                        .background(ReflectPlanStyle.cream, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to card front")
                .accessibilityIdentifier("focusNow.card.back")
                Spacer()
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text("Ready to focus?")
                    .font(.lifeboard(.title2).weight(.bold))
                    .foregroundStyle(LBColorTokens.navy)

                Text("Review the task or start a focused block.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button("View details", systemImage: "doc.text.magnifyingglass", action: onViewDetails)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(LBColorTokens.navy)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 16))

                Button("Start timer", systemImage: "play.fill", action: onStartTimer)
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(LBColorTokens.navy, in: RoundedRectangle(cornerRadius: 16))
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
                        .foregroundStyle(selectedMode == mode ? LBColorTokens.navy : LBColorTokens.navyMuted)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 42)
                        .background(selectedMode == mode ? ReflectPlanStyle.cream : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedMode == mode ? [.isSelected] : [])
            }
        }
        .padding(5)
        .background(ReflectPlanStyle.peachSurfaceStrong, in: Capsule())
        .overlay {
            Capsule().stroke(ReflectPlanStyle.peachBorder.opacity(0.68), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Other great fits")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(LBColorTokens.navy)
                Text(selectedMode == .shuffleView ? "Fresh alternatives for your active card." : "Tap a task to swap it into your set.")
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
            }

            if candidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("No better fits right now")
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)
                    Text("Your current set already looks focused.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navyMuted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 18))
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
                            Divider().overlay(ReflectPlanStyle.peachBorder.opacity(0.68))
                        }
                    }
                }
                .redacted(reason: isShuffling ? .placeholder : [])
                .opacity(isShuffling ? 0.74 : 1)
                .animation(.easeInOut(duration: 0.18), value: isShuffling)
                .background(ReflectPlanStyle.cream.opacity(0.9), in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22).stroke(ReflectPlanStyle.peachBorder.opacity(0.58), lineWidth: 1)
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
                            .foregroundStyle(LBColorTokens.navy)
                            .lineLimit(2)
                        Text(summaryText)
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(task.title). \(summaryText).")
            .accessibilityHint("Double tap to swap into Focus Now.")
            .accessibilityIdentifier("focusNow.candidate.row.\(task.id.uuidString)")

            Button("Swap into Focus Now", systemImage: "arrow.triangle.2.circlepath", action: onSwapTap)
                .labelStyle(.iconOnly)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(LBColorTokens.navyMuted)
                .frame(width: 44, height: 44)
                .background(ReflectPlanStyle.blueSurface.opacity(0.52), in: Circle())
                .accessibilityLabel("Swap into Focus Now")
                .accessibilityIdentifier("focusNow.candidate.swap.\(task.id.uuidString)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var iconToken: some View {
        Group {
            let hero = TaskHeroImageResolver().preferredImages(for: task).first ?? .genericClouds
            Image(systemName: task.iconSymbolName ?? hero.symbolName)
                .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(LBColorTokens.violetDeep)
                    .frame(width: 48, height: 48)
                    .background(ReflectPlanStyle.cream.opacity(0.9), in: Circle())
                    .rotationEffect(.degrees(isShuffling ? 360 : 0))
                    .animation(.easeInOut(duration: 0.42), value: isShuffling)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Shuffle Again")
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)
                    Text("Fresh ideas, same Focus Now.")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navyMuted)
                }

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [
                        ReflectPlanStyle.cream.opacity(0.94),
                        Color(lifeboardHex: "#FFF1EA").opacity(0.86),
                        Color(lifeboardHex: "#F7F1FF").opacity(0.78)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 22)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22).stroke(ReflectPlanStyle.peachBorder.opacity(0.58), lineWidth: 1)
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
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 48, height: 48)
                        .background(Color.white.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(isStarting ? "Starting..." : "Start focus")
                            .font(.lifeboard(.bodyEmphasis))
                        Text("Lock in and get going")
                            .font(.lifeboard(.caption1))
                            .opacity(0.82)
                    }

                    Spacer(minLength: 0)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 74)
                .background(LBColorTokens.navy, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .disabled(!canStart || isStarting)
            .accessibilityLabel("Start focus. Lock in and get going.")
            .accessibilityIdentifier("focusNow.startFocus")

            Button(action: onRefineSet) {
                HStack(spacing: 12) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .background(ReflectPlanStyle.peachSurfaceStrong, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Refine set")
                            .font(.lifeboard(.bodyEmphasis))
                        Text("Adjust until it's right")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(LBColorTokens.navyMuted)
                    }

                    Spacer(minLength: 0)
                }
                .foregroundStyle(LBColorTokens.navy)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 74)
                .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 20))
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Refine Focus Now")
                            .font(.lifeboard(.title2).weight(.bold))
                            .foregroundStyle(LBColorTokens.navy)
                        Text("Choose up to three tasks for this focus block.")
                            .font(.lifeboard(.callout))
                            .foregroundStyle(LBColorTokens.navyMuted)
                        SelectedCountPill(count: selectedIDs.count)
                            .padding(.top, 4)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(allTasks.enumerated()), id: \.element.id) { index, task in
                            refineRow(task)
                            if index < allTasks.count - 1 {
                                Divider().overlay(ReflectPlanStyle.peachBorder.opacity(0.68))
                            }
                        }
                    }
                    .background(ReflectPlanStyle.cream.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22).stroke(ReflectPlanStyle.peachBorder.opacity(0.58), lineWidth: 1)
                    }
                }
                .padding(18)
            }
            .background(ReflectPlanStyle.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(LBColorTokens.navy)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 18))

                    Button("Done") {
                        let selectedTasks = selectedIDs.compactMap { id in
                            allTasks.first(where: { $0.id == id })
                        }
                        onApply(selectedTasks)
                    }
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .background(selectedIDs.isEmpty ? LBColorTokens.navyMuted.opacity(0.48) : LBColorTokens.navy, in: RoundedRectangle(cornerRadius: 18))
                    .disabled(selectedIDs.isEmpty)
                    .accessibilityIdentifier("focusNow.refine.done")
                }
                .padding(16)
                .background(ReflectPlanStyle.canvas)
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
                },
                message: {
                    Text("Choose the focus task to swap out.")
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? LBColorTokens.role(.focus).deep : LBColorTokens.navyMuted)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navy)
                        .lineLimit(2)
                    Text(insightProvider(task.id)?.rationale.first?.label ?? task.projectName ?? "Inbox")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(LBColorTokens.navyMuted)
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
                        .foregroundStyle(LBColorTokens.navy)
                        .fixedSize(horizontal: false, vertical: true)

                    detailGrid

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Why this task?")
                            .font(.lifeboard(.headline))
                            .foregroundStyle(LBColorTokens.navy)
                        Text(insight?.rationale.first?.label ?? "It fits your current focus set and helps keep today narrow.")
                            .font(.lifeboard(.callout))
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(ReflectPlanStyle.blueSurfaceStrong, in: RoundedRectangle(cornerRadius: 18))

                    if let details = task.details, details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.lifeboard(.headline))
                                .foregroundStyle(LBColorTokens.navy)
                            Text(details)
                                .font(.lifeboard(.callout))
                                .foregroundStyle(LBColorTokens.navyMuted)
                        }
                    }
                }
                .padding(18)
            }
            .background(ReflectPlanStyle.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 10) {
                    Button("Start timer", systemImage: "play.fill", action: onStartTimer)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(LBColorTokens.navy, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("focusNow.taskDetail.startTimer")

                    Button("Swap task", systemImage: "arrow.triangle.2.circlepath", action: onSwapTask)
                        .font(.lifeboard(.bodyEmphasis))
                        .foregroundStyle(LBColorTokens.navy)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                        .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("focusNow.taskDetail.swap")
                }
                .padding(16)
                .background(ReflectPlanStyle.canvas)
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
            detailRow("Project", value: task.projectName ?? "Inbox", systemImage: "folder")
            detailRow("Due date", value: dueDateText, systemImage: "calendar")
            detailRow("Duration", value: durationText, systemImage: "clock")
            detailRow("Priority", value: task.priority.displayName, systemImage: "flag")
            detailRow("Subtasks", value: "\(task.subtasks.count)", systemImage: "checklist")
        }
        .padding(14)
        .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 18))
    }

    private func detailRow(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(LBColorTokens.navyMuted)
                .frame(width: 24)
            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundStyle(LBColorTokens.navyMuted)
            Spacer()
            Text(value)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(LBColorTokens.navy)
                .multilineTextAlignment(.trailing)
        }
    }

    private var dueDateText: String {
        guard let dueDate = task.dueDate else { return "Not set" }
        return dueDate.formatted(date: .abbreviated, time: task.isAllDay ? .omitted : .shortened)
    }

    private var durationText: String {
        guard let duration = task.estimatedDuration else { return "Not set" }
        return FocusDurationStore.label(for: max(60, Int(duration.rounded())))
    }
}

struct FocusDurationPickerSheet: View {
    let task: TaskDefinition
    @Binding var selectedDurationSeconds: Int
    let isStarting: Bool
    let onStart: (Int) -> Void
    @State private var customMinutes = ""

    private let presets = [15, 25, 45, 60]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("How long do you want to focus?")
                    .font(.lifeboard(.title2).weight(.bold))
                    .foregroundStyle(LBColorTokens.navy)

                Text(task.title)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { minutes in
                        Button("\(minutes) min") {
                            selectedDurationSeconds = minutes * 60
                            customMinutes = ""
                        }
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(selectedDurationSeconds == minutes * 60 ? Color.white : LBColorTokens.navy)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(selectedDurationSeconds == minutes * 60 ? LBColorTokens.navy : ReflectPlanStyle.cream, in: Capsule())
                        .accessibilityIdentifier("focusNow.timer.preset.\(minutes)")
                    }
                }

                TextField("Custom minutes", text: $customMinutes)
                    .font(.lifeboard(.callout))
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("focusNow.timer.customMinutes")
                    .onChange(of: customMinutes) { _, newValue in
                        guard let minutes = Int(newValue), minutes > 0 else { return }
                        selectedDurationSeconds = min(max(minutes, 1), 180) * 60
                    }

                Spacer()

                Button(startTitle) {
                    onStart(selectedDurationSeconds)
                }
                .font(.lifeboard(.bodyEmphasis))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .background(LBColorTokens.navy, in: RoundedRectangle(cornerRadius: 18))
                .disabled(isStarting)
                .accessibilityIdentifier("focusNow.timer.start")
            }
            .padding(18)
            .background(ReflectPlanStyle.canvas.ignoresSafeArea())
        }
        .accessibilityLabel("Choose focus timer duration.")
        .accessibilityIdentifier("focusNow.timer.sheet")
    }

    private var startTitle: String {
        isStarting ? "Starting focus" : "Start \(FocusDurationStore.label(for: selectedDurationSeconds)) focus"
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
            return "Recharge while you learn."
        }
        if text.containsAny(["run", "walk", "workout", "exercise", "movement", "move", "wellness", "body", "stretch", "gym"]) {
            return "Move your body, reset your energy."
        }
        if text.containsAny(["meditate", "mindful", "calm", "breathe", "breathing", "journal"]) {
            return "Create a quiet reset before the next push."
        }
        if text.containsAny(["cool off", "recover", "recovery", "break", "pause", "recharge", "decompress", "breather"]) {
            return "Give your brain a breather."
        }
        if text.containsAny(["plan", "schedule", "calendar", "tomorrow", "morning", "setup"]) {
            return "Create a planned day before it starts."
        }
        if text.containsAny(["write", "draft", "admin", "paper", "note", "review", "document", "investor", "update", "meeting"]) {
            return "Clarify the next update while context is fresh."
        }
        if text.containsAny(["deep work", "focus", "block", "ship", "build", "code"]) {
            return "Protect your most important time."
        }
        return "Keep today narrow and move one useful thing forward."
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

    var surfaceColor: Color {
        switch self {
        case .meditation: return Color(lifeboardHex: "#FFF4EA")
        case .genericClouds: return Color(lifeboardHex: "#F4FAFF")
        case .recoveryLake: return Color(lifeboardHex: "#F4EEFF")
        case .greenPath: return Color(lifeboardHex: "#F2FAEE")
        case .sunrisePath: return Color(lifeboardHex: "#FFF0E6")
        case .deskNotebook: return Color(lifeboardHex: "#FFF7EC")
        }
    }

    var borderColor: Color {
        switch self {
        case .meditation, .greenPath: return Color(lifeboardHex: "#CFE6C5")
        case .genericClouds: return ReflectPlanStyle.blueBorder
        case .recoveryLake: return Color(lifeboardHex: "#D9C9FF")
        case .sunrisePath, .deskNotebook: return ReflectPlanStyle.peachBorder
        }
    }

    var accentColor: Color {
        switch self {
        case .meditation, .greenPath: return Color(lifeboardHex: "#2F7A4D")
        case .genericClouds: return LBColorTokens.violetDeep
        case .recoveryLake: return Color(lifeboardHex: "#6F57B8")
        case .sunrisePath: return Color(lifeboardHex: "#C9672B")
        case .deskNotebook: return LBColorTokens.navySoft
        }
    }

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
        if minutes == 60 { return "60 min" }
        return "\(minutes) min"
    }
}

private extension String {
    func containsAny(_ needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}

private struct SunriseEvaOverdueRescueSheet: View {
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
                        Text("Debt: \(plan.debtLevel.rawValue.capitalized)")
                            .font(.lifeboard(.headline))
                        Spacer()
                        Text(String(format: "%.1f", plan.debtScore))
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.textSecondary)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            rescueRows(title: "Do today", items: plan.doToday)
                            rescueRows(title: "Move", items: plan.move)
                            rescueRows(title: "Split", items: plan.split)
                            rescueRows(title: "Drop?", items: plan.dropCandidate)
                        }
                    }

                    HStack(spacing: 10) {
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
                        .buttonStyle(.borderedProminent)

                        if lastBatchRunID != nil {
                            Button("Undo last apply") {
                                onUndo()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else {
                    Text("No overdue tasks to rescue.")
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
                Button("Apply", role: .destructive) {
                    onApply(pendingMutations)
                    pendingMutations = []
                    dismiss()
                }
                Button("Cancel", role: .cancel) {
                    pendingMutations = []
                }
            } message: {
                Text("Tasks marked Drop? will move to Inbox and have their due date cleared.")
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
                    Text(tasksByID[item.taskID]?.title ?? "Task")
                        .font(.lifeboard(.body))
                        .foregroundColor(Color.lifeboard.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    Menu {
                        Button("Do today") { selectedActionByTaskID[item.taskID] = .doToday }
                        Button("Move") { selectedActionByTaskID[item.taskID] = .move }
                        Button("Split") { selectedActionByTaskID[item.taskID] = .split }
                        Button("Drop?") { selectedActionByTaskID[item.taskID] = .dropCandidate }
                    } label: {
                        Text(actionTitle(for: selectedActionByTaskID[item.taskID] ?? item.action))
                            .font(.lifeboard(.caption1))
                            .foregroundColor(Color.lifeboard.accentPrimary)
                    }
                    .frame(minHeight: 44)
                }
                .padding(.vertical, 6)
                if (selectedActionByTaskID[item.taskID] ?? item.action) == .split {
                    Button("Open split helper") {
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
        case .doToday: return "Do today"
        case .move: return "Move"
        case .split: return "Split"
        case .dropCandidate: return "Drop?"
        }
    }

    private func buildMutations(plan: EvaRescuePlan) -> [EvaBatchMutationInstruction] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        let recommendations = plan.doToday + plan.move + plan.split + plan.dropCandidate

        return recommendations.compactMap { item in
            let selected = selectedActionByTaskID[item.taskID] ?? item.action
            switch selected {
            case .doToday:
                return EvaBatchMutationInstruction(taskID: item.taskID, dueDate: today)
            case .move:
                return EvaBatchMutationInstruction(taskID: item.taskID, dueDate: item.toDate ?? tomorrow)
            case .dropCandidate:
                return EvaBatchMutationInstruction(
                    taskID: item.taskID,
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
