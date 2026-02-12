//
//  HomeViewController+UISetup.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import SwiftUI
import FluentUI
import TinyConstraints
import SemiModalViewController
import FSCalendar
import UserNotifications

// MARK: - Transparent Hosting Controller for Chart Cards

class TransparentHostingController<Content: View>: UIHostingController<Content> {
    override func viewDidLoad() {
        super.viewDidLoad()
        applyTransparency()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyTransparency()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyTransparency()

        // Additional delayed pass for async-created subviews
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.applyTransparency()
        }
    }

    private func applyTransparency() {
        view.backgroundColor = .clear
        view.isOpaque = false
        clearAllSubviews(view)
    }

    private func clearAllSubviews(_ view: UIView) {
        view.backgroundColor = .clear

        if let scrollView = view as? UIScrollView {
            scrollView.backgroundColor = .clear
            scrollView.isOpaque = false
        }

        for subview in view.subviews {
            clearAllSubviews(subview)
        }
    }
}

extension HomeViewController: BadgeViewDelegate {
    private var homeTopBarHeight: CGFloat { 48 }
    private var tableTopSpacing: CGFloat { 8 }
    
    // MARK: - BadgeViewDelegate Methods
    
    func didSelectBadge(_ badge: BadgeView) {
        // Called when the badge becomes 'selected'.
        // You can leave this empty or handle selection styling if needed.
    }
    
