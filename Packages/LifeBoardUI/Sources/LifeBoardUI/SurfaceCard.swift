import LifeBoardTokens
import SwiftUI

public struct SurfaceCard: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
    }
}

public extension View {
    func lifeBoardPaperCard() -> some View {
        modifier(SurfaceCard())
    }
}
