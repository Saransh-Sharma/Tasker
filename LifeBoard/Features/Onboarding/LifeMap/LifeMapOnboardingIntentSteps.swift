import LifeBoardTokens
import LifeBoardUI
import SwiftUI

// The first five beats: what the user wants, what gets in the way, what they
// carry, and in what order. Nothing here writes a record — every answer lives
// in `LifeMapDraft` until the assemble step commits it.

// MARK: - Welcome

struct LifeMapWelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            LifeMapEyebrow("LIFEBOARD · LIFE OS")
            Text("Your whole life,\nin one calm system.")
                .font(.lifeboard(.heroDisplay))
                .foregroundStyle(Color.lifeboard(.textPrimary))
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
            Text("One private, flexible place to orient, act, recover, and adapt.")
                .font(.lifeboard(.title3))
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                LifeMapTrustRow(symbol: "lock.fill", text: "Private by design")
                LifeMapTrustRow(symbol: "clock", text: "About 3 minutes")
                LifeMapTrustRow(symbol: "slider.horizontal.3", text: "Editable later")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.welcome))
    }
}

private struct LifeMapTrustRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.lifeboard(.caption1))
            .foregroundStyle(Color.lifeboard(.textSecondary))
            .labelStyle(.titleAndIcon)
    }
}

// MARK: - Desired change

struct LifeMapDesiredChangeStep: View {
    let selected: LifeMapDesiredChange?
    let onSelect: (LifeMapDesiredChange) -> Void

    var body: some View {
        LifeMapQuestionScaffold(
            title: "What would feel different first?",
            support: "Choose the change you want LifeBoard to protect."
        ) {
            ForEach(LifeMapDesiredChange.allCases) { value in
                LifeMapChoiceRow(
                    title: value.title,
                    symbol: value.symbol,
                    isSelected: selected == value
                ) {
                    onSelect(value)
                }
                .accessibilityIdentifier(LifeMapAccessibilityID.desiredChange(value.id))
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.desiredChange))
    }
}

// MARK: - Friction

struct LifeMapFrictionStep: View {
    let selectedIDs: [String]
    let onToggle: (LifeMapFriction) -> Void

    private var isAtLimit: Bool { selectedIDs.count >= LifeMapDraft.maximumFrictions }

    var body: some View {
        LifeMapQuestionScaffold(
            title: "What usually gets in the way?",
            support: "Choose up to two. We’ll shape the system around them."
        ) {
            ForEach(LifeMapFriction.allCases) { value in
                let isSelected = selectedIDs.contains(value.id)
                LifeMapChoiceRow(
                    title: value.title,
                    symbol: value.symbol,
                    isSelected: isSelected,
                    isDisabled: isAtLimit && isSelected == false
                ) {
                    onToggle(value)
                }
                .accessibilityIdentifier(LifeMapAccessibilityID.friction(value.id))
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.friction))
    }
}

// MARK: - Life areas

struct LifeMapLifeAreasStep: View {
    let selectedIDs: [String]
    let onToggle: (StarterLifeAreaTemplate) -> Void

    private var isAtLimit: Bool { selectedIDs.count >= LifeMapDraft.maximumLifeAreas }

    var body: some View {
        LifeMapQuestionScaffold(
            title: "What are you carrying right now?",
            support: "Choose two to five. These become the outer ring of your map."
        ) {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: Theme.Spacing.sm)],
                spacing: Theme.Spacing.sm
            ) {
                ForEach(StarterWorkspaceCatalog.allLifeAreas) { template in
                    LifeMapAreaTile(
                        template: template,
                        isSelected: selectedIDs.contains(template.id),
                        isDisabled: isAtLimit && selectedIDs.contains(template.id) == false,
                        onTap: { onToggle(template) }
                    )
                }
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.lifeAreas))
    }
}

