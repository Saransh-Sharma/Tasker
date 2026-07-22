import Combine
import Observation
import SwiftUI
import UIKit

struct AdaptiveTimelineItem: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
}

struct AdaptiveHomeProjectionSnapshot: Equatable, Sendable {
    var selectedDate = Date()
    var focusTitles: [String] = []
    var overdueCount = 0
    var openTaskCount = 0
    var currentHabits: [String] = []
    var recoveryHabits: [String] = []
    var completionRate = 0.0
    var dailyScore = 0
    var streakDays = 0
    var timelineItems: [AdaptiveTimelineItem] = []
    var nextMeetingTitle: String?
    var freeUntil: Date?
    var calendarNeedsSetup = true
    var hasReflection = false
}

private struct HomeTodayStoryItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let destination: LifeBoardDestination
}

/// Converts existing Home stores into actor-safe values consumed by Adaptive Home.
/// It intentionally has no persistence or managed-object dependency of its own.
@MainActor
@Observable
final class HomeProjectionAdapter {
    private(set) var snapshot = AdaptiveHomeProjectionSnapshot()

    @ObservationIgnored private let chromeStore: HomeChromeStore
    @ObservationIgnored private let tasksStore: HomeTasksStore
    @ObservationIgnored private let habitsStore: HomeHabitsStore
    @ObservationIgnored private let calendarStore: HomeCalendarStore
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    init(
        chromeStore: HomeChromeStore,
        tasksStore: HomeTasksStore,
        habitsStore: HomeHabitsStore,
        calendarStore: HomeCalendarStore
    ) {
        self.chromeStore = chromeStore
        self.tasksStore = tasksStore
        self.habitsStore = habitsStore
        self.calendarStore = calendarStore

        chromeStore.$snapshot
            .combineLatest(tasksStore.$snapshot, habitsStore.$snapshot, calendarStore.$snapshot)
            .sink { [weak self] _, _, _, _ in self?.rebuild() }
            .store(in: &cancellables)
        rebuild()
    }

    private func rebuild() {
        let chrome = chromeStore.snapshot
        let tasks = tasksStore.snapshot
        let habits = habitsStore.snapshot
        let calendar = calendarStore.snapshot
        snapshot = AdaptiveHomeProjectionSnapshot(
            selectedDate: chrome.selectedDate,
            focusTitles: tasks.focusNowSectionState.rows.prefix(3).map(\.title),
            overdueCount: tasks.overdueTasks.lazy.filter { !$0.isComplete }.count,
            openTaskCount: tasks.todayOpenTaskCount,
            currentHabits: habits.habitHomeSectionState.primaryRows.prefix(5).map(\.title),
            recoveryHabits: habits.habitHomeSectionState.recoveryRows.prefix(3).map(\.title),
            completionRate: chrome.completionRate,
            dailyScore: chrome.dailyScore,
            streakDays: chrome.progressState.streakDays,
            timelineItems: calendar.selectedDayTimelineEvents.prefix(3).map {
                AdaptiveTimelineItem(id: $0.id, title: $0.title, startDate: $0.startDate, endDate: $0.endDate)
            },
            nextMeetingTitle: calendar.nextMeeting?.event.title,
            freeUntil: calendar.freeUntil,
            calendarNeedsSetup: calendar.moduleState == .permissionRequired || calendar.moduleState == .noCalendarsSelected,
            hasReflection: chrome.dailyReflectionEntryState != nil
        )
    }
}

@MainActor
@Observable
final class AdaptiveHomeStore {
    private(set) var layout: DashboardLayoutValue
    private(set) var draft: HomeLayoutDraft?
    private(set) var contextSelection = HomeContextSelection(candidates: [], evaluatedAt: .distantPast)
    private(set) var lastLayoutTransaction: HomeLayoutTransaction?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var showsGallery = false

    @ObservationIgnored private let repository: (any DashboardLayoutRepository)?
    @ObservationIgnored private var contextCandidates: [HomeContextCandidate] = []
    @ObservationIgnored private var permitsSensitiveContext = false
    @ObservationIgnored private let contextEngine: HomeContextEngine
    @ObservationIgnored private let contextPreferences: HomeContextPreferenceStore
    @ObservationIgnored let registry: DashboardWidgetRegistry

    init(
        repository: (any DashboardLayoutRepository)?,
        registry: DashboardWidgetRegistry = DefaultDashboardWidgetRegistry.shared,
        contextPolicy: any HomeContextPolicy = DeterministicHomeContextPolicy(),
        contextPreferences: HomeContextPreferenceStore = .init()
    ) {
        self.repository = repository
        self.registry = registry
        contextEngine = HomeContextEngine(policy: contextPolicy)
        self.contextPreferences = contextPreferences
        layout = DashboardLayoutValue(
            mode: .smart,
            isDefault: true,
            placements: CoreDataDashboardLayoutRepository.curatedHomePlacements()
        )
    }

    var activeLayout: DashboardLayoutValue { draft?.current ?? layout }
    var isCustomizing: Bool { draft != nil }

