// Base Liquid Glass View
// Provides advanced glass morphism effects and liquid animations with morphing transitions
// Based on Apple's Liquid Glass documentation for custom views

import UIKit
import QuartzCore

// MARK: - Morph State Enum
enum LGMorphState {
    case idle
    case hovering
    case pressed
    case expanding
    case contracting
    case liquidWave
    case shimmerPulse
    case glassRipple
}

// MARK: - Morphing Configuration
struct LGMorphConfig {
    let duration: TimeInterval
    let intensity: CGFloat
    let waveAmplitude: CGFloat
    let rippleRadius: CGFloat
    let shimmerSpeed: CGFloat
    
    static let `default` = LGMorphConfig(
        duration: 0.6,
        intensity: 0.8,
        waveAmplitude: 8.0,
        rippleRadius: 50.0,
        shimmerSpeed: 1.2
    )
    
    static let subtle = LGMorphConfig(
        duration: 0.4,
        intensity: 0.4,
        waveAmplitude: 4.0,
        rippleRadius: 30.0,
        shimmerSpeed: 0.8
    )
    
    static let dramatic = LGMorphConfig(
        duration: 1.0,
        intensity: 1.2,
        waveAmplitude: 12.0,
        rippleRadius: 80.0,
        shimmerSpeed: 1.8
    )
}

class LGBaseView: UIView {
    
    // MARK: - Properties
    private var glassEffectView: UIVisualEffectView?
    private var gradientLayer: CAGradientLayer?
    private var shimmerLayer: CAGradientLayer?
    private var borderLayer: CAShapeLayer?
    private var morphingLayer: CALayer?
    private var liquidAnimationTimer: Timer?
    
    // Morphing Properties
    private var morphingIntensity: CGFloat = 0.0
    private var liquidWavePhase: CGFloat = 0.0
    private var morphingGradientColors: [CGColor] = []
    
    // Animation State
    private var isAnimating: Bool = false
    private var currentMorphState: LGMorphState = .idle
    
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
    
    // MARK: - Advanced Morphing Effects
    
    /// Morphs the glass effect with liquid-like transitions
    func morphGlass(to state: LGMorphState, config: LGMorphConfig = .default, completion: (() -> Void)? = nil) {
        guard currentMorphState != state else { return }
        
        currentMorphState = state
        isAnimating = true
        
        switch state {
        case .idle:
            morphToIdle(config: config, completion: completion)
        case .hovering:
            morphToHover(config: config, completion: completion)
        case .pressed:
            morphToPressed(config: config, completion: completion)
        case .expanding:
            morphToExpanding(config: config, completion: completion)
        case .contracting:
            morphToContracting(config: config, completion: completion)
        case .liquidWave:
            morphToLiquidWave(config: config, completion: completion)
        case .shimmerPulse:
            morphToShimmerPulse(config: config, completion: completion)
        case .glassRipple:
            morphToGlassRipple(config: config, completion: completion)
        }
    }
    
    private func morphToIdle(config: LGMorphConfig, completion: (() -> Void)?) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(config.duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        CATransaction.setCompletionBlock {
            self.isAnimating = false
            completion?()
        }
        
        // Reset to base state
        layer.transform = CATransform3DIdentity
        glassIntensity = 0.8
        alpha = 1.0
        
        CATransaction.commit()
    }
    
    private func morphToHover(config: LGMorphConfig, completion: (() -> Void)?) {
        let scaleTransform = CATransform3DMakeScale(1.02, 1.02, 1.0)
        let rotationTransform = CATransform3DMakeRotation(0.01, 0, 0, 1)
        let combinedTransform = CATransform3DConcat(scaleTransform, rotationTransform)
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(config.duration * 0.6)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setCompletionBlock {
            self.isAnimating = false
            completion?()
        }
        
        layer.transform = combinedTransform
        glassIntensity = 0.9
        
        // Add subtle glow effect
        layer.shadowColor = LGThemeManager.shared.primaryGlassColor.cgColor
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.3
        layer.shadowOffset = CGSize(width: 0, height: 2)
        
        CATransaction.commit()
    }
    
    private func morphToPressed(config: LGMorphConfig, completion: (() -> Void)?) {
        let scaleTransform = CATransform3DMakeScale(0.96, 0.96, 1.0)
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(config.duration * 0.3)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock {
            self.isAnimating = false
            completion?()
        }
        
        layer.transform = scaleTransform
        glassIntensity = 0.6
        alpha = 0.9
        
        CATransaction.commit()
    }
    
