// Migration Banner Component
// Shows users the progress of Liquid Glass UI migration and allows toggling

import UIKit

class LGMigrationBanner: LGBaseView {
    
    // MARK: - UI Elements
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let progressView = UIProgressView()
    private let toggleButton = UIButton()
    private let phaseLabel = UILabel()
    private let dismissButton = UIButton()
    
    // MARK: - Properties
    private var autoHideTimer: Timer?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    deinit {
        autoHideTimer?.invalidate()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // Configure glass effect
        glassIntensity = 0.95
        cornerRadius = 16
        enableGlassBorder = true
        
        // Title
        titleLabel.text = "🚀 Liquid Glass UI Migration"
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        
        // Message
        messageLabel.text = "New UI framework is ready. Toggle to preview the future!"
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        
        // Phase indicator
        phaseLabel.text = "Phase 1 of 7 - Foundation Complete"
        phaseLabel.font = .systemFont(ofSize: 12, weight: .medium)
        phaseLabel.textColor = LGThemeManager.shared.accentColor
        
        // Progress
        progressView.progressTintColor = LGThemeManager.shared.accentColor
        progressView.trackTintColor = UIColor.systemGray5
        progressView.progress = 0.14 // Phase 1 of 7
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true
        
        // Toggle button
        updateToggleButton()
        toggleButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        toggleButton.layer.cornerRadius = 8
        toggleButton.backgroundColor = LGThemeManager.shared.accentColor.withAlphaComponent(0.1)
        toggleButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        
        // Dismiss button
        dismissButton.setTitle("✕", for: .normal)
        dismissButton.setTitleColor(.secondaryLabel, for: .normal)
        dismissButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        
        // Layout
        [titleLabel, messageLabel, phaseLabel, progressView, toggleButton, dismissButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            // Dismiss button (top right)
            dismissButton.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            dismissButton.widthAnchor.constraint(equalToConstant: 24),
            dismissButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor, constant: -8),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Phase label
            phaseLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8),
            phaseLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            phaseLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            // Progress
            progressView.topAnchor.constraint(equalTo: phaseLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Toggle button
            toggleButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 12),
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            toggleButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            toggleButton.heightAnchor.constraint(equalToConstant: 32),
            toggleButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        ])
        
        // Add subtle animation
        animateLiquidTransition()
    }
    
    private func updateToggleButton() {
        let title = FeatureFlags.useLiquidGlassUI ? "Using New UI ✨" : "Preview New UI"
        toggleButton.setTitle(title, for: .normal)
        toggleButton.setTitleColor(LGThemeManager.shared.accentColor, for: .normal)
    }
    
    // MARK: - Actions
    @objc private func toggleTapped() {
        // Animate button press
        UIView.animate(withDuration: 0.1, animations: {
            self.toggleButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.toggleButton.transform = .identity
            }
        }
        
        // Toggle feature flag
        FeatureFlags.useLiquidGlassUI.toggle()
        
        // Update button
        updateToggleButton()
        
        // Show feedback
        showToggleFeedback()
        
        // Haptic feedback
        if FeatureFlags.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    @objc private func dismissTapped() {
        hide()
    }
    
    private func showToggleFeedback() {
        let feedbackLabel = UILabel()
        feedbackLabel.text = FeatureFlags.useLiquidGlassUI ? "Liquid Glass UI Enabled!" : "Switched to Legacy UI"
        feedbackLabel.font = .systemFont(ofSize: 12, weight: .medium)
        feedbackLabel.textColor = LGThemeManager.shared.accentColor
        feedbackLabel.alpha = 0
        feedbackLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(feedbackLabel)
        NSLayoutConstraint.activate([
            feedbackLabel.centerXAnchor.constraint(equalTo: toggleButton.centerXAnchor),
            feedbackLabel.topAnchor.constraint(equalTo: toggleButton.bottomAnchor, constant: 4)
        ])
        
        UIView.animate(withDuration: 0.3, animations: {
            feedbackLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, animations: {
                feedbackLabel.alpha = 0
            }) { _ in
                feedbackLabel.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Public Methods
    func show(in view: UIView, autoHide: Bool = true) {
        translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(self)
        
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        ])
        
        // Animate entrance
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: -20)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.alpha = 1
            self.transform = .identity
        }
        
        // Auto-hide after delay
        if autoHide {
            autoHideTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { _ in
                self.hide()
            }
        }
    }
    
    func hide() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -20)
        }) { _ in
            self.removeFromSuperview()
        }
    }
    
    func updateProgress(_ progress: Float, phase: String) {
        UIView.animate(withDuration: 0.3) {
            self.progressView.progress = progress
        }
        phaseLabel.text = phase
    }
}
