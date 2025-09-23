// LGComponentTestViewController.swift
// Component testing and preview system for Liquid Glass UI components
// Allows developers to test and preview all components in isolation

import UIKit
import SnapKit

// Import all Liquid Glass components
// Note: These imports may need to be adjusted based on your Xcode project structure

class LGComponentTestViewController: UIViewController {
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupComponents()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Component Testing"
        view.backgroundColor = .systemBackground
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissTapped)
        )
        
        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        
        // Standard Auto Layout constraints (temporary until SnapKit is installed)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        // Configure stack view
        stackView.axis = .vertical
        stackView.spacing = 30
        stackView.alignment = .fill
    }
    
    private func setupComponents() {
        // Add component sections
        addSectionHeader("Task Cards")
        addTaskCardComponents()
        
        addSectionHeader("Buttons")
        addButtonComponents()
        
        addSectionHeader("Text Fields")
        addTextFieldComponents()
        
        addSectionHeader("Search Bar")
        addSearchBarComponents()
        
        addSectionHeader("Progress Indicators")
        addProgressComponents()
        
        addSectionHeader("Project Pills")
        addProjectPillComponents()
        
        addSectionHeader("Floating Action Button")
        addFABComponents()
        
        addSectionHeader("Theme System")
        addThemeComponents()
        
        addSectionHeader("Device Adaptive")
        addAdaptiveComponents()
    }
    
    private func addSectionHeader(_ title: String) {
        let headerLabel = UILabel()
        headerLabel.text = title
        headerLabel.font = .systemFont(ofSize: LGLayoutConstants.titleFontSize, weight: .bold)
        headerLabel.textColor = .label
        stackView.addArrangedSubview(headerLabel)
    }
    
    private func addTaskCardComponents() {
        // Placeholder for task card - will be enabled once components are added to Xcode project
        let placeholderView = createPlaceholderView(title: "LGTaskCard", description: "Task display component with glass effects")
        stackView.addArrangedSubview(placeholderView)
    }
    
    private func addButtonComponents() {
        let placeholderView = createPlaceholderView(title: "LGButton", description: "Button variants with glass morphism effects")
        stackView.addArrangedSubview(placeholderView)
    }
    
    private func addTextFieldComponents() {
        let placeholderView = createPlaceholderView(title: "LGTextField", description: "Text input with floating placeholders and glass effects")
        stackView.addArrangedSubview(placeholderView)
    }
    
    private func addSearchBarComponents() {
        let placeholderView = createPlaceholderView(title: "LGSearchBar", description: "Search component with suggestions and glass morphism")
        stackView.addArrangedSubview(placeholderView)
    }
    
    private func addProgressComponents() {
        let placeholderView = createPlaceholderView(title: "LGProgressBar", description: "Linear and circular progress indicators with shimmer effects")
        stackView.addArrangedSubview(placeholderView)
    }
    
    private func addProjectPillComponents() {
        let placeholderView = createPlaceholderView(title: "LGProjectPill", description: "Project pills with liquid gradients and animations")
        stackView.addArrangedSubview(placeholderView)
    }
    
    private func addFABComponents() {
        let placeholderView = createPlaceholderView(title: "LGFloatingActionButton", description: "FAB with ripple effects and expandable actions")
        stackView.addArrangedSubview(placeholderView)
    }
    
    private func addThemeComponents() {
        // Create theme buttons using standard UIButton temporarily
        let themeContainer = UIView()
        let themeStackView = UIStackView()
        themeStackView.axis = .horizontal
        themeStackView.spacing = 10
        themeStackView.distribution = .fillEqually
        
        let themes: [(String, LGTheme)] = [
            ("Light", .light),
            ("Dark", .dark),
            ("Aurora", .aurora)
        ]
        
        for (name, theme) in themes {
            let button = UIButton(type: .system)
            button.setTitle(name, for: .normal)
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 8
            button.addTarget(self, action: #selector(themeButtonTapped(_:)), for: .touchUpInside)
            button.tag = theme.rawValue
            themeStackView.addArrangedSubview(button)
        }
        
        themeContainer.addSubview(themeStackView)
        themeStackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            themeStackView.topAnchor.constraint(equalTo: themeContainer.topAnchor),
            themeStackView.leadingAnchor.constraint(equalTo: themeContainer.leadingAnchor),
            themeStackView.trailingAnchor.constraint(equalTo: themeContainer.trailingAnchor),
            themeStackView.bottomAnchor.constraint(equalTo: themeContainer.bottomAnchor),
            themeStackView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        stackView.addArrangedSubview(themeContainer)
    }
    
    @objc private func themeButtonTapped(_ sender: UIButton) {
        if let theme = LGTheme(rawValue: sender.tag) {
            LGThemeManager.shared.currentTheme = theme
            print("Theme changed to: \(theme.displayName)")
        }
    }
    
    private func addAdaptiveComponents() {
        let deviceInfoView = LGAdaptiveView()
        let deviceLabel = UILabel()
        deviceLabel.text = """
        Device: \(LGDevice.isIPad ? "iPad" : "iPhone")
        Size Class: \(LGDevice.isRegular ? "Regular" : "Compact")
        Screen Size: \(LGDevice.screenSize)
        """
        deviceLabel.numberOfLines = 0
        deviceLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        deviceLabel.textColor = .label
        
        deviceInfoView.addSubview(deviceLabel)
        deviceLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            deviceLabel.topAnchor.constraint(equalTo: deviceInfoView.topAnchor, constant: 16),
            deviceLabel.leadingAnchor.constraint(equalTo: deviceInfoView.leadingAnchor, constant: 16),
            deviceLabel.trailingAnchor.constraint(equalTo: deviceInfoView.trailingAnchor, constant: -16),
            deviceLabel.bottomAnchor.constraint(equalTo: deviceInfoView.bottomAnchor, constant: -16)
        ])
        
        stackView.addArrangedSubview(deviceInfoView)
    }
    
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Placeholder Helper
    private func createPlaceholderView(title: String, description: String) -> UIView {
        let containerView = LGBaseView()
        containerView.glassIntensity = 0.3
        containerView.cornerRadius = LGDevice.isIPad ? 12 : 10
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .center
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.titleFontSize, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        
        containerView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        
        return containerView
    }
    
}
