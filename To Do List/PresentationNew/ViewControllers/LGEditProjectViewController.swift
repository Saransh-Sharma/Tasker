// LGEditProjectViewController.swift
// Edit project view controller - Phase 6 Implementation
// Clean Architecture compliant project editing with glass morphism

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import CoreData

class LGEditProjectViewController: UIViewController {
    
    // MARK: - Properties
    
    private let project: Projects
    private let context: NSManagedObjectContext
    private let disposeBag = DisposeBag()
    
    var onProjectUpdated: (() -> Void)?
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // Name Section
    private let nameSection = LGFormSection()
    private let nameTextField = LGTextField(style: .floating)
    
    // Description Section
    private let descriptionSection = LGFormSection()
    private let descriptionTextView = UITextView()
    
    // Color Section
    private let colorSection = LGFormSection()
    private let colorSelector = LGColorSelector()
    
    // Status Section
    private let statusSection = LGFormSection()
    private let statusSegmentedControl = UISegmentedControl(items: ["Active", "Completed", "Archived"])
    
    // Save Button
    private let saveButton = LGButton(style: .primary, size: .large)
    
    // MARK: - Initialization
    
    init(project: Projects, context: NSManagedObjectContext) {
        self.project = project
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupBindings()
        loadProjectData()
        applyTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        nameTextField.becomeFirstResponder()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        title = "Edit Project"
        
        // Navigation items
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Scroll view
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        
        // Stack view
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        
        // Name section
        nameSection.configure(title: "Project Name", icon: UIImage(systemName: "folder"))
        nameTextField.placeholder = "Enter project name"
        nameTextField.returnKeyType = .next
        nameSection.addContent(nameTextField)
        
        // Description section
        descriptionSection.configure(title: "Description", icon: UIImage(systemName: "text.alignleft"))
        descriptionTextView.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        descriptionTextView.textColor = LGThemeManager.shared.primaryTextColor
        descriptionTextView.backgroundColor = .clear
        descriptionTextView.layer.cornerRadius = 8
        descriptionTextView.layer.borderWidth = 1
        descriptionTextView.layer.borderColor = LGThemeManager.shared.separatorColor.cgColor
        descriptionTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        descriptionSection.addContent(descriptionTextView)
        
        // Color section
        colorSection.configure(title: "Project Color", icon: UIImage(systemName: "paintpalette"))
        colorSection.addContent(colorSelector)
        
        // Status section
        statusSection.configure(title: "Status", icon: UIImage(systemName: "flag"))
        statusSegmentedControl.selectedSegmentIndex = 0
        statusSection.addContent(statusSegmentedControl)
        
        // Save button
        saveButton.setTitle("Save Changes", for: .normal)
        saveButton.icon = UIImage(systemName: "checkmark")
        
        // Add to stack view
        stackView.addArrangedSubview(nameSection)
        stackView.addArrangedSubview(descriptionSection)
        stackView.addArrangedSubview(colorSection)
        stackView.addArrangedSubview(statusSection)
        stackView.addArrangedSubview(saveButton)
        
        contentView.addSubview(stackView)
        scrollView.addSubview(contentView)
        view.addSubview(scrollView)
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(20)
        }
        
        nameTextField.snp.makeConstraints { make in
            make.height.equalTo(50)
        }
        
        descriptionTextView.snp.makeConstraints { make in
            make.height.equalTo(120)
        }
        
        colorSelector.snp.makeConstraints { make in
            make.height.equalTo(60)
        }
        
        statusSegmentedControl.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
        