    func didTapSelectedBadge(_ badge: BadgeView) {
        // Called when user taps on an already-selected badge.
        badge.isSelected = false
        let alert = UIAlertController(title: "A selected badge was tapped",
                                     message: nil,
                                     preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    // MARK: - Backdrop & Foredrop Setup
    
    func setupBackdrop() {
        backdropContainer.frame = view.bounds
        // Apply premium gradient instead of flat accent color
        TaskerHeaderGradient.apply(to: backdropContainer.layer, bounds: view.bounds, traits: traitCollection)

        // Add calendar and charts to backdrop
        setupCalendarInBackdrop()

        // Phase 7: Setup Horizontal Scrollable Chart Cards (NEW)
        setupChartCardsScrollView()

        view.addSubview(backdropContainer)
    }
    
    func setupCalendarInBackdrop() {
        // Initialize calendar if not already done
        if calendar == nil {
            calendar = FSCalendar(frame: CGRect(x: 0, y: -5, width: view.bounds.width, height: 300))
            calendar.dataSource = self
            calendar.delegate = self
            calendar.backgroundColor = .clear
            calendar.appearance.headerTitleColor = todoColors.textInverse
            calendar.appearance.weekdayTextColor = todoColors.textInverse
            calendar.appearance.titleDefaultColor = todoColors.textInverse
            calendar.appearance.todayColor = todoColors.accentMuted//todoColors.accentPrimary
            calendar.appearance.selectionColor = todoColors.accentMuted

            // Ensure calendar starts in week mode
            calendar.scope = .week
        }

        backdropContainer.addSubview(calendar)
    }

    func setupChartCardsScrollView() {
        print("📊 [Charts] Initializing vertical scroll view")

        // Create vertically scrollable chart cards
        let chartScrollView = ChartCardsScrollView(referenceDate: dateForTheView)

        // Use TransparentHostingController for automatic transparency management
        chartScrollHostingController = TransparentHostingController(rootView: AnyView(chartScrollView))

        guard let hostingController = chartScrollHostingController else {
            print("❌ [Charts] ERROR: Failed to create hosting controller")
            return
        }

        // Create container view for the scroll view
        chartScrollContainer = UIView()
        guard let container = chartScrollContainer else {
            print("❌ [Charts] ERROR: Failed to create container view")
            return
        }

        // Add hosting controller as child
        addChild(hostingController)
        container.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        // Configure container with transparency
        container.backgroundColor = .clear
        container.isOpaque = false
        backdropContainer.addSubview(container)

        // Configure hosting controller view with transparency
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false

        // Position scroll view in the chart area
        container.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Container constraints - full width edge-to-edge on iPhone portrait
            container.leadingAnchor.constraint(equalTo: backdropContainer.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: backdropContainer.trailingAnchor),
            container.topAnchor.constraint(equalTo: backdropContainer.topAnchor, constant: 120),
            container.heightAnchor.constraint(equalToConstant: 350),

            // Hosting controller view constraints
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        // Force layout pass to calculate proper frame immediately
        backdropContainer.layoutIfNeeded()

        // Apply immediate transparency
        applyChartScrollTransparency()

        // Apply delayed transparency passes for async-created subviews
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.applyChartScrollTransparency()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.applyChartScrollTransparency()
        }

        // Initially hidden (will be shown via button toggle)
        container.isHidden = true

        print("✅ [Charts] Vertical scroll view ready (hidden until toggle)")
    }

    // MARK: - Chart Scroll Transparency Helpers

    func applyChartScrollTransparency() {
        guard let container = chartScrollContainer,
              let hostingController = chartScrollHostingController else {
            return
        }

        // Clear container
        container.backgroundColor = .clear
        container.isOpaque = false

        // Clear hosting controller view
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false

        // Recursively clear all subviews (including UIScrollView)
        clearAllSubviewsRecursively(hostingController.view)
    }

    private func clearAllSubviewsRecursively(_ view: UIView) {
        view.backgroundColor = .clear

        if let scrollView = view as? UIScrollView {
            scrollView.backgroundColor = .clear
            scrollView.isOpaque = false
        }

        for subview in view.subviews {
            clearAllSubviewsRecursively(subview)
        }
    }
    
    
    
    func setupHomeFordrop() {
        // Calculate dimensions
        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height
        
        // Get the navigation bar height
        let navigationBarHeight = navigationController?.navigationBar.frame.height ?? 0

        // Total top area height (status bar + navigation bar)
        let totalTopHeight = navigationBarHeight
        
        let foredropHeight = screenHeight-totalTopHeight
        
        // Allow content to extend under the Liquid Glass bottom bar (no reserved space)
        // Keep a small top offset for styling, but do not subtract the bar height.
        foredropContainer.frame = CGRect(x: 0,
                                         y: screenHeight - foredropHeight + 24,
                                         width: screenWidth,
                                         height: foredropHeight)
        foredropContainer.backgroundColor = todoColors.bgCanvas        
        foredropContainer.layer.cornerRadius = 24
        foredropContainer.clipsToBounds = false
        foredropContainer.applyTaskerElevation(.e1)
        
        // Setup top section with "Today" title
        setupTopBarInForedrop()

        // Setup FluentUI table view in foredrop (main tableView removed)
        setupTableViewInForedrop()
        
        // Store the original foredrop center Y position for animations
        originalForedropCenterY = foredropContainer.center.y
    }
    
    func setupTopBarInForedrop() {
        homeTopBar = UIView(frame: CGRect(x: 0, y: 0, width: foredropContainer.bounds.width, height: homeTopBarHeight))
        homeTopBar.backgroundColor = UIColor.clear

        homeTitleRow = UIView()
        homeTopBar.addSubview(homeTitleRow)

        // Header label
        toDoListHeaderLabel.frame = CGRect(x: 0, y: 0, width: homeTopBar.bounds.width, height: 28)
        toDoListHeaderLabel.text = "Today"
        toDoListHeaderLabel.textAlignment = .left
        toDoListHeaderLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        toDoListHeaderLabel.textColor = todoColors.textPrimary
        homeTitleRow.addSubview(toDoListHeaderLabel)

        focusPotentialLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        focusPotentialLabel.textColor = todoColors.textSecondary
        focusPotentialLabel.textAlignment = .right
        focusPotentialLabel.numberOfLines = 1
        focusPotentialLabel.adjustsFontForContentSizeCategory = true
        homeTitleRow.addSubview(focusPotentialLabel)

        homeAdvancedFilterButton.setImage(UIImage(systemName: "line.3.horizontal.decrease.circle"), for: .normal)
        homeAdvancedFilterButton.tintColor = todoColors.textPrimary
        homeAdvancedFilterButton.accessibilityIdentifier = "home.focus.menu.button"
        homeAdvancedFilterButton.addTarget(self, action: #selector(toggleQuickFilterMenu), for: .touchUpInside)
        homeTitleRow.addSubview(homeAdvancedFilterButton)

        foredropContainer.addSubview(homeTopBar)
        setupQuickFilterMenu()
        refreshQuickFilterMenuContent()
    }

    private func setupQuickFilterMenu() {
        quickFilterMenuBackdrop.backgroundColor = UIColor.black.withAlphaComponent(0.12)
        quickFilterMenuBackdrop.alpha = 0
        quickFilterMenuBackdrop.isHidden = true
        quickFilterMenuBackdrop.isAccessibilityElement = true
        quickFilterMenuBackdrop.accessibilityLabel = "Dismiss quick filters"
        quickFilterMenuBackdrop.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleQuickFilterMenuBackdropTap)))
        foredropContainer.addSubview(quickFilterMenuBackdrop)

        quickFilterMenuContainer.backgroundColor = todoColors.surfacePrimary
        quickFilterMenuContainer.layer.cornerRadius = 16
        quickFilterMenuContainer.layer.masksToBounds = true
        quickFilterMenuContainer.applyTaskerElevation(.e2)
        quickFilterMenuContainer.alpha = 0
        quickFilterMenuContainer.isHidden = true
        quickFilterMenuContainer.accessibilityIdentifier = "home.focus.menu.container"
        foredropContainer.addSubview(quickFilterMenuContainer)

