import SwiftUI
import UIKit

/// Derives `\.lifeboardLayoutClass` (and the token set that goes with it) from
/// the width this view is actually given, and keeps it current.
///
/// Before this existed nothing live set the layout class, so it stayed at its
/// `.phone` default and every `layoutClass.isPad` branch and readable-width cap
/// was dead on iPad and Mac. It is applied wherever a SwiftUI root is hosted:
/// the shell, UIKit-hosted screens, and presented sheets (a form sheet is
/// narrower than its window and re-derives its own class).
///
/// Only the class is stored, so the environment changes when a breakpoint is
/// crossed and not on every point of a Split View or Mac window drag. It is a
/// modifier rather than a branch: content keeps its identity and `@State`.
public struct LiveLayoutEnvironment: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var layoutClass: LayoutClass

    public init(initial: LayoutClass) {
        _layoutClass = State(initialValue: initial)
    }

    public func body(content: Content) -> some View {
        let sizeClass = horizontalSizeClass.map(UIUserInterfaceSizeClass.init)
        let platform = InterfacePlatform.resolve(idiom: UIDevice.current.userInterfaceIdiom)
        content
            .environment(\.lifeboardLayoutClass, layoutClass)
            .environment(\.lifeboardTokens, ThemeStore.tokens(for: layoutClass))
            .onGeometryChange(for: LayoutClass.self) { proxy in
                LayoutResolver.classify(
                    width: proxy.size.width,
                    horizontalSizeClass: sizeClass,
                    platform: platform
                )
            } action: { newValue in
                if layoutClass != newValue { layoutClass = newValue }
            }
    }
}

public extension View {
    /// See `LiveLayoutEnvironment`.
    func lifeboardLiveLayoutEnvironment(initial: LayoutClass = .phone) -> some View {
        modifier(LiveLayoutEnvironment(initial: initial))
    }
}
