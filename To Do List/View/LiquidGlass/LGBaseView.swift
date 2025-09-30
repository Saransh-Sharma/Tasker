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
    
    var borderColor: UIColor = .white.withAlphaComponent(0.2) {
        didSet { updateBorder() }
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
        
        // Gradient overlay
        gradientLayer.colors = [
            UIColor.white.withAlphaComponent(0.15).cgColor,
            UIColor.white.withAlphaComponent(0.05).cgColor
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
    
    // MARK: - Animation Helpers
    
    func animateGlassAppearance(duration: TimeInterval = 0.3) {
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.alpha = self.glassOpacity
            self.transform = .identity
        }
    }
}
