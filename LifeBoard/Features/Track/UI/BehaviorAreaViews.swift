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

/// Native Phase 2 Track areas.
///
/// This is intentionally not another root or modal mini-app. It is the
/// Medication/Tracker content mounted by `TrackLens.areas`, deep links, and
/// universal capture. All entry points share this store and the same composer,
/// history, correction, and receipt components.
struct BehaviorNativeAreasView: View {
    enum Area: String, CaseIterable, Identifiable {
        case medication = "Medication"
        case trackers = "Trackers"
        var id: String { rawValue }

        var title: String {
            switch self {
            case .medication: String(localized: "Medication")
            case .trackers: String(localized: "Trackers")
            }
        }
    }

    @State private var store: TrackStore
    @State private var area: Area
    @State private var showsTrackerComposer = false
    @State private var editingTracker: TrackerDefinitionValue?
    @State private var loggingTracker: TrackerDefinitionValue?
    @State private var trackerTemplateSeed: TrackerDefinitionValue?
    @State private var showsTrackerTemplates = false
    @State private var historyTracker: TrackerDefinitionValue?
    @State private var deletingTracker: TrackerDefinitionValue?
    @State private var showsMedicationComposer = false
    @State private var editingMedication: MedicationDefinitionValue?
    @State private var historyMedication: MedicationDefinitionValue?
    @State private var deletingMedication: MedicationDefinitionValue?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        repository: any PhaseIIRepository,
        initialArea: Area = .medication
    ) {
        _store = State(initialValue: TrackStore(repository: repository))
        _area = State(initialValue: initialArea)
    }

    var body: some View {
        ZStack {
            Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: dynamicTypeSize.isAccessibilitySize ? 24 : 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(area == .trackers ? "Trackers" : "Medication")
                            .font(Typography.screenTitle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LensPicker(
                        "Area",
                        selection: $area,
                        values: Area.allCases,
                        identifierPrefix: "track.behavior.area",
                        title: \.title,
                        identifier: { $0.rawValue.lowercased() }
                    )

                    Group {
                        switch area {
                        case .medication: medicationArea
                        case .trackers: trackerArea
                        }
                    }
                    .id(area)
                    .transition(.blurReplace.combined(with: .opacity))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .lifeBoardMotion(.selection, value: area)
        .navigationTitle(area.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .refreshable { await store.load() }
        .alert("Couldn’t update Track", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if $0 == false { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
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
                    store.medicationSchedules.first { $0.medicationID == medication.id }
                }
            ) { medication, schedule in
                Task {
                    await store.saveMedication(medication, schedule: schedule)
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
        .confirmationDialog(
            "Delete tracker?",
            isPresented: Binding(
                get: { deletingTracker != nil },
                set: { if $0 == false { deletingTracker = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete tracker", role: .destructive) {
                guard let tracker = deletingTracker else { return }
                deletingTracker = nil
                Task { await store.deleteTracker(tracker) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its entries are deleted too.")
        }
        .confirmationDialog(
            "Delete medication?",
            isPresented: Binding(
                get: { deletingMedication != nil },
                set: { if $0 == false { deletingMedication = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete medication", role: .destructive) {
                guard let medication = deletingMedication else { return }
                deletingMedication = nil
                Task { await store.deleteMedication(medication) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its dose history is deleted too.")
        }
    }
}

extension BehaviorNativeAreasView {
    private var medicationArea: some View {
        VStack(spacing: 12) {
            areaHeader(
                title: "Medication",
                detail: String(localized: "Doses stay open until you log them."),
                symbol: "pills",
                actionTitle: String(localized: "Add")
            ) {
                editingMedication = nil
                showsMedicationComposer = true
            }
            if store.medications.isEmpty {
                nativeEmpty(
                    String(localized: "No medications"),
                    detail: nil,
                    symbol: "pills"
                )
            } else {
                ForEach(store.medications) { medication in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "pills.fill")
                                .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(medication.name).font(.headline)
                                Text(medication.dosageText ?? String(localized: "No dose"))
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                                Text(medicationDefinitionSummary(medication))
                                    .font(.caption2)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            Spacer()
                            Menu {
                                Button("History", systemImage: "clock.arrow.circlepath") {
                                    historyMedication = medication
                                }
                                Button("Edit", systemImage: "pencil") {
                                    editingMedication = medication
                                    showsMedicationComposer = true
                                }
                                Button("Archive", systemImage: "archivebox") {
                                    Task { await store.archiveMedication(medication) }
                                }
                                Button("Export history", systemImage: "square.and.arrow.up") {
                                    Task { await store.prepareMedicationExport(medication) }
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deletingMedication = medication
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Actions for \(medication.name)")
                        }

                        let event = store.medicationEvents
                            .filter { $0.medicationID == medication.id }
                            .sorted { $0.scheduledAt > $1.scheduledAt }
                            .first
                        if let event, event.status == .scheduled || event.status == .unresolved {
                            HStack(spacing: 8) {
                                medicationResolution(String(localized: "Taken"), event: event, status: .taken)
                                medicationResolution(String(localized: "Skipped"), event: event, status: .skipped)
                                Menu {
                                    medicationResolutionMenu(
                                        String(localized: "Snooze 15 min"),
                                        event: event,
                                        status: .snoozed,
                                        scheduledAt: event.scheduledAt.addingTimeInterval(15 * 60)
                                    )
                                    medicationResolutionMenu(
                                        String(localized: "Move 1 hr later"),
                                        event: event,
                                        status: .rescheduled,
                                        scheduledAt: event.scheduledAt.addingTimeInterval(60 * 60)
                                    )
                                    medicationResolutionMenu(
                                        String(localized: "Leave open"),
                                        event: event,
                                        status: .unresolved,
                                        scheduledAt: event.scheduledAt
                                    )
                                    Button("Pick a time", systemImage: "calendar.badge.clock") {
                                        historyMedication = medication
                                    }
                                } label: {
                                    Label("More", systemImage: "ellipsis")
                                        .frame(minHeight: 44)
                                }
                                .buttonStyle(.lifeBoardChip)
                                .accessibilityLabel("More options for \(medication.name)")
                            }
                        } else {
                            Label("No dose due", systemImage: "checkmark.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(SemanticColorTokens.foundationSageInk))
                        }
                        if let exportURL = store.medicationExportURLs[medication.id] {
                            ShareLink(item: exportURL) {
                                Label("Share export", systemImage: "square.and.arrow.up")
                                    .frame(minHeight: 44)
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                    .nativeBehaviorOpenRow(isLast: store.medications.last?.id == medication.id)
                }
            }
        }
    }

    private var trackerArea: some View {
        VStack(spacing: 12) {
            areaHeader(
                title: "Trackers",
                detail: String(localized: "Every entry is editable."),
                symbol: "chart.bar.doc.horizontal",
                actionTitle: String(localized: "New")
            ) {
                editingTracker = nil
                showsTrackerComposer = true
            }
            Button {
                showsTrackerTemplates = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(Color(SemanticColorTokens.foundationSurfaceSelected), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start from a template")
                            .font(.body.weight(.semibold))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .lifeBoardClaySurface(.well, cornerRadius: 16)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("track.tracker.templates")
            if store.trackers.isEmpty {
                nativeEmpty(
                    String(localized: "No trackers yet"),
                    detail: nil,
                    symbol: "chart.xyaxis.line"
                )
            } else {
                ForEach(store.trackers) { tracker in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: trackerSymbol(tracker.kind))
                                .foregroundStyle(Color(SemanticColorTokens.foundationFocusRing))
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tracker.title).font(.headline)
                                Text(trackerDefinitionSummary(tracker))
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            Spacer()
                            Menu {
                                Button("History", systemImage: "clock.arrow.circlepath") {
                                    historyTracker = tracker
                                }
                                Button("Edit", systemImage: "pencil") {
                                    editingTracker = tracker
                                    showsTrackerComposer = true
                                }
                                Button("Archive", systemImage: "archivebox") {
                                    Task { await store.archiveTracker(tracker) }
                                }
                                Button("Export CSV", systemImage: "tablecells") {
                                    Task { await store.prepareTrackerExport(tracker, format: .csv) }
                                }
                                Button("Export JSON", systemImage: "curlybraces") {
                                    Task { await store.prepareTrackerExport(tracker, format: .json) }
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deletingTracker = tracker
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Actions for \(tracker.title)")
                        }
                        Button("Log") {
                            Haptic.pick.play()
                            loggingTracker = tracker
                        }
                        .buttonStyle(.lifeBoardPrimaryCompact)
                        .tint(Color(SemanticColorTokens.inkPrimary))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("track.tracker.log.\(tracker.id.uuidString)")
                        if let exportURL = store.trackerExportURLs[tracker.id] {
                            ShareLink(item: exportURL) {
                                Label("Share export", systemImage: "square.and.arrow.up")
                                    .frame(minHeight: 44)
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                    .nativeBehaviorOpenRow(isLast: store.trackers.last?.id == tracker.id)
                    .privacySensitive(tracker.effectivePrivacyClass != .standard)
                }
            }
        }
    }

    private func areaHeader(
        title: String,
        detail: String,
        symbol: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Label(title, systemImage: symbol)
                    .font(.title3.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer()
            Button(actionTitle, systemImage: "plus", action: action)
                .buttonStyle(.lifeBoardChip)
                .frame(minHeight: 44)
                .accessibilityIdentifier(title == "Trackers" ? "track.tracker.new" : "track.medication.new")
        }
        .padding(.top, 4)
        .featureHeaderArtwork(title == "Trackers" ? .track : .care)
    }

    private func medicationResolution(
        _ title: String,
        event: MedicationEventValue,
        status: MedicationEventStatus
    ) -> some View {
        Button(title) {
            Task {
                if status == .snoozed {
                    await store.correctMedicationEvent(
                        event,
                        status: .snoozed,
                        scheduledAt: event.scheduledAt,
                        resolvedAt: Date(),
                        note: event.note
                    )
                } else {
                    guard let medication = store.medications.first(where: {
                        $0.id == event.medicationID
                    }) else { return }
                    await store.resolveMedication(medication, event: event, status: status)
                }
            }
        }
        .buttonStyle(.lifeBoardChip)
        .controlSize(.small)
        .frame(minHeight: 44)
    }

    private func medicationResolutionMenu(
        _ title: String,
        event: MedicationEventValue,
        status: MedicationEventStatus,
        scheduledAt: Date
    ) -> some View {
        Button(title) {
            Task {
                await store.correctMedicationEvent(
                    event,
                    status: status,
                    scheduledAt: scheduledAt,
                    resolvedAt: status == .unresolved ? nil : Date(),
                    note: event.note
                )
            }
        }
    }

    private func nativeEmpty(_ title: String, detail: String?, symbol: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            // The system description grey is tuned for white; on the warm
            // canvas it measured 3.3:1.
            if let detail {
                Text(detail).foregroundColor(Color(SemanticColorTokens.inkSecondary))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .nativeBehaviorSurface()
    }
}

/// Route-level rollback for the Phase 2 behavior flagship. The disabled branch
/// restores the previous production Track composer; it does not initialize any
/// of the new native-area state.
struct BehaviorAreaRouteView: View {
    let repository: any PhaseIIRepository
    var initialArea: BehaviorNativeAreasView.Area = .medication
    var onOpenHabitBoard: () -> Void = {}
    var onOpenHealth: () -> Void = {}

    @ViewBuilder
    var body: some View {
        if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
            BehaviorNativeAreasView(
                repository: repository,
                initialArea: initialArea
            )
        } else {
            TrackRootView(
                repository: repository,
                initialModule: initialArea == .trackers ? .trackers : .overview,
                onOpenHabitBoard: onOpenHabitBoard,
                onOpenHealth: onOpenHealth
            )
        }
    }
}

private extension View {
    func nativeBehaviorSurface() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.resting, cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
            }
    }

    /// `isLast` suppresses the trailing hairline — without it every list ended
    /// with a rule under its final row and above nothing, the defect
    /// `OpenRowGroup` exists to prevent. Shares `OpenRowSeparator` so one
    /// definition of that hairline exists.
    func nativeBehaviorOpenRow(isLast: Bool = false) -> some View {
        padding(.horizontal, 4)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { OpenRowSeparator().opacity(isLast ? 0 : 1) }
    }
}
