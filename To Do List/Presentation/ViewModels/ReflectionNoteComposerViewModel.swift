import Foundation

@MainActor
public final class ReflectionNoteComposerViewModel: ObservableObject {
    @Published public var noteText: String
    @Published public var prompt: String
    @Published public var mood: Int
    @Published public var energy: Int
    @Published public private(set) var isSaving = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var saveMessage: String?

    public let title: String
    public let kind: ReflectionNoteKind

    private let linkedTaskID: UUID?
    private let linkedProjectID: UUID?
    private let linkedHabitID: UUID?
    private let linkedWeeklyPlanID: UUID?
    private let saveNoteHandler: (ReflectionNote, @escaping (Result<ReflectionNote, Error>) -> Void) -> Void

    public init(
        title: String,
        kind: ReflectionNoteKind,
        linkedTaskID: UUID? = nil,
        linkedProjectID: UUID? = nil,
        linkedHabitID: UUID? = nil,
        linkedWeeklyPlanID: UUID? = nil,
        prompt: String? = nil,
        noteText: String = "",
        mood: Int = 3,
        energy: Int = 3,
        saveNoteHandler: @escaping (ReflectionNote, @escaping (Result<ReflectionNote, Error>) -> Void) -> Void
    ) {
        self.title = title
        self.kind = kind
        self.linkedTaskID = linkedTaskID
        self.linkedProjectID = linkedProjectID
        self.linkedHabitID = linkedHabitID
        self.linkedWeeklyPlanID = linkedWeeklyPlanID
        self.prompt = prompt ?? ""
        self.noteText = noteText
        self.mood = mood
        self.energy = energy
        self.saveNoteHandler = saveNoteHandler
    }

    public var canSave: Bool {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isSaving
    }

    public func clearError() {
        errorMessage = nil
    }

    public func save(completion: ((ReflectionNote) -> Void)? = nil) {
        guard canSave else { return }

        isSaving = true
        errorMessage = nil
        saveMessage = nil

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = ReflectionNote(
            kind: kind,
            linkedTaskID: linkedTaskID,
            linkedProjectID: linkedProjectID,
            linkedHabitID: linkedHabitID,
            linkedWeeklyPlanID: linkedWeeklyPlanID,
            energy: energy,
            mood: mood,
            prompt: trimmedPrompt.isEmpty ? nil : trimmedPrompt,
            noteText: trimmedNote
        )

        saveNoteHandler(note) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success(let savedNote):
                    self.saveMessage = WeeklyCopy.reflectionSaveSuccess
                    completion?(savedNote)
                }
            }
        }
    }
}


// MARK: - Daily Reflect Plan View Model

import Foundation

@MainActor
public final class DailyReflectPlanViewModel: ObservableObject {
    @Published public private(set) var target: DailyReflectionTarget?
    @Published public private(set) var loadState: DailyReflectionLoadState = .idle
    @Published public private(set) var coreSnapshot: DailyReflectionCoreSnapshot?
    @Published public private(set) var optionalContext: DailyReflectionOptionalContext?
    @Published public private(set) var snapshot: DailyReflectionSnapshot?
    @Published public var selectedMood: ReflectionMood?
    @Published public var selectedEnergy: ReflectionEnergy?
    @Published public var selectedFrictionTags: Set<ReflectionFrictionTag> = []
    @Published public var noteText: String = ""
    @Published public private(set) var editablePlan: EditableDailyPlan?
    @Published public private(set) var isSaving: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var successMessage: String?
    @Published public var activeSwapSlot: Int?

    private let loadCoordinator: DailyReflectionLoadCoordinatorProtocol
    private let saveUseCase: SaveDailyReflectionAndPlanUseCase
    private let preferredReflectionDate: Date?
    private let analyticsTracker: ((String, [String: String]) -> Void)?
    private let onComplete: ((SaveDailyReflectionAndPlanResult) -> Void)?
    private let calendar: Calendar
    private var openedAt: Date
    private var loadTask: Task<Void, Never>?
    private var currentLoadID = UUID()

