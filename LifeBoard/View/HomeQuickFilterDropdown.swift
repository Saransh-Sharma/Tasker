//
//  HomeQuickFilterDropdown.swift
//  LifeBoard
//
//  Dropdown menu containing all quick filter options.
//

 import SwiftUI

// MARK: - HomeQuickFilterDropdown

/// Dropdown overlay containing all filter sections.
/// Follows the CreateMenuActionSheet pattern for animations and styling.
public struct HomeQuickFilterDropdown: View {

    // MARK: - Properties

    @ObservedObject var viewModel: HomeViewModel
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    let onShowDatePicker: () -> Void
    let onShowAdvancedFilters: () -> Void

    // MARK: - State

    @State private var isVisible = false

    // MARK: - Tokens

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    // MARK: - Initialization

    /// Initializes a new instance.
    public init(
        viewModel: HomeViewModel,
        isPresented: Binding<Bool>,
        onShowDatePicker: @escaping () -> Void,
        onShowAdvancedFilters: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.onShowDatePicker = onShowDatePicker
        self.onShowAdvancedFilters = onShowAdvancedFilters
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isVisible {
                    LinearGradient(
                        colors: [
                            Color.lifeboard(.overlayScrim).opacity(0.18),
                            Color.lifeboard(.overlayScrim).opacity(0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            dismissWithAnimation()
                        }
                }

                overlayContent(in: geometry)
            }
            .onAppear {
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isVisible = true
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func overlayContent(in geometry: GeometryProxy) -> some View {
        if layoutClass.isPad {
            VStack {
                Spacer()
                HStack {
                    Spacer(minLength: spacing.s20)
                    if isVisible {
                        dropdownContent(
                            maxScrollableHeight: min(geometry.size.height * 0.55, 560),
                            safeAreaBottom: geometry.safeAreaInsets.bottom
                        )
                        .frame(maxWidth: min(max(420, geometry.size.width * 0.42), 520))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.bottom, geometry.safeAreaInsets.bottom + spacing.s16)
            }
        } else {
            VStack {
                Spacer()
                if isVisible {
                    dropdownContent(
                        maxScrollableHeight: geometry.size.height * 0.6,
                        safeAreaBottom: geometry.safeAreaInsets.bottom
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Dropdown Content

    private func dropdownContent(maxScrollableHeight: CGFloat, safeAreaBottom: CGFloat) -> some View {
        LifeBoardFilterSheetContainer(
            horizontalPadding: spacing.s16,
            bottomPadding: safeAreaBottom + spacing.s16
        ) {
            VStack(spacing: 0) {
                headerView

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        quickViewSection
                        divider
                        dateSection
                        divider
                        projectsSection

                        divider
                        savedViewsSection
                        divider
                        advancedFiltersRow
                    }
                }
                .frame(maxHeight: maxScrollableHeight)

                resetButton
            }
        }
        .accessibilityIdentifier("home.focus.menu.container")
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top, spacing: spacing.s12) {
            VStack(alignment: .leading, spacing: spacing.s8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.lifeboard.textQuaternary.opacity(0.28))
                    .frame(width: 42, height: 5)

                Text("Quick filters")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard.textPrimary)

                Text("Keep the board calm while you narrow the scope.")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }

            Spacer(minLength: spacing.s12)

            Button {
                dismissWithAnimation()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .frame(width: 34, height: 34)
                    .lifeboardChromeSurface(
                        cornerRadius: 17,
                        accentColor: Color.lifeboard.accentSecondary,
                        level: .e1
                    )
            }
            .buttonStyle(.plain)
            .lifeboardPressFeedback(reduceMotion: reduceMotion)
        }
        .padding(.horizontal, spacing.s20)
        .padding(.top, spacing.s12)
        .padding(.bottom, spacing.s16)
    }

    // MARK: - Quick View Section

    private var quickViewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Quick View", index: 0)

            ForEach(HomeQuickView.allCases, id: \.rawValue) { quickView in
                LifeBoardFilterRow(
                    title: quickView.title,
                    isSelected: viewModel.activeScope.quickView == quickView,
                    count: viewModel.quickViewCounts[quickView]
                ) {
                    viewModel.setQuickView(quickView)
                    // Don't dismiss - let user see the change
                    provideHapticFeedback()
                }
            }
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Date", index: 1)

            LifeBoardFilterRow(
                title: "Select specific date...",
                isSelected: false,
                systemImage: "calendar"
            ) {
                dismissWithAnimation()
                onShowDatePicker()
            }
        }
    }

    // MARK: - Projects Section

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Projects", index: 2)

            // All Projects option
            LifeBoardFilterRow(
                title: "All Projects",
                isSelected: viewModel.activeFilterState.selectedProjectIDs.isEmpty,
                systemImage: "folder"
            ) {
                viewModel.clearProjectFilters()
                provideHapticFeedback()
            }

            // Pinned projects
            let pinnedProjects = viewModel.projects.filter {
                viewModel.activeFilterState.pinnedProjectIDSet.contains($0.id)
            }

            ForEach(pinnedProjects, id: \.id) { project in
                LifeBoardFilterRow(
                    title: project.name,
                    isSelected: viewModel.activeFilterState.selectedProjectIDSet.contains(project.id),
                    isMultiSelect: true
                ) {
                    viewModel.toggleProjectFilter(project.id)
                    provideHapticFeedback()
                }
            }

            if pinnedProjects.isEmpty {
                Text("No pinned projects")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)
                    .padding(.horizontal, spacing.s20)
                    .padding(.vertical, spacing.s8)
            }
        }
    }

    // MARK: - Saved Views Section

    private var savedViewsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Saved Views", index: 3)

            if viewModel.savedHomeViews.isEmpty {
                Text("No saved views")
                    .font(.lifeboard(.caption1))
                    .foregroundColor(Color.lifeboard.textTertiary)
                    .padding(.horizontal, spacing.s20)
                    .padding(.vertical, spacing.s8)
            } else {
                ForEach(viewModel.savedHomeViews) { savedView in
                    HStack {
                        Button {
                            viewModel.applySavedView(id: savedView.id)
                            dismissWithAnimation()
                        } label: {
                            HStack {
                                Text(savedView.name)
                                    .font(.lifeboard(.callout))
                                    .foregroundColor(Color.lifeboard.textPrimary)

                                if viewModel.activeFilterState.selectedSavedViewID == savedView.id {
                                    Text("Active")
                                        .font(.lifeboard(.caption2))
                                        .foregroundColor(Color.lifeboard.accentOnPrimary)
                                        .padding(.horizontal, spacing.s8)
                                        .padding(.vertical, spacing.s2)
                                        .background(
                                            Capsule()
                                                .fill(Color.lifeboard.accentPrimary)
                                        )
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            viewModel.deleteSavedView(id: savedView.id)
                            provideHapticFeedback()
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                                .foregroundColor(Color.lifeboard.statusDanger)
                        }
                    }
                    .padding(.horizontal, spacing.s20)
                    .padding(.vertical, spacing.s12)
                }
            }
        }
    }

    // MARK: - Advanced Filters Row

    private var advancedFiltersRow: some View {
        LifeBoardFilterRow(
            title: "Advanced Filters",
            subtitle: advancedFiltersSubtitle,
            isSelected: viewModel.activeFilterState.advancedFilter != nil,
            systemImage: "slider.horizontal.3",
            accessibilityIdentifier: "home.focus.menu.advanced"
        ) {
            dismissWithAnimation()
            onShowAdvancedFilters()
        }
    }

    private var advancedFiltersSubtitle: String? {
        guard let filter = viewModel.activeFilterState.advancedFilter else { return nil }
        var parts: [String] = []
        if !filter.priorities.isEmpty { parts.append("\(filter.priorities.count) priorities") }
        if !filter.categories.isEmpty { parts.append("\(filter.categories.count) categories") }
        if !filter.tags.isEmpty { parts.append("\(filter.tags.count) tags") }
        return parts.isEmpty ? "Active" : parts.joined(separator: ", ")
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        Button {
            viewModel.resetAllFilters()
            dismissWithAnimation()
        } label: {
            HStack(spacing: spacing.s8) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 14, weight: .semibold))
                Text("Reset all filters")
                    .font(.lifeboard(.bodyEmphasis))
            }
            .foregroundStyle(Color.lifeboard.statusDanger)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .lifeboardChromeSurface(
                cornerRadius: corner.r3,
                accentColor: Color.lifeboard.statusDanger,
                level: .e1
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r3, style: .continuous)
                    .stroke(Color.lifeboard.statusDanger.opacity(0.28), lineWidth: 1)
            )
        }
        .lifeboardPressFeedback(reduceMotion: reduceMotion)
        .accessibilityIdentifier("home.focus.menu.reset")
        .padding(.horizontal, spacing.s20)
        .padding(.vertical, spacing.s12)
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color.lifeboard.divider)
            .frame(height: 1)
            .padding(.horizontal, spacing.s20)
    }

    /// Executes sectionHeader.
    private func sectionHeader(_ title: String, index: Int = 0) -> some View {
        LifeBoardFilterSectionHeader(title: title, index: index)
    }

    /// Executes provideHapticFeedback.
    private func provideHapticFeedback() {
        LifeBoardFeedback.light()
    }

    /// Executes dismissWithAnimation.
    private func dismissWithAnimation() {
        if reduceMotion {
            isVisible = false
            isPresented = false
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
}

// MARK: - View Extension for Max Height

extension View {
    /// Executes maxHeight.
    func maxHeight(_ maxHeight: CGFloat) -> some View {
        self.modifier(MaxHeightModifier(maxHeight: maxHeight))
    }
}

struct MaxHeightModifier: ViewModifier {
    let maxHeight: CGFloat

    /// Executes body.
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .frame(maxHeight: min(geometry.size.height, maxHeight))
        }
    }
}

// MARK: - Preview

#if DEBUG
struct HomeQuickFilterDropdown_Previews: PreviewProvider {
    static var previews: some View {
        Text("Preview requires ViewModel")
    }
}
#endif
