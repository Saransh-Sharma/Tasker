// LGButton.swift
// Button component with advanced glass morphism effects and liquid morphing animations
// Multiple variants: primary, secondary, ghost with adaptive design and morphing transitions

import UIKit
import SnapKit

// MARK: - Button Component with Advanced Morphing
class LGButton: LGBaseView {
    
    // MARK: - Button Style
    enum Style {
        case primary
        case secondary
        case ghost
        case destructive
        
        var glassIntensity: CGFloat {
            switch self {
            case .primary: return 0.9
            case .secondary: return 0.7
            case .ghost: return 0.3
            case .destructive: return 0.8
            }
        }
    }
    
    enum Size {
        case small
        case medium
        case large
        
        var height: CGFloat {
            switch self {
            case .small: return LGDevice.isIPad ? 36 : 32
            case .medium: return LGDevice.isIPad ? 48 : 44
            case .large: return LGDevice.isIPad ? 56 : 52
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return LGLayoutConstants.captionFontSize
            case .medium: return LGLayoutConstants.bodyFontSize
            case .large: return LGLayoutConstants.titleFontSize
            }
        }
        
        var horizontalPadding: CGFloat {
            switch self {
            case .small: return LGDevice.isIPad ? 16 : 12
            case .medium: return LGDevice.isIPad ? 24 : 20
            case .large: return LGDevice.isIPad ? 32 : 28
            }
        }
    }
    
    // MARK: - UI Elements
    private let titleLabel = UILabel()
    private let iconImageView = UIImageView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let rippleLayer = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    
    // MARK: - Properties
    var title: String? {
        didSet {
            titleLabel.text = title
            updateLayout()
        }
    }
    
    var icon: UIImage? {
        didSet {
            iconImageView.image = icon
            iconImageView.isHidden = icon == nil
            updateLayout()
        }
    }
    
    var style: Style = .primary {
        didSet {
            updateAppearance()
        }
    }
    
    var size: Size = .medium {
        didSet {
            updateSize()
        }
    }
    
    var isLoading: Bool = false {
        didSet {
            updateLoadingState()
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            updateEnabledState()
        }
    }
    
    var onTap: (() -> Void)?
    
    // MARK: - Morphing Properties
    private var buttonMorphState: LGMorphState = .idle
    private var morphingGradientLayer: CAGradientLayer?
    private var liquidRippleLayer: CAShapeLayer?
    private var pressAnimationLayer: CALayer?
    
    // Morphing Configuration
    var morphingEnabled: Bool = true
    var morphingIntensity: CGFloat = 1.0
    var liquidEffectEnabled: Bool = true
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    // MARK: - Setup
    private func setupButton() {
        setupButtonProperties()
        setupSubviews()
        setupConstraints()
        setupInteractions()
        updateAppearance()
        updateSize()
    }
    
    private func setupButtonProperties() {
        isUserInteractionEnabled = true
        layer.addSublayer(gradientLayer)
        layer.addSublayer(rippleLayer)
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.1
    }
    
    private func setupSubviews() {
        // Configure title label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        
        // Configure icon
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.isHidden = true
        
        // Configure loading indicator
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.color = .white
        
        // Configure ripple layer
        rippleLayer.fillColor = UIColor.white.withAlphaComponent(0.3).cgColor
        rippleLayer.opacity = 0
        
        // Add subviews
        [titleLabel, iconImageView, loadingIndicator].forEach {
            addSubview($0)
        }
    }
    
    private func setupConstraints() {
        // Loading indicator
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        updateLayout()
    }
    
    private func updateLayout() {
        let hasIcon = icon != nil
        let hasTitle = !(title?.isEmpty ?? true)
        
        if hasIcon && hasTitle {
            // Icon + Title layout
            iconImageView.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(size.horizontalPadding)
                make.centerY.equalToSuperview()
                make.width.height.equalTo(size.fontSize + 2)
            }
            
            titleLabel.snp.remakeConstraints { make in
                make.leading.equalTo(iconImageView.snp.trailing).offset(8)
                make.trailing.equalToSuperview().offset(-size.horizontalPadding)
                make.centerY.equalToSuperview()
            }
        } else if hasIcon {
            // Icon only layout
            iconImageView.snp.remakeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(size.fontSize + 4)
            }
            
