// LGProgressBar.swift
// Progress bar component with liquid animations and glass morphism
// Adaptive design for iPhone and iPad with smooth progress transitions

import UIKit
import SnapKit

// MARK: - Progress Bar Component
class LGProgressBar: LGBaseView {
    
    // MARK: - UI Elements
    private let trackView = UIView()
    private let progressView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let shimmerLayer = CAGradientLayer()
    
    // MARK: - Properties
    private var _progress: Float = 0.0
    var progress: Float {
        get { return _progress }
        set { setProgress(newValue, animated: false) }
    }
    
    var trackColor: UIColor = UIColor.systemGray5 {
        didSet { updateTrackAppearance() }
    }
    
    var progressColor: UIColor = UIColor.systemBlue {
        didSet { updateProgressAppearance() }
    }
    
    var showShimmer: Bool = true {
        didSet { updateShimmerVisibility() }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupProgressBar()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupProgressBar()
    }
    
    // MARK: - Setup
    private func setupProgressBar() {
        setupProgressBarProperties()
        setupSubviews()
        setupConstraints()
        setupAnimations()
    }
    
    private func setupProgressBarProperties() {
        // Progress bar specific properties
        glassIntensity = 0.3
        cornerRadius = 2
        backgroundColor = .clear
        
        // Set height constraint
        snp.makeConstraints { make in
            make.height.equalTo(4)
        }
    }
    
    private func setupSubviews() {
        // Configure track view
        trackView.backgroundColor = trackColor
        trackView.layer.cornerRadius = 2
        trackView.layer.masksToBounds = true
        
        // Configure progress view
        progressView.layer.cornerRadius = 2
        progressView.layer.masksToBounds = true
        progressView.layer.addSublayer(gradientLayer)
        
        // Configure shimmer layer
        shimmerLayer.colors = [
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.3).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.locations = [0, 0.5, 1]
        progressView.layer.addSublayer(shimmerLayer)
        
        // Add subviews
        addSubview(trackView)
        addSubview(progressView)
        
        // Initial setup
        updateTrackAppearance()
        updateProgressAppearance()
    }
    
    private func setupConstraints() {
        // Track view fills the entire progress bar
        trackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Progress view starts with zero width
        progressView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(0)
        }
    }
    
    private func setupAnimations() {
        // Setup shimmer animation
        let shimmerAnimation = CABasicAnimation(keyPath: "locations")
        shimmerAnimation.fromValue = [-0.3, -0.15, 0]
        shimmerAnimation.toValue = [1, 1.15, 1.3]
        shimmerAnimation.duration = 1.5
        shimmerAnimation.repeatCount = .infinity
        shimmerLayer.add(shimmerAnimation, forKey: "shimmer")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update gradient frame
        gradientLayer.frame = progressView.bounds
        shimmerLayer.frame = progressView.bounds
        
        // Update corner radius based on height
        let radius = bounds.height / 2
        cornerRadius = radius
        trackView.layer.cornerRadius = radius
        progressView.layer.cornerRadius = radius
    }
    
    // MARK: - Progress Management
    func setProgress(_ progress: Float, animated: Bool) {
        let clampedProgress = max(0.0, min(1.0, progress))
        _progress = clampedProgress
        
        let targetWidth = bounds.width * CGFloat(clampedProgress)
        
        if animated {
            animateProgressChange(to: targetWidth)
        } else {
            updateProgressWidth(targetWidth)
        }
        
        // Update shimmer visibility based on progress
        updateShimmerVisibility()
    }
    
    private func updateProgressWidth(_ width: CGFloat) {
        progressView.snp.updateConstraints { make in
            make.width.equalTo(width)
        }
        layoutIfNeeded()
    }
    
    private func animateProgressChange(to width: CGFloat) {
        UIView.animate(withDuration: LGAnimationDurations.medium,
                       delay: 0,
                       usingSpringWithDamping: LGAnimationDurations.spring.damping,
                       initialSpringVelocity: LGAnimationDurations.spring.velocity,
                       options: [.allowUserInteraction]) {
            self.updateProgressWidth(width)
        }
    }
    
    // MARK: - Appearance Updates
    private func updateTrackAppearance() {
        trackView.backgroundColor = trackColor
    }
    
    private func updateProgressAppearance() {
        // Create gradient colors based on progress color
        let lightColor = progressColor.withAlphaComponent(0.8)
        let darkColor = progressColor
        
        gradientLayer.colors = [lightColor.cgColor, darkColor.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
    }
    
    private func updateShimmerVisibility() {
        let shouldShowShimmer = showShimmer && progress > 0 && progress < 1.0
        shimmerLayer.isHidden = !shouldShowShimmer
    }
    
    // MARK: - Convenience Methods
    func setProgress(_ progress: Float, animated: Bool, completion: (() -> Void)? = nil) {
        setProgress(progress, animated: animated)
        
        if animated {
            DispatchQueue.main.asyncAfter(deadline: .now() + LGAnimationDurations.medium) {
                completion?()
            }
        } else {
            completion?()
        }
    }
    
    func incrementProgress(by amount: Float, animated: Bool = true) {
        setProgress(progress + amount, animated: animated)
    }
    
    func reset(animated: Bool = true) {
        setProgress(0.0, animated: animated)
    }
    
    func complete(animated: Bool = true) {
        setProgress(1.0, animated: animated)
    }
}

