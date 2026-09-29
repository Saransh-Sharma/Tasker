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

struct TrackerTemplatePicker: View {
    let onSelect: (TrackerTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(TrackerTemplate.allCases) { template in
                            Button {
                                Haptic.pick.play()
                                onSelect(template)
                            } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: symbol(for: template))
                                        .font(.title3.weight(.semibold))
                                        .frame(width: 42, height: 42)
                                        .background(
                                            Color(SemanticColorTokens.foundationSurfaceSelected),
                                            in: Circle()
                                        )
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack(spacing: 7) {
                                            Text(template.title)
                                                .font(.headline)
                                            if template.isHealthLike {
                                                Text("Private")
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 3)
                                                    .background(
                                                        Color(SemanticColorTokens.foundationSurfaceRecessed),
                                                        in: Capsule()
                                                    )
                                            }
                                        }
                                        Text(template.detail)
                                            .font(.subheadline)
                                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                                        .padding(.top, 13)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                                .lifeBoardClaySurface(.resting, cornerRadius: 20)
                                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 48 : 32)
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .presentationCornerRadius(28)
    }

    private func symbol(for template: TrackerTemplate) -> String {
        switch template {
        case .pain: "waveform.path.ecg"
        case .symptoms: "text.bubble"
        case .caffeine: "cup.and.saucer.fill"
        case .reading: "book.pages.fill"
        case .spending: "creditcard.fill"
        case .screenTime: "hourglass"
        }
    }
}

