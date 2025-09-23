// LGFormSection.swift
// Form section component with glass morphism effects - Phase 4 Implementation
// Provides consistent form layout with title, content, and validation states

import UIKit
import SnapKit

class LGFormSection: UIStackView {
    
    // MARK: - UI Components
    private let titleLabel = UILabel()
    private let requiredIndicator = UILabel()
    private let contentContainer = UIStackView()
    
    // MARK: - Properties
    private var sectionTitle: String = ""
    private var isRequired: Bool = false
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        axis = .vertical
        spacing = 8
        alignment = .fill
        distribution = .fill
        
        setupTitleContainer()
        setupContentContainer()
        
        addArrangedSubview(createTitleContainer())
        addArrangedSubview(contentContainer)
    }
    
    private func setupTitleContainer() {
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.subheadlineFontSize, weight: .semibold)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        titleLabel.numberOfLines = 1
        
        requiredIndicator.text = "*"
        requiredIndicator.font = .systemFont(ofSize: LGLayoutConstants.subheadlineFontSize, weight: .bold)
        requiredIndicator.textColor = .systemRed
        requiredIndicator.isHidden = true
    }
    
    private func setupContentContainer() {
        contentContainer.axis = .vertical
        contentContainer.spacing = 6
        contentContainer.alignment = .fill
        contentContainer.distribution = .fill
    }
    
    private func createTitleContainer() -> UIView {
        let container = UIView()
        
        container.addSubview(titleLabel)
        container.addSubview(requiredIndicator)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        
        requiredIndicator.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(4)
            make.trailing.lessThanOrEqualToSuperview()
            make.centerY.equalTo(titleLabel)
        }
        
        container.snp.makeConstraints { make in
            make.height.equalTo(24)
        }
        
        return container
    }
    
    // MARK: - Public Methods
    
    func configure(title: String, isRequired: Bool = false) {
        self.sectionTitle = title
        self.isRequired = isRequired
        
        titleLabel.text = title
        requiredIndicator.isHidden = !isRequired
        
        updateTheme()
    }
    
    func addContent(_ view: UIView) {
        contentContainer.addArrangedSubview(view)
    }
    
    func removeContent(_ view: UIView) {
        contentContainer.removeArrangedSubview(view)
        view.removeFromSuperview()
    }
    
    func clearContent() {
        contentContainer.arrangedSubviews.forEach { view in
            contentContainer.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
    
    // MARK: - Theme
    
    private func updateTheme() {
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        requiredIndicator.textColor = LGThemeManager.shared.errorColor
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateTheme()
        }
    }
}

// MARK: - Convenience Methods

extension LGFormSection {
    
    func addArrangedSubview(_ view: UIView) {
        contentContainer.addArrangedSubview(view)
    }
    
    func insertArrangedSubview(_ view: UIView, at stackIndex: Int) {
        contentContainer.insertArrangedSubview(view, at: stackIndex)
    }
    
    func removeArrangedSubview(_ view: UIView) {
        contentContainer.removeArrangedSubview(view)
    }
}

// MARK: - LGPrioritySelector

class LGPrioritySelector: UIView {
    
    // MARK: - UI Components
    private let stackView = UIStackView()
    private var priorityButtons: [LGButton] = []
    
    // MARK: - Properties
    var selectedPriority: TaskPriority = .medium {
        didSet {
            updateSelection()
        }
    }
    
    var onPrioritySelected: ((TaskPriority) -> Void)?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        
        createPriorityButtons()
        
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(44)
        }
        
        updateSelection()
    }
    
    private func createPriorityButtons() {
        TaskPriority.allCases.forEach { priority in
            let button = LGButton(style: .ghost, size: .medium)
            button.setTitle(priority.displayName, for: .normal)
            button.icon = UIImage(systemName: priority.iconName)
            button.tag = priority.rawValue
            
            button.addTarget(self, action: #selector(priorityButtonTapped(_:)), for: .touchUpInside)
            
            priorityButtons.append(button)
            stackView.addArrangedSubview(button)
        }
    }
    
    @objc private func priorityButtonTapped(_ sender: LGButton) {
        guard let priority = TaskPriority(rawValue: sender.tag) else { return }
        
        selectedPriority = priority
        onPrioritySelected?(priority)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Animate button
        sender.morphButton(to: .pressed) {
            sender.morphButton(to: .idle)
        }
    }
    
    private func updateSelection() {
        priorityButtons.forEach { button in
            let priority = TaskPriority(rawValue: button.tag) ?? .medium
            let isSelected = priority == selectedPriority
            
            button.style = isSelected ? .primary : .ghost
            button.backgroundColor = isSelected ? priority.color : .clear
            
            if isSelected {
                button.morphButton(to: .pressed, completion: {
                    button.morphButton(to: .idle)
                })
            }
        }
    }
}

// MARK: - LGProjectSelector

class LGProjectSelector: UIView {
    
    // MARK: - UI Components
    private let selectionButton = LGButton(style: .secondary, size: .large)
    private let projectPill = LGProjectPill()
    
