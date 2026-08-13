import SwiftUI

/// A question the composer needs answered before it can act.
///
/// One `private struct … : View` per section is this repo's composer-kit rule,
/// and it is enforced by `scripts/premium-ui-guardrails.sh` for a concrete
/// reason: at `-Onone`, a body that inlines this many conditional sections walks
/// the 1 MB main-thread stack and crashes on the guard page *at launch*, before
/// anything is drawn — so it never shows up in a Release smoke test. These two
/// blocks were the largest remaining inline sections in `LifeThreadComposerHost`.
struct ComposerClarificationRow: View {
    let clarification: ClarificationRequest
    let onDismiss: () -> Void
    let onChoose: (ClarificationOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(clarification.question)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss clarification")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(clarification.options) { option in
                        Button {
                            onChoose(option)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: option.systemImage)
                                Text(option.label)
                            }
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .lifeBoardPressResponse(.control, haptic: nil)
                    }
                }
            }
        }
        .padding(12)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
    }
}

/// What the composer thinks you meant, offered as one tappable proposal.
struct ComposerInterpretationRow: View {
    let interpretation: ComposerInterpretation
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onAccept) {
                HStack(spacing: 6) {
                    Image(systemName: interpretation.systemImage)
                        .foregroundColor(Color.lifeboard(.accentPrimary))
                    Text(interpretation.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))

                    ForEach(interpretation.chips) { chip in
                        Text(chip.label)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(SemanticColorTokens.foundationSurfaceSolid), in: Capsule())
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Color.lifeboard(.accentPrimary))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color.lifeboard(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(SemanticColorTokens.foundationHairline), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .lifeBoardPressResponse(.card, haptic: nil)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(Color(SemanticColorTokens.inkSecondary))
                    .frame(width: 26, height: 26)
                    .background(Color.lifeboard(.surfaceSecondary), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss interpretation")
        }
        .padding(.horizontal, 4)
    }
}