struct TrackerCommitBar: View {
    let title: String
    let phase: AsyncActionPhase<TrackerCommitReceipt>
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if case .recoverableFailure(let failure) = phase {
                Label(failure.message, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            CommitControl(
                title: title,
                runningTitle: String(localized: "Saving…"),
                successTitle: String(localized: "Saved"),
                phase: phase,
                isEnabled: isEnabled,
                action: action
            )
        }
        .padding(12)
        .lifeBoardSystemGlass(
            .regular,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

struct TrackerComposer: View {
    let onSave: (TrackerDefinitionValue, Bool) async -> Bool
    private let existing: TrackerDefinitionValue?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var title = ""
    @State private var kind: TrackerKind = .boolean
    @State private var unit = ""
    @State private var target = 1.0
    @State private var rangeEnabled = false
    @State private var rangeMinimum = 0.0
    @State private var rangeMaximum = 10.0
    @State private var aggregation: TrackerAggregation = .latest
    @State private var privacyClass: TrackerPrivacyClass = .personal
    @State private var isHomeEligible = false
    @State private var choiceOptionsText = ""
    @State private var weekdays = Set(1...7)
    @State private var reminderEnabled = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var commitPhase: AsyncActionPhase<TrackerCommitReceipt> = .idle
    @State private var typeBloomTrigger = 0
    @FocusState private var titleIsFocused: Bool

    init(
        existing: TrackerDefinitionValue? = nil,
        seed: TrackerDefinitionValue? = nil,
        onSave: @escaping (TrackerDefinitionValue, Bool) async -> Bool
    ) {
        self.existing = existing
        self.onSave = onSave
        let source = existing ?? seed
        _title = State(initialValue: source?.title ?? "")
        _kind = State(initialValue: source?.kind ?? .boolean)
        _unit = State(initialValue: source?.unitLabel ?? "")
        _target = State(initialValue: source?.targetValue ?? 1)
        _rangeEnabled = State(initialValue: source?.rangeMin != nil || source?.rangeMax != nil)
        _rangeMinimum = State(initialValue: source?.rangeMin ?? 0)
        _rangeMaximum = State(initialValue: source?.rangeMax ?? 10)
        _aggregation = State(initialValue: source?.effectiveAggregation ?? .latest)
        _privacyClass = State(initialValue: source?.effectivePrivacyClass ?? .personal)
        _isHomeEligible = State(initialValue: source?.isHomeEligible ?? false)
        _choiceOptionsText = State(initialValue: (source?.choiceOptions ?? []).joined(separator: "\n"))
        _weekdays = State(initialValue: source?.schedule ?? Set(1...7))
        let minutes = source?.reminderMinutes
        _reminderEnabled = State(initialValue: minutes != nil)
        if let minutes {
            _reminderTime = State(initialValue: Calendar.current.date(
                bySettingHour: minutes / 60,
                minute: minutes % 60,
                second: 0,
                of: Date()
            ) ?? Date())
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 28 : 24) {
                        trackerBuilderSection(
                            String(localized: "Name"),
                            detail: nil
                        ) {
                            TextField("Tracker name", text: $title, prompt: Text("Tracker name").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                                .focused($titleIsFocused)
                                .textFieldStyle(TokenTextFieldStyle(isFocused: titleIsFocused))
                                .submitLabel(.next)
                                .accessibilityIdentifier("track.tracker.name")

                            Text("Type")
                                .font(.subheadline.weight(.semibold))
                            ScrollView(.horizontal) {
                                HStack(spacing: 12) {
                                    ForEach(TrackerKind.allCases, id: \.self) { value in
                                        trackerKindButton(value)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .scrollIndicators(.hidden)
                            .lifeboardClayPressBloom(
                                center: .center,
                                trigger: typeBloomTrigger,
                                tint: Color(SemanticColorTokens.foundationApricotAccent)
                            )

                    if kind == .quantity || kind == .duration {
                                labeledField(String(localized: "Unit")) {
                                    TextField(kind == .duration ? "minutes, hours…" : "mL, km, ₹…", text: $unit)
                                        .multilineTextAlignment(.trailing)
                                }
                    }
                    if numericKinds.contains(kind) {
                                labeledField(String(localized: "Target (optional)")) {
                                    TextField("Target", value: $target, format: .number, prompt: Text("Target").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                                        .padKeyboard(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                }
                                Toggle("Set a range", isOn: $rangeEnabled)
                                    .tint(Color(SemanticColorTokens.foundationSageInk))
                        if rangeEnabled {
                                    ViewThatFits {
                                        HStack(spacing: 12) { rangeField(String(localized: "Minimum"), value: $rangeMinimum); rangeField(String(localized: "Maximum"), value: $rangeMaximum) }
                                        VStack(spacing: 12) { rangeField(String(localized: "Minimum"), value: $rangeMinimum); rangeField(String(localized: "Maximum"), value: $rangeMaximum) }
                                    }
                            }
                        }
                    if kind == .choice {
                        TextField(
                            "One per line",
                            text: $choiceOptionsText,
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                                .padding(12)
                                .background(Color(SemanticColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("Add at least 2 choices.")
                            .font(.caption)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }

                            labeledField(String(localized: "Summary")) {
                                Picker("Summary", selection: $aggregation) {
                                    ForEach(availableAggregations, id: \.self) {
                                        Text($0.displayName).tag($0)
                                    }
                                }
                                .labelsHidden()
                            }
                        }

                        trackerBuilderSection(
                            String(localized: "Privacy"),
                            detail: nil
                        ) {
                            HStack(spacing: 8) {
                                ForEach(TrackerPrivacyClass.allCases, id: \.self) { value in
                                    privacyButton(value)
                                }
                            }
                            Toggle("Show on Home", isOn: $isHomeEligible)
                                .tint(Color(SemanticColorTokens.foundationSageInk))
                                .frame(minHeight: 44)
                            privacyExplanation
                        }

                        trackerBuilderSection(
                            String(localized: "Schedule"),
                            detail: nil
                        ) {
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    ForEach(1...7, id: \.self) { weekday in
                                        weekdayButton(weekday)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .scrollIndicators(.hidden)
                            Toggle("Remind me", isOn: $reminderEnabled)
                                .tint(Color(SemanticColorTokens.foundationSageInk))
                                .frame(minHeight: 44)
                            if reminderEnabled {
                                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(existing == nil ? "New tracker" : "Edit tracker")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: kind) { _, newKind in
                if availableAggregations.contains(aggregation) == false {
                    aggregation = defaultAggregation(for: newKind)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction) }
            }
            .safeAreaInset(edge: .bottom) {
                TrackerCommitBar(
                    title: existing == nil ? String(localized: "Add tracker") : String(localized: "Save"),
                    phase: commitPhase,
                    isEnabled: isInvalid == false,
                    action: commit
                )
                .accessibilityIdentifier("track.tracker.commit")
            }
        }
        .presentationCornerRadius(28)
        .interactiveDismissDisabled(isRunning)
    }

    private var isRunning: Bool {
        if case .running = commitPhase { return true }
        return false
    }

    private func trackerBuilderSection<Content: View>(
        _ heading: String,
        detail: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(heading).font(Typography.sectionTitle())
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.resting, cornerRadius: 20)
    }

    private func trackerKindButton(_ value: TrackerKind) -> some View {
        let selected = value == kind
        return Button {
            guard selected == false else { return }
            Haptic.pick.play()
            typeBloomTrigger += 1
            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                kind = value
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: trackerKindSymbol(value))
                    .font(.body.weight(.semibold))
                Text(trackerKindTitle(value))
                    .font(.subheadline.weight(selected ? .bold : .semibold))
            }
            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            .padding(12)
            .frame(width: 112, height: 74, alignment: .leading)
            .lifeBoardClaySurface(selected ? .raised : .well, cornerRadius: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        selected
                            ? Color.lifeboard(.borderStrong)
                            : Color(SemanticColorTokens.foundationHairline),
                        lineWidth: selected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("track.tracker.kind.\(value.rawValue)")
    }

    private func privacyButton(_ value: TrackerPrivacyClass) -> some View {
        let selected = value == privacyClass
        return Button {
            Haptic.pick.play()
            withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                privacyClass = value
                if value == .sensitive { isHomeEligible = false }
            }
        } label: {
            Text(value.displayName)
                .font(.footnote.weight(selected ? .bold : .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    selected
                        ? Color(SemanticColorTokens.foundationSurfaceSelected)
                        : Color.clear,
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var privacyExplanation: some View {
        let text = switch privacyClass {
        case .standard: String(localized: "Shown where you choose, including Home.")
        case .personal: String(localized: "Private unless you show it on Home.")
        case .sensitive: isHomeEligible
            ? String(localized: "Shown on Home only. Hidden from widgets and notifications.")
            : String(localized: "Hidden from Home, widgets, notifications and exports.")
        }
        Label(text, systemImage: privacyClass == .sensitive ? "lock.fill" : "hand.raised.fill")
            .font(.caption)
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func weekdayButton(_ weekday: Int) -> some View {
        let selected = weekdays.contains(weekday)
        return Button {
            Haptic.pick.play()
            withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                if selected { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
            }
        } label: {
            Text(Calendar.current.veryShortStandaloneWeekdaySymbols[weekday - 1])
                .font(.caption.weight(.bold))
                .frame(width: 44, height: 44)
                .background(
                    selected
                        ? Color(SemanticColorTokens.foundationSurfaceSelected)
                        : Color(SemanticColorTokens.foundationSurfaceRecessed),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.subheadline)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(Color(SemanticColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rangeField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            TextField(label, value: value, format: .number)
                .padKeyboard(.decimalPad)
                .textFieldStyle(TokenTextFieldStyle())
        }
    }

    private func trackerKindTitle(_ kind: TrackerKind) -> String {
        switch kind {
        case .boolean: String(localized: "Yes / no")
        case .count: String(localized: "Count")
        case .quantity: String(localized: "Amount")
        case .rating: String(localized: "Rating")
        case .duration: String(localized: "Duration")
        case .text: String(localized: "Note")
        case .choice: String(localized: "Choice")
        case .timestamp: String(localized: "Time")
        }
    }

    private func trackerKindSymbol(_ kind: TrackerKind) -> String {
        switch kind {
        case .boolean: "checkmark.circle"
        case .count: "number.circle"
        case .quantity: "ruler"
        case .rating: "slider.horizontal.3"
        case .duration: "timer"
        case .text: "text.cursor"
        case .choice: "list.bullet.circle"
        case .timestamp: "clock.badge.checkmark"
        }
    }

    private func commit() {
        guard isInvalid == false, isRunning == false else { return }
        let calendar = Calendar.current
        let reminderMinutes = reminderEnabled
            ? calendar.component(.hour, from: reminderTime) * 60 + calendar.component(.minute, from: reminderTime)
            : nil
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let definition = TrackerDefinitionValue(
            id: existing?.id ?? UUID(),
            title: trimmedTitle,
            kind: kind,
            unitLabel: trimmedUnit.isEmpty ? nil : trimmedUnit,
            targetValue: numericKinds.contains(kind) ? target : nil,
            schedule: weekdays,
            reminderMinutes: reminderMinutes,
            isArchived: existing?.isArchived ?? false,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            valueType: kind,
            rangeMin: rangeEnabled && numericKinds.contains(kind) ? rangeMinimum : nil,
            rangeMax: rangeEnabled && numericKinds.contains(kind) ? rangeMaximum : nil,
            aggregation: aggregation,
            privacyClass: privacyClass,
            isHomeEligible: isHomeEligible,
            choiceOptions: kind == .choice ? choiceOptions : nil
        )
        commitPhase = .running(progress: nil)
        Task {
            if await onSave(definition, privacyClass == .sensitive && isHomeEligible) {
                commitPhase = .success(receipt: .init())
                Haptic.commit.play()
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 360))
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: String(localized: "Couldn’t save tracker. Try again."),
                    recovery: .retry
                ))
                Haptic.fail.play()
            }
        }
    }

    private var numericKinds: Set<TrackerKind> {
        [.count, .quantity, .rating, .duration]
    }

    private var choiceOptions: [String] {
        choiceOptionsText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .reduce(into: [String]()) { result, option in
                if result.contains(option) == false { result.append(option) }
            }
    }

    private var availableAggregations: [TrackerAggregation] {
        switch kind {
        case .boolean: [.latest, .count]
        case .count, .quantity, .duration: [.latest, .sum, .average, .minimum, .maximum, .count]
        case .rating: [.latest, .average, .minimum, .maximum, .count]
        case .text, .choice, .timestamp: [.latest, .count]
        }
    }

    private func defaultAggregation(for kind: TrackerKind) -> TrackerAggregation {
        switch kind {
        case .count, .quantity, .duration: .sum
        case .rating: .average
        case .boolean, .text, .choice, .timestamp: .latest
        }
    }

    private var isInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || weekdays.isEmpty
            || (rangeEnabled && rangeMinimum > rangeMaximum)
            || (kind == .choice && choiceOptions.count < 2)
    }
}
