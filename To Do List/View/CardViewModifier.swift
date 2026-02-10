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
        cornerRadius: CGFloat,
        shadowRadius: CGFloat,
        shadowOffset: CGSize,
        shadowOpacity: Double
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
                    .fill(Color.tasker.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.strokeHairline), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .taskerElevation(elevationLevel, cornerRadius: cornerRadius, includesBorder: false)
    }

    private var elevationLevel: TaskerElevationLevel {
        if shadowRadius >= 16 {
            return .e3
        }
        if shadowRadius >= 10 {
            return .e2
        }
        return .e1
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
        cornerRadius: CGFloat,
        shadowRadius: CGFloat,
        shadowOffset: CGSize,
        shadowOpacity: Double,
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
                    .fill(Color.tasker.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color(uiColor: TaskerThemeManager.shared.currentTheme.tokens.color.strokeHairline), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .taskerElevation(elevationLevel, cornerRadius: cornerRadius, includesBorder: false)
    }

    private var elevationLevel: TaskerElevationLevel {
        if shadowRadius >= 16 {
            return .e3
        }
        if shadowRadius >= 10 {
            return .e2
        }
        return .e1
    }
}

// MARK: - View Extensions
extension View {
    /// Applies a basic card style with corner radius and shadow
    func cardStyle(
        cornerRadius: CGFloat? = nil,
        shadowRadius: CGFloat? = nil,
        shadowOffset: CGSize? = nil,
        shadowOpacity: Double? = nil
    ) -> some View {
        let tokens = TaskerThemeManager.shared.currentTheme.tokens
        let elevation = tokens.elevation.e1
        return self.modifier(
            CardViewModifier(
                cornerRadius: cornerRadius ?? tokens.corner.card,
                shadowRadius: shadowRadius ?? elevation.shadowBlur / 2,
                shadowOffset: shadowOffset ?? CGSize(width: 0, height: elevation.shadowOffsetY),
                shadowOpacity: shadowOpacity ?? Double(elevation.shadowOpacity)
            )
        )
    }
    
    /// Applies a themed card style that integrates with the app's theme system
    func themedCardStyle(
        cornerRadius: CGFloat? = nil,
        shadowRadius: CGFloat? = nil,
        shadowOffset: CGSize? = nil,
        shadowOpacity: Double? = nil,
        useThemeColors: Bool = true
    ) -> some View {
        let tokens = TaskerThemeManager.shared.currentTheme.tokens
        let elevation = tokens.elevation.e1
        return self.modifier(
            ThemedCardViewModifier(
                cornerRadius: cornerRadius ?? tokens.corner.card,
                shadowRadius: shadowRadius ?? elevation.shadowBlur / 2,
                shadowOffset: shadowOffset ?? CGSize(width: 0, height: elevation.shadowOffsetY),
                shadowOpacity: shadowOpacity ?? Double(elevation.shadowOpacity),
                useThemeColors: useThemeColors
            )
        )
    }
}

// MARK: - Preset Card Styles
extension View {
    /// Small card style for compact content
    func smallCard() -> some View {
        self.cardStyle(cornerRadius: TaskerThemeManager.shared.currentTheme.tokens.corner.r1)
    }
    
    /// Medium card style for standard content
    func mediumCard() -> some View {
        self.cardStyle(cornerRadius: TaskerThemeManager.shared.currentTheme.tokens.corner.r2)
    }
    
    /// Large card style for prominent content
    func largeCard() -> some View {
        self.cardStyle(cornerRadius: TaskerThemeManager.shared.currentTheme.tokens.corner.r3)
    }
    
    /// Themed small card
    func themedSmallCard() -> some View {
        self.themedCardStyle(cornerRadius: TaskerThemeManager.shared.currentTheme.tokens.corner.r1)
    }
    
    /// Themed medium card
    func themedMediumCard() -> some View {
        self.themedCardStyle(cornerRadius: TaskerThemeManager.shared.currentTheme.tokens.corner.r2)
    }
    
    /// Themed large card
    func themedLargeCard() -> some View {
        self.themedCardStyle(cornerRadius: TaskerThemeManager.shared.currentTheme.tokens.corner.r3)
    }
}
