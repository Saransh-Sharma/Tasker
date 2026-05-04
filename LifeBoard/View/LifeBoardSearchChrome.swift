import SwiftUI
import UIKit

enum LifeBoardSearchChromeStyle {
    static let headerCornerRadius: CGFloat = 24
    static let iconButtonCornerRadius: CGFloat = 22
    static let chipCornerRadius: CGFloat = 18
    static let searchFieldHeight: CGFloat = 48
    static let filterSpacing: CGFloat = 12
    static let selectedChipScale: CGFloat = 1.03
    static let projectHeaderCornerRadius: CGFloat = 16
    static let projectHeaderHeight: CGFloat = 44

    static func tintedSelectedBackground(tokens: LifeBoardColorTokens) -> UIColor {
        tokens.accentMuted.withAlphaComponent(0.92)
    }

    static func tintedSelectedBorder(tokens: LifeBoardColorTokens) -> UIColor {
        tokens.accentPrimary.withAlphaComponent(0.28)
    }

    static func projectHeaderBackground(tokens: LifeBoardColorTokens) -> UIColor {
        tokens.surfaceSecondary
    }
}

struct LifeBoardSearchFilterChipDescriptor: Identifiable {
    let id: String
    let title: String
    let isSelected: Bool
    let tintColor: Color
    let accessibilityIdentifier: String
    let action: () -> Void
}

struct LifeBoardSearchHeaderView: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let onQueryChanged: (String) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)

            TextField("Search tasks...", text: $query)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.lifeboard(.body))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .accessibilityIdentifier("search.searchField")
                .onChange(of: query) { _, newValue in
                    onQueryChanged(newValue)
                }
                .onSubmit(onSubmit)

            if !query.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.lifeboard.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search.clearButton")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, spacing.s12)
        .frame(height: LifeBoardSearchChromeStyle.searchFieldHeight)
        .lifeboardChromeSurface(
            cornerRadius: LifeBoardSearchChromeStyle.headerCornerRadius,
            accentColor: Color.lifeboard.accentSecondary,
            level: .e1
        )
    }
}

struct LifeBoardSearchFilterChipsView: View {
    let chips: [LifeBoardSearchFilterChipDescriptor]

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LifeBoardSearchChromeStyle.filterSpacing) {
                ForEach(chips) { chip in
                    LifeBoardFilterChip(
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
