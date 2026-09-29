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

/// Shared with the Track foundation root so fasting is not reachable
/// only through the legacy Track tree.
struct FastingComposer: View {
    let onStart: (TimeInterval?, [TimeInterval]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var usesTarget = false
    @State private var targetHours = 12.0
    @State private var reminderEnabled = false

    var body: some View {
        ComposerScaffold(
            title: String(localized: "Start fast"),
            confirmTitle: String(localized: "Start"),
            identifier: "track.fasting.composer",
            onConfirm: {
                let target = usesTarget ? targetHours * 3_600 : nil
                let reminders = usesTarget && reminderEnabled ? [max(0, targetHours * 3_600 - 3_600)] : []
                onStart(target, reminders)
                dismiss()
            }
        ) {
            FastingTargetSection(
                usesTarget: $usesTarget,
                targetHours: $targetHours,
                reminderEnabled: $reminderEnabled
            )
        }
    }
}

private struct FastingTargetSection: View {
    @Binding var usesTarget: Bool
    @Binding var targetHours: Double
    @Binding var reminderEnabled: Bool

    var body: some View {
        ComposerSection(String(localized: "Target")) {
            Toggle("Set a target", isOn: $usesTarget)
                .toggleStyle(.lifeBoardClay)
            if usesTarget {
                ComposerDial(
                    String(localized: "Target"),
                    value: $targetHours,
                    in: 1...48,
                    step: 1,
                    unit: String(localized: "hr"),
                    diameter: 140
                )
                Toggle("Remind 1 hr before", isOn: $reminderEnabled)
                    .toggleStyle(.lifeBoardClay)
            }
        }
    }
}

/// Complete fasting history with the recorded meaning of every session —
/// planned, early, cancelled, or corrected — plus the same 15-minute
/// correction and undo affordances the inline card offers.
/// Shared with the Track foundation root so fasting is not reachable
/// only through the legacy Track tree.
struct FastingHistoryView: View {
    let sessions: [FastingSessionValue]
    let activeReceipt: (UUID) -> TrackCorrectionReceipt?
    let onUndo: (TrackCorrectionReceipt) async -> Void
    let onCorrect: (FastingSessionValue, TimeInterval, TimeInterval) async -> Void
    /// Sets exact start and end times, as the Fasting destination's history
    /// does. Nil hides "Edit times…".
    var onSetTimes: ((FastingSessionValue, Date, Date?) async -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var editingTimesSession: FastingSessionValue?

    private var finished: [FastingSessionValue] {
        sessions.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if finished.isEmpty {
                    StatusSurface(
                        state: .noRecord,
                        title: String(localized: "No past fasts"),
                        message: ""
                    )
                } else {
                    ForEach(finished) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(meaningTitle(session.completionKind))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color(SemanticColorTokens.foundationSurfaceSelected), in: Capsule())
                            }
                            HStack {
                                Text(durationText(session))
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                                    .monospacedDigit()
                                Spacer()
                                Menu {
                                    if onSetTimes != nil {
                                        Button("Edit times…", systemImage: "clock") { editingTimesSession = session }
                                    }
                                    Section("Start") {
                                        Button("15 min earlier") { Task { await onCorrect(session, -15 * 60, 0) } }
                                        Button("15 min later") { Task { await onCorrect(session, 15 * 60, 0) } }
                                    }
                                    Section("End") {
                                        Button("15 min earlier") { Task { await onCorrect(session, 0, -15 * 60) } }
                                        Button("15 min later") { Task { await onCorrect(session, 0, 15 * 60) } }
                                    }
                                    if let receipt = activeReceipt(session.id) {
                                        Button("Undo correction", systemImage: "arrow.uturn.backward") {
                                            Task { await onUndo(receipt) }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Correct times")
                            }
                            if let note = session.note, note.isEmpty == false {
                                Text(note).font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .lifeBoardFormSurface()
            .navigationTitle("Fasting history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editingTimesSession) { session in
                FastingTimesEditor(session: session) { startedAt, endedAt in
                    Task { await onSetTimes?(session, startedAt, endedAt) }
                }
            }
        }
    }

    private func meaningTitle(_ kind: FastingCompletionKind?) -> String {
        switch kind {
        case .planned: String(localized: "Completed")
        case .early: String(localized: "Ended early")
        case .cancelled: String(localized: "Cancelled")
        case .corrected: String(localized: "Corrected")
        case nil: String(localized: "Logged")
        }
    }

    private func durationText(_ session: FastingSessionValue) -> String {
        let elapsedText = LifeBoardDuration.text(seconds: session.elapsed())
        if let target = session.targetDuration {
            let targetText = LifeBoardDuration.text(seconds: target)
            return String(localized: "\(elapsedText) of \(targetText)")
        }
        return elapsedText
    }
}

// MARK: - Journal module
