// LGSettingsViewController.swift
// Settings Screen with Liquid Glass UI - Phase 5 Implementation
// Modern settings interface with glass panels and theme integration

import UIKit
import SnapKit
import RxSwift
import RxCocoa

class LGSettingsViewController: UIViewController {
    
    // MARK: - Dependencies
    private let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    
    // Navigation
    private let navigationGlassView = LGBaseView()
    private let titleLabel = UILabel()
    private let profileButton = LGButton(style: .ghost, size: .medium)
    
    // Content
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    // Settings Sections
    private let appearanceSection = LGSettingsSection()
    private let notificationsSection = LGSettingsSection()
    private let dataSection = LGSettingsSection()
    private let aboutSection = LGSettingsSection()
    
    // Theme Selection
    private let themeContainer = LGBaseView()
    private let themeStackView = UIStackView()
    private var themeButtons: [LGThemeButton] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupBindings()
        applyTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateEntrance()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        
        setupNavigationView()
        setupScrollView()
        setupSections()
        setupThemeSelection()
    }
    
    private func setupNavigationView() {
        navigationGlassView.glassIntensity = 0.9
        navigationGlassView.cornerRadius = 0
        
        titleLabel.text = "Settings"
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.largeTitleFontSize, weight: .bold)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        profileButton.setTitle("Profile", for: .normal)
        profileButton.icon = UIImage(systemName: "person.circle")
        
        navigationGlassView.addSubview(titleLabel)
        navigationGlassView.addSubview(profileButton)
        view.addSubview(navigationGlassView)
    }
    
    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 40, right: 0)
        
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        
        scrollView.addSubview(stackView)
        view.addSubview(scrollView)
    }
    
    private func setupSections() {
        // Appearance Section
        appearanceSection.configure(
            title: "Appearance",
            icon: UIImage(systemName: "paintbrush.fill"),
            items: [
                LGSettingsItem(
                    title: "Theme",
                    subtitle: "Choose your preferred theme",
                    icon: UIImage(systemName: "circle.lefthalf.filled"),
                    type: .disclosure
                ),
                LGSettingsItem(
                    title: "Liquid Glass Effects",
                    subtitle: "Enable advanced glass morphism",
                    icon: UIImage(systemName: "sparkles"),
                    type: .toggle(FeatureFlags.useLiquidGlassUI)
                ),
                LGSettingsItem(
                    title: "Animations",
                    subtitle: "Enable liquid animations",
                    icon: UIImage(systemName: "wand.and.stars"),
                    type: .toggle(FeatureFlags.enableLiquidAnimations)
                ),
                LGSettingsItem(
                    title: "Haptic Feedback",
                    subtitle: "Enable haptic responses",
                    icon: UIImage(systemName: "hand.tap"),
                    type: .toggle(FeatureFlags.enableHapticFeedback)
                )
            ]
        )
        
        // Notifications Section
        notificationsSection.configure(
            title: "Notifications",
            icon: UIImage(systemName: "bell.fill"),
            items: [
                LGSettingsItem(
                    title: "Task Reminders",
                    subtitle: "Get notified about due tasks",
                    icon: UIImage(systemName: "alarm"),
                    type: .toggle(true)
                ),
                LGSettingsItem(
                    title: "Daily Summary",
                    subtitle: "Daily progress notifications",
                    icon: UIImage(systemName: "chart.bar"),
                    type: .toggle(true)
                ),
                LGSettingsItem(
                    title: "Project Updates",
                    subtitle: "Project milestone notifications",
                    icon: UIImage(systemName: "folder.badge"),
                    type: .toggle(false)
                )
            ]
        )
        
        // Data & Privacy Section
        dataSection.configure(
            title: "Data & Privacy",
            icon: UIImage(systemName: "lock.shield.fill"),
            items: [
                LGSettingsItem(
                    title: "Export Data",
                    subtitle: "Export your tasks and projects",
                    icon: UIImage(systemName: "square.and.arrow.up"),
                    type: .action
                ),
                LGSettingsItem(
                    title: "Import Data",
                    subtitle: "Import from other apps",
                    icon: UIImage(systemName: "square.and.arrow.down"),
                    type: .action
                ),
                LGSettingsItem(
                    title: "Clear Cache",
                    subtitle: "Free up storage space",
                    icon: UIImage(systemName: "trash"),
                    type: .action
                ),
                LGSettingsItem(
                    title: "Reset App",
                    subtitle: "Reset all settings and data",
                    icon: UIImage(systemName: "exclamationmark.triangle"),
                    type: .destructive
                )
            ]
        )
        
        // About Section
        aboutSection.configure(
            title: "About",
            icon: UIImage(systemName: "info.circle.fill"),
            items: [
                LGSettingsItem(
                    title: "Version",
                    subtitle: "1.0.0 (Build 1)",
                    icon: UIImage(systemName: "app.badge"),
                    type: .info
                ),
                LGSettingsItem(
                    title: "What's New",
                    subtitle: "See latest features",
                    icon: UIImage(systemName: "star.fill"),
                    type: .disclosure
                ),
                LGSettingsItem(
                    title: "Privacy Policy",
                    subtitle: "Read our privacy policy",
                    icon: UIImage(systemName: "doc.text"),
                    type: .disclosure
                ),
                LGSettingsItem(
                    title: "Contact Support",
                    subtitle: "Get help and support",
                    icon: UIImage(systemName: "questionmark.circle"),
                    type: .disclosure
                )
            ]
        )
        
        stackView.addArrangedSubview(appearanceSection)
        stackView.addArrangedSubview(themeContainer)
        stackView.addArrangedSubview(notificationsSection)
        stackView.addArrangedSubview(dataSection)
        stackView.addArrangedSubview(aboutSection)
    }
    
    private func setupThemeSelection() {
        themeContainer.glassIntensity = 0.3
        themeContainer.cornerRadius = 16
        
        let titleLabel = UILabel()
        titleLabel.text = "Theme Selection"
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        themeStackView.axis = .horizontal
        themeStackView.distribution = .fillEqually
        themeStackView.spacing = 12
        
        // Create theme buttons
        for theme in LGTheme.allCases {
            let themeButton = LGThemeButton(theme: theme)
            themeButton.isSelected = LGThemeManager.shared.currentTheme == theme
            
            themeButton.onTap = { [weak self] in
                self?.selectTheme(theme)
            }
            
            themeButtons.append(themeButton)
            themeStackView.addArrangedSubview(themeButton)
        }
        
        themeContainer.addSubview(titleLabel)
        themeContainer.addSubview(themeStackView)
        
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        
        themeStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
            make.height.equalTo(LGDevice.isIPad ? 80 : 60)
        }
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        navigationGlassView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(100)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        profileButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(80)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(navigationGlassView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-32)
        }
    }
    
    // MARK: - Bindings
    
    private func setupBindings() {
        profileButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.presentProfile()
            })
            .disposed(by: disposeBag)
        
        // Settings item actions
        appearanceSection.onItemTap = { [weak self] item in
            self?.handleAppearanceItemTap(item)
        }
        
        notificationsSection.onItemTap = { [weak self] item in
            self?.handleNotificationItemTap(item)
        }
        
        dataSection.onItemTap = { [weak self] item in
            self?.handleDataItemTap(item)
        }
        
        aboutSection.onItemTap = { [weak self] item in
            self?.handleAboutItemTap(item)
        }
    }
    
    // MARK: - Actions
    
    private func selectTheme(_ theme: LGTheme) {
        // Update theme buttons
        themeButtons.forEach { button in
            button.isSelected = button.theme == theme
        }
        
        // Apply theme
        LGThemeManager.shared.currentTheme = theme
        
        // Animate theme change
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut) {
            self.applyTheme()
        }
        
        // Haptic feedback
        if FeatureFlags.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    private func handleAppearanceItemTap(_ item: LGSettingsItem) {
        switch item.title {
        case "Theme":
            // Scroll to theme selection
            let themeOffset = themeContainer.frame.origin.y - 20
            scrollView.setContentOffset(CGPoint(x: 0, y: themeOffset), animated: true)
            
        case "Liquid Glass Effects":
            FeatureFlags.useLiquidGlassUI.toggle()
            showFeatureToggleAlert("Liquid Glass Effects", enabled: FeatureFlags.useLiquidGlassUI)
            
        case "Animations":
            FeatureFlags.enableLiquidAnimations.toggle()
            showFeatureToggleAlert("Liquid Animations", enabled: FeatureFlags.enableLiquidAnimations)
            
        case "Haptic Feedback":
            FeatureFlags.enableHapticFeedback.toggle()
            showFeatureToggleAlert("Haptic Feedback", enabled: FeatureFlags.enableHapticFeedback)
            
        default:
            break
        }
    }
    
    private func handleNotificationItemTap(_ item: LGSettingsItem) {
        // Handle notification settings
        showComingSoonAlert()
    }
    
    private func handleDataItemTap(_ item: LGSettingsItem) {
        switch item.title {
        case "Export Data":
            exportData()
        case "Import Data":
            importData()
        case "Clear Cache":
            clearCache()
        case "Reset App":
            showResetConfirmation()
        default:
            break
        }
    }
    
    private func handleAboutItemTap(_ item: LGSettingsItem) {
        switch item.title {
        case "What's New":
            presentWhatsNew()
        case "Privacy Policy":
            presentPrivacyPolicy()
        case "Contact Support":
            presentSupport()
        default:
            break
        }
    }
    
    private func presentProfile() {
        let profileVC = LGProfileViewController()
        let navController = UINavigationController(rootViewController: profileVC)
        present(navController, animated: true)
    }
    
    private func exportData() {
        let alert = UIAlertController(title: "Export Data", message: "Choose export format", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "JSON", style: .default) { _ in
            self.performExport(format: .json)
        })
        
        alert.addAction(UIAlertAction(title: "CSV", style: .default) { _ in
            self.performExport(format: .csv)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func importData() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.json, .commaSeparatedText])
        documentPicker.delegate = self
        present(documentPicker, animated: true)
    }
    
    private func clearCache() {
        let alert = UIAlertController(
            title: "Clear Cache",
            message: "This will free up storage space but may slow down the app temporarily.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            self.performClearCache()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showResetConfirmation() {
        let alert = UIAlertController(
            title: "Reset App",
            message: "This will delete all your data and reset all settings. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { _ in
            self.performReset()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showFeatureToggleAlert(_ feature: String, enabled: Bool) {
        let message = enabled ? "\(feature) enabled" : "\(feature) disabled"
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    
    private func showComingSoonAlert() {
        let alert = UIAlertController(
            title: "Coming Soon",
            message: "This feature will be available in a future update.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Data Operations
    
    private func performExport(format: ExportFormat) {
        // Implement data export
        showComingSoonAlert()
    }
    
    private func performClearCache() {
        // Clear image cache, temporary files, etc.
        URLCache.shared.removeAllCachedResponses()
        
        let alert = UIAlertController(title: "Cache Cleared", message: "Storage space has been freed up.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func performReset() {
        // Reset all user defaults
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        
        // Reset theme
        LGThemeManager.shared.currentTheme = .auto
        
        let alert = UIAlertController(title: "App Reset", message: "The app has been reset. Please restart the app.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func presentWhatsNew() {
        let whatsNewVC = LGWhatsNewViewController()
        present(whatsNewVC, animated: true)
    }
    
    private func presentPrivacyPolicy() {
        if let url = URL(string: "https://example.com/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func presentSupport() {
        let alert = UIAlertController(title: "Contact Support", message: "How would you like to contact us?", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Email", style: .default) { _ in
            if let url = URL(string: "mailto:support@example.com") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Twitter", style: .default) { _ in
            if let url = URL(string: "https://twitter.com/example") {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Theme & Animations
    
    private func applyTheme() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        // Update all sections
        [appearanceSection, notificationsSection, dataSection, aboutSection].forEach { section in
            section.applyTheme()
        }
    }
    
    private func animateEntrance() {
        navigationGlassView.morphGlass(to: .shimmerPulse, config: .subtle) {
            self.navigationGlassView.morphGlass(to: .idle, config: .subtle)
        }
        
        // Animate sections with stagger
        let sections = [appearanceSection, themeContainer, notificationsSection, dataSection, aboutSection]
        for (index, section) in sections.enumerated() {
            section.alpha = 0
            section.transform = CGAffineTransform(translationX: 0, y: 20)
            
            UIView.animate(withDuration: 0.4, delay: TimeInterval(index) * 0.1, options: .curveEaseOut) {
                section.alpha = 1
                section.transform = .identity
            }
        }
    }
}

// MARK: - Document Picker Delegate

extension LGSettingsViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        
        // Process imported file
        showComingSoonAlert()
    }
}

// MARK: - Enums

enum ExportFormat {
    case json, csv
}
