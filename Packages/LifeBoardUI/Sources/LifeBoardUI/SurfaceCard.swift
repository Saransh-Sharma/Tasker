import LifeBoardTokens
import SwiftUI

/// Warm clay behind an independent object.
///
/// Named `PaperCardModifier`, not `SurfaceCard`: `LifeBoardTokens` exports a
/// `public struct SurfaceCard<Content: View>: View` and this file exported a
/// `public struct SurfaceCard: ViewModifier`. Both are visible in every file
/// that imports both modules, so which one `SurfaceCard` meant depended on
/// import order. The public entry point here was always `lifeBoardPaperCard()`,
/// so renaming the type costs no call site.
public struct PaperCardModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
    }
}

public extension View {
    func lifeBoardPaperCard() -> some View {
        modifier(PaperCardModifier())
    }
}
