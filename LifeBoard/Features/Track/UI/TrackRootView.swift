import AVFAudio
import CoreSpotlight
import Foundation
import LifeBoardDomain
import LocalAuthentication
import LifeBoardPersistence
import Observation
import PhotosUI
import LifeBoardDomain
import Speech
import SwiftUI
import LifeBoardTranscription
import UIKit
import UniformTypeIdentifiers
import LifeBoardContracts

struct TrackRootView: View {
    enum Module: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case habits = "Habits"
        case trackers = "Trackers"
        case journal = "Journal"
        case notes = "Notes"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: String(localized: "Overview")
            case .habits: String(localized: "Habits")
            case .trackers: String(localized: "Trackers")
            case .journal: String(localized: "Journal")
            case .notes: String(localized: "Notes")
            }
        }
    }

    @State private var store: TrackStore
    @State private var module: Module = .overview
    @State private var showsMood = false
    @State private var mood: JournalMood = .none
    @State private var showsTrackerComposer = false
    @State private var editingTracker: TrackerDefinitionValue?
    @State private var loggingTracker: TrackerDefinitionValue?
    @State private var trackerTemplateSeed: TrackerDefinitionValue?
    @State private var showsTrackerTemplates = false
    @State private var historyTracker: TrackerDefinitionValue?
    @State private var showsMedicationComposer = false
    @State private var editingMedication: MedicationDefinitionValue?
    @State private var historyMedication: MedicationDefinitionValue?
    @State private var deletingTracker: TrackerDefinitionValue?
    @State private var deletingMedication: MedicationDefinitionValue?
    @State private var showsFastingComposer = false
    @State private var reviewsFastCompletion = false
    @State private var showsFastingHistory = false
    let onOpenHabitBoard: () -> Void
    private let onOpenHealth: () -> Void
    @Environment(PresentationPreferences.self) private var preferences
    // Light-only `palette(for:)` painted light-appearance ink (#6F6252)
    // on the dark canvas; the palette has to follow the appearance.
    @Environment(\.colorScheme) private var colorScheme

    init(
        repository: any PhaseIIRepository,
        initialModule: Module = .overview,
        onOpenHabitBoard: @escaping () -> Void = {},
        onOpenHealth: @escaping () -> Void = {}
    ) {
        _store = State(initialValue: TrackStore(repository: repository))
        _module = State(initialValue: initialModule)
        self.onOpenHabitBoard = onOpenHabitBoard
        self.onOpenHealth = onOpenHealth
    }

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)
        ZStack {
            AtmosphereView(
                daypart: preferences.resolvedDaypart(),
                requestedTier: preferences.renderingTier,
                comfortProfile: preferences.comfortProfile
            )
            .ignoresSafeArea()
            VStack(spacing: 0) {
                modulePicker(palette: palette)
                Group {
                    switch module {
                    case .overview: overview(palette: palette)
                    case .habits: habitsBridge(palette: palette)
                    case .trackers: trackers(palette: palette)
                    case .journal:
                        JournalModuleView(repository: store.repository)
                            .marksJournalContentVisible()
                    case .notes:
                        KnowledgeModuleView(repository: store.repository)
                    }
                }
            }
        }
        .foregroundStyle(palette.color(for: .foreground))
        .navigationTitle("Track")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .alert("Couldn’t update Track", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("Try again") { Task { await store.load() } }
            Button("OK", role: .cancel) {}
        } message: { Text(store.errorMessage ?? "") }
        .sheet(isPresented: $showsMood) {
            JournalMoodDialSheet(selectedMood: $mood, offersReasons: false) { energy, _ in
                Task {
                    await store.saveMood(mood, energy: energy)
                    // After the save: the dial no longer plays this itself.
                    (store.errorMessage == nil ? Haptic.commit : Haptic.fail).play()
                }
            }
        }
        .sheet(isPresented: $showsTrackerComposer, onDismiss: {
            editingTracker = nil
            trackerTemplateSeed = nil
        }) {
            TrackerComposer(
                existing: editingTracker,
                seed: trackerTemplateSeed
            ) { tracker, sensitiveHomeAuthorized in
                await store.saveTracker(
                    tracker,
                    sensitiveHomeAuthorized: sensitiveHomeAuthorized
                )
                return store.errorMessage == nil
            }
        }
        .sheet(isPresented: $showsTrackerTemplates) {
            TrackerTemplatePicker { template in
                trackerTemplateSeed = template.instantiate()
                showsTrackerTemplates = false
                showsTrackerComposer = true
            }
        }
        .sheet(item: $loggingTracker) { tracker in
            TrackerValueCaptureView(tracker: tracker) { value, note, timestamp in
                await store.log(tracker, value: value, note: note, at: timestamp)
                loggingTracker = nil
                return store.errorMessage == nil
            }
        }
        .sheet(item: $historyTracker) { tracker in
            TrackerHistoryView(
                tracker: tracker,
                entries: store.trackerEntries.filter { $0.trackerID == tracker.id },
                activeReceipt: { store.activeCorrection(domain: .tracker, sourceID: $0) },
                onUndo: { await store.undoCorrection($0) },
                onCorrect: { (
                    entry: TrackerEntryValue,
                    value: TrackerValue,
                    note: String?
                ) async -> Bool in
                    await store.correct(entry, tracker: tracker, value: value, note: note)
                    return store.errorMessage == nil
                }
            )
        }
        .sheet(isPresented: $showsMedicationComposer, onDismiss: { editingMedication = nil }) {
            MedicationComposer(
                existing: editingMedication,
                existingSchedule: editingMedication.flatMap { medication in
                    store.medicationSchedules.first(where: { $0.medicationID == medication.id })
                }
            ) { medication, schedule in
                Task {
                    await store.saveMedication(medication, schedule: schedule)
                    // A dose window with no notification is a window the user
                    // has to remember unaided, which defeats the point.
                    await PermissionPrimingCoordinator.shared.offerAfterReward(
                        kind: .notifications,
                        trigger: "medication_scheduled"
                    )
                }
            }
        }
        .sheet(item: $historyMedication) { medication in
            MedicationHistoryView(
                medication: medication,
                events: store.medicationEvents.filter { $0.medicationID == medication.id },
                activeReceipt: { store.activeCorrection(domain: .medication, sourceID: $0) },
                onUndo: { await store.undoCorrection($0) },
                onCorrect: { event, status, scheduledAt, resolvedAt, note in
                    await store.correctMedicationEvent(
                        event,
                        status: status,
                        scheduledAt: scheduledAt,
                        resolvedAt: resolvedAt,
                        note: note
                    )
                }
            )
        }
        .sheet(isPresented: $showsFastingComposer) {
            FastingComposer { target, reminderOffsets in
                Task {
                    await store.toggleFast(target: target, reminderOffsets: reminderOffsets)
                    // Connecting nutrition powers the "last meal" fasting suggestion;
                    // fasting itself is never written to Apple Health.
                    await HealthCoordinator.shared.jitCoordinator.offerConnectAfterReward(
                        leadDomain: .nutrition,
                        trigger: "fasting_start"
                    )
                }
            }
        }
        .sheet(isPresented: $showsFastingHistory) {
            FastingHistoryView(
                sessions: store.fastingSessions,
                activeReceipt: { store.activeCorrection(domain: .fasting, sourceID: $0) },
                onUndo: { await store.undoCorrection($0) },
                onCorrect: { session, startDelta, endDelta in
                    await store.correctFast(session, startDelta: startDelta, endDelta: endDelta)
                }
            )
        }
        .confirmationDialog(
            "End fast?",
            isPresented: $reviewsFastCompletion,
            titleVisibility: .visible
        ) {
            Button("End fast") {
                Task { await store.toggleFast(target: nil) }
            }
            Button("Cancel fast", role: .destructive) {
                Task { await store.cancelFast() }
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("A cancelled fast stays in history.")
        }
        .confirmationDialog(
            "Delete tracker?",
            isPresented: Binding(get: { deletingTracker != nil }, set: { if !$0 { deletingTracker = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete tracker", role: .destructive) {
                guard let tracker = deletingTracker else { return }
                deletingTracker = nil
                Task { await store.deleteTracker(tracker) }
            }
            Button("Cancel", role: .cancel) { deletingTracker = nil }
        } message: {
            Text("Its entries are deleted too. Archive it to keep them.")
        }
        .confirmationDialog(
            "Delete medication?",
            isPresented: Binding(get: { deletingMedication != nil }, set: { if !$0 { deletingMedication = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete medication", role: .destructive) {
                guard let medication = deletingMedication else { return }
                deletingMedication = nil
                Task { await store.deleteMedication(medication) }
            }
            Button("Cancel", role: .cancel) { deletingMedication = nil }
        } message: {
            Text("Its dose history is deleted too. Archive it to keep it.")
        }
    }
}

extension TrackRootView {
    private func modulePicker(palette: DaypartPalette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableModules) { item in
                    Button(item.title) { module = item }
                        .buttonStyle(.lifeBoardChip)
                        .tint(module == item ? palette.color(for: .foreground) : palette.color(for: .foregroundSecondary))
                        .accessibilityAddTraits(module == item ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    private var availableModules: [Module] {
        var values: [Module] = [.overview, .habits]
        if V2FeatureFlags.trackersV1Enabled { values.append(.trackers) }
        if V2FeatureFlags.journalV1Enabled { values.append(.journal) }
        if V2FeatureFlags.knowledgeNotesV1Enabled { values.append(.notes) }
        return values
    }

    private func overview(palette: DaypartPalette) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button { showsMood = true } label: {
                        overviewTile(
                            title: String(localized: "Mood & energy"),
                            value: store.checkIns.first.map { $0.mood.title } ?? String(localized: "Check in"),
                            symbol: "face.smiling",
                            palette: palette
                        )
                    }
                    Button(action: onOpenHealth) {
                        overviewTile(
                            title: String(localized: "Health"),
                            value: healthSummary,
                            symbol: "heart.text.clipboard",
                            palette: palette
                        )
                    }
                }
                .buttonStyle(.plain)

                careCard(palette: palette)
                fastingCard(palette: palette)
                dueTrackersCard(palette: palette)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .refreshable { await store.load() }
    }

    private var healthSummary: String {
        switch store.healthStore.snapshot.availability {
        case .notRequested: String(localized: "Connect")
        case .unavailable: String(localized: "No data")
        case .available:
            if let steps = store.healthStore.snapshot.steps { String(localized: "\(Int(steps)) steps") } else { String(localized: "No data") }
        }
    }

    private func careCard(palette: DaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Medication", systemImage: "pills")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Add") { showsMedicationComposer = true }
            }
            if store.medications.isEmpty {
                Text("No medications")
                    .font(.subheadline)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            } else {
                ForEach(store.medications) { medication in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(medication.name).font(.headline)
                            if let dosage = medication.dosageText { Text(dosage).font(.caption) }
                        }
                        Spacer()
                        Menu("Log dose") {
                            Button("Taken", systemImage: "checkmark.circle") { Task { await store.resolveMedication(medication, status: .taken) } }
                            Button("Snoozed", systemImage: "clock.arrow.circlepath") { Task { await store.resolveMedication(medication, status: .snoozed) } }
                            Button("Skipped", systemImage: "forward.end") { Task { await store.resolveMedication(medication, status: .skipped) } }
                            Divider()
                            Button("History", systemImage: "clock.arrow.circlepath") { historyMedication = medication }
                            Button("Edit", systemImage: "pencil") {
                                editingMedication = medication
                                showsMedicationComposer = true
                            }
                            Button("Archive medication", systemImage: "archivebox", role: .destructive) {
                                Task { await store.archiveMedication(medication) }
                            }
                            Button("Delete medication", systemImage: "trash", role: .destructive) {
                                deletingMedication = medication
                            }
                        }
                    }
                    .padding(12)
                    .background(palette.color(for: .layerOne).opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(18)
        .lifeBoardPaperCard()
    }

    private func fastingCard(palette: DaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(palette.color(for: .layerOne).opacity(0.45), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.activeFast == nil ? "Fasting timer" : "Timer running")
                        .font(.headline)
                    if let activeFast = store.activeFast {
                        Text(Self.duration(activeFast.elapsed()))
                            .font(.caption)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                }
                Spacer()
                Button {
                    if store.activeFast == nil { showsFastingComposer = true }
                    else { reviewsFastCompletion = true }
                } label: {
                    Text(store.activeFast == nil ? "Start" : "End")
                        .foregroundStyle(Color(SemanticColorTokens.foundationSurfaceSolid))
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .tint(palette.color(for: .foreground))
            }
            if store.fastingSessions.contains(where: { $0.endedAt != nil }) {
                Button {
                    showsFastingHistory = true
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            ForEach(store.fastingSessions.filter { $0.endedAt != nil }.prefix(3)) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.weight(.medium))
                        Text(Self.duration(session.elapsed())).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                    Spacer()
                    Menu {
                        Section("Start") {
                            Button("15 min earlier") { Task { await store.correctFast(session, startDelta: -15 * 60) } }
                            Button("15 min later") { Task { await store.correctFast(session, startDelta: 15 * 60) } }
                        }
                        Section("End") {
                            Button("15 min earlier") { Task { await store.correctFast(session, endDelta: -15 * 60) } }
                            Button("15 min later") { Task { await store.correctFast(session, endDelta: 15 * 60) } }
                        }
                        if let receipt = store.activeCorrection(domain: .fasting, sourceID: session.id) {
                            Button("Undo correction", systemImage: "arrow.uturn.backward") {
                                Task { await store.undoCorrection(receipt) }
                            }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Correct times")
                }
                .padding(.top, 8)
            }
        }
        .padding(18)
        .lifeBoardPaperCard()
    }

    private func dueTrackersCard(palette: DaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Trackers").font(.title3.weight(.semibold))
                Spacer()
                Button("Add tracker") { showsTrackerComposer = true }
            }
            if store.trackers.isEmpty {
                Text("No trackers yet")
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            } else {
                ForEach(store.trackers.prefix(4)) { tracker in
                    trackerRow(tracker, palette: palette)
                }
            }
        }
        .padding(18)
        .lifeBoardPaperCard()
    }

    private func trackerRow(_ tracker: TrackerDefinitionValue, palette: DaypartPalette) -> some View {
        HStack {
            Image(systemName: trackerSymbol(tracker.kind)).frame(width: 28)
            VStack(alignment: .leading) {
                Text(tracker.title).font(.headline)
                Text(tracker.kind.trackDisplayName).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Spacer()
            Button("Log") {
                loggingTracker = tracker
            }
            .buttonStyle(.lifeBoardChip)
            Menu {
                Button("History", systemImage: "clock.arrow.circlepath") { historyTracker = tracker }
                Button("Edit", systemImage: "pencil") {
                    editingTracker = tracker
                    showsTrackerComposer = true
                }
                Button("Archive", systemImage: "archivebox", role: .destructive) {
                    Task { await store.archiveTracker(tracker) }
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    deletingTracker = tracker
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("More actions for \(tracker.title)")
        }
        .frame(minHeight: 44)
    }

    private func trackers(palette: DaypartPalette) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
                    Text("Trackers").font(.title2.weight(.semibold))
                    Spacer()
                    Button("New", systemImage: "plus") { showsTrackerComposer = true }
                }
                ForEach(store.trackers) { tracker in
                    VStack(alignment: .leading, spacing: 12) {
                        trackerRow(tracker, palette: palette)
                        let recent = store.trackerEntries.filter { $0.trackerID == tracker.id }.prefix(7)
                        if !recent.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(Array(recent)) { entry in
                                    Capsule()
                                        .fill(palette.color(for: .celestialPrimary))
                                        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: CGFloat(8 + (entry.numericValue ?? 1) * 3))
                                        .accessibilityLabel("Entry \(entry.numericValue ?? (entry.booleanValue == true ? 1 : 0))")
                                }
                            }
                            .frame(height: 40, alignment: .bottom)
                        }
                    }
                    .padding(16)
                    .lifeBoardPaperCard()
                    // `DESIGN.md`: "Scrolling is not a quiet moment." Journal
                    // had no scroll entrance on any of its lists.
                    .lifeBoardScrollEntrance()
                }
            }
            .padding(20)
        }
    }
}
