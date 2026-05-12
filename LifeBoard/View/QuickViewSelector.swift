//
//  QuickViewSelector.swift
//  LifeBoard
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
    @Environment(\.colorScheme) private var colorScheme

    /// Initializes a new instance.
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
                    LifeBoardFeedback.selection()
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
                .accessibilityIdentifier("home.focus.menu.option.\(quickView.rawValue)")
            }

            if onShowDatePicker != nil || onShowAdvancedFilters != nil || onResetFilters != nil {
                Section("Filters") {
                    if let onShowDatePicker {
                        Button {
                            onShowDatePicker()
                            LifeBoardFeedback.selection()
                        } label: {
                            Label("Select date...", systemImage: "calendar")
                        }
                        .accessibilityIdentifier("home.focus.menu.datePicker")
                    }

                    if let onShowAdvancedFilters {
                        Button {
                            onShowAdvancedFilters()
                            LifeBoardFeedback.selection()
                        } label: {
                            Label("Advanced filters", systemImage: "slider.horizontal.3")
                        }
                        .accessibilityIdentifier("home.focus.menu.advanced")
                    }

                    if let onResetFilters {
                        Button(role: .destructive) {
                            onResetFilters()
                            LifeBoardFeedback.selection()
                        } label: {
                            Label("Reset filters", systemImage: "line.3.horizontal.decrease.circle")
                        }
                        .accessibilityIdentifier("home.focus.menu.reset")
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(selectionTint.opacity(colorScheme == .dark ? 0.24 : 0.16))
                        .frame(width: 28, height: 28)

                    Image(systemName: iconName(for: selectedQuickView))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selectionTint)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Focus view")
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color.lifeboard.textTertiary)

                    Text(selectedQuickView.title)
                        .font(.lifeboard(.callout))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard.textPrimary)
                }

                if let count = taskCounts?[selectedQuickView] {
                    Text("\(count)")
                        .font(.lifeboard(.caption1))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.lifeboard.surfacePrimary.opacity(colorScheme == .dark ? 0.58 : 0.92))
                        )
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .rotationEffect(.degrees(2))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .lifeboardChromeSurface(
                cornerRadius: 22,
                accentColor: selectionTint,
                level: .e1
            )
            .contentShape(Capsule(style: .continuous))
            .scaleOnPress()
        }
        .menuStyle(.borderlessButton)
        .accessibilityIdentifier("home.focus.menu.button")
        .accessibilityLabel("Quick view selector: \(selectedQuickView.title)")
        .accessibilityHint("Double tap to change view")
    }

    private var selectionTint: Color {
        switch selectedQuickView {
        case .overdue:
            return Color.lifeboard.statusWarning
        case .done:
            return Color.lifeboard.statusSuccess
        case .morning:
            return Color.lifeboard.accentPrimary
        case .evening:
            return Color.lifeboard.accentSecondary
        case .today, .upcoming:
            return Color.lifeboard.accentPrimary
        }
    }

    private func iconName(for quickView: HomeQuickView) -> String {
        switch quickView {
        case .today: return "sun.max.fill"
        case .upcoming: return "calendar.badge.clock"
        case .overdue: return "flame.fill"
        case .done: return "checkmark.circle.fill"
        case .morning: return "sunrise.fill"
        case .evening: return "moon.stars.fill"
        }
    }
}

// MARK: - Compact Nav Selector

/// Ultra-compact selector for tight navigation bar spaces.
public struct CompactNavSelector: View {
    @Binding var selectedQuickView: HomeQuickView
    var onSelect: ((HomeQuickView) -> Void)? = nil

    /// Initializes a new instance.
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
                    LifeBoardFeedback.selection()
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
            .foregroundStyle(Color.lifeboard.textPrimary)
            .frame(width: 38, height: 38)
            .lifeboardChromeSurface(
                cornerRadius: 19,
                accentColor: Color.lifeboard.accentSecondary,
                level: .e1
            )
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("View: \(selectedQuickView.title)")
    }

    /// Executes iconName.
    private func iconName(for quickView: HomeQuickView) -> String {
        switch quickView {
        case .today: return "sun.max"
        case .upcoming: return "calendar"
        case .overdue: return "exclamationmark.triangle"
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
        .background(Color.lifeboard.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
