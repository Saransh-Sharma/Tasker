// LGSettingsComponents.swift
// Settings UI components with glass morphism - Phase 5 Implementation
// Settings sections, items, and theme selection components

import UIKit
import SnapKit
import RxSwift
import RxCocoa

// MARK: - Settings Section

class LGSettingsSection: LGBaseView {
    
    // MARK: - UI Components
    private let headerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let stackView = UIStackView()
    
    // MARK: - Properties
    private var settingsItems: [LGSettingsItem] = []
    var onItemTap: ((LGSettingsItem) -> Void)?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSection()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSection()
    }
    
    // MARK: - Setup
    
    private func setupSection() {
        glassIntensity = 0.4
        cornerRadius = 16
        enableGlassBorder = true
        
        setupSubviews()
        setupConstraints()
        applyTheme()
    }
    
    private func setupSubviews() {
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = LGThemeManager.shared.primaryGlassColor
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.alignment = .fill
        
        headerView.addSubview(iconImageView)
        headerView.addSubview(titleLabel)
        
        addSubview(headerView)
        addSubview(stackView)
    }
    
    private func setupConstraints() {
        headerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
        
        stackView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    
    func configure(title: String, icon: UIImage?, items: [LGSettingsItem]) {
        titleLabel.text = title
        iconImageView.image = icon
        self.settingsItems = items
        
        // Clear existing items
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add new items
        for (index, item) in items.enumerated() {
            let itemView = LGSettingsItemView(item: item)
            
            itemView.onTap = { [weak self] in
                self?.onItemTap?(item)
            }
            
            stackView.addArrangedSubview(itemView)
            
            // Add separator (except for last item)
            if index < items.count - 1 {
                let separator = createSeparator()
                stackView.addArrangedSubview(separator)
            }
        }
    }
    
    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = LGThemeManager.shared.separatorColor
        separator.snp.makeConstraints { make in
            make.height.equalTo(0.5)
        }
        return separator
    }
    
    func applyTheme() {
        backgroundColor = LGThemeManager.shared.cardBackgroundColor
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        iconImageView.tintColor = LGThemeManager.shared.primaryGlassColor
    }
}

// MARK: - Settings Item View

class LGSettingsItemView: LGBaseView {
    
    // MARK: - UI Components
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let accessoryView = UIView()
    private let chevronImageView = UIImageView()
    private let toggleSwitch = UISwitch()
    private let infoLabel = UILabel()
    
    // MARK: - Properties
    private let item: LGSettingsItem
    var onTap: (() -> Void)?
    
    // MARK: - Initialization
    
    init(item: LGSettingsItem) {
        self.item = item
        super.init(frame: .zero)
        setupItemView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupItemView() {
        glassIntensity = 0.0
        
        setupSubviews()
        setupConstraints()
        setupInteractions()
        configureForItemType()
        applyTheme()
    }
    
    private func setupSubviews() {
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = LGThemeManager.shared.primaryGlassColor
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        subtitleLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        subtitleLabel.textColor = LGThemeManager.shared.secondaryTextColor
        subtitleLabel.numberOfLines = 2
        
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.tintColor = LGThemeManager.shared.tertiaryTextColor
        
        toggleSwitch.onTintColor = LGThemeManager.shared.primaryGlassColor
        
        infoLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        infoLabel.textColor = LGThemeManager.shared.secondaryTextColor
        infoLabel.textAlignment = .right
        
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(accessoryView)
    }
    
    private func setupConstraints() {
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(16)
            make.top.equalToSuperview().offset(16)
            make.trailing.equalTo(accessoryView.snp.leading).offset(-16)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        accessoryView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
        }
        
        snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(60)
        }
    }
    
    private func setupInteractions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    private func configureForItemType() {
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        iconImageView.image = item.icon
        
        // Configure accessory based on item type
        switch item.type {
        case .disclosure:
            accessoryView.addSubview(chevronImageView)
            chevronImageView.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
                make.size.equalTo(16)
            }
            
        case .toggle(let isOn):
            toggleSwitch.isOn = isOn
            accessoryView.addSubview(toggleSwitch)
            toggleSwitch.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
            }
            
            toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
            
        case .action, .destructive:
            accessoryView.addSubview(chevronImageView)
            chevronImageView.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
                make.size.equalTo(16)
            }
            
            if case .destructive = item.type {
                titleLabel.textColor = .systemRed
            }
            
        case .info:
            infoLabel.text = item.subtitle
            subtitleLabel.isHidden = true
            accessoryView.addSubview(infoLabel)
            infoLabel.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }
    
    @objc private func handleTap() {
        // Don't handle tap for toggle items (handled by switch)
        if case .toggle = item.type {
            return
        }
        
        morphGlass(to: .pressed) { [weak self] in
            self?.morphGlass(to: .idle)
            self?.onTap?()
        }
    }
    
    @objc private func toggleChanged() {
        onTap?()
        
        // Haptic feedback
        if FeatureFlags.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func applyTheme() {
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        subtitleLabel.textColor = LGThemeManager.shared.secondaryTextColor
        iconImageView.tintColor = LGThemeManager.shared.primaryGlassColor
        toggleSwitch.onTintColor = LGThemeManager.shared.primaryGlassColor
    }
}

