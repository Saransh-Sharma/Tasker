import LifeBoardTokens
import SwiftUI

/// What a presented surface is, independent of the device it lands on.
public enum LifeBoardPresentationKind: Equatable, Sendable {
    /// A short form or picker: a form sheet on iPad and Mac.
    case form
    /// A full document or workspace: a page sheet on iPad and Mac.
    case page
    /// Holds attention on its own (a routine runner, a mood dial, a ritual).
    /// Full screen on iPhone; a page sheet at pad widths, where covering a
    /// 13-inch display or a whole Mac window for one dial is not immersion but
    /// a lost context.
    case immersive
}

public enum LifeBoardPresentationStyle: Equatable, Sendable {
    case sheet(LifeBoardSheetSizing)
    case fullScreenCover
}

public enum LifeBoardSheetSizing: Equatable, Sendable {
    case form
    case page
}

public enum LifeBoardPresentationPolicy {
    public static func style(
        kind: LifeBoardPresentationKind,
        layoutClass: LayoutClass
    ) -> LifeBoardPresentationStyle {
        switch kind {
        case .form:
            return .sheet(.form)
        case .page:
            return .sheet(.page)
        case .immersive:
            return layoutClass.isPad ? .sheet(.page) : .fullScreenCover
        }
    }
}

public extension View {
    /// A cover that adapts to the width it is presented at — see
    /// `LifeBoardPresentationKind`.
    ///
    /// Both presentations are attached, each behind its own gated binding, so
    /// the choice never becomes a branch that re-identifies the presenter. The
    /// style is latched when the presentation opens: a window resize while it
    /// is up cannot dismiss it and bring it back as the other kind.
    func lifeboardCover<Content: View>(
        isPresented: Binding<Bool>,
        kind: LifeBoardPresentationKind = .immersive,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(
            AdaptiveCoverModifier(
                isPresented: isPresented,
                kind: kind,
                onDismiss: onDismiss,
                coverContent: content
            )
        )
    }

    /// The item-driven form of `lifeboardCover(isPresented:)`.
    func lifeboardCover<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        kind: LifeBoardPresentationKind = .immersive,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        let isPresented = Binding<Bool>(
            get: { item.wrappedValue != nil },
            set: { if $0 == false { item.wrappedValue = nil } }
        )
        return lifeboardCover(isPresented: isPresented, kind: kind, onDismiss: onDismiss) {
            if let value = item.wrappedValue {
                content(value)
            }
        }
    }
}

private struct AdaptiveCoverModifier<CoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let kind: LifeBoardPresentationKind
    let onDismiss: (() -> Void)?
    let coverContent: () -> CoverContent

    @Environment(\.lifeboardLayoutClass) private var layoutClass
    @State private var latchedStyle: LifeBoardPresentationStyle?

    private var style: LifeBoardPresentationStyle {
        latchedStyle ?? LifeBoardPresentationPolicy.style(kind: kind, layoutClass: layoutClass)
    }

    private func binding(for target: LifeBoardPresentationStyle) -> Binding<Bool> {
        Binding(
            get: { isPresented && isSameKind(style, target) },
            set: { newValue in
                guard newValue == false, isSameKind(style, target) else { return }
                isPresented = false
            }
        )
    }

    private func isSameKind(_ lhs: LifeBoardPresentationStyle, _ rhs: LifeBoardPresentationStyle) -> Bool {
        switch (lhs, rhs) {
        case (.fullScreenCover, .fullScreenCover), (.sheet, .sheet): true
        default: false
        }
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: binding(for: .sheet(.page)), onDismiss: onDismiss) {
                coverContent()
                    .modifier(SheetSizingModifier(style: style))
            }
            .fullScreenCover(isPresented: binding(for: .fullScreenCover), onDismiss: onDismiss) {
                coverContent()
            }
            .onChange(of: isPresented, initial: true) { _, presented in
                latchedStyle = presented
                    ? LifeBoardPresentationPolicy.style(kind: kind, layoutClass: layoutClass)
                    : nil
            }
    }
}

private struct SheetSizingModifier: ViewModifier {
    let style: LifeBoardPresentationStyle

    func body(content: Content) -> some View {
        switch style {
        case .sheet(.form):
            content.presentationSizing(.form)
        case .sheet(.page), .fullScreenCover:
            content.presentationSizing(.page)
        }
    }
}
