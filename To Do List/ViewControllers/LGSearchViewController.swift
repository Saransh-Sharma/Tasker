//
//  LGSearchViewController.swift
//  Tasker
//
//  iOS 16+ Liquid Glass Search Screen with Backdrop/Foredrop Architecture
//

import UIKit
import CoreData
import SwiftUI

// MARK: - LGFilterButton

class LGFilterButton: LGBaseView {

    // MARK: - Properties

    var filterType: LGSearchViewController.FilterType = .status(.all) {
        didSet { updateAppearance() }
    }

    var isSelected: Bool = false {
        didSet { updateAppearance() }
    }

    var selectedStyle: TaskerChipSelectionStyle = .tinted {
        didSet { updateAppearance() }
    }

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .tasker.font(for: .bodyEmphasis)
        label.textColor = .label // Will be updated in applyTheme
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

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
        cornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.r2
        borderWidth = 0

        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])

        updateAppearance()
    }

    // MARK: - Public Methods

    func setTitle(_ title: String, for state: UIControl.State) {
        titleLabel.text = title
    }

    func addTapGesture(target: Any?, action: Selector) {
        let tapGesture = UITapGestureRecognizer(target: target, action: action)
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }

    // MARK: - Appearance Methods

    func updateAppearance() {
        let todoColors = TaskerThemeManager.shared.currentTheme.tokens.color
        if isSelected {
            switch selectedStyle {
            case .tinted:
                backgroundColor = todoColors.accentMuted
                titleLabel.textColor = todoColors.accentPrimary
                borderColor = todoColors.accentRing
                borderWidth = 1.0
            case .filled:
                backgroundColor = tintColor ?? todoColors.chipSelectedBackground
                titleLabel.textColor = todoColors.accentOnPrimary
                borderColor = UIColor.clear
                borderWidth = 0
            }
            transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        } else {
            backgroundColor = todoColors.chipUnselectedBackground
            borderColor = UIColor.clear
            borderWidth = 0
            transform = .identity
            titleLabel.textColor = todoColors.textSecondary
        }
    }

    override var tintColor: UIColor! {
        didSet { updateAppearance() }
    }
}

// MARK: - LGSearchViewController

class LGSearchViewController: UIViewController {

    // MARK: - Properties

    private var viewModel: LGSearchViewModel!
    private var tasks: [NTask] = []

