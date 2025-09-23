// LGAddTaskViewController.swift
// Add/Edit Task Screen with Liquid Glass UI - Phase 4 Implementation
// Advanced form with glass morphism effects and reactive validation

import UIKit
import SnapKit
import RxSwift
import RxCocoa

class LGAddTaskViewController: UIViewController {
    
    // MARK: - Dependencies
    private var viewModel: LGAddTaskViewModel!
    private let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    
    // Navigation and Header
    private let navigationGlassView = LGBaseView()
    private let titleLabel = UILabel()
    private let progressView = LGProgressBar()
    private let closeButton = LGButton(style: .ghost, size: .medium)
    private let saveButton = LGButton(style: .primary, size: .medium)
    
    // Form Container
    private let formScrollView = UIScrollView()
    private let formStackView = UIStackView()
    private let formContainer = LGBaseView()
    
    // Form Fields
    private let taskNameSection = LGFormSection()
    private let taskNameField = LGTextField(style: .outlined)
    private let taskNameValidationLabel = UILabel()
    
    private let descriptionSection = LGFormSection()
    private let descriptionField = LGTextField(style: .outlined)
    
    private let prioritySection = LGFormSection()
    private let prioritySelectionView = LGPrioritySelector()
    
    private let projectSection = LGFormSection()
    private let projectSelectionView = LGProjectSelector()
    
    private let dueDateSection = LGFormSection()
    private let dueDatePicker = UIDatePicker()
    private let dueDateDisplayView = LGDateDisplayView()
    
    private let reminderSection = LGFormSection()
    private let reminderToggle = UISwitch()
    private let reminderDatePicker = UIDatePicker()
    private let reminderContainer = LGBaseView()
    
    // Action Buttons
    private let actionButtonsContainer = LGBaseView()
    private let deleteButton = LGButton(style: .destructive, size: .large)
    
    // Loading and Error States
    private let loadingOverlay = LGLoadingOverlay()
    
    // MARK: - Properties
    private var keyboardHeight: CGFloat = 0
    private var isKeyboardVisible = false
    
    // MARK: - Initialization
    
    init(editingTask: NTask? = nil) {
        super.init(nibName: nil, bundle: nil)
        setupViewModel(editingTask: editingTask)
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
        setupKeyboardHandling()
        applyTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateEntrance()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }
    
    // MARK: - Setup
    
    private func setupViewModel(editingTask: NTask?) {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        viewModel = LGAddTaskViewModel(context: context, editingTask: editingTask)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        setupNavigationView()
        setupFormContainer()
        setupFormFields()
        setupActionButtons()
        setupLoadingOverlay()
    }
    
    private func setupNavigationView() {
        navigationGlassView.glassIntensity = 0.9
        navigationGlassView.cornerRadius = 0
        navigationGlassView.enableGlassBorder = false
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.largeTitleFontSize, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.text = "Add Task"
        
        progressView.style = .info
        progressView.cornerRadius = 4
        progressView.shimmerEnabled = true
        
        closeButton.setTitle("Cancel", for: .normal)
        closeButton.icon = UIImage(systemName: "xmark")
        
        saveButton.setTitle("Save", for: .normal)
        saveButton.icon = UIImage(systemName: "checkmark")
        
        navigationGlassView.addSubview(titleLabel)
        navigationGlassView.addSubview(progressView)
        navigationGlassView.addSubview(closeButton)
        navigationGlassView.addSubview(saveButton)
        
        view.addSubview(navigationGlassView)
    }
    
    private func setupFormContainer() {
        formContainer.glassIntensity = 0.3
        formContainer.cornerRadius = LGDevice.isIPad ? 16 : 12
        formContainer.enableGlassBorder = true
        
        formScrollView.backgroundColor = .clear
        formScrollView.showsVerticalScrollIndicator = false
        formScrollView.keyboardDismissMode = .interactive
        
        formStackView.axis = .vertical
        formStackView.spacing = 24
        formStackView.alignment = .fill
        formStackView.distribution = .equalSpacing
        
        formScrollView.addSubview(formStackView)
        formContainer.addSubview(formScrollView)
        view.addSubview(formContainer)
    }
    
