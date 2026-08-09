import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// The shell's overlay layer plus the become-interactive announcement, lifted
/// out of `FoundationShell.body`.
///
/// Kept as one modifier in the original position so the chain's order is
/// unchanged — these sit between the sheet chain and the lifecycle observers,
/// and overlay order decides what draws on top.
/// The shell's presentation chain, lifted out of `FoundationShell.body`.
///
/// Every sheet, the scanner cover and the router alert, kept together and in the
/// original position. Presentation-modifier order decides which surface wins
/// when two are requested in the same runloop turn, so this block is moved
/// verbatim rather than regrouped.
struct ShellSheets: ViewModifier {
    let runtime: FoundationCoordinator
    let phaseIIRepository: any PhaseIIRepository
    let planningRepository: CoreDataPlanningRepository
    let trackFoundationRepository: CoreDataTrackFoundationRepository
    let routineLinkedMutationApplier: any RoutineLinkedMutationApplying
    let lifeBoardMutationCoordinator: MutationCoordinator
    let lifeThreadComposer: LifeThreadComposerCoordinator
    let capturePresentationBinding: Binding<Bool>
    let onAddCardToHome: (DashboardWidgetKind, WidgetSizePreset, Destination) -> Void
    let router: AppRouter
    @Binding var lifeBoardActionReceipt: ActionReceipt?
    @Binding var homeCardPlacementRequest: HomeCardPlacementRequest?
    @Binding var showsComposerAudioCapture: Bool
    @Binding var composerAudioStore: JournalStore?
    @Binding var showsDocumentScanner: Bool
    @Binding var scannedDraft: ScannedDraft?
    var composerIsFocused: FocusState<Bool>.Binding

