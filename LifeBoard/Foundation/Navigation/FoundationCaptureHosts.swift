import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct CaptureSheet: View {
    let request: CaptureRequest
    let phaseIIRepository: (any PhaseIIRepository)?
    let planningRepository: CoreDataPlanningRepository?
    let trackFoundationRepository: CoreDataTrackFoundationRepository?
    let routineLinkedMutationApplier: (any RoutineLinkedMutationApplying)?
    var mutationCoordinator: MutationCoordinator?
    var onReceipt: (ActionReceipt) -> Void = { _ in }
    /// A capture that was saved (not cancelled). The shell uses it to clear the
    /// composer draft the capture came from.
    var onCaptureSaved: () -> Void = {}
    let onClose: () -> Void
    let onOpenHabitBoard: () -> Void

    /// Every capture host has exactly one close control.
    ///
    /// Hosts with their own bar (task, habit, time block, mood check-in) close
    /// through it. The rest are module screens pushed into a bare
    /// `NavigationStack`; they get the close in the leading toolbar slot. The old
    /// floating ✕ pinned top-trailing sat directly on the task composer's "Done",
    /// so a tap meant to save discarded the capture instead.
    var body: some View {
        captureContent
    }

    private var closeButton: some View {
        Button {
            onClose()
        } label: {
            Label("Close", systemImage: "xmark")
                .labelStyle(.iconOnly)
        }
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel("Close")
        .accessibilityValue(request.kind.title)
        .accessibilityIdentifier("foundation.capture.dismiss")
    }

    /// What a capture shows when the store it writes to is not available —
    /// a feature switched off, or storage that failed to open. It used to be
    /// `EmptyView()`: a blank sheet with no way to tell what happened and, for
    /// module hosts, no close control either.
    private var unavailableHost: some View {
        NavigationStack {
            VStack {
                StatusSurface(
                    state: .unavailable,
                    title: String(localized: "\(request.kind.title) unavailable"),
                    message: String(localized: "Nothing was saved. Restart the app and try again.")
                )
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { GrainedCanvas() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    closeButton.keyboardShortcut(.cancelAction)
                }
            }
        }
        .escapeCancels(perform: onClose)
        .accessibilityIdentifier("foundation.capture.unavailable")
    }

    private func moduleHost<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { closeButton }
                }
        }
        // Esc while one of the module's fields is focused closes the capture
        // the same way the close button does.
        .escapeCancels(perform: onClose)
    }

    @ViewBuilder
    private var captureContent: some View {
        switch request.kind {
        case .task:
            TaskCaptureHost(
                prefilledText: request.prefilledText,
                captureSeed: request.captureSeed,
                onCreated: onCaptureSaved
            )
        case .habit:
            HabitCaptureHost()
        case .journal:
            if V2FeatureFlags.journalV1Enabled, let phaseIIRepository {
                moduleHost {
                    JournalModuleView(
                        repository: phaseIIRepository,
                        initialText: request.captureSeed?.rawText ?? request.prefilledText,
                        startsWithTextComposer: request.captureSeed != nil || request.prefilledText != nil
                    )
                    .marksJournalContentVisible()
                }
            } else { unavailableHost }
        case .note:
            if V2FeatureFlags.knowledgeNotesV1Enabled, let phaseIIRepository {
                moduleHost {
                    KnowledgeModuleView(
                        repository: phaseIIRepository,
                        startsWithNewNote: true,
                        captureDraftID: request.draftID,
                        initialText: request.captureSeed?.rawText ?? request.prefilledText
                    )
                }
            } else { unavailableHost }
        case .trackerEntry:
            if V2FeatureFlags.trackersV1Enabled, let phaseIIRepository {
                moduleHost {
                    BehaviorAreaRouteView(
                        repository: phaseIIRepository,
                        initialArea: .trackers,
                        onOpenHabitBoard: onOpenHabitBoard
                    )
                }
            } else { unavailableHost }
        case .mood where V2FeatureFlags.journalParityV1Enabled:
            if let phaseIIRepository, let trackFoundationRepository {
                JournalMoodCaptureView(
                    repository: trackFoundationRepository,
                    phaseIIRepository: phaseIIRepository
                )
            } else { unavailableHost }
        case .mood, .hydration, .medicationEvent, .routineRun:
            if let phaseIIRepository, let trackFoundationRepository {
                moduleHost {
                    TrackUniversalCaptureView(
                        kind: request.kind,
                        repository: trackFoundationRepository,
                        phaseIIRepository: phaseIIRepository,
                        linkedMutationApplier: routineLinkedMutationApplier
                    )
                }
            } else { unavailableHost }
        case .timeBlock:
            if let planningRepository {
                NavigationStack {
                    TimeBlockCaptureHost(
                        repository: planningRepository,
                        mutationCoordinator: mutationCoordinator,
                        onReceipt: onReceipt
                    )
                }
            } else { unavailableHost }
        }
    }
}

