//
//  LGBaseView.swift
//  Tasker
//
//  iOS 16+ Liquid Glass UI Base Component
//  Provides glass morphism effects with backdrop blur and gradients
//

import UIKit

/// Base view with liquid glass morphism effects
class LGBaseView: UIView {
    
    // MARK: - Glass Effect Layers
    
    private let blurEffectView = UIVisualEffectView()
    private let gradientLayer = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    
    // MARK: - Configuration
    
    var glassBlurStyle: UIBlurEffect.Style = .systemUltraThinMaterial {
        didSet { updateGlassEffect() }
    }
    
    var glassOpacity: CGFloat = 0.8 {
        didSet { updateGlassEffect() }
    }
    
    var cornerRadius: CGFloat = 16 {
        didSet { updateCornerRadius() }
    }
    
    var borderWidth: CGFloat = 0.5 {
        didSet { updateBorder() }
    }

    var borderColor: UIColor = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor.white.withAlphaComponent(0.10)
        }
        return UIColor.white.withAlphaComponent(0.25)
    } {
        didSet { updateBorder() }
    }

    var elevationLevel: TaskerElevationLevel = .e1 {
        didSet { applyTokenElevation() }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGlassEffect()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlassEffect()
    }
    
    // MARK: - Setup
    
    private func setupGlassEffect() {
        backgroundColor = .clear
        clipsToBounds = true
        
        // Blur effect
        blurEffectView.effect = UIBlurEffect(style: glassBlurStyle)
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        insertSubview(blurEffectView, at: 0)
        
        // Gradient overlay — subtler for premium feel
        let glassTint = TaskerThemeManager.shared.currentTheme.tokens.color.overlayGlassTint
        gradientLayer.colors = [
            glassTint.withAlphaComponent(0.28).cgColor,
            glassTint.withAlphaComponent(0.08).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradientLayer, at: 1)
        
        // Border
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = borderColor.cgColor
        borderLayer.lineWidth = borderWidth
        layer.addSublayer(borderLayer)
        
        updateCornerRadius()
        applyTokenElevation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        blurEffectView.frame = bounds
        gradientLayer.frame = bounds
        
        let borderPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        borderLayer.path = borderPath.cgPath
    }
    
    // MARK: - Updates
    
    private func updateGlassEffect() {
        blurEffectView.effect = UIBlurEffect(style: glassBlurStyle)
        alpha = glassOpacity
    }
    
    private func updateCornerRadius() {
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
    }
    
    private func updateBorder() {
        borderLayer.strokeColor = borderColor.cgColor
        borderLayer.lineWidth = borderWidth
    }

    private func applyTokenElevation() {
        let style = TaskerThemeManager.shared.currentTheme.tokens.elevation.style(for: elevationLevel)
        let colors = TaskerThemeManager.shared.currentTheme.tokens.color
        layer.shadowColor = style.shadowColor.cgColor
        layer.shadowOpacity = style.shadowOpacity
        layer.shadowOffset = CGSize(width: 0, height: style.shadowOffsetY)
        layer.shadowRadius = style.shadowBlur / 2

        borderWidth = style.borderWidth
        borderColor = style.borderColor
        glassBlurStyle = style.blurStyle
        gradientLayer.colors = [
            colors.overlayGlassTint.withAlphaComponent(0.35).cgColor,
            colors.overlayGlassTint.withAlphaComponent(0.12).cgColor
        ]

        let corner = TaskerThemeManager.shared.currentTheme.tokens.corner
        cornerRadius = corner.card
    }
    
    // MARK: - Animation Helpers
    
    func animateGlassAppearance(duration: TimeInterval = 0.3) {
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.96, y: 0.96)

        UIView.taskerSpringAnimate(TaskerAnimation.uiGentle) {
            self.alpha = self.glassOpacity
            self.transform = .identity
        }
    }
}
