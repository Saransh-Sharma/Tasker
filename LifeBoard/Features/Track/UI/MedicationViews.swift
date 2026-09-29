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

struct MedicationComposer: View {
    let onSave: (MedicationDefinitionValue, MedicationScheduleValue) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dosage = ""
    @State private var instructions = ""
    @State private var form = ""
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var refillEnabled = false
    @State private var refillQuantity = 30.0
    @State private var refillRemaining = 30.0
    @State private var refillThreshold = 5.0
    @State private var recordsLastRefill = false
    @State private var lastRefilledAt = Date()
    @State private var windowStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var windowEnd = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var weekdays = Set(1...7)
    @State private var reminderEnabled = true
    private let existing: MedicationDefinitionValue?
    private let existingSchedule: MedicationScheduleValue?

    init(
        existing: MedicationDefinitionValue? = nil,
        existingSchedule: MedicationScheduleValue? = nil,
        onSave: @escaping (MedicationDefinitionValue, MedicationScheduleValue) -> Void
    ) {
        self.existing = existing
        self.existingSchedule = existingSchedule
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _dosage = State(initialValue: existing?.dosageText ?? "")
        _instructions = State(initialValue: existing?.instructions ?? "")
        _form = State(initialValue: existing?.formRaw ?? "")
        _hasStartDate = State(initialValue: existing?.startDate != nil)
        _startDate = State(initialValue: existing?.startDate ?? Date())
        _hasEndDate = State(initialValue: existing?.endDate != nil)
        _endDate = State(initialValue: existing?.endDate ?? Date())
        let hasRefill = existing?.refillQuantity != nil
            || existing?.refillRemaining != nil
            || existing?.refillThreshold != nil
        _refillEnabled = State(initialValue: hasRefill)
        _refillQuantity = State(initialValue: existing?.refillQuantity ?? 30)
        _refillRemaining = State(initialValue: existing?.refillRemaining ?? existing?.refillQuantity ?? 30)
        _refillThreshold = State(initialValue: existing?.refillThreshold ?? 5)
        _recordsLastRefill = State(initialValue: existing?.lastRefilledAt != nil)
        _lastRefilledAt = State(initialValue: existing?.lastRefilledAt ?? Date())
        let startMinutes = existingSchedule?.windowStartMinutes ?? 8 * 60
        let endMinutes = existingSchedule?.windowEndMinutes ?? 9 * 60
        _windowStart = State(initialValue: Calendar.current.date(
            bySettingHour: startMinutes / 60, minute: startMinutes % 60, second: 0, of: Date()
        ) ?? Date())
        _windowEnd = State(initialValue: Calendar.current.date(
            bySettingHour: endMinutes / 60, minute: endMinutes % 60, second: 0, of: Date()
        ) ?? Date())
        _weekdays = State(initialValue: existingSchedule?.weekdays ?? Set(1...7))
        _reminderEnabled = State(initialValue: existingSchedule?.reminderEnabled ?? true)
    }

    var body: some View {
        ComposerScaffold(
            title: existing == nil ? String(localized: "Add medication") : String(localized: "Edit medication"),
            confirmTitle: String(localized: "Save"),
            isConfirmEnabled: isInvalid == false,
            isPrivacySensitive: true,
            identifier: "track.medication.composer",
            onConfirm: commit
        ) {
            MedicationIdentitySection(
                name: $name,
                form: $form,
                dosage: $dosage,
                instructions: $instructions
            )
            MedicationActiveDatesSection(
                hasStartDate: $hasStartDate,
                startDate: $startDate,
                hasEndDate: $hasEndDate,
                endDate: $endDate
            )
            MedicationRefillSection(
                refillEnabled: $refillEnabled,
                refillQuantity: $refillQuantity,
                refillRemaining: $refillRemaining,
                refillThreshold: $refillThreshold,
                recordsLastRefill: $recordsLastRefill,
                lastRefilledAt: $lastRefilledAt
            )
            MedicationScheduleSection(
                windowStart: $windowStart,
                windowEnd: $windowEnd,
                weekdays: $weekdays,
                reminderEnabled: $reminderEnabled
            )
        }
    }

    private func commit() {
        let trimmedForm = form.trimmingCharacters(in: .whitespacesAndNewlines)
        let medication = MedicationDefinitionValue(
            id: existing?.id ?? UUID(),
            name: name,
            dosageText: dosage.isEmpty ? nil : dosage,
            instructions: instructions.isEmpty ? nil : instructions,
            healthCorrelationID: existing?.healthCorrelationID,
            isArchived: existing?.isArchived ?? false,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            formRaw: trimmedForm.isEmpty ? nil : trimmedForm,
            startDate: hasStartDate ? Calendar.current.startOfDay(for: startDate) : nil,
            endDate: hasEndDate ? Calendar.current.date(
                bySettingHour: 23,
                minute: 59,
                second: 59,
                of: endDate
            ) : nil,
            refillQuantity: refillEnabled ? refillQuantity : nil,
            refillRemaining: refillEnabled ? refillRemaining : nil,
            refillThreshold: refillEnabled ? refillThreshold : nil,
            lastRefilledAt: refillEnabled && recordsLastRefill ? lastRefilledAt : nil
        )
        let calendar = Calendar.current
        let startMinutes = calendar.component(.hour, from: windowStart) * 60 + calendar.component(.minute, from: windowStart)
        let endMinutes = calendar.component(.hour, from: windowEnd) * 60 + calendar.component(.minute, from: windowEnd)
        onSave(medication, .init(
            id: existingSchedule?.id ?? UUID(),
            medicationID: medication.id,
            windowStartMinutes: startMinutes,
            windowEndMinutes: endMinutes,
            weekdays: weekdays,
            reminderEnabled: reminderEnabled
        ))
        dismiss()
    }

