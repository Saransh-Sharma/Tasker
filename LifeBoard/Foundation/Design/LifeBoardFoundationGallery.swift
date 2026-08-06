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
}

private struct HomeTodayStoryItem: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let destination: LifeBoardDestination
}

/// App-level composition for the canonical Home projection.
///
/// The coordinator owns the stores that Adaptive Home reads and applies the
/// view model's slice transaction directly. No view controller has to load or
/// render before Home can receive its first projection.
@MainActor
@Observable
final class HomeProjectionCoordinator {
    private(set) var snapshot = AdaptiveHomeProjectionSnapshot()

    @ObservationIgnored private let chromeStore = HomeChromeStore()
    @ObservationIgnored private let tasksStore = HomeTasksStore()
    @ObservationIgnored private let habitsStore = HomeHabitsStore()
    @ObservationIgnored private let calendarStore = HomeCalendarStore()
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []
    @ObservationIgnored private var lastTransaction = HomeRenderTransaction.empty

    init(homeViewModel: HomeViewModel) {
        chromeStore.$snapshot
            .combineLatest(tasksStore.$snapshot, habitsStore.$snapshot, calendarStore.$snapshot)
            .sink { [weak self] _, _, _, _ in self?.rebuild() }
            .store(in: &cancellables)
        homeViewModel.$homeRenderTransaction
            .receive(on: RunLoop.main)
            .sink { [weak self] transaction in self?.apply(transaction) }
            .store(in: &cancellables)
        apply(homeViewModel.homeRenderTransaction)
        rebuild()
    }

