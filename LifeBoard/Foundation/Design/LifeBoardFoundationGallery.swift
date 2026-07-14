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
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var showsGallery = false

    @ObservationIgnored private let repository: (any DashboardLayoutRepository)?
    @ObservationIgnored let registry: DashboardWidgetRegistry

    init(
        repository: (any DashboardLayoutRepository)?,
        registry: DashboardWidgetRegistry = DefaultDashboardWidgetRegistry.shared
    ) {
        self.repository = repository
        self.registry = registry
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
        draft = HomeLayoutDraft(layout: layout)
    }

    func cancelCustomization() { draft = nil }

    func saveCustomization() async {
        guard let committed = try? draft?.committedLayout() else { return }
        layout = committed
        draft = nil
        do {
            try await repository?.saveHome(committed)
        } catch {
            errorMessage = "Home was updated on this screen, but could not be saved."
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

    func resizePlacement(id: UUID, to size: WidgetSizePreset) {
        guard var value = draft else { return }
        value.resize(id: id, to: size, registry: registry)
        draft = value
    }

    func hidePlacement(id: UUID) {
        guard var value = draft else { return }
        value.setVisible(false, id: id)
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

    func dismissError() { errorMessage = nil }
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
                            .overlay(Circle().stroke(Color.white.opacity(0.62), lineWidth: 1))
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
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) { selectedMood = mood }
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

struct LifeBoardAdaptiveHome: View {
    let projectionAdapter: HomeProjectionAdapter
    let preferences: LifeBoardPresentationPreferences
    let router: LifeBoardAppRouter
    let captureRouter: CaptureRouter
    let phaseIIRepository: (any LifeBoardPhaseIIRepository)?

    @State private var store: AdaptiveHomeStore
    @State private var lifeOSStore: HomeLifeOSProjectionStore
    @State private var selectedMood: LifeBoardJournalMood = .none
    @State private var moodEnergy: Int?
    @State private var showsMoodDial = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        projectionAdapter: HomeProjectionAdapter,
        preferences: LifeBoardPresentationPreferences,
        router: LifeBoardAppRouter,
        captureRouter: CaptureRouter,
        repository: (any DashboardLayoutRepository)?,
        phaseIIRepository: (any LifeBoardPhaseIIRepository)? = nil,
        planningRepository: CoreDataPlanningRepository? = nil,
        trackFoundationRepository: CoreDataTrackFoundationRepository? = nil
    ) {
        self.projectionAdapter = projectionAdapter
        self.preferences = preferences
        self.router = router
        self.captureRouter = captureRouter
        self.phaseIIRepository = phaseIIRepository
        _store = State(initialValue: AdaptiveHomeStore(repository: repository))
        _lifeOSStore = State(initialValue: HomeLifeOSProjectionStore(
            planningRepository: planningRepository,
            trackRepository: trackFoundationRepository,
            phaseIIRepository: phaseIIRepository
        ))
    }

    var body: some View {
        @Bindable var store = store
        let daypart = preferences.resolvedDaypart()
        let palette = LifeBoardDaypartTokens.palette(for: daypart)

        ZStack(alignment: .bottomTrailing) {
            LifeBoardAtmosphereView(
                daypart: daypart,
                requestedTier: preferences.renderingTier,
                comfortProfile: preferences.comfortProfile
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    adaptiveHeader(daypart: daypart, palette: palette)

                    DashboardFlowLayout(isRegular: horizontalSizeClass == .regular) {
                        ForEach(visiblePlacements) { placement in
                            dashboardWidget(for: placement, daypart: daypart, palette: palette)
                                .dashboardPreset(effectivePreset(for: placement.semanticSize))
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 128)
            }
            .scrollIndicators(.hidden)

            captureOrb(palette: palette)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
        .foregroundStyle(palette.color(for: .foreground))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.load()
            await lifeOSStore.load()
            if let latest = lifeOSStore.latestMood {
                selectedMood = latest.mood
                moodEnergy = latest.energy
            } else {
                await loadMoodCheckIn()
            }
        }
        .sheet(isPresented: $store.showsGallery) {
            AdaptiveWidgetGallery(store: store, preferences: preferences)
        }
        .fullScreenCover(isPresented: $showsMoodDial) {
            LifeBoardJournalMoodDialSheet(selectedMood: $selectedMood) { energy in
                moodEnergy = energy
                guard let phaseIIRepository else { return }
                Task {
                    if V2FeatureFlags.trackFoundationsV2Enabled {
                        await lifeOSStore.saveMood(selectedMood, energy: energy)
                    } else {
                        try? await phaseIIRepository.saveMoodCheckIn(.init(mood: selectedMood, energy: energy))
                    }
                }
            }
        }
        .alert(
            "Home layout",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.dismissError() } }
            )
        ) {
            Button("OK", role: .cancel) { store.dismissError() }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .animation(motionAnimation, value: router.dashboardMode)
        .animation(motionAnimation, value: daypart)
    }

    private func loadMoodCheckIn() async {
        guard let phaseIIRepository else { return }
        let start = Calendar.current.startOfDay(for: Date())
        let values = try? await phaseIIRepository.fetchMoodCheckIns(from: start, to: Date().addingTimeInterval(1))
        guard let latest = values?.first else { return }
        selectedMood = latest.mood
        moodEnergy = latest.energy
    }

    private var visiblePlacements: [DashboardWidgetPlacementValue] {
        store.activeLayout.placements
            .filter { $0.isVisible && store.registry.descriptor(for: DashboardWidgetKind(rawValue: $0.widgetKind)) != nil }
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
                    HStack(spacing: 6) {
                        Text(router.dashboardMode.title)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .accessibilityLabel("Dashboard mode, \(router.dashboardMode.title)")

                Spacer()

                if store.isCustomizing {
                    Button("Cancel") { store.cancelCustomization() }
                        .frame(minHeight: 44)
                    Button("Done") { Task { await store.saveCustomization() } }
                        .fontWeight(.semibold)
                        .frame(minHeight: 44)
                } else if V2FeatureFlags.dashboardCustomizationV2Enabled {
                    Button {
                        store.beginCustomization()
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Customize Home")
                }
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(router.dashboardMode == .lowEnergy ? "Let’s take it gently" : daypart.greeting)
                        .font(LifeBoardFoundationTypography.hero())
                        .minimumScaleFactor(0.76)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    Text(projectionAdapter.snapshot.selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(LifeBoardFoundationTypography.body())
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
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
        let kind = DashboardWidgetKind(rawValue: placement.widgetKind)
        Group {
            switch kind {
            case .focusNow:
                focusNowWidget(palette: palette)
            case .lifeSnapshot:
                lifeSnapshotWidget(palette: palette)
            case .care:
                careWidget(daypart: daypart, palette: palette)
            case .scheduleCapacity:
                capacityWidget(palette: palette)
            case .quickCapture:
                quickCaptureWidget(palette: palette)
            case .compactTimeline:
                timelineWidget(palette: palette)
            case .progressReflection:
                progressWidget(palette: palette)
            default:
                EmptyView()
            }
        }
        .overlay(alignment: .topTrailing) {
            if store.isCustomizing {
                customizationControls(for: placement, palette: palette)
                    .padding(8)
            }
        }
        .onLongPressGesture {
            guard V2FeatureFlags.dashboardCustomizationV2Enabled, store.isCustomizing == false else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            store.beginCustomization()
        }
        .accessibilityAction(named: "Customize") { store.beginCustomization() }
    }

    private func focusNowWidget(palette: LifeBoardDaypartPalette) -> some View {
        let primary = lifeOSStore.focusTask?.title ?? projectionAdapter.snapshot.focusTitles.first
        let lowEnergy = router.dashboardMode == .lowEnergy
        return VStack(alignment: .leading, spacing: 14) {
            widgetTitle(lowEnergy ? "One small thing" : "Focus Now", symbol: lowEnergy ? "leaf.fill" : "scope", palette: palette)
            Text(primary ?? (lowEnergy ? "Drink some water and take one quiet minute." : "You’re oriented. Choose one useful next step."))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let reason = lifeOSStore.focusResult?.reasons.first?.text {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            HStack {
                Button {
                    if primary == nil { captureRouter.request(kind: .task, source: .shell) }
                } label: {
                    Text(primary == nil ? "Choose a focus" : "Start")
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(LifeBoardColorTokens.inkPrimary))
                .frame(minHeight: 44)
                if projectionAdapter.snapshot.focusTitles.count > 1 {
                    Button("See options") { router.select(.plan) }
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(18)
        .lifeBoardFloatingClayCard(palette: palette)
        .accessibilityElement(children: .contain)
    }

    private func lifeSnapshotWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            widgetTitle("How life feels", symbol: "heart.text.square", palette: palette)
            HStack(spacing: 10) {
                snapshotMetric(
                    symbol: "face.smiling",
                    value: selectedMood == .none ? "Check in" : selectedMood.title,
                    label: moodEnergy.map { "Mood · E\($0)" } ?? "Mood",
                    palette: palette
                ) {
                    showsMoodDial = true
                }
                snapshotMetric(
                    symbol: "drop.fill",
                    value: homeHydrationLabel,
                    label: "Hydration",
                    palette: palette
                ) { captureRouter.request(kind: .hydration, source: .shell) }
                snapshotMetric(symbol: "figure.walk", value: "Connect", label: "Steps", palette: palette) {}
                if router.dashboardMode != .lowEnergy {
                    snapshotMetric(symbol: "flame.fill", value: "Connect", label: "Active", palette: palette) {}
                }
            }
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func careWidget(daypart: ResolvedDaypart, palette: LifeBoardDaypartPalette) -> some View {
        let routines = lifeOSStore.trackSnapshot?.dueRoutines.map(\.title) ?? []
        let habits = routines + projectionAdapter.snapshot.recoveryHabits + projectionAdapter.snapshot.currentHabits
        return VStack(alignment: .leading, spacing: 13) {
            widgetTitle("\(daypart.rawValue.capitalized) care", symbol: "cross.case.fill", palette: palette)
            if habits.isEmpty {
                honestEmptyState("No care routines are due now", symbol: "checkmark.circle", palette: palette)
            } else {
                ForEach(Array(habits.prefix(router.dashboardMode == .lowEnergy ? 2 : 4).enumerated()), id: \.offset) { _, title in
                    HStack(spacing: 10) {
                        Circle().fill(palette.color(for: .layerOne)).frame(width: 9, height: 9)
                        Text(title).font(.subheadline.weight(.medium)).lineLimit(2)
                        Spacer()
                    }
                }
            }
            Divider().overlay(Color(LifeBoardColorTokens.foundationHairline))
            Label(homeMedicationLabel, systemImage: "pills")
                .font(.caption)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func capacityWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            widgetTitle(router.dashboardMode == .lowEnergy ? "Protected rest" : "Capacity", symbol: "calendar.badge.clock", palette: palette)
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
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func quickCaptureWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetTitle("Capture", symbol: "plus", palette: palette)
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
        }
        .padding(16)
        .lifeBoardRaisedClayCard(palette: palette)
    }

    private func progressWidget(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            widgetTitle(router.dashboardMode == .lowEnergy ? "Continuity" : "Progress & reflection", symbol: "chart.line.uptrend.xyaxis", palette: palette)
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
                captureRouter.request(kind: .journal, source: .shell)
            } label: {
                HStack {
                    Label(projectionAdapter.snapshot.hasReflection ? "Reflection captured" : "A small reflection?", systemImage: "book.pages")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
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
    }

    private func snapshotMetric(
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

    private func captureOrb(palette: LifeBoardDaypartPalette) -> some View {
        Menu {
            ForEach(CaptureKind.allCases, id: \.self) { kind in
                Button(kind.title, systemImage: kind.systemImage) {
                    captureRouter.request(kind: kind, source: .shell)
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(palette.color(for: .foreground))
                .frame(width: 58, height: 58)
                .background(palette.color(for: .celestialPrimary), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1))
                .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.25), radius: 16, y: 8)
        }
        .accessibilityLabel("Universal capture")
    }

    private func customizationControls(
        for placement: DashboardWidgetPlacementValue,
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

private extension View {
    func dashboardPreset(_ value: WidgetSizePreset) -> some View {
        layoutValue(key: DashboardPresetLayoutKey.self, value: value)
    }

    func lifeBoardRaisedClayCard(palette: LifeBoardDaypartPalette) -> some View {
        let isNight = palette.canvas == LifeBoardDaypartTokens.night.canvas
        let surface = isNight
            ? palette.color(for: .layerOne)
            : Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.94)
        return background(surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(isNight ? 0.16 : 0.68), lineWidth: 1)
            }
            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.12), radius: 8, y: 4)
    }

    func lifeBoardFloatingClayCard(palette: LifeBoardDaypartPalette) -> some View {
        let isNight = palette.canvas == LifeBoardDaypartTokens.night.canvas
        let surface = isNight
            ? palette.color(for: .layerOne)
            : Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.97)
        return background(surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(isNight ? 0.2 : 0.76), lineWidth: 1)
            }
            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.17), radius: 18, y: 8)
    }

    func lifeBoardEmbeddedClayWell(palette: LifeBoardDaypartPalette) -> some View {
        let isNight = palette.canvas == LifeBoardDaypartTokens.night.canvas
        let surface = isNight
            ? palette.color(for: .layerTwo)
            : palette.color(for: .canvasSecondary).opacity(0.72)
        return background(surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(LifeBoardColorTokens.foundationHairline).opacity(0.72), lineWidth: 1)
            }
    }
}

private struct DashboardFlowLayout: Layout {
    let isRegular: Bool
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
        let columnWidth = max(0, (width - spacing) / 2)
        var result = Array(repeating: CGRect.zero, count: subviews.count)
        var y: CGFloat = 0
        var pendingHalf: (index: Int, height: CGFloat)?

        func span(for preset: WidgetSizePreset) -> Int {
            if isRegular { return preset == .wide ? 2 : 1 }
            return preset == .compact ? 1 : 2
        }

        for index in subviews.indices {
            let preset = subviews[index][DashboardPresetLayoutKey.self]
            let itemSpan = span(for: preset)
            if itemSpan == 2 {
                if let pendingHalf {
                    y += pendingHalf.height + spacing
                }
                pendingHalf = nil
                let measured = subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil))
                result[index] = CGRect(x: 0, y: y, width: width, height: measured.height)
                y += measured.height + spacing
            } else {
                let measured = subviews[index].sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
                if let first = pendingHalf {
                    result[index] = CGRect(x: columnWidth + spacing, y: y, width: columnWidth, height: measured.height)
                    let rowHeight = max(first.height, measured.height)
                    result[first.index].size.height = rowHeight
                    result[index].size.height = rowHeight
                    y += rowHeight + spacing
                    pendingHalf = nil
                } else {
                    result[index] = CGRect(x: 0, y: y, width: columnWidth, height: measured.height)
                    pendingHalf = (index, measured.height)
                }
            }
        }
        if let pendingHalf { y += pendingHalf.height + spacing }
        return (result, max(0, y - spacing))
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

private extension CaptureKind {
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

private extension WidgetSizePreset {
    var title: String { rawValue.capitalized }
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

private extension DashboardWidgetDescriptor {
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
        case .scheduleCapacity: return "calendar.badge.clock"
        case .quickCapture: return "plus.circle"
        case .compactTimeline: return "timeline.selection"
        case .progressReflection: return "chart.line.uptrend.xyaxis"
        default: return "square.grid.2x2"
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
        let palette = LifeBoardDaypartTokens.palette(for: daypart)

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
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.15 : 0.68), lineWidth: 1)
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
                                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
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
