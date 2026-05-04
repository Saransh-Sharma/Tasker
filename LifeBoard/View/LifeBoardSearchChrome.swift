import SwiftUI
import UIKit

enum TaskerSearchChromeStyle {
    static let headerCornerRadius: CGFloat = 24
    static let iconButtonCornerRadius: CGFloat = 22
    static let chipCornerRadius: CGFloat = 18
    static let searchFieldHeight: CGFloat = 48
    static let filterSpacing: CGFloat = 12
    static let selectedChipScale: CGFloat = 1.03
    static let projectHeaderCornerRadius: CGFloat = 16
    static let projectHeaderHeight: CGFloat = 44

    static func tintedSelectedBackground(tokens: TaskerColorTokens) -> UIColor {
        tokens.accentMuted.withAlphaComponent(0.92)
    }

    static func tintedSelectedBorder(tokens: TaskerColorTokens) -> UIColor {
        tokens.accentPrimary.withAlphaComponent(0.28)
    }

    static func projectHeaderBackground(tokens: TaskerColorTokens) -> UIColor {
        tokens.surfaceSecondary
    }
}

struct TaskerSearchFilterChipDescriptor: Identifiable {
    let id: String
    let title: String
    let isSelected: Bool
    let tintColor: Color
    let accessibilityIdentifier: String
    let action: () -> Void
}

struct TaskerSearchHeaderView: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let onQueryChanged: (String) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.tasker.textSecondary)

            TextField("Search tasks...", text: $query)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.tasker(.body))
                .foregroundStyle(Color.tasker.textPrimary)
                .accessibilityIdentifier("search.searchField")
                .onChange(of: query) { _, newValue in
                    onQueryChanged(newValue)
                }
                .onSubmit(onSubmit)

            if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.tasker.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search.clearButton")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, spacing.s12)
        .frame(height: TaskerSearchChromeStyle.searchFieldHeight)
        .taskerChromeSurface(
            cornerRadius: TaskerSearchChromeStyle.headerCornerRadius,
            accentColor: Color.tasker.accentSecondary,
            level: .e1
        )
    }
}

struct TaskerSearchFilterChipsView: View {
    let chips: [TaskerSearchFilterChipDescriptor]

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TaskerSearchChromeStyle.filterSpacing) {
                ForEach(chips) { chip in
                    TaskerFilterChip(
                        title: chip.title,
                        isSelected: chip.isSelected,
                        accentColor: chip.tintColor,
                        accessibilityIdentifier: chip.accessibilityIdentifier,
                        action: chip.action
                    )
                }
            }
            .padding(.horizontal, spacing.s4)
        }
    }
}