    // Theme
    private var todoColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }

    // Backdrop/Foredrop Architecture (like HomeViewController)
    private let backdropContainer = UIView()
    private let foredropContainer = UIView()

    // Navigation
    private let navigationBarView = UIView()
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.setTitle("Back", for: .normal)
        button.tintColor = .label
        button.titleLabel?.font = .tasker.font(for: .bodyEmphasis)
        button.contentHorizontalAlignment = .leading
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Search Tasks"
        label.font = .tasker.font(for: .title2)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Search Bar (integrated into backdrop)
    private let searchBar = LGSearchBar()

    // Filter Container (backdrop area)
    private let filterScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        return scrollView
    }()

    private let filterStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .center
        stackView.distribution = .fill
        return stackView
    }()

    // Foredrop Content
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        return scrollView
    }()

    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    // Empty State (foredrop area)
    private let emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let emptyStateImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "magnifyingglass")
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No tasks found"
        label.font = .tasker.font(for: .title2)
        label.textColor = .label // Will be updated in applyTheme
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let emptyStateSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Try different search terms or filters"
        label.font = .tasker.font(for: .body)
        label.textColor = .label.withAlphaComponent(0.7) // Will be updated in applyTheme
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewModel()
        setupBackdropForedropArchitecture()
        setupNavigationBar()
        setupSearchBar()
        setupFilters()
        setupForedropContent()
        setupKeyboardHandling()
        applyTheme()

        // Auto-focus search bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            _ = self.searchBar.becomeFirstResponder()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyTheme()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBackdropForedropLayout()
    }
    
    // MARK: - Setup

    private func setupViewModel() {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            logError(" Failed to get Core Data context")
            return
        }

        viewModel = LGSearchViewModel(context: context)
        viewModel.onResultsUpdated = { [weak self] tasks in
            self?.tasks = tasks
            self?.updateResults()
        }
    }

    private func setupBackdropForedropArchitecture() {
        // Add main containers to view hierarchy
        view.addSubview(backdropContainer)
        view.addSubview(foredropContainer)

        // Backdrop covers the entire view
        backdropContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backdropContainer.topAnchor.constraint(equalTo: view.topAnchor),
            backdropContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropContainer.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.4) // Top 40% for backdrop
        ])

        // Foredrop covers the bottom portion
        foredropContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            foredropContainer.topAnchor.constraint(equalTo: backdropContainer.bottomAnchor),
            foredropContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            foredropContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            foredropContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Style containers
        backdropContainer.backgroundColor = todoColors.bgElevated
        foredropContainer.backgroundColor = todoColors.bgCanvas
        foredropContainer.layer.cornerRadius = 24
        foredropContainer.layer.cornerCurve = .continuous
        foredropContainer.applyTaskerElevation(.e1)
    }

    private func setupNavigationBar() {
        // Add navigation bar to backdrop
        backdropContainer.addSubview(navigationBarView)
        navigationBarView.translatesAutoresizingMaskIntoConstraints = false

        // Add navigation elements
        navigationBarView.addSubview(backButton)
        navigationBarView.addSubview(navigationTitleLabel)

        // Setup back button action
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            // Navigation bar positioned at top of backdrop
            navigationBarView.topAnchor.constraint(equalTo: backdropContainer.safeAreaLayoutGuide.topAnchor),
            navigationBarView.leadingAnchor.constraint(equalTo: backdropContainer.leadingAnchor),
            navigationBarView.trailingAnchor.constraint(equalTo: backdropContainer.trailingAnchor),
            navigationBarView.heightAnchor.constraint(equalToConstant: 60),

            // Back button
            backButton.leadingAnchor.constraint(equalTo: navigationBarView.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: navigationBarView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 80),
            backButton.heightAnchor.constraint(equalToConstant: 44),

            // Title label
            navigationTitleLabel.centerXAnchor.constraint(equalTo: navigationBarView.centerXAnchor),
            navigationTitleLabel.centerYAnchor.constraint(equalTo: navigationBarView.centerYAnchor),
            navigationTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 16),
            navigationTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: navigationBarView.trailingAnchor, constant: -16)
        ])
    }

    private func setupSearchBar() {
        // Add search bar to backdrop, below navigation
        backdropContainer.addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.delegate = self

        NSLayoutConstraint.activate([
            // Search bar positioned below navigation bar
            searchBar.topAnchor.constraint(equalTo: navigationBarView.bottomAnchor, constant: 12),
            searchBar.leadingAnchor.constraint(equalTo: backdropContainer.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: backdropContainer.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 44)
        ])

        // Animate appearance
        searchBar.animateGlassAppearance()
    }

    private func setupFilters() {
        // Add filter scroll view to backdrop, below search bar
        backdropContainer.addSubview(filterScrollView)
        filterScrollView.addSubview(filterStackView)

        NSLayoutConstraint.activate([
            // Filter scroll view
            filterScrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 16),
            filterScrollView.leadingAnchor.constraint(equalTo: backdropContainer.leadingAnchor),
            filterScrollView.trailingAnchor.constraint(equalTo: backdropContainer.trailingAnchor),
            filterScrollView.heightAnchor.constraint(equalToConstant: 60),

            // Filter stack view
            filterStackView.topAnchor.constraint(equalTo: filterScrollView.topAnchor),
            filterStackView.leadingAnchor.constraint(equalTo: filterScrollView.leadingAnchor, constant: 16),
            filterStackView.trailingAnchor.constraint(equalTo: filterScrollView.trailingAnchor, constant: -16),
            filterStackView.bottomAnchor.constraint(equalTo: filterScrollView.bottomAnchor),
            filterStackView.heightAnchor.constraint(equalToConstant: 44)
        ])

        setupFilterButtons()
    }

    private func setupForedropContent() {
        // Add scroll view to foredrop
        foredropContainer.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        // Add empty state to foredrop
        foredropContainer.addSubview(emptyStateView)
        emptyStateView.addSubview(emptyStateImageView)
        emptyStateView.addSubview(emptyStateLabel)
        emptyStateView.addSubview(emptyStateSubtitleLabel)

        NSLayoutConstraint.activate([
            // Scroll view fills foredrop
            scrollView.topAnchor.constraint(equalTo: foredropContainer.topAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: foredropContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: foredropContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: foredropContainer.bottomAnchor),

            // Content stack view
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: foredropContainer.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: foredropContainer.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentStackView.widthAnchor.constraint(equalTo: foredropContainer.widthAnchor, constant: -32),

            // Empty state centering
            emptyStateView.centerXAnchor.constraint(equalTo: foredropContainer.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: foredropContainer.centerYAnchor),

            // Empty state image
            emptyStateImageView.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateImageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateImageView.widthAnchor.constraint(equalToConstant: 60),
            emptyStateImageView.heightAnchor.constraint(equalToConstant: 60),

            // Empty state title
            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateImageView.bottomAnchor, constant: 16),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -32),

            // Empty state subtitle
            emptyStateSubtitleLabel.topAnchor.constraint(equalTo: emptyStateLabel.bottomAnchor, constant: 8),
            emptyStateSubtitleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 32),
            emptyStateSubtitleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -32),
            emptyStateSubtitleLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
    }

    private func updateBackdropForedropLayout() {
        // This method can be called from viewDidLayoutSubviews to update layout if needed
        // For now, constraints handle the layout automatically
    }
    
    private func setupFilterButtons() {
        // Clear any existing buttons
        filterStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Status filters
        let statusFilters: [(title: String, type: StatusFilterType)] = [
            ("All Tasks", .all),
            ("Today", .today),
            ("Overdue", .overdue),
            ("Completed", .completed)
        ]

        for filter in statusFilters {
            let button = createGlassFilterButton(title: filter.title, filterType: .status(filter.type))
            button.addTapGesture(target: self, action: #selector(statusFilterTapped(_:)))
            filterStackView.addArrangedSubview(button)
        }

        // Priority filters - using TaskPriorityConfig colors for consistency
        let priorities: [(title: String, value: Int32, color: UIColor)] = [
            ("P0", 1, TaskPriorityConfig.Priority.none.color),   // None - Gray
            ("P1", 2, TaskPriorityConfig.Priority.low.color),    // Low - Blue
            ("P2", 3, TaskPriorityConfig.Priority.high.color),   // High - Orange
            ("P3", 4, TaskPriorityConfig.Priority.max.color)     // Max - Red
        ]

        for priority in priorities {
            let button = createGlassFilterButton(title: priority.title, color: priority.color, filterType: .priority(priority.value))
            button.tag = Int(priority.value)
            button.addTapGesture(target: self, action: #selector(priorityFilterTapped(_:)))
            filterStackView.addArrangedSubview(button)
        }

        // Project filter
        let projectButton = createGlassFilterButton(title: "All Projects", filterType: .project(nil))
        projectButton.addTapGesture(target: self, action: #selector(projectFilterTapped(_:)))
        filterStackView.addArrangedSubview(projectButton)

        // Add initial animation
        animateFilterButtons()
    }

    private func createGlassFilterButton(title: String, color: UIColor? = nil, filterType: FilterType) -> LGFilterButton {
        let button = LGFilterButton()
        button.setTitle(title, for: .normal)
        button.filterType = filterType

        if let color = color {
            button.tintColor = color
        }

        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true

        return button
    }

    private func animateFilterButtons() {
        for (index, button) in filterStackView.arrangedSubviews.enumerated() {
            button.alpha = 0
            button.transform = CGAffineTransform(translationX: 0, y: 20)

            UIView.animate(
                withDuration: 0.4,
                delay: Double(index) * 0.08,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5
            ) {
                button.alpha = 1
                button.transform = .identity
            }
        }
    }

    // MARK: - Filter Types

    enum FilterType {
        case status(StatusFilterType)
        case priority(Int32)
        case project(String?)
    }

    enum StatusFilterType {
        case all, today, overdue, completed
    }
    
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    // MARK: - Theme Application

    private func applyTheme() {
        view.backgroundColor = todoColors.bgCanvas
        backdropContainer.backgroundColor = todoColors.bgElevated
        navigationBarView.backgroundColor = todoColors.surfacePrimary
        backButton.tintColor = todoColors.accentPrimary
        navigationTitleLabel.textColor = todoColors.textPrimary
        searchBar.backgroundColor = todoColors.surfaceSecondary
        searchBar.layer.borderColor = todoColors.divider.cgColor

        // Apply theme to search bar internal elements
        searchBar.applyTheme()

        filterScrollView.backgroundColor = todoColors.bgElevated

        // Update empty state colors to match theme
        emptyStateLabel.textColor = todoColors.textPrimary
        emptyStateSubtitleLabel.textColor = todoColors.textPrimary.withAlphaComponent(0.7)
        emptyStateImageView.tintColor = todoColors.textPrimary.withAlphaComponent(0.5)

        // Apply theme to filter buttons - match home screen styling
        filterStackView.arrangedSubviews.forEach { view in
            if let button = view as? LGFilterButton {
                button.tintColor = todoColors.accentPrimary
                button.updateAppearance()
            }
        }
    }

    // MARK: - Actions

    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }

    @objc private func statusFilterTapped(_ gesture: UITapGestureRecognizer) {
        guard let button = gesture.view as? LGFilterButton else { return }
        // Toggle filter selection
        button.isSelected.toggle()

        // Update other status filters to maintain single selection
        filterStackView.arrangedSubviews.forEach { view in
            if let filterButton = view as? LGFilterButton,
               case .status = filterButton.filterType,
               filterButton != button {
                filterButton.isSelected = false
            }
        }

        // Animate selection
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            button.transform = button.isSelected ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        }

        // Apply filter and re-run search
        applyFiltersAndSearch()
    }

    @objc private func priorityFilterTapped(_ gesture: UITapGestureRecognizer) {
        guard let button = gesture.view as? LGFilterButton else { return }
        // Toggle filter selection
        button.isSelected.toggle()

        // Animate selection
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            button.transform = button.isSelected ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        }

        // Apply filter and re-run search
        applyFiltersAndSearch()
    }

    @objc private func projectFilterTapped(_ gesture: UITapGestureRecognizer) {
        guard let button = gesture.view as? LGFilterButton else { return }
        // For now, just toggle selection - project picker would be implemented here
        button.isSelected.toggle()

        // Animate selection
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            button.transform = button.isSelected ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
        }

        // Apply filter and re-run search
        applyFiltersAndSearch()
    }

    private func applyFiltersAndSearch() {
        // Clear existing filters
        viewModel.clearFilters()

        // Apply selected filters
        filterStackView.arrangedSubviews.forEach { view in
            if let button = view as? LGFilterButton, button.isSelected {
                switch button.filterType {
                case .priority(let priority):
                    viewModel.togglePriorityFilter(priority)
                case .project(let project):
                    if let project = project {
                        viewModel.toggleProjectFilter(project)
                    }
                case .status(let statusType):
                    // Handle status filters in ViewModel
                    applyStatusFilter(statusType)
                }
            }
        }

        // Re-run search
        let searchText = searchBar.text
        if searchText.isEmpty {
            viewModel.searchAll()
        } else {
            viewModel.search(query: searchText)
        }
    }

    private func applyStatusFilter(_ statusType: StatusFilterType) {
        // This would extend the ViewModel to handle status filters
        // For now, we'll implement basic filtering logic here
        switch statusType {
        case .all:
            // No additional filtering needed
            break
        case .today:
            // Filter for today's tasks
            filterTasksForToday()
        case .overdue:
            // Filter for overdue tasks
            filterTasksForOverdue()
        case .completed:
            // Filter for completed tasks
            filterTasksForCompleted()
        }
    }

    private func filterTasksForToday() {
        // Implementation would go here - temporarily using existing search
        viewModel.searchAll()
    }

    private func filterTasksForOverdue() {
        // Implementation would go here - temporarily using existing search
        viewModel.searchAll()
    }

    private func filterTasksForCompleted() {
        // Implementation would go here - temporarily using existing search
        viewModel.searchAll()
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let keyboardHeight = keyboardFrame.height
        scrollView.contentInset.bottom = keyboardHeight
        var verticalInsets = scrollView.verticalScrollIndicatorInsets
        verticalInsets.bottom = keyboardHeight
        scrollView.verticalScrollIndicatorInsets = verticalInsets
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
        var verticalInsets = scrollView.verticalScrollIndicatorInsets
        verticalInsets.bottom = 0
        scrollView.verticalScrollIndicatorInsets = verticalInsets
    }
    
    // MARK: - Update Results

    private func updateResults() {
        // Clear existing cards
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if tasks.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
            displayTaskResults()
        }
    }

    private func showEmptyState() {
        emptyStateView.isHidden = false
        scrollView.isHidden = true

        if searchBar.text.isEmpty {
            emptyStateLabel.text = "Start searching"
            emptyStateSubtitleLabel.text = "Type to search your tasks or use filters above"
        } else {
            emptyStateLabel.text = "No tasks found"
            emptyStateSubtitleLabel.text = "Try different search terms or adjust your filters"
        }
    }

    private func hideEmptyState() {
        emptyStateView.isHidden = true
        scrollView.isHidden = false
    }

    private func displayTaskResults() {
        // Group by project for better organization
        let grouped = viewModel.groupTasksByProject(tasks)

        for (groupIndex, group) in grouped.enumerated() {
            // Create project section header with glass morphism
            let headerContainer = createProjectHeader(project: group.project, count: group.tasks.count)
            contentStackView.addArrangedSubview(headerContainer)

            // Add task cards
            for (taskIndex, task) in group.tasks.enumerated() {
                let card = LGTaskCard()
                card.task = task
                card.onTap = { [weak self] task in
                    self?.showTaskDetail(task)
                }

                contentStackView.addArrangedSubview(card)

                // Animate card appearance with staggered timing
                let cardDelay = Double(groupIndex * 3 + taskIndex) * 0.05
                animateCardAppearance(card, delay: cardDelay)
            }

            // Add spacing between project sections
            if groupIndex < grouped.count - 1 {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.heightAnchor.constraint(equalToConstant: 16).isActive = true
                contentStackView.addArrangedSubview(spacer)
            }
        }
    }

    private func createProjectHeader(project: String, count: Int) -> UIView {
        let headerContainer = LGBaseView()
        headerContainer.cornerRadius = 12
        headerContainer.backgroundColor = todoColors.surfaceSecondary

        let headerLabel = UILabel()
        headerLabel.text = "\(project) (\(count))"
        headerLabel.font = .tasker.font(for: .bodyEmphasis)
        headerLabel.textColor = todoColors.textPrimary
        headerLabel.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(headerLabel)

        NSLayoutConstraint.activate([
            headerLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            headerLabel.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            headerLabel.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
            headerLabel.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -12),
            headerContainer.heightAnchor.constraint(equalToConstant: 44)
        ])

        return headerContainer
    }

    private func animateCardAppearance(_ card: LGTaskCard, delay: TimeInterval) {
        card.alpha = 0
        card.transform = CGAffineTransform(translationX: 0, y: 20)

        UIView.animate(
            withDuration: 0.4,
            delay: delay,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5
        ) {
            card.alpha = 1
            card.transform = .identity
        }
    }

    private func showTaskDetail(_ task: NTask) {
        presentTaskDetailSheet(for: task)
    }

    private func presentTaskDetailSheet(for task: NTask) {
        logDebug("HOME_TAP_DETAIL mode=sheet scope=search action=present_start taskID=\(task.taskID?.uuidString ?? "nil")")
        let detailView = TaskDetailSheetView(
            task: task,
            projectNames: buildProjectChipData(),
            onSave: { [weak self] in
                self?.refreshAfterTaskDetailMutation(reason: "save")
            },
            onToggleComplete: { [weak self] in
                self?.refreshAfterTaskDetailMutation(reason: "toggle")
            },
            onDismiss: nil,
            onDelete: { [weak self] in
                guard let self else { return }
                task.managedObjectContext?.delete(task)
                do {
                    try task.managedObjectContext?.save()
                    logDebug("HOME_TAP_DETAIL mode=sheet scope=search action=delete taskID=\(task.taskID?.uuidString ?? "nil")")
                } catch {
                    logError(
                        event: "search_task_delete_failed",
                        message: "Failed to delete task from search detail sheet",
                        fields: [
                            "task_id": task.taskID?.uuidString ?? "nil",
                            "error": error.localizedDescription
                        ]
                    )
                }

                self.presentedViewController?.dismiss(animated: true) { [weak self] in
                    self?.refreshAfterTaskDetailMutation(reason: "delete")
                }
            }
        )

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        hostingController.modalPresentationStyle = .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        present(hostingController, animated: true)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        logDebug("HOME_TAP_DETAIL mode=sheet scope=search action=presented taskID=\(task.taskID?.uuidString ?? "nil")")
    }

    private func refreshAfterTaskDetailMutation(reason: String) {
        applyFiltersAndSearch()
        logDebug("HOME_TAP_DETAIL mode=sheet scope=search action=refresh reason=\(reason)")
    }

    private func buildProjectChipData() -> [String] {
        var projectNames: [String] = []
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "projectName", ascending: true)]
            if let projects = try? context.fetch(request) {
                projectNames = projects.compactMap { $0.projectName?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }

        let inboxTitle = ProjectConstants.inboxProjectName
        projectNames.removeAll { $0.caseInsensitiveCompare(inboxTitle) == .orderedSame }
        projectNames.insert(inboxTitle, at: 0)

        var deduped: [String] = []
        var seen = Set<String>()
        for name in projectNames {
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            deduped.append(name)
        }
        return deduped
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - LGSearchBarDelegate

extension LGSearchViewController: LGSearchBarDelegate {
    func searchBar(_ searchBar: LGSearchBar, textDidChange text: String) {
        if text.isEmpty {
            viewModel.searchResults = []
            updateResults()
        } else {
            viewModel.search(query: text)
        }
    }
    
    func searchBarDidBeginEditing(_ searchBar: LGSearchBar) {
        // Optional: Handle begin editing
    }
    
    func searchBarDidEndEditing(_ searchBar: LGSearchBar) {
        // Optional: Handle end editing
    }
    
    func searchBarSearchButtonTapped(_ searchBar: LGSearchBar) {
        _ = searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonTapped(_ searchBar: LGSearchBar) {
        dismiss(animated: true)
    }
}