    private var isInvalid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || weekdays.isEmpty
            || windowEnd <= windowStart
            || (hasStartDate && hasEndDate && Calendar.current.startOfDay(for: endDate) < Calendar.current.startOfDay(for: startDate))
            || (refillEnabled && (
                refillQuantity.isFinite == false
                    || refillRemaining.isFinite == false
                    || refillThreshold.isFinite == false
                    || refillQuantity < 0
                    || refillRemaining < 0
                    || refillThreshold < 0
                    || refillRemaining > refillQuantity
            ))
    }
}

private struct MedicationIdentitySection: View {
    @Binding var name: String
    @Binding var form: String
    @Binding var dosage: String
    @Binding var instructions: String

    var body: some View {
        ComposerSection(
            String(localized: "Medication"),
            footer: String(localized: "For your records only. Not medical advice.")
        ) {
            ComposerField(String(localized: "Name"), prompt: String(localized: "Medication name"), text: $name, identifier: "track.medication.name")
            ComposerField(String(localized: "Form"), prompt: String(localized: "Tablet, capsule, liquid…"), text: $form)
            ComposerField(String(localized: "Dose"), prompt: String(localized: "Optional"), text: $dosage)
            ComposerField(String(localized: "Instructions"), prompt: String(localized: "Optional"), text: $instructions, shape: .prose(lineLimit: 2...5))
        }
    }
}

private struct MedicationActiveDatesSection: View {
    @Binding var hasStartDate: Bool
    @Binding var startDate: Date
    @Binding var hasEndDate: Bool
    @Binding var endDate: Date

    var body: some View {
        ComposerSection(String(localized: "Dates")) {
            Toggle("Start date", isOn: $hasStartDate)
                .toggleStyle(.lifeBoardClay)
            if hasStartDate {
                DateCapsuleRow(String(localized: "Starts"), selection: $startDate, components: [.date])
            }
            Toggle("End date", isOn: $hasEndDate)
                .toggleStyle(.lifeBoardClay)
            if hasEndDate {
                DateCapsuleRow(
                    String(localized: "Ends"),
                    selection: $endDate,
                    components: [.date],
                    minimum: hasStartDate ? startDate : nil
                )
            }
        }
    }
}

private struct MedicationRefillSection: View {
    @Binding var refillEnabled: Bool
    @Binding var refillQuantity: Double
    @Binding var refillRemaining: Double
    @Binding var refillThreshold: Double
    @Binding var recordsLastRefill: Bool
    @Binding var lastRefilledAt: Date

    var body: some View {
        ComposerSection(String(localized: "Refills")) {
            Toggle("Track refills", isOn: $refillEnabled)
                .toggleStyle(.lifeBoardClay)
            if refillEnabled {
                ComposerNumberField(String(localized: "Refill quantity"), value: $refillQuantity)
                ComposerNumberField(String(localized: "Remaining"), value: $refillRemaining)
                ComposerNumberField(String(localized: "Remind me at"), value: $refillThreshold)
                Toggle("Last refill date", isOn: $recordsLastRefill)
                    .toggleStyle(.lifeBoardClay)
                if recordsLastRefill {
                    DateCapsuleRow(String(localized: "Last refilled"), selection: $lastRefilledAt, components: [.date])
                }
            }
        }
    }
}

private struct MedicationScheduleSection: View {
    @Binding var windowStart: Date
    @Binding var windowEnd: Date
    @Binding var weekdays: Set<Int>
    @Binding var reminderEnabled: Bool

    var body: some View {
        ComposerSection(String(localized: "Schedule")) {
            DateCapsuleRow(String(localized: "From"), selection: $windowStart, components: [.time])
            DateCapsuleRow(String(localized: "Until"), selection: $windowEnd, components: [.time])
            MedicationWeekdayRail(weekdays: $weekdays)
            Toggle("Remind me", isOn: $reminderEnabled)
                .toggleStyle(.lifeBoardClay)
        }
    }
}