    func load() async {
        guard isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let stored = try await repository?.fetchHome() {
                layout = stored
            } else if let repository {
                layout = try await repository.resetHomeToCuratedDefault()
            }
        } catch {
            errorMessage = "Your saved Home layout could not be loaded. The curated layout is shown instead."
        }
    }

    func beginCustomization() {
        guard draft == nil else { return }
        contextEngine.setFrozen(true, reason: "home-edit")
        draft = HomeLayoutDraft(layout: layout)
    }

    func cancelCustomization() {
        draft = nil
        contextEngine.setFrozen(false, reason: "home-edit")
    }

    func saveCustomization() async {
        guard let committed = try? draft?.committedLayout() else { return }
        let transaction = HomeLayoutTransaction(before: layout, after: committed)
        layout = committed
        draft = nil
        contextEngine.setFrozen(false, reason: "home-edit")
        do {
            try await repository?.saveHome(committed)
            lastLayoutTransaction = transaction
        } catch {
            errorMessage = "Home was updated on this screen, but could not be saved."
        }
    }

    func undoLastLayoutTransaction() async {
        guard let transaction = lastLayoutTransaction else { return }
        layout = transaction.undoLayout
        lastLayoutTransaction = nil
        do {
            try await repository?.saveHome(transaction.undoLayout)
        } catch {
            errorMessage = "The previous Home layout is restored here, but could not be saved."
        }
    }

    func movePlacement(id: UUID, offset: Int) {
        guard var value = draft else { return }
        let placements = value.current.placements.sorted { $0.ordinal < $1.ordinal }
        guard let source = placements.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(0, source + offset), placements.count - 1)
        guard source != target else { return }
        value.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
        draft = value
    }

    func movePlacement(id: UUID, before targetID: UUID) {
        guard var value = draft else { return }
        let placements = value.current.placements.sorted { $0.ordinal < $1.ordinal }
        guard let source = placements.firstIndex(where: { $0.id == id }),
              let target = placements.firstIndex(where: { $0.id == targetID }),
              source != target else { return }
        value.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
        draft = value
    }

    func resizePlacement(id: UUID, to size: WidgetSizePreset) {
        guard var value = draft else { return }
        value.resize(id: id, to: size, registry: registry)
        draft = value
    }

    func cycleSize(id: UUID, expanding: Bool) {
        guard let placement = draft?.current.placements.first(where: { $0.id == id }),
              let descriptor = registry.descriptor(for: DashboardWidgetKind(rawValue: placement.widgetKind)) else { return }
        let choices = WidgetSizePreset.allCases.filter(descriptor.supportedSizes.contains)
        guard let index = choices.firstIndex(of: placement.semanticSize), choices.count > 1 else { return }
        let next = expanding ? min(index + 1, choices.count - 1) : max(index - 1, 0)
        guard next != index else { return }
        resizePlacement(id: id, to: choices[next])
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func hidePlacement(id: UUID) {
        guard var value = draft else { return }
        value.setVisible(false, id: id)
        draft = value
    }

    func toggleSmartSlot(id: UUID) {
        guard var value = draft,
              let placement = value.current.placements.first(where: { $0.id == id }) else { return }
        let nextOwnership: HomeCardOwnership = placement.ownership == .smart ? .pinned : .smart
        value.setOwnership(nextOwnership, id: id)
        draft = value
    }

    func updateSmartSlot(
        id: UUID,
        _ update: (inout HomeSmartSlotConfiguration) -> Void
    ) {
        guard var value = draft,
              let placement = value.current.placements.first(where: { $0.id == id }),
              placement.ownership == .smart else { return }
        var configuration = placement.smartSlot ?? .init()
        update(&configuration)
        value.setOwnership(.smart, smartSlot: configuration, id: id)
        draft = value
    }

    func addWidget(_ descriptor: DashboardWidgetDescriptor) {
        guard var value = draft else { return }
        value.add(kind: descriptor.kind, size: descriptor.defaultSize, registry: registry)
        if let placement = value.current.placements.last(where: { $0.widgetKind == descriptor.kind.rawValue }) {
            value.setVisible(true, id: placement.id)
        }
        draft = value
    }

    func resetDraft() {
        guard var value = draft else { return }
        value.resetToCuratedDefault()
        draft = value
    }

    func refreshContext(
        candidates: [HomeContextCandidate],
        permitsSensitiveHomeContent: Bool,
        now: Date = Date(),
        force: Bool = false
    ) {
        contextCandidates = candidates
        permitsSensitiveContext = permitsSensitiveHomeContent
        contextSelection = contextEngine.reevaluate(
            candidates: candidates,
            dispositions: contextPreferences.dispositions(at: now),
            permitsSensitiveHomeContent: permitsSensitiveHomeContent,
            now: now,
            force: force
        )
    }

    func setContextFrozen(_ frozen: Bool, reason: String) {
        contextEngine.setFrozen(frozen, reason: reason)
    }

    func hideContextForToday(_ candidate: HomeContextCandidate, now: Date = Date()) {
        contextPreferences.hideForToday(candidate.id, now: now)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    func suggestContextLessOften(_ candidate: HomeContextCandidate, now: Date = Date()) {
        contextPreferences.set(.suggestLess, for: candidate.id)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    func neverSuggestContext(_ candidate: HomeContextCandidate, now: Date = Date()) {
        contextPreferences.set(.neverSuggest, for: candidate.id)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    func pinContext(_ candidate: HomeContextCandidate) {
        if draft == nil { beginCustomization() }
        guard let descriptor = registry.descriptor(for: candidate.widgetKind) else { return }
        addWidget(descriptor)
        if var value = draft,
           let placement = value.current.placements.last(where: { $0.widgetKind == candidate.widgetKind.rawValue }) {
            value.setOwnership(.pinned, id: placement.id)
            draft = value
        }
        contextPreferences.set(.pinned, for: candidate.id)
    }

    func dismissError() { errorMessage = nil }
}

@MainActor
final class HomeContextPreferenceStore {
    private struct StoredPreferences: Codable {
        var persistent: [String: HomeContextDisposition] = [:]
        var hiddenByDay: [String: Set<String>] = [:]
    }

    private let defaults: UserDefaults
    private let key = "lifeOS.home.context.preferences.v1"
    private var stored: StoredPreferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(StoredPreferences.self, from: data) {
            stored = decoded
        } else {
            stored = .init()
        }
    }

    func dispositions(at date: Date, calendar: Calendar = .current) -> [String: HomeContextDisposition] {
        var result = stored.persistent
        for id in stored.hiddenByDay[dayKey(for: date, calendar: calendar)] ?? [] {
            result[id] = .hiddenToday
        }
        return result
    }

    func set(_ disposition: HomeContextDisposition, for candidateID: String) {
        stored.persistent[candidateID] = disposition
        persist()
    }

    func hideForToday(_ candidateID: String, now: Date, calendar: Calendar = .current) {
        stored.hiddenByDay[dayKey(for: now, calendar: calendar), default: []].insert(candidateID)
        stored.hiddenByDay = stored.hiddenByDay.filter { $0.key >= dayKey(for: now, calendar: calendar) }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: key)
    }

    private func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

public enum LifeBoardJournalMood: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case none, angry, sad, anxious, tired, calm, grateful, happy, excited

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    public static let dialOrder: [LifeBoardJournalMood] = [
        .angry, .sad, .anxious, .tired, .none, .calm, .grateful, .happy, .excited
    ]

    var supportiveCopy: String {
        switch self {
        case .none: return "Nothing to force."
        case .happy: return "Something feels lighter."
        case .calm: return "A steady moment."
        case .grateful: return "Something mattered today."
        case .excited: return "There’s energy here."
        case .tired: return "Move gently."
        case .anxious: return "Come back to now."
        case .sad: return "Hold this softly."
        case .angry: return "Name it without judging it."
        }
    }

    var largeAssetName: String {
        "LifeBoardJournal/\(assetStem)_Large"
    }

    var faceAssetName: String {
        let name: String
        switch self {
        case .none: name = "Neutral_face"
        case .tired: name = "Sleepy_face"
        default: name = "\(assetStem)_face"
        }
        return "LifeBoardJournal/\(name)"
    }

    var glowAssetName: String {
        switch self {
        case .angry, .sad, .anxious, .tired: return "LifeBoardJournal/Difficult_Glow"
        case .none: return "LifeBoardJournal/Neutral_Glow"
        case .calm, .grateful, .happy, .excited: return "LifeBoardJournal/Positive_Glow"
        }
    }

    private var assetStem: String {
        switch self {
        case .none: return "NoMood_Neutral"
        default: return rawValue.capitalized
        }
    }
}

struct LifeBoardJournalMoodDialSheet: View {
    @Binding var selectedMood: LifeBoardJournalMood
    let onSave: (Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draftMood: LifeBoardJournalMood
    @State private var stage: Stage = .mood
    @State private var energy = 3.0
    @State private var includesEnergy = false

    private enum Stage { case mood, energy }

    init(selectedMood: Binding<LifeBoardJournalMood>, onSave: @escaping (Int?) -> Void) {
        _selectedMood = selectedMood
        _draftMood = State(initialValue: selectedMood.wrappedValue)
        self.onSave = onSave
    }

    var body: some View {
        let palette = LifeBoardDaypartTokens.palette(for: .afternoon)
        ZStack {
            LinearGradient(
                colors: [palette.color(for: .canvas), palette.color(for: .canvasSecondary)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header(palette: palette)
                if stage == .mood {
                    moodStage(palette: palette)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    energyStage(palette: palette)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .foregroundStyle(palette.color(for: .foreground))
        .interactiveDismissDisabled()
        .accessibilityIdentifier("journal.moodDial.sheet")
    }

    private func header(palette: LifeBoardDaypartPalette) -> some View {
        HStack {
            Button("Cancel") { dismiss() }
                .frame(minWidth: 56, minHeight: 44)
            Spacer()
            Text(stage == .mood ? "How are you feeling?" : "And your energy?")
                .font(.headline)
            Spacer()
            Button(stage == .mood ? "Next" : "Done") {
                if stage == .mood {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) { stage = .energy }
                } else {
                    selectedMood = draftMood
                    onSave(includesEnergy ? Int(energy.rounded()) : nil)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    dismiss()
                }
            }
            .fontWeight(.semibold)
            .frame(minWidth: 56, minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private func moodStage(palette: LifeBoardDaypartPalette) -> some View {
        GeometryReader { proxy in
            VStack(spacing: 8) {
                ZStack {
                    Image(draftMood.glowAssetName)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.52)
                        .accessibilityHidden(true)
                    Image(draftMood.largeAssetName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(28)
                        .accessibilityHidden(true)
                }
                .frame(width: min(proxy.size.width * 0.62, 280), height: min(proxy.size.width * 0.48, 220))

                Text(draftMood.title)
                    .font(.system(.title, design: .rounded, weight: .semibold))
                Text(draftMood.supportiveCopy)
                    .font(.body)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))

                LifeBoardJournalMoodWheel(selectedMood: $draftMood, palette: palette)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 8)
        }
    }

    private func energyStage(palette: LifeBoardDaypartPalette) -> some View {
        VStack(spacing: 26) {
            Spacer()
            Image(draftMood.largeAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .accessibilityHidden(true)
            Text(includesEnergy ? energyLabel : "Energy is optional")
                .font(.system(.title2, design: .rounded, weight: .semibold))
            Toggle("Add an energy signal", isOn: $includesEnergy)
                .font(.headline)
                .padding(16)
                .lifeBoardRaisedClayCard(palette: palette)
            if includesEnergy {
                Slider(value: $energy, in: 1...5, step: 1) {
                    Text("Energy")
                } minimumValueLabel: {
                    Image(systemName: "battery.25")
                } maximumValueLabel: {
                    Image(systemName: "battery.100")
                }
                .tint(palette.color(for: .celestialCore))
                .accessibilityValue(energyLabel)
                .onChange(of: energy) {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            Button("Skip energy and save") {
                selectedMood = draftMood
                onSave(nil)
                dismiss()
            }
            .frame(minHeight: 44)
            Spacer()
        }
        .padding(24)
    }

    private var energyLabel: String {
        switch Int(energy.rounded()) {
        case 1: return "Very low energy"
        case 2: return "Low energy"
        case 3: return "Steady energy"
        case 4: return "High energy"
        default: return "Very high energy"
        }
    }
}

private struct LifeBoardJournalMoodWheel: View {
    @Binding var selectedMood: LifeBoardJournalMood
    let palette: LifeBoardDaypartPalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let diameter = max(420, proxy.size.width * 1.36)
            let center = CGPoint(x: proxy.size.width / 2, y: diameter / 2 + 62)
            ZStack {
                ForEach(Array(LifeBoardJournalMood.dialOrder.enumerated()), id: \.element.id) { index, mood in
                    let angle = angleDegrees(for: index)
                    let radians = angle * .pi / 180
                    Button {
                        select(mood)
                    } label: {
                        Image(mood.faceAssetName)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(width: mood == selectedMood ? 58 : 48, height: mood == selectedMood ? 58 : 48)
                            .padding(12)
                            .background(
                                mood == selectedMood
                                    ? palette.color(for: .celestialPrimary)
                                    : palette.color(for: .layerTwo).opacity(0.86),
                                in: Circle()
                            )
                            .overlay(Circle().stroke(Color.lifeboard(.textInverse).opacity(0.62), lineWidth: 1))
                            .shadow(
                                color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(mood == selectedMood ? 0.2 : 0.08),
                                radius: mood == selectedMood ? 10 : 4,
                                y: 3
                            )
                    }
                    .buttonStyle(.plain)
                    .position(
                        x: center.x + cos(radians) * diameter * 0.37,
                        y: center.y + sin(radians) * diameter * 0.37
                    )
                    .accessibilityLabel(mood.title)
                }

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.title2)
                    .foregroundStyle(palette.color(for: .foreground))
                    .position(x: proxy.size.width / 2, y: 22)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in select(nearestMood(to: value.location, center: center)) }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Mood dial")
            .accessibilityValue(selectedMood.title)
            .accessibilityHint("Swipe up or down to change mood")
            .accessibilityAdjustableAction { direction in
                let current = LifeBoardJournalMood.dialOrder.firstIndex(of: selectedMood) ?? 4
                let next: Int
                switch direction {
                case .increment: next = min(current + 1, LifeBoardJournalMood.dialOrder.count - 1)
                case .decrement: next = max(current - 1, 0)
                @unknown default: return
                }
                select(LifeBoardJournalMood.dialOrder[next])
            }
        }
    }

    private func angleDegrees(for index: Int) -> Double {
        205 + Double(index) * (130 / Double(max(1, LifeBoardJournalMood.dialOrder.count - 1)))
    }

    private func nearestMood(to point: CGPoint, center: CGPoint) -> LifeBoardJournalMood {
        let raw = atan2(point.y - center.y, point.x - center.x) * 180 / .pi
        let normalized = raw < 0 ? raw + 360 : raw
        let index = LifeBoardJournalMood.dialOrder.indices.min {
            abs(angleDegrees(for: $0) - normalized) < abs(angleDegrees(for: $1) - normalized)
        } ?? 4
        return LifeBoardJournalMood.dialOrder[index]
    }

    private func select(_ mood: LifeBoardJournalMood) {
        guard mood != selectedMood else { return }
        if reduceMotion {
            selectedMood = mood
        } else {
            withAnimation(LifeBoardAnimation.roleLocalState) { selectedMood = mood }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

struct LifeBoardOverlayHost<Overlay: View, Control: View>: View {
    let isPresented: Bool
    let overlay: () -> Overlay
    let control: () -> Control

    init(
        isPresented: Bool,
        @ViewBuilder overlay: @escaping () -> Overlay,
        @ViewBuilder control: @escaping () -> Control
    ) {
        self.isPresented = isPresented
        self.overlay = overlay
        self.control = control
    }

    var body: some View {
        VStack(spacing: 10) {
            if isPresented { overlay().transition(.move(edge: .bottom).combined(with: .opacity)) }
            control()
        }
        .frame(maxWidth: .infinity)
    }
}

struct LifeBoardAdaptiveHome: View {
    let projectionAdapter: HomeProjectionAdapter
    let preferences: LifeBoardPresentationPreferences
    let router: LifeBoardAppRouter
    let captureRouter: CaptureRouter
    let phaseIIRepository: (any LifeBoardPhaseIIRepository)?
    private let hasPlanningRepository: Bool
    private let hasTrackFoundationRepository: Bool
    private let showsEmbeddedComposer: Bool
    private let contextProviderRegistry: HomeContextCandidateProviderRegistry

    @State private var store: AdaptiveHomeStore
    @State private var lifeOSStore: HomeLifeOSProjectionStore
    @State private var selectedMood: LifeBoardJournalMood = .none
    @State private var moodEnergy: Int?
    @State private var showsMoodDial = false
    @State private var captureOrbState = CaptureOrbPresentationState()
    @State private var contextReasonCandidate: HomeContextCandidate?
    @State private var composerText = ""
    @FocusState private var composerIsFocused: Bool
    @AppStorage("lifeOS.home.sensitive_cards.enabled") private var permitsSensitiveHomeContent = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    init(
        projectionAdapter: HomeProjectionAdapter,
        preferences: LifeBoardPresentationPreferences,
        router: LifeBoardAppRouter,
        captureRouter: CaptureRouter,
        repository: (any DashboardLayoutRepository)?,
        phaseIIRepository: (any LifeBoardPhaseIIRepository)? = nil,
        planningRepository: CoreDataPlanningRepository? = nil,
        trackFoundationRepository: CoreDataTrackFoundationRepository? = nil,
        goalSampleProvider: (any GoalSampleProvider)? = nil,
        wellnessRepository: (any WellnessRepository)? = nil,
        nutritionRepository: (any NutritionRepository)? = nil,
        lifeMomentRepository: (any LifeMomentRepository)? = nil,
        showsEmbeddedComposer: Bool = true
    ) {
        self.projectionAdapter = projectionAdapter
        self.preferences = preferences
        self.router = router
        self.captureRouter = captureRouter
        self.phaseIIRepository = phaseIIRepository
        self.hasPlanningRepository = planningRepository != nil
        self.hasTrackFoundationRepository = trackFoundationRepository != nil
        self.showsEmbeddedComposer = showsEmbeddedComposer
        var candidateProviders: [any HomeContextCandidateProvider] = []
        if let planningRepository {
            candidateProviders.append(PlanningHomeContextCandidateProvider(repository: planningRepository))
        }
        if let phaseIIRepository {
            candidateProviders.append(JournalHomeContextCandidateProvider(repository: phaseIIRepository))
            candidateProviders.append(WeeklyReflectionHomeContextCandidateProvider(repository: phaseIIRepository))
            candidateProviders.append(JournalMemoryHomeContextCandidateProvider(repository: phaseIIRepository))
            candidateProviders.append(FastingHomeContextCandidateProvider(
                repository: LifeBoardFastingRepositoryAdapter(repository: phaseIIRepository)
            ))
        }
        if let trackFoundationRepository {
            candidateProviders.append(GoalHomeContextCandidateProvider(repository: trackFoundationRepository))
            candidateProviders.append(RoutineHomeContextCandidateProvider(repository: trackFoundationRepository))
        }
        if let lifeMomentRepository {
            candidateProviders.append(LifeMomentContextCandidateProvider(repository: lifeMomentRepository))
        }
        self.contextProviderRegistry = HomeContextCandidateProviderRegistry(providers: candidateProviders)
        _store = State(initialValue: AdaptiveHomeStore(repository: repository))
        _lifeOSStore = State(initialValue: HomeLifeOSProjectionStore(
            planningRepository: planningRepository,
            trackRepository: trackFoundationRepository,
            phaseIIRepository: phaseIIRepository,
            goalSampleProvider: goalSampleProvider,
            wellnessRepository: wellnessRepository,
            nutritionRepository: nutritionRepository,
            lifeMomentRepository: lifeMomentRepository
        ))
    }

    var body: some View {
        @Bindable var store = store
        let daypart = preferences.resolvedDaypart()
        let palette = LifeBoardDaypartTokens.functionalPalette(for: daypart, colorScheme: colorScheme)

        ZStack(alignment: .bottom) {
            LifeBoardScenicBackdrop(
                scene: .home,
                daypart: daypart,
                requestedTier: preferences.renderingTier,
                comfortProfile: preferences.comfortProfile
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    adaptiveHeader(daypart: daypart, palette: palette)

                    if let errorMessage = store.errorMessage {
                        LifeBoardStatusSurface(
                            state: .stale,
                            title: "Showing your safe Home layout",
                            message: errorMessage,
                            actionTitle: "Dismiss",
                            action: { store.dismissError() }
                        )
                    }

                    nowSection(palette: palette)

                    homeSectionHeading(
                        "At a glance",
                        detail: "The signals that are useful right now.",
                        palette: palette
                    )
                    signalRowWidget(palette: palette)

                    homeSectionHeading(
                        "My Home",
                        detail: store.isCustomizing
                            ? "Drag the order, resize, or make a card adaptive."
                            : "Your cards stay exactly where you put them.",
                        palette: palette
                    )
                    DashboardFlowLayout(
                        isRegular: horizontalSizeClass == .regular,
                        usesSingleColumn: dynamicTypeSize.isAccessibilitySize
                    ) {
                        ForEach(visiblePlacements) { placement in
                            dashboardWidget(for: placement, daypart: daypart, palette: palette)
                                .dashboardPreset(effectivePreset(for: placement.semanticSize))
                                .accessibilityValue(placement.ownership.accessibilityDescription)
                        }
                    }

                    if store.isCustomizing {
                        Button {
                            store.showsGallery = true
                        } label: {
                            Label("Add a widget", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                        .tint(palette.color(for: .foreground))
                    }

                    todayStorySection(palette: palette)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                // Clears the floating composer + dock chrome. The shell's
                // atmosphere background ignores the safe area, so this root
                // pads explicitly rather than relying on inset propagation.
                .padding(.bottom, showsEmbeddedComposer ? 16 : 150)
            }
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                store.setContextFrozen(phase != .idle, reason: "home-scroll")
            }

        }
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if showsEmbeddedComposer {
                lifeThreadComposer(palette: palette)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .foregroundStyle(palette.color(for: .foreground))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.load()
            await lifeOSStore.load()
            if let latest = await lifeOSStore.latestMoodCheckInToday() {
                selectedMood = latest.mood
                moodEnergy = latest.energy
            }
            refreshContextSelection(boundary: .appForeground)
        }
        .onChange(of: lifeOSStore.heroSnapshot?.id) { _, _ in refreshContextSelection(boundary: .taskMutation) }
        .onChange(of: projectionAdapter.snapshot) { _, _ in refreshContextSelection(boundary: .taskMutation) }
        .onChange(of: permitsSensitiveHomeContent) { _, _ in refreshContextSelection() }
        .onChange(of: daypart) { _, _ in refreshContextSelection(boundary: .daypartBoundary) }
        .onChange(of: voiceOverEnabled, initial: true) { _, enabled in
            store.setContextFrozen(enabled, reason: "voiceover-focus")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshContextSelection(boundary: .appForeground) }
        }
        .sheet(isPresented: $store.showsGallery) {
            AdaptiveWidgetGallery(store: store, preferences: preferences)
        }
        .fullScreenCover(isPresented: $showsMoodDial) {
            LifeBoardJournalMoodDialSheet(selectedMood: $selectedMood) { energy in
                moodEnergy = energy
                Task {
                    await lifeOSStore.saveMood(selectedMood, energy: energy)
                    refreshContextSelection(boundary: .trackerCommit)
                }
            }
        }
        .sheet(item: $contextReasonCandidate) { candidate in
            contextReasonSheet(candidate, palette: palette)
                .presentationDetents([.height(300), .medium])
                .presentationDragIndicator(.visible)
        }
        .animation(motionAnimation, value: router.dashboardMode)
        .animation(motionAnimation, value: daypart)
        .animation(motionAnimation, value: store.contextSelection)
    }

    private func refreshContextSelection(
        now: Date = Date(),
        boundary: HomeContextRefreshBoundary = .explicitRefresh
    ) {
        let local = homeContextCandidates(now: now)
        let permitsSensitive = permitsSensitiveHomeContent
        Task {
            let domainCandidates = await contextProviderRegistry.candidates(
                context: .init(date: now, refreshBoundary: boundary)
            )
            store.refreshContext(
                candidates: local + domainCandidates,
                permitsSensitiveHomeContent: permitsSensitive,
                now: now
            )
            await refreshCardSnapshots(now: now)
        }
    }

    /// Resolves provider snapshots for every currently visible placement at
    /// its effective size, so glance/compact bodies read domain providers
    /// instead of canonical stores.
    private func refreshCardSnapshots(now: Date = Date()) async {
        let daypart = preferences.resolvedDaypart()
        var seen = Set<String>()
        var requests: [(kind: DashboardWidgetKind, size: HomeCardSize)] = []
        for placement in visiblePlacements {
            let kind = resolvedWidgetKind(for: placement, daypart: daypart)
            let size = effectivePreset(for: placement.semanticSize)
            let key = HomeLifeOSProjectionStore.cardSnapshotKey(kind, size)
            guard seen.insert(key).inserted else { continue }
            requests.append((kind, size))
        }
        await lifeOSStore.refreshCardSnapshots(
            requests: requests,
            permitsSensitive: permitsSensitiveHomeContent,
            at: now
        )
    }

    private func homeContextCandidates(now: Date) -> [HomeContextCandidate] {
        var candidates: [HomeContextCandidate] = []
        if let hero = lifeOSStore.heroSnapshot {
            let destination: LifeBoardDestination = switch hero.priority {
            case .safetySensitiveCare, .timedRoutine: .track
            case .activeFocus, .fixedCommitment, .urgentPlannedWork, .generalFocus, .recovery: .plan
            }
            let kind: DashboardWidgetKind = switch hero.priority {
            case .safetySensitiveCare: .care
            case .timedRoutine: .routines
            case .fixedCommitment: .compactTimeline
            default: .focusNow
            }
            candidates.append(
                .init(
                    id: hero.id,
                    widgetKind: kind,
                    title: hero.title,
                    reason: .init(
                        message: hero.detail ?? "This is the most useful active context right now.",
                        signal: hero.priority == .activeFocus ? "active focus" : "current context"
                    ),
                    destination: destination,
                    sensitivity: hero.priority == .safetySensitiveCare ? .privateSensitive : .privateStandard,
                    priority: hero.priority.rawValue,
                    relevantFrom: now,
                    isUserStartedActiveState: hero.priority == .activeFocus
                )
            )
        }
        return candidates
    }

    /// Alive, personal header line echoing the reference: the current time and
    /// weekday, plus a gentle count of what actually needs the user right now.
    private func headerSubtitle(now: Date) -> String {
        let time = now.formatted(date: .omitted, time: .shortened)
        let day = projectionAdapter.snapshot.selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let base = "It’s \(time), \(day)"
        let attention = attentionCount
        guard attention > 0 else { return base }
        return "\(base) · \(attention) need\(attention == 1 ? "s" : "") you"
    }

    /// Count of items honestly asking for a decision: unresolved medication
    /// windows, Must Do work, and due routines. Never inflated by ambient data.
    private var attentionCount: Int {
        let care = lifeOSStore.trackSnapshot?.unresolvedMedicationEvents.filter { $0.status == .unresolved }.count ?? 0
        let mustDo = lifeOSStore.planSnapshot?.plannedTasks.filter { $0.metadata.commitmentLevel == .mustDo }.count ?? 0
        let routines = lifeOSStore.trackSnapshot?.dueRoutines.count ?? 0
        return care + mustDo + routines
    }

    private func homeSectionHeading(
        _ title: String,
        detail: String,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(detail)
                .font(.caption.weight(.medium))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func nowSection(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            homeSectionHeading(
                "Now",
                detail: "A small, explainable view of what matters next.",
                palette: palette
            )
            if store.contextSelection.candidates.isEmpty {
                focusNowWidget(palette: palette)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(Array(store.contextSelection.candidates.enumerated()), id: \.element.id) { index, candidate in
                            contextCard(
                                candidate,
                                palette: palette,
                                accessibilityIdentifier: index == 0 ? "home.hero" : "home.context.\(candidate.id)"
                            )
                                .frame(maxWidth: .infinity)
                        }
                    }
                    VStack(spacing: 12) {
                        ForEach(Array(store.contextSelection.candidates.enumerated()), id: \.element.id) { index, candidate in
                            contextCard(
                                candidate,
                                palette: palette,
                                accessibilityIdentifier: index == 0 ? "home.hero" : "home.context.\(candidate.id)"
                            )
                        }
                    }
                }
            }
        }
        // The whole explainable "Now" region is the canonical Home hero.
        // Its contents can legitimately swap from Focus to a context card as
        // providers hydrate, so the stable identity belongs on the region.
        .accessibilityIdentifier("home.hero")
    }

    private func contextCard(
        _ candidate: HomeContextCandidate,
        palette: LifeBoardDaypartPalette,
        accessibilityIdentifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol(for: candidate.widgetKind))
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(palette.color(for: .canvasSecondary), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.title)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .lineLimit(2)
                    Text(candidate.reason.message)
                        .font(.caption)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Menu {
                    Button("Why this?", systemImage: "info.circle") {
                        contextReasonCandidate = candidate
                    }
                    Button("Keep on Home", systemImage: "pin") {
                        store.pinContext(candidate)
                        Task { await store.saveCustomization() }
                    }
                    Button("Hide for today", systemImage: "sun.horizon") {
                        store.hideContextForToday(candidate)
                    }
                    Button("Suggest less often", systemImage: "arrow.down.right") {
                        store.suggestContextLessOften(candidate)
                    }
                    Button("Never suggest this", systemImage: "eye.slash", role: .destructive) {
                        store.neverSuggestContext(candidate)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(candidate.title)")
            }

            Button {
                router.select(candidate.destination)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                HStack {
                    Text("Open \(candidate.destination.title)")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .lifeBoardFloatingClayCard(palette: palette)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(candidate.title)
        .accessibilityHint(candidate.reason.message)
        .accessibilityIdentifier(accessibilityIdentifier)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in store.setContextFrozen(true, reason: "context-touch") }
                .onEnded { _ in store.setContextFrozen(false, reason: "context-touch") }
        )
    }

    private func contextReasonSheet(
        _ candidate: HomeContextCandidate,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                Text("Why this is here")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Spacer()
            }
            Text(candidate.reason.message)
                .font(.body)
            Label("Based on \(candidate.reason.signal)", systemImage: "checkmark.shield")
                .font(.subheadline)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Spacer()
            Button("Keep on Home") {
                store.pinContext(candidate)
                contextReasonCandidate = nil
                Task { await store.saveCustomization() }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid))
    }

    private func todayStorySection(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            homeSectionHeading(
                "Today Story",
                detail: "The small moments that are shaping your day.",
                palette: palette
            )
            VStack(spacing: 0) {
                ForEach(todayStoryItems) { item in
                    Button {
                        router.select(item.destination)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 15, weight: .semibold))
                                .frame(width: 30, height: 30)
                                .background(palette.color(for: .canvasSecondary), in: Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(item.detail)
                                    .font(.caption)
                                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
                        .padding(.vertical, 13)
                    }
                    .buttonStyle(.plain)
                    if item.id != todayStoryItems.last?.id {
                        Divider().padding(.leading, 42)
                    }
                }
            }
            .padding(.horizontal, 14)
            .lifeBoardRaisedClayCard(palette: palette)
        }
        .accessibilityIdentifier("home.todayStory")
    }

    private var todayStoryItems: [HomeTodayStoryItem] {
        var items: [HomeTodayStoryItem] = []
        if projectionAdapter.snapshot.openTaskCount > 0 {
            items.append(.init(
                id: "tasks",
                title: "Today is still in motion",
                detail: "\(projectionAdapter.snapshot.openTaskCount) open tasks remain; choose what still deserves today.",
                symbol: "checklist",
                destination: .plan
            ))
        }
        if let mood = lifeOSStore.latestMood {
            items.append(.init(
                id: "mood",
                title: "You checked in as \(mood.mood.title.lowercased())",
                detail: mood.energy.map { "Energy was \($0) out of 5." } ?? "No energy score was needed.",
                symbol: "face.smiling",
                destination: .track
            ))
        }
        if projectionAdapter.snapshot.completionRate > 0 {
            items.append(.init(
                id: "progress",
                title: "Progress is settling in",
                detail: "\(Int(projectionAdapter.snapshot.completionRate * 100))% of today’s planned work is complete.",
                symbol: "chart.line.uptrend.xyaxis",
                destination: .insights
            ))
        }
        if items.isEmpty {
            items.append(.init(
                id: "empty",
                title: "The day is still open",
                detail: "Capture one thought or choose one useful next step.",
                symbol: "sparkles",
                destination: .eva
            ))
        }
        return Array(items.prefix(3))
    }

    private func lifeThreadComposer(palette: LifeBoardDaypartPalette) -> some View {
        HStack(spacing: 10) {
            Menu {
                Button("Task", systemImage: "checkmark.circle") {
                    captureRouter.request(kind: .task, source: .shell)
                }
                Button("Journal", systemImage: "book.closed") {
                    captureRouter.request(kind: .journal, source: .shell)
                }
                Button("Mood + Energy", systemImage: "face.smiling") {
                    captureRouter.request(kind: .mood, source: .shell)
                }
                Button("Hydration", systemImage: "drop.fill") {
                    captureRouter.request(kind: .hydration, source: .shell)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 42)
            }
            .accessibilityLabel("Capture something")

            TextField("Talk to Eva or capture anything", text: $composerText, axis: .vertical)
                .lineLimit(1...4)
                .focused($composerIsFocused)
                .submitLabel(.send)
                .onSubmit(submitComposer)
                .accessibilityIdentifier("home.lifeThread.composer")

            Button(action: composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                   ? { captureRouter.request(kind: .journal, source: .shell) }
                   : submitComposer) {
                Image(systemName: composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      ? "waveform"
                      : "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                    .frame(width: 42, height: 42)
                    .background(Color(LifeBoardColorTokens.inkPrimary), in: Circle())
            }
            .accessibilityLabel(
                composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? "Record in Journal"
                    : "Send to Eva"
            )
        }
        .padding(8)
        .lifeBoardGlassSurface(cornerRadius: 27, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
        }
        .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.18), radius: 14, y: 8)
    }

    private func submitComposer() {
        let prompt = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }
        do {
            try EvaChatLaunchRequestStore.shared.submit(.init(prompt: prompt))
            composerText = ""
            composerIsFocused = false
            router.select(.eva)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } catch {
            store.dismissError()
        }
    }

    private func symbol(for kind: DashboardWidgetKind) -> String {
        store.registry.descriptor(for: kind)?.systemImage ?? "square.grid.2x2"
    }

    private var visiblePlacements: [DashboardWidgetPlacementValue] {
        store.activeLayout.placements
            .filter {
                $0.isVisible
                    && $0.widgetKind != DashboardWidgetKind.focusNow.rawValue
                    && $0.widgetKind != DashboardWidgetKind.lifeSnapshot.rawValue
                    // The compact shell already exposes universal capture in its
                    // measured safe-area host. Avoid presenting the same action
                    // twice or letting the dashboard tile visually compete with it.
                    && ($0.widgetKind != DashboardWidgetKind.quickCapture.rawValue || horizontalSizeClass == .regular)
                    && store.registry.descriptor(for: DashboardWidgetKind(rawValue: $0.widgetKind)) != nil
            }
            .sorted { $0.ordinal < $1.ordinal }
    }

    private var motionAnimation: Animation? {
        guard reduceMotion == false, preferences.comfortProfile != .calm else {
            return .easeInOut(duration: 0.18)
        }
        return .spring(response: 0.38, dampingFraction: 0.86)
    }

    @ViewBuilder
    private func adaptiveHeader(daypart: ResolvedDaypart, palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Menu {
                    ForEach(DashboardMode.allCases, id: \.self) { mode in
                        Button {
                            router.dashboardMode = mode
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Label(mode.title, systemImage: mode.systemImage)
                        }
                    }
                } label: {
                    if dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: router.dashboardMode.systemImage)
                            .font(.title2.weight(.semibold))
                            .frame(width: 44, height: 44)
                    } else {
                        HStack(spacing: 6) {
                            Text(router.dashboardMode.title)
                                .font(LifeBoardFoundationTypography.sectionTitle())
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                }
                .accessibilityLabel("Dashboard mode, \(router.dashboardMode.title)")
                .accessibilityIdentifier("home.dashboardMode.menu")

                Spacer()

                if store.isCustomizing {
                    Button("Cancel") { store.cancelCustomization() }
                        .frame(minHeight: 44)
                    Button("Done") { Task { await store.saveCustomization() } }
                        .fontWeight(.semibold)
                        .frame(minHeight: 44)
                } else {
                    if store.lastLayoutTransaction != nil {
                        Button("Undo") {
                            Task { await store.undoLastLayoutTransaction() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityHint("Restores the previous Home arrangement")
                    }
                    if V2FeatureFlags.dashboardCustomizationV2Enabled {
                        Button {
                            store.beginCustomization()
                        } label: {
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Customize Home")
                        .accessibilityIdentifier("home.customize")
                    }
                }
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(router.dashboardMode == .lowEnergy ? "Let’s take it gently" : daypart.greeting)
                        .font(LifeBoardFoundationTypography.hero())
                        .minimumScaleFactor(0.76)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .accessibilityIdentifier("home.header")
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(headerSubtitle(now: context.date))
                            .font(LifeBoardFoundationTypography.body())
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                            .contentTransition(.numericText())
                    }
                }
                Spacer(minLength: 4)
                Menu {
                    ForEach(DaypartSelection.allCases, id: \.self) { selection in
                        Button {
                            preferences.daypartSelection = selection
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            Label(selection.title, systemImage: selection.systemImage)
                        }
                    }
                    if preferences.activeDaypartOverride != nil {
                        Divider()
                        Button("Return to Auto", systemImage: "clock.arrow.circlepath") {
                            preferences.returnToAutomaticDaypart()
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(palette.color(for: .celestialPrimary))
                            .frame(width: 58, height: 58)
                            .shadow(color: palette.color(for: .celestialCore).opacity(0.35), radius: 12)
                        Image(systemName: DaypartSelection(rawValue: daypart.rawValue)?.systemImage ?? "sun.max")
                            .font(.system(size: 22, weight: .semibold))
                    }
                }
                .accessibilityLabel("Daypart, \(daypart.rawValue)")
                .accessibilityHint(preferences.activeDaypartOverride == nil ? "Automatic" : "Manual override active")
                .accessibilityIdentifier("home.daypart.menu")
            }

            if let override = preferences.activeDaypartOverride {
                Button {
                    preferences.returnToAutomaticDaypart()
                } label: {
                    Label("Manual until \(override.expiresAt.formatted(date: .omitted, time: .shortened)) · Return to Auto", systemImage: "clock")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .frame(minHeight: 32)
            }
        }
    }

    @ViewBuilder
    private func dashboardWidget(
        for placement: DashboardWidgetPlacementValue,
        daypart: ResolvedDaypart,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        let kind = resolvedWidgetKind(for: placement, daypart: daypart)
        let preset = effectivePreset(for: placement.semanticSize)
        VStack(spacing: store.isCustomizing ? 6 : 0) {
            if store.isCustomizing {
                HStack(spacing: 8) {
                    Label(
                        placement.ownership == .smart ? "Smart" : "Pinned",
                        systemImage: placement.ownership == .smart ? "sparkles" : "pin.fill"
                    )
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 9)
                    .frame(minHeight: 30)
                    .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: Capsule())
                    .accessibilityLabel(placement.ownership.accessibilityDescription)

                    Spacer(minLength: 0)
                    customizationControls(for: placement, daypart: daypart, palette: palette)
                }
                .padding(.horizontal, 4)
            }

            Group {
                if preset == .compact {
                    glanceWidget(kind: kind, daypart: daypart, palette: palette)
                } else if preset == .standard {
                    // Standard cards must preserve their meaningful primary actions.
                    // Collapsing these into a generic "Open" tile made capture,
                    // recovery, and evidence routes undiscoverable in the curated
                    // two-column Home layout.
                    switch kind {
                    case .care:
                        careWidget(daypart: daypart, palette: palette)
                    case .tasks:
                        tasksWidget(palette: palette)
                    case .routines:
                        routinesWidget(daypart: daypart, palette: palette)
                    case .scheduleCapacity:
                        capacityWidget(palette: palette)
                    case .journal:
                        journalWidget(palette: palette)
                    case .progressReflection:
                        progressWidget(palette: palette)
                    default:
                        compactWidget(kind: kind, daypart: daypart, palette: palette)
                    }
                } else {
                    switch kind {
                    case .focusNow:
                        focusNowWidget(palette: palette)
                    case .lifeSnapshot:
                        lifeSnapshotWidget(palette: palette)
                    case .care:
                        careWidget(daypart: daypart, palette: palette)
                    case .tasks:
                        tasksWidget(palette: palette)
                    case .routines:
                        routinesWidget(daypart: daypart, palette: palette)
                    case .scheduleCapacity:
                        capacityWidget(palette: palette)
                    case .quickCapture:
                        quickCaptureWidget(palette: palette)
                    case .compactTimeline:
                        timelineWidget(palette: palette)
                    case .journal:
                        journalWidget(palette: palette)
                    case .progressReflection:
                        progressWidget(palette: palette)
                    case .fasting:
                        fastingWidget(palette: palette)
                    default:
                        EmptyView()
                    }
                }
            }
            .frame(minHeight: preset.minimumCardHeight)
        }
        .modifier(
            HomeCardReorderModifier(
                placementID: placement.id,
                isEnabled: store.isCustomizing,
                onMove: { sourceID, targetID in store.movePlacement(id: sourceID, before: targetID) },
                onResize: { expanding in store.cycleSize(id: placement.id, expanding: expanding) }
            )
        )
        .onLongPressGesture(minimumDuration: 0.45) {
            guard store.isCustomizing == false else { return }
            withAnimation(motionAnimation) { store.beginCustomization() }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        .accessibilityAction(named: "Customize") { store.beginCustomization() }
    }

    private func glanceWidget(
        kind: DashboardWidgetKind,
        daypart: ResolvedDaypart,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        let descriptor = store.registry.descriptor(for: kind)
        return Button {
            openWidget(kind)
        } label: {
            HStack(spacing: 11) {
                Image(systemName: descriptor?.systemImage ?? "square.grid.2x2")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .frame(width: 30, height: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text(descriptor?.title ?? "LifeBoard")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(1)
                    Text(widgetSummary(kind, daypart: daypart, size: .compact))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(palette.color(for: .foreground))
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .lifeBoardRaisedClayCard(palette: palette)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the source")
    }

    private func compactWidget(
        kind: DashboardWidgetKind,
        daypart: ResolvedDaypart,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        let descriptor = store.registry.descriptor(for: kind)
        return Button {
            openWidget(kind)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    Image(systemName: descriptor?.systemImage ?? "square.grid.2x2")
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(descriptor?.title ?? "LifeBoard")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text(widgetSummary(kind, daypart: daypart, size: .standard))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text("Open")
                    Image(systemName: "arrow.up.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            .frame(maxWidth: .infinity, minHeight: 146, alignment: .leading)
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .lifeBoardRaisedClayCard(palette: palette)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the source")
    }

    private func widgetSummary(
        _ kind: DashboardWidgetKind,
        daypart: ResolvedDaypart,
        size: HomeCardSize = .compact
    ) -> String {
        // Canonical path: display-ready snapshot resolved by the domain
        // provider registry. The legacy switch below remains only as a
        // first-frame fallback before the first provider resolution lands.
        if let snapshot = lifeOSStore.cardSnapshot(kind: kind, size: size) {
            let parts = [snapshot.value, snapshot.detail].compactMap { $0 }
            if parts.isEmpty == false { return parts.joined(separator: " · ") }
        }
        switch kind {
        case .focusNow:
            return lifeOSStore.heroSnapshot?.title
                ?? lifeOSStore.focusTask?.title
                ?? projectionAdapter.snapshot.focusTitles.first
                ?? "Choose one kind next step"
        case .lifeSnapshot:
            return "\(projectionAdapter.snapshot.dailyScore) today · \(projectionAdapter.snapshot.openTaskCount) open"
        case .care:
            return "\(homeHydrationLabel) · \(homeMedicationLabel)"
        case .tasks:
            return projectionAdapter.snapshot.openTaskCount == 0
                ? "Nothing is asking for attention"
                : "\(projectionAdapter.snapshot.openTaskCount) open today"
        case .routines:
            let count = lifeOSStore.trackSnapshot?.dueRoutines.count ?? projectionAdapter.snapshot.currentHabits.count
            return count == 0 ? "All clear for this \(daypart.rawValue)" : "\(count) ready this \(daypart.rawValue)"
        case .scheduleCapacity:
            if let capacity = lifeOSStore.planSnapshot?.capacity {
                return capacity.overloadDuration > 0
                    ? "\(homeDuration(capacity.overloadDuration)) over capacity"
                    : "\(homeDuration(capacity.remainingKnownCapacity)) of known room"
            }
            return projectionAdapter.snapshot.freeUntil.map {
                "Open until \($0.formatted(date: .omitted, time: .shortened))"
            } ?? "No reliable free window yet"
        case .quickCapture:
            return "Capture a task, thought, mood, or moment"
        case .compactTimeline:
            return projectionAdapter.snapshot.timelineItems.first.map {
                "\($0.startDate.formatted(date: .omitted, time: .shortened)) · \($0.title)"
            } ?? "Your next commitment will appear here"
        case .journal:
            return projectionAdapter.snapshot.hasReflection
                ? "Today’s reflection is ready to revisit"
                : "Keep one honest moment from today"
        case .progressReflection:
            return "\(projectionAdapter.snapshot.completionRate.formatted(.percent)) complete · \(projectionAdapter.snapshot.streakDays) day continuity"
        case .fasting:
            guard let fast = lifeOSStore.activeFast else { return "No fast is active" }
            return "\(homeDuration(fast.elapsed())) elapsed"
        default:
            return "Open in LifeBoard"
        }
    }

    private func openWidget(_ kind: DashboardWidgetKind) {
        switch kind {
        case .focusNow, .tasks:
            router.select(.plan)
        case .lifeSnapshot, .care, .routines:
            router.select(.track)
        case .scheduleCapacity, .compactTimeline:
            router.navigate(.planDay, in: .plan)
        case .quickCapture:
            composerIsFocused = true
        case .journal:
            router.select(.track)
        case .progressReflection:
            router.select(.insights)
        case .fasting:
            router.select(.track)
        default:
            break
        }
    }

    private func focusNowWidget(palette: LifeBoardDaypartPalette) -> some View {
        let hero = lifeOSStore.heroSnapshot
        let primary = hero?.title ?? lifeOSStore.focusTask?.title ?? projectionAdapter.snapshot.focusTitles.first
        let lowEnergy = router.dashboardMode == .lowEnergy
        let expanded = hero?.priority == .activeFocus || hero?.priority == .safetySensitiveCare || hero?.priority == .recovery
        return HStack(spacing: 12) {
            Image(systemName: lowEnergy ? "leaf.fill" : heroSymbol(for: hero?.priority))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .frame(width: 28, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(lowEnergy ? "One small thing" : heroLabel(for: hero?.priority))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                Text(primary ?? (lowEnergy ? "Drink some water and take one quiet minute." : "Choose one useful next step"))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(expanded ? 2 : 1)
                if expanded, let reason = hero?.detail ?? lifeOSStore.focusResult?.reasons.first?.text {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                performHeroPrimaryAction(hero)
            } label: {
                Text(compactHeroActionTitle(hero?.primaryActionTitle ?? (primary == nil ? "Choose" : "Start")))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Color(LifeBoardColorTokens.inkPrimary), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 112)
            .accessibilityHint(hero?.secondaryActionTitles.first.map { "More actions include \($0)." } ?? "")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: expanded ? 104 : 80)
        .lifeBoardFloatingClayCard(palette: palette)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.hero")
    }

    private func heroLabel(for priority: AdaptiveHeroPriority?) -> String {
        switch priority {
        case .activeFocus: "Focus in progress"
        case .safetySensitiveCare: "Care needs a decision"
        case .fixedCommitment: "Current commitment"
        case .urgentPlannedWork: "Must Do"
        case .timedRoutine: "Routine"
        case .recovery: "Recovery"
        case .generalFocus, .none: "Focus Now"
        }
    }

    private func heroSymbol(for priority: AdaptiveHeroPriority?) -> String {
        switch priority {
        case .activeFocus: "timer"
        case .safetySensitiveCare: "cross.case"
        case .fixedCommitment: "calendar"
        case .urgentPlannedWork: "exclamationmark.circle"
        case .timedRoutine: "list.bullet.clipboard"
        case .recovery: "arrow.counterclockwise"
        case .generalFocus, .none: "scope"
        }
    }

    private func compactHeroActionTitle(_ title: String) -> String {
        switch title {
        case "Choose a focus": "Choose"
        case "Open focus", "Open day": "Open"
        default: title
        }
    }

    private func performHeroPrimaryAction(_ hero: AdaptiveHeroSnapshot?) {
        guard let hero else {
            captureRouter.request(kind: .task, source: .shell)
            return
        }
        switch hero.priority {
        case .safetySensitiveCare, .timedRoutine:
            router.select(.track)
        case .activeFocus, .fixedCommitment, .urgentPlannedWork, .generalFocus, .recovery:
            router.select(.plan)
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func performHeroSecondaryAction(_ hero: AdaptiveHeroSnapshot?) {
        guard let hero else { return }
        switch hero.priority {
        case .safetySensitiveCare, .timedRoutine: router.select(.track)
        default: router.select(.plan)
        }
    }

    @ViewBuilder
    private func signalRowWidget(palette: LifeBoardDaypartPalette) -> some View {
        let hydrationAmount = lifeOSStore.trackSnapshot?.hydrationAmountMilliliters
        let hydrationTarget = lifeOSStore.trackSnapshot?.hydrationTargetMilliliters
        let hydrationProgress = hydrationAmount.flatMap { amount in
            hydrationTarget.flatMap { $0 > 0 ? min(1, amount / $0) : nil }
        }
        let hydrationAvailability: HomeSignalState = if lifeOSStore.isLoading {
            .loading
        } else if hasTrackFoundationRepository == false {
            .unavailable
        } else if hydrationAmount == nil {
            .setupRequired
        } else {
            .available
        }
        let slots = [
            HomeSignalSlot(
                id: "hydration", title: "Hydration",
                valueText: hydrationAmount.map { "\(Int($0)) ml" }, progress: hydrationProgress,
                systemImage: "drop.fill",
                availability: hydrationAvailability
            ),
            HomeSignalSlot(id: "steps", title: "Steps", systemImage: "figure.walk", availability: .permissionRequired),
            HomeSignalSlot(id: "active", title: "Active", systemImage: "flame.fill", availability: .permissionRequired),
            HomeSignalSlot(
                id: "fasting",
                title: "Fasting",
                valueText: lifeOSStore.activeFast.map { homeDuration($0.elapsed()) },
                progress: lifeOSStore.activeFast.flatMap { fast in
                    fast.targetDuration.flatMap { $0 > 0 ? min(1, fast.elapsed() / $0) : nil }
                },
                systemImage: "timer",
                availability: lifeOSStore.activeFast == nil ? .setupRequired : .available
            )
        ]
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(slots) { slot in compactSignalRing(slot, palette: palette) }
            }
            .accessibilityIdentifier("home.signalRow")
        } else {
            HStack(spacing: 8) {
                ForEach(slots) { slot in compactSignalRing(slot, palette: palette) }
            }
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("home.signalRow")
        }
    }

    private func compactSignalRing(_ slot: HomeSignalSlot, palette: LifeBoardDaypartPalette) -> some View {
        Button {
            if slot.id == "hydration" { captureRouter.request(kind: .hydration, source: .shell) }
            else { router.select(.track) }
        } label: {
            LifeBoardMetricRing(
                label: slot.title,
                state: ringState(for: slot),
                diameter: 58,
                palette: palette,
                liquidTint: liquidTint(for: slot, palette: palette)
            )
            .frame(maxWidth: .infinity, minHeight: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(slot.title), \(slot.valueText ?? accessibilityAvailability(slot.availability))")
        .accessibilityIdentifier("home.signal.\(slot.id)")
    }

    /// Water-like signals fill with liquid; movement signals keep the plain
    /// arc so the metaphor stays honest.
    private func liquidTint(for slot: HomeSignalSlot, palette: LifeBoardDaypartPalette) -> Color? {
        guard slot.availability == .available || slot.availability == .stale else { return nil }
        switch slot.id {
        case "hydration": return Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.55)
        case "fasting": return Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.6)
        default: return nil
        }
    }

    private func ringState(for slot: HomeSignalSlot) -> LifeBoardMetricRing.RingState {
        switch slot.availability {
        case .loading:
            return .loading
        case .setupRequired, .permissionRequired:
            return .setupRequired
        case .unavailable:
            return .unavailable
        case .stale:
            guard let value = slot.valueText else { return .unavailable }
            return .stale(progress: slot.progress ?? 0, centerText: value)
        case .available:
            guard let value = slot.valueText else { return .setupRequired }
            let progress = slot.progress ?? 0
            if progress == 0 { return .zero(centerText: value) }
            return progress >= 1 ? .complete(centerText: value) : .value(progress: progress, centerText: value)
        }
    }

    private func accessibilityAvailability(_ availability: HomeSignalSlot.Availability) -> String {
        switch availability {
        case .available: "available"
        case .loading: "loading"
        case .setupRequired: "setup required"
        case .permissionRequired: "permission required"
        case .stale: "out of date"
        case .unavailable: "unavailable"
        }
    }

    private func lifeSnapshotWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            widgetTitle("How life feels", symbol: "heart.text.square", palette: palette)
                .accessibilityIdentifier("home.widget.lifeSnapshot")
            HStack(spacing: 10) {
                snapshotMetric(
                    id: "mood",
                    symbol: "face.smiling",
                    value: selectedMood == .none ? "Check in" : selectedMood.title,
                    label: moodEnergy.map { "Mood · E\($0)" } ?? "Mood",
                    palette: palette
                ) {
                    showsMoodDial = true
                }
                snapshotMetric(
                    id: "hydration",
                    symbol: "drop.fill",
                    value: homeHydrationLabel,
                    label: "Hydration",
                    palette: palette
                ) { captureRouter.request(kind: .hydration, source: .shell) }
                snapshotMetric(id: "steps", symbol: "figure.walk", value: "Connect", label: "Steps", palette: palette) {
                    router.select(.track)
                }
                if router.dashboardMode != .lowEnergy {
                    snapshotMetric(id: "active", symbol: "flame.fill", value: "Connect", label: "Active", palette: palette) {
                        router.select(.track)
                    }
                }
            }
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func careWidget(daypart: ResolvedDaypart, palette: LifeBoardDaypartPalette) -> some View {
        let medicationEvents = lifeOSStore.trackSnapshot?.unresolvedMedicationEvents ?? []
        return VStack(alignment: .leading, spacing: 13) {
            widgetTitle("\(daypart.rawValue.capitalized) care", symbol: "cross.case.fill", palette: palette)
                .accessibilityIdentifier("home.widget.care")
            if medicationEvents.isEmpty {
                honestEmptyState("No unresolved care decisions", symbol: "checkmark.circle", palette: palette)
            } else {
                ForEach(medicationEvents.prefix(router.dashboardMode == .lowEnergy ? 1 : 3)) { event in
                    Button {
                        router.navigate(.careLibrary, in: .track)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "pills")
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                            Text("Medication decision")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(event.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.care.event.\(event.id.uuidString)")
                }
            }
            Divider().overlay(Color(LifeBoardColorTokens.foundationHairline))
            Button("Open Care") { router.navigate(.careLibrary, in: .track) }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.care.open")
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func tasksWidget(palette: LifeBoardDaypartPalette) -> some View {
        let snapshot = lifeOSStore.planSnapshot
        let tasks = (snapshot?.plannedTasks ?? []) + (snapshot?.unscheduledTasks ?? [])
        return VStack(alignment: .leading, spacing: 12) {
            widgetTitle("Today’s tasks", symbol: "checklist", palette: palette)
                .accessibilityIdentifier("home.widget.tasks")
            if hasPlanningRepository == false {
                honestEmptyState("Tasks are unavailable right now", symbol: "exclamationmark.triangle", palette: palette)
            } else if lifeOSStore.isLoading, snapshot == nil {
                honestEmptyState("Loading tasks", symbol: "hourglass", palette: palette)
            } else if tasks.isEmpty {
                honestEmptyState("Nothing is asking for your attention", symbol: "checkmark.circle", palette: palette)
            } else {
                ForEach(tasks.prefix(router.dashboardMode == .lowEnergy ? 2 : 4)) { task in
                    Button {
                        router.navigate(.taskDetail(task.id), in: .home)
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: task.metadata.commitmentLevel == .mustDo ? "exclamationmark.circle.fill" : "circle")
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                            Text(task.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("home.task.\(task.id.uuidString)")
                }
            }
            Button {
                captureRouter.request(kind: .task, source: .widget)
            } label: {
                Label("Add a task", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.tasks.add")
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func routinesWidget(daypart: ResolvedDaypart, palette: LifeBoardDaypartPalette) -> some View {
        let dueRoutines = lifeOSStore.trackSnapshot?.dueRoutines ?? []
        let habitTitles = projectionAdapter.snapshot.recoveryHabits + projectionAdapter.snapshot.currentHabits
        return VStack(alignment: .leading, spacing: 12) {
            widgetTitle("\(daypart.rawValue.capitalized) routines", symbol: "repeat", palette: palette)
                .accessibilityIdentifier("home.widget.routines")
            if hasTrackFoundationRepository == false {
                honestEmptyState("Routines are unavailable right now", symbol: "exclamationmark.triangle", palette: palette)
            } else if lifeOSStore.isLoading, lifeOSStore.trackSnapshot == nil {
                honestEmptyState("Loading routines", symbol: "hourglass", palette: palette)
            } else if dueRoutines.isEmpty, habitTitles.isEmpty {
                honestEmptyState("No routines are due in this part of the day", symbol: "checkmark.circle", palette: palette)
            } else {
                ForEach(dueRoutines.prefix(router.dashboardMode == .lowEnergy ? 1 : 3)) { routine in
                    Button {
                        router.navigate(.routine(routine.id), in: .home)
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "figure.mind.and.body")
                            Text(routine.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(palette.color(for: .foreground))
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("home.routine.\(routine.id.uuidString)")
                }
                if dueRoutines.isEmpty, let habit = habitTitles.first {
                    Button {
                        router.navigate(.habitBoard, in: .track)
                    } label: {
                        HStack {
                            Image(systemName: "repeat")
                            Text(habit).font(.subheadline.weight(.medium)).lineLimit(2)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.routines.openHabitBoard")
                }
            }
            Button("Open routines") { router.select(.track) }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.routines.open")
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func capacityWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            widgetTitle(router.dashboardMode == .lowEnergy ? "Protected rest" : "Capacity", symbol: "calendar.badge.clock", palette: palette)
                .accessibilityIdentifier("home.widget.scheduleCapacity")
            if let capacity = lifeOSStore.planSnapshot?.capacity {
                Text(capacity.overloadDuration > 0 ? "\(homeDuration(capacity.overloadDuration)) over capacity" : "\(homeDuration(capacity.remainingKnownCapacity)) known room")
                    .font(.title3.weight(.semibold))
                Text(capacity.isEstimateIncomplete ? "Estimate incomplete · confidence \(Int(capacity.confidence * 100))%" : "Usable capacity \(homeDuration(capacity.usableDuration))")
                    .font(.subheadline)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            } else if projectionAdapter.snapshot.calendarNeedsSetup {
                honestEmptyState("Connect Calendar to see your next usable window", symbol: "calendar.badge.plus", palette: palette)
            } else if let freeUntil = projectionAdapter.snapshot.freeUntil {
                Text("Open until \(freeUntil.formatted(date: .omitted, time: .shortened))")
                    .font(.title3.weight(.semibold))
                Text(capacityDescription)
                    .font(.subheadline)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            } else {
                Text("No reliable free window yet")
                    .font(.headline)
                Text("Missing estimates lower confidence; LifeBoard won’t invent precision.")
                    .font(.caption)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Button("Open Day") { router.navigate(.planDay, in: .plan) }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.capacity.openDay")
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func quickCaptureWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetTitle("Capture", symbol: "plus", palette: palette)
                .accessibilityIdentifier("home.widget.quickCapture")
            HStack(spacing: 8) {
                captureButton("Task", symbol: "checkmark.circle", kind: .task, palette: palette)
                captureButton("Habit", symbol: "repeat", kind: .habit, palette: palette)
                captureButton("Journal", symbol: "book.closed", kind: .journal, palette: palette)
                if V2FeatureFlags.careModulesV2Enabled {
                    captureButton("Water", symbol: "drop.fill", kind: .hydration, palette: palette)
                }
            }
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private var homeHydrationLabel: String {
        guard let amount = lifeOSStore.trackSnapshot?.hydrationAmountMilliliters else { return "Set up" }
        return "\(Int(amount)) ml"
    }

    private var homeMedicationLabel: String {
        let count = lifeOSStore.trackSnapshot?.unresolvedMedicationEvents.count ?? 0
        return count == 0 ? "No unresolved medication events" : "\(count) medication decision\(count == 1 ? "" : "s")"
    }

    private func homeDuration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60, remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    private func timelineWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            widgetTitle("Now & next", symbol: "timeline.selection", palette: palette)
                .accessibilityIdentifier("home.widget.compactTimeline")
            if projectionAdapter.snapshot.timelineItems.isEmpty {
                honestEmptyState("Your next three commitments will appear here", symbol: "calendar", palette: palette)
            } else {
                ForEach(projectionAdapter.snapshot.timelineItems) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Text(item.startDate.formatted(date: .omitted, time: .shortened))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                            .frame(width: 62, alignment: .leading)
                        Capsule().fill(palette.color(for: .layerTwo)).frame(width: 4, height: 34)
                        Text(item.title).font(.subheadline.weight(.medium)).lineLimit(2)
                        Spacer()
                    }
                }
            }
            Button("Open complete day shape") { router.select(.plan) }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
                .accessibilityIdentifier("home.timeline.openDay")
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func journalWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            widgetTitle("Journal", symbol: "book.closed", palette: palette)
                .accessibilityIdentifier("home.widget.journal")
            Text(projectionAdapter.snapshot.hasReflection
                 ? "Today’s reflection is safe and ready to revisit."
                 : "Keep one honest moment from today—words, photos, or audio.")
                .font(.subheadline)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                Button {
                    captureRouter.request(kind: .journal, source: .widget)
                } label: {
                    Label(projectionAdapter.snapshot.hasReflection ? "Add entry" : "Write", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.color(for: .foreground))
                .accessibilityIdentifier("home.journal.capture")

                Button {
                    router.navigate(.journalSearch, in: .home)
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("home.journal.search")
            }
            Button {
                let week = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
                router.navigate(.weeklyReflection(week), in: .home)
            } label: {
                HStack {
                    Label("Weekly reflection", systemImage: "sparkles.rectangle.stack")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.journal.weeklyReflection")
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func progressWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            widgetTitle(router.dashboardMode == .lowEnergy ? "Continuity" : "Progress", symbol: "chart.line.uptrend.xyaxis", palette: palette)
                .accessibilityIdentifier("home.widget.progressReflection")
            ProgressView(value: projectionAdapter.snapshot.completionRate)
                .tint(palette.color(for: .celestialCore))
                .accessibilityLabel("Today’s progress")
                .accessibilityValue(projectionAdapter.snapshot.completionRate.formatted(.percent))
            HStack {
                Label("\(projectionAdapter.snapshot.openTaskCount) open", systemImage: "checklist")
                Spacer()
                Label("\(projectionAdapter.snapshot.streakDays) day continuity", systemImage: "sparkles")
            }
            .font(.caption.weight(.medium))
            Divider().overlay(Color(LifeBoardColorTokens.foundationHairline))
            Button {
                router.select(.insights)
            } label: {
                HStack {
                    Label("See evidence behind today", systemImage: "chart.xyaxis.line")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home.progress.openInsights")
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func fastingWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            widgetTitle("Active fast", symbol: "timer", palette: palette)
                .accessibilityIdentifier("home.widget.fasting")
            if let fast = lifeOSStore.activeFast {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = fast.elapsed(at: context.date)
                    let progress = fast.targetDuration.map { $0 > 0 ? min(1, elapsed / $0) : 0.25 } ?? 0.25
                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .stroke(palette.color(for: .canvasSecondary), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: max(0.025, progress))
                                .stroke(
                                    palette.color(for: .celestialCore),
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .lifeboardFastingEmberRing(
                                    progress: progress,
                                    tint: palette.color(for: .celestialCore)
                                )
                        }
                        .frame(width: 86, height: 86)
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(homeDuration(elapsed))
                                .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                            Text(fast.targetDuration.map {
                                elapsed >= $0
                                    ? "Planned duration reached"
                                    : "\(homeDuration($0 - elapsed)) until your planned finish"
                            } ?? "End whenever it feels right")
                                .font(.caption)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Active fast")
                    .accessibilityValue("\(homeDuration(elapsed)) elapsed")
                }
                HStack(spacing: 10) {
                    Button("End fast") {
                        Task { await lifeOSStore.endActiveFast() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.color(for: .foreground))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    Button("Open Track") { router.select(.track) }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            } else {
                honestEmptyState("No fast is active", symbol: "checkmark.circle", palette: palette)
                Button("Set up in Track") { router.select(.track) }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func widgetTitle(_ title: String, symbol: String, palette: LifeBoardDaypartPalette) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(title).font(.system(.headline, design: .rounded, weight: .semibold))
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func snapshotMetric(
        id: String,
        symbol: String,
        value: String,
        label: String,
        palette: LifeBoardDaypartPalette,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                Text(value).font(.caption2.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(label).font(.caption2).foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .lifeBoardEmbeddedClayWell(palette: palette)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.snapshot.\(id)")
    }

    private func captureButton(
        _ title: String,
        symbol: String,
        kind: CaptureKind,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        Button {
            captureRouter.request(kind: kind, source: .shell)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                Text(title).font(.caption.weight(.medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .lifeBoardEmbeddedClayWell(palette: palette)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.capture.\(kind.rawValue)")
    }

    private func honestEmptyState(_ text: String, symbol: String, palette: LifeBoardDaypartPalette) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(text).font(.subheadline).foregroundStyle(palette.color(for: .foregroundSecondary))
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var capacityDescription: String {
        if router.dashboardMode == .lowEnergy { return "Keep this window light and protect recovery." }
        if projectionAdapter.snapshot.overdueCount > 2 { return "Your day is carrying some pressure. Choose one commitment." }
        return "There is room for one focused block."
    }

    private func customizationControls(
        for placement: DashboardWidgetPlacementValue,
        daypart: ResolvedDaypart,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        Menu {
            if let descriptor = store.registry.descriptor(for: DashboardWidgetKind(rawValue: placement.widgetKind)) {
                Section("Size") {
                    ForEach(WidgetSizePreset.allCases, id: \.self) { size in
                        if descriptor.supportedSizes.contains(size) {
                            Button(size.title) { store.resizePlacement(id: placement.id, to: size) }
                        }
                    }
                }
            }
            Button("Move earlier", systemImage: "arrow.up") { store.movePlacement(id: placement.id, offset: -1) }
            Button("Move later", systemImage: "arrow.down") { store.movePlacement(id: placement.id, offset: 1) }
            Button(
                placement.ownership == .smart ? "Make pinned" : "Make adaptive",
                systemImage: placement.ownership == .smart ? "pin" : "sparkles"
            ) {
                store.toggleSmartSlot(id: placement.id)
            }
            if placement.ownership == .smart {
                let slot = placement.smartSlot ?? .init()
                Section("Smart Slot") {
                    Button(
                        slot.frozenWidgetKind == nil ? "Freeze current card" : "Resume adapting",
                        systemImage: slot.frozenWidgetKind == nil ? "snowflake" : "sparkles"
                    ) {
                        let displayed = resolvedWidgetKind(for: placement, daypart: daypart)
                        store.updateSmartSlot(id: placement.id) {
                            $0.frozenWidgetKind = slot.frozenWidgetKind == nil ? displayed.rawValue : nil
                        }
                    }
                    Menu("When it adapts", systemImage: "clock") {
                        ForEach(HomeSmartSlotSchedule.allCases, id: \.self) { schedule in
                            Button {
                                store.updateSmartSlot(id: placement.id) { $0.schedule = schedule }
                            } label: {
                                if slot.schedule == schedule {
                                    Label(schedule.title, systemImage: "checkmark")
                                } else {
                                    Text(schedule.title)
                                }
                            }
                        }
                    }
                    Menu("Allowed sections", systemImage: "square.grid.2x2") {
                        ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                            Button {
                                store.updateSmartSlot(id: placement.id) { configuration in
                                    if configuration.allowedDestinations.contains(destination),
                                       configuration.allowedDestinations.count > 1 {
                                        configuration.allowedDestinations.remove(destination)
                                    } else {
                                        configuration.allowedDestinations.insert(destination)
                                    }
                                }
                            } label: {
                                Label(
                                    destination.title,
                                    systemImage: slot.allowedDestinations.contains(destination) ? "checkmark.circle.fill" : "circle"
                                )
                            }
                        }
                    }
                }
            }
            Button("Hide", systemImage: "eye.slash", role: .destructive) { store.hidePlacement(id: placement.id) }
        } label: {
            Image(systemName: "ellipsis")
                .font(.headline)
                .frame(width: 38, height: 38)
                .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: Circle())
                .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow), radius: 6, y: 2)
        }
        .accessibilityLabel("Edit widget")
        .accessibilityAction(named: "Move before") { store.movePlacement(id: placement.id, offset: -1) }
        .accessibilityAction(named: "Move after") { store.movePlacement(id: placement.id, offset: 1) }
        .accessibilityAction(named: "Hide") { store.hidePlacement(id: placement.id) }
    }

    private func resolvedWidgetKind(
        for placement: DashboardWidgetPlacementValue,
        daypart: ResolvedDaypart
    ) -> DashboardWidgetKind {
        let fallback = DashboardWidgetKind(rawValue: placement.widgetKind)
        guard placement.ownership == .smart,
              let slot = placement.smartSlot,
              smartSlotIsEligible(slot, daypart: daypart) else { return fallback }
        if let frozen = slot.frozenWidgetKind {
            return DashboardWidgetKind(rawValue: frozen)
        }
        return store.contextSelection.candidates.first(where: { candidate in
            slot.allowedDestinations.contains(candidate.destination)
                && (store.registry.descriptor(for: candidate.widgetKind)?.supportedSizes.contains(placement.semanticSize) ?? false)
        })?.widgetKind ?? fallback
    }

    private func smartSlotIsEligible(
        _ slot: HomeSmartSlotConfiguration,
        daypart: ResolvedDaypart,
        now: Date = Date()
    ) -> Bool {
        switch slot.schedule {
        case .always:
            return true
        case .weekend:
            return Calendar.current.isDateInWeekend(now)
        case .morning:
            return daypart == .morning
        case .workday:
            return Calendar.current.isDateInWeekend(now) == false
                && (daypart == .morning || daypart == .afternoon)
        case .evening:
            return daypart == .evening || daypart == .night
        }
    }

    private func effectivePreset(for saved: WidgetSizePreset) -> WidgetSizePreset {
        dynamicTypeSize.isAccessibilitySize ? .wide : saved
    }
}

private struct AdaptiveWidgetGallery: View {
    let store: AdaptiveHomeStore
    let preferences: LifeBoardPresentationPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(WidgetGalleryCategory.allCases, id: \.self) { category in
                    let descriptors = filteredDescriptors.filter { $0.category == category }
                    if descriptors.isEmpty == false {
                        Section(category.title) {
                            ForEach(descriptors, id: \.kind) { descriptor in
                                Button {
                                    store.addWidget(descriptor)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: descriptor.systemImage)
                                            .font(.title3)
                                            .frame(width: 38, height: 38)
                                            .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 12))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(descriptor.title).font(.headline)
                                            Text("\(descriptor.defaultSize.title) · \(descriptor.multiplicity.title)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(minHeight: 52)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search widgets")
            .navigationTitle("Widget Gallery")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset to curated Home", role: .destructive) {
                        store.resetDraft()
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredDescriptors: [DashboardWidgetDescriptor] {
        let all = store.registry.availableDescriptors()
        guard query.isEmpty == false else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.category.title.localizedCaseInsensitiveContains(query) }
    }
}

private struct DashboardPresetLayoutKey: LayoutValueKey {
    static let defaultValue: WidgetSizePreset = .standard
}

private struct HomeCardReorderModifier: ViewModifier {
    let placementID: UUID
    let isEnabled: Bool
    let onMove: (UUID, UUID) -> Void
    let onResize: (Bool) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .draggable(placementID.uuidString) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.94))
                        .frame(width: 170, height: 108)
                        .overlay {
                            Image(systemName: "hand.draw.fill")
                                .font(.title2)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.18), radius: 14, y: 8)
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let source = items.compactMap(UUID.init(uuidString:)).first,
                          source != placementID else { return false }
                    onMove(source, placementID)
                    UISelectionFeedbackGenerator().selectionChanged()
                    return true
                }
                .simultaneousGesture(
                    MagnifyGesture()
                        .onEnded { value in
                            if value.magnification > 1.08 { onResize(true) }
                            if value.magnification < 0.92 { onResize(false) }
                        }
                )
        } else {
            content
        }
    }
}

private extension View {
    func dashboardPreset(_ value: WidgetSizePreset) -> some View {
        layoutValue(key: DashboardPresetLayoutKey.self, value: value)
    }

}

private struct DashboardFlowLayout: Layout {
    let isRegular: Bool
    let usesSingleColumn: Bool
    private let spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        return CGSize(width: width, height: frames(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = frames(width: bounds.width, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        let columnCount: Int
        if usesSingleColumn {
            columnCount = 1
        } else if isRegular {
            columnCount = width >= 1_100 ? 12 : 8
        } else {
            columnCount = 4
        }
        let columnWidth = max(0, (width - (CGFloat(columnCount - 1) * spacing)) / CGFloat(columnCount))
        var result = Array(repeating: CGRect.zero, count: subviews.count)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

        for index in subviews.indices {
            let preset = subviews[index][DashboardPresetLayoutKey.self]
            let requestedSpan = usesSingleColumn
                ? 1
                : DashboardResponsiveSpanResolver.columns(for: preset, columnCount: columnCount)
            let itemSpan = min(columnCount, max(1, requestedSpan))
            var bestColumn = 0
            var bestY = CGFloat.greatestFiniteMagnitude

            if columnCount > itemSpan {
                for start in 0...(columnCount - itemSpan) {
                    let candidateY = columnHeights[start..<(start + itemSpan)].max() ?? 0
                    if candidateY < bestY {
                        bestY = candidateY
                        bestColumn = start
                    }
                }
            } else {
                bestY = columnHeights.max() ?? 0
            }

            let itemWidth = (columnWidth * CGFloat(itemSpan)) + (spacing * CGFloat(itemSpan - 1))
            let measured = subviews[index].sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            let x = CGFloat(bestColumn) * (columnWidth + spacing)
            result[index] = CGRect(x: x, y: bestY, width: itemWidth, height: measured.height)
            let nextHeight = bestY + measured.height + spacing
            for column in bestColumn..<(bestColumn + itemSpan) {
                columnHeights[column] = nextHeight
            }
        }
        return (result, max(0, (columnHeights.max() ?? 0) - spacing))
    }
}

/// Home presets are defined against the canonical four-column phone grid.
/// Regular-width layouts preserve that semantic density by scaling spans into
/// their 8/12-column coordinate spaces; otherwise a standard two-column card
/// becomes an unreadable one-sixth-width strip on a wide iPad.
enum DashboardResponsiveSpanResolver {
    static func columns(for preset: WidgetSizePreset, columnCount: Int) -> Int {
        let safeColumnCount = max(1, columnCount)
        let canonicalColumnCount = 4
        let scale = max(1, safeColumnCount / canonicalColumnCount)
        return min(safeColumnCount, preset.canonicalGridSpan.columns * scale)
    }
}

private extension DashboardMode {
    var systemImage: String {
        switch self {
        case .smart: return "sparkles"
        case .work: return "briefcase"
        case .personal: return "person.crop.circle"
        case .lowEnergy: return "leaf"
        }
    }
}

extension CaptureKind {
    var systemImage: String {
        switch self {
        case .task: return "checkmark.circle"
        case .habit: return "repeat"
        case .journal: return "book.closed"
        case .note: return "note.text"
        case .trackerEntry: return "dial.medium"
        case .mood: return "face.smiling"
        case .hydration: return "drop.fill"
        case .medicationEvent: return "pills"
        case .routineRun: return "figure.mind.and.body"
        case .timeBlock: return "rectangle.inset.filled.and.person.filled"
        }
    }
}

private extension WidgetGalleryCategory {
    var title: String { rawValue.capitalized }
}

private extension WidgetMultiplicity {
    var title: String {
        switch self {
        case .singleton: return "One instance"
        case .multipleInstances: return "Multiple allowed"
        }
    }
}

extension DashboardWidgetDescriptor {
    var defaultSize: WidgetSizePreset {
        for preferred in [WidgetSizePreset.standard, .wide, .compact, .tall] where supportedSizes.contains(preferred) {
            return preferred
        }
        return supportedSizes.first ?? .standard
    }

    var systemImage: String {
        switch kind {
        case .focusNow: return "scope"
        case .lifeSnapshot: return "heart.text.square"
        case .care: return "cross.case"
        case .tasks: return "checklist"
        case .routines: return "repeat"
        case .scheduleCapacity: return "calendar.badge.clock"
        case .quickCapture: return "plus.circle"
        case .compactTimeline: return "timeline.selection"
        case .journal: return "book.closed"
        case .progressReflection: return "chart.line.uptrend.xyaxis"
        case .fasting: return "timer"
        case .bodyMetric: return "scalemass"
        case .workout: return "figure.run"
        case .sleep: return "bed.double"
        case .movement: return "figure.walk"
        case .lifeMoment: return "calendar.badge.clock"
        default: return "square.grid.2x2"
        }
    }
}

private extension WidgetSizePreset {
    var minimumCardHeight: CGFloat {
        switch self {
        case .compact: return 104
        case .standard, .wide: return 178
        case .tall: return 260
        case .expanded: return 340
        }
    }
}

public struct LifeBoardReferenceDashboard: View {
    public let preferences: LifeBoardPresentationPreferences
    public var showsDeveloperControls: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        preferences: LifeBoardPresentationPreferences,
        showsDeveloperControls: Bool = true
    ) {
        self.preferences = preferences
        self.showsDeveloperControls = showsDeveloperControls
    }

    public var body: some View {
        @Bindable var preferences = preferences
        let daypart = preferences.resolvedDaypart()
        let palette = LifeBoardDaypartTokens.functionalPalette(for: daypart, colorScheme: colorScheme)

        ZStack {
            LifeBoardAtmosphereView(
                daypart: daypart,
                requestedTier: preferences.renderingTier,
                comfortProfile: preferences.comfortProfile
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header(daypart: daypart, palette: palette)
                    metricRibbon(palette: palette)
                    medicationSection(daypart: daypart, palette: palette)
                    todoSection(palette: palette)
                    habitSection(daypart: daypart, palette: palette)
                    if showsDeveloperControls {
                        developerControls(preferences: preferences, palette: palette)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 112)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(palette.color(for: .foreground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            referenceDock
        }
        .animation(
            preferences.comfortProfile == .calm ? .easeInOut(duration: 0.18) : .spring(response: 0.38, dampingFraction: 0.86),
            value: daypart
        )
    }

    @ViewBuilder
    private func header(daypart: ResolvedDaypart, palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Menu {
                    ForEach(DaypartSelection.allCases, id: \.self) { selection in
                        Button {
                            preferences.daypartSelection = selection
                        } label: {
                            Label(selection.title, systemImage: selection.systemImage)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Smart")
                            .font(.system(size: 22, weight: .semibold))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(palette.color(for: .foreground))
                }
                .accessibilityLabel("Dashboard mode and daypart")

                Spacer()

                Button {} label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 20, weight: .medium))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Customize dashboard")
            }

            Text(daypart.greeting)
                .font(LifeBoardFoundationTypography.hero())
                .minimumScaleFactor(0.82)
                .lineLimit(1)

            Text(Date.now.formatted(.dateTime.hour().minute().weekday(.wide).month(.wide).day()))
                .font(LifeBoardFoundationTypography.body())
                .foregroundStyle(palette.color(for: .foregroundSecondary))
        }
    }

    private func metricRibbon(palette: LifeBoardDaypartPalette) -> some View {
        HStack(spacing: 12) {
            ReferenceMetricRing(label: "Hydration", value: "1460ml", progress: 0.62, palette: palette)
            ReferenceMetricRing(label: "Steps", value: "3563", progress: 0.48, palette: palette)
            ReferenceMetricRing(label: "Calories", value: "1500", progress: 0.72, palette: palette)
            ReferenceMetricRing(label: "Fasting", value: "8h", progress: 0.56, palette: palette)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func medicationSection(daypart: ResolvedDaypart, palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ReferenceSectionHeader(title: "\(daypart.rawValue.capitalized) Medications", showsAdd: false, palette: palette)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ReferenceMedicationCard(symbol: "pills", title: daypart == .morning ? "Vitamin C" : "Creatine", detail: daypart == .morning ? "1000 mg" : "3.5g", palette: palette)
                ReferenceMedicationCard(symbol: "cross.case", title: daypart == .morning ? "Tumeric" : "Whey protein", detail: daypart == .morning ? "1 pill" : "1 scoop", palette: palette)
                if daypart != .morning {
                    ReferenceMedicationCard(symbol: "capsule", title: "Omega 3", detail: "1", palette: palette)
                    ReferenceMedicationCard(symbol: "pills.circle", title: "Neurovit", detail: "1 pill", palette: palette)
                }
            }
        }
    }

    private func todoSection(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ReferenceSectionHeader(title: "Todos", showsAdd: true, palette: palette)
            ReferenceTodoRow(title: "Ship the ultimate browser", palette: palette)
            ReferenceTodoRow(title: "Finally ship TestFlight", palette: palette)
        }
    }

    @ViewBuilder
    private func habitSection(daypart: ResolvedDaypart, palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ReferenceSectionHeader(title: "\(daypart.rawValue.capitalized) Habits", showsAdd: false, palette: palette)
            HStack(spacing: 10) {
                ReferenceHabitCard(symbol: "speaker.slash", title: "Lunch in silence", palette: palette)
                ReferenceHabitCard(symbol: "figure.walk", title: "Walk outside", palette: palette)
                ReferenceHabitCard(symbol: "sun.max", title: "Sunlight 10 min", palette: palette)
            }
        }
    }

    private func developerControls(
        preferences: LifeBoardPresentationPreferences,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        @Bindable var preferences = preferences
        return VStack(alignment: .leading, spacing: 14) {
            Text("Foundation controls")
                .font(LifeBoardFoundationTypography.sectionTitle())
            Picker("Comfort", selection: $preferences.comfortProfile) {
                ForEach(LifeBoardComfortProfile.allCases, id: \.self) { profile in
                    Text(profile.title).tag(profile)
                }
            }
            .pickerStyle(.segmented)
            Picker("Rendering", selection: $preferences.renderingTier) {
                ForEach(AmbientRenderingTier.allCases, id: \.self) { tier in
                    Text(tier.title).tag(tier)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .lifeBoardPaperCard()
        .accessibilityElement(children: .contain)
    }

    private var referenceDock: some View {
        HStack(spacing: 0) {
            ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                VStack(spacing: 4) {
                    Image(systemName: destination.systemImage)
                        .font(.system(size: 17, weight: destination == .home ? .semibold : .regular))
                    Text(destination.title)
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(
                    destination == .home
                        ? Color(LifeBoardColorTokens.inkPrimary)
                        : Color(LifeBoardColorTokens.inkSecondary)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Color(LifeBoardColorTokens.warmMenuGlass)
                .opacity(reduceTransparency ? 1 : 0.96),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.lifeboard(.textInverse).opacity(colorScheme == .dark ? 0.15 : 0.68), lineWidth: 1)
        }
        .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .accessibilityElement(children: .contain)
    }
}

public struct LifeBoardTokenGallery: View {
    public let preferences: LifeBoardPresentationPreferences

    public init(preferences: LifeBoardPresentationPreferences) {
        self.preferences = preferences
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(ResolvedDaypart.allCases, id: \.self) { daypart in
                    let palette = LifeBoardDaypartTokens.palette(for: daypart)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(daypart.rawValue.capitalized)
                            .font(LifeBoardFoundationTypography.sectionTitle())
                            .foregroundStyle(palette.color(for: .foreground))

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132))], spacing: 10) {
                            ForEach(LifeBoardDaypartColorRole.allCases, id: \.self) { role in
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(palette.color(for: role))
                                        .frame(height: 72)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.08), lineWidth: 1)
                                        }
                                    Text(role.rawValue)
                                        .font(.caption.weight(.semibold))
                                    Text(palette.hex(for: role))
                                        .font(.caption.monospaced())
                                }
                                .padding(10)
                                .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                    .padding(16)
                    .background(palette.color(for: .canvas), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .padding(20)
        }
        .navigationTitle("Daypart tokens")
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid))
    }
}

private struct ReferenceMetricRing: View {
    let label: String
    let value: String
    let progress: Double
    let palette: LifeBoardDaypartPalette

    var body: some View {
        VStack(spacing: 7) {
            Text(label)
                .font(LifeBoardFoundationTypography.metadata())
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(Color(LifeBoardColorTokens.metricRingTrack), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                Circle()
                    .trim(from: 0.12, to: 0.12 + 0.76 * progress)
                    .stroke(Color(LifeBoardColorTokens.metricRingFill), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                Text(value)
                    .font(LifeBoardFoundationTypography.metadata().weight(.semibold))
                    .foregroundStyle(palette.color(for: .foreground))
            }
            .rotationEffect(.degrees(90))
            .overlay {
                Text(value)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(palette.color(for: .foreground))
            }
            .frame(width: 60, height: 60)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
    }
}

private struct ReferenceSectionHeader: View {
    let title: String
    let showsAdd: Bool
    let palette: LifeBoardDaypartPalette

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(LifeBoardFoundationTypography.sectionTitle())
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Spacer()
            if showsAdd {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("Add")
            }
        }
    }
}

private struct ReferenceMedicationCard: View {
    let symbol: String
    let title: String
    let detail: String
    let palette: LifeBoardDaypartPalette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(palette.color(for: .layerOne))
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 74)
        .lifeBoardPaperCard()
        .accessibilityElement(children: .combine)
    }
}

private struct ReferenceTodoRow: View {
    let title: String
    let palette: LifeBoardDaypartPalette

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                .overlay(Circle().stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1.5))
                .frame(width: 28, height: 28)
            Text(title)
                .font(LifeBoardFoundationTypography.body())
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to complete")
    }
}

private struct ReferenceHabitCard: View {
    let symbol: String
    let title: String
    let palette: LifeBoardDaypartPalette

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(title)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 94)
        .lifeBoardPaperCard()
        .accessibilityElement(children: .combine)
    }
}