    private func setupFormFields() {
        // Task Name Section
        taskNameSection.configure(title: "Task Name", isRequired: true)
        taskNameField.placeholder = "Enter task name"
        taskNameField.leadingIcon = UIImage(systemName: "text.cursor")
        taskNameField.characterLimit = 100
        
        taskNameValidationLabel.font = .systemFont(ofSize: 12, weight: .medium)
        taskNameValidationLabel.textColor = .systemRed
        taskNameValidationLabel.isHidden = true
        
        taskNameSection.addArrangedSubview(taskNameField)
        taskNameSection.addArrangedSubview(taskNameValidationLabel)
        
        // Description Section
        descriptionSection.configure(title: "Description", isRequired: false)
        descriptionField.placeholder = "Add description (optional)"
        descriptionField.leadingIcon = UIImage(systemName: "text.alignleft")
        descriptionField.isMultiline = true
        descriptionField.characterLimit = 500
        
        descriptionSection.addArrangedSubview(descriptionField)
        
        // Priority Section
        prioritySection.configure(title: "Priority", isRequired: true)
        prioritySelectionView.selectedPriority = .medium
        
        prioritySection.addArrangedSubview(prioritySelectionView)
        
        // Project Section
        projectSection.configure(title: "Project", isRequired: false)
        projectSelectionView.placeholder = "Select project (optional)"
        
        projectSection.addArrangedSubview(projectSelectionView)
        
        // Due Date Section
        dueDateSection.configure(title: "Due Date", isRequired: true)
        dueDatePicker.datePickerMode = .dateAndTime
        dueDatePicker.preferredDatePickerStyle = .wheels
        dueDatePicker.minimumDate = Date()
        
        dueDateDisplayView.configure(date: Date())
        
        dueDateSection.addArrangedSubview(dueDateDisplayView)
        dueDateSection.addArrangedSubview(dueDatePicker)
        
        // Reminder Section
        reminderSection.configure(title: "Reminder", isRequired: false)
        reminderToggle.onTintColor = LGThemeManager.shared.primaryGlassColor
        
        reminderContainer.glassIntensity = 0.2
        reminderContainer.cornerRadius = 8
        reminderContainer.isHidden = true
        
        reminderDatePicker.datePickerMode = .dateAndTime
        reminderDatePicker.preferredDatePickerStyle = .compact
        
        let reminderToggleContainer = UIStackView()
        reminderToggleContainer.axis = .horizontal
        reminderToggleContainer.alignment = .center
        reminderToggleContainer.spacing = 12
        
        let reminderLabel = UILabel()
        reminderLabel.text = "Enable reminder"
        reminderLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        reminderLabel.textColor = .label
        
        reminderToggleContainer.addArrangedSubview(reminderLabel)
        reminderToggleContainer.addArrangedSubview(UIView()) // Spacer
        reminderToggleContainer.addArrangedSubview(reminderToggle)
        
        reminderContainer.addSubview(reminderDatePicker)
        
        reminderSection.addArrangedSubview(reminderToggleContainer)
        reminderSection.addArrangedSubview(reminderContainer)
        
        // Add all sections to form
        formStackView.addArrangedSubview(taskNameSection)
        formStackView.addArrangedSubview(descriptionSection)
        formStackView.addArrangedSubview(prioritySection)
        formStackView.addArrangedSubview(projectSection)
        formStackView.addArrangedSubview(dueDateSection)
        formStackView.addArrangedSubview(reminderSection)
    }
    
    private func setupActionButtons() {
        actionButtonsContainer.glassIntensity = 0.4
        actionButtonsContainer.cornerRadius = LGDevice.isIPad ? 16 : 12
        actionButtonsContainer.enableGlassBorder = true
        
        deleteButton.setTitle("Delete Task", for: .normal)
        deleteButton.icon = UIImage(systemName: "trash")
        deleteButton.isHidden = true // Show only in edit mode
        
        actionButtonsContainer.addSubview(deleteButton)
        view.addSubview(actionButtonsContainer)
    }
    