/// Weekdays as clay chips.
///
/// The previous row painted a bare `Capsule` behind selected days, so selection
/// was carried by tint alone — invisible under Differentiate Without Colour.
/// Clay depth carries it here instead.
private struct MedicationWeekdayRail: View {
    @Binding var weekdays: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Days")
                .font(.lifeboard(.meta))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { weekday in
                    let isOn = weekdays.contains(weekday)
                    Button {
                        Haptic.pick.play()
                        if isOn { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                    } label: {
                        Text(Calendar.current.veryShortStandaloneWeekdaySymbols[weekday - 1])
                            .font(.lifeboard(isOn ? .bodyStrong : .body))
                            .foregroundStyle(Color(isOn
                                ? SemanticColorTokens.inkPrimary
                                : SemanticColorTokens.inkSecondary))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .lifeBoardClaySurface(
                                isOn ? .raised : .well,
                                cornerRadius: Radius.pill
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                }
            }
            .lifeBoardMotion(.selection, value: weekdays)
        }
    }
}

struct MedicationHistoryView: View {
    let medication: MedicationDefinitionValue
    let events: [MedicationEventValue]
    let activeReceipt: (UUID) -> TrackCorrectionReceipt?
    let onUndo: (TrackCorrectionReceipt) async -> Void
    let onCorrect: (MedicationEventValue, MedicationEventStatus, Date, Date?, String?) async -> Void
    @State private var correcting: MedicationEventValue?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    StatusSurface(state: .noRecord, title: String(localized: "No doses yet"), message: "")
                } else {
                    List(events.sorted(by: { $0.scheduledAt > $1.scheduledAt })) { event in
                        Button { correcting = event } label: {
                            HStack {
                                Label(event.status.trackDisplayName, systemImage: statusSymbol(event.status))
                                Spacer()
                                Text(event.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(Color.lifeboard(.textSecondary))
                            }
                            .frame(minHeight: 44)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if let receipt = activeReceipt(event.id) {
                                Button("Undo", systemImage: "arrow.uturn.backward") {
                                    Task { await onUndo(receipt) }
                                }
                                .tint(Color(SemanticColorTokens.foundationSageInk))
                            }
                        }
                        // Undo was a leading swipe and nothing else — out of
                        // reach of a mouse, a trackpad click and VoiceOver.
                        .contextMenu {
                            if let receipt = activeReceipt(event.id) {
                                Button("Undo correction", systemImage: "arrow.uturn.backward") {
                                    Task { await onUndo(receipt) }
                                }
                            }
                        }
                        .accessibilityActions {
                            if let receipt = activeReceipt(event.id) {
                                Button("Undo correction") { Task { await onUndo(receipt) } }
                            }
                        }
                    }
                }
            }
            .navigationTitle(medication.name)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $correcting) { event in
                MedicationCorrectionView(event: event) { status, scheduledAt, resolvedAt, note in
                    await onCorrect(event, status, scheduledAt, resolvedAt, note)
                    correcting = nil
                }
            }
        }
    }

    private func statusSymbol(_ status: MedicationEventStatus) -> String {
        switch status {
        case .taken: "checkmark.circle"
        case .skipped: "forward.end"
        case .snoozed, .rescheduled: "clock.arrow.circlepath"
        case .scheduled: "calendar"
        case .unresolved: "questionmark.circle"
        }
    }
}

private struct MedicationCorrectionView: View {
    let event: MedicationEventValue
    let onSave: (MedicationEventStatus, Date, Date?, String?) async -> Void
    @State private var status: MedicationEventStatus
    @State private var scheduledAt: Date
    @State private var resolvedAt: Date
    @State private var note: String
    @Environment(\.dismiss) private var dismiss

    init(
        event: MedicationEventValue,
        onSave: @escaping (MedicationEventStatus, Date, Date?, String?) async -> Void
    ) {
        self.event = event
        self.onSave = onSave
        _status = State(initialValue: event.status)
        _scheduledAt = State(initialValue: event.scheduledAt)
        _resolvedAt = State(initialValue: event.resolvedAt ?? Date())
        _note = State(initialValue: event.note ?? "")
    }

    var body: some View {
        ComposerScaffold(
            title: String(localized: "Edit dose"),
            confirmTitle: String(localized: "Save"),
            identifier: "track.medication.correction",
            onConfirm: {
                Task {
                    await onSave(status, scheduledAt, resolvedAt, note)
                    dismiss()
                }
            }
        ) {
            ComposerSection(String(localized: "Status")) {
                OptionRail(
                    "Status",
                    selection: $status,
                    values: MedicationEventStatus.allCases,
                    identifierPrefix: "track.medication.status",
                    title: { $0.trackDisplayName },
                    showsLabel: false
                )
            }
            ComposerSection(String(localized: "Times")) {
                DateCapsuleRow(String(localized: "Scheduled"), selection: $scheduledAt)
                if status != .scheduled && status != .unresolved {
                    DateCapsuleRow(String(localized: "Logged"), selection: $resolvedAt)
                }
            }
            ComposerSection(String(localized: "Note")) {
                ComposerField(
                    String(localized: "Note"),
                    prompt: String(localized: "Optional"),
                    text: $note,
                    shape: .prose(lineLimit: 2...5),
                    showsLabel: false
                )
            }
        }
    }
}
