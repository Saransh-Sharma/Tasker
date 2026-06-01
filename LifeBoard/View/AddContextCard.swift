import SwiftUI

struct AddContextCard: View {
    @Binding var isExpanded: Bool
    @Binding var noteText: String
    let selectedMood: ReflectionMood?
    let selectedEnergy: ReflectionEnergy?
    let selectedFrictionTags: Set<ReflectionFrictionTag>
    let onToggleMood: (ReflectionMood) -> Void
    let onToggleEnergy: (ReflectionEnergy) -> Void
    let onToggleFriction: (ReflectionFrictionTag) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            Button(action: toggleExpanded) {
                HStack(alignment: .center, spacing: LBSpacingTokens.md) {
                    ZStack {
                        Circle()
                            .fill(ReflectPlanStyle.peachSurfaceStrong)
                            .frame(width: 42, height: 42)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LBColorTokens.role(.personal).deep)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Add context")
                            .font(.lifeboard(.headline))
                            .foregroundStyle(LBColorTokens.navy)
                        Text("Mood, energy, friction, and note")
                            .font(.lifeboard(.caption1))
                            .foregroundStyle(LBColorTokens.navyMuted)
                    }

                    Spacer(minLength: LBSpacingTokens.sm)

                    Text(isExpanded ? "Hide" : "Optional")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navyMuted)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(reduceMotion ? nil : LifeBoardAnimation.snappy, value: isExpanded)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add context. \(isExpanded ? "Hide" : "Optional"). Mood, energy, friction, and note.")

            if isExpanded {
                expandedContent
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(LBSpacingTokens.lg)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(ReflectPlanStyle.peachBorder.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: ReflectPlanStyle.shadow, radius: 18, x: 0, y: 10)
        .animation(reduceMotion ? nil : LifeBoardAnimation.snappy, value: isExpanded)
    }

    private var expandedContent: some View {
        ZStack(alignment: .trailing) {
            SunriseDecorImage(asset: .subtleLeaf, size: 126, opacity: reduceTransparency ? 0.12 : 0.20, rotation: .degrees(-8))
                .offset(x: 28, y: -2)

            VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
                VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
                    Text("One-line note")
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(LBColorTokens.navyMuted)
                    TextField("What mattered most?", text: $noteText, axis: .vertical)
                        .font(.lifeboard(.callout))
                        .lineLimit(1...2)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(ReflectPlanStyle.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(ReflectPlanStyle.peachBorder.opacity(0.58), lineWidth: 1)
                        )
                        .accessibilityLabel("One-line note. What mattered most?")
                }

                ContextChipGroup(
                    title: "Mood",
                    items: ReflectionMood.allCases,
                    selectedItems: Set(selectedMood.map { [$0] } ?? []),
                    allowsMultipleSelection: false,
                    titleProvider: \.title,
                    onToggle: onToggleMood
                )

                ContextChipGroup(
                    title: "Energy",
                    items: ReflectionEnergy.allCases,
                    selectedItems: Set(selectedEnergy.map { [$0] } ?? []),
                    allowsMultipleSelection: false,
                    titleProvider: \.title,
                    onToggle: onToggleEnergy
                )

                ContextChipGroup(
                    title: "Friction",
                    items: ReflectionFrictionTag.allCases,
                    selectedItems: selectedFrictionTags,
                    allowsMultipleSelection: true,
                    titleProvider: \.title,
                    onToggle: onToggleFriction
                )
            }
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(ReflectPlanStyle.peachSurfaceStrong)
        } else {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            ReflectPlanStyle.peachSurfaceStrong,
                            ReflectPlanStyle.peachSurface,
                            ReflectPlanStyle.cream
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }

    private func toggleExpanded() {
        LifeBoardFeedback.selection()
        isExpanded.toggle()
    }
}
