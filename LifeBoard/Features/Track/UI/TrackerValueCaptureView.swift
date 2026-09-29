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

struct TrackerValueCaptureView: View {
    let tracker: TrackerDefinitionValue
    let title: String
    let onSave: (TrackerValue, String?, Date) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var booleanValue: Bool
    @State private var countValue: Int
    @State private var numericValue: Double
    @State private var durationMinutes: Double
    @State private var textValue: String
    @State private var choiceValue: String
    @State private var timestampValue: Date
    @State private var note: String
    @State private var commitPhase: AsyncActionPhase<TrackerCommitReceipt> = .idle
    @State private var saveBloomTrigger = 0

    init(
        tracker: TrackerDefinitionValue,
        entry: TrackerEntryValue? = nil,
        title: String = String(localized: "Log value"),
        onSave: @escaping (TrackerValue, String?, Date) async -> Bool
    ) {
        self.tracker = tracker
        self.title = title
        self.onSave = onSave
        let value = entry?.value
        if case .boolean(let current) = value {
            _booleanValue = State(initialValue: current)
        } else {
            _booleanValue = State(initialValue: entry?.booleanValue ?? true)
        }
        if case .count(let current) = value {
            _countValue = State(initialValue: current)
        } else {
            _countValue = State(initialValue: Int(entry?.numericValue ?? 0))
        }
        switch value {
        case .quantity(let current, _), .rating(let current):
            _numericValue = State(initialValue: current)
        default:
            _numericValue = State(initialValue:
                entry?.numericValue
                    ?? tracker.rangeMin
                    ?? (tracker.effectiveValueType == .rating ? 1 : 0)
            )
        }
        if case .duration(let seconds) = value {
            _durationMinutes = State(initialValue: seconds / 60)
        } else {
            _durationMinutes = State(initialValue: (entry?.numericValue ?? 0) / 60)
        }
        if case .text(let current) = value {
            _textValue = State(initialValue: current)
        } else {
            _textValue = State(initialValue: tracker.effectiveValueType == .text ? entry?.note ?? "" : "")
        }
        if case .choice(let current) = value {
            _choiceValue = State(initialValue: current)
        } else {
            _choiceValue = State(initialValue: tracker.choiceOptions?.first ?? "")
        }
        if case .timestamp(let current) = value {
            _timestampValue = State(initialValue: current)
        } else {
            _timestampValue = State(initialValue: entry?.timestamp ?? Date())
        }
        _note = State(initialValue: tracker.effectiveValueType == .text ? "" : entry?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 28 : 22) {
                        VStack(spacing: 8) {
                            Image(systemName: trackerSymbol)
                                .font(.title2.weight(.semibold))
                                .frame(width: 52, height: 52)
                                .background(
                                    Color(SemanticColorTokens.foundationSurfaceSelected),
                                    in: Circle()
                                )
                            Text(tracker.title)
                                .font(Typography.sectionTitle().weight(.bold))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .lifeboardClayPressBloom(
                            center: .center,
                            trigger: saveBloomTrigger,
                            tint: Color(SemanticColorTokens.foundationSageAccent)
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            valueEditor
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lifeBoardClaySurface(.resting, cornerRadius: 20)

                        if tracker.effectiveValueType != .text {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Note")
                                    .font(.subheadline.weight(.semibold))
                                TextField("Optional", text: $note, prompt: Text("Optional").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                                    .lineLimit(2...5)
                                    .padding(12)
                                    .background(
                                        Color(SemanticColorTokens.foundationSurfaceRecessed),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let minimum = tracker.rangeMin, let maximum = tracker.rangeMax {
                            Label(
                                "Range: \(minimum.formatted())–\(maximum.formatted())",
                                systemImage: "slider.horizontal.below.rectangle"
                            )
                            .font(.caption)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if tracker.effectivePrivacyClass != .standard {
                            Label(
                                tracker.effectivePrivacyClass == .sensitive
                                    ? "Sensitive"
                                    : "Personal",
                                systemImage: "lock.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .safeAreaInset(edge: .bottom) {
                TrackerCommitBar(
                    title: title == "Correct entry" ? String(localized: "Save") : String(localized: "Log"),
                    phase: commitPhase,
                    isEnabled: typedValue != nil,
                    action: commit
                )
                .accessibilityIdentifier("track.tracker.value.commit")
            }
        }
        .presentationCornerRadius(28)
        .interactiveDismissDisabled(isRunning)
    }

    @ViewBuilder
    private var valueEditor: some View {
        switch tracker.effectiveValueType {
        case .boolean:
            HStack(spacing: 12) {
                binaryChoice("Yes", symbol: "checkmark", value: true)
                binaryChoice("No", symbol: "xmark", value: false)
            }
        case .count:
            stepperEditor(
                value: Binding(
                    get: { Double(countValue) },
                    set: { countValue = max(0, Int($0.rounded())) }
                ),
                unit: "count",
                step: 1
            )
        case .quantity:
            numericEditor(value: $numericValue, unit: tracker.unitLabel ?? "amount")
        case .rating:
            ratingEditor
        case .duration:
            stepperEditor(value: $durationMinutes, unit: tracker.unitLabel ?? String(localized: "min"), step: 5)
        case .text:
            TextField("Note", text: $textValue, prompt: Text("Note").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                .lineLimit(4...10)
                .padding(14)
                .background(
                    Color(SemanticColorTokens.foundationSurfaceRecessed),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        case .choice:
            if let choices = tracker.choiceOptions, choices.isEmpty == false {
                LazyVGrid(
                    columns: dynamicTypeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.adaptive(minimum: 120), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(choices, id: \.self) { choice in
                        choiceButton(choice)
                    }
                }
            } else {
                Text("No choices yet.")
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
        case .timestamp:
            DatePicker("When", selection: $timestampValue)
                .datePickerStyle(.compact)
        }
    }

    private var isRunning: Bool {
        if case .running = commitPhase { return true }
        return false
    }

    private func binaryChoice(_ label: String, symbol: String, value: Bool) -> some View {
        let selected = booleanValue == value
        return Button {
            Haptic.pick.play()
            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                booleanValue = value
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                Text(label).font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .lifeBoardClaySurface(selected ? .raised : .well, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func numericEditor(value: Binding<Double>, unit: String) -> some View {
        VStack(spacing: 8) {
            TextField("Value", value: value, format: .number, prompt: Text("Value").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                .padKeyboard(.decimalPad)
                .multilineTextAlignment(.center)
                .font(Typography.hero().weight(.bold))
                .monospacedDigit()
                .accessibilityIdentifier("track.tracker.value.numeric")
            Text(unit)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            Color(SemanticColorTokens.foundationSurfaceRecessed),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func stepperEditor(value: Binding<Double>, unit: String, step: Double) -> some View {
        HStack(spacing: 14) {
            stepButton("minus", enabled: value.wrappedValue >= step) {
                value.wrappedValue = max(0, value.wrappedValue - step)
            }
            VStack(spacing: 3) {
            TextField("Value", value: value, format: .number, prompt: Text("Value").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                    .padKeyboard(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(Typography.hero().weight(.bold))
                    .monospacedDigit()
                    .accessibilityIdentifier("track.tracker.value.numeric")
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            .frame(maxWidth: .infinity)
            stepButton("plus", enabled: true) { value.wrappedValue += step }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.pick.play()
            withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 48, height: 48)
                .lifeBoardClaySurface(.well, cornerRadius: 24)
        }
        .buttonStyle(.plain)
        .disabled(enabled == false)
        .opacity(enabled ? 1 : 0.42)
    }

    private var ratingEditor: some View {
        let lower = tracker.rangeMin ?? 1
        let upper = max(lower + 1, tracker.rangeMax ?? 5)
        return VStack(spacing: 14) {
            Text(numericValue.formatted(.number.precision(.fractionLength(0...1))))
                .font(Typography.hero().weight(.bold))
                .contentTransition(.numericText())
                .monospacedDigit()
            Slider(value: $numericValue, in: lower...upper, step: 1)
                .tint(Color(SemanticColorTokens.foundationSageInk))
            HStack {
                Text(lower.formatted())
                Spacer()
                Text(upper.formatted())
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
    }

    private func choiceButton(_ choice: String) -> some View {
        let selected = choiceValue == choice
        return Button {
            Haptic.pick.play()
            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                choiceValue = choice
            }
        } label: {
            HStack(spacing: 8) {
                Text(choice)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                if selected { Image(systemName: "checkmark.circle.fill") }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .lifeBoardClaySurface(selected ? .raised : .well, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func commit() {
        guard let value = typedValue, isRunning == false else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        commitPhase = .running(progress: nil)
        Task {
            if await onSave(value, trimmedNote.isEmpty ? nil : trimmedNote, timestampValue) {
                commitPhase = .success(receipt: .init())
                saveBloomTrigger += 1
                Haptic.commit.play()
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 360))
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: String(localized: "Couldn’t log value. Try again."),
                    recovery: .retry
                ))
                Haptic.fail.play()
            }
        }
    }

    private var typedValue: TrackerValue? {
        let numericCandidate: Double?
        switch tracker.effectiveValueType {
        case .count: numericCandidate = Double(countValue)
        case .quantity, .rating: numericCandidate = numericValue
        case .duration: numericCandidate = durationMinutes * 60
        default: numericCandidate = nil
        }
        if let numericCandidate {
            guard numericCandidate.isFinite,
                  tracker.rangeMin.map({ numericCandidate >= $0 }) ?? true,
                  tracker.rangeMax.map({ numericCandidate <= $0 }) ?? true else {
                return nil
            }
        }
        switch tracker.effectiveValueType {
        case .boolean: return .boolean(booleanValue)
        case .count: return countValue >= 0 ? .count(countValue) : nil
        case .quantity: return .quantity(numericValue, unit: tracker.unitLabel)
        case .rating: return .rating(numericValue)
        case .duration: return durationMinutes >= 0 ? .duration(durationMinutes * 60) : nil
        case .text:
            let value = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : .text(value)
        case .choice:
            return tracker.choiceOptions?.contains(choiceValue) == true ? .choice(choiceValue) : nil
        case .timestamp: return .timestamp(timestampValue)
        }
    }
}
