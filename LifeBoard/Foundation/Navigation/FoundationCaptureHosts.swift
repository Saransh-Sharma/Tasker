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
    let onClose: () -> Void
    let onOpenHabitBoard: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            captureContent
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .lifeboardFont(.headline)
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close capture")
            .accessibilityValue(request.kind.title)
            .accessibilityIdentifier("foundation.capture.dismiss")
            .padding(12)
            .zIndex(10)
        }
    }

    @ViewBuilder
    private var captureContent: some View {
        switch request.kind {
        case .task:
            TaskCaptureHost(
                prefilledText: request.prefilledText,
                captureSeed: request.captureSeed
            )
        case .habit:
            HabitCaptureHost()
        case .journal:
            if V2FeatureFlags.journalV1Enabled, let phaseIIRepository {
                NavigationStack {
                    JournalModuleView(
                        repository: phaseIIRepository,
                        initialText: request.captureSeed?.rawText ?? request.prefilledText,
                        startsWithTextComposer: request.captureSeed != nil || request.prefilledText != nil
                    )
                }
            } else { EmptyView() }
        case .note:
            if V2FeatureFlags.knowledgeNotesV1Enabled, let phaseIIRepository {
                NavigationStack {
                    KnowledgeModuleView(
                        repository: phaseIIRepository,
                        startsWithNewNote: true,
                        captureDraftID: request.draftID,
                        initialText: request.captureSeed?.rawText ?? request.prefilledText
                    )
                }
            } else { EmptyView() }
        case .trackerEntry:
            if V2FeatureFlags.trackersV1Enabled, let phaseIIRepository {
                NavigationStack {
                    BehaviorAreaRouteView(
                        repository: phaseIIRepository,
                        initialArea: .trackers,
                        onOpenHabitBoard: onOpenHabitBoard
                    )
                }
            } else { EmptyView() }
        case .mood where V2FeatureFlags.journalParityV1Enabled:
            if let phaseIIRepository, let trackFoundationRepository {
                JournalMoodCaptureView(
                    repository: trackFoundationRepository,
                    phaseIIRepository: phaseIIRepository
                )
            } else { EmptyView() }
        case .mood, .hydration, .medicationEvent, .routineRun:
            if let phaseIIRepository, let trackFoundationRepository {
                NavigationStack {
                    TrackUniversalCaptureView(
                        kind: request.kind,
                        repository: trackFoundationRepository,
                        phaseIIRepository: phaseIIRepository,
                        linkedMutationApplier: routineLinkedMutationApplier
                    )
                }
            } else { EmptyView() }
        case .timeBlock:
            if let planningRepository {
                NavigationStack {
                    TimeBlockCaptureHost(
                        repository: planningRepository,
                        mutationCoordinator: mutationCoordinator,
                        onReceipt: onReceipt
                    )
                }
            } else { EmptyView() }
        }
    }
}

struct TimeBlockCaptureHost: View {
    let repository: CoreDataPlanningRepository
    var mutationCoordinator: MutationCoordinator?
    var onReceipt: (ActionReceipt) -> Void = { _ in }
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
                // Canonical path: apply through the mutation coordinator so
                // this capture produces a receipt with working Undo, like
                // every conversational mutation.
                if let mutationCoordinator {
                    let repository = repository
                    let command = MutationCommand(
                        preview: .init(
                            destination: .plan,
                            summary: "Add time block “\(block.title)”",
                            changes: ["Reserves \(Int(minutes)) minutes starting \(start.formatted(date: .omitted, time: .shortened))"],
                            origin: .directTap
                        ),
                        apply: {
                            try await repository.saveTimeBlock(block)
                            return "Time block “\(block.title)” added"
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
    @StateObject private var viewModel = CompositionRoot.shared.makeNewAddTaskViewModel()
    @State private var provisionalID = UUID()

    var body: some View {
        AddTaskSheetView(viewModel: viewModel)
            .task {
                // Seeded once, and only when the field is still untouched, so a
                // re-render cannot overwrite what the user has since typed.
                if let seed = captureSeed, viewModel.taskName.isEmpty {
                    if let parsed = seed.parsedCapture {
                        viewModel.taskName = parsed.cleanTitle.isEmpty ? seed.rawText : parsed.cleanTitle
                        if let date = parsed.dueDate { viewModel.dueDate = date }
                        if let priority = parsed.priority { viewModel.selectedPriority = priority }
                        if let duration = parsed.duration { viewModel.estimatedDuration = duration }
                        if let repeatPattern = parsed.repeatPattern { viewModel.repeatPattern = repeatPattern }
                        if let project = parsed.projectName { viewModel.selectedProject = project }
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
            }
    }
}

struct HabitCaptureHost: View {
    @StateObject private var viewModel = CompositionRoot.shared.makeNewAddHabitViewModel()

    var body: some View {
        AddHabitSheetView(viewModel: viewModel)
    }
}