    private func apply(_ transaction: HomeRenderTransaction) {
        guard transaction != lastTransaction else { return }
        if transaction.chrome != lastTransaction.chrome { chromeStore.apply(transaction.chrome) }
        if transaction.tasks != lastTransaction.tasks { tasksStore.apply(transaction.tasks) }
        if transaction.habits != lastTransaction.habits { habitsStore.apply(transaction.habits) }
        if transaction.calendar != lastTransaction.calendar { calendarStore.apply(transaction.calendar) }
        lastTransaction = transaction
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
            calendarNeedsSetup: calendar.moduleState == .permissionRequired || calendar.moduleState == .noCalendarsSelected
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
            seedUITestUserSpaceIfNeeded()
        } catch {
            errorMessage = "Your saved Home layout could not be loaded. The curated layout is shown instead."
        }
    }

    private func seedUITestUserSpaceIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_TEST_SEED_HOME_USER_SPACE"),
              layout.placements.contains(where: { $0.sectionOverride == .userSpace }) == false else {
            return
        }
        let testPlacementID = UUID(uuidString: "D6ED45B2-1267-4C2C-9A91-A3F5503D51AF")!
        var placement = DashboardWidgetPlacementValue(
            id: testPlacementID,
            widgetKind: DashboardWidgetKind.lifeMoment.rawValue,
            semanticSize: .standard,
            ordinal: layout.placements.count
        )
        placement.updateHomeConfiguration { configuration in
            configuration.placement.ownership = .pinned
            configuration.placement.sectionOverride = .userSpace
            configuration.placement.smartSlot = nil
        }
        layout.placements = HomeGridPackingEngine.normalized(layout.placements + [placement])
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
        value.setOwnership(.pinned, id: id)
        draft = value
    }

    func movePlacement(id: UUID, before targetID: UUID) {
        guard var value = draft else { return }
        let placements = value.current.placements.sorted { $0.ordinal < $1.ordinal }
        guard let source = placements.firstIndex(where: { $0.id == id }),
              let target = placements.firstIndex(where: { $0.id == targetID }),
              source != target else { return }
        value.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
        value.setOwnership(.pinned, id: id)
        draft = value
    }

    func resizePlacement(id: UUID, to size: WidgetSizePreset) {
        guard var value = draft else { return }
        value.resize(id: id, to: size, registry: registry)
        value.setOwnership(.pinned, id: id)
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

    /// Cards leaving the board erode away rather than vanishing between
    /// frames, so it reads as the card being put down rather than lost.
    private(set) var dissolvingPlacementID: UUID?

    func hidePlacement(id: UUID) {
        guard var value = draft else { return }
        dissolvingPlacementID = id
        value.setVisible(false, id: id)
        draft = value
    }

    func finishDissolve(id: UUID) {
        guard dissolvingPlacementID == id else { return }
        dissolvingPlacementID = nil
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

    func pinContext(_ candidate: HomeContextCandidate, section: HomeSectionRole? = nil) {
        if draft == nil { beginCustomization() }
        guard let descriptor = registry.descriptor(for: candidate.widgetKind) else { return }
        guard var value = draft else { return }
        if let existing = value.current.placements.first(where: {
            $0.widgetKind == candidate.widgetKind.rawValue && $0.isVisible
        }) {
            value.setOwnership(.pinned, id: existing.id)
            value.setSection(section, id: existing.id)
        } else {
            value.add(kind: descriptor.kind, size: descriptor.defaultSize, registry: registry)
            guard let placement = value.current.placements.last(where: {
                $0.widgetKind == candidate.widgetKind.rawValue
            }) else { return }
            value.setVisible(true, id: placement.id)
            value.setOwnership(.pinned, id: placement.id)
            value.setSection(section, id: placement.id)
        }
        draft = value
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
                // A dial rather than a slider: energy is a level being tuned,
                // not a position on a line, and the arc keeps the five detents
                // far enough apart to hit without looking.
                LifeBoardArcDial(
                    title: "Energy",
                    value: $energy,
                    range: 1...5,
                    step: 1,
                    format: { _ in energyLabel }
                )
                .frame(width: 190, height: 190)
                .accessibilityIdentifier("journal.mood.energy.dial")
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

private struct HomeTaskAgendaDatePicker: View {
    @Bindable var store: HomeLifeOSProjectionStore

    var body: some View {
        DatePicker(
            "Task date",
            selection: $store.taskAgendaDate,
            displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .frame(minHeight: 44)
        .accessibilityLabel("Task date")
        .accessibilityValue(
            store.taskAgenda.selectedDate.formatted(
                .dateTime.weekday(.wide).month(.wide).day().year()
            )
        )
        .accessibilityIdentifier("home.tasks.datePicker")
    }
}

struct LifeBoardAdaptiveHome: View {
    let projectionAdapter: HomeProjectionCoordinator
    let preferences: LifeBoardPresentationPreferences
    let router: LifeBoardAppRouter
    let captureRouter: CaptureRouter
    let phaseIIRepository: (any LifeBoardPhaseIIRepository)?
    private let hasPlanningRepository: Bool
    /// Retained so the day-loop stage can ask whether today already has an
    /// applied close receipt. Already passed in for the context providers; this
    /// keeps a reference rather than adding a new dependency.
    private let planningRepository: CoreDataPlanningRepository?
    private let hasTrackFoundationRepository: Bool
    private let showsEmbeddedComposer: Bool
    private let onCustomizationChanged: (Bool) -> Void
    private let contextProviderRegistry: HomeContextCandidateProviderRegistry
    /// Resolves what each Home mode actually changes. Modes were persisted and
    /// restored but had no reachable control and no effect beyond Low Energy.
    private let modePolicy: any DashboardModePolicy = DeterministicDashboardModePolicy()

    @State private var store: AdaptiveHomeStore
    @State private var lifeOSStore: HomeLifeOSProjectionStore
    @State private var healthStore = LifeBoardHealthRuntime.shared.connectionStore
    @State private var selectedMood: LifeBoardJournalMood = .none
    @State private var moodEnergy: Int?
    @State private var showsMoodDial = false
    @State private var captureOrbState = CaptureOrbPresentationState()
    @State private var contextReasonCandidate: HomeContextCandidate?
    @State private var expandedTaskWidgetIDs: Set<UUID> = []
    @State private var showsFastingError = false
    @State private var showsFastEndReceipt = false
    @State private var fastingStateChangeTrigger = 0
    /// Drives the one-shot daypart cross-dissolve. Incremented on a real
    /// daypart boundary or a manual override, never on a redraw.
    @State private var daypartTransitionTrigger = 0
    /// Bumped when the evening ritual is snoozed, so the entry row re-evaluates
    /// without waiting for the next Home reload.
    @State private var dayRitualSnoozeGeneration = 0
    /// Whether today already has an applied day-close receipt. Drives `.rest`,
    /// which is what stops the ritual re-offering itself all evening.
    @State private var dayLoopClosedToday = false
    /// The loop's own continuity, read from applied receipts.
    @State private var dayLoopSummary: DayLoopSummary?
    /// Whether today already has an applied day-open receipt. Stops the morning
    /// re-offering a commitment that has already been made.
    @State private var dayLoopCommittedToday = false
    @State private var composerText = ""
    @FocusState private var composerIsFocused: Bool
    /// In-app Home is already behind the device unlock, so a glanceable card
    /// shows its real value here by default. Redaction is for surfaces that
    /// render outside the unlocked app — widgets, Spotlight, notification
    /// previews — and for Work mode, which is what gets screen-shared.
    @AppStorage("lifeOS.home.sensitive_cards.enabled") private var permitsSensitiveHomeContent = true
    @AppStorage("lifeOS.home.dashboardDensity.v1") private var dashboardDensity: DashboardDensity = .balanced
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeBoardAtmosphereSnapshot) private var atmosphereSnapshot
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted

    init(
        projectionAdapter: HomeProjectionCoordinator,
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
        showsEmbeddedComposer: Bool = true,
        onCustomizationChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.projectionAdapter = projectionAdapter
        self.preferences = preferences
        self.router = router
        self.captureRouter = captureRouter
        self.phaseIIRepository = phaseIIRepository
        self.hasPlanningRepository = planningRepository != nil
        self.planningRepository = planningRepository
        self.hasTrackFoundationRepository = trackFoundationRepository != nil
        self.showsEmbeddedComposer = showsEmbeddedComposer
        self.onCustomizationChanged = onCustomizationChanged
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
        let daypart = atmosphereSnapshot.semanticDaypart
        let palette = LifeBoardDaypartTokens.functionalPalette(for: daypart, colorScheme: colorScheme)
        let ambientPalette = daypart == .night && horizontalSizeClass == .regular
            ? LifeBoardDaypartTokens.palette(for: daypart)
            : palette

        ZStack(alignment: .bottom) {
            if atmosphereIsHosted == false {
                LifeBoardScenicBackdrop(
                    scene: .home,
                    daypart: daypart,
                    requestedTier: preferences.renderingTier,
                    comfortProfile: preferences.comfortProfile
                )
                // A static warm tooth so the large flat canvas areas read as
                // pressed paper. No time input — this must never animate, and
                // it drops out entirely under Increased Contrast.
                .lifeboardPaperGrain()
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let errorMessage = store.errorMessage {
                        LifeBoardStatusSurface(
                            state: .stale,
                            title: "Showing your safe Home layout",
                            message: errorMessage,
                            actionTitle: "Dismiss",
                            action: { store.dismissError() }
                        )
                    }

                    let budget = modePolicy
                        .sectionBudget(for: router.dashboardMode)
                        .applying(dashboardDensity)

                    if V2FeatureFlags.homeLoopSpineV1Enabled {
                        loopSpine(palette: palette, ambientPalette: ambientPalette, budget: budget)
                    } else {
                        nowSection(palette: palette)
                    }

                    homeSectionHeading(
                        "Signals",
                        palette: ambientPalette
                    )
                    signalRowWidget(palette: ambientPalette)
                    if showsFastEndReceipt {
                        fastingEndReceipt(palette: ambientPalette)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Today's committed work sits directly under orientation.
                    // It previously fell through to "Your space" and rendered
                    // below wellbeing and reflection on a default install.
                    if budget.showsToday {
                        placementSection(
                            "Today",
                            placements: todayPlacements,
                            daypart: daypart,
                            palette: palette,
                            ambientPalette: ambientPalette
                        )
                    }

                    if budget.showsDayAhead {
                        todayStorySection(palette: palette)
                    }

                    if budget.showsNeedsAttention, store.contextSelection.candidates.count > 1 {
                        needsAttentionSection(palette: palette)
                    }

                    placementSection(
                        "Keep steady",
                        placements: keepSteadyPlacements,
                        daypart: daypart,
                        palette: palette,
                        ambientPalette: ambientPalette
                    )

                    // Outside the budget on purpose. `showsCloseLoop` is false
                    // for both Low Energy and Minimal density, which hid the
                    // ritual on exactly the days that most need a gentle close.
                    // The *placement section* stays budgeted; the door does not.
                    //
                    // Under the spine the ritual is already the `.close` stage
                    // body, so repeating it here would restate the same
                    // projection twice on one screen.
                    if V2FeatureFlags.homeLoopSpineV1Enabled == false {
                        dayRitualEntry(palette: palette)
                    }

                    // Retired as a rendered section under the spine: "Close the
                    // loop" is what the spine now *is*, and two things by that
                    // name on one screen is the restatement DESIGN.md forbids.
                    // Its placements are not lost — `effectiveSectionRole`
                    // coalesces them into the pinned dashboard.
                    if budget.showsCloseLoop, V2FeatureFlags.homeLoopSpineV1Enabled == false {
                        placementSection(
                            "Close the loop",
                            placements: closeLoopPlacements,
                            daypart: daypart,
                            palette: palette,
                            ambientPalette: ambientPalette
                        )
                    }

                    if budget.showsUserSpace {
                        userSpaceSection(
                            daypart: daypart,
                            palette: palette,
                            ambientPalette: ambientPalette
                        )
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                // Clears the floating composer + dock chrome. The shell's
                // atmosphere background ignores the safe area, so this root
                // pads explicitly rather than relying on inset propagation.
                .padding(
                    .bottom,
                    store.isCustomizing ? 16 : (showsEmbeddedComposer ? 16 : 150)
                )
            }
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                store.setContextFrozen(phase != .idle, reason: "home-scroll")
            }

        }
        // The screen changing time of day should feel like weather moving
        // across it, not like a palette swap.
        .lifeboardDaypartCrossDissolve(trigger: daypartTransitionTrigger, daypart: daypart)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if store.isCustomizing {
                customizationActionBar(palette: palette)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            } else if showsEmbeddedComposer {
                lifeThreadComposer(palette: palette)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .foregroundStyle(palette.color(for: .foreground))
        .toolbar(.hidden, for: .navigationBar)
        .alert("Fasting needs attention", isPresented: $showsFastingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lifeOSStore.fastingMutationError ?? "The timer could not be updated.")
        }
        .task {
            await store.load()
            await lifeOSStore.load()
            await refreshDayLoopStage()
            if let latest = await lifeOSStore.latestMoodCheckInToday() {
                selectedMood = latest.mood
                moodEnergy = latest.energy
            }
            refreshContextSelection(boundary: .appForeground)
        }
        .task {
            let updates = await HealthSyncInvalidationHub.shared.updates()
            for await _ in updates {
                guard Task.isCancelled == false else { return }
                await lifeOSStore.load()
                refreshContextSelection(boundary: .trackerCommit)
            }
        }
        .onChange(of: lifeOSStore.heroSnapshot?.id) { _, _ in refreshContextSelection(boundary: .taskMutation) }
        .onChange(of: projectionAdapter.snapshot) { _, _ in refreshContextSelection(boundary: .taskMutation) }
        .onChange(of: permitsSensitiveHomeContent) { _, _ in refreshContextSelection() }
        .onChange(of: daypart) { _, _ in
            refreshContextSelection(boundary: .daypartBoundary)
            daypartTransitionTrigger &+= 1
        }
        .onChange(of: voiceOverEnabled, initial: true) { _, enabled in
            store.setContextFrozen(enabled, reason: "voiceover-focus")
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshContextSelection(boundary: .appForeground)
            Task {
                await lifeOSStore.load()
                await refreshDayLoopStage()
            }
        }
        // A meal can be logged in Track while Home remains mounted. Refresh
        // when the user returns so the fasting clock anchors to that meal
        // immediately instead of waiting for a foreground transition.
        .onChange(of: router.selectedDestination) { _, destination in
            guard destination == .home else { return }
            Task { await lifeOSStore.load() }
        }
        // Returning from the ritual pops back to Home without a scene-phase
        // change, so without this the row would keep offering a day that was
        // just closed — and would keep hiding one that was just undone.
        .onChange(of: router.path(for: .home).count) { _, _ in
            Task { await refreshDayLoopStage() }
        }
        .onChange(of: store.isCustomizing, initial: true) { _, isCustomizing in
            onCustomizationChanged(isCustomizing)
        }
        .onDisappear {
            onCustomizationChanged(false)
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
        let mode = router.dashboardMode
        Task {
            let domainCandidates = await contextProviderRegistry.candidates(
                context: .init(date: now, refreshBoundary: boundary)
            )
            let candidates = mode == .lowEnergy
                ? lowEnergyCandidates(from: local + domainCandidates, now: now)
                : local + domainCandidates
            store.refreshContext(
                candidates: candidates,
                permitsSensitiveHomeContent: permitsSensitive,
                now: now
            )
            await refreshCardSnapshots(now: now)
        }
    }

    private func lowEnergyCandidates(
        from candidates: [HomeContextCandidate],
        now: Date
    ) -> [HomeContextCandidate] {
        let care = candidates
            .filter { $0.resolvedSemanticRole == .care }
            .sorted { $0.priority > $1.priority }
            .first
            ?? .init(
                id: "low-energy-essential-care",
                widgetKind: .care,
                title: "A small care check-in",
                reason: .init(
                    message: "Water, medication you already planned, food, or one quiet minute can come first.",
                    signal: "Low Energy mode"
                ),
                destination: .track,
                priority: 900,
                relevantFrom: now,
                semanticRole: .care
            )
        let sourceAction = candidates
            .filter { $0.resolvedSemanticRole == .primaryNow }
            .sorted { $0.priority > $1.priority }
            .first
        let smallAction = HomeContextCandidate(
            id: "low-energy-small-action:\(sourceAction?.id ?? "choose")",
            widgetKind: .focusNow,
            title: sourceAction.map { "One gentle step: \($0.title)" } ?? "Choose one five-minute action",
            reason: .init(
                message: "Keep the outcome intentionally small so recovery still has room.",
                signal: "Low Energy mode"
            ),
            destination: sourceAction?.destination ?? .plan,
            sensitivity: sourceAction?.sensitivity ?? .privateStandard,
            priority: 1_000,
            relevantFrom: now,
            relevantUntil: sourceAction?.relevantUntil,
            semanticRole: .primaryNow
        )
        return [smallAction, care]
    }

    /// Resolves provider snapshots for every currently visible placement at
    /// its effective size, so glance/compact bodies read domain providers
    /// instead of canonical stores.
    private func refreshCardSnapshots(now: Date = Date()) async {
        let daypart = atmosphereSnapshot.semanticDaypart
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

    /// A section heading carries the section's *state*, not an explanation of
    /// itself.
    ///
    /// This previously took a mandatory `detail:` string, so every section was
    /// structurally required to have a subtitle. Home opened with "A small,
    /// explainable view of what matters next.", "The signals that are useful
    /// right now." and "Your cards stay exactly where you put them." — three
    /// lines that described the interface to the person already looking at it,
    /// and together cost roughly a quarter of the first viewport. `state` is
    /// now optional and reserved for information the user cannot see at a
    /// glance: a count, a time, a number needing attention.
    private func homeSectionHeading(
        _ title: String,
        state: String? = nil,
        palette: LifeBoardDaypartPalette,
        usesInverseInk: Bool = false
    ) -> some View {
        let primary = usesInverseInk
            ? Color.lifeboard(.textInverse)
            : palette.color(for: .foreground)
        let secondary = usesInverseInk
            ? Color.lifeboard(.textInverse).opacity(0.78)
            : palette.color(for: .foregroundSecondary)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(LifeBoardFoundationTypography.sectionTitle())
                .foregroundStyle(primary)
            if let state {
                Text(state)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Says how many things are actually asking for attention, which the user
    /// cannot count at a glance once the list is longer than one.
    private var nowSectionState: String? {
        let count = store.contextSelection.candidates.count
        guard count > 1 else { return nil }
        return "\(count) need attention"
    }

    /// - Parameter showsHeading: `false` when the loop spine is already titling
    ///   this region. The spine's `.act` stage *is* "Now", so a heading here
    ///   would name the same thing twice — the same reason `spineRepairBody`
    ///   passes `header: nil` to its deck.
    @ViewBuilder
    private func nowSection(
        palette: LifeBoardDaypartPalette,
        showsHeading: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeading {
                homeSectionHeading(
                    "Now",
                    state: nowSectionState,
                    palette: palette,
                    usesInverseInk: atmosphereSnapshot.phase == .night
                )
            }
            if store.contextSelection.candidates.isEmpty {
                focusNowWidget(palette: palette)
            } else if let candidate = store.contextSelection.candidates.first {
                contextCard(
                    candidate,
                    palette: palette,
                    accessibilityIdentifier: "home.hero"
                )
            }
        }
        // The whole explainable "Now" region is the canonical Home hero.
        // Its contents can legitimately swap from Focus to a context card as
        // providers hydrate, so the stable identity belongs on the region.
        .accessibilityIdentifier("home.hero")
    }

    private func needsAttentionSection(palette: LifeBoardDaypartPalette) -> some View {
        let candidates = Array(store.contextSelection.candidates.dropFirst().prefix(3))
        return VStack(alignment: .leading, spacing: 10) {
            homeSectionHeading(
                "Needs attention",
                state: "\(candidates.count)",
                palette: palette
            )
            ForEach(candidates) { candidate in
                Button {
                    pinContextAfterAction(candidate)
                    router.select(candidate.destination)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: symbol(for: candidate.widgetKind))
                            .frame(width: 30, height: 30)
                            .background(palette.color(for: .canvasSecondary), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.title)
                                .font(.subheadline.weight(.semibold))
                            Text(candidate.reason.message)
                                .font(.caption)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .lifeBoardRaisedClayCard(palette: palette)
        .accessibilityIdentifier("home.needsAttention")
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
                    Menu("Move to Section", systemImage: "rectangle.3.group") {
                        ForEach(
                            [HomeSectionRole.today, .keepSteady, .closeLoop, .userSpace],
                            id: \.self
                        ) { section in
                            Button(section.title) {
                                store.pinContext(candidate, section: section)
                                Task { await store.saveCustomization() }
                            }
                        }
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(candidate.title)")
            }

            Button {
                pinContextAfterAction(candidate)
                if let route = candidate.route {
                    // `navigate` rather than `select` + `push`: it lets the root
                    // change finish before the typed leaf is appended, so a
                    // just-popped empty path cannot be written over the new
                    // route. Root selection alone never leaves a blank frame now
                    // (`LifeBoardRootRetention`), but the ordering still matters.
                    router.navigate(route, in: candidate.destination)
                } else {
                    router.select(candidate.destination)
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } label: {
                HStack {
                    Text(candidate.actionTitle)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .lifeBoardTransitionSource(
                candidate.route?.spatialTransitionID ?? "route.home.context.\(candidate.id)"
            )
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

    private func pinContextAfterAction(_ candidate: HomeContextCandidate) {
        let section: HomeSectionRole = switch candidate.resolvedSemanticRole {
        case .primaryNow, .dayAheadStory: .today
        case .care: .keepSteady
        case .reflection: .closeLoop
        case .attention: .userSpace
        }
        store.pinContext(candidate, section: section)
        Task { await store.saveCustomization() }
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
                "Day ahead",
                state: todayStoryItems.isEmpty ? nil : "\(todayStoryItems.count) moments",
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
            // This read "N% of today's planned work is complete", which broke
            // the copy law twice on a closed day. It reported 100% after an
            // evening reconciliation where one task was carried to tomorrow and
            // one was let go — neither is completion — and it asserted a
            // confident percentage for a day that had nothing scheduled at all,
            // so "absent" rendered as "100%". Counts say what happened; a rate
            // says what someone should conclude from it.
            let openCount = projectionAdapter.snapshot.openTaskCount
            items.append(.init(
                id: "progress",
                title: "Progress is settling in",
                detail: openCount == 0
                    ? "Nothing you committed to is still open."
                    : "\(openCount) still open.",
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
                    .frame(width: 44, height: 44)
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
                    .frame(width: 44, height: 44)
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

    /// Section membership now comes from `DashboardWidgetDescriptor.sectionRole`.
    /// It used to live as three hardcoded string sets here plus a fourth copy
    /// in the layout repository — registering a new kind silently dropped it
    /// into "Your space", and the two anchored copies could drift apart.
    private func descriptor(for placement: DashboardWidgetPlacementValue) -> DashboardWidgetDescriptor? {
        store.registry.descriptor(for: DashboardWidgetKind(rawValue: placement.widgetKind))
    }

    private var visiblePlacements: [DashboardWidgetPlacementValue] {
        let mode = router.dashboardMode
        return store.activeLayout.placements
            .filter { placement in
                guard placement.isVisible, let descriptor = descriptor(for: placement) else { return false }
                // An anchored role is rendered by its own fixed section. A card
                // the user deliberately pinned stays reachable in "Your space"
                // — the repository preserves those, so dropping them here left
                // them persisted forever and never drawn.
                if effectiveSectionRole(for: placement) == .anchored, placement.ownership != .pinned { return false }
                // The spine draws Focus Now itself, so a pinned copy rendered
                // the same `heroSnapshot` a second time on one screen. Dropped
                // at read time like `.closeLoop`, not unpinned: the placement
                // stays in the repository, so turning the spine off brings the
                // person's own arrangement back exactly as they left it.
                if V2FeatureFlags.homeLoopSpineV1Enabled, placement.widgetKind == DashboardWidgetKind.focusNow.rawValue { return false }
                return modePolicy.permits(descriptor, in: mode)
            }
            .sorted { $0.ordinal < $1.ordinal }
    }

    private func placements(in role: HomeSectionRole) -> [DashboardWidgetPlacementValue] {
        visiblePlacements.filter { effectiveSectionRole(for: $0) == role }
    }

    private func effectiveSectionRole(for placement: DashboardWidgetPlacementValue) -> HomeSectionRole {
        let resolved = placement.sectionOverride ?? descriptor(for: placement)?.sectionRole ?? .userSpace
        // Under the spine, "Close the loop" is no longer a rendered section —
        // the spine is. Its placements fall into the pinned dashboard rather
        // than vanishing.
        //
        // Coalesced at *read* time on purpose. `.closeLoop` is persisted in
        // `sectionOverride`, so deleting the case or rewriting stored rows would
        // break decoding of layouts people already have; this is reversible by
        // flipping the flag and touches no data.
        guard V2FeatureFlags.homeLoopSpineV1Enabled, resolved == .closeLoop else { return resolved }
        return .userSpace
    }

    private var todayPlacements: [DashboardWidgetPlacementValue] {
        placements(in: .today)
    }

    private var keepSteadyPlacements: [DashboardWidgetPlacementValue] {
        placements(in: .keepSteady)
    }

    private var closeLoopPlacements: [DashboardWidgetPlacementValue] {
        placements(in: .closeLoop)
    }

    private var supportingPlacements: [DashboardWidgetPlacementValue] {
        let claimed = Set(
            (todayPlacements + keepSteadyPlacements + closeLoopPlacements).map(\.id)
        )
        return visiblePlacements.filter { claimed.contains($0.id) == false }
    }

    @ViewBuilder
    private func placementSection(
        _ title: String,
        placements: [DashboardWidgetPlacementValue],
        daypart: ResolvedDaypart,
        palette: LifeBoardDaypartPalette,
        ambientPalette: LifeBoardDaypartPalette
    ) -> some View {
        if placements.isEmpty == false {
            homeSectionHeading(title, palette: ambientPalette)
            DashboardFlowLayout(
                isRegular: horizontalSizeClass == .regular,
                usesSingleColumn: dynamicTypeSize.isAccessibilitySize
            ) {
                ForEach(placements) { placement in
                    dashboardWidget(for: placement, daypart: daypart, palette: palette)
                        .dashboardPreset(effectivePreset(for: placement.semanticSize))
                        .accessibilityValue(placement.ownership.accessibilityDescription)
                        .lifeBoardScrollEntrance(
                            intensity: scrollEntranceIntensity(for: placement, daypart: daypart)
                        )
                        .modifier(HomeCardDissolveModifier(
                            isDissolving: store.dissolvingPlacementID == placement.id,
                            tint: palette.color(for: .celestialPrimary),
                            onFinish: { store.finishDissolve(id: placement.id) }
                        ))
                }
            }
        }
    }

    @ViewBuilder
    private func userSpaceSection(
        daypart: ResolvedDaypart,
        palette: LifeBoardDaypartPalette,
        ambientPalette: LifeBoardDaypartPalette
    ) -> some View {
        // Rendered even with nothing in it. This section used to appear only once
        // `supportingPlacements` was non-empty or customization was already
        // running, which made customization unreachable: the only control that
        // starts it lives here, and the only way to get a placement is to start it.
        // A fresh Home therefore had no route into "Add a widget" at all.
        Group {
            HStack(alignment: .center, spacing: 8) {
                // Named "Your dashboard" under the spine: it stops being the
                // leftover bucket below the app's own sections and becomes the
                // one region that is explicitly the person's. The spine leads;
                // this is theirs, and it keeps every widget it had.
                homeSectionHeading(
                    dashboardSectionTitle,
                    palette: ambientPalette
                )
                if store.isCustomizing == false {
                    // Layout undo was implemented in the store but its only
                    // button lived in the never-called adaptive header, so a
                    // rearrangement could not be taken back.
                    if store.lastLayoutTransaction != nil {
                        Button("Undo") {
                            Task { await store.undoLastLayoutTransaction() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                        .fixedSize()
                        .accessibilityHint("Restores the previous Home arrangement")
                        .accessibilityIdentifier("home.layoutUndo")
                    }
                    if V2FeatureFlags.dashboardCustomizationV2Enabled {
                        Button {
                            store.beginCustomization()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        // `homeSectionHeading` ends in a greedy `Spacer`, which
                        // compressed this control to 17 x 14 points — well under the
                        // 44-point minimum, and small enough that the hit test
                        // missed it entirely.
                        .fixedSize()
                        .accessibilityLabel("Customize Home")
                        .accessibilityIdentifier("home.customize")
                    }
                }
            }

            if supportingPlacements.isEmpty, store.isCustomizing == false {
                // Empty is a success state here, so this says what the space is
                // for and points at the one control that fills it.
                Text("Room for the widgets you choose.")
                    .font(.subheadline)
                    .foregroundStyle(ambientPalette.color(for: .foregroundSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("home.userSpace.empty")
            } else {
                DashboardFlowLayout(
                    isRegular: horizontalSizeClass == .regular,
                    usesSingleColumn: dynamicTypeSize.isAccessibilitySize
                ) {
                    ForEach(supportingPlacements) { placement in
                        dashboardWidget(for: placement, daypart: daypart, palette: palette)
                            .dashboardPreset(effectivePreset(for: placement.semanticSize))
                            .accessibilityValue(placement.ownership.accessibilityDescription)
                            .lifeBoardScrollEntrance(
                                intensity: scrollEntranceIntensity(for: placement, daypart: daypart)
                            )
                    }
                }
            }
        }
    }

    private func customizationActionBar(palette: LifeBoardDaypartPalette) -> some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                withAnimation(motionAnimation) { store.cancelCustomization() }
            }
            .frame(minWidth: 88, minHeight: 48)
            .accessibilityIdentifier("home.customization.cancel")

            Spacer(minLength: 8)

            Button("Done") {
                Task { await store.saveCustomization() }
            }
            .fontWeight(.semibold)
            .frame(minWidth: 88, minHeight: 48)
            .accessibilityIdentifier("home.customization.done")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(palette.color(for: .foreground))
        .lifeBoardGlassSurface(cornerRadius: 28, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.customization.actions")
    }

    private var motionAnimation: Animation? {
        guard reduceMotion == false, preferences.comfortProfile != .calm else {
            return .easeInOut(duration: 0.18)
        }
        return .spring(response: 0.38, dampingFraction: 0.86)
    }

    private func scrollEntranceIntensity(
        for placement: DashboardWidgetPlacementValue,
        daypart: ResolvedDaypart
    ) -> CGFloat {
        guard store.isCustomizing == false else { return 0 }
        let isExpandedTaskCard = resolvedWidgetKind(for: placement, daypart: daypart) == .tasks
            && expandedTaskWidgetIDs.contains(placement.id)
        // The shared entrance transition blurs an entire widget while its
        // bottom edge enters the viewport. An expanded task card can be taller
        // than that viewport, so it never reaches the identity phase and its
        // already-visible header and rows stay blurred during normal scrolling.
        return isExpandedTaskCard ? 0 : 1
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
                    Image(systemName: "line.3.horizontal")
                        .font(.headline)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Drag widget")
                        .accessibilityIdentifier("home.widget.drag.\(placement.id.uuidString)")

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
                        tasksWidget(placementID: placement.id, palette: palette)
                    case .routines:
                        routinesWidget(daypart: daypart, palette: palette)
                    case .scheduleCapacity:
                        capacityWidget(palette: palette)
                    case .journal:
                        journalWidget(palette: palette)
                    case .progressReflection:
                        progressWidget(palette: palette)
                    default:
                        archetypeWidget(kind: kind, preset: preset, palette: palette)
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
                        tasksWidget(placementID: placement.id, palette: palette)
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
                        // Was `EmptyView()`. Eleven registered kinds — goals,
                        // body metric, workout, sleep, movement, nutrition,
                        // recent meal, log meal, life moment, saved Eva
                        // insight and setup — reached this branch and drew
                        // nothing. Accessibility text sizes force this preset,
                        // so those cards were blank for anyone using large
                        // type. Every kind now has an archetype, and every
                        // archetype draws.
                        archetypeWidget(kind: kind, preset: preset, palette: palette)
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

    /// Renders a card from its registered archetype rather than a per-kind
    /// case. This is the universal body: any registered kind draws something
    /// meaningful at any preset, which is what makes the old `EmptyView()`
    /// fallthrough unrepresentable.
    @ViewBuilder
    private func archetypeWidget(
        kind: DashboardWidgetKind,
        preset: WidgetSizePreset,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        let descriptor = store.registry.descriptor(for: kind)
        Button {
            openWidget(kind)
        } label: {
            LifeBoardHomeCardBody(
                snapshot: lifeOSStore.cardSnapshot(kind: kind, size: preset),
                archetype: descriptor?.archetype ?? .queue,
                preset: preset,
                palette: palette,
                title: descriptor?.title ?? "LifeBoard",
                symbol: symbol(for: kind),
                queueLimit: modePolicy
                    .sectionBudget(for: router.dashboardMode)
                    .applying(dashboardDensity)
                    .queueLimit,
                onAction: { action in
                    if let destination = action.destination {
                        router.select(destination)
                    } else {
                        openWidget(kind)
                    }
                },
                onOpen: { openWidget(kind) }
            )
        }
        .buttonStyle(.plain)
        .lifeBoardRaisedClayCard(palette: palette)
        .accessibilityHint("Opens the source")
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
        // The domain provider registry is the only source of card copy.
        //
        // A parallel switch used to live here as a "first-frame fallback" and had
        // drifted into a second, contradictory copy set for the same cards —
        // tasks-empty existed in three spellings, fasting and journal in two, and
        // Focus Now shipped the ungrammatical "Choose one kind next step". A card
        // shows its title alone until its provider resolves, which is a frame at
        // most, rather than showing something that disagrees with what follows.
        guard let snapshot = lifeOSStore.cardSnapshot(kind: kind, size: size) else { return "" }
        return [snapshot.value, snapshot.detail]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// The way into the end-of-day ritual, and the morning's read-only echo.
    ///
    /// A section-level affordance rather than a `DashboardWidgetKind`: it is not
    /// a readout, it cannot be reordered or pinned, and registering it as a
    /// widget would oblige it to render at all five size presets for no benefit.
    ///
    /// Deliberately *not* wired to `DayCompassEngine`'s `eveningReview` card —
    /// that card's only consumer is the legacy Sunrise home, which this shell
    /// replaces. Reusing the engine's window predicate and its snooze ledger
    /// gives the same tested behaviour without shipping to a screen nobody sees.
    @ViewBuilder
    private func dayRitualEntry(palette: LifeBoardDaypartPalette) -> some View {
        if V2FeatureFlags.dayCloseV1Enabled, let ritual = activeDayRitual {
            Button {
                router.push(ritual.route, in: .home)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: ritual.symbol)
                        .font(.title3)
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationSunAccent))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ritual.title)
                            .font(.headline)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                        Text(ritual.subtitle)
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(16)
            .lifeBoardClaySurface(.raised, cornerRadius: LifeBoardFoundationRadius.card)
            // The ritual grows out of the row you tapped rather than sliding in
            // from the edge as an unrelated screen — it is the same day, opened.
            // Already gated on Reduce Motion, Catalyst and -UI_TESTING inside.
            .lifeBoardTransitionSource(LifeBoardDayLoopTransition.id(for: ritual.route))
            .accessibilityIdentifier("home.dayRitual")
            .contextMenu {
                if ritual.isEvening {
                    Button("Not tonight") {
                        DayCompassSnoozeStore().snoozeUntilEndOfDay(flow: .eveningReview)
                        dayRitualSnoozeGeneration += 1
                    }
                }
            }
        }
    }

    private struct DayRitualEntry {
        let route: AppRoute
        let title: String
        let subtitle: String
        let symbol: String
        let isEvening: Bool
    }

    // MARK: - Loop spine

    /// Home's spine: what stage the day is in, and the one thing it asks for.
    ///
    /// App-owned and never pinnable — a person cannot reorder or remove the
    /// loop, because the loop is what the app *is*. Deliberately outside
    /// `HomeSectionBudget`: Low Energy changes which **stages** appear, not
    /// whether the spine does. That is what stops Low Energy from being the mode
    /// that hides the gentle close.
    @ViewBuilder
    private func loopSpine(
        palette: LifeBoardDaypartPalette,
        ambientPalette: LifeBoardDaypartPalette,
        budget: HomeSectionBudget
    ) -> some View {
        let stage = dayLoopStage
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(spineTitle(for: stage))
                    .font(LifeBoardFoundationTypography.sectionTitle())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                // The count belongs to whichever heading survives. `.act` used
                // to stack the spine's title above `nowSection`'s own, so the
                // screen read "Now" twice and only the lower one carried the
                // number. One row now, and it keeps the number.
                if let state = spineState(for: stage) {
                    Text(state)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let rhythm = dayLoopRhythmText {
                    Text(rhythm)
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        // Two lines, never truncation: this once shortened to
                        // "1 of 14 days · 1 day…", hiding one of the two honest
                        // facts. Both numbers carry equal weight
                        // because the anti-guilt mechanism here is arithmetic,
                        // not copy.
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                        // Per-glyph displacement under TextRenderer, capped at
                        // 6pt and disabled at accessibility sizes — the line
                        // stays fully legible and never scales or blurs.
                        .lifeBoardKineticGreeting()
                }
            }
            .accessibilityElement(children: .combine)

            switch stage {
            case .commit, .close:
                // The ritual is the stage body, not a row buried below one.
                dayRitualEntry(palette: palette)
            case .act:
                nowSection(palette: palette, showsHeading: false)
            case .repair:
                spineRepairBody
            case .rest:
                spineRestBody
            }
        }
        .lifeBoardMotion(.cardReflow, value: stage)
        .accessibilityIdentifier("home.loopSpine.\(stage.rawValue)")
    }

    private var dashboardSectionTitle: String {
        let base = V2FeatureFlags.homeLoopSpineV1Enabled ? "Your dashboard" : "Your space"
        return store.isCustomizing ? "\(base) · drag to arrange" : base
    }

    /// The count the stage's body would otherwise have titled for itself.
    ///
    /// Only `.act` has one: its body is `nowSection`, whose heading is
    /// suppressed so the spine owns the single row.
    private func spineState(for stage: DayLoopStage) -> String? {
        stage == .act ? nowSectionState : nil
    }

    private func spineTitle(for stage: DayLoopStage) -> String {
        switch stage {
        case .commit: "Start today"
        case .act: "Now"
        case .repair: "Worth a look"
        case .close: "Ending the day"
        // Not "Done" or "Complete" — the day is put down, not scored.
        case .rest: "Today is closed"
        }
    }

    /// `.repair` states what the day did, and offers a way to answer it.
    ///
    /// Not paired with `nowSection`: the deck already names the work, and
    /// restating the same projection twice under one heading reads as two
    /// separate asks.
    ///
    /// The copy reports and stops. "Nothing has changed yet" is the load-bearing
    /// half — the deck is an offer, and a person who reads this and does nothing
    /// has lost nothing. No count styled as a badge, no red, and none of
    /// "missed", "late", "behind" or "overdue": these blocks did not happen when
    /// they were planned, which is a fact about a day, not about a person.
    @ViewBuilder
    private var spineRepairBody: some View {
        let count = lifeOSStore.driftCount
        VStack(alignment: .leading, spacing: 12) {
            Text(
                count == 1
                    ? "One thing didn't happen when you planned it. Nothing has changed yet."
                    : "\(count) things didn't happen when you planned them. Nothing has changed yet."
            )
            .font(LifeBoardFoundationTypography.body())
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            .fixedSize(horizontal: false, vertical: true)

            PlanRepairDeck(
                proposals: lifeOSStore.repairProposals,
                // The spine already says "Worth a look"; a second header here
                // would title the same thing twice.
                header: nil,
                // The service's own wording — "this planned block has passed
                // without a completion receipt" — is a sentence about our data
                // model, not about the person's day.
                fallbackExplanation: "This one didn't get its window today."
            ) { action, _ in
                // Home decides, Plan commits. Choosing a direction only *stages*
                // a scenario, and staging needs a `PlanningScenarioCoordinator`
                // that Home's `PlanStore` is built without — so acting here
                // would look like it worked and quietly do nothing.
                if action == .askEva {
                    router.select(.eva)
                } else {
                    router.navigate(.planDay, in: .plan)
                }
            }
        }
        .accessibilityIdentifier("home.loopSpine.repair.body")
    }

    /// `.rest` asks for nothing.
    ///
    /// Closing a day must not open a new obligation, so this states the fact and
    /// stops. No CTA, no next step, no offer to plan tomorrow.
    private var spineRestBody: some View {
        HStack(alignment: .center, spacing: 18) {
            // The day, closed — the same ring from the ritual, small and
            // finished. Its completion mark is already drawn at closedProgress 1,
            // so this is a record rather than a second celebration.
            LifeBoardDayRing(
                plannedMinutes: nil,
                focusedMinutes: nil,
                closedProgress: 1,
                diameter: 64
            )
            .accessibilityHidden(true)

            Text("Nothing more is being asked of you today.")
                .font(LifeBoardFoundationTypography.body())
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lifeBoardClaySurface(.resting, cornerRadius: LifeBoardFoundationRadius.card)
        // Arrives, settles, and stops. A closed day must not shimmer, so there
        // is deliberately no TimelineView, no repeatForever, and no CTA — the
        // whole point of `.rest` is that it asks for nothing.
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today is closed. Nothing more is being asked of you today.")
        .accessibilityIdentifier("home.loopSpine.rest")
    }

    /// The day-loop stage Home is currently in.
    ///
    /// Loop state first, clock second — see `DayLoopStageResolver`. Drift is not
    /// wired yet, so `.repair` cannot be reached from here; the case exists so
    /// the stage set is complete for the surfaces that will consume it.
    private var dayLoopStage: DayLoopStage {
        // Read so a snooze re-evaluates this without a full Home reload.
        _ = dayRitualSnoozeGeneration
        let now = Date()
        let engine = DayCompassEngine()
        let calendar = Calendar.current

        #if DEBUG
        // The morning and evening windows leave the ritual unreachable for most
        // of the working day, which would force a seeded journey to either
        // mutate the device clock or wait until 18:00. Neither is a
        // condition-based wait, so the stage is forceable in Debug only.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-LIFEBOARD_FORCE_DAY_CLOSE") { return .close }
        if arguments.contains("-LIFEBOARD_FORCE_DAY_OPEN") { return .commit }
        // Repair needs two drifted blocks that are both over 15 minutes old,
        // which a seeded journey cannot arrange without waiting out the clock.
        if arguments.contains("-LIFEBOARD_FORCE_DAY_REPAIR") { return .repair }
        #endif

        return DayLoopStageResolver.resolve(
            closedToday: dayLoopClosedToday,
            openedToday: dayLoopCommittedToday,
            isMorningWindow: engine.isMorningPlanWindow(now, calendar: calendar),
            isEveningWindow: engine.isEveningReviewWindow(now, calendar: calendar),
            // Already filtered by `PlanDriftPolicy`: one slipped block is a
            // normal day and stays at 0, so this only rises when the day has a
            // shape worth looking at.
            driftCount: lifeOSStore.driftCount,
            // Low Energy changes the spine's *stage set*, not its visibility.
            // Repair is the one stage that asks something extra of a day already
            // going badly, so it is the one Low Energy drops.
            suppressesRepair: router.dashboardMode == .lowEnergy
        )
    }

    /// The ritual row, or `nil` when the day is already closed or the evening
    /// offer was snoozed.
    ///
    /// The door is open at every stage except `.rest`. Previously it existed
    /// only between 05:00–11:00 and 18:00–midnight, so a day finished early —
    /// or a day whose owner works nights — had nowhere to put it down.
    private var activeDayRitual: DayRitualEntry? {
        let now = Date()
        let stage = dayLoopStage
        guard stage.offersClose else { return nil }

        if stage == .commit {
            return DayRitualEntry(
                route: .dayOpen(now),
                title: "What carried over",
                // Deliberately does not claim "last night's decisions" yet: the
                // morning currently reads *today*, so on a day that was never
                // closed that phrasing is false. The claim comes back when the
                // retrospective day is wired.
                subtitle: "Today's shape, and what's still open.",
                symbol: "sunrise",
                isEvening: false
            )
        }

        let snoozes = DayCompassSnoozeStore().load(now: now, calendar: .current)
        guard snoozes.isSnoozed(.eveningReview, at: now) == false else { return nil }
        return DayRitualEntry(
            route: .dayClose(now),
            // Matches the wording already shipped in `LBDayCompassCard` rather
            // than inventing a second voice for the same moment.
            title: "Close the day",
            subtitle: stage == .close
                ? "Reflect once, and set tomorrow's first thing."
                // Before evening the same door stays open, without implying the
                // day is over or that anything is late.
                : "Put the day down whenever you're ready.",
            symbol: "moon.stars",
            isEvening: stage == .close
        )
    }

    /// Refreshes `.rest` from the ledger. The receipt's applied/undone state is
    /// the record, so an undone close correctly reopens the ritual.
    private func refreshDayLoopStage() async {
        guard let planningRepository else { return }
        let now = Date()
        let today = PlanningDay(date: now)
        let closeSource = DayCloseScenarioBuilder.receiptSource(for: today)
        let openSource = DayOpenScenarioBuilder.receiptSource(for: today)
        dayLoopClosedToday = (try? await planningRepository.hasAppliedReceipt(source: closeSource)) ?? false
        dayLoopCommittedToday = (try? await planningRepository.hasAppliedReceipt(source: openSource)) ?? false

        // One fetch covers both the stage and the rhythm. Bounded to the window
        // plus a day so this never walks the whole receipt history.
        let horizon = Calendar.current.date(
            byAdding: .day,
            value: -(DayLoopLedger.defaultWindow + 1),
            to: now
        )
        if let records = try? await planningRepository.fetchMutationReceipts(since: horizon) {
            dayLoopSummary = DayLoopLedger.summarize(records: records, now: now)
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
        let hydrationAmount = healthStore.aggregates[.water]?.value
            ?? lifeOSStore.trackSnapshot?.hydrationAmountMilliliters
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
        let steps = healthStore.aggregates[.steps]
        let activeEnergy = healthStore.aggregates[.activeEnergy]
        let candidates = [
            HomeSignalSlot(
                id: "hydration", title: "Hydration",
                valueText: hydrationAmount.map { "\(Int($0)) ml" }, progress: hydrationProgress,
                systemImage: "drop.fill",
                availability: hydrationAvailability
            ),
            HomeSignalSlot(
                id: "steps",
                title: "Steps",
                valueText: steps.map { $0.value.formatted(.number.precision(.fractionLength(0))) },
                progress: steps.map { min(1, $0.value / 10_000) },
                systemImage: "figure.walk",
                availability: homeAvailability(for: .activity, value: steps)
            ),
            HomeSignalSlot(
                id: "active",
                title: "Active",
                valueText: activeEnergy.map { "\(Int($0.value)) kcal" },
                progress: activeEnergy.map { min(1, $0.value / 500) },
                systemImage: "flame.fill",
                availability: homeAvailability(for: .energy, value: activeEnergy)
            ),
            HomeSignalSlot(
                id: "fasting",
                title: "Fasting",
                valueText: nil,
                progress: lifeOSStore.activeFast.flatMap { fast in
                    fast.targetDuration.flatMap { $0 > 0 ? min(1, fast.elapsed() / $0) : nil }
                },
                systemImage: "timer",
                availability: phaseIIRepository != nil ? .available : .unavailable
            )
        ]
        // These are explicitly configured Home signals. The relevance budget
        // still controls every other Home module, but silently dropping a
        // configured timer makes its active state unreachable. Preserve all
        // four and use ranking only to order the three Health facts.
        let healthSlots = candidates
            .filter { $0.id != "fasting" }
            .sorted { signalRank($0) > signalRank($1) }
        let slots = healthSlots + candidates.filter { $0.id == "fasting" }
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(slots) { slot in compactSignalRing(slot, palette: palette) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.signalRow")
        } else {
            HStack(spacing: 8) {
                ForEach(slots) { slot in compactSignalRing(slot, palette: palette) }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.signalRow")
        }
    }

    private func homeAvailability(
        for domain: HealthDomain,
        value: HealthAggregateValue?
    ) -> HomeSignalState {
        let signal = healthStore.statuses[domain]?.signal ?? .setupRequired
        switch signal {
        case .loading: return .loading
        case .setupRequired: return .permissionRequired
        case .stale, .partial: return value == nil ? .unavailable : .stale
        case .unavailable, .protectedDataLocked, .offline, .writeDenied: return value == nil ? .unavailable : .stale
        case .noRecord: return .setupRequired
        case .explicitZero, .recorded: return value == nil ? .setupRequired : .available
        }
    }

    private func signalRank(_ slot: HomeSignalSlot) -> Int {
        let stateRank: Int = switch slot.availability {
        case .available: 40
        case .stale: 30
        case .loading: 20
        case .setupRequired, .permissionRequired: 10
        case .unavailable: 0
        }
        let domainRank: Int = switch slot.id {
        case "steps": 4
        case "active": 3
        case "hydration": 2
        case "fasting": 1
        default: 0
        }
        return stateRank + domainRank
    }

    @ViewBuilder
    private func compactSignalRing(_ slot: HomeSignalSlot, palette: LifeBoardDaypartPalette) -> some View {
        if slot.id == "fasting" {
            fastingSignal(palette: palette)
        } else {
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
                .frame(maxWidth: .infinity, minHeight: 100)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(slot.title), \(slot.valueText ?? accessibilityAvailability(slot.availability))")
            .accessibilityIdentifier("home.signal.\(slot.id)")
        }
    }

    private func fastingSignal(palette: LifeBoardDaypartPalette) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let activeFast = lifeOSStore.activeFast
            let mealAnchor = HomeFastingAnchorPolicy.recentMealAnchor(
                latestMealAt: lifeOSStore.recentMealAt,
                now: context.date
            )
            let openAnchor = mealAnchor ?? lifeOSStore.latestEndedFast?.endedAt
            let elapsed = activeFast?.elapsed(at: context.date)
                ?? openAnchor.map { max(0, context.date.timeIntervalSince($0)) }
                ?? 0
            let progress = activeFast?.targetDuration.flatMap { target in
                target > 0 ? min(1, elapsed / target) : nil
            } ?? 0
            let isAvailable = phaseIIRepository != nil

            Button {
                guard isAvailable else {
                    router.select(.track)
                    return
                }
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                if activeFast == nil {
                    let startDate = HomeFastingAnchorPolicy.recentMealAnchor(
                        latestMealAt: lifeOSStore.recentMealAt,
                        now: Date()
                    ) ?? Date()
                    Task { await commitFastStart(at: startDate) }
                } else {
                    Task { await commitFastEnd() }
                }
            } label: {
                VStack(spacing: 5) {
                    ZStack {
                        Circle()
                            .fill(palette.color(for: .canvasSecondary).opacity(0.62))
                        Circle()
                            .stroke(
                                palette.color(for: .foregroundSecondary).opacity(activeFast == nil ? 0.48 : 0.20),
                                style: StrokeStyle(lineWidth: activeFast == nil ? 2.5 : 5, dash: activeFast == nil ? [3, 5] : [])
                            )
                        if activeFast != nil {
                            Circle()
                                .trim(from: 0, to: max(0.025, progress))
                                .stroke(
                                    Color(LifeBoardColorTokens.foundationSunAccent),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .lifeboardFastingEmberRing(
                                    progress: progress,
                                    tint: Color(LifeBoardColorTokens.foundationSunAccent)
                                )
                        }
                        VStack(spacing: 0) {
                            Text(compactHours(elapsed))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                                .contentTransition(.numericText())
                            Text(activeFast != nil ? "fast" : (mealAnchor == nil ? "open" : "since meal"))
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
                    }
                    .frame(width: 58, height: 58)

                    Text("Fasting")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(isAvailable ? (activeFast == nil ? (mealAnchor == nil ? "Start" : "Start from meal") : "End") : "Unavailable")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .foregroundStyle(
                            isAvailable
                                ? Color(LifeBoardColorTokens.inkPrimary)
                                : palette.color(for: .foregroundSecondary)
                        )
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .contentShape(Rectangle())
                .lifeboardClayPressBloom(
                    center: .center,
                    trigger: fastingStateChangeTrigger,
                    tint: Color(LifeBoardColorTokens.foundationSunAccent)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(activeFast == nil ? "Start fasting timer" : "End fasting timer")
            .accessibilityValue(
                activeFast == nil
                    ? "Open window, \(spokenHours(elapsed))"
                    : "Fasting, \(spokenHours(elapsed))"
            )
            .accessibilityHint(
                activeFast == nil
                    ? (mealAnchor == nil ? "Starts now" : "Starts from your latest meal with one tap")
                    : "Saves the end time with one tap; an Undo appears below"
            )
            .accessibilityIdentifier("home.signal.fasting")
        }
    }

    private func compactHours(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }

    private func spokenHours(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours) hours, \(minutes) minutes"
    }

    @MainActor
    private func commitFastStart(at date: Date) async {
        if await lifeOSStore.startFast(targetDuration: nil, at: date) {
            showsFastEndReceipt = false
            fastingStateChangeTrigger &+= 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            showsFastingError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    @MainActor
    private func commitFastEnd() async {
        if await lifeOSStore.endActiveFast() {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.38, bounce: 0.16)) {
                showsFastEndReceipt = true
            }
            fastingStateChangeTrigger &+= 1
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            showsFastingError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func fastingEndReceipt(palette: LifeBoardDaypartPalette) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            VStack(alignment: .leading, spacing: 2) {
                Text("Fast saved")
                    .font(.subheadline.weight(.semibold))
                Text("Your open-window clock is running.")
                    .font(.caption)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Spacer(minLength: 8)
            Button("Undo") {
                Task {
                    if await lifeOSStore.undoLastFastEnd() {
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.34, bounce: 0.12)) {
                            showsFastEndReceipt = false
                        }
                        fastingStateChangeTrigger &+= 1
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } else {
                        showsFastingError = true
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .lifeBoardClaySurface(.raised, cornerRadius: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.fasting.receipt")
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

    private func tasksWidget(placementID: UUID, palette: LifeBoardDaypartPalette) -> some View {
        let snapshot = lifeOSStore.planSnapshot
        let tasks = lifeOSStore.taskAgenda.tasks
        let collapsedLimit = router.dashboardMode == .lowEnergy ? 2 : 4
        let isExpanded = expandedTaskWidgetIDs.contains(placementID)
        let visibleTasks = isExpanded ? tasks : Array(tasks.prefix(collapsedLimit))
        let hasHiddenTasks = tasks.count > collapsedLimit
        return VStack(alignment: .leading, spacing: 12) {
            taskWidgetHeader(isExpanded: isExpanded, palette: palette)
            if hasPlanningRepository == false {
                honestEmptyState("Tasks are unavailable right now", symbol: "exclamationmark.triangle", palette: palette)
            } else if lifeOSStore.isLoading, snapshot == nil {
                honestEmptyState("Loading tasks", symbol: "hourglass", palette: palette)
            } else if tasks.isEmpty {
                honestEmptyState(taskWidgetEmptyMessage, symbol: "checkmark.circle", palette: palette)
            } else {
                ForEach(visibleTasks) { task in
                    taskWidgetRow(task, palette: palette)
                }
            }
            // A completion is a real mutation, so it gets a receipt here rather
            // than relying on Plan's Undo, which reads a different PlanStore
            // instance and can never see a completion made from Home.
            if let completed = lifeOSStore.lastCompletedTask {
                HStack(spacing: 8) {
                    Text("Completed “\(completed.title)”")
                        .font(.caption)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Undo") {
                        Task { await lifeOSStore.undoLastTaskCompletion() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityHint("Reopens \(completed.title)")
                    .accessibilityIdentifier("home.tasks.undoCompletion")
                }
                .buttonStyle(.plain)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    taskWidgetAddButton
                    Spacer(minLength: 8)
                    if isExpanded || hasHiddenTasks {
                        taskWidgetExpansionButton(isExpanded: isExpanded, placementID: placementID)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    taskWidgetAddButton
                    if isExpanded || hasHiddenTasks {
                        taskWidgetExpansionButton(isExpanded: isExpanded, placementID: placementID)
                    }
                }
            }
        }
        .padding(16)
        .background {
            // Keep the clay surface in its own noninteractive render subtree.
            // An arbitrarily tall expanded agenda must not apply
            // `lifeBoardRaisedClayCard` directly to its foreground hierarchy.
            Color.clear
                .lifeBoardRaisedClayCard(palette: palette)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .animation(taskWidgetAnimation, value: isExpanded)
        .animation(taskWidgetAnimation, value: lifeOSStore.taskAgenda)
    }

    @ViewBuilder
    private func taskWidgetHeader(isExpanded: Bool, palette: LifeBoardDaypartPalette) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                taskWidgetTitleLabel(palette: palette)
                if isExpanded {
                    HomeTaskAgendaDatePicker(store: lifeOSStore)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                taskWidgetTitleLabel(palette: palette)
                if isExpanded {
                    HomeTaskAgendaDatePicker(store: lifeOSStore)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.widget.tasks")
    }

    private func taskWidgetTitleLabel(palette: LifeBoardDaypartPalette) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checklist")
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(taskWidgetTitle)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private var taskWidgetTitle: String {
        let selectedDate = lifeOSStore.taskAgenda.selectedDate
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today’s tasks"
        }
        return "\(selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) tasks"
    }

    private var taskWidgetEmptyMessage: String {
        let selectedDate = lifeOSStore.taskAgenda.selectedDate
        if Calendar.current.isDateInToday(selectedDate) {
            return "No overdue tasks or tasks due today"
        }
        let date = selectedDate.formatted(.dateTime.month(.abbreviated).day())
        return "No overdue tasks or tasks due \(date)"
    }

    private func taskWidgetRow(_ task: PlanningTaskSummary, palette: LifeBoardDaypartPalette) -> some View {
        // The completion control is a sibling of the navigating button, never
        // nested inside it: a Button within a Button gives its tap to the outer
        // one and would silently open detail instead of completing the task.
        HStack(spacing: 11) {
            if V2FeatureFlags.lifeBoardDailyLoopV1Enabled {
                LifeBoardCompletionControl(
                    isComplete: false,
                    title: task.title
                ) { _ in
                    Task { await lifeOSStore.setTaskCompletion(task, to: true) }
                }
                .padding(.leading, -11)
            } else {
                Image(systemName: task.metadata.commitmentLevel == .mustDo ? "exclamationmark.circle.fill" : "circle")
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Button {
                router.navigate(.taskDetail(task.id), in: .home)
            } label: {
                HStack(spacing: 11) {
                    if task.metadata.commitmentLevel == .mustDo {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                            .accessibilityLabel("Must do")
                    }
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
            .lifeBoardTransitionSource("route.task.\(task.id.uuidString)")
            .accessibilityIdentifier("home.task.\(task.id.uuidString)")
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private var taskWidgetAddButton: some View {
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

    private func taskWidgetExpansionButton(isExpanded: Bool, placementID: UUID) -> some View {
        Button {
            withAnimation(taskWidgetAnimation) {
                if isExpanded {
                    expandedTaskWidgetIDs.remove(placementID)
                    lifeOSStore.resetTaskAgendaDateToToday()
                } else {
                    lifeOSStore.resetTaskAgendaDateToToday()
                    expandedTaskWidgetIDs.insert(placementID)
                }
            }
        } label: {
            Label(isExpanded ? "Show less" : "Show more", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                .font(.subheadline.weight(.semibold))
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isExpanded ? "home.tasks.showLess" : "home.tasks.showMore")
        .accessibilityHint(isExpanded ? "Collapses the task card and returns to today" : "Shows every overdue task and task due today")
    }

    private var taskWidgetAnimation: Animation? {
        guard reduceMotion == false else { return nil }
        return motionAnimation
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

    private func journalCaptureButton(palette: LifeBoardDaypartPalette) -> some View {
        Button {
            captureRouter.request(kind: .journal, source: .widget)
        } label: {
            Label("Write", systemImage: "square.and.pencil")
                .lineLimit(1)
        }
        .buttonStyle(LifeBoardPrimaryActionStyle(fill: palette.color(for: .foreground)))
        .accessibilityIdentifier("home.journal.capture")
    }

    private func journalSearchButton() -> some View {
        Button {
            router.navigate(.journalSearch, in: .home)
        } label: {
            Label("Search", systemImage: "magnifyingglass")
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("home.journal.search")
    }

    private func journalWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            widgetTitle("Journal", symbol: "book.closed", palette: palette)
                .accessibilityIdentifier("home.widget.journal")
            Text("Keep one honest moment from today—words, photos, or audio.")
                .font(.subheadline)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .fixedSize(horizontal: false, vertical: true)
            // In a half-width card these two buttons get about 63pt each, which
            // is narrower than "Search" plus its symbol. Laid out in a fixed
            // HStack the labels wrapped to one character per line and the
            // buttons grew to ~350pt tall. `ViewThatFits` keeps the side-by-side
            // arrangement wherever it genuinely fits and stacks otherwise.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    journalCaptureButton(palette: palette)
                    journalSearchButton()
                }
                VStack(spacing: 8) {
                    journalCaptureButton(palette: palette)
                    journalSearchButton()
                }
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

    @ViewBuilder
    private var progressMetricLabels: some View {
        Label("\(projectionAdapter.snapshot.openTaskCount) open", systemImage: "checklist")
            .lineLimit(1)
        Spacer(minLength: 0)
        // Was `snapshot.streakDays` — `GamificationEngine`'s "consecutive days
        // with any XP event", which is not a fact about the loop at all. These
        // two come from applied close receipts, so the number cannot disagree
        // with what actually happened, and Undo moves it.
        if let rhythm = dayLoopRhythmText {
            // Two lines rather than one: the Progress card renders in a 2-up
            // grid, and truncating to "1 of 14 days · 1 day…" would hide one of
            // the two honest facts. DESIGN.md forbids
            // shrinking type to preserve a grid, so it wraps instead.
            Label(rhythm, systemImage: "circle.hexagongrid")
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The loop's rhythm: how the last two weeks went, then the current run.
    ///
    /// Both numbers render at the same size in the same label, which is the
    /// anti-guilt mechanism — it is arithmetic, not copy. Consistency leads so
    /// breaking a run cannot make the smallest number the first visual fact.
    ///
    /// `nil` before anything has been closed: "0 days running" would be a
    /// verdict on nothing.
    private var dayLoopRhythmText: String? {
        guard let summary = dayLoopSummary, summary.hasNoHistory == false else { return nil }
        let window = "\(summary.closedInWindow) of \(summary.window) days"
        guard summary.runLength > 0 else { return window }
        let run = summary.runLength == 1 ? "1 day running" : "\(summary.runLength) days running"
        return "\(window) · \(run)"
    }

    private func progressWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            widgetTitle(router.dashboardMode == .lowEnergy ? "Continuity" : "Progress", symbol: "chart.line.uptrend.xyaxis", palette: palette)
                .accessibilityIdentifier("home.widget.progressReflection")
            ProgressView(value: projectionAdapter.snapshot.completionRate)
                .tint(palette.color(for: .celestialCore))
                .accessibilityLabel("Today’s progress")
                .accessibilityValue(projectionAdapter.snapshot.completionRate.formatted(.percent))
            // Half-width cards hyphenated "continuity" mid-word. These two
            // metrics wrap as a unit rather than breaking their own labels.
            ViewThatFits(in: .horizontal) {
                HStack {
                    progressMetricLabels
                }
                VStack(alignment: .leading, spacing: 6) {
                    progressMetricLabels
                }
            }
            .font(.caption.weight(.medium))
            Divider().overlay(Color(LifeBoardColorTokens.foundationHairline))
            Button {
                // The label promises evidence, so open the evidence route with
                // its disclosure already expanded rather than the Insights
                // overview the user then has to dig through.
                router.select(.insights)
                router.push(.insightEvidence(nil), in: .insights)
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
                    .buttonStyle(LifeBoardPrimaryActionStyle(fill: palette.color(for: .foreground)))
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
                .frame(width: 44, height: 44)
                .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: Circle())
                .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow), radius: 6, y: 2)
        }
        .accessibilityLabel("Edit widget")
        .accessibilityIdentifier("home.widget.edit.\(placement.id.uuidString)")
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

/// Drives the one-shot erosion when a card is hidden from Home. The animation
/// owns only its own progress; the layout draft has already removed the card,
/// so an interrupted dissolve can never strand the board in a wrong state.
private struct HomeCardDissolveModifier: ViewModifier {
    let isDissolving: Bool
    let tint: Color
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: Double = 0

    private let duration: TimeInterval = 0.36

    func body(content: Content) -> some View {
        content
            .lifeboardDissolveAway(progress: progress, tint: tint)
            .onChange(of: isDissolving) { _, dissolving in
                guard dissolving else {
                    progress = 0
                    return
                }
                guard reduceMotion == false else {
                    onFinish()
                    return
                }
                withAnimation(.easeIn(duration: duration)) { progress = 1 }
                Task {
                    try? await Task.sleep(for: .seconds(duration))
                    progress = 0
                    onFinish()
                }
            }
    }
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

        widenRowsWithNoNeighbour(&result, subviews: subviews, fullWidth: width)

        return (result, max(0, result.map(\.maxY).max() ?? 0))
    }

    /// Gives a card the full content width when nothing sits beside it.
    ///
    /// Spans are declared against the semantic grid, so a two-column card in a
    /// section that only ever contains one card rendered at half width with the
    /// other half left empty — Home's "Today" section did exactly that, squeezing
    /// three-word task titles onto two lines each while the space next to them
    /// stayed blank. The same happened to a trailing odd card in a longer section.
    ///
    /// A card alone in its vertical band is safe to widen: because nothing overlaps
    /// that band, re-measuring only changes its own height, so everything below it
    /// shifts by that delta and no repacking is needed. Subview order is untouched,
    /// which matters because the Home hierarchy test walks widgets top to bottom
    /// and cannot scroll back.
    private func widenRowsWithNoNeighbour(
        _ frames: inout [CGRect],
        subviews: Subviews,
        fullWidth: CGFloat
    ) {
        let tolerance: CGFloat = 0.5
        for index in frames.indices {
            let original = frames[index]
            guard original.width < fullWidth - tolerance else { continue }
            let hasNeighbour = frames.indices.contains { other in
                guard other != index else { return false }
                let candidate = frames[other]
                let entirelyBelow = candidate.minY >= original.maxY - tolerance
                let entirelyAbove = candidate.maxY <= original.minY + tolerance
                return entirelyBelow == false && entirelyAbove == false
            }
            guard hasNeighbour == false else { continue }

            let measured = subviews[index].sizeThatFits(
                ProposedViewSize(width: fullWidth, height: nil)
            )
            frames[index] = CGRect(
                x: 0,
                y: original.minY,
                width: fullWidth,
                height: measured.height
            )

            let delta = measured.height - original.height
            guard abs(delta) > tolerance else { continue }
            for other in frames.indices where other != index {
                if frames[other].minY >= original.maxY - tolerance {
                    frames[other].origin.y += delta
                }
            }
        }
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
                // The one line in the app that is addressed to the person
                // rather than reporting to them, so it is the one line that
                // answers to a touch. The renderer is identity at rest, and it
                // suppresses itself entirely under Reduce Motion, accessibility
                // Dynamic Type, low power, and the screenshot fixtures.
                .lifeBoardKineticGreeting()

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