// MARK: - Theme Button

class LGThemeButton: LGBaseView {
    
    // MARK: - UI Components
    private let previewView = UIView()
    private let titleLabel = UILabel()
    private let checkmarkImageView = UIImageView()
    
    // MARK: - Properties
    let theme: LGTheme
    var onTap: (() -> Void)?
    
    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    // MARK: - Initialization
    
    init(theme: LGTheme) {
        self.theme = theme
        super.init(frame: .zero)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupButton() {
        glassIntensity = 0.5
        cornerRadius = 12
        enableGlassBorder = true
        
        setupSubviews()
        setupConstraints()
        setupInteractions()
        configureForTheme()
        updateAppearance()
    }
    
    private func setupSubviews() {
        previewView.layer.cornerRadius = 8
        previewView.clipsToBounds = true
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.tintColor = .systemGreen
        checkmarkImageView.isHidden = true
        
        addSubview(previewView)
        addSubview(titleLabel)
        addSubview(checkmarkImageView)
    }
    
    private func setupConstraints() {
        previewView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8)
            make.top.equalTo(previewView.snp.bottom).offset(8)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        checkmarkImageView.snp.makeConstraints { make in
            make.trailing.top.equalToSuperview().inset(4)
            make.size.equalTo(20)
        }
    }
    
    private func setupInteractions() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    private func configureForTheme() {
        titleLabel.text = theme.displayName
        
        // Create theme preview
        switch theme {
        case .light:
            previewView.backgroundColor = .white
            previewView.layer.borderWidth = 1
            previewView.layer.borderColor = UIColor.lightGray.cgColor
            
        case .dark:
            previewView.backgroundColor = .black
            
        case .auto:
            // Split preview
            let lightView = UIView()
            lightView.backgroundColor = .white
            let darkView = UIView()
            darkView.backgroundColor = .black
            
            previewView.addSubview(lightView)
            previewView.addSubview(darkView)
            
            lightView.snp.makeConstraints { make in
                make.leading.top.bottom.equalToSuperview()
                make.width.equalToSuperview().multipliedBy(0.5)
            }
            
            darkView.snp.makeConstraints { make in
                make.trailing.top.bottom.equalToSuperview()
                make.width.equalToSuperview().multipliedBy(0.5)
            }
            
        case .aurora:
            // Gradient preview
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor.systemPurple.cgColor,
                UIColor.systemPink.cgColor,
                UIColor.systemBlue.cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 24)
            previewView.layer.addSublayer(gradientLayer)
            
        case .ocean:
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor.systemBlue.cgColor,
                UIColor.systemTeal.cgColor,
                UIColor.systemCyan.cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 24)
            previewView.layer.addSublayer(gradientLayer)
            
        case .sunset:
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = [
                UIColor.systemOrange.cgColor,
                UIColor.systemRed.cgColor,
                UIColor.systemPink.cgColor
            ]
            gradientLayer.startPoint = CGPoint(x: 0, y: 0)
            gradientLayer.endPoint = CGPoint(x: 1, y: 1)
            gradientLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 24)
            previewView.layer.addSublayer(gradientLayer)
        }
    }
    
    @objc private func handleTap() {
        morphGlass(to: .pressed) { [weak self] in
            self?.morphGlass(to: .idle)
            self?.onTap?()
        }
    }
    
    private func updateAppearance() {
        checkmarkImageView.isHidden = !isSelected
        
        if isSelected {
            glassIntensity = 0.8
            backgroundColor = LGThemeManager.shared.primaryGlassColor.withAlphaComponent(0.2)
            titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        } else {
            glassIntensity = 0.3
            backgroundColor = .clear
            titleLabel.textColor = LGThemeManager.shared.secondaryTextColor
        }
    }
}

// MARK: - Settings Item Model

struct LGSettingsItem {
    let title: String
    let subtitle: String?
    let icon: UIImage?
    let type: ItemType
    
    enum ItemType {
        case disclosure
        case toggle(Bool)
        case action
        case destructive
        case info
    }
}

// MARK: - Theme Manager Extensions

extension LGThemeManager {
    var cardBackgroundColor: UIColor {
        switch currentTheme {
        case .light:
            return UIColor.white.withAlphaComponent(0.8)
        case .dark:
            return UIColor.black.withAlphaComponent(0.8)
        case .auto:
            return UIColor.systemBackground.withAlphaComponent(0.8)
        case .aurora:
            return UIColor.systemPurple.withAlphaComponent(0.1)
        case .ocean:
            return UIColor.systemBlue.withAlphaComponent(0.1)
        case .sunset:
            return UIColor.systemOrange.withAlphaComponent(0.1)
        }
    }
    
    var separatorColor: UIColor {
        return UIColor.separator.withAlphaComponent(0.3)
    }
    
    var tertiaryTextColor: UIColor {
        return UIColor.tertiaryLabel
    }
}