        quickFilterMenuScrollView.showsVerticalScrollIndicator = false
        quickFilterMenuScrollView.alwaysBounceVertical = false
        quickFilterMenuScrollView.backgroundColor = .clear
        quickFilterMenuScrollView.translatesAutoresizingMaskIntoConstraints = false
        quickFilterMenuContainer.addSubview(quickFilterMenuScrollView)

        quickFilterMenuContentStack.axis = .vertical
        quickFilterMenuContentStack.alignment = .fill
        quickFilterMenuContentStack.spacing = 8
        quickFilterMenuContentStack.translatesAutoresizingMaskIntoConstraints = false
        quickFilterMenuScrollView.addSubview(quickFilterMenuContentStack)

        quickFilterMenuQuickSectionLabel.text = "Quick Views"
        quickFilterMenuQuickSectionLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        quickFilterMenuQuickSectionLabel.textColor = todoColors.textSecondary
        quickFilterMenuQuickSectionLabel.adjustsFontForContentSizeCategory = true

        quickFilterMenuProjectSectionLabel.text = "Projects"
        quickFilterMenuProjectSectionLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        quickFilterMenuProjectSectionLabel.textColor = todoColors.textSecondary
        quickFilterMenuProjectSectionLabel.adjustsFontForContentSizeCategory = true

        quickFilterMenuQuickScrollView.showsHorizontalScrollIndicator = false
        quickFilterMenuQuickScrollView.backgroundColor = .clear
        quickFilterMenuQuickScrollView.translatesAutoresizingMaskIntoConstraints = false

        quickFilterMenuQuickStack.axis = .horizontal
        quickFilterMenuQuickStack.alignment = .center
        quickFilterMenuQuickStack.spacing = 8
        quickFilterMenuQuickStack.distribution = .fillProportionally
        quickFilterMenuQuickStack.translatesAutoresizingMaskIntoConstraints = false
        quickFilterMenuQuickScrollView.addSubview(quickFilterMenuQuickStack)

        quickFilterMenuProjectScrollView.showsHorizontalScrollIndicator = false
        quickFilterMenuProjectScrollView.backgroundColor = .clear
        quickFilterMenuProjectScrollView.translatesAutoresizingMaskIntoConstraints = false

        quickFilterMenuProjectStack.axis = .horizontal
        quickFilterMenuProjectStack.alignment = .center
        quickFilterMenuProjectStack.spacing = 8
        quickFilterMenuProjectStack.distribution = .fillProportionally
        quickFilterMenuProjectStack.translatesAutoresizingMaskIntoConstraints = false
        quickFilterMenuProjectScrollView.addSubview(quickFilterMenuProjectStack)