    private func morphToExpanding(config: LGMorphConfig, completion: (() -> Void)?) {
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.1
        animation.duration = config.duration
        animation.damping = 8
        animation.initialVelocity = 3
        animation.stiffness = 80
        
        layer.add(animation, forKey: "expandingMorph")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration) {
            self.isAnimating = false
            completion?()
        }
    }
    
    private func morphToContracting(config: LGMorphConfig, completion: (() -> Void)?) {
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 0.9
        animation.duration = config.duration
        animation.damping = 12
        animation.initialVelocity = 2
        animation.stiffness = 120
        
        layer.add(animation, forKey: "contractingMorph")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration) {
            self.isAnimating = false
            completion?()
        }
    }
    
    private func morphToLiquidWave(config: LGMorphConfig, completion: (() -> Void)?) {
        startLiquidWaveAnimation(config: config)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration * 2) {
            self.stopLiquidWaveAnimation()
            self.isAnimating = false
            completion?()
        }
    }
    
    private func morphToShimmerPulse(config: LGMorphConfig, completion: (() -> Void)?) {
        startShimmerPulseAnimation(config: config)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration * 3) {
            self.stopShimmerPulseAnimation()
            self.isAnimating = false
            completion?()
        }
    }
    
    private func morphToGlassRipple(config: LGMorphConfig, completion: (() -> Void)?) {
        let centerPoint = CGPoint(x: bounds.midX, y: bounds.midY)
        animateGlassRipple(at: centerPoint)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration) {
            self.isAnimating = false
            completion?()
        }
    }
    
    // MARK: - Continuous Animations
    
    private func startLiquidWaveAnimation(config: LGMorphConfig) {
        liquidAnimationTimer?.invalidate()
        liquidWavePhase = 0.0
        
        liquidAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            self.liquidWavePhase += CGFloat(config.shimmerSpeed * 0.1)
            self.updateLiquidWave(amplitude: config.waveAmplitude)
        }
    }
    
    private func updateLiquidWave(amplitude: CGFloat) {
        let waveOffset = sin(liquidWavePhase) * amplitude
        let transform = CATransform3DMakeTranslation(waveOffset, 0, 0)
        layer.transform = transform
        
        // Update glass intensity with wave
        let intensityVariation = (sin(liquidWavePhase * 2) + 1) * 0.1
        glassIntensity = 0.8 + intensityVariation
    }
    
    private func stopLiquidWaveAnimation() {
        liquidAnimationTimer?.invalidate()
        liquidAnimationTimer = nil
        
        // Smooth return to normal
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        layer.transform = CATransform3DIdentity
        glassIntensity = 0.8
        CATransaction.commit()
    }
    
    private func startShimmerPulseAnimation(config: LGMorphConfig) {
        guard let shimmerLayer = shimmerLayer else { return }
        
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.0
        pulseAnimation.toValue = 0.8
        pulseAnimation.duration = config.duration / 2
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        shimmerLayer.add(pulseAnimation, forKey: "shimmerPulse")
    }
    
    private func stopShimmerPulseAnimation() {
        shimmerLayer?.removeAnimation(forKey: "shimmerPulse")
    }
    
    /// Creates a liquid morphing transition between two states
    func createLiquidTransition(from startState: LGMorphState, to endState: LGMorphState, duration: TimeInterval = 0.8) {
        // First morph to intermediate liquid state
        morphGlass(to: .liquidWave, config: LGMorphConfig(duration: duration * 0.3, intensity: 1.0, waveAmplitude: 6.0, rippleRadius: 40.0, shimmerSpeed: 1.5)) {
            // Then morph to final state
            self.morphGlass(to: endState, config: LGMorphConfig(duration: duration * 0.7, intensity: 0.8, waveAmplitude: 4.0, rippleRadius: 30.0, shimmerSpeed: 1.0))
        }
    }
    
    // MARK: - Touch Handling with Morphing
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if FeatureFlags.enableLiquidAnimations {
            morphGlass(to: .pressed, config: .subtle)
        }
        
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
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if FeatureFlags.enableLiquidAnimations {
            createLiquidTransition(from: .pressed, to: .idle, duration: 0.4)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        if FeatureFlags.enableLiquidAnimations {
            morphGlass(to: .idle, config: .subtle)
        }
    }
    
    // MARK: - Hover Support (iPad)
    #if targetEnvironment(macCatalyst)
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if FeatureFlags.enableLiquidAnimations {
            morphGlass(to: .hovering, config: .subtle)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if FeatureFlags.enableLiquidAnimations {
            morphGlass(to: .idle, config: .subtle)
        }
    }
    #endif
}
