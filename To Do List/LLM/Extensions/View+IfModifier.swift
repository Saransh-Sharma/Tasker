//
//  View+IfModifier.swift
//  To Do List
//
//  Created to support conditional view modifiers used across the LLM module.
//  Mirrors the helper defined in the original "fullmoon" project.
//

import SwiftUI

public extension View {
    /// Applies the given transform if the condition evaluates to true.
    /// - Parameters:
    ///   - condition: Boolean flag that controls whether the transform is applied.
    ///   - transform: Transform closure returning the modified view.
    /// - Returns: Either the transformed view (when `condition` is `true`) or the original view.
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