        quickFilterMenuAdvancedButton.setTitle("Advanced Filters", for: .normal)
        quickFilterMenuAdvancedButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        quickFilterMenuAdvancedButton.titleLabel?.adjustsFontForContentSizeCategory = true
        quickFilterMenuAdvancedButton.backgroundColor = todoColors.surfaceSecondary
        quickFilterMenuAdvancedButton.setTitleColor(todoColors.textPrimary, for: .normal)
        quickFilterMenuAdvancedButton.layer.cornerRadius = 12
        quickFilterMenuAdvancedButton.accessibilityIdentifier = "home.focus.menu.advanced"
        quickFilterMenuAdvancedButton.addTarget(self, action: #selector(openAdvancedFiltersFromMenu), for: .touchUpInside)
        quickFilterMenuAdvancedButton.translatesAutoresizingMaskIntoConstraints = false

        quickFilterMenuContentStack.addArrangedSubview(quickFilterMenuQuickSectionLabel)
        quickFilterMenuContentStack.addArrangedSubview(quickFilterMenuQuickScrollView)
        quickFilterMenuContentStack.addArrangedSubview(quickFilterMenuProjectSectionLabel)
        quickFilterMenuContentStack.addArrangedSubview(quickFilterMenuProjectScrollView)
        quickFilterMenuContentStack.addArrangedSubview(quickFilterMenuAdvancedButton)

        NSLayoutConstraint.activate([
            quickFilterMenuScrollView.leadingAnchor.constraint(equalTo: quickFilterMenuContainer.leadingAnchor, constant: 12),
            quickFilterMenuScrollView.trailingAnchor.constraint(equalTo: quickFilterMenuContainer.trailingAnchor, constant: -12),
            quickFilterMenuScrollView.topAnchor.constraint(equalTo: quickFilterMenuContainer.topAnchor, constant: 12),
            quickFilterMenuScrollView.bottomAnchor.constraint(equalTo: quickFilterMenuContainer.bottomAnchor, constant: -12),

            quickFilterMenuContentStack.leadingAnchor.constraint(equalTo: quickFilterMenuScrollView.contentLayoutGuide.leadingAnchor),
            quickFilterMenuContentStack.trailingAnchor.constraint(equalTo: quickFilterMenuScrollView.contentLayoutGuide.trailingAnchor),
            quickFilterMenuContentStack.topAnchor.constraint(equalTo: quickFilterMenuScrollView.contentLayoutGuide.topAnchor),
            quickFilterMenuContentStack.bottomAnchor.constraint(equalTo: quickFilterMenuScrollView.contentLayoutGuide.bottomAnchor),
            quickFilterMenuContentStack.widthAnchor.constraint(equalTo: quickFilterMenuScrollView.frameLayoutGuide.widthAnchor),

            quickFilterMenuQuickScrollView.heightAnchor.constraint(equalToConstant: 40),
            quickFilterMenuProjectScrollView.heightAnchor.constraint(equalToConstant: 40),
            quickFilterMenuAdvancedButton.heightAnchor.constraint(equalToConstant: 36),

            quickFilterMenuQuickStack.leadingAnchor.constraint(equalTo: quickFilterMenuQuickScrollView.contentLayoutGuide.leadingAnchor),
            quickFilterMenuQuickStack.trailingAnchor.constraint(equalTo: quickFilterMenuQuickScrollView.contentLayoutGuide.trailingAnchor),
            quickFilterMenuQuickStack.topAnchor.constraint(equalTo: quickFilterMenuQuickScrollView.contentLayoutGuide.topAnchor),
            quickFilterMenuQuickStack.bottomAnchor.constraint(equalTo: quickFilterMenuQuickScrollView.contentLayoutGuide.bottomAnchor),
            quickFilterMenuQuickStack.heightAnchor.constraint(equalTo: quickFilterMenuQuickScrollView.frameLayoutGuide.heightAnchor),

            quickFilterMenuProjectStack.leadingAnchor.constraint(equalTo: quickFilterMenuProjectScrollView.contentLayoutGuide.leadingAnchor),
            quickFilterMenuProjectStack.trailingAnchor.constraint(equalTo: quickFilterMenuProjectScrollView.contentLayoutGuide.trailingAnchor),
            quickFilterMenuProjectStack.topAnchor.constraint(equalTo: quickFilterMenuProjectScrollView.contentLayoutGuide.topAnchor),
            quickFilterMenuProjectStack.bottomAnchor.constraint(equalTo: quickFilterMenuProjectScrollView.contentLayoutGuide.bottomAnchor),
            quickFilterMenuProjectStack.heightAnchor.constraint(equalTo: quickFilterMenuProjectScrollView.frameLayoutGuide.heightAnchor)
        ])
    }
    
    func setupTableViewInForedrop() {
        setupTaskListViewInForedrop()
        print("HOME_UI_MODE setupTableViewInForedrop renderer=TaskListView")
    }

    func setupTaskListViewInForedrop() {
        let input = buildTaskListInput(for: currentViewType)
        print(
            "HOME_DATA mode=\(currentViewType) morning=\(input.morning.count) evening=\(input.evening.count) " +
            "overdue=\(input.overdue.count) done=\(input.doneTimeline.count) projects=\(input.projects.count)"
        )

        let listView = TaskListView(
            morningTasks: input.morning,
            eveningTasks: input.evening,
            overdueTasks: input.overdue,
            projects: input.projects,
            doneTimelineTasks: input.doneTimeline,
            activeQuickView: input.activeQuickView,
            emptyStateMessage: input.emptyStateMessage,
            emptyStateActionTitle: input.emptyStateActionTitle,
            onTaskTap: { [weak self] task in
                self?.handleRevampedTaskTap(task)
            },
            onToggleComplete: { [weak self] task in
                self?.handleRevampedTaskToggleComplete(task)
            },
            onDeleteTask: { [weak self] task in
                self?.handleRevampedTaskDelete(task)
            },
            onRescheduleTask: { [weak self] task in
                self?.handleRevampedTaskReschedule(task)
            },
            onEmptyStateAction: { [weak self] in
                self?.AddTaskAction()
            }
        )

        if let hostingController = taskListHostingController {
            hostingController.rootView = listView
            hostingController.view.isHidden = false
        } else {
            let hostingController = TransparentHostingController(rootView: listView)
            hostingController.view.backgroundColor = .clear
            hostingController.view.isOpaque = false
            taskListHostingController = hostingController

            addChild(hostingController)
            foredropContainer.addSubview(hostingController.view)
            hostingController.didMove(toParent: self)
        }

        fluentToDoTableViewController?.view.isHidden = true
        layoutForedropListViews()
        print("HOME_UI_MODE mounted renderer=TaskListView")
    }

