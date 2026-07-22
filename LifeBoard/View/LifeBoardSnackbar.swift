//
//  LifeBoardSnackbar.swift
//  LifeBoard
//
//  Lightweight snackbar overlay with auto-dismiss, action buttons.
//  Slides up from the bottom with spring animation.
//

import SwiftUI
import UIKit

// MARK: - Snackbar Data

struct SnackbarData: Equatable {
    let id: UUID
    let message: String
    let actions: [SnackbarAction]
    let autoDismissSeconds: TimeInterval

    /// Initializes a new instance.
    init(id: UUID = UUID(), message: String, actions: [SnackbarAction] = [], autoDismissSeconds: TimeInterval = 5.0) {
        self.id = id
        self.message = message
        self.actions = actions
        self.autoDismissSeconds = autoDismissSeconds
    }

    /// Executes ==.
    static func == (lhs: SnackbarData, rhs: SnackbarData) -> Bool {
        lhs.id == rhs.id
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

/// Receipt-style confirmation surface. It stays above keyboard-safe content,
/// announces its message once, and keeps Undo visible for the full receipt
/// window. `LifeBoardSnackbar` remains as the compatibility wrapper used by
/// existing feature views.
struct LifeBoardReceiptToast: View {
    let data: SnackbarData
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0
    @State private var autoDismissTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    var body: some View {
        HStack(spacing: spacing.s12) {
            // Message
            Text(data.message)
                .font(.lifeboard(.callout))
                .foregroundStyle(Color.lifeboard.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            // Action buttons
            ForEach(data.actions, id: \.title) { action in
                Button {
                    LifeBoardFeedback.selection()
                    action.action()
                    dismissSnackbar()
                } label: {
                    Text(action.title)
                        .font(.lifeboard(.callout).weight(.semibold))
                        .foregroundStyle(Color.lifeboard.accentPrimary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("lifeboard.snackbar.action.\(action.title.lowercased().replacingOccurrences(of: " ", with: "_"))")
            }
        }
        .padding(.horizontal, spacing.s16)
        .padding(.vertical, spacing.s12)
        .background(
            RoundedRectangle(cornerRadius: corner.r3)
                .fill(Color.lifeboard.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: corner.r3)
                .stroke(Color.lifeboard.strokeHairline, lineWidth: 0.5)
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
                        withAnimation(reduceMotion ? nil : LifeBoardAnimation.roleLocalState) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(reduceMotion ? nil : LifeBoardAnimation.roleRoute) {
                isVisible = true
            }
            UIAccessibility.post(notification: .announcement, argument: data.message)
            autoDismissTask?.cancel()
            autoDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(data.autoDismissSeconds))
                guard Task.isCancelled == false else { return }
                dismissSnackbar()
            }
        }
        .onDisappear { autoDismissTask?.cancel() }
        .accessibilityIdentifier("lifeboard.snackbar")
    }

    /// Executes dismissSnackbar.
    private func dismissSnackbar() {
        autoDismissTask?.cancel()
        withAnimation(reduceMotion ? nil : LifeBoardAnimation.roleRoute) {
            isVisible = false
        }
        Task { @MainActor in
            if reduceMotion == false {
                try? await Task.sleep(for: .milliseconds(360))
            }
            onDismiss()
        }
    }
}

struct LifeBoardSnackbar: View {
    let data: SnackbarData
    let onDismiss: () -> Void

    var body: some View {
        LifeBoardReceiptToast(data: data, onDismiss: onDismiss)
    }
}

// MARK: - Snackbar Modifier

struct SnackbarModifier: ViewModifier {
    /// Executes body.
    @Binding var snackbar: SnackbarData?
    var bottomPadding: CGFloat = 0

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if let data = snackbar {
                LifeBoardSnackbar(data: data) {
                    snackbar = nil
                }
                .id(data.id)
                .padding(.bottom, bottomPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(LifeBoardAnimation.snappy, value: snackbar != nil)
    }
}

extension View {
    /// Executes lifeboardSnackbar.
    func lifeboardSnackbar(_ snackbar: Binding<SnackbarData?>, bottomPadding: CGFloat = 0) -> some View {
        modifier(SnackbarModifier(snackbar: snackbar, bottomPadding: bottomPadding))
    }
}
