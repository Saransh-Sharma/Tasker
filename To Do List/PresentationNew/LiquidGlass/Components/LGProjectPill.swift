// LGProjectPill.swift
// Project pill component with liquid animations and adaptive design
// Displays project information with glass morphism effects

import UIKit
import SnapKit

// MARK: - Project Pill Component
class LGProjectPill: LGBaseView {
    
    // MARK: - UI Elements
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let gradientLayer = CAGradientLayer()
    
    // MARK: - Properties
    var project: ProjectData? {
        didSet {
            updateContent()
        }
    }
    
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPill()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPill()
    }
    
    // MARK: - Setup
    private func setupPill() {
        setupPillProperties()
        setupSubviews()
        setupConstraints()
        setupInteractions()
    }
    
    private func setupPillProperties() {
        // Pill-specific glass properties
        glassIntensity = 0.7
        cornerRadius = LGDevice.isIPad ? 16 : 14
        
        // Add gradient background
        layer.insertSublayer(gradientLayer, at: 0)
        
        // Enable interaction
        isUserInteractionEnabled = true
    }
    
    private func setupSubviews() {
        // Configure icon
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        
        // Configure title label
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        
        // Configure count label
        countLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize - 2, weight: .semibold)
        countLabel.textColor = .white.withAlphaComponent(0.9)
        countLabel.textAlignment = .center
        countLabel.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        countLabel.layer.cornerRadius = 8
        countLabel.layer.masksToBounds = true
        
        // Add subviews
        [iconView, titleLabel, countLabel].forEach {
            addSubview($0)
        }
    }
    
    private func setupConstraints() {
        let horizontalPadding: CGFloat = LGDevice.isIPad ? 12 : 10
        let iconSize: CGFloat = LGDevice.isIPad ? 18 : 16
        
        // Icon constraints
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(iconSize)
        }
        
        // Title label constraints
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(6)
            make.centerY.equalToSuperview()
        }
        
        // Count label constraints
        countLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-horizontalPadding)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(20)
            make.height.equalTo(16)
        }
        
        // Set content compression resistance
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        countLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    private func setupInteractions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(pillTapped))
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
    }
    
    // MARK: - Configuration
    func configure(with project: ProjectData) {
        self.project = project
        updateContent()
    }
    
    private func updateContent() {
        guard let project = project else { return }
        
        titleLabel.text = project.name
        iconView.image = UIImage(systemName: project.iconName)
        
        // Update count if available
        if project.taskCount > 0 {
            countLabel.text = "\(project.taskCount)"
            countLabel.isHidden = false
        } else {
            countLabel.isHidden = true
        }
        
        // Update gradient colors
        updateGradient(with: project.color)
        
        // Animate appearance
        animateAppearance()
    }
    
    private func updateGradient(with color: UIColor) {
        let lightColor = color.withAlphaComponent(0.8)
        let darkColor = color.withAlphaComponent(1.0)
        
        gradientLayer.colors = [lightColor.cgColor, darkColor.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = cornerRadius
    }
    
    // MARK: - Actions
    @objc private func pillTapped() {
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
    private func animateAppearance() {
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        alpha = 0
        
        UIView.animate(withDuration: LGAnimationDurations.medium,
                       delay: 0,
                       usingSpringWithDamping: LGAnimationDurations.spring.damping,
                       initialSpringVelocity: LGAnimationDurations.spring.velocity,
                       options: [.allowUserInteraction]) {
            self.transform = .identity
            self.alpha = 1
        }
    }
    
    private func animateTap(completion: @escaping () -> Void) {
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
        let scale: CGFloat = isHovering ? 1.05 : 1.0
        let brightness: CGFloat = isHovering ? 1.1 : 1.0
        
        UIView.animate(withDuration: LGAnimationDurations.medium) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
            
            // Adjust brightness
            let filter = CIFilter(name: "CIColorControls")
            filter?.setValue(brightness, forKey: kCIInputBrightnessKey)
            self.layer.filters = isHovering ? [filter] : nil
        }
    }
}

// MARK: - Project Data Model
struct ProjectData {
    let id: String
    let name: String
    let color: UIColor
    let iconName: String
    let taskCount: Int
    let completedCount: Int
    
    init(id: String, name: String, color: UIColor, iconName: String = "folder.fill", 
         taskCount: Int = 0, completedCount: Int = 0) {
        self.id = id
        self.name = name
        self.color = color
        self.iconName = iconName
        self.taskCount = taskCount
        self.completedCount = completedCount
    }
    
    var completionPercentage: Float {
        guard taskCount > 0 else { return 0 }
        return Float(completedCount) / Float(taskCount)
    }
}

// MARK: - Predefined Project Colors
extension ProjectData {
    static let defaultColors: [UIColor] = [
        .systemBlue, .systemGreen, .systemOrange, .systemRed,
        .systemPurple, .systemTeal, .systemIndigo, .systemPink,
        .systemYellow, .systemMint, .systemCyan
    ]
    
    static func randomColor() -> UIColor {
        return defaultColors.randomElement() ?? .systemBlue
    }
}
