// LGTaskDetailViewController.swift
// Task Detail View with Liquid Glass UI - Phase 4 Implementation
// Interactive detail view with glass morphism effects and gesture support

import UIKit
import SnapKit
import RxSwift
import RxCocoa

class LGTaskDetailViewController: UIViewController {
    
    // MARK: - Dependencies
    private var viewModel: LGTaskDetailViewModel!
    private let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    
    // Navigation and Header
    private let navigationGlassView = LGBaseView()
    private let titleLabel = UILabel()
    private let editButton = LGButton(style: .ghost, size: .medium)
    private let closeButton = LGButton(style: .ghost, size: .medium)
    
    // Content Container
    private let contentScrollView = UIScrollView()
    private let contentStackView = UIStackView()
    private let contentContainer = LGBaseView()
    
    // Task Information Sections
    private let taskHeaderCard = LGTaskHeaderCard()
    private let taskDetailsCard = LGTaskDetailsCard()
    private let taskMetadataCard = LGTaskMetadataCard()
    private let taskActionsCard = LGTaskActionsCard()
    
    // Quick Actions
    private let quickActionsContainer = LGBaseView()
    private let completeButton = LGFloatingActionButton()
    private let editFAB = LGFloatingActionButton()
    
    // MARK: - Properties
    private let task: NTask
    private var isEditMode = false
    
    // MARK: - Initialization
    
    init(task: NTask) {
        self.task = task
        super.init(nibName: nil, bundle: nil)
        setupViewModel()
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
        setupGestures()
        applyTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateEntrance()
        viewModel.refreshTask()
    }
    
    // MARK: - Setup
    
