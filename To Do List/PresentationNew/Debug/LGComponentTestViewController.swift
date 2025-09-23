// Component Test View Controller
// Allows testing and previewing Liquid Glass UI components

import UIKit

class LGComponentTestViewController: UIViewController {
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // Test components
    private var testViews: [LGBaseView] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        createTestComponents()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "🧪 Component Tests"
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
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.distribution = .fill
        
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
    }
    
    @objc private func dismissTapped() {
        dismiss(animated: true)
    }
    
    private func createTestComponents() {
        // Test 1: Basic Glass View
        let basicGlassView = createTestSection(title: "Basic Glass View") {
            let glassView = LGBaseView()
            glassView.backgroundColor = .clear
            glassView.heightAnchor.constraint(equalToConstant: 100).isActive = true
            
            let label = UILabel()
            label.text = "Basic Glass Effect"
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 16, weight: .medium)
            label.textColor = .label
            
            glassView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: glassView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: glassView.centerYAnchor)
            ])
            
            return glassView
        }
        
        // Test 2: Glass View with Shimmer
        let shimmerGlassView = createTestSection(title: "Glass View with Shimmer") {
            let glassView = LGBaseView()
            glassView.backgroundColor = .clear
            glassView.heightAnchor.constraint(equalToConstant: 100).isActive = true
            glassView.addShimmerEffect()
            
            let label = UILabel()
            label.text = "Shimmer Effect"
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 16, weight: .medium)
            label.textColor = .label
            
            glassView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: glassView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: glassView.centerYAnchor)
            ])
            
            return glassView
        }
        
        // Test 3: Different Corner Radius
        let roundedGlassView = createTestSection(title: "Rounded Glass View") {
            let glassView = LGBaseView()
            glassView.backgroundColor = .clear
            glassView.cornerRadius = 30
            glassView.heightAnchor.constraint(equalToConstant: 100).isActive = true
            
            let label = UILabel()
            label.text = "Rounded Corners"
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 16, weight: .medium)
            label.textColor = .label
            
            glassView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: glassView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: glassView.centerYAnchor)
            ])
            
            return glassView
        }
        
        // Test 4: Interactive Glass View
        let interactiveGlassView = createTestSection(title: "Interactive Glass View") {
            let glassView = LGBaseView()
            glassView.backgroundColor = .clear
            glassView.heightAnchor.constraint(equalToConstant: 100).isActive = true
            
            let label = UILabel()
            label.text = "Tap for Ripple Effect"
            label.textAlignment = .center
            label.font = .systemFont(ofSize: 16, weight: .medium)
            label.textColor = .label
            
            glassView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: glassView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: glassView.centerYAnchor)
            ])
            
            // Add tap gesture
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            glassView.addGestureRecognizer(tapGesture)
            glassView.tag = 100 // Identify this view
            
            return glassView
        }
        
        // Test 5: Migration Banner
        let bannerSection = createTestSection(title: "Migration Banner") {
            let containerView = UIView()
            containerView.heightAnchor.constraint(equalToConstant: 150).isActive = true
            
            let banner = LGMigrationBanner()
            banner.show(in: containerView, autoHide: false)
            
            return containerView
        }
        
        // Test 6: Theme Colors
        let themeSection = createTestSection(title: "Theme Colors") {
            let containerView = UIView()
            containerView.heightAnchor.constraint(equalToConstant: 60).isActive = true
            
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = 8
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // Create color swatches
            let primarySwatch = createColorSwatch(color: LGThemeManager.shared.primaryGlassColor, title: "Primary")
            let secondarySwatch = createColorSwatch(color: LGThemeManager.shared.secondaryGlassColor, title: "Secondary")
            let accentSwatch = createColorSwatch(color: LGThemeManager.shared.accentColor, title: "Accent")
            
            stackView.addArrangedSubview(primarySwatch)
            stackView.addArrangedSubview(secondarySwatch)
            stackView.addArrangedSubview(accentSwatch)
            
            containerView.addSubview(stackView)
            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: containerView.topAnchor),
                stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            return containerView
        }
        
        // Add all test sections
        [basicGlassView, shimmerGlassView, roundedGlassView, interactiveGlassView, bannerSection, themeSection].forEach {
            stackView.addArrangedSubview($0)
        }
    }
    
    private func createTestSection(title: String, contentBuilder: () -> UIView) -> UIView {
        let sectionView = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        
        let contentView = contentBuilder()
        
        sectionView.addSubview(titleLabel)
        sectionView.addSubview(contentView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: sectionView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
            
            contentView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            contentView.leadingAnchor.constraint(equalTo: sectionView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: sectionView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: sectionView.bottomAnchor)
        ])
        
        return sectionView
    }
    
    private func createColorSwatch(color: UIColor, title: String) -> UIView {
        let containerView = UIView()
        
        let colorView = UIView()
        colorView.backgroundColor = color
        colorView.layer.cornerRadius = 8
        colorView.layer.borderWidth = 1
        colorView.layer.borderColor = UIColor.systemGray4.cgColor
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        
        containerView.addSubview(colorView)
        containerView.addSubview(titleLabel)
        
        colorView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            colorView.topAnchor.constraint(equalTo: containerView.topAnchor),
            colorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            colorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            colorView.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.topAnchor.constraint(equalTo: colorView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let glassView = gesture.view as? LGBaseView else { return }
        
        let location = gesture.location(in: glassView)
        glassView.animateGlassRipple(at: location)
        glassView.animateLiquidTransition()
    }
}
