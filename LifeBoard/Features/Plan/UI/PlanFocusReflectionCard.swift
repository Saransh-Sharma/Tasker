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
            TextField("Note", text: $focusReflectionNote, prompt: Text("Note").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                // Clay well, not the system rounded border: that drew a pure white
                // box on warm paper and a pure black one in dark appearance.
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .lifeBoardClaySurface(.well, cornerRadius: Radius.field)
                .accessibilityIdentifier("plan.focus.reflection.note")
            VStack(alignment: .leading, spacing: 12) {
                if receipt.interruptionCount > 0 {
                    Label(
                        receipt.interruptionCount == 1
                            ? String(localized: "1 interruption")
                            : String(localized: "\(receipt.interruptionCount) interruptions"),
                        systemImage: "bell.slash"
                    )
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                CommitControl(
                    title: String(localized: "Save"),
                    runningTitle: String(localized: "Saving…"),
                    successTitle: String(localized: "Saved"),
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