            titleLabel.snp.remakeConstraints { make in
                make.size.equalTo(0)
            }
        } else {
            // Title only layout
            titleLabel.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(size.horizontalPadding)
                make.trailing.equalToSuperview().offset(-size.horizontalPadding)
                make.centerY.equalToSuperview()
            }
            
            iconImageView.snp.remakeConstraints { make in
                make.size.equalTo(0)
            }
        }
    }
    
    private func setupInteractions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(buttonTapped))
        addGestureRecognizer(tapGesture)
        
        // Add hover effect for iPad
        if LGDevice.isIPad {
            let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(hoverChanged(_:)))
            addGestureRecognizer(hoverGesture)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        gradientLayer.frame = bounds
        gradientLayer.cornerRadius = cornerRadius
        
        rippleLayer.frame = bounds
        rippleLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
    }
    
    // MARK: - Appearance Updates
    private func updateAppearance() {
        glassIntensity = style.glassIntensity
        
        let colors = getColorsForStyle()
        titleLabel.textColor = colors.text
        iconImageView.tintColor = colors.text
        loadingIndicator.color = colors.text
        
        // Update gradient
        gradientLayer.colors = colors.gradient
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        
        // Update border for ghost style
        if style == .ghost {
            layer.borderWidth = 1
            layer.borderColor = colors.text.withAlphaComponent(0.3).cgColor
        } else {
            layer.borderWidth = 0
        }
    }
    
    private func updateSize() {
        cornerRadius = size.height / 2
        titleLabel.font = .systemFont(ofSize: size.fontSize, weight: .semibold)
        
        snp.remakeConstraints { make in
            make.height.equalTo(size.height)
        }
        
        updateLayout()
    }
    
    private func updateLoadingState() {
        if isLoading {
            loadingIndicator.startAnimating()
            titleLabel.alpha = 0
            iconImageView.alpha = 0
            isUserInteractionEnabled = false
        } else {
            loadingIndicator.stopAnimating()
            titleLabel.alpha = 1
            iconImageView.alpha = 1
            isUserInteractionEnabled = isEnabled
        }
    }
    
    private func updateEnabledState() {
        let alpha: CGFloat = isEnabled ? 1.0 : 0.6
        
        UIView.animate(withDuration: LGAnimationDurations.short) {
            self.alpha = alpha
        }
        
        isUserInteractionEnabled = isEnabled && !isLoading
    }
    
    private func getColorsForStyle() -> (text: UIColor, gradient: [CGColor]) {
        let accentColor = LGThemeManager.shared.accentColor
        
        switch style {
        case .primary:
            return (
                text: .white,
                gradient: [
                    accentColor.withAlphaComponent(0.9).cgColor,
                    accentColor.cgColor
                ]
            )
        case .secondary:
            return (
                text: accentColor,
                gradient: [
                    accentColor.withAlphaComponent(0.1).cgColor,
                    accentColor.withAlphaComponent(0.2).cgColor
                ]
            )
        case .ghost:
            return (
                text: accentColor,
                gradient: [
                    UIColor.clear.cgColor,
                    UIColor.clear.cgColor
                ]
            )
        case .destructive:
            return (
                text: .white,
                gradient: [
                    UIColor.systemRed.withAlphaComponent(0.9).cgColor,
                    UIColor.systemRed.cgColor
                ]
            )
        }
    }
    
    // MARK: - Actions
    @objc private func buttonTapped() {
        guard isEnabled && !isLoading else { return }
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Animate tap
        animateTap {
            self.onTap?()
        }
    }
    
    @objc private func hoverChanged(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            animateHover(true)
        case .ended, .cancelled:
            animateHover(false)
        default:
            break
        }
    }
    
    // MARK: - Animations
    private func animateTap(completion: @escaping () -> Void) {
        // Create ripple effect
        createRippleEffect()
        
        UIView.animate(withDuration: LGAnimationDurations.short,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.8,
                       options: [.allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in
            UIView.animate(withDuration: LGAnimationDurations.short) {
                self.transform = .identity
            } completion: { _ in
                completion()
            }
        }
    }
    
    private func animateHover(_ isHovering: Bool) {
        let scale: CGFloat = isHovering ? 1.02 : 1.0
        let shadowOpacity: Float = isHovering ? 0.15 : 0.1
        
        UIView.animate(withDuration: LGAnimationDurations.medium) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.layer.shadowOpacity = shadowOpacity
        }
    }
    
    private func createRippleEffect() {
        rippleLayer.opacity = 1
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 0.0
        scaleAnimation.toValue = 1.0
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1.0
        opacityAnimation.toValue = 0.0
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation]
        animationGroup.duration = 0.6
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        rippleLayer.add(animationGroup, forKey: "ripple")
    }
}

