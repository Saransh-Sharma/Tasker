import Foundation
import Observation
import SwiftUI

/// Eva's receipt slot: one `ReceiptBar` above the composer.
///
/// Chat was the one surface that changed things with no receipt at all.
/// Applying a proposal left a caption inside the card, and deleting a chat or
/// rewriting a thread with "Edit and resend" could not be taken back. Every
/// reversible change in Eva now reports here, and Undo is one tap, at the
/// same place, whichever message or list caused it.
///
/// A receipt that is replaced or dismissed runs `onSettle`. That is where a
/// soft delete becomes permanent, so nothing is destroyed while its Undo is
/// still on screen.
@MainActor
@Observable
final class EvaChatReceiptCenter {
    struct Receipt: Identifiable {
        let id = UUID()
        let message: String
        var detail: String?
        /// `nil` when the change cannot be reversed.
        var undo: (() async -> Bool)?
        /// Runs once when the receipt leaves without Undo.
        var onSettle: (() -> Void)?
    }

    /// One center for the app: the chats list, the transcript and the
    /// composer are separate hosts, and all of them report to the same slot.
    static let shared = EvaChatReceiptCenter()

    private(set) var current: Receipt?

    /// Chats deleted but still undoable: hidden from the list, not yet gone.
    var pendingDeletedThreadIDs: Set<UUID> = []

    func show(_ receipt: Receipt) {
        settleCurrent()
        current = receipt
        AccessibilityNotification.Announcement(
            ActionReceiptPresentation.announcement(message: receipt.message, canUndo: receipt.undo != nil)
        ).post()
    }

    func dismiss() {
        settleCurrent()
        current = nil
    }

    /// `false` when the undo did not take; the receipt is gone either way,
    /// because its action has been attempted.
    @discardableResult
    func undo() async -> Bool {
        guard let receipt = current, let undo = receipt.undo else { return false }
        current = nil
        return await undo()
    }

    private func settleCurrent() {
        guard let receipt = current else { return }
        current = nil
        receipt.onSettle?()
    }
}

/// Draws the center's receipt. Hold the instance in `@State` so reads of
/// `current` are observed: a static read would not be.
struct EvaChatReceiptSlot: View {
    @State private var center = EvaChatReceiptCenter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let receipt = center.current {
                ReceiptBar(
                    ActionReceiptPresentation(id: receipt.id, message: receipt.message, detail: receipt.detail),
                    undo: receipt.undo == nil ? nil : {
                        Task {
                            if await center.undo() == false { Haptic.fail.play() }
                        }
                    },
                    destination: nil,
                    onDismiss: { center.dismiss() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("eva.chat.receipt")
            }
        }
        .animation(InteractionMotion.sheetRise(reduceMotion: reduceMotion), value: center.current?.id)
    }
}
