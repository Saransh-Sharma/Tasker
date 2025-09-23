// LGFloatingActionButton.swift
// Floating Action Button with glass morphism and ripple effects
// Adaptive design with liquid animations for iPhone and iPad

import UIKit
import SnapKit

// MARK: - Floating Action Button Component
class LGFloatingActionButton: LGBaseView {
    
    // MARK: - UI Elements
    private let iconImageView = UIImageView()
    private let rippleLayer = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()
    
    // MARK: - Properties
    var icon: UIImage? {
        didSet {
            iconImageView.image = icon
        }
    }
    
    var iconColor: UIColor = .white {
        didSet {
            iconImageView.tintColor = iconColor
        }
    }
    
    var fabColor: UIColor = UIColor.systemBlue {
        didSet {
            updateAppearance()
        }
    }
    
    var onTap: (() -> Void)?
    
    private var isExpanded = false
    private var actionButtons: [LGFABActionButton] = []
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupFAB()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupFAB()
    }
    
    // MARK: - Setup
    private func setupFAB() {
        setupFABProperties()
        setupSubviews()
        setupConstraints()
        setupInteractions()
        setupAnimations()
    }
    
    private func setupFABProperties() {
        // FAB specific properties
        glassIntensity = 0.9
        let fabSize = LGLayoutConstants.fabSize
        cornerRadius = fabSize / 2
        
        // Set fixed size
        snp.makeConstraints { make in
            make.width.height.equalTo(fabSize)
        }
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.3
        
        // Add ripple layer
        layer.addSublayer(rippleLayer)
        layer.addSublayer(pulseLayer)
        
        updateAppearance()
    }
    
    private func setupSubviews() {
        // Configure icon
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = iconColor
        iconImageView.image = UIImage(systemName: "plus")
        
        addSubview(iconImageView)
    }
    
    private func setupConstraints() {
        let iconSize: CGFloat = LGDevice.isIPad ? 28 : 24
        
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(iconSize)
        }
    }
    
    private func setupInteractions() {
        isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(fabTapped))
        addGestureRecognizer(tapGesture)
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(fabLongPressed))
        longPressGesture.minimumPressDuration = 0.3
        addGestureRecognizer(longPressGesture)
        
        // Add hover effect for iPad
        if LGDevice.isIPad {
            let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(hoverChanged(_:)))
            addGestureRecognizer(hoverGesture)
        }
    }
    
    private func setupAnimations() {
        // Setup pulse animation
        setupPulseAnimation()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update ripple layer
        rippleLayer.frame = bounds
        rippleLayer.path = UIBezierPath(ovalIn: bounds).cgPath
        
        // Update pulse layer
        pulseLayer.frame = bounds
        pulseLayer.path = UIBezierPath(ovalIn: bounds).cgPath
    }
    
    // MARK: - Appearance
    private func updateAppearance() {
        // Create gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = [
            fabColor.withAlphaComponent(0.9).cgColor,
            fabColor.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = cornerRadius
        
        // Insert gradient at the bottom
        if let existingGradient = layer.sublayers?.first(where: { $0 is CAGradientLayer }) {
            existingGradient.removeFromSuperlayer()
        }
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func setupPulseAnimation() {
        pulseLayer.fillColor = UIColor.clear.cgColor
        pulseLayer.strokeColor = fabColor.withAlphaComponent(0.6).cgColor
        pulseLayer.lineWidth = 2
        pulseLayer.opacity = 0
        
        let pulseAnimation = CAAnimationGroup()
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.3
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1.0
        opacityAnimation.toValue = 0.0
        
        pulseAnimation.animations = [scaleAnimation, opacityAnimation]
        pulseAnimation.duration = 2.0
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        pulseLayer.add(pulseAnimation, forKey: "pulse")
    }
    
    // MARK: - Actions
    @objc private func fabTapped() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate tap
        animateTap {
            if self.actionButtons.isEmpty {
                self.onTap?()
            } else {
                self.toggleExpansion()
            }
        }
    }
    
    @objc private func fabLongPressed(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // Add stronger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            // Show context menu or additional options
            showContextMenu()
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
    
    // MARK: - Expansion
    func addActionButton(_ button: LGFABActionButton) {
        actionButtons.append(button)
        button.alpha = 0
        button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        
        if let superview = superview {
            superview.insertSubview(button, belowSubview: self)
        }
    }
    
    private func toggleExpansion() {
        isExpanded.toggle()
        
        if isExpanded {
            expandActionButtons()
            rotateIcon(angle: .pi / 4) // 45 degrees
        } else {
            collapseActionButtons()
            rotateIcon(angle: 0)
        }
    }
    
    private func expandActionButtons() {
        let spacing: CGFloat = LGDevice.isIPad ? 80 : 70
        
        for (index, button) in actionButtons.enumerated() {
            let angle = CGFloat(index) * (CGFloat.pi / 4) + CGFloat.pi / 2
            let x = cos(angle) * spacing
            let y = sin(angle) * spacing
            
            button.snp.remakeConstraints { make in
                make.centerX.equalTo(self).offset(x)
                make.centerY.equalTo(self).offset(-y)
            }
            
            UIView.animate(withDuration: LGAnimationDurations.medium,
                           delay: Double(index) * 0.05,
                           usingSpringWithDamping: LGAnimationDurations.spring.damping,
                           initialSpringVelocity: LGAnimationDurations.spring.velocity,
                           options: [.allowUserInteraction]) {
                button.alpha = 1
                button.transform = .identity
                button.superview?.layoutIfNeeded()
            }
        }
    }
    
    private func collapseActionButtons() {
        for (index, button) in actionButtons.enumerated() {
            button.snp.remakeConstraints { make in
                make.center.equalTo(self)
            }
            
            UIView.animate(withDuration: LGAnimationDurations.medium,
                           delay: Double(actionButtons.count - index - 1) * 0.05,
                           usingSpringWithDamping: LGAnimationDurations.spring.damping,
                           initialSpringVelocity: LGAnimationDurations.spring.velocity,
                           options: [.allowUserInteraction]) {
                button.alpha = 0
                button.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                button.superview?.layoutIfNeeded()
            }
        }
    }
    
    private func rotateIcon(angle: CGFloat) {
        UIView.animate(withDuration: LGAnimationDurations.medium,
                       delay: 0,
                       usingSpringWithDamping: LGAnimationDurations.spring.damping,
                       initialSpringVelocity: LGAnimationDurations.spring.velocity,
                       options: [.allowUserInteraction]) {
            self.iconImageView.transform = CGAffineTransform(rotationAngle: angle)
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
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        } completion: { _ in
            UIView.animate(withDuration: LGAnimationDurations.short) {
                self.transform = .identity
            } completion: { _ in
                completion()
            }
        }
    }
    
    private func animateHover(_ isHovering: Bool) {
        let scale: CGFloat = isHovering ? 1.1 : 1.0
        let shadowOpacity: Float = isHovering ? 0.4 : 0.3
        
        UIView.animate(withDuration: LGAnimationDurations.medium) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.layer.shadowOpacity = shadowOpacity
        }
    }
    
    private func createRippleEffect() {
        rippleLayer.fillColor = UIColor.white.withAlphaComponent(0.3).cgColor
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
    
    private func showContextMenu() {
        // Implementation for context menu
        // Could show options like change color, add action buttons, etc.
    }
}