    func refreshQuickFilterMenuContent() {
        guard let viewModel else { return }

        for view in quickFilterMenuQuickStack.arrangedSubviews {
            quickFilterMenuQuickStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for view in quickFilterMenuProjectStack.arrangedSubviews {
            quickFilterMenuProjectStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let activeState = viewModel.activeFilterState
        let counts = viewModel.quickViewCounts
        let systemViews = HomeQuickView.allCases
        toDoListHeaderLabel.text = activeState.quickView.title

        for quickView in systemViews {
            let count = counts[quickView] ?? 0
            let title = "\(quickView.title) \(count)"
            let button = makeFocusChip(
                title: title,
                selected: activeState.quickView == quickView,
                accessibilityID: "home.focus.quick.\(quickView.rawValue)"
            )
            button.addAction(UIAction { [weak self] _ in
                self?.viewModel?.setQuickView(quickView)
                self?.hideQuickFilterMenu(animated: true)
            }, for: .touchUpInside)
            quickFilterMenuQuickStack.addArrangedSubview(button)
        }

        let visibleSaved = Array(viewModel.savedHomeViews.prefix(6))
        for savedView in visibleSaved {
            let button = makeFocusChip(
                title: "• \(savedView.name)",
                selected: activeState.selectedSavedViewID == savedView.id,
                accessibilityID: "home.focus.saved.\(savedView.id.uuidString)"
            )
            button.addAction(UIAction { [weak self] _ in
                self?.viewModel?.applySavedView(id: savedView.id)
                self?.hideQuickFilterMenu(animated: true)
            }, for: .touchUpInside)
            quickFilterMenuQuickStack.addArrangedSubview(button)
        }

        let selectedProjectSet = Set(activeState.selectedProjectIDs)
        let pinnedProjects = viewModel.projects.filter { activeState.pinnedProjectIDSet.contains($0.id) }

        for project in pinnedProjects {
            let button = makeFocusChip(
                title: project.name,
                selected: selectedProjectSet.contains(project.id),
                accessibilityID: "home.focus.project.\(project.id.uuidString)"
            )
            button.addAction(UIAction { [weak self] _ in
                self?.viewModel?.toggleProjectFilter(project.id)
            }, for: .touchUpInside)
            quickFilterMenuProjectStack.addArrangedSubview(button)
        }

        let allProjectsButton = makeFocusChip(
            title: selectedProjectSet.isEmpty ? "All Projects ✓" : "All Projects",
            selected: selectedProjectSet.isEmpty,
            accessibilityID: "home.focus.project.all"
        )
        allProjectsButton.addAction(UIAction { [weak self] _ in
            self?.viewModel?.clearProjectFilters()
        }, for: .touchUpInside)
        quickFilterMenuProjectStack.addArrangedSubview(allProjectsButton)

        let moreButton = makeFocusChip(
            title: "More",
            selected: false,
            accessibilityID: "home.focus.project.more"
        )
        moreButton.addTarget(self, action: #selector(showProjectMultiSelectSheet), for: .touchUpInside)
        quickFilterMenuProjectStack.addArrangedSubview(moreButton)

        layoutForedropListViews()
    }

    func refreshFocusFilterRails() {
        refreshQuickFilterMenuContent()
    }

    private func makeFocusChip(title: String, selected: Bool, accessibilityID: String) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        button.layer.cornerRadius = 14
        button.layer.masksToBounds = true
        button.accessibilityIdentifier = accessibilityID

        if selected {
            button.backgroundColor = todoColors.accentPrimary
            button.setTitleColor(todoColors.accentOnPrimary, for: .normal)
        } else {
            button.backgroundColor = todoColors.surfaceSecondary
            button.setTitleColor(todoColors.textPrimary, for: .normal)
        }

        return button
    }

    @objc private func showProjectMultiSelectSheet() {
        guard let viewModel else { return }
        hideQuickFilterMenu(animated: true, announce: false)

        let alert = UIAlertController(
            title: "Project Filters",
            message: "Toggle projects to combine with your quick view",
            preferredStyle: .actionSheet
        )

        let selected = Set(viewModel.activeFilterState.selectedProjectIDs)
        for project in viewModel.projects.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let marker = selected.contains(project.id) ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(marker)\(project.name)", style: .default, handler: { [weak self] _ in
                self?.viewModel?.toggleProjectFilter(project.id)
                self?.showProjectMultiSelectSheet()
            }))
        }

        alert.addAction(UIAlertAction(title: "Clear Selection", style: .destructive, handler: { [weak self] _ in
            self?.viewModel?.clearProjectFilters()
        }))
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = homeTopBar
            popover.sourceRect = CGRect(x: homeTopBar.bounds.midX, y: homeTopBar.bounds.midY, width: 1, height: 1)
        }

        present(alert, animated: true)
    }

    @objc func toggleQuickFilterMenu() {
        if isQuickFilterMenuVisible {
            hideQuickFilterMenu(animated: true)
        } else {
            showQuickFilterMenu(animated: true)
        }
    }

    @objc private func handleQuickFilterMenuBackdropTap() {
        hideQuickFilterMenu(animated: true)
    }

    func showQuickFilterMenu(animated: Bool) {
        guard !isQuickFilterMenuVisible else { return }
        isQuickFilterMenuVisible = true
        refreshQuickFilterMenuContent()
        quickFilterMenuBackdrop.isHidden = false
        quickFilterMenuContainer.isHidden = false
        quickFilterMenuContainer.transform = CGAffineTransform(translationX: 0, y: -8)
        quickFilterMenuContainer.alpha = 0
        layoutForedropListViews()

        let updates = {
            self.quickFilterMenuBackdrop.alpha = 1
            self.quickFilterMenuContainer.alpha = 1
            self.quickFilterMenuContainer.transform = .identity
        }

        if animated {
            UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut], animations: updates)
        } else {
            updates()
        }

        UIAccessibility.post(notification: .announcement, argument: "Quick filters expanded")
    }

    func hideQuickFilterMenu(animated: Bool, announce: Bool = true) {
        guard isQuickFilterMenuVisible else { return }
        isQuickFilterMenuVisible = false

        let completion: (Bool) -> Void = { _ in
            self.quickFilterMenuBackdrop.isHidden = true
            self.quickFilterMenuContainer.isHidden = true
            self.quickFilterMenuContainer.transform = .identity
        }

        let updates = {
            self.quickFilterMenuBackdrop.alpha = 0
            self.quickFilterMenuContainer.alpha = 0
            self.quickFilterMenuContainer.transform = CGAffineTransform(translationX: 0, y: -8)
        }

        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseIn], animations: updates, completion: completion)
        } else {
            updates()
            completion(true)
        }

        if announce {
            UIAccessibility.post(notification: .announcement, argument: "Quick filters collapsed")
        }
    }

    @objc private func openAdvancedFiltersFromMenu() {
        hideQuickFilterMenu(animated: true, announce: false)
        showAdvancedFilterSheet()
    }

    @objc func showAdvancedFilterSheet() {
        guard let viewModel else { return }
        hideQuickFilterMenu(animated: false, announce: false)

        let sheet = HomeAdvancedFilterSheetView(
            initialFilter: viewModel.activeFilterState.advancedFilter,
            initialShowCompletedInline: viewModel.activeFilterState.showCompletedInline,
            savedViews: viewModel.savedHomeViews,
            activeSavedViewID: viewModel.activeFilterState.selectedSavedViewID,
            onApply: { [weak self] filter, showCompletedInline in
                self?.viewModel?.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
            },
            onClear: { [weak self] in
                self?.viewModel?.applyAdvancedFilter(nil, showCompletedInline: false)
                self?.viewModel?.clearProjectFilters()
                self?.viewModel?.setQuickView(.today)
            },
            onSaveNamedView: { [weak self] filter, showCompletedInline, name in
                self?.viewModel?.applyAdvancedFilter(filter, showCompletedInline: showCompletedInline)
                self?.viewModel?.saveCurrentFilterAsView(name: name)
            },
            onApplySavedView: { [weak self] id in
                self?.viewModel?.applySavedView(id: id)
            },
            onDeleteSavedView: { [weak self] id in
                self?.viewModel?.deleteSavedView(id: id)
            }
        )

        let hosting = UIHostingController(rootView: sheet)
        hosting.modalPresentationStyle = .formSheet
        present(hosting, animated: true)
    }
    
    
    func createButton(title: String, action: Selector) -> FluentUI.Button {
        let button = FluentUI.Button()
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body) // Plan Step C: Replaced todoFont
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.numberOfLines = 0
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    func fitViewIntoSuperview(_ view: UIView, margins: UIEdgeInsets) {
        guard let superview = view.superview else {
            return
        }
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: superview.topAnchor, constant: margins.top),
            view.leftAnchor.constraint(equalTo: superview.leftAnchor, constant: margins.left),
            view.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -margins.bottom),
            view.rightAnchor.constraint(equalTo: superview.rightAnchor, constant: -margins.right)
        ])
    }
    
    func createBadge(text: String, labelStyle: BadgeView.Style = .default, size: BadgeView.SizeCategory = .medium, isEnabled: Bool = true) -> BadgeView { // Plan Step E: Updated signature
        let dataSource = BadgeViewDataSource(
            text: text,
            style: labelStyle,
            sizeCategory: size
        )
        let badge = BadgeView(dataSource: dataSource)
        badge.isActive = isEnabled
        if isEnabled {
            badge.delegate = self
        }
        return badge
    }
    
    // MARK: - Badge Setup
    
    func setupBadgeCount() {
        // Badge count setup implementation
        notificationBadgeNumber = getTaskForTodayCount()
        
        if UIApplication.shared.delegate is AppDelegate {
            let badgeCount = self.todoTimeUtils.isNightTime(date: Date()) ? 0 : getTaskForTodayCount()
            setApplicationBadgeCount(badgeCount)
            
            UIApplication.shared.registerForRemoteNotifications() // Plan Step G
        }
    }

    private func setApplicationBadgeCount(_ count: Int) {
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error {
                    print("⚠️ Failed to set badge count: \(error)")
                }
            }
        } else {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    // MARK: - App Lifecycle
    
    @objc
    func appMovedToForeground() {
        print("App moved to ForeGround!")
        // toDoAnimations.animateTinyPieChartAtHome(pieChartView: tinyPieChartView) - REMOVED

        // Phase 7: Update horizontal chart cards
        updateChartCardsScrollView()
        updateHomeDateLabel(date: dateForTheView)
        
        if dateForTheView == Date.today() {
            print("###### Today !")
        }
    }
    
    @objc
    func appMovedToBackground() {
        print("App moved to Background!")
        // Perform any background tasks here
    }
    
    @objc
    func appTerminated() {
        print("App is terminating!")
        // Save state or perform cleanup before termination
    }
    
    // MARK: - Calendar and Charts Toggles
    
    @objc func toggleCalendar() {
        // Use new state manager if available, otherwise fall back to legacy behavior
        if let stateManager = foredropStateManager {
            stateManager.toggleCalendar()
            
            // Update legacy flags for backward compatibility
            isCalDown = stateManager.isCalendarVisible && !stateManager.isChartsVisible
            isChartsDown = stateManager.isChartsVisible
            
            // Optionally adjust calendar scope based on state
            if stateManager.isCalendarVisible {
                calendar.setScope(.week, animated: true)
            }
        } else {
            // Legacy behavior (fallback)
            if isChartsDown {
                // Charts are down, need two-step animation: return to original then show calendar
                returnToOriginalThenRevealCalendar()
            } else if isCalDown {
                // Calendar is currently showing (monthly) - hide it and switch to weekly
                // Reset calendar to week scope BEFORE hiding animation
                calendar.setScope(.week, animated: true)
                // Hide calendar (foredrop goes up)
                UIView.animate(withDuration: 0.2) {
                    self.moveUp_toHideCal(view: self.foredropContainer)
                }
            } else {
                // Calendar is currently hidden - show it in monthly view
                // Show calendar (foredrop goes down)
                UIView.animate(withDuration: 0.2) {
                    self.moveDown_revealJustCal(view: self.foredropContainer)
                }
                // Expand calendar to month scope when showing
                calendar.setScope(.week, animated: true)
            }
        }
    }
    
    @objc func toggleCharts() {
        // Use new state manager if available, otherwise fall back to legacy behavior
        if let stateManager = foredropStateManager {
            stateManager.toggleCharts()
            
            // Update legacy flags for backward compatibility
            isCalDown = stateManager.isCalendarVisible && !stateManager.isChartsVisible
            isChartsDown = stateManager.isChartsVisible
        } else {
            // Legacy behavior (fallback)
            if isCalDown {
                // Calendar is down, need two-step animation: return to original then show charts
                returnToOriginalThenRevealCharts()
            } else if isChartsDown {
                // Hide charts
                UIView.animate(withDuration: 0.3) {
                    self.moveUp_hideCharts(view: self.foredropContainer)
                }
            } else {
                // Show charts
                UIView.animate(withDuration: 0.3) {
                    self.moveDown_revealCharts(view: self.foredropContainer)
                }
                
            }
        }
    }
    
    func setupSampleTableView(for date: Date = Date.today()) {
        print("HOME_LEGACY_GUARD setupSampleTableView_called date=\(date)")
        refreshHomeTaskList(reason: "legacyGuard.setupSampleTableView")
    }

    func layoutForedropListViews() {
        // Keep title bar fully visible and list content separated from it.
        homeTopBar.frame = CGRect(
            x: 0,
            y: 0,
            width: foredropContainer.bounds.width,
            height: homeTopBarHeight
        )

        homeTitleRow.frame = CGRect(
            x: 16,
            y: 4,
            width: max(0, homeTopBar.bounds.width - 32),
            height: 28
        )

        toDoListHeaderLabel.frame = CGRect(
            x: 0,
            y: 0,
            width: max(0, homeTitleRow.bounds.width - 168),
            height: homeTitleRow.bounds.height
        )

        focusPotentialLabel.frame = CGRect(
            x: max(0, homeTitleRow.bounds.width - 196),
            y: 0,
            width: 160,
            height: homeTitleRow.bounds.height
        )

        homeAdvancedFilterButton.frame = CGRect(
            x: max(0, homeTitleRow.bounds.width - 28),
            y: 2,
            width: 24,
            height: 24
        )

        let menuTopY = homeTopBar.frame.maxY + 6
        let menuHorizontalInset: CGFloat = 12
        let menuWidth = max(0, homeTopBar.bounds.width - (menuHorizontalInset * 2))
        let menuHeight = min(max(196, quickFilterMenuContentStack.systemLayoutSizeFitting(
            CGSize(width: menuWidth - 24, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height + 24), max(220, foredropContainer.bounds.height * 0.5))

        quickFilterMenuBackdrop.frame = CGRect(
            x: 0,
            y: homeTopBar.frame.maxY,
            width: foredropContainer.bounds.width,
            height: max(0, foredropContainer.bounds.height - homeTopBar.frame.maxY)
        )

        quickFilterMenuContainer.frame = CGRect(
            x: menuHorizontalInset,
            y: menuTopY,
            width: menuWidth,
            height: menuHeight
        )

        quickFilterMenuQuickStack.layoutIfNeeded()
        quickFilterMenuQuickScrollView.contentSize = CGSize(
            width: quickFilterMenuQuickStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width,
            height: quickFilterMenuQuickScrollView.bounds.height
        )

        quickFilterMenuProjectStack.layoutIfNeeded()
        quickFilterMenuProjectScrollView.contentSize = CGSize(
            width: quickFilterMenuProjectStack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width,
            height: quickFilterMenuProjectScrollView.bounds.height
        )

        let tableOriginY = homeTopBar.frame.maxY + tableTopSpacing
        let availableHeight = max(0, foredropContainer.bounds.height - tableOriginY)
        let listFrame = CGRect(
            x: 0,
            y: tableOriginY,
            width: foredropContainer.bounds.width,
            height: availableHeight
        )

        taskListHostingController?.view.frame = listFrame
        taskListHostingController?.view.isHidden = false
        fluentToDoTableViewController?.view.isHidden = true

        // Keep the title bar above section headers.
        if let hostingView = taskListHostingController?.view, hostingView.superview === foredropContainer {
            foredropContainer.bringSubviewToFront(hostingView)
        }
        if quickFilterMenuBackdrop.superview === foredropContainer {
            foredropContainer.bringSubviewToFront(quickFilterMenuBackdrop)
        }
        if quickFilterMenuContainer.superview === foredropContainer {
            foredropContainer.bringSubviewToFront(quickFilterMenuContainer)
        }
        if homeTopBar.superview === foredropContainer {
            foredropContainer.bringSubviewToFront(homeTopBar)
        }

        if !isQuickFilterMenuVisible {
            quickFilterMenuBackdrop.alpha = 0
            quickFilterMenuBackdrop.isHidden = true
            quickFilterMenuContainer.alpha = 0
            quickFilterMenuContainer.isHidden = true
            quickFilterMenuContainer.transform = .identity
        }
    }
    
    func setupForedropBackground() {
        // Setup the foredrop background image view
        backdropForeImageView.frame = CGRect(x: 0, y: 0, width: foredropContainer.bounds.width, height: foredropContainer.bounds.height)
        backdropForeImageView.image = backdropForeImage?.withRenderingMode(.alwaysTemplate)
        backdropForeImageView.backgroundColor = .clear
        
        // Add subtle tokenized separation
        backdropForeImageView.applyTaskerElevation(.e1)
        
        // Add the foredrop background to the container (behind the table view)
        foredropContainer.addSubview(backdropForeImageView)
        foredropContainer.sendSubviewToBack(backdropForeImageView)
    }
    
    func getPriorityIcon(for priority: Int) -> String {
        switch TaskPriority(rawValue: Int32(priority)) {
        case .max: return "🔴"
        case .high: return "🟠"
        case .low: return "🟢"
        case .none: return "⚪"
        }
    }
    
    func refreshSampleTableView(for date: Date) {
        print("HOME_LEGACY_GUARD refreshSampleTableView_called date=\(date)")
        refreshHomeTaskList(reason: "legacyGuard.refreshSampleTableView")
    }
    
    // MARK: - Two-Step Animation Helper Functions
    
    private func returnToOriginalThenRevealCalendar() {
        // First animation: Hide charts and return to original position
        UIView.animate(withDuration: 0.2, animations: {
            self.moveUp_hideCharts(view: self.foredropContainer)
        }) { _ in
            // Second animation: Show calendar
            UIView.animate(withDuration: 0.2) {
                self.moveDown_revealJustCal(view: self.foredropContainer)
            }
            // Expand calendar to week scope when showing
            self.calendar.setScope(.week, animated: true)
        }
    }
    
    private func returnToOriginalThenRevealCharts() {
        // First animation: Hide calendar and return to original position
        self.calendar.setScope(.week, animated: true)
        UIView.animate(withDuration: 0.2, animations: {
            self.moveUp_toHideCal(view: self.foredropContainer)
        }) { _ in
            // Second animation: Show charts
            UIView.animate(withDuration: 0.3) {
                self.moveDown_revealCharts(view: self.foredropContainer)
            }
            // Animate the chart axes when showing charts
            self.animateLineChart(chartView: self.lineChartView)
        }
    }
}
