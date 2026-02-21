//
//  TaskerSnackbar.swift
//  Tasker
//
//  Lightweight snackbar overlay with auto-dismiss, action buttons.
//  Slides up from the bottom with spring animation.
//

import SwiftUI

// MARK: - Snackbar Data

struct SnackbarData: Equatable {
    let message: String
    let actions: [SnackbarAction]
    let autoDismissSeconds: TimeInterval

    /// Initializes a new instance.
    init(message: String, actions: [SnackbarAction] = [], autoDismissSeconds: TimeInterval = 5.0) {
        self.message = message
        self.actions = actions
        self.autoDismissSeconds = autoDismissSeconds
    }

    /// Executes ==.
    static func == (lhs: SnackbarData, rhs: SnackbarData) -> Bool {
        lhs.message == rhs.message
    }
}

struct SnackbarAction: Equatable {
    let title: String
    let action: () -> Void

    /// Executes ==.
    static func == (lhs: SnackbarAction, rhs: SnackbarAction) -> Bool {
        lhs.title == rhs.title
    }
}

// MARK: - Snackbar View

struct TaskerSnackbar: View {
    let data: SnackbarData
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        HStack(spacing: spacing.s12) {
            // Message
            Text(data.message)
                .font(.tasker(.callout))
                .foregroundColor(Color.tasker.textPrimary)

            Spacer()

            // Action buttons
            ForEach(data.actions, id: \.title) { action in
                Button {
                    TaskerFeedback.selection()
                    action.action()
                    dismissSnackbar()
                } label: {
                    Text(action.title)
                        .font(.tasker(.callout).weight(.semibold))
                        .foregroundColor(Color.tasker.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: corner.r3)
                .fill(Color.tasker.surfacePrimary)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner.r3)
                .stroke(Color.tasker.strokeHairline, lineWidth: 0.5)
        )
        .padding(.horizontal, spacing.s16)
        .offset(y: isVisible ? dragOffset : 100)
        .opacity(isVisible ? 1 : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 40 {
                        dismissSnackbar()
                    } else {
                        withAnimation(TaskerAnimation.snappy) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(TaskerAnimation.snappy) {
                isVisible = true
            }

            // Auto-dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + data.autoDismissSeconds) {
                dismissSnackbar()
            }
        }
    }

    /// Executes dismissSnackbar.
    private func dismissSnackbar() {
        withAnimation(TaskerAnimation.gentle) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onDismiss()
        }
    }
}

// MARK: - Snackbar Modifier

struct SnackbarModifier: ViewModifier {
    /// Executes body.
    @Binding var snackbar: SnackbarData?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if let data = snackbar {
                TaskerSnackbar(data: data) {
                    snackbar = nil
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(TaskerAnimation.snappy, value: snackbar != nil)
    }
}

extension View {
    /// Executes taskerSnackbar.
    func taskerSnackbar(_ snackbar: Binding<SnackbarData?>) -> some View {
        modifier(SnackbarModifier(snackbar: snackbar))
    }
}