// MARK: - Convenience Initializers
extension LGButton {
    
    convenience init(title: String, style: Style = .primary, size: Size = .medium) {
        self.init(frame: .zero)
        self.title = title
        self.style = style
        self.size = size
        updateAppearance()
        updateSize()
    }
    
    convenience init(icon: UIImage, style: Style = .primary, size: Size = .medium) {
        self.init(frame: .zero)
        self.icon = icon
        self.style = style
        self.size = size
        updateAppearance()
        updateSize()
    }
    
    convenience init(title: String, icon: UIImage, style: Style = .primary, size: Size = .medium) {
        self.init(frame: .zero)
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        updateAppearance()
        updateSize()
    }
    
    // MARK: - Advanced Button Morphing Effects
    
    /// Morphs the button with liquid glass effects
    func morphButton(to state: LGMorphState, animated: Bool = true, completion: (() -> Void)? = nil) {
        guard morphingEnabled && buttonMorphState != state else { 
            completion?()
            return 
        }
        
        buttonMorphState = state
        
        if animated {
            performAnimatedMorph(to: state, completion: completion)
        } else {
            performInstantMorph(to: state)
            completion?()
        }
    }
    
    private func performAnimatedMorph(to state: LGMorphState, completion: (() -> Void)?) {
        switch state {
        case .idle:
            morphToIdleButton(completion: completion)
        case .hovering:
            morphToHoveringButton(completion: completion)
        case .pressed:
            morphToPressedButton(completion: completion)
        case .expanding:
            morphToExpandingButton(completion: completion)
        case .liquidWave:
            morphToLiquidWaveButton(completion: completion)
        case .shimmerPulse:
            morphToShimmerPulseButton(completion: completion)
        default:
            // Use base class morphing for other states
            morphGlass(to: state, completion: completion)
        }
    }
    
    private func performInstantMorph(to state: LGMorphState) {
        switch state {
        case .idle:
            resetButtonToIdle()
        case .pressed:
            applyPressedButtonState()
        case .hovering:
            applyHoveringButtonState()
        default:
            break
        }
    }
    
    // MARK: - Button-Specific Morphing States
    
    private func morphToIdleButton(completion: (() -> Void)?) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setCompletionBlock(completion)
        
        // Reset transform and appearance
        layer.transform = CATransform3DIdentity
        alpha = 1.0
        
        // Reset glass intensity based on style
        glassIntensity = style.glassIntensity
        
        // Remove any temporary effects
        removeLiquidEffects()
        