        saveButton.snp.makeConstraints { make in
            make.height.equalTo(56)
        }
    }
    
    private func setupBindings() {
        // Name validation
        nameTextField.rx.text
            .map { text in
                return !(text?.isEmpty ?? true)
            }
            .bind(to: saveButton.rx.isEnabled)
            .disposed(by: disposeBag)
        
        // Save button
        saveButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.saveChanges()
            })
            .disposed(by: disposeBag)
        
        // Keyboard handling
        NotificationCenter.default.rx
            .notification(UIResponder.keyboardWillShowNotification)
            .subscribe(onNext: { [weak self] notification in
                self?.handleKeyboardShow(notification)
            })
            .disposed(by: disposeBag)
        
        NotificationCenter.default.rx
            .notification(UIResponder.keyboardWillHideNotification)
            .subscribe(onNext: { [weak self] _ in
                self?.handleKeyboardHide()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Data
    
    private func loadProjectData() {
        nameTextField.text = project.name
        descriptionTextView.text = project.projectDescription
        
        if let colorData = project.color,
           let color = UIColor.from(data: colorData) {
            colorSelector.selectedColor = color
        }
        
        if project.isCompleted {
            statusSegmentedControl.selectedSegmentIndex = 1
        } else if project.isArchived {
            statusSegmentedControl.selectedSegmentIndex = 2
        } else {
            statusSegmentedControl.selectedSegmentIndex = 0
        }
    }
    
    private func saveChanges() {
        // Validate
        guard let name = nameTextField.text, !name.isEmpty else {
            showError("Please enter a project name")
            return
        }
        
        // Update project
        project.name = name
        project.projectDescription = descriptionTextView.text
        project.color = colorSelector.selectedColor.toData()
        
        // Update status
        switch statusSegmentedControl.selectedSegmentIndex {
        case 0: // Active
            project.isCompleted = false
            project.isArchived = false
        case 1: // Completed
            project.isCompleted = true
            project.isArchived = false
            project.dateCompleted = Date()
        case 2: // Archived
            project.isCompleted = false
            project.isArchived = true
            project.dateArchived = Date()
        default:
            break
        }
        
        // Save
        do {
            try context.save()
            onProjectUpdated?()
            dismiss(animated: true)
        } catch {
            showError("Failed to save changes: \(error.localizedDescription)")
        }
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        
        // Shake animation for error feedback
        LGAnimationRefinement.shared.shakeAnimation(for: saveButton)
    }
    
    // MARK: - Keyboard Handling
    
    private func handleKeyboardShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    private func handleKeyboardHide() {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    // MARK: - Theme
    
    private func applyTheme() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        descriptionTextView.textColor = LGThemeManager.shared.primaryTextColor
        descriptionTextView.layer.borderColor = LGThemeManager.shared.separatorColor.cgColor
    }
}

// MARK: - Color Selector Component

class LGColorSelector: LGBaseView {
    
    // MARK: - Properties
    
    var selectedColor: UIColor = .systemBlue {
        didSet {
            updateSelection()
        }
    }
    
    private let colors: [UIColor] = [
        .systemRed,
        .systemOrange,
        .systemYellow,
        .systemGreen,
        .systemBlue,
        .systemIndigo,
        .systemPurple,
        .systemPink
    ]
    
    private var colorButtons: [UIButton] = []
    private let stackView = UIStackView()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSelector()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupSelector()
    }
    
    // MARK: - Setup
    
    private func setupSelector() {
        glassIntensity = 0.3
        cornerRadius = 12
        
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 12
        
        for color in colors {
            let button = UIButton()
            button.backgroundColor = color
            button.layer.cornerRadius = 20
            button.layer.borderWidth = 3
            button.layer.borderColor = UIColor.clear.cgColor
            
            button.addTarget(self, action: #selector(colorTapped(_:)), for: .touchUpInside)
            
            colorButtons.append(button)
            stackView.addArrangedSubview(button)
            
            button.snp.makeConstraints { make in
                make.size.equalTo(40)
            }
        }
        
        addSubview(stackView)
        
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(40)
        }
        
        // Set initial selection
        updateSelection()
    }
    
    @objc private func colorTapped(_ sender: UIButton) {
        guard let index = colorButtons.firstIndex(of: sender) else { return }
        selectedColor = colors[index]
        
        // Haptic feedback
        if FeatureFlags.enableHapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        // Animate selection
        LGAnimationRefinement.shared.bounceAnimation(for: sender)
    }
    
    private func updateSelection() {
        for (index, button) in colorButtons.enumerated() {
            if colors[index] == selectedColor {
                button.layer.borderColor = LGThemeManager.shared.primaryTextColor.cgColor
                button.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            } else {
                button.layer.borderColor = UIColor.clear.cgColor
                button.transform = .identity
            }
        }
    }
}
