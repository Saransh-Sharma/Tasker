import SwiftUI
import UIKit

public struct LifeOSFoundationShell: View {
    private let legacyHomeController: UIViewController
    private let runtime: LifeOSFoundationRuntime
    private let showsReferenceHome: Bool
    private let homeProjectionAdapter: HomeProjectionAdapter?
    private let dashboardLayoutRepository: (any DashboardLayoutRepository)?
    private let phaseIIRepository: (any LifeBoardPhaseIIRepository)?
    private let planningRepository: CoreDataPlanningRepository?
    private let trackFoundationRepository: CoreDataTrackFoundationRepository?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        legacyHomeController: UIViewController,
        runtime: LifeOSFoundationRuntime = .shared,
        homeProjectionAdapter: HomeProjectionAdapter? = nil,
        dashboardLayoutRepository: (any DashboardLayoutRepository)? = nil,
        phaseIIRepository: (any LifeBoardPhaseIIRepository)? = nil,
        planningRepository: CoreDataPlanningRepository? = nil,
        trackFoundationRepository: CoreDataTrackFoundationRepository? = nil,
        showsReferenceHome: Bool = ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_FOUNDATION_REFERENCE_DASHBOARD")
    ) {
        self.legacyHomeController = legacyHomeController
        self.runtime = runtime
        self.homeProjectionAdapter = homeProjectionAdapter
        self.dashboardLayoutRepository = dashboardLayoutRepository
        self.phaseIIRepository = phaseIIRepository
        self.planningRepository = planningRepository
        self.trackFoundationRepository = trackFoundationRepository
        self.showsReferenceHome = showsReferenceHome
    }

    public var body: some View {
        @Bindable var router = runtime.router
        Group {
            if horizontalSizeClass == .regular {
                expandedShell(router: router)
            } else {
                compactShell(router: router)
            }
        }
        .environment(runtime.preferences)
        .sheet(isPresented: capturePresentationBinding) {
            if let request = runtime.captureRouter.activeRequest {
                FoundationCaptureSheet(
                    request: request,
                    phaseIIRepository: phaseIIRepository,
                    planningRepository: planningRepository,
                    trackFoundationRepository: trackFoundationRepository
                )
            }
        }
        .alert(item: $router.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .onOpenURL { url in
            _ = runtime.handle(url: url)
        }
    }

    private func compactShell(router: LifeBoardAppRouter) -> some View {
        @Bindable var router = router
        return TabView(selection: $router.selectedDestination) {
            ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                destinationNavigation(destination, router: router)
                    .tabItem {
                        Label(destination.title, systemImage: destination.systemImage)
                    }
                    .tag(destination)
            }
        }
    }

    private func expandedShell(router: LifeBoardAppRouter) -> some View {
        @Bindable var router = router
        return NavigationSplitView {
            List {
                ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                    Button {
                        router.select(destination)
                    } label: {
                        Label(destination.title, systemImage: destination.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        router.selectedDestination == destination
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                }
            }
            .navigationTitle("LifeBoard")
        } detail: {
            destinationNavigation(router.selectedDestination, router: router)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func destinationNavigation(
        _ destination: LifeBoardDestination,
        router: LifeBoardAppRouter
    ) -> some View {
        NavigationStack(path: pathBinding(for: destination)) {
            destinationRoot(destination, router: router)
                .navigationDestination(for: AppRoute.self) { route in
                    routeView(route)
                }
                .toolbar {
                    if destination != .home || showsReferenceHome {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button {
                                router.push(.tokenGallery, in: destination)
                            } label: {
                                Image(systemName: "swatchpalette")
                            }
                            .accessibilityLabel("Open token gallery")

                            Menu {
                                Button("Task", systemImage: "checkmark.circle") {
                                    runtime.captureRouter.request(kind: .task, source: .shell)
                                }
                                Button("Habit", systemImage: "repeat.circle") {
                                    runtime.captureRouter.request(kind: .habit, source: .shell)
                                }
                                if V2FeatureFlags.journalV1Enabled {
                                    Button("Journal", systemImage: "book.closed") {
                                        runtime.captureRouter.request(kind: .journal, source: .shell)
                                    }
                                }
                                if V2FeatureFlags.knowledgeNotesV1Enabled {
                                    Button("Note", systemImage: "note.text") {
                                        runtime.captureRouter.request(kind: .note, source: .shell)
                                    }
                                }
                                if V2FeatureFlags.trackersV1Enabled {
                                    Button("Tracker Entry", systemImage: "chart.bar.doc.horizontal") {
                                        runtime.captureRouter.request(kind: .trackerEntry, source: .shell)
                                    }
                                }
                                if V2FeatureFlags.careModulesV2Enabled {
                                    Button("Mood + Energy", systemImage: "face.smiling") {
                                        runtime.captureRouter.request(kind: .mood, source: .shell)
                                    }
                                    Button("Hydration", systemImage: "drop.fill") {
                                        runtime.captureRouter.request(kind: .hydration, source: .shell)
                                    }
                                    Button("Medication Event", systemImage: "pills") {
                                        runtime.captureRouter.request(kind: .medicationEvent, source: .shell)
                                    }
                                }
                                if V2FeatureFlags.goalsRoutinesV1Enabled {
                                    Button("Routine Run", systemImage: "figure.mind.and.body") {
                                        runtime.captureRouter.request(kind: .routineRun, source: .shell)
                                    }
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .accessibilityLabel("Universal capture")
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func destinationRoot(
        _ destination: LifeBoardDestination,
        router: LifeBoardAppRouter
    ) -> some View {
        if destination == .home,
           V2FeatureFlags.adaptiveHomeV2Enabled,
           let homeProjectionAdapter {
            LifeBoardAdaptiveHome(
                projectionAdapter: homeProjectionAdapter,
                preferences: runtime.preferences,
                router: router,
                captureRouter: runtime.captureRouter,
                repository: dashboardLayoutRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                trackFoundationRepository: trackFoundationRepository
            )
        } else if destination == .home, showsReferenceHome == false {
            LegacyHomeControllerHost(controller: legacyHomeController)
                .ignoresSafeArea()
        } else if destination == .plan,
                  V2FeatureFlags.planningCoreV1Enabled,
                  V2FeatureFlags.planDestinationV1Enabled,
                  let planningRepository {
            LifeBoardPlanRootView(repository: planningRepository)
        } else if destination == .track,
                  V2FeatureFlags.trackFoundationsV2Enabled,
                  let trackFoundationRepository,
                  let phaseIIRepository {
            LifeBoardTrackFoundationRootView(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository
            )
        } else if destination == .track,
                  (V2FeatureFlags.trackersV1Enabled || V2FeatureFlags.healthIntegrationsV1Enabled || V2FeatureFlags.journalV1Enabled || V2FeatureFlags.knowledgeNotesV1Enabled),
                  let phaseIIRepository {
            LifeBoardTrackRootView(repository: phaseIIRepository)
        } else if destination == .home {
            LifeBoardReferenceDashboard(preferences: runtime.preferences)
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
        } else {
            FoundationDestinationBridgeView(destination: destination) {
                router.select(.home)
                DispatchQueue.main.async {
                    postLegacyRoute(for: destination)
                }
            }
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        switch route {
        case .tokenGallery:
            LifeBoardTokenGallery(preferences: runtime.preferences)
        case .referenceDashboard:
            LifeBoardReferenceDashboard(preferences: runtime.preferences)
                .navigationTitle("Reference dashboard")
                .navigationBarTitleDisplayMode(.inline)
        case .weeklyPlanner:
            FoundationRoutePlaceholder(title: "Weekly Planner", systemImage: "calendar.badge.clock")
        case .weeklyReview:
            FoundationRoutePlaceholder(title: "Weekly Review", systemImage: "checklist")
        case .settings:
            FoundationRoutePlaceholder(title: "Settings", systemImage: "gearshape")
        case .taskDetail(let id):
            FoundationRoutePlaceholder(title: "Task", detail: id.uuidString, systemImage: "checkmark.circle")
        case .habitDetail(let id):
            FoundationRoutePlaceholder(title: "Habit", detail: id.uuidString, systemImage: "repeat.circle")
        case .project(let id):
            FoundationRoutePlaceholder(title: "Project", detail: id.uuidString, systemImage: "folder")
        }
    }

    private var capturePresentationBinding: Binding<Bool> {
        Binding(
            get: { runtime.captureRouter.activeRequest != nil },
            set: { isPresented in
                if isPresented == false {
                    runtime.captureRouter.completeActiveRequest()
                }
            }
        )
    }

    private func pathBinding(for destination: LifeBoardDestination) -> Binding<[AppRoute]> {
        Binding(
            get: { runtime.router.path(for: destination) },
            set: { runtime.router.setPath($0, for: destination) }
        )
    }

    private func postLegacyRoute(for destination: LifeBoardDestination) {
        let name: Notification.Name
        switch destination {
        case .home:
            name = .lifeboardOpenHomeDeepLink
        case .plan:
            name = .lifeboardOpenCalendarScheduleDeepLink
        case .track:
            name = .lifeboardOpenHabitBoardDeepLink
        case .insights:
            name = .lifeboardOpenInsightsDeepLink
        case .eva:
            name = .lifeboardOpenChatDeepLink
        }
        NotificationCenter.default.post(name: name, object: nil)
    }
}

private struct LegacyHomeControllerHost: UIViewControllerRepresentable {
    let controller: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private struct FoundationDestinationBridgeView: View {
    let destination: LifeBoardDestination
    let openLegacySurface: () -> Void

    @Environment(LifeBoardPresentationPreferences.self) private var environmentPreferences

    init(destination: LifeBoardDestination, openLegacySurface: @escaping () -> Void) {
        self.destination = destination
        self.openLegacySurface = openLegacySurface
    }

    var body: some View {
        let palette = LifeBoardDaypartTokens.palette(for: environmentPreferences.resolvedDaypart())
        ZStack {
            LifeBoardAtmosphereView(
                daypart: environmentPreferences.resolvedDaypart(),
                requestedTier: environmentPreferences.renderingTier,
                comfortProfile: environmentPreferences.comfortProfile
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: destination.systemImage)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                Text(destination.title)
                    .font(LifeBoardFoundationTypography.screenTitle())
                Text("The Phase 1 shell owns navigation and restoration. This adapter opens the existing production surface while the redesigned destination is built.")
                    .font(LifeBoardFoundationTypography.body())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                Button(action: openLegacySurface) {
                    Text("Open current \(destination.title)")
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(LifeBoardColorTokens.inkPrimary))
                    .frame(minHeight: 44)
            }
            .padding(24)
            .lifeBoardPaperCard()
            .padding(24)
        }
        .foregroundStyle(palette.color(for: .foreground))
        .navigationTitle(destination.title)
    }
}

private struct FoundationRoutePlaceholder: View {
    let title: String
    var detail: String? = nil
    let systemImage: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let detail {
                Text(detail)
                    .font(.caption.monospaced())
            } else {
                Text("This typed route is ready for its owning product phase.")
            }
        }
        .navigationTitle(title)
    }
}

private struct FoundationCaptureSheet: View {
    let request: CaptureRequest
    let phaseIIRepository: (any LifeBoardPhaseIIRepository)?
    let planningRepository: CoreDataPlanningRepository?
    let trackFoundationRepository: CoreDataTrackFoundationRepository?

    var body: some View {
        switch request.kind {
        case .task:
            FoundationTaskCaptureHost()
        case .habit:
            FoundationHabitCaptureHost()
        case .journal:
            if V2FeatureFlags.journalV1Enabled, let phaseIIRepository {
                NavigationStack { LifeBoardJournalModuleView(repository: phaseIIRepository) }
            } else { EmptyView() }
        case .note:
            if V2FeatureFlags.knowledgeNotesV1Enabled, let phaseIIRepository {
                NavigationStack { LifeBoardKnowledgeModuleView(repository: phaseIIRepository) }
            } else { EmptyView() }
        case .trackerEntry:
            if V2FeatureFlags.trackersV1Enabled, let phaseIIRepository {
                NavigationStack { LifeBoardTrackRootView(repository: phaseIIRepository) }
            } else { EmptyView() }
        case .mood, .hydration, .medicationEvent, .routineRun:
            if let phaseIIRepository, let trackFoundationRepository {
                NavigationStack {
                    TrackUniversalCaptureView(
                        kind: request.kind,
                        repository: trackFoundationRepository,
                        phaseIIRepository: phaseIIRepository
                    )
                }
            } else { EmptyView() }
        case .timeBlock:
            if let planningRepository {
                NavigationStack { FoundationTimeBlockCaptureHost(repository: planningRepository) }
            } else { EmptyView() }
        }
    }
}

private struct FoundationTimeBlockCaptureHost: View {
    let repository: CoreDataPlanningRepository
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start = Date()
    @State private var minutes = 45.0
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            TextField("What is this time for?", text: $title)
            DatePicker("Starts", selection: $start)
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration: \(Int(minutes)) minutes")
                Slider(value: $minutes, in: 15...240, step: 15)
            }
        }
        .navigationTitle("New time block")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Add") { save() }
                    .disabled(isSaving)
            }
        }
        .alert("Time block wasn’t saved", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if $0 == false { errorMessage = nil } }
        )
    }

    private func save() {
        guard isSaving == false else { return }
        isSaving = true
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let block = InternalTimeBlock(
            title: cleanTitle.isEmpty ? "Focus block" : cleanTitle,
            startAt: start,
            endAt: start.addingTimeInterval(minutes * 60)
        )
        Task {
            do {
                try await repository.saveTimeBlock(block)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private struct FoundationTaskCaptureHost: View {
    @StateObject private var viewModel = PresentationDependencyContainer.shared.makeNewAddTaskViewModel()

    var body: some View {
        SunriseAddTaskSheetView(viewModel: viewModel)
    }
}

private struct FoundationHabitCaptureHost: View {
    @StateObject private var viewModel = PresentationDependencyContainer.shared.makeNewAddHabitViewModel()

    var body: some View {
        SunriseAddHabitSheetView(viewModel: viewModel)
    }
}
