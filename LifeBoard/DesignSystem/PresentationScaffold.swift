import SwiftUI

/// Canonical wrapper for LifeBoard-owned sheets and covers. Apple-owned
/// controllers remain native and are intentionally exempt.
public struct PresentationScaffold<Content: View>: View {
    public let mode: ScreenMode
    public let readableWidth: CGFloat?
    private let content: Content
    @Environment(\.lifeboardLayoutClass) private var presenterLayoutClass

    public init(
        mode: ScreenMode,
        readableWidth: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.mode = mode
        self.readableWidth = readableWidth
        self.content = content()
    }

    public var body: some View {
        ScreenScaffold(
            mode: mode,
            placement: .focusedPresentation,
            bottomClearance: mode == .editor ? 8 : 0,
            readableWidth: readableWidth
        ) {
            content
                .scrollDismissesKeyboard(.interactively)
        }
        // A form sheet is narrower than the window that presents it; it
        // re-derives its own layout class instead of inheriting the window's.
        .lifeboardLiveLayoutEnvironment(initial: presenterLayoutClass)
        .presentationBackground(Color.lifeboard(.bgElevated))
        .presentationCornerRadius(mode == .critical ? 24 : 30)
        .presentationDragIndicator(mode == .critical ? .hidden : .visible)
    }
}