// MARK: - Progress Bar Styles
extension LGProgressBar {
    
    enum Style {
        case `default`
        case success
        case warning
        case error
        case info
        
        var colors: (track: UIColor, progress: UIColor) {
            switch self {
            case .default:
                return (.systemGray5, .systemBlue)
            case .success:
                return (.systemGreen.withAlphaComponent(0.2), .systemGreen)
            case .warning:
                return (.systemOrange.withAlphaComponent(0.2), .systemOrange)
            case .error:
                return (.systemRed.withAlphaComponent(0.2), .systemRed)
            case .info:
                return (.systemTeal.withAlphaComponent(0.2), .systemTeal)
            }
        }
    }
    
    func applyStyle(_ style: Style) {
        let colors = style.colors
        trackColor = colors.track
        progressColor = colors.progress
    }
}

// MARK: - Circular Progress Bar
class LGCircularProgressBar: LGBaseView {
    
    // MARK: - UI Elements
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let gradientLayer = CAGradientLayer()
    private let centerLabel = UILabel()
    
    // MARK: - Properties
    private var _progress: Float = 0.0
    var progress: Float {
        get { return _progress }
        set { setProgress(newValue, animated: false) }
    }
    
    var lineWidth: CGFloat = 8 {
        didSet { updateLayers() }
    }
    
    var trackColor: UIColor = UIColor.systemGray5 {
        didSet { trackLayer.strokeColor = trackColor.cgColor }
    }
    
    var progressColor: UIColor = UIColor.systemBlue {
        didSet { updateProgressAppearance() }
    }
    
    var showPercentage: Bool = true {
        didSet { centerLabel.isHidden = !showPercentage }
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCircularProgress()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCircularProgress()
    }
    
    // MARK: - Setup
    private func setupCircularProgress() {
        setupCircularProperties()
        setupLayers()
        setupCenterLabel()
    }
    
    private func setupCircularProperties() {
        glassIntensity = 0.4
        backgroundColor = .clear
    }
    
    private func setupLayers() {
        // Configure track layer
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = trackColor.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.lineCap = .round
        
        // Configure progress layer
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0
        
        // Add gradient to progress layer
        progressLayer.mask = gradientLayer
        
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
    }
    
    private func setupCenterLabel() {
        centerLabel.textAlignment = .center
        centerLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .semibold)
        centerLabel.textColor = .label
        centerLabel.text = "0%"
        
