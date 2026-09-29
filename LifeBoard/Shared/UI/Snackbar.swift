//
//  Snackbar.swift
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

    /// A snackbar carrying actions stays until it is dismissed.
    ///
    /// The default 5-second timer took Undo with it, which turns a reversible
    /// action into an irreversible one for anyone reading at their own pace.
    /// `DESIGN.md` requires Undo to stay exposed while reversal is supported, so
    /// only a message-only snackbar auto-dismisses. Pass `autoDismissSeconds`
    /// explicitly to override either way.
    init(id: UUID = UUID(), message: String, actions: [SnackbarAction] = [], autoDismissSeconds: TimeInterval? = nil) {
        self.id = id
        self.message = message
        self.actions = actions
        self.autoDismissSeconds = autoDismissSeconds ?? (actions.isEmpty ? 5.0 : 0)
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

/// Receipt-style confirmation surface, drawn by the shared `ReceiptBar`.
///
/// This was the last hand-rolled receipt: a callout-sized row with its own
/// corner radius, no dismiss control, and actions in a fixed `HStack` that
/// competed with the message at accessibility sizes. It now renders the one
/// receipt silhouette the rest of the app uses. An "Undo" action becomes the
/// bar's Undo (played with `Haptic.decline`), any other single action its
/// destination. Only a message-only receipt still folds on its own.
struct ReceiptToast: View {
    let data: SnackbarData
    let onDismiss: () -> Void

    @State private var autoDismissTask: Task<Void, Never>?

    private var undoAction: SnackbarAction? {
        data.actions.first { $0.title.caseInsensitiveCompare("Undo") == .orderedSame }
    }

    private var destinationAction: SnackbarAction? {
        data.actions.first { $0.title.caseInsensitiveCompare("Undo") != .orderedSame }
    }

    var body: some View {
        ReceiptBar(
            ActionReceiptPresentation(id: data.id, message: data.message),
            undo: undoAction.map { action in
                {
                    action.action()
                    dismiss()
                }
            },
            destination: destinationAction.map { action in
                ReceiptBar.Destination(title: action.title) {
                    action.action()
                    dismiss()
                }
            },
            onDismiss: dismiss
        )
        .padding(.horizontal, 16)
        .onAppear {
            UIAccessibility.post(notification: .announcement, argument: data.message)
            autoDismissTask?.cancel()
            // Zero means "stays until dismissed" — see `SnackbarData.init`.
            if data.autoDismissSeconds > 0 {
                autoDismissTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(data.autoDismissSeconds))
                    guard Task.isCancelled == false else { return }
                    dismiss()
                }
            }
        }
        .onDisappear { autoDismissTask?.cancel() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lifeboard.snackbar")
    }

    private func dismiss() {
        autoDismissTask?.cancel()
        onDismiss()
    }
}

struct Snackbar: View {
    let data: SnackbarData
    let onDismiss: () -> Void

    var body: some View {
        ReceiptToast(data: data, onDismiss: onDismiss)
    }
}

// MARK: - Snackbar Modifier

struct SnackbarModifier: ViewModifier {
    /// Executes body.
    @Binding var snackbar: SnackbarData?
    var bottomPadding: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if let data = snackbar {
                Snackbar(data: data) {
                    snackbar = nil
                }
                .id(data.id)
                .padding(.bottom, bottomPadding)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .animation(InteractionMotion.sheetRise(reduceMotion: reduceMotion), value: snackbar?.id)
    }
}

extension View {
    /// Executes lifeboardSnackbar.
    func lifeboardSnackbar(_ snackbar: Binding<SnackbarData?>, bottomPadding: CGFloat = 0) -> some View {
        modifier(SnackbarModifier(snackbar: snackbar, bottomPadding: bottomPadding))
    }
}