    private func setupViewModel() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        viewModel = LGTaskDetailViewModel(task: task, context: context)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        setupNavigationView()
        setupContentContainer()
        setupTaskCards()
        setupQuickActions()
    }
    
    private func setupNavigationView() {
        navigationGlassView.glassIntensity = 0.9
        navigationGlassView.cornerRadius = 0
        navigationGlassView.enableGlassBorder = false
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.largeTitleFontSize, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.text = "Task Details"
        titleLabel.numberOfLines = 2
        
        editButton.setTitle("Edit", for: .normal)
        editButton.icon = UIImage(systemName: "pencil")
        
        closeButton.setTitle("Close", for: .normal)
        closeButton.icon = UIImage(systemName: "xmark")
        
        navigationGlassView.addSubview(titleLabel)
        navigationGlassView.addSubview(editButton)
        navigationGlassView.addSubview(closeButton)
        
        view.addSubview(navigationGlassView)
    }
    
    private func setupContentContainer() {
        contentContainer.glassIntensity = 0.1
        contentContainer.cornerRadius = 0
        contentContainer.enableGlassBorder = false
        
        contentScrollView.backgroundColor = .clear
        contentScrollView.showsVerticalScrollIndicator = false
        contentScrollView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 100, right: 0)
        
        contentStackView.axis = .vertical
        contentStackView.spacing = 16
        contentStackView.alignment = .fill
        contentStackView.distribution = .equalSpacing
        
        contentScrollView.addSubview(contentStackView)
        contentContainer.addSubview(contentScrollView)
        view.addSubview(contentContainer)
    }
    
    private func setupTaskCards() {
        // Configure task cards
        taskHeaderCard.configure(with: task)
        taskDetailsCard.configure(with: task)
        taskMetadataCard.configure(with: task)
        taskActionsCard.configure(with: task)
        
        // Add cards to stack view
        contentStackView.addArrangedSubview(taskHeaderCard)
        contentStackView.addArrangedSubview(taskDetailsCard)
        contentStackView.addArrangedSubview(taskMetadataCard)
        contentStackView.addArrangedSubview(taskActionsCard)
    }
    
    private func setupQuickActions() {
        quickActionsContainer.glassIntensity = 0.4
        quickActionsContainer.cornerRadius = LGDevice.isIPad ? 32 : 28
        quickActionsContainer.enableGlassBorder = true
        
        // Complete button
        completeButton.icon = UIImage(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
        completeButton.backgroundColor = task.isComplete ? .systemGreen : LGThemeManager.shared.primaryGlassColor
        completeButton.rippleEffectEnabled = true
        
        // Edit FAB
        editFAB.icon = UIImage(systemName: "pencil")
        editFAB.backgroundColor = LGThemeManager.shared.secondaryGlassColor
        editFAB.rippleEffectEnabled = true
        
        quickActionsContainer.addSubview(completeButton)
        quickActionsContainer.addSubview(editFAB)
        view.addSubview(quickActionsContainer)
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
            make.trailing.equalTo(editButton.snp.leading).offset(-12)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        editButton.snp.makeConstraints { make in
            make.trailing.equalTo(closeButton.snp.leading).offset(-8)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(60)
        }
        
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(60)
        }
        
        // Content container
        contentContainer.snp.makeConstraints { make in
            make.top.equalTo(navigationGlassView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        contentScrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
            make.width.equalTo(contentScrollView).offset(-32)
        }
        
        // Quick actions
        quickActionsContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.width.equalTo(LGDevice.isIPad ? 140 : 120)
            make.height.equalTo(LGDevice.isIPad ? 64 : 56)
        }
        
        completeButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(LGDevice.isIPad ? 48 : 40)
        }
        
        editFAB.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.size.equalTo(LGDevice.isIPad ? 48 : 40)
        }
    }
    
    // MARK: - Bindings
    
    private func setupBindings() {
        // Task updates
        viewModel.taskData
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] taskData in
                self?.updateTaskDisplay(taskData)
            })
            .disposed(by: disposeBag)
        
        viewModel.isLoading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isLoading in
                self?.updateLoadingState(isLoading)
            })
            .disposed(by: disposeBag)
        
        viewModel.error
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] error in
                self?.showError(error)
            })
            .disposed(by: disposeBag)
        
        viewModel.taskUpdated
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] task in
                self?.handleTaskUpdate(task)
            })
            .disposed(by: disposeBag)
        
        // Button actions
        closeButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.handleClose()
            })
            .disposed(by: disposeBag)
        
        editButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.handleEdit()
            })
            .disposed(by: disposeBag)
        
        completeButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.handleToggleComplete()
            })
            .disposed(by: disposeBag)
        
        editFAB.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.handleEdit()
            })
            .disposed(by: disposeBag)
        
        // Card actions
        taskActionsCard.onDeleteTapped = { [weak self] in
            self?.handleDelete()
        }
        
        taskActionsCard.onDuplicateTapped = { [weak self] in
            self?.handleDuplicate()
        }
        
        taskActionsCard.onShareTapped = { [weak self] in
            self?.handleShare()
        }
    }
    
    // MARK: - Gestures
    
    private func setupGestures() {
        // Swipe gestures
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)
        
        // Long press for quick actions
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        taskHeaderCard.addGestureRecognizer(longPress)
        
        // Pinch to zoom (for accessibility)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
    }
    
    @objc private func handleSwipeLeft() {
        // Swipe left to mark complete
        if !task.isComplete {
            handleToggleComplete()
        }
    }
    
    @objc private func handleSwipeRight() {
        // Swipe right to edit
        handleEdit()
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        // Show context menu
        showContextMenu(at: gesture.location(in: view))
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        // Accessibility zoom
        let scale = gesture.scale
        
        if scale > 1.2 {
            // Zoom in - increase font sizes
            increaseFontSizes()
        } else if scale < 0.8 {
            // Zoom out - decrease font sizes
            decreaseFontSizes()
        }
        
        gesture.scale = 1.0
    }
    
    // MARK: - UI Updates
    
    private func updateTaskDisplay(_ taskData: TaskCardData) {
        titleLabel.text = taskData.title
        
        taskHeaderCard.configure(with: task)
        taskDetailsCard.configure(with: task)
        taskMetadataCard.configure(with: task)
        taskActionsCard.configure(with: task)
        
        // Update complete button
        let isComplete = taskData.isCompleted
        completeButton.icon = UIImage(systemName: isComplete ? "checkmark.circle.fill" : "circle")
        completeButton.backgroundColor = isComplete ? .systemGreen : LGThemeManager.shared.primaryGlassColor
        
        if isComplete {
            completeButton.morphButton(to: .pressed) {
                self.completeButton.morphButton(to: .idle)
            }
        }
    }
    
    private func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            // Show loading state
            contentScrollView.isUserInteractionEnabled = false
            navigationGlassView.morphGlass(to: .shimmerPulse, config: .subtle)
        } else {
            contentScrollView.isUserInteractionEnabled = true
            navigationGlassView.morphGlass(to: .idle, config: .subtle)
        }
    }
    
    // MARK: - Actions
    
    private func handleClose() {
        dismiss(animated: true)
    }
    
    private func handleEdit() {
        let editVC = LGAddTaskViewController(editingTask: task)
        let navController = UINavigationController(rootViewController: editVC)
        navController.modalPresentationStyle = .pageSheet
        
        present(navController, animated: true)
    }
    
    private func handleToggleComplete() {
        // Add haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Animate button
        completeButton.morphButton(to: .expanding) {
            self.completeButton.morphButton(to: .idle)
        }
        
        viewModel.toggleTaskCompletion()
    }
    
    private func handleDelete() {
        showDeleteConfirmationAlert()
    }
    
    private func handleDuplicate() {
        viewModel.duplicateTask()
        
        // Show success feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
        
        showSuccessMessage("Task duplicated successfully")
    }
    
    private func handleShare() {
        let taskText = """
        Task: \(task.taskName ?? "Untitled")
        Description: \(task.taskDescription ?? "No description")
        Due Date: \(task.dueDate?.formatted() ?? "No due date")
        Priority: \(TaskPriority(rawValue: Int(task.taskPriority))?.displayName ?? "Medium")
        Status: \(task.isComplete ? "Completed" : "Pending")
        """
        
        let activityVC = UIActivityViewController(activityItems: [taskText], applicationActivities: nil)
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = taskActionsCard
            popover.sourceRect = taskActionsCard.bounds
        }
        
        present(activityVC, animated: true)
    }
    
    private func handleTaskUpdate(_ task: NTask) {
        // Refresh the display
        viewModel.refreshTask()
        
        // Add success haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
    
    // MARK: - Context Menu
    
    private func showContextMenu(at point: CGPoint) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Toggle completion
        let completeTitle = task.isComplete ? "Mark Incomplete" : "Mark Complete"
        let completeIcon = task.isComplete ? "circle" : "checkmark.circle"
        alertController.addAction(UIAlertAction(title: completeTitle, style: .default) { _ in
            self.handleToggleComplete()
        })
        
        // Edit
        alertController.addAction(UIAlertAction(title: "Edit", style: .default) { _ in
            self.handleEdit()
        })
        
        // Duplicate
        alertController.addAction(UIAlertAction(title: "Duplicate", style: .default) { _ in
            self.handleDuplicate()
        })
        
        // Share
        alertController.addAction(UIAlertAction(title: "Share", style: .default) { _ in
            self.handleShare()
        })
        
        // Delete
        alertController.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.handleDelete()
        })
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(origin: point, size: CGSize(width: 1, height: 1))
        }
        
        present(alertController, animated: true)
    }
    
    // MARK: - Alerts
    
    private func showDeleteConfirmationAlert() {
        let alert = UIAlertController(
            title: "Delete Task",
            message: "Are you sure you want to delete this task? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.viewModel.deleteTask()
            self.dismiss(animated: true)
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
    
    private func showSuccessMessage(_ message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Accessibility
    
    private func increaseFontSizes() {
        // Implement font size increase for accessibility
        titleLabel.font = titleLabel.font.withSize(titleLabel.font.pointSize * 1.1)
    }
    
    private func decreaseFontSizes() {
        // Implement font size decrease
        titleLabel.font = titleLabel.font.withSize(max(titleLabel.font.pointSize * 0.9, 12))
    }
    
    // MARK: - Theme
    
    private func applyTheme() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        // Update glass intensities based on theme
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        navigationGlassView.glassIntensity = isDarkMode ? 0.7 : 0.9
        contentContainer.glassIntensity = isDarkMode ? 0.05 : 0.1
        quickActionsContainer.glassIntensity = isDarkMode ? 0.3 : 0.4
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        // Animate navigation view
        navigationGlassView.morphGlass(to: .shimmerPulse, config: .subtle) {
            self.navigationGlassView.morphGlass(to: .idle, config: .subtle)
        }
        
        // Animate cards with staggered timing
        contentStackView.arrangedSubviews.enumerated().forEach { index, view in
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: 0, y: 30)
            
            UIView.animate(withDuration: 0.5, delay: TimeInterval(index) * 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
                view.alpha = 1
                view.transform = .identity
            }
        }
        
        // Animate quick actions
        quickActionsContainer.alpha = 0
        quickActionsContainer.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.6, delay: 0.4, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.quickActionsContainer.alpha = 1
            self.quickActionsContainer.transform = .identity
        }
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyTheme()
        }
    }
}