    private func setupLoadingOverlay() {
        loadingOverlay.message = "Saving task..."
        loadingOverlay.isHidden = true
        view.addSubview(loadingOverlay)
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        // Navigation view
        navigationGlassView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(100)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-50)
        }
        
        progressView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(6)
        }
        
        closeButton.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.bottom.equalTo(titleLabel.snp.top).offset(-8)
            make.width.equalTo(80)
        }
        
        saveButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(closeButton)
            make.width.equalTo(80)
        }
        
        // Form container
        formContainer.snp.makeConstraints { make in
            make.top.equalTo(navigationGlassView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(actionButtonsContainer.snp.top).offset(-16)
        }
        
        formScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        formStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(20)
            make.width.equalTo(formScrollView).offset(-40)
        }
        
        // Reminder date picker
        reminderDatePicker.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
            make.height.equalTo(44)
        }
        
        // Action buttons
        actionButtonsContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-16)
            make.height.equalTo(60)
        }
        
        deleteButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(44)
        }
        
        // Loading overlay
        loadingOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Bindings
    
    private func setupBindings() {
        // Input bindings
        taskNameField.rx.text.orEmpty
            .bind(to: viewModel.taskName)
            .disposed(by: disposeBag)
        
        descriptionField.rx.text.orEmpty
            .bind(to: viewModel.taskDescription)
            .disposed(by: disposeBag)
        
        dueDatePicker.rx.date
            .bind(to: viewModel.selectedDueDate)
            .disposed(by: disposeBag)
        
        reminderToggle.rx.isOn
            .bind(to: viewModel.isReminderEnabled)
            .disposed(by: disposeBag)
        
        reminderDatePicker.rx.date
            .bind(to: viewModel.reminderDate)
            .disposed(by: disposeBag)
        
        // Priority selection
        prioritySelectionView.onPrioritySelected = { [weak self] priority in
            self?.viewModel.updatePriority(priority)
        }
        
        // Project selection
        projectSelectionView.onProjectSelected = { [weak self] project in
            self?.viewModel.updateProject(project)
        }
        
        // Output bindings
        viewModel.isEditMode
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isEdit in
                self?.updateUIForEditMode(isEdit)
            })
            .disposed(by: disposeBag)
        
        viewModel.formProgress
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] progress in
                self?.progressView.setProgressWithMorphing(progress, morphState: .liquidWave, animated: true)
            })
            .disposed(by: disposeBag)
        
        viewModel.taskNameValidation
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] validation in
                self?.updateTaskNameValidation(validation)
            })
            .disposed(by: disposeBag)
        
        viewModel.isLoading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isLoading in
                self?.updateLoadingState(isLoading)
            })
            .disposed(by: disposeBag)
        
        viewModel.canSave
            .observe(on: MainScheduler.instance)
            .bind(to: saveButton.rx.isEnabled)
            .disposed(by: disposeBag)
        
        viewModel.canDelete
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] canDelete in
                self?.deleteButton.isHidden = !canDelete
            })
            .disposed(by: disposeBag)
        
        viewModel.isReminderEnabled
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] enabled in
                self?.updateReminderUI(enabled)
            })
            .disposed(by: disposeBag)
        
        viewModel.availableProjects
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] projects in
                self?.projectSelectionView.updateProjects(projects)
            })
            .disposed(by: disposeBag)
        
        viewModel.error
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] error in
                self?.showError(error)
            })
            .disposed(by: disposeBag)
        
        viewModel.saveSuccess
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] task in
                self?.handleSaveSuccess(task)
            })
            .disposed(by: disposeBag)
        
        // Button actions
        closeButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.handleClose()
            })
            .disposed(by: disposeBag)
        
        saveButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.handleSave()
            })
            .disposed(by: disposeBag)
        
        deleteButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.handleDelete()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - UI Updates
    
    private func updateUIForEditMode(_ isEdit: Bool) {
        titleLabel.text = isEdit ? "Edit Task" : "Add Task"
        saveButton.setTitle(isEdit ? "Update" : "Save", for: .normal)
        
        if isEdit {
            dueDatePicker.minimumDate = nil // Allow past dates for editing
        }
    }
    
    private func updateTaskNameValidation(_ validation: LGAddTaskViewModel.ValidationResult) {
        switch validation {
        case .idle:
            taskNameValidationLabel.isHidden = true
            taskNameField.errorState = false
        case .valid:
            taskNameValidationLabel.isHidden = true
            taskNameField.errorState = false
        case .invalid(let message):
            taskNameValidationLabel.text = message
            taskNameValidationLabel.isHidden = false
            taskNameField.errorState = true
        }
    }
    
    private func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            loadingOverlay.show()
        } else {
            loadingOverlay.hide()
        }
        
        // Disable form interaction during loading
        formScrollView.isUserInteractionEnabled = !isLoading
        closeButton.isEnabled = !isLoading
    }
    
    private func updateReminderUI(_ enabled: Bool) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.reminderContainer.isHidden = !enabled
            self.reminderContainer.alpha = enabled ? 1.0 : 0.0
        }
        
        if enabled {
            reminderContainer.morphGlass(to: .expanding, config: .subtle) {
                self.reminderContainer.morphGlass(to: .idle, config: .subtle)
            }
        }
    }
    
    // MARK: - Actions
    
    private func handleClose() {
        // Check if form has unsaved changes
        if viewModel.formProgress.value > 0.1 {
            showUnsavedChangesAlert()
        } else {
            dismiss(animated: true)
        }
    }
    
    private func handleSave() {
        view.endEditing(true)
        
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate save button
        saveButton.morphButton(to: .pressed) {
            self.saveButton.morphButton(to: .idle)
        }
        
        viewModel.saveTask()
    }
    
    private func handleDelete() {
        showDeleteConfirmationAlert()
    }
    
    private func handleSaveSuccess(_ task: NTask) {
        // Add success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        // Show success animation
        progressView.celebrateCompletion()
        
        // Dismiss after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dismiss(animated: true)
        }
    }
    
    // MARK: - Alerts
    
    private func showUnsavedChangesAlert() {
        let alert = UIAlertController(
            title: "Unsaved Changes",
            message: "You have unsaved changes. Are you sure you want to close?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { _ in
            self.dismiss(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showDeleteConfirmationAlert() {
        let alert = UIAlertController(
            title: "Delete Task",
            message: "Are you sure you want to delete this task? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.viewModel.deleteTask()
        })
        
        present(alert, animated: true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        keyboardHeight = keyboardFrame.height
        isKeyboardVisible = true
        
        UIView.animate(withDuration: 0.3) {
            self.formScrollView.contentInset.bottom = self.keyboardHeight
            self.formScrollView.scrollIndicatorInsets.bottom = self.keyboardHeight
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        isKeyboardVisible = false
        
        UIView.animate(withDuration: 0.3) {
            self.formScrollView.contentInset.bottom = 0
            self.formScrollView.scrollIndicatorInsets.bottom = 0
        }
    }
    
    // MARK: - Theme
    
    private func applyTheme() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        // Update glass intensities based on theme
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        navigationGlassView.glassIntensity = isDarkMode ? 0.7 : 0.9
        formContainer.glassIntensity = isDarkMode ? 0.2 : 0.3
        actionButtonsContainer.glassIntensity = isDarkMode ? 0.3 : 0.4
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        // Animate navigation view
        navigationGlassView.morphGlass(to: .shimmerPulse, config: .subtle) {
            self.navigationGlassView.morphGlass(to: .idle, config: .subtle)
        }
        
        // Animate form container
        formContainer.alpha = 0
        formContainer.transform = CGAffineTransform(translationX: 0, y: 20)
        
        UIView.animate(withDuration: 0.5, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            self.formContainer.alpha = 1
            self.formContainer.transform = .identity
        }
        
        // Animate form sections with staggered timing
        formStackView.arrangedSubviews.enumerated().forEach { index, view in
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: -20, y: 0)
            
            UIView.animate(withDuration: 0.4, delay: TimeInterval(index) * 0.1, options: .curveEaseOut) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyTheme()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
