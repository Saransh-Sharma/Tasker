// Base Liquid Glass View
// Provides glass morphism effects and liquid animations for all Liquid Glass UI components

import UIKit

class LGBaseView: UIView {
    
    // MARK: - Properties
    private var glassEffectView: UIVisualEffectView?
    private var gradientLayer: CAGradientLayer?
    private var shimmerLayer: CAGradientLayer?
    private var borderLayer: CAShapeLayer?
    
    // Configuration
    var glassIntensity: CGFloat = 0.8 {
        didSet { updateGlassEffect() }
    }
    
    var glassColor: UIColor = .systemBackground {
        didSet { updateGlassEffect() }
    }
    
    var cornerRadius: CGFloat = 20 {
        didSet { updateCornerRadius() }
    }
    
    var enableGlassBorder: Bool = true {
        didSet { updateBorder() }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGlassEffect()
        setupThemeObserver()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlassEffect()
        setupThemeObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupGlassEffect() {
        // Background blur effect
        let blurEffect = UIBlurEffect(style: LGThemeManager.shared.glassBlurStyle)
        let effectView = UIVisualEffectView(effect: blurEffect)
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.alpha = LGThemeManager.shared.glassIntensity
        
        insertSubview(effectView, at: 0)
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: topAnchor),
            effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        self.glassEffectView = effectView
        
        // Add gradient overlay
        setupGradientLayer()
        
        // Add glass border
        setupBorder()
        
        // Configure appearance
        updateCornerRadius()
        setupShadow()
    }
    
    private func setupGradientLayer() {
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.white.withAlphaComponent(0.1).cgColor,
            UIColor.white.withAlphaComponent(0.05).cgColor,
            UIColor.clear.cgColor
        ]
        gradient.locations = [0, 0.5, 1]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        
        layer.insertSublayer(gradient, at: 1)
        self.gradientLayer = gradient
    }
    
    private func setupBorder() {
        let border = CAShapeLayer()
        border.strokeColor = UIColor.white.withAlphaComponent(0.2).cgColor
        border.fillColor = UIColor.clear.cgColor
        border.lineWidth = 1.0
        
        layer.addSublayer(border)
        self.borderLayer = border
    }
    
    private func setupShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = LGThemeManager.shared.shadowOpacity
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowRadius = 20
        layer.masksToBounds = false
    }
    
    private func setupThemeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .lgThemeDidChange,
            object: nil
        )
    }
    
    @objc private func themeDidChange() {
        updateGlassEffect()
        updateBorder()
        setupShadow()
    }
    
    private func updateGlassEffect() {
        let blurEffect = UIBlurEffect(style: LGThemeManager.shared.glassBlurStyle)
        glassEffectView?.effect = blurEffect
        glassEffectView?.alpha = LGThemeManager.shared.glassIntensity
        glassEffectView?.backgroundColor = LGThemeManager.shared.primaryGlassColor.withAlphaComponent(0.01)
    }
    
    private func updateCornerRadius() {
        layer.cornerRadius = cornerRadius
        glassEffectView?.layer.cornerRadius = cornerRadius
        glassEffectView?.clipsToBounds = true
        
        // Update border path
        updateBorderPath()
    }
    
    private func updateBorder() {
        borderLayer?.isHidden = !enableGlassBorder
        if enableGlassBorder {
            borderLayer?.strokeColor = UIColor.white.withAlphaComponent(0.2).cgColor
        }
    }
    
    private func updateBorderPath() {
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        borderLayer?.path = path.cgPath
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = bounds
        shimmerLayer?.frame = bounds
        updateBorderPath()
    }
    
    // MARK: - Animations
    func addShimmerEffect() {
        guard shimmerLayer == nil else { return }
        
        let shimmer = CAGradientLayer()
        shimmer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.2).cgColor,
            UIColor.clear.cgColor
        ]
        shimmer.locations = [0.0, 0.5, 1.0]
        shimmer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmer.frame = bounds
        
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 2.0
        animation.repeatCount = .infinity
        
        shimmer.add(animation, forKey: "shimmer")
        layer.addSublayer(shimmer)
        self.shimmerLayer = shimmer
    }
    
    func removeShimmerEffect() {
        shimmerLayer?.removeFromSuperlayer()
        shimmerLayer = nil
    }
    
    func animateLiquidTransition() {
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.fromValue = 0.95
        animation.toValue = 1.0
        animation.duration = 0.6
        animation.damping = 10
        animation.initialVelocity = 5
        animation.stiffness = 100
        
        layer.add(animation, forKey: "liquidTransition")
    }
    
    func animateGlassRipple(at point: CGPoint) {
        let ripple = CAShapeLayer()
        let startRadius: CGFloat = 0
        let endRadius: CGFloat = max(bounds.width, bounds.height)
        
        let startPath = UIBezierPath(arcCenter: point, radius: startRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        let endPath = UIBezierPath(arcCenter: point, radius: endRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        
        ripple.path = startPath.cgPath
        ripple.fillColor = UIColor.white.withAlphaComponent(0.1).cgColor
        ripple.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        ripple.lineWidth = 2.0
        
        layer.addSublayer(ripple)
        
        let pathAnimation = CABasicAnimation(keyPath: "path")
        pathAnimation.fromValue = startPath.cgPath
        pathAnimation.toValue = endPath.cgPath
        pathAnimation.duration = 0.6
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1.0
        opacityAnimation.toValue = 0.0
        opacityAnimation.duration = 0.6
        
        let group = CAAnimationGroup()
        group.animations = [pathAnimation, opacityAnimation]
        group.duration = 0.6
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        ripple.add(group, forKey: "ripple")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            ripple.removeFromSuperlayer()
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if FeatureFlags.enableAdvancedAnimations,
           let touch = touches.first {
            let location = touch.location(in: self)
            animateGlassRipple(at: location)
        }
        
        // Haptic feedback
        if FeatureFlags.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}
