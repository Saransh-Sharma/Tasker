import SwiftUI
import UIKit

/// The post-session prompt. Energy and note are owned by the root so a lens
/// switch does not silently discard half-typed input.
struct PlanFocusReflectionCard: View {
    let store: PlanStore
    let receipt: FocusExecutionReceipt
    @Binding var focusReflectionEnergy: Int
    @Binding var focusReflectionNote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("How did that feel?")
                        .font(.headline)
                    Text(
                        "\(PlanSectionCopy.duration(receipt.actualFocusedDuration)) focused · "
                            + "\(PlanSectionCopy.duration(receipt.targetDuration)) planned"
                    )
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer()
                Button {
                    store.dismissFocusReflection()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip reflection")
            }
            // Was `.pickerStyle(.segmented)` — the stock grey segmented control,
            // which is system chrome rather than clay. `OptionRail` is the
            // design system's equivalent and carries the same semantics: one
            // selection, a per-value accessibility identifier, and reflow at
            // accessibility text sizes.
            OptionRail(
                "Energy after focus",
                selection: $focusReflectionEnergy,
                values: Array(1...5),
                identifierPrefix: "plan.focus.reflection.energy",
                title: { "\($0)" }
            )
            .accessibilityValue("\(focusReflectionEnergy) out of 5")
            TextField("A short note, if useful", text: $focusReflectionNote, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("plan.focus.reflection.note")
            VStack(alignment: .leading, spacing: 10) {
                if receipt.interruptionCount > 0 {
                    Label(
                        "\(receipt.interruptionCount) interruption\(receipt.interruptionCount == 1 ? "" : "s")",
                        systemImage: "bell.slash"
                    )
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                CommitControl(
                    title: "Save reflection",
                    runningTitle: "Saving reflection",
                    successTitle: "Reflection saved",
                    phase: store.focusReflectionCommitPhase
                ) {
                    let energy = focusReflectionEnergy
                    let note = focusReflectionNote
                    Task {
                        await store.saveFocusReflection(energy: energy, note: note)
                        if store.pendingFocusReflection == nil {
                            focusReflectionNote = ""
                            focusReflectionEnergy = 3
                        }
                    }
                }
                .accessibilityIdentifier("plan.focus.reflection.commit")
            }
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.focus.reflection")
    }
}