    func body(content: Content) -> some View {
        @Bindable var router = router
        return content
            .sheet(isPresented: capturePresentationBinding) {
                PresentationScaffold(mode: .editor, readableWidth: 720) {
                    if let request = runtime.captureRouter.activeRequest {
                        CaptureSheet(
                            request: request,
                            phaseIIRepository: phaseIIRepository,
                            planningRepository: planningRepository,
                            trackFoundationRepository: trackFoundationRepository,
                            routineLinkedMutationApplier: routineLinkedMutationApplier,
                            mutationCoordinator: lifeBoardMutationCoordinator,
                            onReceipt: { receipt in lifeBoardActionReceipt = receipt },
                            onClose: { runtime.captureRouter.cancelActiveRequest() },
                            onOpenHabitBoard: {
                                runtime.captureRouter.completeActiveRequest()
                                runtime.router.push(.habitBoard, in: .track)
                            }
                        )
                    }
                }
            }
            .sheet(item: $homeCardPlacementRequest) { request in
                PresentationScaffold(mode: .utility, readableWidth: 640) {
                    if let descriptor = DefaultDashboardWidgetRegistry.shared.descriptor(for: request.kind) {
                        HomeCardPlacementSheet(
                            descriptor: descriptor,
                            destination: request.destination,
                            onCancel: { homeCardPlacementRequest = nil },
                            onAdd: { size in
                                homeCardPlacementRequest = nil
                                onAddCardToHome(request.kind, size, request.destination)
                            }
                        )
                    }
                }
            }
            .sheet(isPresented: $showsComposerAudioCapture, onDismiss: {
                if lifeThreadComposer.state == .recording { lifeThreadComposer.focus() }
            }) {
                PresentationScaffold(mode: .editor, readableWidth: 720) {
                    if let store = composerAudioStore {
                        NavigationStack {
                            JournalAudioCapture(
                            onSave: { path, duration, transcription in
                                if store.allDays.isEmpty { await store.load() }
                                return await store.appendAudio(
                                    relativePath: path,
                                    duration: duration,
                                    transcription: transcription
                                )
                            },
                            onTranscription: { path, text in
                                await store.updateAudioTranscription(relativePath: path, text: text)
                            },
                            onDiscard: { path in
                                await store.discardAudio(relativePath: path)
                            }
                        )
                            .navigationTitle("Voice note")
                            .navigationBarTitleDisplayMode(.inline)
                        }
                        .presentationDetents([.medium, .large])
                    } else {
                        // Without this the sheet presented completely empty with no
                        // way to tell whether it was broken or still working. The
                        // store is built synchronously in `beginComposerAudioCapture`,
                        // so reaching here means the state write had not landed when
                        // the sheet body first evaluated — recoverable, so it rebuilds
                        // the store rather than stranding the recording the user came
                        // here to make.
                        NavigationStack {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Preparing voice capture…")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .navigationTitle("Voice note")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") { showsComposerAudioCapture = false }
                                }
                            }
                            .task {
                                guard composerAudioStore == nil else { return }
                                composerAudioStore = JournalStore(repository: phaseIIRepository)
                            }
                        }
                        .presentationDetents([.medium, .large])
                        .accessibilityLabel("Preparing voice capture")
                    }
                }
            }
            .fullScreenCover(isPresented: $showsDocumentScanner) {
                DocumentScannerView(
                    completion: { result in
                        showsDocumentScanner = false
                        switch result {
                        case .success(let draft): scannedDraft = draft
                        case .failure(let error):
                            router.activeAlert = .init(
                                title: "Couldn’t read scan",
                                message: error.localizedDescription
                            )
                        }
                    },
                    cancellation: { showsDocumentScanner = false }
                )
                .ignoresSafeArea()
            }
            .sheet(item: $scannedDraft) { draft in
                PresentationScaffold(mode: .editor, readableWidth: 720) {
                    ScanReviewView(
                        draft: draft,
                        onUse: { text in
                            lifeThreadComposer.draftText = text
                            lifeThreadComposer.focus()
                            scannedDraft = nil
                            composerIsFocused.wrappedValue = true
                        },
                        onCancel: { scannedDraft = nil }
                    )
                }
            }
            .sheet(item: Binding(
                get: { PermissionPrimingCoordinator.shared.pendingPrompt },
                set: { if $0 == nil { PermissionPrimingCoordinator.shared.decline() } }
            )) { prompt in
                PermissionPrimingSheet(
                    prompt: prompt,
                    onGrant: { domains in
                        Task { await PermissionPrimingCoordinator.shared.grant(healthDomains: domains) }
                    },
                    onDecline: { PermissionPrimingCoordinator.shared.decline() }
                )
            }
            .alert(item: $router.activeAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
    }
}

struct ShellOverlays: ViewModifier {
    let runtime: FoundationCoordinator
    let homeViewModel: HomeViewModel
    let dashboardLayoutRepository: any DashboardLayoutRepository
    let planningRepository: CoreDataPlanningRepository
    let visualFixture: VisualFixture?
    let onDismissRescue: () -> Void
    @Binding var homeCardReceipt: HomeCardPlacementReceipt?

