import SwiftUI

/// Exact-value adapters used while legacy feature styling is moved behind the
/// shared UI boundary. These preserve rendered output; callers should prefer
/// semantic typography and elevation tokens whenever an exact match exists.
public extension View {
    func lifeboardCompatibilityShadow(
        color: Color,
        radius: CGFloat,
        x: CGFloat = 0,
        y: CGFloat = 0
    ) -> some View {
        shadow(color: color, radius: radius, x: x, y: y)
    }

    func lifeboardCompatibilitySystemFont(
        size: CGFloat,
        weight: Font.Weight = .regular
    ) -> some View {
        font(.system(size: size, weight: weight))
    }
}
