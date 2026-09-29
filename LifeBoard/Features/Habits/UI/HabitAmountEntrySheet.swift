import SwiftUI
import LifeBoardDomain
import LifeBoardUI

/// What the sheet needs to know about the habit it is editing.
struct HabitAmountEntryContext: Identifiable, Equatable {
    let id: UUID
    let habitID: UUID
    let title: String
    let target: HabitTarget
    let current: Double

    init(habitID: UUID, title: String, target: HabitTarget, current: Double) {
        id = habitID
        self.habitID = habitID
        self.title = title
        self.target = target
        self.current = current
    }
}

/// "Enter amount": the design system's drum bound to today's recorded amount,
/// one commit that sets it, and the host's receipt with Undo afterwards.
/// A ring is for nudging; this is for the moment you already know the number.
struct HabitAmountEntrySheet: View {
    let context: HabitAmountEntryContext
    /// Persists the new *stored* value; returns whether it saved.
    let onSet: (Double) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var display: Double
    @State private var phase: AsyncActionPhase<Double> = .idle

    init(context: HabitAmountEntryContext, onSet: @escaping (Double) async -> Bool) {
        self.context = context
        self.onSet = onSet
        _display = State(initialValue: HabitAmountEntry.displayValue(context.current, target: context.target))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let drum = HabitAmountEntry.drum(for: context.target, current: context.current) {
                    ValueDrum(
                        drum.label,
                        value: $display,
                        in: drum.range,
                        step: drum.step,
                        coarseStep: drum.coarseStep,
                        unit: drum.unit,
                        fractionDigits: drum.fractionDigits,
                        identifier: "habit.amount.entry.value",
                        keyboardPrompt: drum.label
                    )
                    Text(HabitAmountEntry.receipt(title: context.title, value: HabitAmountEntry.storedValue(display, target: context.target), target: context.target))
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .accessibilityIdentifier("habit.amount.entry.preview")
                }
                Spacer(minLength: 0)
                CommitControl(
                    title: commitTitle,
                    runningTitle: String(localized: "Saving…"),
                    successTitle: String(localized: "Set"),
                    phase: phase,
                    isEnabled: change != nil
                ) {
                    commit()
                }
                .accessibilityIdentifier("habit.amount.entry.commit")
            }
            .padding(20)
            .background(Color.lifeboard(.bgCanvas).ignoresSafeArea())
            .navigationTitle(context.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("habit.amount.entry.cancel")
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("habit.amount.entry")
    }

    private var change: HabitAmountChange? {
        HabitAmountEntry.change(from: context.current, toDisplay: display, target: context.target)
    }

    private var commitTitle: String {
        let stored = HabitAmountEntry.storedValue(display, target: context.target)
        let isTimed: Bool = { if case .timed = context.target { return true }; return false }()
        if isTimed { return String(localized: "Set to \(LifeBoardDuration.text(minutes: Int((stored / 60).rounded())))") }
        let unit: String = { if case let .quantitative(_, unit) = context.target { return unit }; return "" }()
        let amount = stored == stored.rounded() ? String(Int(stored)) : String(format: "%.1f", stored)
        return unit.isEmpty ? String(localized: "Set to \(amount)") : String(localized: "Set to \(amount) \(unit)")
    }

    private func commit() {
        guard case .set(let next)? = change else { return }
        phase = .running(progress: nil)
        Task {
            let saved = await onSet(next)
            if saved {
                phase = .success(receipt: next)
                Haptic.commit.play()
                try? await Task.sleep(for: .milliseconds(320))
                dismiss()
            } else {
                phase = .recoverableFailure(AsyncActionFailure(message: String(localized: "Couldn’t save amount."), recovery: .retry))
            }
        }
    }
}