    public init(
        useCaseCoordinator: UseCaseCoordinator,
        preferredReflectionDate: Date? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        analyticsTracker: ((String, [String: String]) -> Void)? = nil,
        onComplete: ((SaveDailyReflectionAndPlanResult) -> Void)? = nil
    ) {
        self.loadCoordinator = useCaseCoordinator.dailyReflectionLoadCoordinator
        self.saveUseCase = useCaseCoordinator.saveDailyReflectionAndPlan
        self.preferredReflectionDate = preferredReflectionDate
        self.analyticsTracker = analyticsTracker
        self.onComplete = onComplete
        self.calendar = calendar
        self.openedAt = Date()

        load()
    }

    deinit {
        loadTask?.cancel()
    }

    public var isLoading: Bool {
        loadState == .loadingCore
    }

    public var canSave: Bool {
        isSaving == false && snapshot != nil && editablePlan != nil
    }

    public var planningStatusMessage: String? {
        optionalContext?.status.message
    }

    public var isPlanningPlaceholderVisible: Bool {
        loadState == .coreLoaded && editablePlan == nil
    }

    public func load() {
        cancelLoading()

        openedAt = Date()
        currentLoadID = UUID()
        errorMessage = nil
        successMessage = nil
        target = nil
        coreSnapshot = nil
        optionalContext = nil
        snapshot = nil
        editablePlan = nil
        activeSwapSlot = nil
        loadState = .loadingCore

        let loadID = currentLoadID
        loadTask = Task { [weak self] in
            guard let self else { return }

            let resolvedTarget = await loadCoordinator.resolveTarget(preferredReflectionDate: preferredReflectionDate)
            guard self.isActiveLoad(loadID) else { return }

            guard let resolvedTarget else {
                self.target = nil
                self.loadState = .idle
                return
            }

            do {
                let coreBundle = try await loadCoordinator.loadCore(target: resolvedTarget)
                guard self.isActiveLoad(loadID) else { return }

                self.target = resolvedTarget
                self.coreSnapshot = coreBundle.coreSnapshot
                self.loadState = .coreLoaded
                self.analyticsTracker?("reflection_entry_shown", self.baseAnalyticsMetadata(mode: coreBundle.coreSnapshot.mode))
                self.analyticsTracker?("reflection_opened", self.baseAnalyticsMetadata(mode: coreBundle.coreSnapshot.mode))
                self.analyticsTracker?(
                    coreBundle.coreSnapshot.mode == .sameDay ? "reflection_mode_same_day" : "reflection_mode_catch_up_yesterday",
                    self.baseAnalyticsMetadata(mode: coreBundle.coreSnapshot.mode)
                )

                let optionalContext = await loadCoordinator.loadOptionalContext(target: resolvedTarget, coreBundle: coreBundle)
                guard self.isActiveLoad(loadID) else { return }

                self.optionalContext = optionalContext
                self.snapshot = coreBundle.coreSnapshot.makeSnapshot(optionalContext: optionalContext)
                self.editablePlan = EditableDailyPlan(planningDate: resolvedTarget.planningDate, suggestion: optionalContext.suggestedPlan)
                self.loadState = .fullyLoaded
            } catch is CancellationError {
                guard self.isActiveLoad(loadID) else { return }
            } catch {
                guard self.isActiveLoad(loadID) else { return }
                self.errorMessage = error.localizedDescription
                self.loadState = .coreFailed
            }
        }
    }

    public func cancelLoading() {
        loadTask?.cancel()
        loadTask = nil
    }

    public func toggleMood(_ mood: ReflectionMood) {
        selectedMood = selectedMood == mood ? nil : mood
        trackChipSelected(kind: "mood", value: mood.rawValue)
    }

    public func toggleEnergy(_ energy: ReflectionEnergy) {
        selectedEnergy = selectedEnergy == energy ? nil : energy
        trackChipSelected(kind: "energy", value: energy.rawValue)
    }

    public func toggleFriction(_ tag: ReflectionFrictionTag) {
        if selectedFrictionTags.contains(tag) {
            selectedFrictionTags.remove(tag)
        } else {
            selectedFrictionTags.insert(tag)
        }
        trackChipSelected(kind: "friction", value: tag.rawValue)
    }

