//
//  CreationSharedComponents.swift
//  LifeBoard
//
//  Shared Sunrise creation controls used by task, habit, and life-management forms.
//

import SwiftUI

struct AddTaskTypeChips: View {
    @Binding var selectedType: TaskType

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    private let types: [(type: TaskType, icon: String, label: String)] = [
        (.morning, "sun.max", "Morning"),
        (.evening, "moon.stars", "Evening"),
        (.upcoming, "arrow.right.circle", "Upcoming"),
    ]

    var body: some View {
        HStack(spacing: spacing.chipSpacing) {
            ForEach(types, id: \.type) { item in
                AddTaskMetadataChip(
                    icon: item.icon,
                    text: item.label,
                    isActive: selectedType == item.type
                ) {
                    withAnimation(LifeBoardAnimation.snappy) {
                        selectedType = item.type
                    }
                }
            }
        }
    }
}

struct LifeBoardComposerOption<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let icon: String?
    let accentHex: String?
}

struct LifeBoardComposerOptionGrid<ID: Hashable>: View {
    let title: String
    let helperText: String?
    let options: [LifeBoardComposerOption<ID>]
    let selectedID: ID?
    let noneOptionTitle: String?
    let emptyStateText: String?
    let accessibilityIdentifier: String?
    let onSelect: (ID?) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).corner }
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 168 : 128), spacing: spacing.s8, alignment: .leading)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            VStack(alignment: .leading, spacing: spacing.s4) {
                Text(title)
                    .font(.lifeboard(.callout).weight(.semibold))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                if let helperText, helperText.isEmpty == false {
                    Text(helperText)
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: columns, alignment: .leading, spacing: spacing.s8) {
                if let noneOptionTitle {
                    optionButton(
                        title: noneOptionTitle,
                        icon: "minus",
                        accentHex: nil,
                        isSelected: selectedID == nil
                    ) {
                        onSelect(nil)
                    }
                }

                ForEach(options) { option in
                    optionButton(
                        title: option.title,
                        icon: option.icon,
                        accentHex: option.accentHex,
                        isSelected: selectedID == option.id
                    ) {
                        onSelect(option.id)
                    }
                }
            }
            .accessibilityIdentifier(accessibilityIdentifier ?? "")

            if options.isEmpty, let emptyStateText, emptyStateText.isEmpty == false {
                Text(emptyStateText)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .padding(.top, spacing.s4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func optionButton(
        title: String,
        icon: String?,
        accentHex: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let hasAccent = LifeBoardHexColor.normalized(accentHex) != nil
        let accentColor = LifeBoardHexColor.color(accentHex, fallback: Color.lifeboard.accentPrimary)
        return Button {
            LifeBoardFeedback.selection()
            action()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                if let icon, icon.isEmpty == false {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                                ? (hasAccent ? accentColor : Color.lifeboard.accentPrimary)
                                : (hasAccent ? accentColor.opacity(0.86) : Color.lifeboard.textTertiary)
                        )
                }

                Text(title)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(hasAccent ? accentColor : Color.lifeboard.accentPrimary)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(
                        isSelected
                            ? (hasAccent ? accentColor.opacity(0.18) : Color.lifeboard.accentWash)
                            : (hasAccent ? accentColor.opacity(0.08) : Color.lifeboard.surfaceSecondary)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .stroke(
                        isSelected
                            ? (hasAccent ? accentColor.opacity(0.52) : Color.lifeboard.accentRing)
                            : (hasAccent ? accentColor.opacity(0.24) : Color.lifeboard.strokeHairline),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .animation(LifeBoardAnimation.quick, value: isSelected)
    }
}

struct LifeBoardComposerDisclosureRow: View {
    let title: String
    let summary: String
    let isExpanded: Bool
    let accessibilityIdentifier: String?
    let action: () -> Void

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).corner }

    var body: some View {
        Button {
            LifeBoardFeedback.selection()
            action()
        } label: {
            HStack(alignment: .top, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.textPrimary)

                    Text(summary)
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.lifeboard.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .padding(.top, 2)
            }
            .padding(spacing.s12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .fill(Color.lifeboard.surfaceSecondary.opacity(isExpanded ? 0.72 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r2, style: .continuous)
                    .stroke(Color.lifeboard.strokeHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? "")
        .accessibilityLabel("\(title). \(summary)")
        .accessibilityHint(isExpanded ? "Collapse details" : "Expand details")
        .animation(LifeBoardAnimation.snappy, value: isExpanded)
    }
}