private struct LifeMapAreaTile: View {
    let template: StarterLifeAreaTemplate
    let isSelected: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    private var tint: Color {
        HexColor.color(template.colorHex, fallback: Color.lifeboard(.accentPrimary))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm + 1) {
                Image(systemName: template.icon)
                    .font(.lifeboard(.title3))
                    .foregroundStyle(tint)
                Text(template.name)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .multilineTextAlignment(.leading)
                Text(template.subtitle)
                    .font(.lifeboard(.caption2))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .padding(Theme.Spacing.md + 2)
            .lifeBoardClaySurface(
                isSelected ? .raised : .resting,
                cornerRadius: Radius.card,
                fill: isSelected ? Color.lifeboard(.accentWash) : nil
            )
        }
        .buttonStyle(LifeMapPressButtonStyle())
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.48 : 1)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(LifeMapAccessibilityID.lifeArea(template.id))
    }
}

// MARK: - Priorities

struct LifeMapPrioritiesStep: View {
    let templates: [StarterLifeAreaTemplate]
    let onMove: (Int, Int) -> Void

    var body: some View {
        LifeMapQuestionScaffold(
            title: "What needs the front seat this season?",
            support: "Drag to reorder, or use the arrow buttons. Everything still matters."
        ) {
            ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                LifeMapPriorityRow(
                    template: template,
                    rank: index,
                    isFirst: index == 0,
                    isLast: index == templates.count - 1,
                    onMoveEarlier: { onMove(index, index - 1) },
                    onMoveLater: { onMove(index, index + 1) },
                    onDrop: { sourceID in
                        guard let source = templates.firstIndex(where: { $0.id == sourceID }) else { return false }
                        onMove(source, index)
                        return true
                    }
                )
            }
        }
        .accessibilityIdentifier(LifeMapAccessibilityID.step(.priorities))
    }
}

/// Rank changes order and a restrained amount of emphasis — never dignity.
/// `DESIGN.md` forbids shrinking type to express hierarchy, so the difference
/// between first and last is a numeral and a tint, not a size ramp.
private struct LifeMapPriorityRow: View {
    let template: StarterLifeAreaTemplate
    let rank: Int
    let isFirst: Bool
    let isLast: Bool
    let onMoveEarlier: () -> Void
    let onMoveLater: () -> Void
    let onDrop: (String) -> Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Text("\(rank + 1)")
                .font(.lifeboard(.caption1))
                .monospacedDigit()
                .foregroundStyle(Color.lifeboard(.accentOnPrimary))
                .frame(width: 28, height: 28)
                .background(Color.lifeboard(.accentPrimary), in: Circle())
            Image(systemName: template.icon)
                .font(.lifeboard(.body))
                .foregroundStyle(HexColor.color(template.colorHex, fallback: Color.lifeboard(.accentPrimary)))
            Text(template.name)
                .font(.lifeboard(.bodyStrong))
                .foregroundStyle(Color.lifeboard(.textPrimary))
            Spacer(minLength: Theme.Spacing.sm)
            Button(action: onMoveEarlier) {
                Image(systemName: "arrow.up")
            }
            .disabled(isFirst)
            .accessibilityLabel("Move \(template.name) earlier")
            .accessibilityIdentifier(LifeMapAccessibilityID.moveEarlier(template.id))
            Button(action: onMoveLater) {
                Image(systemName: "arrow.down")
            }
            .disabled(isLast)
            .accessibilityLabel("Move \(template.name) later")
            .accessibilityIdentifier(LifeMapAccessibilityID.moveLater(template.id))
        }
        .font(.lifeboard(.body))
        .foregroundStyle(Color.lifeboard(.textSecondary))
        .padding(Theme.Spacing.md + 2)
        .lifeBoardClaySurface(.resting, cornerRadius: Radius.card)
        .draggable(template.id)
        .dropDestination(for: String.self) { values, _ in
            guard let sourceID = values.first else { return false }
            return onDrop(sourceID)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(LifeMapAccessibilityID.priority(template.id))
        .accessibilityValue("Priority \(rank + 1)")
    }
}