        CATransaction.commit()
    }
    
    private func morphToHoveringButton(completion: (() -> Void)?) {
        let scaleTransform = CATransform3DMakeScale(1.05, 1.05, 1.0)
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setCompletionBlock(completion)
        
        layer.transform = scaleTransform
        glassIntensity = min(style.glassIntensity + 0.2, 1.0)
        
        // Add glow effect
        addButtonGlow()
        
        CATransaction.commit()
    }
    
    private func morphToPressedButton(completion: (() -> Void)?) {
        let scaleTransform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.1)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeIn))
        CATransaction.setCompletionBlock(completion)
        
        layer.transform = scaleTransform
        glassIntensity = style.glassIntensity - 0.2
        alpha = 0.9
        
        CATransaction.commit()
    }
    
    private func morphToExpandingButton(completion: (() -> Void)?) {
        // Create expanding ripple effect
        createExpandingRipple()
        
        let animation = CASpringAnimation(keyPath: "transform.scale")
        animation.fromValue = 1.0
        animation.toValue = 1.15
        animation.duration = 0.6
        animation.damping = 8
        animation.initialVelocity = 4
        animation.stiffness = 100
        
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        layer.add(animation, forKey: "expandingButtonMorph")
        CATransaction.commit()
    }
    
    private func morphToLiquidWaveButton(completion: (() -> Void)?) {
        startButtonLiquidWave()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.stopButtonLiquidWave()
            completion?()
        }
    }
    
    private func morphToShimmerPulseButton(completion: (() -> Void)?) {
        startButtonShimmerPulse()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.stopButtonShimmerPulse()
            completion?()
        }
    }
    
    // MARK: - Button Effect Helpers
    
    private func addButtonGlow() {
        layer.shadowColor = getButtonGlowColor().cgColor
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.4
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }
    
    private func getButtonGlowColor() -> UIColor {
        switch style {
        case .primary:
            return LGThemeManager.shared.primaryGlassColor
        case .secondary:
            return LGThemeManager.shared.secondaryGlassColor
        case .ghost:
            return .systemBlue
        case .destructive:
            return .systemRed
        }
    }
    
    private func createExpandingRipple() {
        guard liquidEffectEnabled else { return }
        
        let ripple = CAShapeLayer()
        let startRadius: CGFloat = 0
        let endRadius: CGFloat = max(bounds.width, bounds.height) * 1.5
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        let startPath = UIBezierPath(arcCenter: center, radius: startRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        let endPath = UIBezierPath(arcCenter: center, radius: endRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        
        ripple.path = startPath.cgPath
        ripple.fillColor = UIColor.clear.cgColor
        ripple.strokeColor = getButtonGlowColor().withAlphaComponent(0.6).cgColor
        ripple.lineWidth = 2.0
        
        layer.addSublayer(ripple)
        
        let pathAnimation = CABasicAnimation(keyPath: "path")
        pathAnimation.fromValue = startPath.cgPath
        pathAnimation.toValue = endPath.cgPath
        pathAnimation.duration = 0.8
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1.0
        opacityAnimation.toValue = 0.0
        opacityAnimation.duration = 0.8
        
        let group = CAAnimationGroup()
        group.animations = [pathAnimation, opacityAnimation]
        group.duration = 0.8
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        ripple.add(group, forKey: "expandingRipple")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            ripple.removeFromSuperlayer()
        }
    }
    
    private func startButtonLiquidWave() {
        guard liquidEffectEnabled else { return }
        
        let waveAnimation = CABasicAnimation(keyPath: "transform.translation.x")
        waveAnimation.fromValue = -5
        waveAnimation.toValue = 5
        waveAnimation.duration = 0.3
        waveAnimation.autoreverses = true
        waveAnimation.repeatCount = 4
        waveAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        layer.add(waveAnimation, forKey: "liquidWaveButton")
        
        // Pulse glass intensity
        let intensityAnimation = CABasicAnimation(keyPath: "opacity")
        intensityAnimation.fromValue = 0.8
        intensityAnimation.toValue = 1.0
        intensityAnimation.duration = 0.15
        intensityAnimation.autoreverses = true
        intensityAnimation.repeatCount = 8
        
        layer.add(intensityAnimation, forKey: "liquidWaveIntensity")
    }
    
    private func stopButtonLiquidWave() {
        layer.removeAnimation(forKey: "liquidWaveButton")
        layer.removeAnimation(forKey: "liquidWaveIntensity")
        
        // Smooth return to normal
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.2)
        layer.transform = CATransform3DIdentity
        alpha = 1.0
        CATransaction.commit()
    }
    
    private func startButtonShimmerPulse() {
        let shimmerLayer = CAGradientLayer()
        shimmerLayer.frame = bounds
        shimmerLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.3).cgColor,
            UIColor.clear.cgColor
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.locations = [0, 0.5, 1]
        
        layer.addSublayer(shimmerLayer)
        
        let shimmerAnimation = CABasicAnimation(keyPath: "locations")
        shimmerAnimation.fromValue = [-0.3, -0.15, 0]
        shimmerAnimation.toValue = [1, 1.15, 1.3]
        shimmerAnimation.duration = 1.0
        shimmerAnimation.repeatCount = 2
        shimmerAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        shimmerLayer.add(shimmerAnimation, forKey: "shimmerPulse")
        
        self.morphingGradientLayer = shimmerLayer
    }
    
    private func stopButtonShimmerPulse() {
        morphingGradientLayer?.removeFromSuperlayer()
        morphingGradientLayer = nil
    }
    
    private func removeLiquidEffects() {
        layer.shadowOpacity = 0
        morphingGradientLayer?.removeFromSuperlayer()
        morphingGradientLayer = nil
        liquidRippleLayer?.removeFromSuperlayer()
        liquidRippleLayer = nil
    }
    
    private func resetButtonToIdle() {
        layer.transform = CATransform3DIdentity
        alpha = 1.0
        glassIntensity = style.glassIntensity
        removeLiquidEffects()
    }
    
    private func applyPressedButtonState() {
        layer.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
        alpha = 0.9
        glassIntensity = style.glassIntensity - 0.2
    }
    
    private func applyHoveringButtonState() {
        layer.transform = CATransform3DMakeScale(1.05, 1.05, 1.0)
        glassIntensity = min(style.glassIntensity + 0.2, 1.0)
        addButtonGlow()
    }
    
    // MARK: - Enhanced Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if morphingEnabled && FeatureFlags.enableLiquidAnimations {
            morphButton(to: .pressed)
        }
        
        if liquidEffectEnabled && FeatureFlags.enableAdvancedAnimations,
           let touch = touches.first {
            let location = touch.location(in: self)
            animateGlassRipple(at: location)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if morphingEnabled && FeatureFlags.enableLiquidAnimations {
            createLiquidTransition(from: .pressed, to: .idle, duration: 0.3)
        }
        
        // Trigger tap callback
        if bounds.contains(touches.first?.location(in: self) ?? .zero) {
            onTap?()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        if morphingEnabled && FeatureFlags.enableLiquidAnimations {
            morphButton(to: .idle)
        }
    }
}

// MARK: - Button Group
class LGButtonGroup: UIView {
    
    private let stackView = UIStackView()
    private var buttons: [LGButton] = []
    
    var axis: NSLayoutConstraint.Axis = .horizontal {
        didSet {
            stackView.axis = axis
        }
    }
    
    var spacing: CGFloat = 8 {
        didSet {
            stackView.spacing = spacing
        }
    }
    
    var distribution: UIStackView.Distribution = .fillEqually {
        didSet {
            stackView.distribution = distribution
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButtonGroup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButtonGroup()
    }
    
    private func setupButtonGroup() {
        stackView.axis = axis
        stackView.spacing = spacing
        stackView.distribution = distribution
        stackView.alignment = .fill
        
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func addButton(_ button: LGButton) {
        buttons.append(button)
        stackView.addArrangedSubview(button)
    }
    
    func removeButton(_ button: LGButton) {
        if let index = buttons.firstIndex(of: button) {
            buttons.remove(at: index)
            stackView.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
    }
    
    func removeAllButtons() {
        buttons.forEach { button in
            stackView.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        buttons.removeAll()
    }
}