struct TimeBlockCaptureHost: View {
    let repository: CoreDataPlanningRepository
    var mutationCoordinator: MutationCoordinator?
    var onReceipt: (ActionReceipt) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start = TimeBlockDraft.defaultStart(on: Date())
    @State private var minutes = TimeBlockDraft.defaultMinutes
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            TextField("Title", text: $title, prompt: Text("Title").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
            DatePicker("Starts", selection: $start)
            TimeBlockDurationField(minutes: $minutes)
        }
        // The warm canvas behind the grouped list, not the system's pure white
        // (light) or pure black (dark) grouped background.
        .scrollContentBackground(.hidden)
        .background { GrainedCanvas() }
        .navigationTitle("New time block")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Add") { save() }
                    .disabled(isSaving || TimeBlockDraft.isValid(title: title) == false)
            }
        }
        .alert("Couldn’t save time block", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? String(localized: "Try again."))
        }
        // Esc with the title field focused does what Cancel does.
        .escapeCancels { dismiss() }
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
            title: cleanTitle.isEmpty ? String(localized: "Focus") : cleanTitle,
            startAt: start,
            endAt: start.addingTimeInterval(minutes * 60)
        )
        Task {
            do {
                // Canonical path: apply through the mutation coordinator so
                // this capture produces a receipt with working Undo, like
                // every conversational mutation.
                if let mutationCoordinator {
                    let repository = repository
                    let command = MutationCommand(
                        preview: .init(
                            destination: .plan,
                            summary: String(localized: "Add time block “\(block.title)”"),
                            changes: [String(localized: "\(TimeBlockDraft.durationLabel(minutes: minutes)) at \(start.formatted(date: .omitted, time: .shortened))")],
                            origin: .directTap
                        ),
                        apply: {
                            try await repository.saveTimeBlock(block)
                            return String(localized: "Added “\(block.title)”")
                        },
                        undo: {
                            try await repository.deleteTimeBlock(id: block.id)
                        }
                    )
                    let preview = await mutationCoordinator.prepare(command)
                    let receipt = try await mutationCoordinator.apply(previewID: preview.id)
                    onReceipt(receipt)
                } else {
                    try await repository.saveTimeBlock(block)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

struct TaskCaptureHost: View {
    /// Raw text of an already-captured item being reviewed, if any.
    var prefilledText: String?
    var captureSeed: CaptureSeed? = nil
    var onCreated: () -> Void = {}
    @StateObject private var viewModel = CompositionRoot.shared.makeNewAddTaskViewModel()
    @State private var provisionalID = UUID()

    var body: some View {
        AddTaskSheetView(viewModel: viewModel)
            .task {
                // Seeded once, and only when the field is still untouched, so a
                // re-render cannot overwrite what the user has since typed.
                if let seed = captureSeed, viewModel.taskName.isEmpty {
                    if let parsed = seed.parsedCapture {
                        viewModel.applyCaptureSeed(parsed, rawText: seed.rawText)
                    } else {
                        viewModel.taskName = seed.rawText
                    }
                    return
                }
                if let prefilledText, viewModel.taskName.isEmpty {
                    viewModel.taskName = prefilledText
                    return
                }
                guard captureSeed == nil,
                      prefilledText == nil,
                      viewModel.taskName.isEmpty,
                      let recovered = PendingCaptureInbox.read()
                        .filter({ $0.source == "in-app" && $0.isProvisional })
                        .max(by: { ($0.provisionalAt ?? $0.createdAt) < ($1.provisionalAt ?? $1.createdAt) })
                else { return }
                provisionalID = recovered.id
                viewModel.taskName = recovered.rawText
            }
            .onChange(of: viewModel.taskName) { _, newValue in
                let meaningful = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard meaningful.count >= 3, viewModel.isTaskCreated == false else { return }
                PendingCaptureInbox.upsert(PendingCapture(
                    id: provisionalID,
                    rawText: newValue,
                    source: "in-app",
                    provisionalAt: Date()
                ))
            }
            .onChange(of: viewModel.isTaskCreated) { _, created in
                guard created else { return }
                IntentDonations.taskAdded(title: viewModel.taskName)
                PendingCaptureInbox.remove(ids: [provisionalID])
                onCreated()
            }
    }
}

struct HabitCaptureHost: View {
    @StateObject private var viewModel = CompositionRoot.shared.makeNewAddHabitViewModel()

    var body: some View {
        AddHabitSheetView(viewModel: viewModel)
    }
}