// MARK: - FAB Action Button
class LGFABActionButton: LGBaseView {
    
    // MARK: - UI Elements
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    
    // MARK: - Properties
    var icon: UIImage? {
        didSet {
            iconImageView.image = icon
        }
    }
    
    var title: String? {
        didSet {
            titleLabel.text = title
            titleLabel.isHidden = title?.isEmpty ?? true
        }
    }
    
    var actionColor: UIColor = UIColor.systemBlue {
        didSet {
            updateAppearance()
        }
    }
    
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupActionButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupActionButton()
    }
    
    // MARK: - Setup
    private func setupActionButton() {
        setupActionProperties()
        setupSubviews()
        setupConstraints()
        setupInteractions()
    }
    
    private func setupActionProperties() {
        glassIntensity = 0.8
        let buttonSize: CGFloat = LGDevice.isIPad ? 48 : 44
        cornerRadius = buttonSize / 2
        
        snp.makeConstraints { make in
            make.width.height.equalTo(buttonSize)
        }
        
        // Add shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.2
        
        updateAppearance()
    }
    
    private func setupSubviews() {
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.isHidden = true
        
        addSubview(iconImageView)
        addSubview(titleLabel)
    }
    
    private func setupConstraints() {
        let iconSize: CGFloat = LGDevice.isIPad ? 22 : 20
        
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(iconSize)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(iconImageView.snp.bottom).offset(4)
        }
    }
    
    private func setupInteractions() {
        isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(actionTapped))
        addGestureRecognizer(tapGesture)
    }
    
    private func updateAppearance() {
        backgroundColor = actionColor
    }
    
    @objc private func actionTapped() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Animate tap
        UIView.animate(withDuration: LGAnimationDurations.short,
                       delay: 0,
                       usingSpringWithDamping: 0.6,
                       initialSpringVelocity: 0.8,
                       options: [.allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            UIView.animate(withDuration: LGAnimationDurations.short) {
                self.transform = .identity
            } completion: { _ in
                self.onTap?()
            }
        }
    }
}