    func body(content: Content) -> some View {
        content
            .task {
                // Announce once the shell is genuinely on screen so first run can be
                // presented. Previously this depended on the legacy Home controller
                // reaching its tasks face, which never happens when the adaptive Home
                // is the root — onboarding simply never appeared.
                NotificationCenter.default.post(name: .lifeboardShellDidBecomeInteractive, object: nil)
            }
            .overlay(alignment: .top) {
                if let receipt = homeCardReceipt {
                    HomeCardPlacementReceiptView(
                        receipt: receipt,
                        onView: {
                            homeCardReceipt = nil
                            runtime.router.activateRoot(.home)
                        },
                        onUndo: {
                            homeCardReceipt = nil
                            Task { try? await dashboardLayoutRepository.saveHome(receipt.transaction.undoLayout) }
                        },
                        onDismiss: { homeCardReceipt = nil }
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(20)
                }
            }
            .overlay {
                if homeViewModel.overdueRescueLaunchCoordinator.presentation != nil {
                    OverdueRescuePresentationHost(
                        coordinator: homeViewModel.overdueRescueLaunchCoordinator,
                        projectsByID: Dictionary(uniqueKeysWithValues: homeViewModel.projects.map { ($0.id, $0) }),
                        bottomInset: 0,
                        onRetry: {
                            guard let context = homeViewModel.overdueRescueLaunchCoordinator.presentation else { return }
                            homeViewModel.launchOverdueRescue(context)
                        },
                        onUpdate: { request, completion in
                            Task { @MainActor in
                                homeViewModel.updateTask(taskID: request.id, request: request, completion: completion)
                            }
                        },
                        onDelete: { taskID, completion in
                            Task { @MainActor in
                                homeViewModel.deleteTask(taskID: taskID, scope: .single, completion: completion)
                            }
                        },
                        onRestore: { task, completion in
                            Task { @MainActor in
                                homeViewModel.restoreDeletedTaskSnapshot(task, completion: completion)
                            }
                        },
                        onApply: { mutations, completion in
                            Task { @MainActor in
                                homeViewModel.applyRescuePlan(mutations: mutations, completion: completion)
                            }
                        },
                        onUndo: { completion in
                            Task { @MainActor in homeViewModel.undoRescueRun(completion: completion) }
                        },
                        onSavePlanningMetadata: { metadata, completion in
                            Task {
                                do {
                                    try await planningRepository.saveTaskMetadata(metadata)
                                    completion(.success(()))
                                } catch {
                                    completion(.failure(error))
                                }
                            }
                        },
                        onTrack: { action, metadata in
                            homeViewModel.trackHomeInteraction(action: action, metadata: metadata)
                        },
                        onDismiss: onDismissRescue
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.992)))
                    .zIndex(90)
                }
            }
            .overlay {
                if let visualFixture, visualFixture.state != .populated {
                    VisualFixtureSurface(fixture: visualFixture)
                        .zIndex(100)
                }
            }
    }
}

struct ComposerToolStagger: ViewModifier {
    let index: Int
    let reduceMotion: Bool

    private static let perChipDelay: Double = 0.028
    private static let maximumDelay: Double = 0.22

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.82, anchor: .bottomLeading)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                guard reduceMotion == false else {
                    appeared = true
                    return
                }
                let delay = min(Double(index) * Self.perChipDelay, Self.maximumDelay)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78).delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct InteractiveGlassModifier: ViewModifier {
    let isEnabled: Bool
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.lifeBoardSystemGlass(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                interactive: true
            )
        } else {
            content
        }
    }
}

/// The one-shot lift a dock icon makes when its root becomes the current one.
///
/// A `matchedGeometryEffect` already slides the selected well between slots, but
/// the icon itself stayed inert, so arriving somewhere read as the background
/// moving rather than the destination responding. The phases run once per
/// selection — rest, lift, settle — so the icon acknowledges the tap and then
/// gets out of the way, rather than looping and pulling the eye back down.
struct DockLift: ViewModifier {
    let isSelected: Bool
    let reduceMotion: Bool

    enum Phase: CaseIterable {
        case rest, lift, settle

        var scale: Double {
            switch self {
            case .rest, .settle: 1
            case .lift: 1.18
            }
        }

        var offsetY: Double {
            switch self {
            case .rest, .settle: 0
            case .lift: -3
            }
        }
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.phaseAnimator(Phase.allCases, trigger: isSelected) { view, phase in
                view
                    .scaleEffect(phase.scale)
                    .offset(y: phase.offsetY)
            } animation: { phase in
                switch phase {
                case .rest: .easeOut(duration: 0.01)
                case .lift: .spring(response: 0.22, dampingFraction: 0.55)
                case .settle: .spring(response: 0.32, dampingFraction: 0.78)
                }
            }
        }
    }
}
