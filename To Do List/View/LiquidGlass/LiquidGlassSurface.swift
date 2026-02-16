//
//  LiquidGlassSurface.swift
//  Tasker
//

import SwiftUI

private enum LiquidGlassRecipe {
    static let rimLineWidth: CGFloat = 1.0
    static let innerRimLineWidth: CGFloat = 0.5
    static let innerRimBlur: CGFloat = 0.5

    static let darkRimOpacity: Double = 0.18
    static let lightRimOpacity: Double = 0.12
    static let darkInnerRimOpacity: Double = 0.35
    static let lightInnerRimOpacity: Double = 0.10

    static let strongDarkSpecularTop: Double = 0.18
    static let strongLightSpecularTop: Double = 0.12
    static let normalDarkSpecularTop: Double = 0.16
    static let normalLightSpecularTop: Double = 0.10

    static let strongShadowOpacity: Double = 0.30
    static let normalShadowOpacity: Double = 0.22
    static let strongShadowRadius: CGFloat = 18
    static let normalShadowRadius: CGFloat = 14
    static let strongShadowYOffset: CGFloat = 12
    static let normalShadowYOffset: CGFloat = 10

    static let reduceTransparencyOpacity: Double = 0.96
}

struct LiquidGlassSurface<S: Shape, Content: View>: View {
    enum Emphasis {
        case normal
        case strong
    }

    private let shape: S
    private let emphasis: Emphasis
    private let content: Content

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        shape: S,
        emphasis: Emphasis = .normal,
        @ViewBuilder content: () -> Content
    ) {
        self.shape = shape
        self.emphasis = emphasis
        self.content = content()
    }

    var body: some View {
        content
            .background {
                shape
                    .fill(surfaceStyle)
                    .overlay(rimOverlay)
                    .overlay(innerRimOverlay)
                    .overlay(specularOverlay)
                    .overlay(lightModeContrastOverlay)
                    .shadow(
                        color: Color.black.opacity(emphasis == .strong ? LiquidGlassRecipe.strongShadowOpacity : LiquidGlassRecipe.normalShadowOpacity),
                        radius: emphasis == .strong ? LiquidGlassRecipe.strongShadowRadius : LiquidGlassRecipe.normalShadowRadius,
                        y: emphasis == .strong ? LiquidGlassRecipe.strongShadowYOffset : LiquidGlassRecipe.normalShadowYOffset
                    )
            }
    }

    private var surfaceStyle: AnyShapeStyle {
        if reduceTransparency {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.tasker.surfacePrimary.opacity(LiquidGlassRecipe.reduceTransparencyOpacity),
                        Color.tasker.surfaceSecondary.opacity(LiquidGlassRecipe.reduceTransparencyOpacity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        if colorScheme == .dark {
            return AnyShapeStyle(.ultraThinMaterial)
        }

        return AnyShapeStyle(.thinMaterial)
    }

    private var rimOverlay: some View {
        shape.stroke(
            Color.white.opacity(colorScheme == .dark ? LiquidGlassRecipe.darkRimOpacity : LiquidGlassRecipe.lightRimOpacity),
            lineWidth: LiquidGlassRecipe.rimLineWidth
        )
    }

    private var innerRimOverlay: some View {
        shape
            .stroke(
                Color.black.opacity(colorScheme == .dark ? LiquidGlassRecipe.darkInnerRimOpacity : LiquidGlassRecipe.lightInnerRimOpacity),
                lineWidth: LiquidGlassRecipe.innerRimLineWidth
            )
            .blur(radius: LiquidGlassRecipe.innerRimBlur)
    }

    private var specularOverlay: some View {
        shape
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(specularTopOpacity),
                        Color.white.opacity(0.05),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
    }

    @ViewBuilder
    private var lightModeContrastOverlay: some View {
        if !reduceTransparency && colorScheme == .light {
            shape.fill(Color.black.opacity(0.04))
        }
    }

    private var specularTopOpacity: Double {
        switch (emphasis, colorScheme) {
        case (.strong, .dark):
            return LiquidGlassRecipe.strongDarkSpecularTop
        case (.strong, .light):
            return LiquidGlassRecipe.strongLightSpecularTop
        case (.normal, .dark):
            return LiquidGlassRecipe.normalDarkSpecularTop
        case (.normal, .light):
            return LiquidGlassRecipe.normalLightSpecularTop
        @unknown default:
            return LiquidGlassRecipe.normalLightSpecularTop
        }
    }
}
