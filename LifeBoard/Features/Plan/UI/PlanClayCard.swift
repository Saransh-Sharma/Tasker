import SwiftUI
import UIKit

extension View {
    /// Delegates to the canonical clay depth scale so Plan cards match Home
    /// and Track. This used to carry its own radius-4 shadow and 0.75pt
    /// stroke, which made Plan read subtly flatter than every other root.
    func foundationClayCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
    }
}
