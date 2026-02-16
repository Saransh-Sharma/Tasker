//
//  QuickViewSelector.swift
//  Tasker
//
//  Navigation bar dropdown for quick view selection.
//  Compact design for seamless nav bar integration.
//

import SwiftUI

// MARK: - Quick View Selector

/// Compact dropdown selector for quick views in navigation bar.
public struct QuickViewSelector: View {
    @Binding var selectedQuickView: HomeQuickView
    var taskCounts: [HomeQuickView: Int]? = nil
    var onSelect: ((HomeQuickView) -> Void)? = nil
    var onShowDatePicker: (() -> Void)? = nil
    var onShowAdvancedFilters: (() -> Void)? = nil
    var onResetFilters: (() -> Void)? = nil

    public init(
        selectedQuickView: Binding<HomeQuickView>,
        taskCounts: [HomeQuickView: Int]? = nil,
        onSelect: ((HomeQuickView) -> Void)? = nil,
        onShowDatePicker: (() -> Void)? = nil,
        onShowAdvancedFilters: (() -> Void)? = nil,
        onResetFilters: (() -> Void)? = nil
    ) {
        self._selectedQuickView = selectedQuickView
        self.taskCounts = taskCounts
        self.onSelect = onSelect
        self.onShowDatePicker = onShowDatePicker
        self.onShowAdvancedFilters = onShowAdvancedFilters
        self.onResetFilters = onResetFilters
    }

    public var body: some View {
        Menu {
            ForEach(HomeQuickView.allCases, id: \.rawValue) { quickView in
                Button {
                    selectedQuickView = quickView
                    onSelect?(quickView)
                    TaskerFeedback.selection()
                } label: {
                    HStack {
                        Text(quickView.title)
                        Spacer()
                        if let count = taskCounts?[quickView] {
                            Text("\(count)")
                                .foregroundColor(.secondary)
                        }
                        if quickView == selectedQuickView {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if onShowDatePicker != nil || onShowAdvancedFilters != nil || onResetFilters != nil {
                Section("Filters") {
                    if let onShowDatePicker {
                        Button {
                            onShowDatePicker()
                            TaskerFeedback.selection()
                        } label: {
                            Label("Select date...", systemImage: "calendar")
                        }
                    }

                    if let onShowAdvancedFilters {
                        Button {
                            onShowAdvancedFilters()
                            TaskerFeedback.selection()
                        } label: {
                            Label("Advanced filters", systemImage: "slider.horizontal.3")
                        }
                    }

                    if let onResetFilters {
                        Button(role: .destructive) {
                            onResetFilters()
                            TaskerFeedback.selection()
                        } label: {
                            Label("Reset filters", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(selectedQuickView.title)
                    .font(.tasker(.headline))
                    .foregroundColor(Color.tasker.textPrimary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.tasker.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.tasker.surfaceSecondary.opacity(0.5))
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Quick view selector: \(selectedQuickView.title)")
        .accessibilityHint("Double tap to change view")
    }
}

// MARK: - Compact Nav Selector

/// Ultra-compact selector for tight navigation bar spaces.
public struct CompactNavSelector: View {
    @Binding var selectedQuickView: HomeQuickView
    var onSelect: ((HomeQuickView) -> Void)? = nil

    @State private var isExpanded = false

    public init(
        selectedQuickView: Binding<HomeQuickView>,
        onSelect: ((HomeQuickView) -> Void)? = nil
    ) {
        self._selectedQuickView = selectedQuickView
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            ForEach(HomeQuickView.allCases, id: \.rawValue) { quickView in
                Button {
                    selectedQuickView = quickView
                    onSelect?(quickView)
                    TaskerFeedback.selection()
                } label: {
                    Label {
                        Text(quickView.title)
                    } icon: {
                        Image(systemName: iconName(for: quickView))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: iconName(for: selectedQuickView))
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(Color.tasker.textPrimary)
            .padding(6)
            .background(
                Circle()
                    .fill(Color.tasker.surfaceSecondary)
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("View: \(selectedQuickView.title)")
    }

    private func iconName(for quickView: HomeQuickView) -> String {
        switch quickView {
        case .today: return "sun.max"
        case .upcoming: return "calendar"
        case .done: return "checkmark.circle"
        case .morning: return "sunrise"
        case .evening: return "moon"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct QuickViewSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Standard selector
            QuickViewSelector(
                selectedQuickView: .constant(.today),
                taskCounts: [.today: 5, .upcoming: 12, .done: 8]
            )

            // Compact selector
            HStack(spacing: 16) {
                CompactNavSelector(selectedQuickView: .constant(.today))
                CompactNavSelector(selectedQuickView: .constant(.upcoming))
                CompactNavSelector(selectedQuickView: .constant(.done))
            }
        }
        .padding()
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
