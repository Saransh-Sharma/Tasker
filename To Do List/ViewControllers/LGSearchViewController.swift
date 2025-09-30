//
//  LGSearchViewController.swift
//  Tasker
//
//  iOS 16+ Liquid Glass Search Screen
//

import UIKit
import CoreData

class LGSearchViewController: UIViewController {
    
    // MARK: - Properties
    
    private var viewModel: LGSearchViewModel!
    private var tasks: [NTask] = []
    
    // UI Components
    private let searchBar = LGSearchBar()
    
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
    
    private let filterContainerView = LGBaseView()
    
    private let filterStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let emptyStateView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No tasks found"
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emptyStateSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Try a different search term"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.4)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .white.withAlphaComponent(0.8)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewModel()
        setupUI()
        setupKeyboardHandling()
        
        // Auto-focus search bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            _ = self.searchBar.becomeFirstResponder()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Apply theme (fallback to default if asset not found)
        let themeColor = UIColor(named: "AppPrimaryColor") ?? UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0)
        view.backgroundColor = themeColor
    }
    
    // MARK: - Setup
    
    private func setupViewModel() {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            print("❌ Failed to get Core Data context")
            return
        }
        
        viewModel = LGSearchViewModel(context: context)
        viewModel.onResultsUpdated = { [weak self] tasks in
            self?.tasks = tasks
            self?.updateResults()
        }
    }
    
    private func setupUI() {
        view.addSubview(closeButton)
        view.addSubview(searchBar)
        view.addSubview(filterContainerView)
        view.addSubview(scrollView)
        view.addSubview(emptyStateView)
        
        scrollView.addSubview(contentStackView)
        
        filterContainerView.addSubview(filterStackView)
        
        emptyStateView.addSubview(emptyStateLabel)
        emptyStateView.addSubview(emptyStateSubtitleLabel)
        
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        
        filterContainerView.translatesAutoresizingMaskIntoConstraints = false
        filterContainerView.cornerRadius = 12
        
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            // Close button
            closeButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Search bar
            searchBar.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            
            // Filter container
            filterContainerView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 12),
            filterContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            filterContainerView.heightAnchor.constraint(equalToConstant: 50),
            
            // Filter stack view
            filterStackView.leadingAnchor.constraint(equalTo: filterContainerView.leadingAnchor, constant: 12),
            filterStackView.trailingAnchor.constraint(equalTo: filterContainerView.trailingAnchor, constant: -12),
            filterStackView.centerYAnchor.constraint(equalTo: filterContainerView.centerYAnchor),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: filterContainerView.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content stack view
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -100),
            
            // Empty state
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -64),
            
            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            
            emptyStateSubtitleLabel.topAnchor.constraint(equalTo: emptyStateLabel.bottomAnchor, constant: 8),
            emptyStateSubtitleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateSubtitleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor),
            emptyStateSubtitleLabel.bottomAnchor.constraint(equalTo: emptyStateView.bottomAnchor)
        ])
        
        setupFilterButtons()
        
        // Animate appearance
        searchBar.animateGlassAppearance()
        filterContainerView.animateGlassAppearance(duration: 0.4)
    }
    
    private func setupFilterButtons() {
        // Priority filters
        let priorities: [(title: String, value: Int32, color: UIColor)] = [
            ("High", 1, .systemRed),
            ("Medium", 3, .systemYellow),
            ("Low", 4, .systemGreen)
        ]
        
        for priority in priorities {
            let button = createFilterButton(title: priority.title, color: priority.color)
            button.tag = Int(priority.value)
            button.addTarget(self, action: #selector(priorityFilterTapped(_:)), for: .touchUpInside)
            filterStackView.addArrangedSubview(button)
        }
    }
    
    private func createFilterButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = color.withAlphaComponent(0.3)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = color.withAlphaComponent(0.5).cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        return button
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
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func priorityFilterTapped(_ sender: UIButton) {
        let priority = Int32(sender.tag)
        viewModel.togglePriorityFilter(priority)
        
        // Update button appearance
        if viewModel.filteredPriorities.contains(priority) {
            sender.alpha = 1.0
            sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } else {
            sender.alpha = 0.5
            sender.transform = .identity
        }
        
        UIView.animate(withDuration: 0.2) {
            sender.transform = .identity
        }
        
        // Re-run search
        viewModel.search(query: searchBar.text)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let keyboardHeight = keyboardFrame.height
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.scrollIndicatorInsets.bottom = keyboardHeight
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset.bottom = 0
        scrollView.scrollIndicatorInsets.bottom = 0
    }
    
    // MARK: - Update Results
    
    private func updateResults() {
        // Clear existing cards
        contentStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if tasks.isEmpty {
            emptyStateView.isHidden = false
            scrollView.isHidden = true
            
            if searchBar.text.isEmpty {
                emptyStateLabel.text = "Start searching"
                emptyStateSubtitleLabel.text = "Type to search your tasks"
            } else {
                emptyStateLabel.text = "No tasks found"
                emptyStateSubtitleLabel.text = "Try a different search term"
            }
        } else {
            emptyStateView.isHidden = true
            scrollView.isHidden = false
            
            // Group by project
            let grouped = viewModel.groupTasksByProject(tasks)
            
            for (index, group) in grouped.enumerated() {
                // Project header
                let headerLabel = UILabel()
                headerLabel.text = "\(group.project) (\(group.tasks.count))"
                headerLabel.font = .systemFont(ofSize: 16, weight: .bold)
                headerLabel.textColor = .white.withAlphaComponent(0.9)
                contentStackView.addArrangedSubview(headerLabel)
                
                // Task cards
                for task in group.tasks {
                    let card = LGTaskCard()
                    card.task = task
                    card.onTap = { [weak self] task in
                        self?.showTaskDetail(task)
                    }
                    
                    contentStackView.addArrangedSubview(card)
                    
                    // Animate card appearance
                    card.alpha = 0
                    card.transform = CGAffineTransform(translationX: 0, y: 20)
                    
                    UIView.animate(
                        withDuration: 0.4,
                        delay: Double(index) * 0.05,
                        usingSpringWithDamping: 0.8,
                        initialSpringVelocity: 0.5
                    ) {
                        card.alpha = 1
                        card.transform = .identity
                    }
                }
                
                // Add spacing between groups
                if index < grouped.count - 1 {
                    let spacer = UIView()
                    spacer.translatesAutoresizingMaskIntoConstraints = false
                    spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
                    contentStackView.addArrangedSubview(spacer)
                }
            }
        }
    }
    
    private func showTaskDetail(_ task: NTask) {
        // TODO: Present task detail view
        print("📝 Show detail for task: \(task.name ?? "Untitled")")
        
        // For now, just provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
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
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonTapped(_ searchBar: LGSearchBar) {
        dismiss(animated: true)
    }
}