    // MARK: - Properties
    private var availableProjects: [Projects] = []
    private var selectedProject: Projects?
    
    var placeholder: String = "Select project" {
        didSet {
            updateDisplay()
        }
    }
    
    var onProjectSelected: ((Projects?) -> Void)?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        selectionButton.setTitle(placeholder, for: .normal)
        selectionButton.icon = UIImage(systemName: "folder")
        selectionButton.addTarget(self, action: #selector(showProjectSelection), for: .touchUpInside)
        
        projectPill.isHidden = true
        
        addSubview(selectionButton)
        addSubview(projectPill)
        
        selectionButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(44)
        }
        
        projectPill.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(44)
        }
    }
    
    @objc private func showProjectSelection() {
        let actionSheet = UIAlertController(title: "Select Project", message: nil, preferredStyle: .actionSheet)
        
        // Add "No Project" option
        actionSheet.addAction(UIAlertAction(title: "No Project", style: .default) { _ in
            self.selectedProject = nil
            self.onProjectSelected?(nil)
            self.updateDisplay()
        })
        
        // Add available projects
        availableProjects.forEach { project in
            let action = UIAlertAction(title: project.projectName ?? "Untitled", style: .default) { _ in
                self.selectedProject = project
                self.onProjectSelected?(project)
                self.updateDisplay()
            }
            actionSheet.addAction(action)
        }
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Present from the nearest view controller
        if let viewController = findViewController() {
            if let popover = actionSheet.popoverPresentationController {
                popover.sourceView = self
                popover.sourceRect = bounds
            }
            viewController.present(actionSheet, animated: true)
        }
    }
    
    func updateProjects(_ projects: [Projects]) {
        availableProjects = projects
    }
    
    private func updateDisplay() {
        if let project = selectedProject {
            selectionButton.isHidden = true
            projectPill.isHidden = false
            
            let projectData = ProjectData(
                id: project.objectID.uriRepresentation().absoluteString,
                name: project.projectName ?? "Untitled",
                color: UIColor(named: project.projectColor ?? "systemBlue") ?? .systemBlue,
                iconName: project.projectIcon ?? "folder.fill",
                taskCount: 0,
                completedCount: 0
            )
            
            projectPill.configure(with: projectData)
        } else {
            selectionButton.isHidden = false
            projectPill.isHidden = true
            selectionButton.setTitle(placeholder, for: .normal)
        }
    }
}

// MARK: - LGDateDisplayView

class LGDateDisplayView: LGBaseView {
    
    // MARK: - UI Components
    private let dateLabel = UILabel()
    private let timeLabel = UILabel()
    private let iconImageView = UIImageView()
    
    // MARK: - Properties
    private var currentDate: Date = Date()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        glassIntensity = 0.2
        cornerRadius = 8
        enableGlassBorder = true
        
        iconImageView.image = UIImage(systemName: "calendar")
        iconImageView.tintColor = LGThemeManager.shared.primaryGlassColor
        iconImageView.contentMode = .scaleAspectFit
        
        dateLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .semibold)
        dateLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        timeLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        timeLabel.textColor = LGThemeManager.shared.secondaryTextColor
        
        addSubview(iconImageView)
        addSubview(dateLabel)
        addSubview(timeLabel)
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
        }
        
        dateLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-12)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(dateLabel)
            make.top.equalTo(dateLabel.snp.bottom).offset(2)
            make.bottom.equalToSuperview().offset(-8)
        }
        
        snp.makeConstraints { make in
            make.height.equalTo(60)
        }
    }
    
    // MARK: - Public Methods
    
    func configure(date: Date) {
        currentDate = date
        updateDisplay()
    }
    
    private func updateDisplay() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateLabel.text = dateFormatter.string(from: currentDate)
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeLabel.text = timeFormatter.string(from: currentDate)
    }
}

// MARK: - LGLoadingOverlay

class LGLoadingOverlay: LGBaseView {
    
    // MARK: - UI Components
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()
    
    // MARK: - Properties
    var message: String = "Loading..." {
        didSet {
            messageLabel.text = message
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        glassIntensity = 0.8
        cornerRadius = 0
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        activityIndicator.color = LGThemeManager.shared.primaryGlassColor
        activityIndicator.hidesWhenStopped = true
        
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        messageLabel.textColor = LGThemeManager.shared.primaryTextColor
        messageLabel.textAlignment = .center
        
        addSubview(activityIndicator)
        addSubview(messageLabel)
        
        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(activityIndicator.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(40)
        }
    }
    
    // MARK: - Public Methods
    
    func show() {
        isHidden = false
        activityIndicator.startAnimating()
        
        alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
        
        morphGlass(to: .shimmerPulse, config: .subtle)
    }
    
    func hide() {
        UIView.animate(withDuration: 0.3) {
            self.alpha = 0
        } completion: { _ in
            self.isHidden = true
            self.activityIndicator.stopAnimating()
        }
        
        morphGlass(to: .idle, config: .subtle)
    }
}

// MARK: - UIView Extension

extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}
