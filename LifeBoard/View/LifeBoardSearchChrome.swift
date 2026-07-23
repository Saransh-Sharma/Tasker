import SwiftUI
import UIKit

enum LifeBoardSearchChromeStyle {
    static let headerCornerRadius: CGFloat = 28
    static let iconButtonCornerRadius: CGFloat = 22
    static let chipCornerRadius: CGFloat = 18
    static let searchFieldHeight: CGFloat = 58
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
    var systemImage: String? = nil
    var count: Int? = nil
    let isSelected: Bool
    let tintColor: Color
    let accessibilityIdentifier: String
    let action: () -> Void
}

struct LifeBoardSearchHeaderView: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String = "Search tasks, notes, habits, projects..."
    var isCommandMode: Bool = false
    let onQueryChanged: (String) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.lifeboard.textSecondary)

            TextField(placeholder, text: $query)
                .focused($isFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.lifeboard(.headline))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .tint(LBColorTokens.violetDeep)
                .accessibilityIdentifier("search.searchField")
                .onChange(of: query) { _, newValue in
                    onQueryChanged(newValue)
                }
                .onSubmit(onSubmit)

            if isCommandMode {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LBColorTokens.violetDeep)
                    .accessibilityHidden(true)
            }

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
        .background {
            RoundedRectangle(cornerRadius: LifeBoardSearchChromeStyle.headerCornerRadius, style: .continuous)
                .fill(LBColorTokens.glassStrong.opacity(0.82))
                .lifeBoardSystemGlass(
                    .regular,
                    in: RoundedRectangle(cornerRadius: LifeBoardSearchChromeStyle.headerCornerRadius, style: .continuous),
                    interactive: true
                )
                .overlay {
                    RoundedRectangle(cornerRadius: LifeBoardSearchChromeStyle.headerCornerRadius, style: .continuous)
                        .stroke(isFocused ? LBColorTokens.violet.opacity(0.82) : LBColorTokens.hairline.opacity(0.38), lineWidth: isFocused ? 1.5 : 1)
                }
                .shadow(color: LBColorTokens.elevationShadow, radius: 15, x: 0, y: 8)
        }
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
