import SwiftUI

struct SunriseSearchFaceView<ResultsContent: View>: View {
    @Binding var query: String
    @FocusState.Binding var isFocused: Bool
    let bottomInset: CGFloat
    let statusChips: [LifeBoardSearchFilterChipDescriptor]
    let priorityChips: [LifeBoardSearchFilterChipDescriptor]
    let projectChips: [LifeBoardSearchFilterChipDescriptor]
    let isLoading: Bool
    let loadingMessage: String
    let showsNoResults: Bool
    let emptyTitle: String
    let emptySubtitle: String
    let hasActiveFilters: Bool
    let onBack: () -> Void
    let onQueryChanged: (String) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void
    @ViewBuilder let resultsContent: ResultsContent

    var body: some View {
        SunriseDestinationScaffold(
            title: "Search",
            subtitle: "Find what matters. Focus on what’s next.",
            leadingSystemImage: "line.3.horizontal",
            leadingAccessibilityLabel: "Back to tasks",
            leadingAccessibilityIdentifier: "search.backChip",
            leadingAction: onBack,
            trailingSystemImage: "sparkles",
            trailingAccessibilityLabel: "Commit search",
            trailingAction: onSubmit,
            bottomInset: 0
        ) {
            VStack(spacing: LBSpacingTokens.lg) {
                searchChrome

                GeometryReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        bodyContent(availableHeight: proxy.size.height)
                            .padding(.bottom, bottomInset + LBSpacingTokens.lg)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .accessibilityIdentifier("search.contentContainer")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.view")
    }

    private var searchChrome: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            LifeBoardSearchHeaderView(
                query: $query,
                isFocused: _isFocused,
                onQueryChanged: onQueryChanged,
                onSubmit: onSubmit,
                onClear: onClear
            )

            chipRows
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("search.chromeContainer")
    }

    private var chipRows: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.sm) {
            SunriseSearchChipRow(chips: statusChips)
            SunriseSearchChipRow(chips: priorityChips)
            if projectChips.isEmpty == false {
                SunriseSearchChipRow(chips: projectChips)
            }
        }
    }

    @ViewBuilder
    private func bodyContent(availableHeight: CGFloat) -> some View {
        if isLoading {
            SunriseSearchStateCard(
                asset: .thinkingCup,
                title: loadingMessage,
                subtitle: "Gathering the matching tasks.",
                showsProgress: true
            )
            .frame(maxWidth: .infinity, minHeight: max(availableHeight - bottomInset, 260), alignment: .center)
        } else if showsNoResults {
            SunriseSearchStateCard(
                asset: emptyAsset,
                title: emptyTitle,
                subtitle: emptySubtitle,
                showsProgress: false
            )
            .frame(maxWidth: .infinity, minHeight: max(availableHeight - bottomInset, 260), alignment: .center)
        } else {
            resultsContent
        }
    }

    private var emptyAsset: SunriseDecorAsset {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && hasActiveFilters == false
            ? .thinkingCup
            : .decisionSign
    }
}

struct SunriseSearchChipRow: View {
    let chips: [LifeBoardSearchFilterChipDescriptor]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: LBSpacingTokens.sm) {
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
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
    }
}

struct SunriseSearchResultsSurface<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            Color.clear
                .frame(height: 0)
                .accessibilityIdentifier("search.resultsList")

            content
        }
        .padding(LBSpacingTokens.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LBColorTokens.glass.opacity(0.72))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(LBColorTokens.glassBorder, lineWidth: 1)
                )
                .shadow(color: LBColorTokens.elevationShadow, radius: 18, x: 0, y: 10)
        }
    }
}

private struct SunriseSearchStateCard: View {
    let asset: SunriseDecorAsset
    let title: String
    let subtitle: String
    let showsProgress: Bool

    var body: some View {
        VStack(spacing: LBSpacingTokens.md) {
            SunriseDecorImage(asset: asset, size: 132, opacity: 0.88)

            if showsProgress {
                ProgressView()
                    .progressViewStyle(.circular)
            }

            VStack(spacing: LBSpacingTokens.xs) {
                Text(title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(LBColorTokens.navy)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("search.emptyStateLabel")

                Text(subtitle)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(LBColorTokens.navyMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(LBSpacingTokens.xl)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LBColorTokens.glass.opacity(0.70))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(LBColorTokens.glassBorder, lineWidth: 1)
                )
        }
    }
}
