import SwiftUI

struct ContextChipGroup<Item: Hashable>: View {
    let title: String
    let items: [Item]
    let selectedItems: Set<Item>
    let allowsMultipleSelection: Bool
    let titleProvider: KeyPath<Item, String>
    let onToggle: (Item) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.xs) {
            Text(title)
                .font(.lifeboard(.caption1).weight(.semibold))
                .foregroundStyle(LBColorTokens.navyMuted)

            ReflectPlanChipFlow(items: items) { item in
                let isSelected = selectedItems.contains(item)
                Button {
                    onToggle(item)
                } label: {
                    Text(item[keyPath: titleProvider])
                        .font(.lifeboard(.caption1).weight(.semibold))
                        .foregroundStyle(isSelected ? LBColorTokens.navy : LBColorTokens.navySoft)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .frame(minHeight: 44)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? ReflectPlanStyle.selectedChip : ReflectPlanStyle.cream)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(isSelected ? ReflectPlanStyle.selectedChipBorder : ReflectPlanStyle.peachBorder.opacity(0.54), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item[keyPath: titleProvider])")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                .accessibilityHint(allowsMultipleSelection ? "Toggles this friction tag." : "Selects this \(title.lowercased()) option.")
            }
        }
    }
}