    public func swapTask(slotIndex: Int, with option: DailyPlanTaskOption) {
        guard var editablePlan else { return }
        editablePlan.swapTask(at: slotIndex, with: option)
        self.editablePlan = editablePlan
        activeSwapSlot = nil
        analyticsTracker?(
            "reflection_plan_swapped",
            baseAnalyticsMetadata(mode: target?.mode).merging(
                [
                    "slot_index": String(slotIndex),
                    "task_id": option.id.uuidString
                ],
                uniquingKeysWith: { _, new in new }
            )
        )
    }

    public func swapOptions(for slotIndex: Int) -> [DailyPlanTaskOption] {
        editablePlan?.swapOptions(for: slotIndex) ?? []
    }

    public func save(replaceManualDraft: Bool = false) {
        guard isSaving == false,
              let snapshot,
              let editablePlan else { return }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let trimmedNote = noteText
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let input = DailyReflectionInput(
            mood: selectedMood,
            energy: selectedEnergy,
            frictionTags: selectedFrictionTags.sorted { $0.rawValue < $1.rawValue },
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )

        if input.note != nil {
            analyticsTracker?("reflection_note_added", baseAnalyticsMetadata(mode: snapshot.mode))
        }

        saveUseCase.execute(
            snapshot: snapshot,
            input: input,
            plan: editablePlan,
            replaceExistingManualDraft: replaceManualDraft
        ) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.analyticsTracker?(
                        "reflection_save_failed",
                        self.baseAnalyticsMetadata(mode: snapshot.mode).merging(
                            ["error": error.localizedDescription],
                            uniquingKeysWith: { _, new in new }
                        )
                    )
                case .success(let saveResult):
                    let zeroTyping = input.note == nil
                        && input.mood == nil
                        && input.energy == nil
                        && input.frictionTags.isEmpty
                    self.successMessage = saveResult.preservedExistingManualDraft
                        ? "Reflection saved. Existing manual plan kept."
                        : "Reflection saved. Next board updated."
                    self.analyticsTracker?(
                        "reflection_saved",
                        self.baseAnalyticsMetadata(mode: snapshot.mode).merging(
                            [
                                "zero_typing": zeroTyping ? "true" : "false",
                                "completion_seconds": String(Int(Date().timeIntervalSince(self.openedAt)))
                            ],
                            uniquingKeysWith: { _, new in new }
                        )
                    )
                    self.analyticsTracker?("reflection_plan_saved", self.baseAnalyticsMetadata(mode: snapshot.mode))
                    self.analyticsTracker?("reflection_to_board_opened", self.baseAnalyticsMetadata(mode: snapshot.mode))
                    self.onComplete?(saveResult)
                }
            }
        }
    }

    public var isCompleteStateVisible: Bool {
        loadState == .idle && target == nil && coreSnapshot == nil && errorMessage == nil
    }

    public var screenTitle: String {
        "Reflect & Plan"
    }

    public var reflectionDateLabel: String {
        guard let date = target?.reflectionDate else { return "" }
        return Self.dayTitle(for: date, calendar: calendar)
    }

    public var planningDateLabel: String {
        guard let date = target?.planningDate else { return "" }
        return Self.dayTitle(for: date, calendar: calendar)
    }

    private func isActiveLoad(_ loadID: UUID) -> Bool {
        !Task.isCancelled && loadID == currentLoadID
    }

    private func trackChipSelected(kind: String, value: String) {
        analyticsTracker?(
            "reflection_chip_selected",
            baseAnalyticsMetadata(mode: target?.mode).merging(
                ["chip_kind": kind, "chip_value": value],
                uniquingKeysWith: { _, new in new }
            )
        )
    }

    private func baseAnalyticsMetadata(mode: DailyReflectionMode?) -> [String: String] {
        var metadata: [String: String] = [:]
        if let mode {
            metadata["mode"] = mode.rawValue
        }
        if let target {
            metadata["reflection_date"] = Self.dateStamp(for: target.reflectionDate, calendar: calendar)
            metadata["planning_date"] = Self.dateStamp(for: target.planningDate, calendar: calendar)
        }
        return metadata
    }

    private static func dayTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()), calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    private static func dateStamp(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: calendar.startOfDay(for: date))
    }
}
