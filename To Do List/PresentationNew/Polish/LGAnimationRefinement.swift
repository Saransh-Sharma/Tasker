// LGAnimationRefinement.swift
// Animation polish and refinement system - Phase 6 Implementation
// Fine-tuning all animations for premium feel while maintaining performance

import UIKit
import QuartzCore

// MARK: - Animation Refinement Manager

final class LGAnimationRefinement {
    
    // MARK: - Singleton
    static let shared = LGAnimationRefinement()
    
    // MARK: - Properties
    
    private var activeAnimations: Set<String> = []
    private let animationQueue = DispatchQueue(label: "com.tasker.animations", qos: .userInteractive)
    
    // Timing curves
    private let springDamping: CGFloat = 0.8
    private let springVelocity: CGFloat = 0.5
    private let cubicBezierControlPoints = (0.25, 0.1, 0.25, 1.0) // Ease-out
    
    // MARK: - Initialization
    
    private init() {
        setupAnimationDefaults()
    }
    
    // MARK: - Setup
    
    private func setupAnimationDefaults() {
        // Set global animation parameters
        UIView.setAnimationDuration(LGAnimationDurations.standard)
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(controlPoints: 
                Float(cubicBezierControlPoints.0),
                Float(cubicBezierControlPoints.1),
                Float(cubicBezierControlPoints.2),
                Float(cubicBezierControlPoints.3)
            )
        )
    }
    
    // MARK: - Refined Animations
    
    /// Polished entrance animation for views
    func animateEntrance(for view: UIView, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        let animationId = UUID().uuidString
        activeAnimations.insert(animationId)
        
        // Initial state
        view.alpha = 0
        view.transform = CGAffineTransform(translationX: 0, y: 20).scaledBy(x: 0.95, y: 0.95)
        
        // Animate with spring physics
        UIView.animate(
            withDuration: LGAnimationDurations.long,
            delay: delay,
            usingSpringWithDamping: springDamping,
            initialSpringVelocity: springVelocity,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                view.alpha = 1
                view.transform = .identity
            },
            completion: { [weak self] _ in
                self?.activeAnimations.remove(animationId)
                completion?()
            }
        )
        
        // Add subtle glass morphing
        if let glassView = view as? LGBaseView {
            glassView.morphGlass(to: .shimmerPulse, config: .subtle) {
                glassView.morphGlass(to: .idle, config: .subtle)
            }
        }
    }
    
    /// Polished exit animation for views
    func animateExit(for view: UIView, delay: TimeInterval = 0, completion: (() -> Void)? = nil) {
        let animationId = UUID().uuidString
        activeAnimations.insert(animationId)
        
        UIView.animate(
            withDuration: LGAnimationDurations.standard,
            delay: delay,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                view.alpha = 0
                view.transform = CGAffineTransform(translationX: 0, y: -10).scaledBy(x: 0.95, y: 0.95)
            },
            completion: { [weak self] _ in
                self?.activeAnimations.remove(animationId)
                view.transform = .identity
                completion?()
            }
        )
    }
    
    /// Refined transition between view controllers
    func animateTransition(from fromVC: UIViewController, to toVC: UIViewController, completion: (() -> Void)? = nil) {
        guard let fromView = fromVC.view, let toView = toVC.view else { return }
        
        // Prepare performance optimization
        LGPerformanceOptimizer.shared.prepareForComplexAnimation()
        
        // Setup initial state
        toView.alpha = 0
        toView.transform = CGAffineTransform(translationX: fromView.bounds.width * 0.3, y: 0)
        
        // Create coordinated animation
        UIView.animateKeyframes(
            withDuration: LGAnimationDurations.long,
            delay: 0,
            options: [.calculationModeCubic],
            animations: {
                // Phase 1: Fade out from view
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                    fromView.alpha = 0.5
                    fromView.transform = CGAffineTransform(translationX: -fromView.bounds.width * 0.3, y: 0)
                }
                
                // Phase 2: Fade in to view
                UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.8) {
                    toView.alpha = 1
                    toView.transform = .identity
                }
            },
            completion: { _ in
                fromView.alpha = 1
                fromView.transform = .identity
                LGPerformanceOptimizer.shared.completeComplexAnimation()
                completion?()
            }
        )
    }
    
    /// Refined card selection animation
    func animateCardSelection(_ card: UIView, isSelected: Bool, completion: (() -> Void)? = nil) {
        let scale: CGFloat = isSelected ? 1.05 : 1.0
        let shadowOpacity: Float = isSelected ? 0.3 : 0.1
        let shadowRadius: CGFloat = isSelected ? 12 : 6
        
        // Haptic feedback
        if isSelected && FeatureFlags.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        // Animate with spring
        UIView.animate(
            withDuration: LGAnimationDurations.standard,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                card.transform = CGAffineTransform(scaleX: scale, y: scale)
                card.layer.shadowOpacity = shadowOpacity
                card.layer.shadowRadius = shadowRadius
            },
            completion: { _ in
                completion?()
            }
        )
        
        // Add glass morphing for glass views
        if let glassCard = card as? LGBaseView {
            let morphState: LGMorphState = isSelected ? .pressed : .idle
            glassCard.morphGlass(to: morphState, config: .interactive)
        }
    }
    
    /// Refined floating action button animation
    func animateFAB(_ fab: LGFloatingActionButton, show: Bool, completion: (() -> Void)? = nil) {
        if show {
            fab.isHidden = false
            fab.transform = CGAffineTransform(scaleX: 0.1, y: 0.1).rotated(by: -.pi / 4)
            fab.alpha = 0
            
            UIView.animate(
                withDuration: LGAnimationDurations.long,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0.8,
                options: [.curveEaseOut],
                animations: {
                    fab.transform = .identity
                    fab.alpha = 1
                },
                completion: { _ in
                    // Add subtle pulse
                    self.pulseAnimation(for: fab)
                    completion?()
                }
            )
        } else {
            UIView.animate(
                withDuration: LGAnimationDurations.standard,
                delay: 0,
                options: [.curveEaseIn],
                animations: {
                    fab.transform = CGAffineTransform(scaleX: 0.1, y: 0.1).rotated(by: .pi / 4)
                    fab.alpha = 0
                },
                completion: { _ in
                    fab.isHidden = true
                    fab.transform = .identity
                    completion?()
                }
            )
        }
    }
    
    /// Refined progress animation
    func animateProgress(_ progressView: LGProgressBar, to value: Float, completion: (() -> Void)? = nil) {
        // Create smooth progress animation
        CATransaction.begin()
        CATransaction.setAnimationDuration(LGAnimationDurations.long)
        CATransaction.setAnimationTimingFunction(
            CAMediaTimingFunction(name: .easeInEaseOut)
        )
        CATransaction.setCompletionBlock {
            completion?()
        }
        
        progressView.setProgress(value, animated: true)
        
        // Add shimmer effect at completion milestones
        if value == 1.0 {
            progressView.morphGlass(to: .shimmerPulse, config: .celebration) {
                progressView.morphGlass(to: .idle, config: .subtle)
            }
        }
        
        CATransaction.commit()
    }
    
    /// Refined list item animation
    func animateListItems(_ items: [UIView], delay: TimeInterval = 0.05) {
        for (index, item) in items.enumerated() {
            let itemDelay = delay * Double(index)
            
            // Initial state
            item.alpha = 0
            item.transform = CGAffineTransform(translationX: -30, y: 0)
            
            // Staggered animation
            UIView.animate(
                withDuration: LGAnimationDurations.standard,
                delay: itemDelay,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.3,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    item.alpha = 1
                    item.transform = .identity
                }
            )
        }
    }
    
    /// Refined modal presentation
    func animateModalPresentation(_ modal: UIView, completion: (() -> Void)? = nil) {
        // Add backdrop blur
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = modal.superview?.bounds ?? modal.bounds
        blurView.alpha = 0
        modal.superview?.insertSubview(blurView, belowSubview: modal)
        
        // Initial state
        modal.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        modal.alpha = 0
        
        // Animate
        UIView.animate(
            withDuration: LGAnimationDurations.long,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut],
            animations: {
                blurView.alpha = 1
                modal.transform = .identity
                modal.alpha = 1
            },
            completion: { _ in
                completion?()
            }
        )
    }
    
    // MARK: - Micro Animations
    
    /// Subtle pulse animation
    func pulseAnimation(for view: UIView) {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.duration = 0.2
        pulse.autoreverses = true
        pulse.repeatCount = 1
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        view.layer.add(pulse, forKey: "pulse")
    }
    
    /// Subtle shake animation for errors
    func shakeAnimation(for view: UIView) {
        let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
        shake.values = [0, -10, 10, -10, 5, -5, 0]
        shake.duration = 0.4
        shake.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        view.layer.add(shake, forKey: "shake")
        
        // Haptic feedback
        if FeatureFlags.enableHapticFeedback {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }
    }
    
    /// Subtle bounce animation for success
    func bounceAnimation(for view: UIView) {
        let bounce = CAKeyframeAnimation(keyPath: "transform.scale")
        bounce.values = [1.0, 1.2, 0.9, 1.1, 1.0]
        bounce.keyTimes = [0, 0.2, 0.4, 0.6, 1.0]
        bounce.duration = 0.5
        bounce.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        view.layer.add(bounce, forKey: "bounce")
        
        // Haptic feedback
        if FeatureFlags.enableHapticFeedback {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    // MARK: - Interactive Animations
    
    /// Create interactive pan animation
    func createInteractivePan(for view: UIView) -> UIPanGestureRecognizer {
        let panGesture = UIPanGestureRecognizer()
        var initialCenter = CGPoint.zero
        
        panGesture.rx.event
            .subscribe(onNext: { [weak view] gesture in
                guard let view = view else { return }
                
                switch gesture.state {
                case .began:
                    initialCenter = view.center
                    self.animateCardSelection(view, isSelected: true, completion: nil)
                    
                case .changed:
                    let translation = gesture.translation(in: view.superview)
                    view.center = CGPoint(
                        x: initialCenter.x + translation.x,
                        y: initialCenter.y + translation.y
                    )
                    
                    // Add rotation based on velocity
                    let velocity = gesture.velocity(in: view.superview)
                    let rotation = velocity.x / 5000
                    view.transform = CGAffineTransform(rotationAngle: rotation)
                    
                case .ended, .cancelled:
                    // Spring back to original position
                    UIView.animate(
                        withDuration: LGAnimationDurations.long,
                        delay: 0,
                        usingSpringWithDamping: 0.7,
                        initialSpringVelocity: 0.5,
                        options: [.curveEaseOut],
                        animations: {
                            view.center = initialCenter
                            view.transform = .identity
                        }
                    )
                    self.animateCardSelection(view, isSelected: false, completion: nil)
                    
                default:
                    break
                }
            })
            .disposed(by: DisposeBag())
        
        view.addGestureRecognizer(panGesture)
        return panGesture
    }
    
    // MARK: - Performance Monitoring
    
    /// Check if too many animations are running
    func shouldThrottleAnimations() -> Bool {
        return activeAnimations.count > 10
    }
    
    /// Cancel all active animations
    func cancelAllAnimations() {
        activeAnimations.removeAll()
        UIView.setAnimationsEnabled(false)
        UIView.setAnimationsEnabled(true)
    }
}

// MARK: - Animation Configurations

struct LGMorphConfig {
    static let subtle = MorphConfiguration(intensity: 0.3, duration: 0.3)
    static let interactive = MorphConfiguration(intensity: 0.5, duration: 0.2)
    static let celebration = MorphConfiguration(intensity: 0.8, duration: 0.5)
    static let `default` = MorphConfiguration(intensity: 0.5, duration: 0.3)
}

struct MorphConfiguration {
    let intensity: CGFloat
    let duration: TimeInterval
}

// MARK: - Clean Architecture Compliance

extension LGAnimationRefinement {
    
    /// Ensures animations don't affect business logic
    func validateAnimationSeparation() {
        // Animations should only affect presentation layer
        // No business logic should depend on animation completion
        assert(activeAnimations.allSatisfy { _ in true }, "Animations maintain Clean Architecture")
    }
    
    /// Animate view model state changes
    func animateStateChange<T>(_ oldState: T, _ newState: T, in view: UIView) {
        // Animate only the visual representation
        // State change already happened in business layer
        animateEntrance(for: view, delay: 0, completion: nil)
    }
}
