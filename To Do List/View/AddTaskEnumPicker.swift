//
//  AddTaskEnumPicker.swift
//  Tasker
//
//  Reusable pickers for entity selection (Life Area, Section by UUID)
//  and enum selection (Energy, Category, Context by value).
//

import SwiftUI

// MARK: - UUID-Based Entity Picker (Life Area, Section)

struct AddTaskEntityPickerItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let icon: String?
    let accentHex: String?
}

struct AddTaskEntityPicker: View {
    let label: String
    let items: [AddTaskEntityPickerItem]
    @Binding var selectedID: UUID?

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text(label)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    AddTaskMetadataChip(
                        icon: "minus.circle",
                        text: "None",
                        isActive: selectedID == nil
                    ) {
                        withAnimation(TaskerAnimation.snappy) {
                            selectedID = nil
                        }
                    }

                    ForEach(items, id: \.id) { item in
                        AddTaskMetadataChip(
                            icon: item.icon ?? "circle",
                            text: item.name,
                            isActive: selectedID == item.id,
                            tintHex: item.accentHex
                        ) {
                            withAnimation(TaskerAnimation.snappy) {
                                selectedID = item.id
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Enum Chip Row (Energy, Category, Context)

struct AddTaskEnumChipRow<T: Hashable & CaseIterable>: View where T.AllCases: RandomAccessCollection {
    let label: String
    let displayName: (T) -> String
    let icon: ((T) -> String)?
    @Binding var selected: T

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    /// Initializes a new instance.
    init(label: String, displayName: @escaping (T) -> String, icon: ((T) -> String)? = nil, selected: Binding<T>) {
        self.label = label
        self.displayName = displayName
        self.icon = icon
        self._selected = selected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text(label)
                .font(.tasker(.caption1))
                .foregroundColor(Color.tasker.textTertiary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing.chipSpacing) {
                    ForEach(Array(T.allCases), id: \.self) { value in
                        AddTaskMetadataChip(
                            icon: icon?(value) ?? "circle",
                            text: displayName(value),
                            isActive: selected == value
                        ) {
                            withAnimation(TaskerAnimation.snappy) {
                                selected = value
                            }
                        }
                    }
                }
            }
        }
    }
}
