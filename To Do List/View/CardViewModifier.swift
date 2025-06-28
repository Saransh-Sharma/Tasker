//
//  CardViewModifier.swift
//  To Do List
//
//  Created by Assistant on Card View Implementation
//

import SwiftUI
import UIKit

// MARK: - Basic Card View Modifier
struct CardViewModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let shadowOpacity: Double
    
    init(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: 2),
        shadowOpacity: Double = 0.1
    ) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.shadowOpacity = shadowOpacity
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: Color.black.opacity(shadowOpacity),
                        radius: shadowRadius,
                        x: shadowOffset.width,
                        y: shadowOffset.height
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Themed Card View Modifier
struct ThemedCardViewModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let shadowOpacity: Double
    let useThemeColors: Bool
    
    init(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: 2),
        shadowOpacity: Double = 0.1,
        useThemeColors: Bool = true
    ) {
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
        self.shadowOpacity = shadowOpacity
        self.useThemeColors = useThemeColors
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundGradient)
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: shadowOffset.width,
                        y: shadowOffset.height
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    private var backgroundGradient: LinearGradient {
        if useThemeColors {
            return LinearGradient(
                gradient: Gradient(colors: [
                    Color(ToDoColors.themes[ToDoColors.currentIndex].primary).opacity(0.05),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var shadowColor: Color {
        if useThemeColors {
            return Color(ToDoColors.themes[ToDoColors.currentIndex].primary).opacity(shadowOpacity * 0.5)
        } else {
            return Color.black.opacity(shadowOpacity)
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a basic card style with corner radius and shadow
    func cardStyle(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: 2),
        shadowOpacity: Double = 0.1
    ) -> some View {
        self.modifier(
            CardViewModifier(
                cornerRadius: cornerRadius,
                shadowRadius: shadowRadius,
                shadowOffset: shadowOffset,
                shadowOpacity: shadowOpacity
            )
        )
    }
    
    /// Applies a themed card style that integrates with the app's theme system
    func themedCardStyle(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: 2),
        shadowOpacity: Double = 0.1,
        useThemeColors: Bool = true
    ) -> some View {
        self.modifier(
            ThemedCardViewModifier(
                cornerRadius: cornerRadius,
                shadowRadius: shadowRadius,
                shadowOffset: shadowOffset,
                shadowOpacity: shadowOpacity,
                useThemeColors: useThemeColors
            )
        )
    }
}

// MARK: - Preset Card Styles
extension View {
    /// Small card style for compact content
    func smallCard() -> some View {
        self.cardStyle(
            cornerRadius: 8,
            shadowRadius: 4,
            shadowOffset: CGSize(width: 0, height: 1),
            shadowOpacity: 0.08
        )
    }
    
    /// Medium card style for standard content
    func mediumCard() -> some View {
        self.cardStyle(
            cornerRadius: 12,
            shadowRadius: 8,
            shadowOffset: CGSize(width: 0, height: 2),
            shadowOpacity: 0.1
        )
    }
    
    /// Large card style for prominent content
    func largeCard() -> some View {
        self.cardStyle(
            cornerRadius: 16,
            shadowRadius: 12,
            shadowOffset: CGSize(width: 0, height: 4),
            shadowOpacity: 0.15
        )
    }
    
    /// Themed small card
    func themedSmallCard() -> some View {
        self.themedCardStyle(
            cornerRadius: 8,
            shadowRadius: 4,
            shadowOffset: CGSize(width: 0, height: 1),
            shadowOpacity: 0.08
        )
    }
    
    /// Themed medium card
    func themedMediumCard() -> some View {
        self.themedCardStyle(
            cornerRadius: 12,
            shadowRadius: 8,
            shadowOffset: CGSize(width: 0, height: 2),
            shadowOpacity: 0.1
        )
    }
    
    /// Themed large card
    func themedLargeCard() -> some View {
        self.themedCardStyle(
            cornerRadius: 16,
            shadowRadius: 12,
            shadowOffset: CGSize(width: 0, height: 4),
            shadowOpacity: 0.15
        )
    }
}