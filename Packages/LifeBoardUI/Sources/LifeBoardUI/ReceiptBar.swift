import LifeBoardTokens
import SwiftUI

/// What just changed, in the person's words.
///
/// `LifeBoardUI` cannot see the app's `ActionReceipt`, so features map their own
/// receipt type into this at the boundary. That is deliberate rather than
/// unfortunate: it keeps the presentation contract — one sentence, optional
/// detail, optional Undo — independent of whatever the domain happens to record.
public struct ActionReceiptPresentation: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// One plain sentence naming what changed. Not a status ("Success"), and not
    /// internal vocabulary — `DESIGN.md`: "A receipt names what changed."
    public let message: String
    /// Optional second line: where it went, when it lands.
    public let detail: String?

    public init(id: UUID = UUID(), message: String, detail: String? = nil) {
        self.id = id
        self.message = message
        self.detail = detail
    }
}

/// The receipt that follows a consequential action.
///
/// There were at least six hand-rolled versions of this bar in the app — in the
/// composer, the placement sheet, the tracker commit path, Plan's project
/// templates, the fasting end state, the goal transition — each with its own
/// padding, its own dismiss behaviour, and its own answer to whether Undo is a
/// button or a link. Consolidating them matters most for the part that is easy
/// to get wrong quietly: Undo has to stay reachable for as long as reversal is
/// actually supported, and it must never be the thing that auto-dismisses.
public struct ReceiptBar: View {
    private let presentation: ActionReceiptPresentation
    private let undo: (() -> Void)?
    private let onDismiss: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        _ presentation: ActionReceiptPresentation,
        undo: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.undo = undo
        self.onDismiss = onDismiss
    }

    public var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("lifeboard.receipt")
    }

    @ViewBuilder
    private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                message
                HStack(spacing: 10) { actions }
            }
        } else {
            HStack(spacing: 10) {
                message
                Spacer(minLength: 8)
                actions
            }
        }
    }

    private var message: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(presentation.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .fixedSize(horizontal: false, vertical: true)
            if let detail = presentation.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actions: some View {
        if let undo {
            Button("Undo") {
                // Reversal is the action; the receipt disappearing is a
                // consequence of it, so the haptic belongs to the undo and the
                // dismissal follows.
                Haptic.decline.play()
                undo()
                onDismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            .frame(minHeight: 44)
            .buttonStyle(.plain)
            .lifeBoardPressResponse(.control, haptic: nil)
            .accessibilityIdentifier("lifeboard.receipt.undo")
        }

        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss receipt")
        .accessibilityIdentifier("lifeboard.receipt.dismiss")
    }
}

/// Presents a receipt above the host's bottom edge.
///
/// A `ViewModifier` rather than a bare `View` extension so it can read
/// `accessibilityReduceMotion` — an extension would have to hardcode a value and
/// would animate the bar in for someone who asked it not to.
private struct ReceiptPresenter: ViewModifier {
    @Binding var presentation: ActionReceiptPresentation?
    let undo: ((ActionReceiptPresentation) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let value = presentation {
                    ReceiptBar(
                        value,
                        undo: undo.map { action in { action(value) } },
                        onDismiss: { presentation = nil }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(
                InteractionMotion.sheetRise(reduceMotion: reduceMotion),
                value: presentation?.id
            )
    }
}

public extension View {
    /// Presents a receipt above this view's bottom edge.
    ///
    /// Deliberately no auto-dismiss timer. A receipt that vanishes on its own
    /// takes Undo with it, which turns a reversible action into an irreversible
    /// one for anyone reading at their own pace — and `DESIGN.md` requires Undo
    /// to be exposed wherever reversal is supported.
    func lifeBoardReceipt(
        _ presentation: Binding<ActionReceiptPresentation?>,
        undo: ((ActionReceiptPresentation) -> Void)? = nil
    ) -> some View {
        modifier(ReceiptPresenter(presentation: presentation, undo: undo))
    }
}
