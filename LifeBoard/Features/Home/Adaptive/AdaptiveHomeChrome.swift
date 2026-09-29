import SwiftUI
import UIKit
import LifeBoardDomain

struct HomeCustomizationActionBar: View {
    let store: AdaptiveHomeStore
    let palette: DaypartPalette
    let motionAnimation: Animation?

    var body: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                withAnimation(motionAnimation) { store.cancelCustomization() }
            }
            .frame(minWidth: 88, minHeight: 48)
            .keyboardShortcut(.cancelAction)
            .accessibilityIdentifier("home.customization.cancel")

            Spacer(minLength: 8)

            Button("Done") {
                Task { await store.saveCustomization() }
            }
            .fontWeight(.semibold)
            .frame(minWidth: 88, minHeight: 48)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("home.customization.done")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(palette.color(for: .foreground))
        .lifeBoardGlassSurface(cornerRadius: Radius.dock, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.dock, style: .continuous)
                .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.customization.actions")
    }
}

struct AdaptiveWidgetGallery: View {
    let store: AdaptiveHomeStore
    let preferences: PresentationPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedKind: DashboardWidgetKind?
    @State private var confirmsReset = false

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
                                            Text(descriptor.multiplicity.galleryDetail(defaultSize: descriptor.defaultSize))
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
            .searchable(text: $query, prompt: "Search cards")
            .navigationTitle("Add a card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.keyboardShortcut(.cancelAction) }
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset Home…", role: .destructive) {
                        confirmsReset = true
                    }
                }
            }
            // Resetting replaces every card and position the person chose, so
            // it asks first and says what is lost.
            .confirmationDialog(
                "Reset Home?",
                isPresented: $confirmsReset,
                titleVisibility: .visible
            ) {
                Button("Reset Home", role: .destructive) {
                    store.resetDraft()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Replaces your cards, sizes and order when you tap Done.")
            }
        }
    }

    private var filteredDescriptors: [DashboardWidgetDescriptor] {
        let all = store.registry.availableDescriptors()
        guard query.isEmpty == false else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.category.title.localizedCaseInsensitiveContains(query) }
    }
}

extension WidgetGalleryCategory {
    var title: String {
        switch self {
        case .orient: String(localized: "Orient")
        case .act: String(localized: "Act")
        case .plan: String(localized: "Plan")
        case .wellbeing: String(localized: "Wellbeing")
        case .reflect: String(localized: "Reflect")
        case .progress: String(localized: "Progress")
        }
    }
}

extension WidgetMultiplicity {
    /// The gallery row's second line, in plain words.
    func galleryDetail(defaultSize: WidgetSizePreset) -> String {
        switch self {
        case .singleton: String(localized: "\(defaultSize.title) card")
        case .multipleInstances: String(localized: "\(defaultSize.title) card · add as many as you like")
        }
    }
}

// MARK: - Presentation and lifecycle chains
//
// Kept off `AdaptiveHome.body` so the struct and its helper extension each
// fit the file-size gate; every binding is the same `@State` the sheets and
// tasks always used.

extension AdaptiveHome {
    /// The alerts and sheets, kept off `body` so the struct stays inside the
    /// file-size gate; every binding is the same `@State` the sheets always used.
    func presentations(palette: DaypartPalette) -> some ViewModifier {
        AdaptiveHomeChain { content in
            content
        .alert("Couldn’t update fast", isPresented: $showsFastingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(lifeOSStore.fastingMutationError ?? String(localized: "Try again."))
        }
        .alert("Couldn’t save check-in", isPresented: Binding(
            get: { moodSaveError != nil }, set: { if !$0 { moodSaveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(moodSaveError ?? String(localized: "Try again."))
        }
        .sheet(isPresented: $store.showsGallery) {
            AdaptiveWidgetGallery(store: store, preferences: preferences)
        }
        // Full screen on iPhone; a page sheet on iPad and Mac, where one dial
        // covering the whole display lost the Home it was opened from.
        .lifeboardCover(isPresented: $showsMoodDial) {
            JournalMoodDialSheet(selectedMood: $selectedMood, offersReasons: false) { energy, _ in
                moodEnergy = energy
                Task {
                    // The dial no longer buzzes before the save; the
                    // outcome decides which haptic plays.
                    if case .failed(let message) = await lifeOSStore.saveMood(selectedMood, energy: energy) {
                        Haptic.fail.play()
                        moodSaveError = message
                    } else {
                        Haptic.commit.play()
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        }
    }

    /// Loading, refresh boundaries and observation. Same reasoning as
    /// `presentations(palette:)`.
    func lifecycle(daypart: ResolvedDaypart) -> some ViewModifier {
        AdaptiveHomeChain { content in
            content
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
            // Coming back to Home on a new day starts from that day.
            lifeOSStore.rollAgendaToToday()
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
        // "Today" used to be fixed at launch: left open overnight, Home kept
        // showing yesterday's tasks, stage and ritual until relaunch.
        .onReceive(
            NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
                .merge(with: NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification))
                .merge(with: NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange))
                .receive(on: DispatchQueue.main)
        ) { _ in
            lifeOSStore.rollAgendaToToday()
            refreshContextSelection(boundary: .calendarBoundary, immediate: true)
            Task { await refreshDayLoopStage() }
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
        // Report again on the way back: leaving mid-edit reported `false`, and
        // an unchanged value never re-fires the `onChange` above, so the shell
        // drew the dock and composer over the edit bar.
        .onAppear {
            onCustomizationChanged(store.isCustomizing)
        }
        .onDisappear {
            onCustomizationChanged(false)
        }
        }
    }
}

/// A modifier built from a closure, so the presentation and lifecycle chains
/// can live in extension funcs without restating every binding as a parameter.
struct AdaptiveHomeChain<Chained: View>: ViewModifier {
    let chain: (AnyView) -> Chained
    init(@ViewBuilder _ chain: @escaping (AnyView) -> Chained) { self.chain = chain }
    func body(content: Content) -> some View { chain(AnyView(content)) }
}
