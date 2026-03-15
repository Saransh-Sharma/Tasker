//
//  HomeQuickFilterDropdown.swift
//  Tasker
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

    let onShowDatePicker: () -> Void
    let onShowAdvancedFilters: () -> Void

    // MARK: - State

    @State private var isVisible = false

    // MARK: - Tokens

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

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
        ZStack {
            // Dimmed background
            if isVisible {
                LinearGradient(
                    colors: [
                        Color.tasker(.overlayScrim).opacity(0.18),
                        Color.tasker(.overlayScrim).opacity(0.72)
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

            VStack {
                Spacer()

                // Dropdown content
                if isVisible {
                    dropdownContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
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

    // MARK: - Dropdown Content

    private var dropdownContent: some View {
        TaskerFilterSheetContainer(
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

                        if shouldShowGrouping {
                            divider
                            groupingSection
                        }

                        divider
                        savedViewsSection
                        divider
                        advancedFiltersRow
                    }
                }
                .frame(maxHeight: screenHeight * 0.6)

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
                    .fill(Color.tasker.textQuaternary.opacity(0.28))
                    .frame(width: 42, height: 5)

                Text("Quick filters")
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)

                Text("Keep the board calm while you narrow the scope.")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
            }

            Spacer(minLength: spacing.s12)

            Button {
                dismissWithAnimation()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .frame(width: 34, height: 34)
                    .taskerChromeSurface(
                        cornerRadius: 17,
                        accentColor: Color.tasker.accentSecondary,
                        level: .e1
                    )
            }
            .buttonStyle(.plain)
            .taskerPressFeedback(reduceMotion: reduceMotion)
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
                TaskerFilterRow(
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

            TaskerFilterRow(
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
            TaskerFilterRow(
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
                TaskerFilterRow(
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
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)
                    .padding(.horizontal, spacing.s20)
                    .padding(.vertical, spacing.s8)
            }
        }
    }

    // MARK: - Grouping Section

    private var shouldShowGrouping: Bool {
        switch viewModel.activeScope {
        case .today, .customDate:
            return true
        default:
            return false
        }
    }

    private var groupingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Grouping", index: 3)

            ForEach(HomeProjectGroupingMode.allCases, id: \.rawValue) { mode in
                TaskerFilterRow(
                    title: mode.title,
                    isSelected: viewModel.activeFilterState.projectGroupingMode == mode
                ) {
                    viewModel.setProjectGroupingMode(mode)
                    provideHapticFeedback()
                }
            }
        }
    }

    // MARK: - Saved Views Section

    private var savedViewsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Saved Views", index: 4)

            if viewModel.savedHomeViews.isEmpty {
                Text("No saved views")
                    .font(.tasker(.caption1))
                    .foregroundColor(Color.tasker.textTertiary)
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
                                    .font(.tasker(.callout))
                                    .foregroundColor(Color.tasker.textPrimary)

                                if viewModel.activeFilterState.selectedSavedViewID == savedView.id {
                                    Text("Active")
                                        .font(.tasker(.caption2))
                                        .foregroundColor(Color.tasker.accentOnPrimary)
                                        .padding(.horizontal, spacing.s8)
                                        .padding(.vertical, spacing.s2)
                                        .background(
                                            Capsule()
                                                .fill(Color.tasker.accentPrimary)
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
                                .foregroundColor(Color.tasker.statusDanger)
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
        TaskerFilterRow(
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
                    .font(.tasker(.bodyEmphasis))
            }
            .foregroundStyle(Color.tasker.statusDanger)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .taskerChromeSurface(
                cornerRadius: corner.r3,
                accentColor: Color.tasker.statusDanger,
                level: .e1
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner.r3, style: .continuous)
                    .stroke(Color.tasker.statusDanger.opacity(0.28), lineWidth: 1)
            )
        }
        .taskerPressFeedback(reduceMotion: reduceMotion)
        .padding(.horizontal, spacing.s20)
        .padding(.vertical, spacing.s12)
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Color.tasker.divider)
            .frame(height: 1)
            .padding(.horizontal, spacing.s20)
    }

    /// Executes sectionHeader.
    private func sectionHeader(_ title: String, index: Int = 0) -> some View {
        TaskerFilterSectionHeader(title: title, index: index)
    }

    /// Executes provideHapticFeedback.
    private func provideHapticFeedback() {
        TaskerFeedback.light()
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

    private var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }

    private var safeAreaBottom: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
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
