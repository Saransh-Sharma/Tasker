import Combine
import Observation
import SwiftUI
import LifeBoardDomain
import UIKit

struct AdaptiveTimelineItem: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
}

struct AdaptiveHomeProjectionSnapshot: Equatable, Sendable {
    var selectedDate = HomeReferenceClock.now
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
    let destination: Destination
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

    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    #if DEBUG
    init(designSnapshot: AdaptiveHomeProjectionSnapshot) {
        snapshot = designSnapshot
    }
    #endif

    init(homeViewModel: HomeViewModel) {
        homeViewModel.$homeRenderTransaction
            .removeDuplicates()
            .sink { [weak self] transaction in self?.apply(transaction) }
            .store(in: &cancellables)
        apply(homeViewModel.homeRenderTransaction)
    }

    private func apply(_ transaction: HomeRenderTransaction) {
        let nextSnapshot = Self.project(transaction)
        guard nextSnapshot != snapshot else { return }
        snapshot = nextSnapshot
    }

    static func project(_ transaction: HomeRenderTransaction) -> AdaptiveHomeProjectionSnapshot {
        let chrome = transaction.chrome
        let tasks = transaction.tasks
        let habits = transaction.habits
        let calendar = transaction.calendar
        let nextSnapshot = AdaptiveHomeProjectionSnapshot(
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
        return nextSnapshot
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
    @ObservationIgnored private let contextEngine: HomeContextService
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
        contextEngine = HomeContextService(policy: contextPolicy)
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
            #if DEBUG
            if HomeProductionEvidenceProfile.enabled {
                layout = HomeProductionEvidenceProfile.layout
                try await repository?.saveHome(layout)
            }
            #endif
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
        layout.placements = HomeGridPackingService.normalized(layout.placements + [placement])
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
        Haptic.pick.play()
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

    func addWidget(_ descriptor: DashboardWidgetDescriptor, size: WidgetSizePreset? = nil) {
        guard var value = draft else { return }
        let selectedSize = size ?? descriptor.defaultSize
        guard descriptor.supportedSizes.contains(selectedSize) else { return }
        value.add(kind: descriptor.kind, size: selectedSize, registry: registry)
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
        now: Date = HomeReferenceClock.now,
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

    func applyPendingContext(now: Date = HomeReferenceClock.now) {
        refreshContext(candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext, now: now)
    }

    func canReevaluateContext(now: Date = HomeReferenceClock.now, force: Bool = false) -> Bool {
        contextEngine.canReevaluate(now: now, force: force)
    }

    func hideContextForToday(_ candidate: HomeContextCandidate, now: Date = HomeReferenceClock.now) {
        contextPreferences.hideForToday(candidate.id, now: now)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    func suggestContextLessOften(_ candidate: HomeContextCandidate, now: Date = HomeReferenceClock.now) {
        contextPreferences.set(.suggestLess, for: candidate.id)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    /// Puts a suppressed suggestion back into consideration.
    func restoreContextSuggestion(_ candidate: HomeContextCandidate, now: Date = HomeReferenceClock.now) {
        contextPreferences.clear(candidate.id, now: now)
        refreshContext(
            candidates: contextCandidates,
            permitsSensitiveHomeContent: permitsSensitiveContext,
            now: now,
            force: true
        )
    }

    func neverSuggestContext(_ candidate: HomeContextCandidate, now: Date = HomeReferenceClock.now) {
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

    /// Restores a candidate to no stated preference. Without this, "Never
    /// suggest this" was a one-way door with no receipt.
    func clear(_ candidateID: String, now: Date, calendar: Calendar = .current) {
        stored.persistent[candidateID] = nil
        stored.hiddenByDay[dayKey(for: now, calendar: calendar)]?.remove(candidateID)
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

extension JournalMood {
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

struct JournalMoodDialSheet: View {
    @Binding var selectedMood: JournalMood
    let onSave: (Int?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draftMood: JournalMood
    @State private var stage: Stage = .mood
    @State private var energy = 3.0
    @State private var includesEnergy = false

    private enum Stage { case mood, energy }

    init(selectedMood: Binding<JournalMood>, onSave: @escaping (Int?) -> Void) {
        _selectedMood = selectedMood
        _draftMood = State(initialValue: selectedMood.wrappedValue)
        self.onSave = onSave
    }

    var body: some View {
        let palette = DaypartTokens.palette(for: .afternoon)
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

    private func header(palette: DaypartPalette) -> some View {
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
                    Haptic.commit.play()
                    dismiss()
                }
            }
            .fontWeight(.semibold)
            .frame(minWidth: 56, minHeight: 44)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private func moodStage(palette: DaypartPalette) -> some View {
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
                    .lifeboardFont(.screenTitle)
                Text(draftMood.supportiveCopy)
                    .font(.body)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))

                JournalMoodWheel(selectedMood: $draftMood, palette: palette)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.top, 8)
        }
    }

    private func energyStage(palette: DaypartPalette) -> some View {
        VStack(spacing: 26) {
            Spacer()
            Image(draftMood.largeAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .accessibilityHidden(true)
            Text(includesEnergy ? energyLabel : "Energy is optional")
                .lifeboardFont(.metric)
            Toggle("Add an energy signal", isOn: $includesEnergy)
                .font(.headline)
                .padding(16)
                .lifeBoardRaisedClayCard(palette: palette)
            if includesEnergy {
                // A dial rather than a slider: energy is a level being tuned,
                // not a position on a line, and the arc keeps the five detents
                // far enough apart to hit without looking.
                ArcDial(
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

private struct JournalMoodWheel: View {
    @Binding var selectedMood: JournalMood
    let palette: DaypartPalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let diameter = max(420, proxy.size.width * 1.36)
            let center = CGPoint(x: proxy.size.width / 2, y: diameter / 2 + 62)
            ZStack {
                ForEach(Array(JournalMood.dialOrder.enumerated()), id: \.element.id) { index, mood in
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
                                color: Color(SemanticColorTokens.foundationWarmShadow).opacity(mood == selectedMood ? 0.2 : 0.08),
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
                let current = JournalMood.dialOrder.firstIndex(of: selectedMood) ?? 4
                let next: Int
                switch direction {
                case .increment: next = min(current + 1, JournalMood.dialOrder.count - 1)
                case .decrement: next = max(current - 1, 0)
                @unknown default: return
                }
                select(JournalMood.dialOrder[next])
            }
        }
    }

    private func angleDegrees(for index: Int) -> Double {
        205 + Double(index) * (130 / Double(max(1, JournalMood.dialOrder.count - 1)))
    }

    private func nearestMood(to point: CGPoint, center: CGPoint) -> JournalMood {
        let raw = atan2(point.y - center.y, point.x - center.x) * 180 / .pi
        let normalized = raw < 0 ? raw + 360 : raw
        let index = JournalMood.dialOrder.indices.min {
            abs(angleDegrees(for: $0) - normalized) < abs(angleDegrees(for: $1) - normalized)
        } ?? 4
        return JournalMood.dialOrder[index]
    }

    private func select(_ mood: JournalMood) {
        guard mood != selectedMood else { return }
        if reduceMotion {
            selectedMood = mood
        } else {
            withAnimation(LifeBoardAnimation.roleLocalState) { selectedMood = mood }
        }
        Haptic.pick.play()
    }
}

struct OverlayHost<Overlay: View, Control: View>: View {
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
        VStack(spacing: 12) {
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

/// Coalesces Home invalidations into one cancellation-aware generation.
/// The coordinator intentionally owns no view data: expensive provider work
/// happens in the supplied operation and only the current generation may
/// publish its result.
enum HomeRefreshUrgency: Sendable { case automatic, immediate }
typealias HomeRefreshReason = HomeContextRefreshBoundary

struct HomeRefreshRequest {
    var now: Date
    var boundary: HomeRefreshReason
    var reasons: Set<HomeRefreshReason>
    var urgency: HomeRefreshUrgency
}

@MainActor
final class AdaptiveHomeRefreshCoordinator {
    typealias Request = HomeRefreshRequest
    private var task: Task<Void, Never>?
    private var generation = 0
    private var isDebouncing = false
    private let debounce: @MainActor () async throws -> Void

    init(debounce: @escaping @MainActor () async throws -> Void = {
        try await Task.sleep(for: .milliseconds(100))
    }) { self.debounce = debounce }
    private var pending: Request?
    private var activeRequest: Request?
    private var deferred = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]
    private(set) var requestCount = 0
    private(set) var executedCount = 0
    private(set) var completedCount = 0

    func request(now: Date, boundary: HomeRefreshReason, immediate: Bool, deferred: Bool,
                 operation: @escaping @MainActor (Request, Int) async -> Void) {
        requestCount += 1
        generation += 1
        var reasons = pending?.reasons ?? []
        reasons.insert(boundary)
        pending = Request(now: now, boundary: boundary, reasons: reasons,
            urgency: immediate || pending?.urgency == .immediate ? .immediate : .automatic)
        self.deferred = deferred && !immediate
        PerformanceTrace.event("HomeRefreshRequested", value: requestCount)
        if immediate, isDebouncing {
            task?.cancel()
            task = nil
            isDebouncing = false
        }
        startIfNeeded(operation: operation)
    }

    func resume(operation: @escaping @MainActor (Request, Int) async -> Void) {
        deferred = false
        startIfNeeded(operation: operation)
    }

    func isCurrent(_ candidate: Int) -> Bool { candidate == generation && !Task.isCancelled }

    func cancel() {
        // Cancelling presentation must not forget a read already removed from
        // the pending slot. Reactivation needs to retry its dirty domains.
        if let activeRequest {
            if let queued = pending {
                pending = Request(now: queued.now, boundary: queued.boundary,
                    reasons: queued.reasons.union(activeRequest.reasons),
                    urgency: queued.urgency == .immediate || activeRequest.urgency == .immediate
                        ? .immediate : .automatic)
            } else {
                pending = activeRequest
            }
        }
        activeRequest = nil
        generation += 1
        task?.cancel()
        task = nil
        isDebouncing = false
        deferred = true
        finishWaiters()
    }

    func waitUntilSettled() async {
        guard task != nil || pending != nil, !Task.isCancelled else { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                if Task.isCancelled || (task == nil && pending == nil) { continuation.resume() }
                else { waiters[id] = continuation }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.waiters.removeValue(forKey: id)?.resume() }
        }
    }

    private func finishWaiters() {
        let values = waiters.values
        waiters.removeAll()
        values.forEach { $0.resume() }
    }

    private func startIfNeeded(operation: @escaping @MainActor (Request, Int) async -> Void) {
        guard task == nil, pending != nil, !deferred else { return }
        task = Task { [weak self] in
            guard let self else { return }
            if pending?.urgency == .automatic {
                isDebouncing = true
                do { try await debounce(); try Task.checkCancellation() } catch { return }
                isDebouncing = false
            }
            while let request = pending, !deferred, !Task.isCancelled {
                pending = nil
                activeRequest = request
                let current = generation
                executedCount += 1
                PerformanceTrace.event("HomeRefreshExecuted", value: executedCount)
                await operation(request, current)
                guard !Task.isCancelled else { return }
                activeRequest = nil
                if isCurrent(current) {
                    completedCount += 1
                    PerformanceTrace.event("HomeRefreshCompleted", value: completedCount)
                }
            }
            task = nil
            if pending == nil { finishWaiters() }
        }
    }
}

struct HomeDashboardRenderPlan: Equatable {
    var budget: HomeSectionBudget
    var visible: [DashboardWidgetPlacementValue]
    var today: [DashboardWidgetPlacementValue]
    var keepSteady: [DashboardWidgetPlacementValue]
    var closeLoop: [DashboardWidgetPlacementValue]
    var supporting: [DashboardWidgetPlacementValue]
    var resolvedKinds: [UUID: DashboardWidgetKind]
    var effectivePresets: [UUID: WidgetSizePreset]
    var effectiveRoles: [UUID: HomeSectionRole]
}

extension HomeDashboardRenderPlan {
    static let empty = HomeDashboardRenderPlan(budget: .init(), visible: [], today: [], keepSteady: [],
        closeLoop: [], supporting: [], resolvedKinds: [:], effectivePresets: [:], effectiveRoles: [:])
}

struct HomeDashboardRenderPlanSignature: Equatable {
    let placements: [DashboardWidgetPlacementValue]
    let mode: DashboardMode
    let density: DashboardDensity
    let daypart: ResolvedDaypart
    let calendarDay: Date
    let isRegular: Bool
    let usesAccessibilityLayout: Bool
    let loopSpineEnabled: Bool
    let contextCandidates: [String]
    var candidateInputs: [HomeContextCandidate] = []
    var dynamicType: String = ""
    var locale: String = ""
    var timeZone: String = ""
    var permitsSensitive = false
}

@MainActor
final class HomeDashboardRenderPlanCache {
    private var signature: HomeDashboardRenderPlanSignature?
    private var plan: HomeDashboardRenderPlan?
    private(set) var buildCount = 0

    func resolve(
        signature: HomeDashboardRenderPlanSignature,
        build: () -> HomeDashboardRenderPlan
    ) -> HomeDashboardRenderPlan {
        if self.signature == signature, let plan { return plan }
        let next = build()
        self.signature = signature
        plan = next
        buildCount &+= 1
        PerformanceTrace.event("HomeDashboardRenderPlanBuilt", value: buildCount)
        return next
    }
}

struct AdaptiveHome: View {
    let projectionAdapter: HomeProjectionCoordinator
    let preferences: PresentationPreferences
    let router: AppRouter
    let captureRouter: CaptureRouter
    let phaseIIRepository: (any PhaseIIRepository)?
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
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @State private var selectedMood: JournalMood = .none
    @State private var moodEnergy: Int?
    @State private var moodSaveError: String?
    @State private var showsMoodDial = false
    @State private var captureOrbState = CaptureOrbPresentationState()
    @State private var contextReasonCandidate: HomeContextCandidate?
    @State private var expandedTaskWidgetIDs: Set<UUID> = []
    @State private var showsFastingError = false
    @State private var showsFastEndReceipt = false
    @State private var contextSuppressionReceipt: ActionReceiptPresentation?
    @State private var suppressedContext: HomeContextCandidate?
    @State private var fastingStateChangeTrigger = 0
    @State private var refreshCoordinator = AdaptiveHomeRefreshCoordinator()
    @State private var renderPlanCache = HomeDashboardRenderPlanCache()
    @State private var presentedRenderPlan = HomeDashboardRenderPlan.empty
    @State private var isScrolling = false
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
    @Environment(\.lifeBoardRootActivity) private var rootActivity

    init(
        projectionAdapter: HomeProjectionCoordinator,
        preferences: PresentationPreferences,
        router: AppRouter,
        captureRouter: CaptureRouter,
        repository: (any DashboardLayoutRepository)?,
        phaseIIRepository: (any PhaseIIRepository)? = nil,
        planningRepository: CoreDataPlanningRepository? = nil,
        trackFoundationRepository: CoreDataTrackFoundationRepository? = nil,
        goalSampleProvider: (any GoalSampleRepository)? = nil,
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
        var candidateProviders: [any HomeContextCandidateSource] = []
        if let planningRepository {
            candidateProviders.append(PlanningHomeContextCandidateSource(repository: planningRepository))
        }
        if let phaseIIRepository {
            candidateProviders.append(JournalHomeContextCandidateSource(repository: phaseIIRepository))
            candidateProviders.append(WeeklyReflectionHomeContextCandidateSource(repository: phaseIIRepository))
            candidateProviders.append(JournalMemoryHomeContextCandidateSource(repository: phaseIIRepository))
            candidateProviders.append(FastingHomeContextCandidateSource(
                repository: FastingRepositoryAdapter(repository: phaseIIRepository)
            ))
        }
        if let trackFoundationRepository {
            candidateProviders.append(GoalHomeContextCandidateSource(repository: trackFoundationRepository))
            candidateProviders.append(RoutineHomeContextCandidateSource(repository: trackFoundationRepository))
        }
        if let lifeMomentRepository {
            candidateProviders.append(LifeMomentContextCandidateSource(repository: lifeMomentRepository))
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
            lifeMomentRepository: lifeMomentRepository,
            healthMetrics: HealthCoordinator.shared.metricsReader
        ))
    }

    var body: some View {
        @Bindable var store = store
        let daypart = atmosphereSnapshot.semanticDaypart
        let palette = DaypartTokens.functionalPalette(for: daypart, colorScheme: colorScheme)
        let ambientPalette = daypart == .night && horizontalSizeClass == .regular
            ? DaypartTokens.palette(for: daypart)
            : palette
        let renderPlan = presentedRenderPlan

        ZStack(alignment: .bottom) {
            if atmosphereIsHosted == false {
                ScenicBackdrop(
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
                LazyVStack(alignment: .leading, spacing: 20) {
                    if let errorMessage = store.errorMessage {
                        StatusSurface(
                            state: .stale,
                            title: "Showing your safe Home layout",
                            message: errorMessage,
                            actionTitle: "Dismiss",
                            action: { store.dismissError() }
                        )
                    }

                    let budget = renderPlan.budget

                    if V2FeatureFlags.homeLoopSpineV1Enabled {
                        loopSpine(palette: palette, ambientPalette: ambientPalette, budget: budget)
                    } else {
                        nowSection(palette: palette)
                    }

                    homeSectionHeading(
                        "Signals",
                        palette: ambientPalette
                    )
                    HomeSignalRow(
                        lifeOSStore: lifeOSStore,
                        healthStore: healthStore,
                        router: router,
                        captureRouter: captureRouter,
                        hasTrackFoundationRepository: hasTrackFoundationRepository,
                        hasPhaseIIRepository: phaseIIRepository != nil,
                        palette: ambientPalette,
                        reduceMotion: reduceMotion,
                        showsFastEndReceipt: $showsFastEndReceipt,
                        showsFastingError: $showsFastingError,
                        fastingStateChangeTrigger: $fastingStateChangeTrigger
                    )
                    if showsFastEndReceipt {
                        HomeFastingEndReceipt(
                            lifeOSStore: lifeOSStore,
                            palette: ambientPalette,
                            reduceMotion: reduceMotion,
                            showsFastEndReceipt: $showsFastEndReceipt,
                            showsFastingError: $showsFastingError,
                            fastingStateChangeTrigger: $fastingStateChangeTrigger
                        )
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
                            placements: renderPlan.today,
                            renderPlan: renderPlan,
                            daypart: daypart,
                            palette: palette,
                            ambientPalette: ambientPalette
                        )
                    }

                    if budget.showsDayAhead {
                        HomeTodayStorySection(
                            projectionAdapter: projectionAdapter,
                            lifeOSStore: lifeOSStore,
                            router: router,
                            palette: palette
                        )
                    }

                    if budget.showsNeedsAttention, store.contextSelection.candidates.count > 1 {
                        HomeNeedsAttentionSection(
                            store: store,
                            router: router,
                            palette: palette,
                            onPinAfterAction: pinContextAfterAction
                        )
                    }

                    placementSection(
                        "Keep steady",
                        placements: renderPlan.keepSteady,
                        renderPlan: renderPlan,
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
                            placements: renderPlan.closeLoop,
                            renderPlan: renderPlan,
                            daypart: daypart,
                            palette: palette,
                            ambientPalette: ambientPalette
                        )
                    }

                    if budget.showsUserSpace {
                        userSpaceSection(
                            placements: renderPlan.supporting,
                            renderPlan: renderPlan,
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
                .padding(.top, 12)
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
                isScrolling = phase != .idle
                store.setContextFrozen(isScrolling, reason: "home-scroll")
                if isScrolling == false, contextRefreshIsDeferred == false {
                    store.applyPendingContext()
                }
            }
            .lifeBoardReportsComposerScroll()
            .accessibilityIdentifier("foundation.home.scroll")

        }
        // The screen changing time of day should feel like weather moving
        // across it, not like a palette swap.
        .lifeboardDaypartCrossDissolve(trigger: daypartTransitionTrigger, daypart: daypart)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if store.isCustomizing {
                HomeCustomizationActionBar(
                    store: store,
                    palette: palette,
                    motionAnimation: motionAnimation
                )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            } else if showsEmbeddedComposer {
                HomeLifeThreadComposer(
                    store: store,
                    router: router,
                    captureRouter: captureRouter,
                    palette: palette,
                    composerText: $composerText,
                    composerIsFocused: $composerIsFocused
                )
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
        .alert("Mood check-in needs attention", isPresented: Binding(
            get: { moodSaveError != nil }, set: { if !$0 { moodSaveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(moodSaveError ?? "The check-in could not be updated.")
        }
        .onChange(of: dashboardRenderPlanInput, initial: true) { _, _ in
            presentedRenderPlan = dashboardRenderPlan(daypart: daypart)
        }
        .task(id: rootActivity) {
            guard rootActivity.performsContinuousWork else {
                refreshCoordinator.cancel()
                lifeOSStore.setContinuousUpdatesEnabled(false)
                return
            }
            lifeOSStore.setContinuousUpdatesEnabled(false)
            await store.load()
            refreshContextSelection(boundary: .appForeground, immediate: true)
            await refreshCoordinator.waitUntilSettled()
            await refreshDayLoopStage()
            if let latest = await lifeOSStore.latestMoodCheckInToday() {
                selectedMood = latest.mood
                moodEnergy = latest.energy
            }
        }
        .task(id: rootActivity) {
            guard rootActivity.performsContinuousWork else {
                lifeOSStore.stopCommittedProjectionWork()
                return
            }
            await lifeOSStore.observeCommittedHydrationChanges()
        }
        .task(id: rootActivity) {
            guard rootActivity.performsContinuousWork else { return }
            await lifeOSStore.observeCommittedMoodChanges()
        }
        .task(id: rootActivity) {
            guard rootActivity.performsContinuousWork else { return }
            let updates = await HealthSyncInvalidationService.shared.updates()
            for await _ in updates {
                guard Task.isCancelled == false else { return }
                refreshContextSelection(boundary: .trackerCommit)
            }
        }
        .task(id: rootActivity) {
            guard rootActivity.performsContinuousWork else { return }
            for await event in await JournalProjectionInvalidationService.shared.updates() {
                guard !Task.isCancelled else { return }
                if case .projectionsInvalidated = event { refreshContextSelection(boundary: .trackerCommit) }
            }
        }
        .refreshable {
            refreshContextSelection(immediate: true)
            await refreshCoordinator.waitUntilSettled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .foundationDomainMaintenanceCommitted)) { _ in
            guard rootActivity.performsContinuousWork else { return }
            refreshContextSelection(boundary: .timerChange, immediate: true)
        }
        .onChange(of: lifeOSStore.mutationRevision) { _, _ in
            refreshContextSelection(boundary: .trackerCommit, immediate: true)
        }
        .onChange(of: projectionAdapter.snapshot) { _, _ in refreshContextSelection(boundary: .taskMutation) }
        .onChange(of: permitsSensitiveHomeContent) { _, _ in
            lifeOSStore.invalidateCardPrivacy()
            refreshContextSelection(immediate: true)
        }
        .onChange(of: daypart) { _, _ in
            refreshContextSelection(boundary: .daypartBoundary)
            daypartTransitionTrigger &+= 1
        }
        .onChange(of: voiceOverEnabled, initial: true) { _, enabled in
            // VoiceOver keeps stable card identities; it must not freeze live values.
            store.setContextFrozen(false, reason: "voiceover-focus")
            if enabled == false, contextRefreshIsDeferred == false {
                refreshCoordinator.resume(operation: performContextRefresh)
            }
        }
        // Returning from the ritual pops back to Home without a scene-phase
        // change, so without this the row would keep offering a day that was
        // just closed — and would keep hiding one that was just undone.
        .onChange(of: router.path(for: .home).count) { _, _ in
            Task { await refreshDayLoopStage() }
        }
        .onChange(of: store.isCustomizing, initial: true) { _, isCustomizing in
            onCustomizationChanged(isCustomizing)
            if isCustomizing == false, contextRefreshIsDeferred == false {
                store.applyPendingContext()
            }
        }
        .onDisappear {
            onCustomizationChanged(false)
        }
        .sheet(isPresented: $store.showsGallery) {
            AdaptiveWidgetGallery(store: store, preferences: preferences)
        }
        .fullScreenCover(isPresented: $showsMoodDial) {
            JournalMoodDialSheet(selectedMood: $selectedMood) { energy in
                moodEnergy = energy
                Task {
                    if case .failed(let message) = await lifeOSStore.saveMood(selectedMood, energy: energy) {
                        moodSaveError = message
                    }
                }
            }
        }
        .sheet(item: $contextReasonCandidate) { candidate in
            HomeContextReasonSheet(
                candidate: candidate,
                store: store,
                palette: palette,
                contextReasonCandidate: $contextReasonCandidate
            )
                .presentationDetents([.height(300), .medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func refreshContextSelection(
        now: Date = HomeReferenceClock.now,
        boundary: HomeContextRefreshBoundary = .explicitRefresh,
        immediate: Bool = false
    ) {
        refreshCoordinator.request(
            now: now,
            boundary: boundary,
            immediate: immediate,
            deferred: contextRefreshIsDeferred,
            operation: performContextRefresh
        )
    }

    private var contextRefreshIsDeferred: Bool {
        rootActivity.performsContinuousWork == false
    }

    @MainActor
    private func performContextRefresh(
        _ request: AdaptiveHomeRefreshCoordinator.Request,
        generation: Int
    ) async {
        await lifeOSStore.load(isCurrent: { refreshCoordinator.isCurrent(generation) })
        guard refreshCoordinator.isCurrent(generation) else { return }
        let permitsSensitive = permitsSensitiveHomeContent
        let mode = router.dashboardMode
        // Always retain the newest candidate inputs. The context service owns
        // automatic structural deferral; idle applies these without another read.
        do {
            let local = homeContextCandidates(now: request.now)
            let domainCandidates = await contextProviderRegistry.candidates(
                context: .init(date: request.now, refreshBoundary: request.boundary)
            )
            guard refreshCoordinator.isCurrent(generation) else { return }
            let candidates = mode == .lowEnergy
                ? lowEnergyCandidates(from: local + domainCandidates, now: request.now)
                : local + domainCandidates
            store.refreshContext(
                candidates: candidates,
                permitsSensitiveHomeContent: permitsSensitive,
                now: request.now,
                force: request.urgency == .immediate
            )
        }
        guard refreshCoordinator.isCurrent(generation) else { return }
        await refreshCardSnapshots(now: request.now, generation: generation)
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
    private func refreshCardSnapshots(now: Date = HomeReferenceClock.now, generation: Int? = nil) async {
        let daypart = atmosphereSnapshot.semanticDaypart
        let renderPlan = dashboardRenderPlan(daypart: daypart, now: now)
        var seen = Set<String>()
        var requests: [(kind: DashboardWidgetKind, size: HomeCardSize)] = []
        for placement in renderPlan.visible {
            let kind = renderPlan.resolvedKinds[placement.id]
                ?? resolvedWidgetKind(for: placement, daypart: daypart, now: now)
            let size = renderPlan.effectivePresets[placement.id]
                ?? effectivePreset(for: placement.semanticSize)
            let key = HomeLifeOSProjectionStore.cardSnapshotKey(kind, size)
            guard seen.insert(key).inserted else { continue }
            requests.append((kind, size))
        }
        await lifeOSStore.refreshCardSnapshots(
            requests: requests,
            permitsSensitive: permitsSensitiveHomeContent,
            at: now,
            isCurrent: { generation.map(refreshCoordinator.isCurrent) ?? true }
        )
    }

    private func homeContextCandidates(now: Date) -> [HomeContextCandidate] {
        var candidates: [HomeContextCandidate] = []
        if let hero = lifeOSStore.heroSnapshot {
            let destination: Destination = switch hero.priority {
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
    /// The heading itself is `HomeSectionHeading`; this is the call-site
    /// spelling the sections already use.
    private func homeSectionHeading(
        _ title: String,
        state: String? = nil,
        palette: DaypartPalette,
        usesInverseInk: Bool = false
    ) -> HomeSectionHeading {
        HomeSectionHeading(title, state: state, palette: palette, usesInverseInk: usesInverseInk)
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
        palette: DaypartPalette,
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
                HomeFocusNowWidget(
                    preset: .wide,
                    lifeOSStore: lifeOSStore,
                    projectionAdapter: projectionAdapter,
                    router: router,
                    captureRouter: captureRouter,
                    palette: palette
                )
                .lifeBoardFloatingClayCard(palette: palette)
            } else if let candidate = store.contextSelection.candidates.first {
                HomeContextCard(
                    candidate: candidate,
                    store: store,
                    router: router,
                    palette: palette,
                    accessibilityIdentifier: "home.hero",
                    contextReasonCandidate: $contextReasonCandidate,
                    onPinAfterAction: { pinContextAfterAction($0) },
                    onSuppressed: { candidate, message in
                        suppressedContext = candidate
                        contextSuppressionReceipt = ActionReceiptPresentation(message: message)
                    }
                )
            }

            // Three of the card's menu items remove a suggestion, and one of
            // them is permanent. `DESIGN.md`: end consequential work with a
            // receipt and Undo where reversal is supported.
            if let receipt = contextSuppressionReceipt {
                ReceiptBar(
                    receipt,
                    undo: {
                        if let candidate = suppressedContext {
                            store.restoreContextSuggestion(candidate)
                        }
                        contextSuppressionReceipt = nil
                        suppressedContext = nil
                    },
                    onDismiss: {
                        contextSuppressionReceipt = nil
                        suppressedContext = nil
                    }
                )
                .accessibilityIdentifier("home.context.suppressionReceipt")
                .lifeBoardMotion(.contentInsertion, value: receipt.id)
            }
        }
        // The whole explainable "Now" region is the canonical Home hero.
        // Its contents can legitimately swap from Focus to a context card as
        // providers hydrate, so the stable identity belongs on the region.
        .accessibilityIdentifier("home.hero")
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

    /// Section membership now comes from `DashboardWidgetDescriptor.sectionRole`.
    /// It used to live as three hardcoded string sets here plus a fourth copy
    /// in the layout repository — registering a new kind silently dropped it
    /// into "Your space", and the two anchored copies could drift apart.
    private func descriptor(for placement: DashboardWidgetPlacementValue) -> DashboardWidgetDescriptor? {
        store.registry.descriptor(for: DashboardWidgetKind(rawValue: placement.widgetKind))
    }

    private func visiblePlacements(for mode: DashboardMode) -> [DashboardWidgetPlacementValue] {
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

    private var dashboardRenderPlanInput: HomeDashboardRenderPlanSignature {
        return HomeDashboardRenderPlanSignature(
            placements: store.activeLayout.placements,
            mode: router.dashboardMode,
            density: dashboardDensity,
            daypart: atmosphereSnapshot.semanticDaypart,
            calendarDay: Calendar.current.startOfDay(for: HomeReferenceClock.now),
            isRegular: horizontalSizeClass == .regular,
            usesAccessibilityLayout: dynamicTypeSize.isAccessibilitySize,
            loopSpineEnabled: V2FeatureFlags.homeLoopSpineV1Enabled,
            contextCandidates: [],
            candidateInputs: store.contextSelection.candidates,
            dynamicType: String(describing: dynamicTypeSize),
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            permitsSensitive: permitsSensitiveHomeContent
        )
    }

    private func dashboardRenderPlan(
        daypart: ResolvedDaypart,
        now: Date = HomeReferenceClock.now
    ) -> HomeDashboardRenderPlan {
        let mode = router.dashboardMode
        let signature = dashboardRenderPlanInput
        return renderPlanCache.resolve(signature: signature) {
            buildDashboardRenderPlan(mode: mode, daypart: daypart, now: now)
        }
    }

    private func buildDashboardRenderPlan(
        mode: DashboardMode,
        daypart: ResolvedDaypart,
        now: Date
    ) -> HomeDashboardRenderPlan {
        let visible = visiblePlacements(for: mode)
        var today: [DashboardWidgetPlacementValue] = []
        var keepSteady: [DashboardWidgetPlacementValue] = []
        var closeLoop: [DashboardWidgetPlacementValue] = []
        var supporting: [DashboardWidgetPlacementValue] = []
        var resolvedKinds: [UUID: DashboardWidgetKind] = [:]
        var effectivePresets: [UUID: WidgetSizePreset] = [:]
        var effectiveRoles: [UUID: HomeSectionRole] = [:]
        for placement in visible {
            let role = effectiveSectionRole(for: placement)
            effectiveRoles[placement.id] = role
            resolvedKinds[placement.id] = resolvedWidgetKind(
                for: placement,
                daypart: daypart,
                now: now
            )
            effectivePresets[placement.id] = effectivePreset(for: placement.semanticSize)
            switch role {
            case .today: today.append(placement)
            case .keepSteady: keepSteady.append(placement)
            case .closeLoop: closeLoop.append(placement)
            default: supporting.append(placement)
            }
        }
        return HomeDashboardRenderPlan(
            budget: modePolicy.sectionBudget(for: mode).applying(dashboardDensity),
            visible: visible,
            today: today,
            keepSteady: keepSteady,
            closeLoop: closeLoop,
            supporting: supporting,
            resolvedKinds: resolvedKinds,
            effectivePresets: effectivePresets,
            effectiveRoles: effectiveRoles
        )
    }

    @ViewBuilder
    private func placementSection(
        _ title: String,
        placements: [DashboardWidgetPlacementValue],
        renderPlan: HomeDashboardRenderPlan,
        daypart: ResolvedDaypart,
        palette: DaypartPalette,
        ambientPalette: DaypartPalette
    ) -> some View {
        if placements.isEmpty == false {
            homeSectionHeading(title, palette: ambientPalette)
            DashboardFlowLayout(
                isRegular: horizontalSizeClass == .regular,
                usesSingleColumn: dynamicTypeSize.isAccessibilitySize
            ) {
                ForEach(placements) { placement in
                    let kind = renderPlan.resolvedKinds[placement.id]
                        ?? resolvedWidgetKind(for: placement, daypart: daypart)
                    let preset = renderPlan.effectivePresets[placement.id]
                        ?? effectivePreset(for: placement.semanticSize)
                    dashboardWidget(for: placement, kind: kind, preset: preset, daypart: daypart, palette: palette)
                        .dashboardPreset(preset)
                            .layoutValue(key: DashboardLayoutRevisionKey.self, value: layoutRevision(for: placement, kind: kind, preset: preset))
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
        placements: [DashboardWidgetPlacementValue],
        renderPlan: HomeDashboardRenderPlan,
        daypart: ResolvedDaypart,
        palette: DaypartPalette,
        ambientPalette: DaypartPalette
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

            if placements.isEmpty, store.isCustomizing == false {
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
                    ForEach(placements) { placement in
                        let kind = renderPlan.resolvedKinds[placement.id]
                            ?? resolvedWidgetKind(for: placement, daypart: daypart)
                        let preset = renderPlan.effectivePresets[placement.id]
                            ?? effectivePreset(for: placement.semanticSize)
                        dashboardWidget(for: placement, kind: kind, preset: preset, daypart: daypart, palette: palette)
                            .dashboardPreset(preset)
                            .layoutValue(key: DashboardLayoutRevisionKey.self, value: layoutRevision(for: placement, kind: kind, preset: preset))
                            .accessibilityValue(placement.ownership.accessibilityDescription)
                            .lifeBoardScrollEntrance(
                                intensity: scrollEntranceIntensity(for: placement, daypart: daypart)
                            )
                    }
                }
            }
        }
    }

    private func layoutRevision(for placement: DashboardWidgetPlacementValue, kind: DashboardWidgetKind,
                                preset: WidgetSizePreset) -> DashboardLayoutRevision {
        var content = lifeOSStore.cardSnapshot(kind: kind, size: preset)
        content?.updatedAt = .distantPast
        return DashboardLayoutRevision(id: placement.id, expanded: expandedTaskWidgetIDs.contains(placement.id),
            content: content, dynamicType: String(describing: dynamicTypeSize), locale: Locale.current.identifier)
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

    /// Builds one dashboard card. Deliberately returns the concrete
    /// `HomeDashboardWidget` rather than `some View`: the card's own `body`
    /// then runs in its own stack frame instead of being inlined here.
    private func dashboardWidget(
        for placement: DashboardWidgetPlacementValue,
        kind: DashboardWidgetKind,
        preset: WidgetSizePreset,
        daypart: ResolvedDaypart,
        palette: DaypartPalette
    ) -> HomeDashboardWidget {
        HomeDashboardWidget(
            placement: placement,
            kind: kind,
            preset: preset,
            daypart: daypart,
            palette: palette,
            store: store,
            lifeOSStore: lifeOSStore,
            projectionAdapter: projectionAdapter,
            router: router,
            captureRouter: captureRouter,
            modePolicy: modePolicy,
            dashboardDensity: dashboardDensity,
            hasPlanningRepository: hasPlanningRepository,
            hasTrackFoundationRepository: hasTrackFoundationRepository,
            dayLoopSummary: dayLoopSummary,
            motionAnimation: motionAnimation,
            reduceMotion: reduceMotion,
            selectedMood: selectedMood,
            moodEnergy: moodEnergy,
            showsMoodDial: $showsMoodDial,
            expandedTaskWidgetIDs: $expandedTaskWidgetIDs,
            onOpenWidget: { openWidget($0) }
        )
    }

    /// The ritual row. Same reasoning as `dashboardWidget`: a concrete struct,
    /// not an inlined `some View`.
    private func dayRitualEntry(palette: DaypartPalette) -> HomeDayRitualRow {
        HomeDayRitualRow(
            ritual: activeDayRitual,
            router: router,
            dayRitualSnoozeGeneration: $dayRitualSnoozeGeneration
        )
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
        palette: DaypartPalette,
        ambientPalette: DaypartPalette,
        budget: HomeSectionBudget
    ) -> some View {
        let stage = dayLoopStage
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(HomeSectionCopy.spineTitle(for: stage))
                    .font(Typography.sectionTitle())
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                // The count belongs to whichever heading survives. `.act` used
                // to stack the spine's title above `nowSection`'s own, so the
                // screen read "Now" twice and only the lower one carried the
                // number. One row now, and it keeps the number.
                // `.act` is the only stage whose body would otherwise have
                // titled itself: it is `nowSection`, whose heading is
                // suppressed so the spine owns the single row.
                if stage == .act, let state = nowSectionState {
                    Text(state)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .monospacedDigit()
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let rhythm = HomeSectionCopy.dayLoopRhythmText(dayLoopSummary) {
                    Text(rhythm)
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
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
                HomeSpineRepairBody(lifeOSStore: lifeOSStore, router: router)
            case .rest:
                HomeSpineRestBody()
            }
        }
        .lifeBoardMotion(.cardReflow, value: stage)
        .accessibilityIdentifier("home.loopSpine.\(stage.rawValue)")
    }

    private var dashboardSectionTitle: String {
        let base = V2FeatureFlags.homeLoopSpineV1Enabled ? "Your dashboard" : "Your space"
        return store.isCustomizing ? "\(base) · drag to arrange" : base
    }


    /// The day-loop stage Home is currently in.
    ///
    /// Loop state first, clock second — see `DayLoopStageResolver`. Drift is not
    /// wired yet, so `.repair` cannot be reached from here; the case exists so
    /// the stage set is complete for the surfaces that will consume it.
    private var dayLoopStage: DayLoopStage {
        // Read so a snooze re-evaluates this without a full Home reload.
        _ = dayRitualSnoozeGeneration
        let now = HomeReferenceClock.now
        let engine = DayCompassService()
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
    private var activeDayRitual: HomeDayRitual? {
        let now = HomeReferenceClock.now
        let stage = dayLoopStage
        guard stage.offersClose else { return nil }

        if stage == .commit {
            return HomeDayRitual(
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
        return HomeDayRitual(
            route: .dayClose(now),
            // Matches the wording already shipped in `DayCompassCard` rather
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
        let now = HomeReferenceClock.now
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
        if let route = HomeWidgetRouteResolver.route(for: kind) {
            router.openLeaf(route, in: .track)
            return
        }
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
            router.navigateReplacingPath(.fasting, in: .track)
        default:
            break
        }
    }

    private func resolvedWidgetKind(
        for placement: DashboardWidgetPlacementValue,
        daypart: ResolvedDaypart,
        now: Date = HomeReferenceClock.now
    ) -> DashboardWidgetKind {
        let fallback = DashboardWidgetKind(rawValue: placement.widgetKind)
        guard placement.ownership == .smart,
              let slot = placement.smartSlot,
              smartSlotIsEligible(slot, daypart: daypart, now: now) else { return fallback }
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
        now: Date = HomeReferenceClock.now
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

// MARK: - Adaptive Home sections
//
// Every section below used to be a computed `some View` member of
// `AdaptiveHome`. A computed property is inlined into its caller's
// frame, so the entire screen was built inside `body`'s frame and walked off
// the 1 MB main-thread stack in Debug — `-Onone` gives every SwiftUI temporary
// its own stack slot instead of reusing them, which is why it never reproduced
// in Release. A `struct: View` gets its own `body` call and therefore its own
// frame. This is pure code motion: behaviour, copy, layout and every
// accessibility identifier are unchanged.

/// Pure derivations lifted out of `AdaptiveHome`.
///
/// `@MainActor` is required rather than decorative: several of these read
/// `@Observable @MainActor` stores.
@MainActor
enum HomeSectionCopy {
    static func symbol(for kind: DashboardWidgetKind, store: AdaptiveHomeStore) -> String {
        store.registry.descriptor(for: kind)?.systemImage ?? "square.grid.2x2"
    }

    static func heroLabel(for priority: AdaptiveHeroPriority?) -> String {
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

    static func heroSymbol(for priority: AdaptiveHeroPriority?) -> String {
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

    static func compactHeroActionTitle(_ title: String) -> String {
        switch title {
        case "Choose a focus": "Choose"
        case "Open focus", "Open day": "Open"
        default: title
        }
    }

    static func homeAvailability(
        for domain: HealthDomain,
        value: HealthAggregateValue?,
        healthStore: HealthConnectionStore
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

    static func signalRank(_ slot: HomeSignalSlot) -> Int {
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

    /// Water-like signals fill with liquid; movement signals keep the plain
    /// arc so the metaphor stays honest.
    static func liquidTint(for slot: HomeSignalSlot, palette: DaypartPalette) -> Color? {
        guard slot.availability == .available || slot.availability == .stale else { return nil }
        switch slot.id {
        case "hydration": return Color(SemanticColorTokens.foundationSageAccent).opacity(0.55)
        case "fasting": return Color(SemanticColorTokens.foundationApricotAccent).opacity(0.6)
        default: return nil
        }
    }

    static func ringState(for slot: HomeSignalSlot) -> MetricRing.RingState {
        switch slot.availability {
        case .loading:
            return .loading
        case .setupRequired:
            return .setupRequired
        case .permissionRequired:
            // These two were one case, and the collapse discarded a distinction
            // the domain had just made: `homeAvailability` above separates
            // "HealthKit was never authorized" (.permissionRequired) from
            // "authorized, nothing recorded yet" (.setupRequired). Both drew the
            // same dashed "+", so a declined permission read as unfinished
            // setup — and the "+" implied tapping would let you add a value,
            // which it cannot.
            return .permissionRequired
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

    static func accessibilityAvailability(_ availability: HomeSignalSlot.Availability) -> String {
        switch availability {
        case .available: "available"
        case .loading: "loading"
        case .setupRequired: "setup required"
        case .permissionRequired: "permission required"
        case .stale: "out of date"
        case .unavailable: "unavailable"
        }
    }

    static func compactHours(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        return "\(totalMinutes / 60)h \(totalMinutes % 60)m"
    }

    static func spokenHours(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours) hours, \(minutes) minutes"
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60, remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }

    static func hydrationLabel(_ lifeOSStore: HomeLifeOSProjectionStore) -> String {
        guard let amount = lifeOSStore.trackSnapshot?.hydrationAmountMilliliters else { return "Set up" }
        return "\(Int(amount)) ml"
    }

    static func medicationLabel(_ lifeOSStore: HomeLifeOSProjectionStore) -> String {
        let count = lifeOSStore.trackSnapshot?.unresolvedMedicationEvents.count ?? 0
        return count == 0 ? "No unresolved medication events" : "\(count) medication decision\(count == 1 ? "" : "s")"
    }

    static func capacityDescription(
        router: AppRouter,
        projectionAdapter: HomeProjectionCoordinator
    ) -> String {
        if router.dashboardMode == .lowEnergy { return "Keep this window light and protect recovery." }
        if projectionAdapter.snapshot.overdueCount > 2 { return "Your day is carrying some pressure. Choose one commitment." }
        return "There is room for one focused block."
    }

    static func taskWidgetTitle(_ lifeOSStore: HomeLifeOSProjectionStore) -> String {
        let selectedDate = lifeOSStore.taskAgenda.selectedDate
        if Calendar.current.isDate(selectedDate, inSameDayAs: lifeOSStore.presentationDate) {
            return "Today’s tasks"
        }
        return "\(selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) tasks"
    }

    static func taskWidgetEmptyMessage(_ lifeOSStore: HomeLifeOSProjectionStore) -> String {
        let selectedDate = lifeOSStore.taskAgenda.selectedDate
        if Calendar.current.isDate(selectedDate, inSameDayAs: lifeOSStore.presentationDate) {
            return "No overdue tasks or tasks due today"
        }
        let date = selectedDate.formatted(.dateTime.month(.abbreviated).day())
        return "No overdue tasks or tasks due \(date)"
    }

    static func spineTitle(for stage: DayLoopStage) -> String {
        switch stage {
        case .commit: "Start today"
        case .act: "Now"
        case .repair: "Worth a look"
        case .close: "Ending the day"
        // Not "Done" or "Complete" — the day is put down, not scored.
        case .rest: "Today is closed"
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
    static func dayLoopRhythmText(_ dayLoopSummary: DayLoopSummary?) -> String? {
        guard let summary = dayLoopSummary, summary.hasNoHistory == false else { return nil }
        let window = "\(summary.closedInWindow) of \(summary.window) days"
        guard summary.runLength > 0 else { return window }
        let run = summary.runLength == 1 ? "1 day running" : "\(summary.runLength) days running"
        return "\(window) · \(run)"
    }

    /// The domain provider registry is the only source of card copy.
    ///
    /// A parallel switch used to live here as a "first-frame fallback" and had
    /// drifted into a second, contradictory copy set for the same cards —
    /// tasks-empty existed in three spellings, fasting and journal in two, and
    /// Focus Now shipped the ungrammatical "Choose one kind next step". A card
    /// shows its title alone until its provider resolves, which is a frame at
    /// most, rather than showing something that disagrees with what follows.
    static func widgetSummary(
        _ kind: DashboardWidgetKind,
        size: HomeCardSize,
        lifeOSStore: HomeLifeOSProjectionStore
    ) -> String {
        guard let snapshot = lifeOSStore.cardSnapshot(kind: kind, size: size) else { return "" }
        return snapshot.value ?? snapshot.detail ?? ""
    }
}

// MARK: - Home shared chrome

private struct HomeSectionHeading: View {
    let title: String
    var state: String?
    let palette: DaypartPalette
    var usesInverseInk = false

    init(
        _ title: String,
        state: String? = nil,
        palette: DaypartPalette,
        usesInverseInk: Bool = false
    ) {
        self.title = title
        self.state = state
        self.palette = palette
        self.usesInverseInk = usesInverseInk
    }

    var body: some View {
        let primary = usesInverseInk
            ? Color.lifeboard(.textInverse)
            : palette.color(for: .foreground)
        let secondary = usesInverseInk
            ? Color.lifeboard(.textInverse).opacity(0.78)
            : palette.color(for: .foregroundSecondary)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(Typography.sectionTitle())
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
}

struct HomeWidgetTitle: View {
    let title: String
    let symbol: String
    let palette: DaypartPalette

    init(_ title: String, symbol: String, palette: DaypartPalette) {
        self.title = title
        self.symbol = symbol
        self.palette = palette
    }

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(title).lifeboardFont(.headline)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}

struct HomeEmptyStateRow: View {
    let text: String
    let symbol: String
    let palette: DaypartPalette

    init(_ text: String, symbol: String, palette: DaypartPalette) {
        self.text = text
        self.symbol = symbol
        self.palette = palette
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(palette.color(for: .foregroundSecondary))
            Text(text).font(.subheadline).foregroundStyle(palette.color(for: .foregroundSecondary))
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct HomeSnapshotMetric: View {
    let id: String
    let symbol: String
    let value: String
    let label: String
    let palette: DaypartPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).lifeboardFont(.title2)
                Text(value).font(.caption.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                    .homeCardEvidence("snapshot.\(id).value", role: "value", copy: value, typography: .init(role: "caption", points: 12, weight: "semibold", alignment: "center"))
                Text(label).font(.caption2).foregroundStyle(palette.color(for: .foregroundSecondary))
                    .homeCardEvidence("snapshot.\(id).label", role: "text", copy: label, typography: .init(role: "caption2", points: 11, weight: "regular", alignment: "center"))
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .lifeBoardEmbeddedClayWell(palette: palette)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.snapshot.\(id)")
        .homeCardEvidence("snapshot.\(id).open", role: "control", copy: value + " " + label)
    }
}

private struct HomeCaptureTile: View {
    let title: String
    let symbol: String
    let kind: CaptureKind
    let palette: DaypartPalette
    let captureRouter: CaptureRouter

    var body: some View {
        Button {
            captureRouter.request(kind: kind, source: .shell)
            Haptic.pick.play()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol).lifeboardFont(.title2)
                Text(title).font(.caption.weight(.medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .lifeBoardEmbeddedClayWell(palette: palette)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.capture.\(kind.rawValue)")
    }
}

// MARK: - Home orientation sections

private struct HomeNeedsAttentionSection: View {
    let store: AdaptiveHomeStore
    let router: AppRouter
    let palette: DaypartPalette
    let onPinAfterAction: (HomeContextCandidate) -> Void

    var body: some View {
        let candidates = Array(store.contextSelection.candidates.dropFirst().prefix(3))
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeading(
                "Needs attention",
                state: "\(candidates.count)",
                palette: palette
            )
            ForEach(candidates) { candidate in
                Button {
                    onPinAfterAction(candidate)
                    router.select(candidate.destination)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: HomeSectionCopy.symbol(for: candidate.widgetKind, store: store))
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
}

private struct HomeContextCard: View {
    let candidate: HomeContextCandidate
    let store: AdaptiveHomeStore
    let router: AppRouter
    let palette: DaypartPalette
    let accessibilityIdentifier: String
    @Binding var contextReasonCandidate: HomeContextCandidate?
    let onPinAfterAction: (HomeContextCandidate) -> Void
    /// Reports a suppression so the section can show a receipt with Undo. The
    /// card itself disappears the moment the suggestion is suppressed, so it
    /// cannot host its own receipt.
    var onSuppressed: ((HomeContextCandidate, String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: HomeSectionCopy.symbol(for: candidate.widgetKind, store: store))
                    .lifeboardFont(.title2)
                    .frame(width: 34, height: 34)
                    .background(palette.color(for: .canvasSecondary), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.title)
                        .lifeboardFont(.headline)
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
                        onSuppressed?(candidate, "Hidden for today")
                    }
                    Button("Suggest less often", systemImage: "arrow.down.right") {
                        store.suggestContextLessOften(candidate)
                        onSuppressed?(candidate, "Suggesting “\(candidate.title)” less often")
                    }
                    Button("Never suggest this", systemImage: "eye.slash", role: .destructive) {
                        store.neverSuggestContext(candidate)
                        onSuppressed?(candidate, "Won't suggest “\(candidate.title)” again")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Options for \(candidate.title)")
            }

            Button {
                onPinAfterAction(candidate)
                if let route = candidate.route {
                    // `navigate` rather than `select` + `push`: it lets the root
                    // change finish before the typed leaf is appended, so a
                    // just-popped empty path cannot be written over the new
                    // route. Root selection alone never leaves a blank frame now
                    // (`RootRetention`), but the ordering still matters.
                    router.navigate(route, in: candidate.destination)
                } else {
                    router.select(candidate.destination)
                }
                Haptic.pick.play()
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
}

private struct HomeContextReasonSheet: View {
    let candidate: HomeContextCandidate
    let store: AdaptiveHomeStore
    let palette: DaypartPalette
    @Binding var contextReasonCandidate: HomeContextCandidate?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                Text("Why this is here")
                    .lifeboardFont(.metric)
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
            .buttonStyle(.lifeBoardPrimaryCompact)
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(Color(SemanticColorTokens.foundationSurfaceSolid))
    }
}

private struct HomeTodayStorySection: View {
    let projectionAdapter: HomeProjectionCoordinator
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let palette: DaypartPalette

    var body: some View {
        let items = todayStoryItems
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeading(
                "Day ahead",
                state: items.isEmpty ? nil : "\(items.count) moments",
                palette: palette
            )
            VStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        router.select(item.destination)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.symbol)
                                .lifeboardFont(.headline)
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
                    if item.id != items.last?.id {
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
}

private struct HomeLifeThreadComposer: View {
    let store: AdaptiveHomeStore
    let router: AppRouter
    let captureRouter: CaptureRouter
    let palette: DaypartPalette
    @Binding var composerText: String
    var composerIsFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 12) {
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
                    .lifeboardFont(.title2)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Capture something")

            TextField("Talk to Eva or capture anything", text: $composerText, axis: .vertical)
                .lineLimit(1...4)
                .focused(composerIsFocused)
                .submitLabel(.send)
                .onSubmit(submitComposer)
                .accessibilityIdentifier("home.lifeThread.composer")

            Button(action: composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                   ? { captureRouter.request(kind: .journal, source: .shell) }
                   : submitComposer) {
                Image(systemName: composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      ? "waveform"
                      : "arrow.up")
                    .lifeboardFont(.headline)
                    .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceSolid))
                    .frame(width: 44, height: 44)
                    .background(Color(SemanticColorTokens.inkPrimary), in: Circle())
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
                .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
        }
        .shadow(color: Color(SemanticColorTokens.foundationWarmShadow).opacity(0.18), radius: 14, y: 8)
    }

    private func submitComposer() {
        let prompt = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard prompt.isEmpty == false else { return }
        do {
            try EvaChatLaunchRequestStore.shared.submit(.init(prompt: prompt))
            composerText = ""
            composerIsFocused.wrappedValue = false
            router.select(.eva)
            Haptic.pick.play()
        } catch {
            store.dismissError()
        }
    }
}

private struct HomeCustomizationActionBar: View {
    let store: AdaptiveHomeStore
    let palette: DaypartPalette
    let motionAnimation: Animation?

    var body: some View {
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
                .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.customization.actions")
    }
}

// MARK: - Home loop spine

/// The ritual row's content, resolved once by `AdaptiveHome`.
private struct HomeDayRitual {
    let route: AppRoute
    let title: String
    let subtitle: String
    let symbol: String
    let isEvening: Bool
}

/// The way into the end-of-day ritual, and the morning's read-only echo.
///
/// A section-level affordance rather than a `DashboardWidgetKind`: it is not
/// a readout, it cannot be reordered or pinned, and registering it as a
/// widget would oblige it to render at all five size presets for no benefit.
///
/// Deliberately *not* wired to `DayCompassService`'s `eveningReview` card —
/// that card's only consumer is the legacy Sunrise home, which this shell
/// replaces. Reusing the engine's window predicate and its snooze ledger
/// gives the same tested behaviour without shipping to a screen nobody sees.
private struct HomeDayRitualRow: View {
    let ritual: HomeDayRitual?
    let router: AppRouter
    @Binding var dayRitualSnoozeGeneration: Int

    var body: some View {
        if V2FeatureFlags.dayCloseV1Enabled, let ritual {
            Button {
                router.push(ritual.route, in: .home)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: ritual.symbol)
                        .font(.title3)
                        .foregroundStyle(Color(SemanticColorTokens.foundationSunAccent))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ritual.title)
                            .font(.headline)
                            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        Text(ritual.subtitle)
                            .font(.caption)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(16)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
            // The ritual grows out of the row you tapped rather than sliding in
            // from the edge as an unrelated screen — it is the same day, opened.
            // Already gated on Reduce Motion, Catalyst and -UI_TESTING inside.
            .lifeBoardTransitionSource(DayLoopTransition.id(for: ritual.route))
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
private struct HomeSpineRepairBody: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter

    var body: some View {
        let count = lifeOSStore.driftCount
        VStack(alignment: .leading, spacing: 12) {
            Text(
                count == 1
                    ? "One thing didn't happen when you planned it. Nothing has changed yet."
                    : "\(count) things didn't happen when you planned them. Nothing has changed yet."
            )
            .font(Typography.body())
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
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
}

/// `.rest` asks for nothing.
///
/// Closing a day must not open a new obligation, so this states the fact and
/// stops. No CTA, no next step, no offer to plan tomorrow.
private struct HomeSpineRestBody: View {
    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            // The day, closed — the same ring from the ritual, small and
            // finished. Its completion mark is already drawn at closedProgress 1,
            // so this is a record rather than a second celebration.
            DayRing(
                plannedMinutes: nil,
                focusedMinutes: nil,
                closedProgress: 1,
                diameter: 64
            )
            .accessibilityHidden(true)

            Text("Nothing more is being asked of you today.")
                .font(Typography.body())
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        // Arrives, settles, and stops. A closed day must not shimmer, so there
        // is deliberately no TimelineView, no repeatForever, and no CTA — the
        // whole point of `.rest` is that it asks for nothing.
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today is closed. Nothing more is being asked of you today.")
        .accessibilityIdentifier("home.loopSpine.rest")
    }
}

// MARK: - Home signals

/// What Home shows instead of a row of dashed rings when Health was never shared.
///
/// A `.permissionRequired` ring is correctly modelled — `ringState(for:)` is
/// careful to keep "declined" distinct from "nothing recorded yet" — but three
/// of them side by side is the most prominent band on the first screen of the
/// app, and it reads as a failure rather than as a choice the person made.
private struct HomeSignalConnectHealthTile: View {
    let healthStore: HealthConnectionStore

    @State private var isRequesting = false

    var body: some View {
        Button {
            guard isRequesting == false else { return }
            isRequesting = true
            Task {
                _ = await healthStore.connectReadOnly()
                isRequesting = false
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "heart.text.square")
                    .lifeboardFont(.title2)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .frame(height: 58)
                // The row gives each slot roughly a third of the screen, so this
                // says the one thing it has room to say. The reason lives in the
                // accessibility hint, where it does not cost three wrapped lines
                // and a tile four times the height of the rings beside it.
                Text("Connect\nHealth")
                    .font(.lifeboard(.meta))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRequesting)
        .accessibilityLabel("Connect Health")
        .accessibilityHint("Steps and activity stay hidden until you share them.")
        .accessibilityIdentifier("home.signal.connectHealth")
    }
}


private struct HomeSignalRow: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let healthStore: HealthConnectionStore
    let router: AppRouter
    let captureRouter: CaptureRouter
    let hasTrackFoundationRepository: Bool
    let hasPhaseIIRepository: Bool
    let palette: DaypartPalette
    let reduceMotion: Bool
    @Binding var showsFastEndReceipt: Bool
    @Binding var showsFastingError: Bool
    @Binding var fastingStateChangeTrigger: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let slots = presentedSlots
        if dynamicTypeSize.isAccessibilitySize {
            // One column, not two. `DESIGN.md`: at large text sizes use one
            // content column — a two-up grid still halves the width each ring's
            // label has to live in.
            VStack(spacing: 12) {
                ForEach(slots) { slot in ring(slot) }
                if collapsesBlockedHealth { HomeSignalConnectHealthTile(healthStore: healthStore) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.signalRow")
        } else {
            HStack(spacing: 8) {
                ForEach(slots) { slot in ring(slot) }
                if collapsesBlockedHealth { HomeSignalConnectHealthTile(healthStore: healthStore) }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.signalRow")
        }
    }

    /// Health signals whose data was never shared with the app.
    private var blockedHealthSlots: [HomeSignalSlot] {
        signalSlots.filter { $0.id != "fasting" && $0.availability == .permissionRequired }
    }

    /// Two or more dashed rings in a row stop reading as "not shared" and start
    /// reading as "broken". Past one, they collapse into a single affordance
    /// that says what it wants and can actually grant it.
    private var collapsesBlockedHealth: Bool { blockedHealthSlots.count >= 2 }

    private var presentedSlots: [HomeSignalSlot] {
        guard collapsesBlockedHealth else { return signalSlots }
        let blocked = Set(blockedHealthSlots.map(\.id))
        return signalSlots.filter { blocked.contains($0.id) == false }
    }

    @ViewBuilder
    private func ring(_ slot: HomeSignalSlot) -> some View {
        if slot.id == "fasting" {
            HomeFastingSignal(
                lifeOSStore: lifeOSStore,
                router: router,
                hasPhaseIIRepository: hasPhaseIIRepository,
                palette: palette,
                reduceMotion: reduceMotion,
                showsFastEndReceipt: $showsFastEndReceipt,
                showsFastingError: $showsFastingError,
                fastingStateChangeTrigger: $fastingStateChangeTrigger
            )
        } else {
            Button {
                if slot.id == "hydration" {
                    captureRouter.request(kind: .hydration, source: .shell)
                } else if slot.availability == .permissionRequired {
                    // This used to `router.select(.track)`, which dropped a
                    // person onto another root with no explanation and no way
                    // to grant the thing they had just tapped. The ring is the
                    // request, so it asks.
                    Task { _ = await healthStore.connectReadOnly() }
                } else {
                    router.select(.track)
                }
            } label: {
                MetricRing(
                    label: slot.title,
                    state: HomeSectionCopy.ringState(for: slot),
                    diameter: 58,
                    palette: palette,
                    liquidTint: HomeSectionCopy.liquidTint(for: slot, palette: palette)
                )
                .frame(maxWidth: .infinity, minHeight: 100)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(slot.title), \(slot.valueText ?? HomeSectionCopy.accessibilityAvailability(slot.availability))")
            .accessibilityHint(slot.id == "hydration" && healthStore.aggregates[.water] == nil
                ? lifeOSStore.hydrationRefreshError ?? "" : "")
            .accessibilityIdentifier("home.signal.\(slot.id)")
        }
    }

    private var signalSlots: [HomeSignalSlot] {
        let hydrationAmount = healthStore.aggregates[.water]?.value
            ?? lifeOSStore.trackSnapshot?.hydrationAmountMilliliters
        let hydrationTarget = lifeOSStore.trackSnapshot?.hydrationTargetMilliliters
        let hydrationProgress = hydrationAmount.flatMap { amount in
            hydrationTarget.flatMap { $0 > 0 ? min(1, amount / $0) : nil }
        }
        let hydrationAvailability: HomeSignalState = if lifeOSStore.isLoading && hydrationAmount == nil && lifeOSStore.trackSnapshot == nil {
            .loading
        } else if hasTrackFoundationRepository == false {
            .unavailable
        } else if lifeOSStore.hydrationRefreshError != nil && healthStore.aggregates[.water] == nil {
            hydrationAmount == nil ? .unavailable : .stale
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
                // No ring without a target the person set. A hard-coded 10,000
                // draws a progress arc against a goal nobody chose, which is
                // exactly the "health quality implied by colour and trend"
                // `DESIGN.md` forbids. Hydration keeps its ring because its
                // target is a real, user-set value.
                progress: nil,
                systemImage: "figure.walk",
                availability: HomeSectionCopy.homeAvailability(for: .activity, value: steps, healthStore: healthStore)
            ),
            HomeSignalSlot(
                id: "active",
                title: "Active",
                valueText: activeEnergy.map { "\(Int($0.value)) kcal" },
                progress: nil,
                systemImage: "flame.fill",
                availability: HomeSectionCopy.homeAvailability(for: .energy, value: activeEnergy, healthStore: healthStore)
            ),
            HomeSignalSlot(
                id: "fasting",
                title: "Fasting",
                valueText: nil,
                progress: lifeOSStore.activeFast.flatMap { fast in
                    fast.targetDuration.flatMap { $0 > 0 ? min(1, fast.elapsed() / $0) : nil }
                },
                systemImage: "timer",
                availability: hasPhaseIIRepository ? .available : .unavailable
            )
        ]
        // These are explicitly configured Home signals. The relevance budget
        // still controls every other Home module, but silently dropping a
        // configured timer makes its active state unreachable. Preserve all
        // four and use ranking only to order the three Health facts.
        let healthSlots = candidates
            .filter { $0.id != "fasting" }
            .sorted { HomeSectionCopy.signalRank($0) > HomeSectionCopy.signalRank($1) }
        return healthSlots + candidates.filter { $0.id == "fasting" }
    }

}

private struct HomeFastingSignal: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let hasPhaseIIRepository: Bool
    let palette: DaypartPalette
    let reduceMotion: Bool
    @Binding var showsFastEndReceipt: Bool
    @Binding var showsFastingError: Bool
    @Binding var fastingStateChangeTrigger: Int

    var body: some View {
        ActiveVisibleTimeline(every: 1) { context in
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
            let isAvailable = hasPhaseIIRepository

            Button {
                guard isAvailable else {
                    router.select(.track)
                    return
                }
                Haptic.pick.play()
                if activeFast == nil {
                    let startDate = HomeFastingAnchorPolicy.recentMealAnchor(
                        latestMealAt: lifeOSStore.recentMealAt,
                        now: HomeReferenceClock.now
                    ) ?? HomeReferenceClock.now
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
                                    Color(SemanticColorTokens.foundationSunAccent),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .lifeboardFastingEmberRing(
                                    progress: progress,
                                    tint: Color(SemanticColorTokens.foundationSunAccent)
                                )
                        }
                        VStack(spacing: 0) {
                            Text(HomeSectionCopy.compactHours(elapsed))
                                .lifeboardFont(.eyebrow)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.68)
                                .contentTransition(.numericText())
                            Text(activeFast != nil ? "fast" : (mealAnchor == nil ? "open" : "since meal"))
                                .lifeboardFont(.eyebrow)
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
                    }
                    .frame(width: 58, height: 58)

                    Text("Fasting")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(isAvailable ? (activeFast == nil ? (mealAnchor == nil ? "Start" : "Start from meal") : "End") : "Unavailable")
                        .lifeboardFont(.eyebrow)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .foregroundStyle(
                            isAvailable
                                ? Color(SemanticColorTokens.inkPrimary)
                                : palette.color(for: .foregroundSecondary)
                        )
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .contentShape(Rectangle())
                .lifeboardClayPressBloom(
                    center: .center,
                    trigger: fastingStateChangeTrigger,
                    tint: Color(SemanticColorTokens.foundationSunAccent)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(activeFast == nil ? "Start fasting timer" : "End fasting timer")
            .accessibilityValue(
                activeFast == nil
                    ? "Open window, \(HomeSectionCopy.spokenHours(elapsed))"
                    : "Fasting, \(HomeSectionCopy.spokenHours(elapsed))"
            )
            .accessibilityHint(
                activeFast == nil
                    ? (mealAnchor == nil ? "Starts now" : "Starts from your latest meal with one tap")
                    : "Saves the end time with one tap; an Undo appears below"
            )
            .accessibilityIdentifier("home.signal.fasting")
        }
    }

    @MainActor
    private func commitFastStart(at date: Date) async {
        if await lifeOSStore.startFast(targetDuration: nil, at: date) {
            showsFastEndReceipt = false
            fastingStateChangeTrigger &+= 1
            Haptic.commit.play()
        } else {
            showsFastingError = true
            Haptic.fail.play()
        }
    }

    @MainActor
    private func commitFastEnd() async {
        if await lifeOSStore.endActiveFast() {
            withAnimation(reduceMotion ? nil : .spring(duration: 0.38, bounce: 0.16)) {
                showsFastEndReceipt = true
            }
            fastingStateChangeTrigger &+= 1
            Haptic.commit.play()
        } else {
            showsFastingError = true
            Haptic.fail.play()
        }
    }
}

private struct HomeFastingEndReceipt: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let palette: DaypartPalette
    let reduceMotion: Bool
    @Binding var showsFastEndReceipt: Bool
    @Binding var showsFastingError: Bool
    @Binding var fastingStateChangeTrigger: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(SemanticColorTokens.foundationSageAccent))
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
                        Haptic.commit.play()
                    } else {
                        showsFastingError = true
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.leading, 14)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .lifeBoardClaySurface(.raised, cornerRadius: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.fasting.receipt")
    }
}

// MARK: - Home dashboard widgets

struct HomeDashboardWidget: View {
    let placement: DashboardWidgetPlacementValue
    let kind: DashboardWidgetKind
    let preset: WidgetSizePreset
    let daypart: ResolvedDaypart
    let palette: DaypartPalette
    let store: AdaptiveHomeStore
    let lifeOSStore: HomeLifeOSProjectionStore
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let captureRouter: CaptureRouter
    let modePolicy: any DashboardModePolicy
    let dashboardDensity: DashboardDensity
    let hasPlanningRepository: Bool
    let hasTrackFoundationRepository: Bool
    let dayLoopSummary: DayLoopSummary?
    let motionAnimation: Animation?
    let reduceMotion: Bool
    let selectedMood: JournalMood
    let moodEnergy: Int?
    @Binding var showsMoodDial: Bool
    @Binding var expandedTaskWidgetIDs: Set<UUID>
    let onOpenWidget: (DashboardWidgetKind) -> Void

    var body: some View {
        VStack(spacing: store.isCustomizing ? 6 : 0) {
            if store.isCustomizing {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal")
                        .font(.headline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Drag widget")
                        .accessibilityIdentifier("home.widget.drag.\(placement.id.uuidString)")

                    Spacer(minLength: 0)
                    HomeCustomizationControls(
                        placement: placement,
                        displayedKind: kind,
                        store: store
                    )
                }
                .padding(.horizontal, 4)
            }

            Group {
                if preset == .compact {
                    HomeGlanceWidget(
                        kind: kind,
                        daypart: daypart,
                        store: store,
                        lifeOSStore: lifeOSStore,
                        router: router,
                        palette: palette,
                        onOpenWidget: onOpenWidget
                    )
                } else if preset == .standard {
                    // Standard cards must preserve their meaningful primary actions.
                    // Collapsing these into a generic "Open" tile made capture,
                    // recovery, and evidence routes undiscoverable in the curated
                    // two-column Home layout.
                    switch kind {
                    case .care:
                        careWidget
                    case .tasks:
                        tasksWidget
                    case .routines:
                        routinesWidget
                    case .scheduleCapacity:
                        capacityWidget
                    case .journal:
                        journalWidget
                    case .progressReflection:
                        progressWidget
                    default:
                        archetypeWidget
                    }
                } else {
                    switch kind {
                    case .focusNow:
                        focusNowWidget
                    case .lifeSnapshot:
                        lifeSnapshotWidget
                    case .care:
                        careWidget
                    case .tasks:
                        tasksWidget
                    case .routines:
                        routinesWidget
                    case .scheduleCapacity:
                        capacityWidget
                    case .quickCapture:
                        HomeQuickCaptureWidget(captureRouter: captureRouter, palette: palette)
                    case .compactTimeline:
                        HomeTimelineWidget(
                            projectionAdapter: projectionAdapter,
                            router: router,
                            palette: palette
                        )
                    case .journal:
                        journalWidget
                    case .progressReflection:
                        progressWidget
                    case .fasting:
                        HomeFastingWidget(
                            lifeOSStore: lifeOSStore,
                            palette: palette,
                            onOpen: { onOpenWidget(.fasting) }
                        )
                    default:
                        // Was `EmptyView()`. Eleven registered kinds — goals,
                        // body metric, workout, sleep, movement, nutrition,
                        // recent meal, log meal, life moment, saved Eva
                        // insight and setup — reached this branch and drew
                        // nothing. Accessibility text sizes force this preset,
                        // so those cards were blank for anyone using large
                        // type. Every kind now has an archetype, and every
                        // archetype draws.
                        archetypeWidget
                    }
                }
            }
            .modifier(HomeCardIllustratedSurface(
                style: .init(kind: kind, preset: preset),
                palette: palette,
                showsScene: showsDecorativeScene
            ))
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
            Haptic.pick.play()
        }
        .accessibilityAction(named: "Customize") { store.beginCustomization() }
        #if DEBUG
        .modifier(HomeProductionPlacementEvidence(id: placement.id))
        #endif
    }

    private var showsDecorativeScene: Bool {
        let snapshot = lifeOSStore.cardSnapshot(kind: kind, size: preset)
        let hasMedia: Bool
        if case .moment(let moment) = snapshot?.payload { hasMedia = moment.imagePath != nil } else { hasMedia = false }
        return HomeCardPresentationStyle.showsScene(availability: snapshot?.availability, hasUserMedia: hasMedia)
    }

    private var archetypeWidget: some View {
        HomeArchetypeWidget(
            kind: kind,
            preset: preset,
            daypart: daypart,
            palette: palette,
            store: store,
            lifeOSStore: lifeOSStore,
            router: router,
            modePolicy: modePolicy,
            dashboardDensity: dashboardDensity,
            onOpenWidget: onOpenWidget
        )
    }

    private var focusNowWidget: some View {
        HomeFocusNowWidget(
            preset: preset,
            lifeOSStore: lifeOSStore,
            projectionAdapter: projectionAdapter,
            router: router,
            captureRouter: captureRouter,
            palette: palette
        )
    }

    private var lifeSnapshotWidget: some View {
        HomeLifeSnapshotWidget(
            lifeOSStore: lifeOSStore,
            router: router,
            captureRouter: captureRouter,
            palette: palette,
            selectedMood: selectedMood,
            moodEnergy: moodEnergy,
            showsMoodDial: $showsMoodDial
        )
    }

    private var careWidget: some View {
        HomeCareWidget(
            preset: preset,
            lifeOSStore: lifeOSStore,
            router: router,
            daypart: daypart,
            palette: palette
        )
    }

    private var tasksWidget: some View {
        HomeTasksWidget(
            preset: preset,
            placementID: placement.id,
            lifeOSStore: lifeOSStore,
            router: router,
            captureRouter: captureRouter,
            hasPlanningRepository: hasPlanningRepository,
            palette: palette,
            motionAnimation: motionAnimation,
            reduceMotion: reduceMotion,
            expandedTaskWidgetIDs: $expandedTaskWidgetIDs
        )
    }

    private var routinesWidget: some View {
        HomeRoutinesWidget(
            preset: preset,
            lifeOSStore: lifeOSStore,
            projectionAdapter: projectionAdapter,
            router: router,
            hasTrackFoundationRepository: hasTrackFoundationRepository,
            daypart: daypart,
            palette: palette
        )
    }

    private var capacityWidget: some View {
        HomeCapacityWidget(
            lifeOSStore: lifeOSStore,
            projectionAdapter: projectionAdapter,
            router: router,
            palette: palette
        )
    }

    private var journalWidget: some View {
        HomeJournalWidget(
            router: router,
            captureRouter: captureRouter,
            palette: palette
        )
    }

    private var progressWidget: some View {
        HomeProgressWidget(
            projectionAdapter: projectionAdapter,
            router: router,
            dayLoopSummary: dayLoopSummary,
            palette: palette
        )
    }
}

/// Renders a card from its registered archetype rather than a per-kind
/// case. This is the universal body: any registered kind draws something
/// meaningful at any preset, which is what makes the old `EmptyView()`
/// fallthrough unrepresentable.
private struct HomeArchetypeWidget: View {
    let kind: DashboardWidgetKind
    let preset: WidgetSizePreset
    let daypart: ResolvedDaypart
    let palette: DaypartPalette
    let store: AdaptiveHomeStore
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let modePolicy: any DashboardModePolicy
    let dashboardDensity: DashboardDensity
    let onOpenWidget: (DashboardWidgetKind) -> Void

    /// Counts opens so the card warps as its destination arrives — the
    /// `source` of source → travel → settle. Without it a whole screen
    /// replaces a motionless card, which reads as a cut.
    @State private var openTrigger = 0

    var body: some View {
        let descriptor = store.registry.descriptor(for: kind)
        let resolution = lifeOSStore.cardResolution(kind: kind, size: preset)
        let target = HomeWidgetRouteResolver.target(
            for: kind,
            resolution: resolution,
            daypart: daypart
        )
        HomeCardBody(
            snapshot: relabeledSnapshot(resolution?.snapshot ?? lifeOSStore.cardSnapshot(kind: kind, size: preset), target: target),
            archetype: descriptor?.archetype ?? .queue,
            preset: preset,
            palette: palette,
            title: descriptor?.title ?? "LifeBoard",
            symbol: HomeSectionCopy.symbol(for: kind, store: store),
            queueLimit: modePolicy
                .sectionBudget(for: router.dashboardMode)
                .applying(dashboardDensity)
                .queueLimit,
            onAction: { action in
                openTrigger += 1
                if let target {
                    router.openLeaf(target.route, in: .track)
                } else if let destination = action.destination {
                    router.select(destination)
                } else {
                    onOpenWidget(kind)
                }
            },
            onOpen: {
                openTrigger += 1
                if let target {
                    router.openLeaf(target.route, in: .track)
                } else {
                    onOpenWidget(kind)
                }
            }
        )
        // The hero radius: a Home card is the closed form of the hero it
        // opens into, and the shared silhouette is the continuity.
        .lifeboardCardMorphWarp(origin: .center, trigger: openTrigger)
        .accessibilityHint("Opens the source")
    }

    private func relabeledSnapshot(
        _ snapshot: HomeCardSnapshot?,
        target: HomeWidgetOpenTarget?
    ) -> HomeCardSnapshot? {
        guard var snapshot, let target, snapshot.actions.isEmpty == false else { return snapshot }
        snapshot.actions = snapshot.actions.enumerated().map { index, action in
            guard index == 0 else { return action }
            return HomeCardActionDescriptor(
                id: action.id,
                title: target.actionTitle,
                systemImage: action.systemImage,
                role: action.role,
                destination: action.destination,
                requiresMutationPreview: action.requiresMutationPreview
            )
        }
        return snapshot
    }
}

private struct HomeGlanceWidget: View {
    let kind: DashboardWidgetKind
    let daypart: ResolvedDaypart
    let store: AdaptiveHomeStore
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let palette: DaypartPalette
    let onOpenWidget: (DashboardWidgetKind) -> Void

    var body: some View {
        let descriptor = store.registry.descriptor(for: kind)
        let target = HomeWidgetRouteResolver.target(
            for: kind,
            resolution: lifeOSStore.cardResolution(kind: kind, size: .compact),
            daypart: daypart
        )
        HomeGlanceCardContent(
            title: HomeCardPresentationStyle.glanceTitle(for: kind, fallback: descriptor?.title ?? "LifeBoard"),
            summary: HomeSectionCopy.widgetSummary(kind, size: .compact, lifeOSStore: lifeOSStore),
            symbol: descriptor?.systemImage ?? "square.grid.2x2",
            palette: palette,
            onOpen: {
            if let target {
                router.openLeaf(target.route, in: .track)
            } else {
                onOpenWidget(kind)
            }

            }
        )
    }
}

private struct HomeFocusNowWidget: View {
    let preset: WidgetSizePreset
    let lifeOSStore: HomeLifeOSProjectionStore
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let captureRouter: CaptureRouter
    let palette: DaypartPalette

    var body: some View {
        let hero = lifeOSStore.heroSnapshot
        let primary = hero?.title ?? lifeOSStore.focusTask?.title ?? projectionAdapter.snapshot.focusTitles.first
        let lowEnergy = router.dashboardMode == .lowEnergy
        HomeFocusCardContent(
            title: lowEnergy ? "One small thing" : HomeSectionCopy.heroLabel(for: hero?.priority),
            primary: primary ?? (lowEnergy ? "Drink some water and take one quiet minute." : "Choose one useful next step"),
            reason: hero?.detail ?? lifeOSStore.focusResult?.reasons.first?.text,
            symbol: lowEnergy ? "leaf.fill" : HomeSectionCopy.heroSymbol(for: hero?.priority),
            actionTitle: HomeSectionCopy.compactHeroActionTitle(hero?.primaryActionTitle ?? (primary == nil ? "Choose" : "Start")),
            actionHint: hero?.secondaryActionTitles.first.map { "More actions include \($0)." } ?? "",
            preset: preset, palette: palette, onOpen: { performHeroPrimaryAction(hero) }
        )
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
        Haptic.pick.play()
    }
}

private struct HomeLifeSnapshotWidget: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let captureRouter: CaptureRouter
    let palette: DaypartPalette
    let selectedMood: JournalMood
    let moodEnergy: Int?
    @Binding var showsMoodDial: Bool

    var body: some View {
        HomeLifeSnapshotCardContent(
            mood: selectedMood == .none ? "Check in" : selectedMood.title,
            moodLabel: moodEnergy.map { "Mood · E\($0)" } ?? "Mood",
            hydration: HomeSectionCopy.hydrationLabel(lifeOSStore), lowEnergy: router.dashboardMode == .lowEnergy,
            palette: palette, onMood: { showsMoodDial = true },
            onHydration: { captureRouter.request(kind: .hydration, source: .shell) },
            onTrack: { router.select(.track) }
        )
    }
}

private struct HomeCareWidget: View {
    let preset: WidgetSizePreset
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let daypart: ResolvedDaypart
    let palette: DaypartPalette

    var body: some View {
        let events = lifeOSStore.trackSnapshot?.unresolvedMedicationEvents ?? []
        HomeActionQueueCardContent(
            title: "\(daypart.rawValue.capitalized) care", symbol: "cross.case.fill",
            rows: events.map { .init(id: $0.id, title: "Medication decision", symbol: "pills", detail: $0.status.rawValue.capitalized) },
            limit: HomeCardPresentationStyle(kind: .care, preset: preset).rowLimit(lowEnergy: router.dashboardMode == .lowEnergy),
            statusMessage: events.isEmpty ? "No unresolved care decisions" : nil,
            statusSymbol: "checkmark.circle", actionTitle: "Open Care", identifier: "care", palette: palette,
            onOpen: { router.navigate(.careLibrary, in: .track) },
            onOpenRow: { _ in router.navigate(.careLibrary, in: .track) }
        )
    }
}

private struct HomeTasksWidget: View {
    let preset: WidgetSizePreset
    let placementID: UUID
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let captureRouter: CaptureRouter
    let hasPlanningRepository: Bool
    let palette: DaypartPalette
    let motionAnimation: Animation?
    let reduceMotion: Bool
    @Binding var expandedTaskWidgetIDs: Set<UUID>

    var body: some View {
        HomeTasksCardContent(
            tasks: lifeOSStore.taskAgenda.tasks,
            title: HomeSectionCopy.taskWidgetTitle(lifeOSStore),
            emptyMessage: HomeSectionCopy.taskWidgetEmptyMessage(lifeOSStore),
            isLoading: lifeOSStore.isLoading && !lifeOSStore.hasLoadedCore,
            hasPlanningRepository: hasPlanningRepository,
            collapsedLimit: HomeCardPresentationStyle(kind: .tasks, preset: preset).rowLimit(lowEnergy: router.dashboardMode == .lowEnergy),
            isExpanded: expandedTaskWidgetIDs.contains(placementID),
            allowsCompletion: V2FeatureFlags.lifeBoardDailyLoopV1Enabled,
            completedTask: lifeOSStore.lastCompletedTask,
            refreshFailure: refreshFailure,
            palette: palette,
            dateControls: HomeTaskAgendaDatePicker(store: lifeOSStore),
            taskWidgetAnimation: reduceMotion ? nil : motionAnimation,
            onComplete: { task in Task { await lifeOSStore.setTaskCompletion(task, to: true) } },
            onOpen: { router.navigate(.taskDetail($0.id), in: .home) },
            onAdd: { captureRouter.request(kind: .task, source: .widget) },
            onUndo: { Task { await lifeOSStore.undoLastTaskCompletion() } },
            onRetry: { Task { await lifeOSStore.retryTaskMutationRefresh() } },
            onToggleExpansion: {
                withAnimation(reduceMotion ? nil : motionAnimation) {
                    lifeOSStore.resetTaskAgendaDateToToday()
                    if expandedTaskWidgetIDs.contains(placementID) {
                        expandedTaskWidgetIDs.remove(placementID)
                    } else {
                        expandedTaskWidgetIDs.insert(placementID)
                    }
                }
            }
        )
    }

    private var refreshFailure: String? {
        if case .failed(let message) = lifeOSStore.lastTaskMutationRefreshOutcome { return message }
        return nil
    }
}

private struct HomeRoutinesWidget: View {
    let preset: WidgetSizePreset
    let lifeOSStore: HomeLifeOSProjectionStore
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let hasTrackFoundationRepository: Bool
    let daypart: ResolvedDaypart
    let palette: DaypartPalette

    var body: some View {
        HomeActionQueueCardContent(
            title: "\(daypart.rawValue.capitalized) routines", symbol: "repeat", rows: rows,
            limit: HomeCardPresentationStyle(kind: .routines, preset: preset).rowLimit(lowEnergy: router.dashboardMode == .lowEnergy),
            statusMessage: statusMessage, statusSymbol: statusSymbol,
            actionTitle: "View \(daypart.rawValue) routines", identifier: "routines", palette: palette,
            titleIsAction: true, onOpen: openDaypart,
            onOpenRow: { id in
                if lifeOSStore.trackSnapshot?.dueRoutines.isEmpty != false {
                    router.navigate(.habitBoard, in: .track)
                } else {
                    router.openLeaf(.routine(id), in: .track)
                }
            }
        )
    }

    private var rows: [HomeCardQueueRow] {
        let routines = lifeOSStore.trackSnapshot?.dueRoutines ?? []
        if !routines.isEmpty { return routines.map { .init(id: $0.id, title: $0.title, symbol: "figure.mind.and.body", accessibilityIdentifier: "home.routine.\($0.id.uuidString)") } }
        if let habit = (projectionAdapter.snapshot.recoveryHabits + projectionAdapter.snapshot.currentHabits).first {
            return [.init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: habit, symbol: "repeat", accessibilityIdentifier: "home.routines.openHabitBoard")]
        }
        return []
    }

    private var statusMessage: String? {
        if !hasTrackFoundationRepository { return "Routines are unavailable right now" }
        if lifeOSStore.isLoading && lifeOSStore.trackSnapshot == nil { return "Loading routines" }
        return rows.isEmpty ? "No routines are due in this part of the day" : nil
    }

    private var statusSymbol: String {
        if !hasTrackFoundationRepository { return "exclamationmark.triangle" }
        return lifeOSStore.isLoading && lifeOSStore.trackSnapshot == nil ? "hourglass" : "checkmark.circle"
    }

    private func openDaypart() {
        router.openLeaf(.routines(.daypart(daypart)), in: .track)
    }
}

private struct HomeCapacityWidget: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let palette: DaypartPalette

    var body: some View {
        HomeCapacityCardContent(
            title: router.dashboardMode == .lowEnergy ? "Protected rest" : "Capacity",
            summary: summary,
            detail: detail,
            needsSetup: lifeOSStore.planSnapshot?.capacity == nil && projectionAdapter.snapshot.calendarNeedsSetup,
            palette: palette,
            onOpen: { router.navigate(.planDay, in: .plan) }
        )
    }

    private var summary: String {
        if let capacity = lifeOSStore.planSnapshot?.capacity {
            return capacity.overloadDuration > 0
                ? "\(HomeSectionCopy.duration(capacity.overloadDuration)) over capacity"
                : "\(HomeSectionCopy.duration(capacity.remainingKnownCapacity)) known room"
        }
        if let freeUntil = projectionAdapter.snapshot.freeUntil {
            return "Open until \(freeUntil.formatted(date: .omitted, time: .shortened))"
        }
        return "No reliable free window yet"
    }

    private var detail: String {
        if let capacity = lifeOSStore.planSnapshot?.capacity {
            return capacity.isEstimateIncomplete
                ? "Estimate incomplete · confidence \(Int(capacity.confidence * 100))%"
                : "Usable capacity \(HomeSectionCopy.duration(capacity.usableDuration))"
        }
        if projectionAdapter.snapshot.freeUntil != nil {
            return HomeSectionCopy.capacityDescription(router: router, projectionAdapter: projectionAdapter)
        }
        return "Missing estimates lower confidence; LifeBoard won’t invent precision."
    }
}

private struct HomeQuickCaptureWidget: View {
    let captureRouter: CaptureRouter
    let palette: DaypartPalette

    var body: some View {
        HomeQuickCaptureCardContent(
            includesWater: V2FeatureFlags.careModulesV2Enabled,
            palette: palette,
            onCapture: { kind in
                captureRouter.request(kind: kind, source: .shell)
                Haptic.pick.play()
            }
        )
    }
}

private struct HomeTimelineWidget: View {
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let palette: DaypartPalette

    var body: some View {
        HomeTimelineCardContent(
            items: projectionAdapter.snapshot.timelineItems,
            onOpen: { router.select(.plan) },
            palette: palette
        )
    }
}

private struct HomeJournalWidget: View {
    let router: AppRouter
    let captureRouter: CaptureRouter
    let palette: DaypartPalette

    var body: some View {
        HomeJournalCardContent(
            onCapture: { captureRouter.request(kind: .journal, source: .widget) },
            onSearch: { router.navigate(.journalSearch, in: .home) },
            onReflection: {
                let week = Calendar.current.dateInterval(of: .weekOfYear, for: HomeReferenceClock.now)?.start ?? HomeReferenceClock.now
                router.navigate(.weeklyReflection(week), in: .home)
            },
            palette: palette
        )
    }
}

private struct HomeProgressWidget: View {
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let dayLoopSummary: DayLoopSummary?
    let palette: DaypartPalette

    var body: some View {
        HomeProgressCardContent(
            title: router.dashboardMode == .lowEnergy ? "Continuity" : "Progress",
            completionRate: projectionAdapter.snapshot.completionRate,
            openTaskCount: projectionAdapter.snapshot.openTaskCount,
            rhythm: HomeSectionCopy.dayLoopRhythmText(dayLoopSummary), palette: palette,
            onOpen: { router.select(.insights); router.push(.insightEvidence(nil), in: .insights) }
        )
    }
}

/// The product-owned mapping from a Home card to the typed leaf that owns its
/// review and capture experience. Kept pure so route coverage cannot regress
/// behind SwiftUI interaction tests alone.
struct HomeWidgetOpenTarget: Equatable {
    let route: AppRoute
    let actionTitle: String
}

enum HomeWidgetRouteResolver {
    static func target(
        for kind: DashboardWidgetKind,
        resolution: HomeCardResolution?,
        daypart: ResolvedDaypart
    ) -> HomeWidgetOpenTarget? {
        if let route = resolution?.primaryRoute {
            return HomeWidgetOpenTarget(
                route: route,
                actionTitle: resolution?.primaryActionTitle ?? "Open"
            )
        }
        switch kind {
        case .goals: return .init(route: .goals, actionTitle: "View goals")
        case .routines: return .init(route: .routines(.daypart(daypart)), actionTitle: "View routines")
        case .lifeMoment: return .init(route: .lifeMoments(.overview), actionTitle: "View moments")
        case .logMeal: return .init(route: .nutrition(.logMeal), actionTitle: "Log meal")
        case .nutritionSummary: return .init(route: .nutrition(.dailySummary), actionTitle: "View nutrition")
        case .bodyMetric: return .init(route: .wellness(.bodyMetric(.bodyMass)), actionTitle: "View body metrics")
        case .workout: return .init(route: .wellness(.workouts), actionTitle: "View workouts")
        case .sleep: return .init(route: .wellness(.sleep), actionTitle: "View sleep")
        case .movement: return .init(route: .wellness(.movement), actionTitle: "View movement")
        case .fasting: return .init(route: .fasting, actionTitle: "View fasting")
        default: return nil
        }
    }

    static func route(for kind: DashboardWidgetKind) -> AppRoute? {
        switch kind {
        case .goals: .goals
        case .routines: .routines(.library)
        case .lifeMoment: .lifeMoments(.overview)
        case .bodyMetric: .wellness(.bodyMetric(.bodyMass))
        case .workout: .wellness(.workouts)
        case .sleep: .wellness(.sleep)
        case .movement: .wellness(.movement)
        case .nutritionSummary: .nutrition(.dailySummary)
        case .logMeal: .nutrition(.logMeal)
        case .fasting: .fasting
        default: nil
        }
    }
}

private struct HomeCustomizationControls: View {
    let placement: DashboardWidgetPlacementValue
    /// The kind the card is currently *drawing*, which is what "Freeze current
    /// card" has to capture. Resolved by the caller so smart-slot resolution
    /// happens exactly once per placement.
    let displayedKind: DashboardWidgetKind
    let store: AdaptiveHomeStore

    var body: some View {
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
                        let displayed = displayedKind
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
                        ForEach(Destination.allCases, id: \.self) { destination in
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
                .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: Circle())
                .shadow(color: Color(SemanticColorTokens.foundationWarmShadow), radius: 6, y: 2)
        }
        .accessibilityLabel("Edit widget")
        .accessibilityIdentifier("home.widget.edit.\(placement.id.uuidString)")
        .accessibilityAction(named: "Move before") { store.movePlacement(id: placement.id, offset: -1) }
        .accessibilityAction(named: "Move after") { store.movePlacement(id: placement.id, offset: 1) }
        .accessibilityAction(named: "Hide") { store.hidePlacement(id: placement.id) }
    }
}

private struct AdaptiveWidgetGallery: View {
    let store: AdaptiveHomeStore
    let preferences: PresentationPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedKind: DashboardWidgetKind?

    var body: some View {
        NavigationStack {
            List {
                ForEach(WidgetGalleryCategory.allCases, id: \.self) { category in
                    let descriptors = filteredDescriptors.filter { $0.category == category }
                    if descriptors.isEmpty == false {
                        Section(category.title) {
                            ForEach(descriptors, id: \.kind) { descriptor in
                                Button {
                                    selectedKind = descriptor.kind
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: descriptor.systemImage)
                                            .font(.title3)
                                            .frame(width: 38, height: 38)
                                            .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: Radius.field))
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(descriptor.title).font(.headline)
                                            Text("\(descriptor.defaultSize.title) · \(descriptor.multiplicity.title)")
                                                .font(.caption)
                                                .foregroundStyle(Color.lifeboard(.textSecondary))
                                        }
                                    }
                                    .frame(minHeight: 52)
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { selectedKind != nil },
                set: { if !$0 { selectedKind = nil } }
            )) {
                if let selectedKind, let descriptor = store.registry.descriptor(for: selectedKind) {
                    HomeCardPlacementSheet(
                        descriptor: descriptor,
                        destination: .home,
                        onCancel: { self.selectedKind = nil },
                        onAdd: { size in
                            store.addWidget(descriptor, size: size)
                            self.selectedKind = nil
                            dismiss()
                        }
                    )
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

struct DashboardLayoutRevision: Equatable {
    var id: UUID?
    var expanded = false
    var content: HomeCardSnapshot?
    var dynamicType = ""
    var locale = ""
}

private struct DashboardLayoutRevisionKey: LayoutValueKey {
    static let defaultValue = DashboardLayoutRevision()
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
                .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .draggable(placementID.uuidString) {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .fill(Color(SemanticColorTokens.foundationSurfaceSolid).opacity(0.94))
                        .frame(width: 170, height: 108)
                        .overlay {
                            Image(systemName: "hand.draw.fill")
                                .font(.title2)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                        .shadow(color: Color(SemanticColorTokens.foundationWarmShadow).opacity(0.18), radius: 14, y: 8)
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let source = items.compactMap(UUID.init(uuidString:)).first,
                          source != placementID else { return false }
                    onMove(source, placementID)
                    Haptic.pick.play()
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

    struct Cache {
        var signature: Signature?
        var result: LayoutResult?
        var calculationCount = 0
    }

    struct Signature: Equatable {
        let width: CGFloat
        let isRegular: Bool
        let usesSingleColumn: Bool
        let presets: [WidgetSizePreset]
        let revisions: [DashboardLayoutRevision]
    }

    struct LayoutResult {
        let frames: [CGRect]
        let height: CGFloat
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.signature = nil
        cache.result = nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width ?? 360
        let result = cachedFrames(width: width, subviews: subviews, cache: &cache)
        return CGSize(width: width, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let result = cachedFrames(width: bounds.width, subviews: subviews, cache: &cache)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func cachedFrames(width: CGFloat, subviews: Subviews, cache: inout Cache) -> LayoutResult {
        let signature = Signature(
            width: width,
            isRegular: isRegular,
            usesSingleColumn: usesSingleColumn,
            presets: subviews.map { $0[DashboardPresetLayoutKey.self] },
            revisions: subviews.map { $0[DashboardLayoutRevisionKey.self] }
        )
        if cache.signature == signature, let result = cache.result {
            return result
        }
        let result = frames(width: width, subviews: subviews)
        cache.signature = signature
        cache.result = result
        cache.calculationCount &+= 1
        PerformanceTrace.event("DashboardLayoutCalculated", value: cache.calculationCount)
        return result
    }

    private func frames(width: CGFloat, subviews: Subviews) -> LayoutResult {
        let columnCount = usesSingleColumn ? 1 : (isRegular ? (width >= 1_100 ? 12 : 8) : 4)
        let spans = subviews.map {
            usesSingleColumn ? 1 : DashboardResponsiveSpanResolver.columns(
                for: $0[DashboardPresetLayoutKey.self], columnCount: columnCount)
        }
        let result = DashboardFramePlanner.frames(width: width, columnCount: columnCount, spans: spans) { index, itemWidth in
            subviews[index].sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
        }
        return LayoutResult(frames: result.frames, height: result.height)
    }
}

/// Pure geometry boundary; SwiftUI still owns when measurements are invalidated.
enum DashboardFramePlanner {
    struct Result: Equatable {
        let frames: [CGRect]
        let height: CGFloat
    }
    static func frames(width: CGFloat, columnCount: Int, spans: [Int],
        measure: (Int, CGFloat) -> CGSize) -> Result {
        let columnCount = max(1, columnCount)
        let spacing: CGFloat = 12
        let columnWidth = max(0, (width - (CGFloat(columnCount - 1) * spacing)) / CGFloat(columnCount))
        var result = Array(repeating: CGRect.zero, count: spans.count)
        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

        for index in spans.indices {
            let requestedSpan = spans[index]
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
            let measured = measure(index, itemWidth)
            let x = CGFloat(bestColumn) * (columnWidth + spacing)
            result[index] = CGRect(x: x, y: bestY, width: itemWidth, height: measured.height)
            let nextHeight = bestY + measured.height + spacing
            for column in bestColumn..<(bestColumn + itemSpan) {
                columnHeights[column] = nextHeight
            }
        }

        widenRowsWithNoNeighbour(&result, fullWidth: width, measure: measure)

        return Result(frames: result, height: max(0, result.map(\.maxY).max() ?? 0))
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
    private static func widenRowsWithNoNeighbour(
        _ frames: inout [CGRect],
        fullWidth: CGFloat,
        measure: (Int, CGFloat) -> CGSize
    ) {
        let tolerance: CGFloat = 0.5
        var hasNeighbour = Array(repeating: false, count: frames.count)
        var active: [Int] = []

        // Sweep top-to-bottom. The active set contains only vertical ranges
        // that can overlap the current card, replacing the previous all-pairs
        // search while preserving its exact overlap rule.
        for index in frames.indices.sorted(by: { frames[$0].minY < frames[$1].minY }) {
            let current = frames[index]
            active.removeAll { frames[$0].maxY <= current.minY + tolerance }
            for other in active {
                hasNeighbour[index] = true
                hasNeighbour[other] = true
            }
            active.append(index)
        }

        for index in frames.indices {
            let original = frames[index]
            guard original.width < fullWidth - tolerance else { continue }
            guard hasNeighbour[index] == false else { continue }

            let measured = measure(index, fullWidth)
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

public struct ReferenceDashboard: View {
    public let preferences: PresentationPreferences
    public var showsDeveloperControls: Bool

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        preferences: PresentationPreferences,
        showsDeveloperControls: Bool = true
    ) {
        self.preferences = preferences
        self.showsDeveloperControls = showsDeveloperControls
    }

    public var body: some View {
        @Bindable var preferences = preferences
        let daypart = preferences.resolvedDaypart()
        let palette = DaypartTokens.functionalPalette(for: daypart, colorScheme: colorScheme)

        ZStack {
            AtmosphereView(
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
    private func header(daypart: ResolvedDaypart, palette: DaypartPalette) -> some View {
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
                    HStack(spacing: 8) {
                        Text("Smart")
                            .lifeboardFont(.title1)
                        Image(systemName: "chevron.up.chevron.down")
                            .lifeboardFont(.eyebrow)
                    }
                    .foregroundStyle(palette.color(for: .foreground))
                }
                .accessibilityLabel("Dashboard mode and daypart")

                Spacer()

                Button {} label: {
                    Image(systemName: "square.grid.2x2")
                        .lifeboardFont(.sectionTitle)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Customize dashboard")
            }

            Text(daypart.greeting)
                .font(Typography.hero())
                .minimumScaleFactor(0.82)
                .lineLimit(1)
                // The one line in the app that is addressed to the person
                // rather than reporting to them, so it is the one line that
                // answers to a touch. The renderer is identity at rest, and it
                // suppresses itself entirely under Reduce Motion, accessibility
                // Dynamic Type, low power, and the screenshot fixtures.
                .lifeBoardKineticGreeting()

            Text(Date.now.formatted(.dateTime.hour().minute().weekday(.wide).month(.wide).day()))
                .font(Typography.body())
                .foregroundStyle(palette.color(for: .foregroundSecondary))
        }
    }

    private func metricRibbon(palette: DaypartPalette) -> some View {
        HStack(spacing: 12) {
            ReferenceMetricRing(label: "Hydration", value: "1460ml", progress: 0.62, palette: palette)
            ReferenceMetricRing(label: "Steps", value: "3563", progress: 0.48, palette: palette)
            ReferenceMetricRing(label: "Calories", value: "1500", progress: 0.72, palette: palette)
            ReferenceMetricRing(label: "Fasting", value: "8h", progress: 0.56, palette: palette)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func medicationSection(daypart: ResolvedDaypart, palette: DaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ReferenceSectionHeader(title: "\(daypart.rawValue.capitalized) Medications", showsAdd: false, palette: palette)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ReferenceMedicationCard(symbol: "pills", title: daypart == .morning ? "Vitamin C" : "Creatine", detail: daypart == .morning ? "1000 mg" : "3.5g", palette: palette)
                ReferenceMedicationCard(symbol: "cross.case", title: daypart == .morning ? "Tumeric" : "Whey protein", detail: daypart == .morning ? "1 pill" : "1 scoop", palette: palette)
                if daypart != .morning {
                    ReferenceMedicationCard(symbol: "capsule", title: "Omega 3", detail: "1", palette: palette)
                    ReferenceMedicationCard(symbol: "pills.circle", title: "Neurovit", detail: "1 pill", palette: palette)
                }
            }
        }
    }

    private func todoSection(palette: DaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ReferenceSectionHeader(title: "Todos", showsAdd: true, palette: palette)
            ReferenceTodoRow(title: "Ship the ultimate browser", palette: palette)
            ReferenceTodoRow(title: "Finally ship TestFlight", palette: palette)
        }
    }

    @ViewBuilder
    private func habitSection(daypart: ResolvedDaypart, palette: DaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ReferenceSectionHeader(title: "\(daypart.rawValue.capitalized) Habits", showsAdd: false, palette: palette)
            HStack(spacing: 12) {
                ReferenceHabitCard(symbol: "speaker.slash", title: "Lunch in silence", palette: palette)
                ReferenceHabitCard(symbol: "figure.walk", title: "Walk outside", palette: palette)
                ReferenceHabitCard(symbol: "sun.max", title: "Sunlight 10 min", palette: palette)
            }
        }
    }

    private func developerControls(
        preferences: PresentationPreferences,
        palette: DaypartPalette
    ) -> some View {
        @Bindable var preferences = preferences
        return VStack(alignment: .leading, spacing: 14) {
            Text("Foundation controls")
                .font(Typography.sectionTitle())
            // Was `.pickerStyle(.segmented)`, the stock grey segmented
            // control. `OptionRail` is the design system's equivalent and
            // keeps the semantics: one selection, per-value accessibility
            // identifiers, and reflow at accessibility text sizes.
            OptionRail(
                "Comfort",
                selection: $preferences.comfortProfile,
                values: Array(ComfortProfile.allCases),
                identifierPrefix: "lifeBoardFoundationGallery.comfort",
                title: { $0.title }
            )
            // Was `.pickerStyle(.segmented)`, the stock grey segmented
            // control. `OptionRail` is the design system's equivalent and
            // keeps the semantics: one selection, per-value accessibility
            // identifiers, and reflow at accessibility text sizes.
            OptionRail(
                "Rendering",
                selection: $preferences.renderingTier,
                values: Array(AmbientRenderingTier.allCases),
                identifierPrefix: "lifeBoardFoundationGallery.rendering",
                title: { $0.title }
            )
        }
        .padding(16)
        .lifeBoardPaperCard()
        .accessibilityElement(children: .contain)
    }

    private var referenceDock: some View {
        HStack(spacing: 0) {
            ForEach(Destination.allCases, id: \.self) { destination in
                VStack(spacing: 4) {
                    Image(systemName: destination.systemImage)
                        .font(.system(size: 17, weight: destination == .home ? .semibold : .regular))
                    Text(destination.title)
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(
                    destination == .home
                        ? Color(SemanticColorTokens.inkPrimary)
                        : Color(SemanticColorTokens.inkSecondary)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Color(SemanticColorTokens.warmMenuGlass)
                .opacity(reduceTransparency ? 1 : 0.96),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.lifeboard(.textInverse).opacity(colorScheme == .dark ? 0.15 : 0.68), lineWidth: 1)
        }
        .shadow(color: Color(SemanticColorTokens.foundationWarmShadow), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }
}

public struct TokenGallery: View {
    public let preferences: PresentationPreferences

    public init(preferences: PresentationPreferences) {
        self.preferences = preferences
    }

    public var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(ResolvedDaypart.allCases, id: \.self) { daypart in
                    let palette = DaypartTokens.palette(for: daypart)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(daypart.rawValue.capitalized)
                            .font(Typography.sectionTitle())
                            .foregroundStyle(palette.color(for: .foreground))

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132))], spacing: 12) {
                            ForEach(DaypartColorRole.allCases, id: \.self) { role in
                                VStack(alignment: .leading, spacing: 8) {
                                    RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                                        .fill(palette.color(for: role))
                                        .frame(height: 72)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                                                .stroke(Color(SemanticColorTokens.foundationWarmShadow).opacity(0.08), lineWidth: 1)
                                        }
                                    Text(role.rawValue)
                                        .font(.caption.weight(.semibold))
                                    Text(palette.hex(for: role))
                                        .font(.caption.monospaced())
                                }
                                .padding(12)
                                .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }
                    .padding(16)
                    .background(palette.color(for: .canvas), in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
            }
            .padding(20)
        }
        .navigationTitle("Daypart tokens")
        .background(Color(SemanticColorTokens.foundationSurfaceSolid))
    }
}

private struct ReferenceMetricRing: View {
    let label: String
    let value: String
    let progress: Double
    let palette: DaypartPalette

    var body: some View {
        VStack(spacing: 7) {
            Text(label)
                .font(Typography.metadata())
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            ZStack {
                Circle()
                    .trim(from: 0.12, to: 0.88)
                    .stroke(Color(SemanticColorTokens.metricRingTrack), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                Circle()
                    .trim(from: 0.12, to: 0.12 + 0.76 * progress)
                    .stroke(Color(SemanticColorTokens.metricRingFill), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                Text(value)
                    .font(Typography.metadata().weight(.semibold))
                    .foregroundStyle(palette.color(for: .foreground))
            }
            .rotationEffect(.degrees(90))
            .overlay {
                Text(value)
                    .lifeboardFont(.eyebrow)
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
    let palette: DaypartPalette

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(Typography.sectionTitle())
            Image(systemName: "chevron.right")
                .lifeboardFont(.buttonSmall)
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
    let palette: DaypartPalette

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .lifeboardFont(.title1)
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
    let palette: DaypartPalette

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(SemanticColorTokens.foundationSurfaceSolid))
                .overlay(Circle().stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1.5))
                .frame(width: 28, height: 28)
            Text(title)
                .font(Typography.body())
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to complete")
    }
}

private struct ReferenceHabitCard: View {
    let symbol: String
    let title: String
    let palette: DaypartPalette

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .lifeboardFont(.title1)
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