        addSubview(centerLabel)
        centerLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayers()
    }
    
    private func updateLayers() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - lineWidth / 2
        
        let path = UIBezierPath(arcCenter: center,
                               radius: radius,
                               startAngle: -CGFloat.pi / 2,
                               endAngle: 3 * CGFloat.pi / 2,
                               clockwise: true)
        
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        
        gradientLayer.frame = bounds
        updateProgressAppearance()
    }
    
    // MARK: - Progress Management
    func setProgress(_ progress: Float, animated: Bool) {
        let clampedProgress = max(0.0, min(1.0, progress))
        _progress = clampedProgress
        
        if animated {
            animateProgress(to: clampedProgress)
        } else {
            progressLayer.strokeEnd = CGFloat(clampedProgress)
        }
        
        updateCenterLabel()
    }
    
    private func animateProgress(to progress: Float) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = progress
        animation.duration = LGAnimationDurations.medium
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        progressLayer.strokeEnd = CGFloat(progress)
        progressLayer.add(animation, forKey: "progressAnimation")
    }
    
    private func updateProgressAppearance() {
        let lightColor = progressColor.withAlphaComponent(0.8)
        let darkColor = progressColor
        
        gradientLayer.colors = [lightColor.cgColor, darkColor.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.type = .conic
    }
    
    private func updateCenterLabel() {
        if showPercentage {
            let percentage = Int(progress * 100)
            centerLabel.text = "\(percentage)%"
        }
    }
    
    // MARK: - Advanced Morphing Effects for Progress Bar
    
    /// Morphs the progress bar with liquid glass effects
    func morphProgress(to state: LGMorphState, config: LGMorphConfig = .default, completion: (() -> Void)? = nil) {
        guard FeatureFlags.enableLiquidAnimations else {
            completion?()
            return
        }
        
        switch state {
        case .idle:
            morphToIdleProgress(config: config, completion: completion)
        case .shimmerPulse:
            morphToShimmerPulseProgress(config: config, completion: completion)
        case .liquidWave:
            morphToLiquidWaveProgress(config: config, completion: completion)
        case .expanding:
            morphToExpandingProgress(config: config, completion: completion)
        case .glassRipple:
            morphToGlassRippleProgress(config: config, completion: completion)
        default:
            // Use base class morphing for other states
            morphGlass(to: state, config: config, completion: completion)
        }
    }
    
    private func morphToIdleProgress(config: LGMorphConfig, completion: (() -> Void)?) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(config.duration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setCompletionBlock(completion)
        
        // Reset to normal state
        layer.transform = CATransform3DIdentity
        alpha = 1.0
        stopAllProgressAnimations()
        
        CATransaction.commit()
    }
    
    private func morphToShimmerPulseProgress(config: LGMorphConfig, completion: (() -> Void)?) {
        startProgressShimmerPulse(config: config)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration * 2) {
            self.stopProgressShimmerPulse()
            completion?()
        }
    }
    
    private func morphToLiquidWaveProgress(config: LGMorphConfig, completion: (() -> Void)?) {
        startProgressLiquidWave(config: config)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration * 1.5) {
            self.stopProgressLiquidWave()
            completion?()
        }
    }
    
    private func morphToExpandingProgress(config: LGMorphConfig, completion: (() -> Void)?) {
        let scaleAnimation = CASpringAnimation(keyPath: "transform.scale.y")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.2
        scaleAnimation.duration = config.duration
        scaleAnimation.damping = 8
        scaleAnimation.initialVelocity = 3
        scaleAnimation.stiffness = 100
        scaleAnimation.autoreverses = true
        
        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        layer.add(scaleAnimation, forKey: "expandingProgress")
        CATransaction.commit()
    }
    
    private func morphToGlassRippleProgress(config: LGMorphConfig, completion: (() -> Void)?) {
        createProgressRippleEffect(config: config)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration) {
            completion?()
        }
    }
    
    // MARK: - Progress-Specific Effects
    
    private func startProgressShimmerPulse(config: LGMorphConfig) {
        guard shimmerEnabled else { return }
        
        // Enhanced shimmer effect for progress bar
        let shimmerLayer = CAGradientLayer()
        shimmerLayer.frame = progressView.bounds
        shimmerLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.6).cgColor,
            UIColor.clear.cgColor
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerLayer.locations = [0, 0.5, 1]
        
        progressView.layer.addSublayer(shimmerLayer)
        
        let shimmerAnimation = CABasicAnimation(keyPath: "locations")
        shimmerAnimation.fromValue = [-0.5, -0.25, 0]
        shimmerAnimation.toValue = [1, 1.25, 1.5]
        shimmerAnimation.duration = config.duration / 2
        shimmerAnimation.repeatCount = .infinity
        shimmerAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        shimmerLayer.add(shimmerAnimation, forKey: "progressShimmerPulse")
        
        // Store reference for cleanup
        shimmerLayer.setValue("progressShimmer", forKey: "effectType")
    }
    
    private func stopProgressShimmerPulse() {
        progressView.layer.sublayers?.forEach { layer in
            if layer.value(forKey: "effectType") as? String == "progressShimmer" {
                layer.removeFromSuperlayer()
            }
        }
    }
    
    private func startProgressLiquidWave(config: LGMorphConfig) {
        // Create liquid wave effect that follows progress
        let waveLayer = CAShapeLayer()
        let waveHeight: CGFloat = 4.0
        
        let wavePath = createWavePath(height: waveHeight, phase: 0)
        waveLayer.path = wavePath.cgPath
        waveLayer.fillColor = progressColor.withAlphaComponent(0.3).cgColor
        waveLayer.strokeColor = UIColor.clear.cgColor
        
        progressView.layer.addSublayer(waveLayer)
        
        // Animate wave movement
        let waveAnimation = CABasicAnimation(keyPath: "path")
        let endWavePath = createWavePath(height: waveHeight, phase: .pi * 2)
        waveAnimation.fromValue = wavePath.cgPath
        waveAnimation.toValue = endWavePath.cgPath
        waveAnimation.duration = config.duration / 3
        waveAnimation.repeatCount = .infinity
        waveAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
        
        waveLayer.add(waveAnimation, forKey: "liquidWave")
        waveLayer.setValue("liquidWave", forKey: "effectType")
        
        // Add progress pulsing
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.3
        pulseAnimation.toValue = 0.8
        pulseAnimation.duration = config.duration / 4
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        
        progressView.layer.add(pulseAnimation, forKey: "progressPulse")
    }
    
    private func stopProgressLiquidWave() {
        progressView.layer.sublayers?.forEach { layer in
            if layer.value(forKey: "effectType") as? String == "liquidWave" {
                layer.removeFromSuperlayer()
            }
        }
        progressView.layer.removeAnimation(forKey: "progressPulse")
    }
    
    private func createWavePath(height: CGFloat, phase: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let width = progressView.bounds.width
        let progressHeight = progressView.bounds.height
        
        path.move(to: CGPoint(x: 0, y: progressHeight))
        
        for x in stride(from: 0, through: width, by: 2) {
            let y = progressHeight - height * sin((x / width) * .pi * 4 + phase)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: progressHeight))
        path.addLine(to: CGPoint(x: 0, y: progressHeight))
        path.close()
        
        return path
    }
    
    private func createProgressRippleEffect(config: LGMorphConfig) {
        let rippleCount = 3
        let baseDelay: TimeInterval = 0.2
        
        for i in 0..<rippleCount {
            let delay = TimeInterval(i) * baseDelay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.createSingleProgressRipple(config: config)
            }
        }
    }
    
    private func createSingleProgressRipple(config: LGMorphConfig) {
        let ripple = CAShapeLayer()
        let startRadius: CGFloat = 2
        let endRadius: CGFloat = bounds.height * 2
        let center = CGPoint(x: bounds.width * CGFloat(progress), y: bounds.height / 2)
        
        let startPath = UIBezierPath(arcCenter: center, radius: startRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        let endPath = UIBezierPath(arcCenter: center, radius: endRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        
        ripple.path = startPath.cgPath
        ripple.fillColor = UIColor.clear.cgColor
        ripple.strokeColor = progressColor.withAlphaComponent(0.4).cgColor
        ripple.lineWidth = 1.5
        
        layer.addSublayer(ripple)
        
        let pathAnimation = CABasicAnimation(keyPath: "path")
        pathAnimation.fromValue = startPath.cgPath
        pathAnimation.toValue = endPath.cgPath
        pathAnimation.duration = config.duration * 0.8
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 1.0
        opacityAnimation.toValue = 0.0
        opacityAnimation.duration = config.duration * 0.8
        
        let group = CAAnimationGroup()
        group.animations = [pathAnimation, opacityAnimation]
        group.duration = config.duration * 0.8
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        ripple.add(group, forKey: "progressRipple")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + config.duration * 0.8) {
            ripple.removeFromSuperlayer()
        }
    }
    
    private func stopAllProgressAnimations() {
        stopProgressShimmerPulse()
        stopProgressLiquidWave()
        layer.removeAllAnimations()
        progressView.layer.removeAllAnimations()
    }
    
    // MARK: - Enhanced Progress Animation
    
    /// Sets progress with advanced morphing effects
    func setProgressWithMorphing(_ progress: Float, morphState: LGMorphState = .liquidWave, animated: Bool = true) {
        // First set the progress
        setProgress(progress, animated: animated)
        
        // Then apply morphing effect
        if animated && FeatureFlags.enableLiquidAnimations {
            morphProgress(to: morphState, config: .default)
        }
    }
    
    /// Animates progress with celebration effect for completion
    func celebrateCompletion() {
        guard progress >= 1.0 else { return }
        
        // Celebration sequence
        morphProgress(to: .expanding, config: .dramatic) {
            self.morphProgress(to: .shimmerPulse, config: .default) {
                self.morphProgress(to: .glassRipple, config: .subtle) {
                    self.morphProgress(to: .idle, config: .subtle)
                }
            }
        }
        
        // Haptic feedback for completion
        if FeatureFlags.enableHapticFeedback {
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
}
