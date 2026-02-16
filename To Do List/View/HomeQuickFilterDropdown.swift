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

    let onShowDatePicker: () -> Void
    let onShowAdvancedFilters: () -> Void

    // MARK: - State

    @State private var isVisible = false

    // MARK: - Tokens

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    // MARK: - Initialization

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
                Color.black.opacity(0.3)
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    // MARK: - Dropdown Content

    private var dropdownContent: some View {
        VStack(spacing: 0) {
            // Header with close button
            headerView

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Quick View Section
                    quickViewSection

                    divider

                    // Date Section
                    dateSection

                    divider

                    // Projects Section
                    projectsSection

                    // Grouping Section (only for Today/customDate)
                    if shouldShowGrouping {
                        divider
                        groupingSection
                    }

                    divider

                    // Saved Views Section
                    savedViewsSection

                    divider

                    // Advanced Filters Row
                    advancedFiltersRow
                }
            }
            .maxHeight(screenHeight * 0.6)

            // Reset Button
            resetButton
        }
        .background(
            RoundedRectangle(cornerRadius: corner.modal)
                .fill(Color.tasker.surfacePrimary)
        )
        .taskerElevation(.e3, cornerRadius: corner.modal, includesBorder: false)
        .padding(.horizontal, spacing.s16)
        .padding(.bottom, safeAreaBottom + spacing.s16)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Spacer()

            VStack(spacing: spacing.s8) {
                // Handle indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.tasker.textQuaternary.opacity(0.4))
                    .frame(width: 40, height: 5)

                Text("Filters")
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)
            }

            Spacer()

            // Close button (positioned absolutely)
            Button {
                dismissWithAnimation()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.tasker.textTertiary)
            }
        }
        .padding(.horizontal, spacing.s20)
        .padding(.top, spacing.s12)
        .padding(.bottom, spacing.s16)
        .overlay(
            Button {
                dismissWithAnimation()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.tasker.textTertiary)
            }
            .padding(.trailing, spacing.s20),
            alignment: .trailing
        )
    }

    // MARK: - Quick View Section

    private var quickViewSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Quick View")

            ForEach(HomeQuickView.allCases, id: \.rawValue) { quickView in
                FilterRow(
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
            sectionHeader("Date")

            FilterRow(
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
            sectionHeader("Projects")

            // All Projects option
            FilterRow(
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
                FilterRow(
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
            sectionHeader("Grouping")

            ForEach(HomeProjectGroupingMode.allCases, id: \.rawValue) { mode in
                FilterRow(
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
            sectionHeader("Saved Views")

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
        FilterRow(
            title: "Advanced Filters",
            subtitle: advancedFiltersSubtitle,
            isSelected: viewModel.activeFilterState.advancedFilter != nil,
            systemImage: "slider.horizontal.3"
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
            Text("Reset All Filters")
                .font(.tasker(.bodyEmphasis))
                .foregroundColor(Color.tasker.statusDanger)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: corner.r3)
                        .fill(Color.tasker.surfaceSecondary)
                )
        }
        .buttonStyle(.plain)
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.tasker(.caption1))
            .foregroundColor(Color.tasker.textSecondary)
            .padding(.horizontal, spacing.s20)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s8)
    }

    private func provideHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    private func dismissWithAnimation() {
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

// MARK: - Filter Row

/// A single row in the filter dropdown.
struct FilterRow: View {

    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var count: Int? = nil
    var isMultiSelect: Bool = false
    var systemImage: String? = nil
    let action: () -> Void

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        Button(action: {
            action()
        }) {
            HStack(spacing: spacing.s12) {
                // Selection indicator
                if isMultiSelect {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundColor(isSelected ? Color.tasker.accentPrimary : Color.tasker.textTertiary)
                }

                // Optional system image
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16))
                        .foregroundColor(Color.tasker.textSecondary)
                }

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.tasker(.callout))
                        .foregroundColor(Color.tasker.textPrimary)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.tasker(.caption2))
                            .foregroundColor(Color.tasker.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Count badge
                if let count = count {
                    Text("\(count)")
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .padding(.horizontal, spacing.s8)
                        .padding(.vertical, spacing.s2)
                        .background(
                            Capsule()
                                .fill(Color.tasker.surfaceSecondary)
                        )
                }

                // Chevron for navigation rows
                if systemImage != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.tasker.textTertiary)
                }
            }
            .padding(.horizontal, spacing.s20)
            .padding(.vertical, spacing.s12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelected ? "Selected" : "Not selected")
    }

    private var accessibilityLabel: String {
        var label = title
        if let count = count {
            label += ", \(count) items"
        }
        if isSelected {
            label += ", selected"
        }
        return label
    }
}

// MARK: - View Extension for Max Height

extension View {
    func maxHeight(_ maxHeight: CGFloat) -> some View {
        self.modifier(MaxHeightModifier(maxHeight: maxHeight))
    }
}

struct MaxHeightModifier: ViewModifier {
    let maxHeight: CGFloat

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
