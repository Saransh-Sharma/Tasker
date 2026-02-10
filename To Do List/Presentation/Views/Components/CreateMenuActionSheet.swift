//
//  CreateMenuActionSheet.swift
//  Tasker
//
//  Action sheet for FAB create menu with options to create Task, Habit, or Life Area.
//

import SwiftUI

// MARK: - Create Action Type

/// Type of item to create
public enum CreateActionType: String, CaseIterable, Identifiable {
    case task
    case habit
    case lifeArea

    public var id: String { rawValue }

    /// Display title
    public var title: String {
        switch self {
        case .task: return "New Task"
        case .habit: return "New Habit"
        case .lifeArea: return "New Life Area"
        }
    }

    /// SF Symbol icon name
    public var iconName: String {
        switch self {
        case .task: return "checkmark.circle.fill"
        case .habit: return "flame.fill"
        case .lifeArea: return "circle.grid.2x2.fill"
        }
    }

    /// Accent color
    public var color: Color {
        switch self {
        case .task: return TaskerTheme.Colors.coral
        case .habit: return TaskerTheme.Colors.LifeAreaColors.gold
        case .lifeArea: return TaskerTheme.Colors.purple
        }
    }

    /// Description subtitle
    public var description: String {
        switch self {
        case .task: return "Add a one-time or recurring task"
        case .habit: return "Build a daily streak"
        case .lifeArea: return "Organize tasks by life area"
        }
    }
}

// MARK: - Create Menu Callback

/// Callback when user selects a create action
public typealias CreateActionCallback = (CreateActionType) -> Void

// MARK: - CreateMenuActionSheet

/// Action sheet that appears when FAB is tapped
/// Shows options to create Task, Habit, or Life Area
public struct CreateMenuActionSheet: View {

    // MARK: - Properties

    private let onActionSelected: CreateActionCallback
    private let onDismiss: () -> Void

    // MARK: - State

    @State private var isVisible = false
    @State private var selectedItem: CreateActionType?

    // MARK: - Initialization

    /// Create a menu action sheet
    /// - Parameters:
    ///   - onActionSelected: Callback when user selects an action type
    ///   - onDismiss: Callback when sheet is dismissed
    public init(
        onActionSelected: @escaping CreateActionCallback,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.onActionSelected = onActionSelected
        self.onDismiss = onDismiss
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

                // Menu content
                if isVisible {
                    menuContent
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            // Animate in on appear
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isVisible = true
            }
        }
    }

    // MARK: - Menu Content

    private var menuContent: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Action buttons
            VStack(spacing: 12) {
                ForEach(CreateActionType.allCases) { actionType in
                    actionButton(for: actionType)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Cancel button
            cancelButton
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(TaskerTheme.Colors.cardBackground)
        )
        .taskerElevation(.e3, cornerRadius: 28)
        .padding(.horizontal, 16)
        .padding(.bottom, safeAreaBottom + 16)
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(spacing: 8) {
            // Handle indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(TaskerTheme.Colors.textTertiary.opacity(0.4))
                .frame(width: 40, height: 5)

            // Title
            Text("Create New")
                .font(.tasker(.title2))
                .foregroundColor(TaskerTheme.Colors.textPrimary)

            // Subtitle
            Text("What would you like to create?")
                .font(.tasker(.callout))
                .foregroundColor(TaskerTheme.Colors.textSecondary)
        }
        .padding(.top, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Action Button

    private func actionButton(for actionType: CreateActionType) -> some View {
        Button(action: {
            selectedItem = actionType
            handleActionSelection(actionType)
        }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(actionType.color.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: actionType.iconName)
                        .font(.tasker(.title2))
                        .foregroundColor(actionType.color)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(actionType.title)
                        .font(.tasker(.button))
                        .foregroundColor(TaskerTheme.Colors.textPrimary)

                    Text(actionType.description)
                        .font(.tasker(.caption1))
                        .foregroundColor(TaskerTheme.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.tasker(.buttonSmall))
                    .foregroundColor(TaskerTheme.Colors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(selectedItem == actionType ?
                          actionType.color.opacity(0.1) :
                          TaskerTheme.Colors.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedItem == actionType ?
                           actionType.color.opacity(0.3) :
                           Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(actionType.title)
        .accessibilityHint(actionType.description)
    }

    // MARK: - Cancel Button

    private var cancelButton: some View {
        Button(action: dismissWithAnimation) {
            Text("Cancel")
                .font(.tasker(.bodyEmphasis))
                .foregroundColor(TaskerTheme.Colors.coral)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(TaskerTheme.Colors.background)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .accessibilityLabel("Cancel")
    }

    // MARK: - Actions

    private func handleActionSelection(_ actionType: CreateActionType) {
        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Small delay for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onActionSelected(actionType)
            onDismiss()
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }

    // MARK: - Safe Area

    private var safeAreaBottom: CGFloat {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        return windowScene?.windows.first?.safeAreaInsets.bottom ?? 0
    }
}

// MARK: - Preview

#if DEBUG
struct CreateMenuActionSheet_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            // Background content
            TaskerTheme.Colors.background
                .ignoresSafeArea()

            VStack {
                Text("Create Menu Preview")
                    .font(.title)
                    .foregroundColor(.white)

                Spacer()

                Text("Swipe up or tap to dismiss")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 100)
            }

            // Action sheet overlay
            CreateMenuActionSheet(
                onActionSelected: { action in
                    print("Selected: \(action.title)")
                },
                onDismiss: {
                    print("Dismissed")
                }
            )
        }
        .previewDisplayName("Create Menu Action Sheet")
    }
}
#endif
