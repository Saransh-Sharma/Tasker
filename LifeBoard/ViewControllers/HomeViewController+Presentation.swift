//
//  HomeViewController+Presentation.swift
//  LifeBoard
//
//  Move-only HomeViewController decomposition.
//

import UIKit
import SwiftUI
@preconcurrency import Combine
import SwiftData


extension HomeViewController {
    // MARK: - Navigation Actions

    /// Executes onMenuButtonTapped.
    @objc func onMenuButtonTapped() {
        let settingsVC = SettingsPageViewController()
        settingsVC.presentationDependencyContainer = presentationDependencyContainer
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.navigationBar.prefersLargeTitles = false
        navController.modalPresentationStyle = .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(navController, animated: true)
    }

    /// Executes AddTaskAction.
    @objc func AddTaskAction() {
        presentAddTaskFlow(suggestedDate: nil)
    }

    func presentAddTaskFlow(suggestedDate: Date?) {
        if isUsingIPadNativeShell,
           currentLayoutClass == .padExpanded,
           suggestedDate == nil {
            iPadShellState.destination = .addTask
            return
        }

        if isUsingIPadNativeShell {
            presentAddTaskSheetForPadFallback(suggestedDate: suggestedDate)
            return
        }

        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        let vm = presentationDependencyContainer.makeNewAddTaskViewModel()
        applyTimelineSuggestedDate(suggestedDate, to: vm)
        let sheet = SunriseAddTaskSheetView(viewModel: vm)
        let hostingVC = UIHostingController(rootView: sheet)
        hostingVC.modalPresentationStyle = .pageSheet
        if let sheetController = hostingVC.sheetPresentationController {
            sheetController.detents = [.medium(), .large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        let interval = LifeBoardPerformanceTrace.begin("AddTaskSheetOpen")
        present(hostingVC, animated: true) {
            LifeBoardPerformanceTrace.end(interval)
        }
    }

    func presentAddTaskSheetForPadFallback(suggestedDate: Date? = nil) {
        guard isUsingIPadNativeShell else {
            presentAddTaskFlow(suggestedDate: suggestedDate)
            return
        }
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        let vm = presentationDependencyContainer.makeNewAddTaskViewModel()
        applyTimelineSuggestedDate(suggestedDate, to: vm)
        let sheet = SunriseAddTaskSheetView(viewModel: vm)
        let hostingVC = UIHostingController(rootView: sheet.lifeboardLayoutClass(currentLayoutClass))
        hostingVC.modalPresentationStyle = .formSheet
        hostingVC.preferredContentSize = CGSize(width: 540, height: 620)
        if let sheetController = hostingVC.sheetPresentationController {
            sheetController.detents = [.large()]
            sheetController.prefersGrabberVisible = true
            sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        viewModel?.trackHomeInteraction(
            action: "ipad_fallback_sheet_presented",
            metadata: [
                "layout_class": currentLayoutClass.rawValue,
                "surface": "add_task"
            ]
        )
        let interval = LifeBoardPerformanceTrace.begin("AddTaskSheetOpen")
        present(hostingVC, animated: true) {
            LifeBoardPerformanceTrace.end(interval)
        }
    }

    func applyTimelineSuggestedDate(_ suggestedDate: Date?, to viewModel: AddTaskViewModel) {
        guard let suggestedDate else { return }
        viewModel.applyPrefill(
            AddTaskPrefillTemplate(
                title: "",
                dueDateIntent: .exact(suggestedDate),
                expandedSections: [.schedule],
                showMoreDetails: true
            )
        )
    }

    @objc func openProjectCreator() {
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }
        if isUsingIPadNativeShell {
            iPadShellState.destination = .projects
            return
        }

        let viewModel = presentationDependencyContainer.makeProjectManagementViewModel()
        let rootView = SunriseProjectManagementView(viewModel: viewModel)
            .lifeboardLayoutClass(currentLayoutClass)
        let controller = UIHostingController(rootView: rootView)
        controller.title = "Projects"

        let navController = UINavigationController(rootViewController: controller)
        navController.navigationBar.prefersLargeTitles = false
        navController.modalPresentationStyle = currentLayoutClass.isPad ? .formSheet : .pageSheet
        if let sheet = navController.sheetPresentationController {
            sheet.detents = currentLayoutClass.isPad ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(navController, animated: true)
    }

    @MainActor
    func presentWeeklyPlanner() {
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }

        let weeklySummary = viewModel?.weeklySummary
        let referenceDate = weeklySummary?.weekStartDate ?? Date()
        let plannerPresentation = weeklySummary?.plannerPresentation ?? .thisWeek

        let plannerView = SunriseWeeklyPlannerView(
            viewModel: presentationDependencyContainer.makeWeeklyPlannerViewModel(
                referenceDate: referenceDate,
                plannerPresentation: plannerPresentation
            ),
            onClose: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        .lifeboardLayoutClass(currentLayoutClass)

        let hostingController = UIHostingController(rootView: plannerView)
        hostingController.modalPresentationStyle = currentLayoutClass.isPad ? .formSheet : .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = currentLayoutClass.isPad ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(hostingController, animated: true)
    }

    @MainActor
    func presentWeeklyReview() {
        guard let presentationDependencyContainer else {
            fatalError("HomeViewController missing PresentationDependencyContainer")
        }

        let referenceDate = viewModel?.weeklySummary?.weekStartDate ?? Date()

        let reviewView = SunriseWeeklyReviewView(
            viewModel: presentationDependencyContainer.makeWeeklyReviewViewModel(referenceDate: referenceDate),
            onClose: { [weak self] in
                self?.dismiss(animated: true)
            },
            onCompleted: { [weak self] message in
                self?.dismiss(animated: true) {
                    self?.viewModel?.refreshAfterWeeklyReviewCompletion()
                    self?.showHomeSnackbar(message: message)
                }
            }
        )
        .lifeboardLayoutClass(currentLayoutClass)

        let hostingController = UIHostingController(rootView: reviewView)
        hostingController.modalPresentationStyle = currentLayoutClass.isPad ? .formSheet : .pageSheet
        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = currentLayoutClass.isPad ? [.large()] : [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        present(hostingController, animated: true)
    }

    /// Executes searchButtonTapped.
    @objc func searchButtonTapped() {
        let presentSearch = { [weak self] in
            guard let self else { return }
            self.openSearch(source: "navigation_search_button")
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .search
            }
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                presentSearch()
            }
        } else {
            presentSearch()
        }
    }

    /// Executes chatButtonTapped.
    @objc func chatButtonTapped() {
        presentEvaChatScreen(source: "sunrise_chat_button")
    }

    func resetHomeSelectionAfterEvaChatDismissalIfNeeded() {
        guard shouldResetHomeAfterEvaChatDismissal else { return }
        guard presentedViewController == nil else { return }
        resetHomeSelectionAfterEvaChatDismissal()
    }

    func resetHomeSelectionAfterEvaChatDismissal() {
        shouldResetHomeAfterEvaChatDismissal = false
        presentedEvaChatController = nil
        faceCoordinator.setActiveFace(.tasks)
        faceCoordinator.bottomBarState.select(.home)
    }

    func performEmbeddedChatDayTaskAction(
        _ action: EvaDayTaskAction,
        card: EvaDayTaskCard,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        guard let viewModel else {
            completion(.failure(embeddedChatError(code: 1, message: "Home view model unavailable")))
            return
        }

        switch action {
        case .done:
            viewModel.setTaskCompletion(taskID: card.taskID, to: true) { result in
                completion(result.map { _ in })
            }
        case .reopen:
            viewModel.setTaskCompletion(taskID: card.taskID, to: false) { result in
                completion(result.map { _ in })
            }
        case .tomorrow:
            let calendar = Calendar.current
            let baseDay = calendar.startOfDay(for: Date())
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: baseDay) else {
                completion(.failure(embeddedChatError(code: 2, message: "Could not compute tomorrow")))
                return
            }
            viewModel.rescheduleTask(taskID: card.taskID, to: tomorrow) { result in
                completion(result.map { _ in })
            }
        case .open:
            handleTaskTap(card.taskSnapshot)
            completion(.success(()))
        }
    }

    func performEmbeddedChatDayHabitAction(
        _ action: EvaDayHabitAction,
        card: EvaDayHabitCard,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        if action == .open {
            handleHabitDetailDeepLink(habitID: card.habitID)
            completion(.success(()))
            return
        }

        guard let coordinator = presentationDependencyContainer?.coordinator else {
            completion(.failure(embeddedChatError(code: 3, message: "Coordinator unavailable")))
            return
        }

        let habitAction: HabitOccurrenceAction
        switch action {
        case .done:
            habitAction = .complete
        case .skip:
            habitAction = .skip
        case .stayedClean:
            habitAction = .abstained
        case .lapsed, .logLapse:
            habitAction = .lapsed
        case .open:
            handleHabitDetailDeepLink(habitID: card.habitID)
            completion(.success(()))
            return
        }

        coordinator.resolveHabitOccurrence.execute(
            habitID: card.habitID,
            action: habitAction,
            on: card.dueAt ?? Date()
        ) { [weak self] result in
            Task { @MainActor in
                if case .success = result {
                    self?.viewModel?.refreshCurrentScopeContent(source: "eva_chat_habit_action")
                }
                completion(result)
            }
        }
    }

    func embeddedChatError(code: Int, message: String) -> NSError {
        NSError(
            domain: "HomeEmbeddedEvaChat",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    // MARK: - Task Routing

    /// Executes handleTaskTap.
    func handleTaskTap(_ task: TaskDefinition) {
        if isUsingIPadNativeShell, currentLayoutClass == .padExpanded {
            iPadShellState.selectedTask = task
            return
        }
        presentTaskDetailView(for: task)
    }

    /// Executes handleTaskReschedule.
    func handleTaskReschedule(_ task: TaskDefinition) {
        let rescheduleVC = RescheduleViewController(
            taskTitle: task.title,
            currentDueDate: task.dueDate
        ) { [weak self] (selectedDate: Date) in
            guard let self else { return }
            self.viewModel?.rescheduleTask(task, to: selectedDate)
        }

        let navController = UINavigationController(rootViewController: rescheduleVC)
        present(navController, animated: true)
    }

    /// Executes handleTaskDeleteRequested.
    func handleTaskDeleteRequested(_ task: TaskDefinition) {
        guard let viewModel else { return }
        guard task.recurrenceSeriesID != nil else {
            viewModel.deleteTask(taskID: task.id) { _ in }
            return
        }

        presentRecurringTaskDeleteConfirmation(
            taskTitle: task.title,
            onDeleteSingle: { [viewModel] in
                viewModel.deleteTask(taskID: task.id, scope: .single) { _ in }
            },
            onDeleteSeries: { [viewModel] in
                viewModel.deleteTask(taskID: task.id, scope: .series) { _ in }
            }
        )
    }

    func presentRecurringTaskDeleteConfirmation(
        taskTitle: String,
        onDeleteSingle: @escaping () -> Void,
        onDeleteSeries: @escaping () -> Void
    ) {
        let confirmationView = SunriseRecurringTaskDeleteConfirmationView(
            taskTitle: taskTitle,
            onDeleteSingle: onDeleteSingle,
            onDeleteSeries: onDeleteSeries
        )
        .lifeboardLayoutClass(currentLayoutClass)

        let hostingController = UIHostingController(rootView: confirmationView)
        hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
        }

        present(hostingController, animated: true)
    }

    func presentTimelineAnchorDetail(for anchor: TimelineAnchorItem) {
        guard let selection = TimelineAnchorSelection(anchorID: anchor.id) else { return }
        viewModel?.trackHomeInteraction(
            action: "home_timeline_anchor_edit_opened",
            metadata: ["anchor": selection.rawValue, "layout_class": currentLayoutClass.rawValue]
        )

        let detailView = TimelineAnchorDetailSheetView(selection: selection)
        let hostingController = UIHostingController(rootView: detailView.lifeboardLayoutClass(currentLayoutClass))
        hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas

        if isUsingIPadNativeShell {
            hostingController.modalPresentationStyle = .formSheet
            hostingController.preferredContentSize = CGSize(width: 540, height: 520)
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            }
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }

        present(hostingController, animated: true)
    }

    /// Executes presentTaskDetailView.
    func presentTaskDetailView(for task: TaskDefinition) {
        let detailView = makeTaskDetailView(for: task, containerMode: .sheet)

        let hostingController = UIHostingController(rootView: detailView.lifeboardLayoutClass(currentLayoutClass))
        hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        if isUsingIPadNativeShell {
            switch currentLayoutClass {
            case .padCompact:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                viewModel?.trackHomeInteraction(
                    action: "ipad_task_detail_fallback_formsheet",
                    metadata: ["layout_class": currentLayoutClass.rawValue]
                )
                viewModel?.trackHomeInteraction(
                    action: "ipad_fallback_sheet_presented",
                    metadata: ["layout_class": currentLayoutClass.rawValue, "surface": "task_detail_formsheet"]
                )
            case .padRegular:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }
                viewModel?.trackHomeInteraction(
                    action: "ipad_task_detail_fallback_formsheet",
                    metadata: ["layout_class": currentLayoutClass.rawValue]
                )
                viewModel?.trackHomeInteraction(
                    action: "ipad_fallback_sheet_presented",
                    metadata: ["layout_class": currentLayoutClass.rawValue, "surface": "task_detail_formsheet"]
                )
            case .padExpanded:
                hostingController.modalPresentationStyle = .formSheet
                hostingController.preferredContentSize = CGSize(width: 540, height: 680)
                if let sheet = hostingController.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                    sheet.prefersScrollingExpandsWhenScrolledToEdge = false
                }
            case .phone:
                hostingController.modalPresentationStyle = .pageSheet
            }
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }
        }

        let interval = LifeBoardPerformanceTrace.begin("TaskDetailOpen")
        present(hostingController, animated: true) {
            LifeBoardPerformanceTrace.end(interval)
        }
    }

    /// Executes makeTaskDetailView.
    func makeTaskDetailView(
        for task: TaskDefinition,
        containerMode: TaskDetailContainerMode
    ) -> SunriseTaskDetailScreen {
        SunriseTaskDetailScreen(
            task: task,
            projects: viewModel?.projects ?? [],
            todayXPSoFar: {
                guard let viewModel else { return nil }
                return viewModel.progressState.earnedXP
            }(),
            isGamificationV2Enabled: V2FeatureFlags.gamificationV2Enabled,
            containerMode: containerMode,
            onUpdate: { [weak self] taskID, request, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.updateTask(taskID: taskID, request: request) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onSetCompletion: { [weak self] taskID, isComplete, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.setTaskCompletion(taskID: taskID, to: isComplete) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onDelete: { [weak self] taskID, scope, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.deleteTask(taskID: taskID, scope: scope) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onReschedule: { [weak self] taskID, date, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.rescheduleTask(taskID: taskID, to: date) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onLoadMetadata: { [weak self] projectID, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.loadTaskDetailMetadata(projectID: projectID) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onLoadRelationshipMetadata: { [weak self] projectID, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 9,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.loadTaskDetailRelationshipMetadata(projectID: projectID) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onLoadChildren: { [weak self] parentTaskID, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 6,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.loadTaskChildren(parentTaskID: parentTaskID) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onCreateTask: { [weak self] request, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 7,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.createTaskDefinition(request: request) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onCreateTag: { [weak self] name, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 8,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.createTagForTaskDetail(name: name) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onCreateProject: { [weak self] name, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 9,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.createProjectForTaskDetail(name: name) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onSaveReflectionNote: { [weak self] note, completion in
                guard let self, let viewModel = self.viewModel else {
                    completion(.failure(NSError(
                        domain: "HomeViewController",
                        code: 10,
                        userInfo: [NSLocalizedDescriptionKey: "HomeViewModel unavailable"]
                    )))
                    return
                }
                viewModel.saveReflectionNote(note) { result in
                    Task { @MainActor in completion(result) }
                }
            },
            onLoadTaskFitHint: { [weak self] task, completion in
                Task { @MainActor [weak self] in
                    guard let self, let service = self.presentationDependencyContainer?.coordinator.calendarIntegrationService else {
                        completion(.unknown)
                        return
                    }
                    completion(service.taskFitHint(for: task))
                }
            }
        )
    }

    func presentCalendarChooser() {
        guard let service = presentationDependencyContainer?.coordinator.calendarIntegrationService else { return }
        let chooser = EventKitCalendarChooserContainerView(
            service: service,
            initialSelectedCalendarIDs: service.snapshot.selectedCalendarIDs,
            onCommit: { selectedIDs in
                service.updateSelectedCalendarIDs(selectedIDs)
            }
        )
        let host = UIHostingController(rootView: AnyView(chooser.lifeboardLayoutClass(currentLayoutClass)))
        host.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        host.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        if let sheet = host.sheetPresentationController {
            let detents: [UISheetPresentationController.Detent] = [.medium(), .large()]
            sheet.detents = detents
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
        }
        present(host, animated: true)
    }

    func presentCalendarSchedule() {
        if isUsingIPadNativeShell {
            unwindActiveFaceForIPadDestination(source: "calendar_schedule_modal")
            iPadShellState.destination = .schedule
            return
        }
        guard let service = presentationDependencyContainer?.coordinator.calendarIntegrationService else { return }
        let view = SunriseScheduleScreen(
            service: service,
            weekStartsOn: service.weekStartsOn,
            presentationMode: .modal,
            selectedDate: calendarScheduleSelectedDateBinding()
        )
        let host = UIHostingController(rootView: AnyView(view.lifeboardLayoutClass(currentLayoutClass)))
        host.modalPresentationStyle = currentLayoutClass.isPad
            ? UIModalPresentationStyle.pageSheet
            : UIModalPresentationStyle.fullScreen
        host.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
        if currentLayoutClass.isPad, let sheet = host.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
        }
        presentedCalendarScheduleController = host
        host.presentationController?.delegate = self
        present(host, animated: true)
    }

    func handleFocusDeepLink() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        let preferredTask = viewModel?.focusTasks.first
            ?? viewModel?.morningTasks.first(where: { !$0.isComplete })
            ?? viewModel?.eveningTasks.first(where: { !$0.isComplete })
        startFocusFlow(task: preferredTask, source: "deeplink")
    }

    func handleChatDeepLink(prompt: String?) {
        let launchRequest = EvaChatLaunchRequest(prompt: prompt)
        do {
            try EvaChatLaunchRequestStore.shared.submit(launchRequest)
        } catch {
            logError(
                event: "shortcut_chat_launch_request_store_failed",
                message: "Failed to persist Eva chat launch request",
                fields: [
                    "error": error.localizedDescription
                ]
            )
        }

        routeToChatSurface()
    }

    func routeToChatSurface() {
        if isUsingIPadNativeShell {
            let routeToChat = { [weak self] in
                self?.iPadShellState.destination = .chat
            }

            if presentedViewController != nil {
                dismiss(animated: true) {
                    routeToChat()
                }
                return
            }

            routeToChat()
            return
        }

        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.presentEvaChatScreen(source: "deeplink_chat")
            }
            return
        }

        presentEvaChatScreen(source: "deeplink_chat")
    }

    func consumePendingShortcutHandoffIfNeeded() {
        if let action = PendingShortcutLaunchActionStore.shared.consumePendingAction() {
            handlePendingShortcutLaunchAction(action)
        }
        if let signal = ShortcutMutationSignalStore.shared.consumePendingSignal() {
            handlePendingShortcutMutationSignal(signal)
        }
    }

    func handlePendingShortcutLaunchAction(_ action: PendingShortcutLaunchAction) {
        switch action.kind {
        case .askEva:
            handleChatDeepLink(prompt: action.prompt)
        case .startFocus:
            handleFocusDeepLink()
        }
    }

    func handlePendingShortcutMutationSignal(_ signal: ShortcutMutationSignal) {
        switch signal.kind {
        case .taskCreated:
            faceCoordinator.recordSearchMutation()
            viewModel?.handleExternalMutation(reason: .created)
        }
    }

    func handleHomeDeepLink(notice: String? = nil) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        viewModel?.setQuickView(.today)
        if let notice, notice.isEmpty == false {
            showHomeSnackbar(message: notice)
        }
    }

    func handleInsightsDeepLink() {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .analytics
        }
        viewModel?.launchInsights(.default)
    }

    func handleTaskScopeDeepLink(scope: String, projectID: UUID?) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        switch scope {
        case "upcoming":
            viewModel?.clearProjectFilters()
            viewModel?.setQuickView(.upcoming)
        case "overdue":
            viewModel?.clearProjectFilters()
            viewModel?.setQuickView(.overdue)
        case "project":
            guard let projectID else {
                viewModel?.clearProjectFilters()
                viewModel?.setQuickView(.today)
                return
            }
            viewModel?.setQuickView(.today)
            viewModel?.setProjectFilters([projectID])
        default:
            viewModel?.clearProjectFilters()
            viewModel?.setQuickView(.today)
        }
    }

    func handleTaskDetailDeepLink(taskID: UUID) {
        viewModel?.setQuickView(.today)
        pendingNotificationFocusTaskID = taskID
        resolveAndPresentTaskDetail(taskID: taskID)
    }

    func handleHabitBoardDeepLink() {
        routeToHabitDeepLinkDestination {
            NotificationCenter.default.post(name: .lifeboardPresentHabitBoard, object: nil)
        }
    }

    func handleHabitLibraryDeepLink() {
        routeToHabitDeepLinkDestination {
            NotificationCenter.default.post(name: .lifeboardPresentHabitLibrary, object: nil)
        }
    }

    func handleHabitDetailDeepLink(habitID: UUID) {
        routeToHabitDeepLinkDestination {
            NotificationCenter.default.post(
                name: .lifeboardPresentHabitDetail,
                object: nil,
                userInfo: ["habitID": habitID.uuidString]
            )
        }
    }

    func routeToHabitDeepLinkDestination(_ completion: @escaping () -> Void) {
        if isUsingIPadNativeShell {
            iPadShellState.destination = .tasks
        }
        viewModel?.setQuickView(.today)

        if presentedViewController != nil {
            dismiss(animated: true) {
                Task { @MainActor in
                    completion()
                }
            }
            return
        }

        Task { @MainActor in
            completion()
        }
    }

    func handleQuickAddDeepLink() {
        if isUsingIPadNativeShell {
            if presentedViewController != nil {
                dismiss(animated: true) { [weak self] in
                    guard let self else { return }
                    if self.currentLayoutClass == .padExpanded {
                        self.iPadShellState.destination = .addTask
                    } else {
                        self.presentAddTaskSheetForPadFallback()
                    }
                }
                return
            }
            if currentLayoutClass == .padExpanded {
                iPadShellState.destination = .addTask
            } else {
                presentAddTaskSheetForPadFallback()
            }
            return
        }
        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.AddTaskAction()
            }
            return
        }
        AddTaskAction()
    }

    func handleCalendarScheduleDeepLink() {
        if isUsingIPadNativeShell {
            let routeToSchedule = { [weak self] in
                self?.iPadShellState.destination = .schedule
            }
            if presentedViewController != nil {
                dismiss(animated: true) {
                    routeToSchedule()
                }
                return
            }
            routeToSchedule()
            return
        }

        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.openSchedule(source: "deeplink_schedule")
            }
            return
        }
        openSchedule(source: "deeplink_schedule")
    }

    func handleCalendarChooserDeepLink() {
        let openChooser = { [weak self] in
            guard let self else { return }
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .schedule
            }
            self.presentCalendarChooser()
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                openChooser()
            }
            return
        }
        openChooser()
    }

    func handleWeeklyPlannerDeepLink() {
        let openPlanner = { [weak self] in
            guard let self else { return }
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .tasks
            }
            self.viewModel?.setQuickView(.today)
            self.presentWeeklyPlanner()
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                openPlanner()
            }
            return
        }

        openPlanner()
    }

    func handleWeeklyReviewDeepLink() {
        let openReview = { [weak self] in
            guard let self else { return }
            if self.isUsingIPadNativeShell {
                self.iPadShellState.destination = .tasks
            }
            self.viewModel?.setQuickView(.today)
            self.presentWeeklyReview()
        }

        if presentedViewController != nil {
            dismiss(animated: true) {
                openReview()
            }
            return
        }

        openReview()
    }

    func processPendingWidgetActionCommand() {
        guard V2FeatureFlags.interactiveTaskWidgetsEnabled else { return }
        guard AppDelegate.isWriteClosed == false else { return }
        guard let command = TaskListWidgetActionCommand.loadPending() else { return }

        if command.expiresAt <= Date() {
            TaskListWidgetActionCommand.clearPending()
            return
        }

        processWidgetActionCommand(command, attemptsRemaining: 2)
    }

    func processWidgetActionCommand(_ command: TaskListWidgetActionCommand, attemptsRemaining: Int) {
        guard let viewModel else { return }

        guard let task = viewModel.taskSnapshot(for: command.taskID) else {
            guard attemptsRemaining > 0 else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            viewModel.loadTodayTasks()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.processWidgetActionCommand(command, attemptsRemaining: attemptsRemaining - 1)
            }
            return
        }

        switch command.action {
        case .complete:
            guard task.isComplete == false else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            viewModel.setTaskCompletion(taskID: task.id, to: true) { _ in
                TaskListWidgetActionCommand.clearPending()
            }
            viewModel.setQuickView(.today)

        case .defer15m, .defer60m:
            guard task.isComplete == false else {
                TaskListWidgetActionCommand.clearPending()
                return
            }
            let deferMinutes = command.action == .defer15m ? 15 : 60
            let idempotenceThreshold = command.createdAt.addingTimeInterval(TimeInterval(max(deferMinutes - 1, 1) * 60))
            if let dueDate = task.dueDate, dueDate >= idempotenceThreshold {
                TaskListWidgetActionCommand.clearPending()
                return
            }

            let requestedDate = Date().addingTimeInterval(TimeInterval(deferMinutes * 60))
            let clampedDate = min(requestedDate, Date().addingTimeInterval(24 * 60 * 60))
            viewModel.rescheduleTask(taskID: task.id, to: clampedDate) { _ in
                TaskListWidgetActionCommand.clearPending()
            }
            viewModel.setQuickView(.today)
        }
    }

    func startFocusFlow(task: TaskDefinition?, source: String) {
        guard let viewModel else { return }
        if presentedViewController != nil {
            dismiss(animated: true) { [weak self] in
                self?.startFocusFlow(task: task, source: source)
            }
            return
        }

        viewModel.startFocusSession(taskID: task?.id) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let session):
                    self.presentFocusTimer(task: task, session: session, source: source)
                case .failure(let error):
                    if let focusError = error as? FocusSessionError, case .alreadyActive = focusError {
                        self.resumeActiveFocusSession(source: source)
                    } else {
                        logWarning(
                            event: "focus_session_start_failed",
                            message: "Failed to start focus session",
                            fields: [
                                "source": source,
                                "error": error.localizedDescription
                            ]
                        )
                    }
                }
            }
        }
    }

    func resumeActiveFocusSession(source: String) {
        viewModel?.fetchActiveFocusSession { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let session):
                    guard let session else {
                        self.viewModel?.setQuickView(.today)
                        logWarning(
                            event: "focus_session_resume_missing",
                            message: "Expected an active focus session to resume, but none was found",
                            fields: ["source": source]
                        )
                        return
                    }

                    let task = self.resolveTaskForFocusSession(taskID: session.taskID)
                    self.presentFocusTimer(task: task, session: session, source: "\(source)_resume")
                case .failure(let error):
                    self.viewModel?.setQuickView(.today)
                    logWarning(
                        event: "focus_session_resume_failed",
                        message: "Failed to resume active focus session",
                        fields: [
                            "source": source,
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
        }
    }

    func resolveTaskForFocusSession(taskID: UUID?) -> TaskDefinition? {
        guard let taskID else { return nil }
        var candidates: [TaskDefinition] = []
        candidates.append(contentsOf: viewModel?.focusTasks ?? [])
        candidates.append(contentsOf: viewModel?.morningTasks ?? [])
        candidates.append(contentsOf: viewModel?.eveningTasks ?? [])
        candidates.append(contentsOf: viewModel?.overdueTasks ?? [])
        return candidates.first(where: { $0.id == taskID })
    }

    func presentFocusTimer(task: TaskDefinition?, session: FocusSessionDefinition, source: String) {
        let timerView = SunriseFocusTimerView(
            taskTitle: task?.title,
            taskPriority: task?.priority.displayName,
            targetDurationSeconds: session.targetDurationSeconds,
            onComplete: { [weak self] _ in
                self?.dismiss(animated: true) {
                    self?.finishFocusSession(sessionID: session.id, source: source)
                }
            },
            onCancel: { [weak self] in
                self?.dismiss(animated: true) {
                    self?.finishFocusSession(sessionID: session.id, source: "\(source)_cancel")
                }
            }
        )
        let host = UIHostingController(rootView: timerView)
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
    }

    func finishFocusSession(sessionID: UUID, source: String) {
        viewModel?.endFocusSession(sessionID: sessionID) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let focusResult):
                    self.presentFocusSummary(focusResult)
                    self.viewModel?.trackHomeInteraction(
                        action: "focus_session_finished",
                        metadata: [
                            "source": source,
                            "duration_seconds": focusResult.session.durationSeconds,
                            "awarded_xp": focusResult.xpResult?.awardedXP ?? 0
                        ]
                    )
                case .failure(let error):
                    logWarning(
                        event: "focus_session_end_failed",
                        message: "Failed to end focus session",
                        fields: [
                            "source": source,
                            "error": error.localizedDescription
                        ]
                    )
                }
            }
        }
    }

    func presentFocusSummary(_ result: FocusSessionResult) {
        guard let viewModel else { return }
        let summaryView = SunriseFocusSessionSummaryView(
            durationSeconds: result.session.durationSeconds,
            xpAwarded: result.xpResult?.awardedXP ?? result.session.xpAwarded,
            dailyXPSoFar: result.xpResult?.dailyXPSoFar ?? viewModel.dailyScore,
            onDismiss: { [weak self] in
                self?.dismiss(animated: true)
            },
            onContinueMomentum: { [weak self] in
                self?.viewModel?.setQuickView(.today)
                self?.dismiss(animated: true)
            }
        )
        let host = UIHostingController(rootView: summaryView)
        host.modalPresentationStyle = .pageSheet
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(host, animated: true)
    }

    func handleNotificationRoute(_ route: LifeBoardNotificationRoute) {
        guard viewModel != nil else { return }
        navigationCoordinator.handle(.notificationRoute(route))
    }

    func resolveAndPresentTaskDetail(taskID: UUID, attemptsRemaining: Int = 2) {
        if let task = viewModel?.taskSnapshot(for: taskID) {
            if isUsingIPadNativeShell {
                iPadShellState.destination = .tasks
                if currentLayoutClass == .padExpanded {
                    iPadShellState.selectedTask = task
                } else {
                    presentTaskDetailView(for: task)
                }
            } else {
                presentTaskDetailView(for: task)
            }
            return
        }
        guard attemptsRemaining > 0 else { return }
        viewModel?.loadTodayTasks()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.resolveAndPresentTaskDetail(taskID: taskID, attemptsRemaining: attemptsRemaining - 1)
        }
    }

    func presentDailySummaryModal(kind: LifeBoardDailySummaryKind, dateStamp: String?) {
        guard let viewModel else { return }

        let presentSummary: @Sendable (DailySummaryModalData) -> Void = { [weak self] summary in
            Task { @MainActor in
            guard let self else { return }
            let dismissSummary: (@escaping () -> Void) -> Void = { [weak self] completion in
                self?.dismiss(animated: true) {
                    self?.scheduleOnboardingEvaluationIfNeeded()
                    self?.onboardingCoordinator?.drainPendingPresentationIfPossible()
                    completion()
                }
            }

            let summaryView = DailySummaryModalView(
                summary: summary,
                onDismiss: {
                    dismissSummary {}
                },
                onStartToday: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "start_today", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.trackDailySummaryActionResult(cta: "start_today", success: true, error: nil)
                    dismissSummary {}
                },
                onCompleteMorningRoutine: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "complete_morning_routine", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.completeMorningRoutine { result in
                        let succeeded: Bool
                        let errorDescription: String?
                        switch result {
                        case .success:
                            succeeded = true
                            errorDescription = nil
                        case .failure(let error):
                            succeeded = false
                            errorDescription = error.localizedDescription
                        }
                        Task { @MainActor in
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "complete_morning_routine",
                                success: succeeded,
                                errorDescription: errorDescription
                            )
                        }
                    }
                    dismissSummary {}
                },
                onStartTriage: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "start_triage", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.startTriage(scope: .visible)
                    self.viewModel.trackDailySummaryActionResult(cta: "start_triage", success: true, error: nil)
                    dismissSummary {}
                },
                onRescueOverdue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "rescue_overdue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.openRescue()
                    self.viewModel.trackDailySummaryActionResult(cta: "rescue_overdue", success: true, error: nil)
                    dismissSummary {}
                },
                onAddTask: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "add_task", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.trackDailySummaryActionResult(cta: "add_task", success: true, error: nil)
                    dismissSummary {
                        self.AddTaskAction()
                    }
                },
                onPlanTomorrow: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "plan_tomorrow", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.performEndOfDayCleanup { result in
                        let succeeded: Bool
                        let errorDescription: String?
                        switch result {
                        case .success:
                            succeeded = true
                            errorDescription = nil
                        case .failure(let error):
                            succeeded = false
                            errorDescription = error.localizedDescription
                        }
                        Task { @MainActor in
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "plan_tomorrow",
                                success: succeeded,
                                errorDescription: errorDescription
                            )
                        }
                    }
                    dismissSummary {}
                },
                onReviewDone: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "review_done", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.done)
                    self.viewModel.trackDailySummaryActionResult(cta: "review_done", success: true, error: nil)
                    dismissSummary {}
                },
                onRescheduleOverdue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "reschedule_overdue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.rescheduleOverdueTasks { result in
                        let succeeded: Bool
                        let errorDescription: String?
                        switch result {
                        case .success:
                            succeeded = true
                            errorDescription = nil
                        case .failure(let error):
                            succeeded = false
                            errorDescription = error.localizedDescription
                        }
                        Task { @MainActor in
                            self.viewModel.trackDailySummaryActionResult(
                                cta: "reschedule_overdue",
                                success: succeeded,
                                errorDescription: errorDescription
                            )
                        }
                    }
                    dismissSummary {}
                },
                onOpenRescue: { [weak self] in
                    guard let self else { return }
                    self.viewModel.trackDailySummaryCTA(kind: kind, cta: "open_rescue", countsSnapshot: summary.analyticsSnapshot)
                    self.viewModel.setQuickView(.today)
                    self.viewModel.openRescue()
                    self.viewModel.trackDailySummaryActionResult(cta: "open_rescue", success: true, error: nil)
                    dismissSummary {}
                }
            )

            let hostingController = UIHostingController(rootView: summaryView)
            hostingController.view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
            hostingController.view.accessibilityIdentifier = "home.dailySummaryModal"
            hostingController.modalPresentationStyle = .pageSheet
            hostingController.presentationController?.delegate = self

            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = LifeBoardThemeManager.shared.currentTheme.tokens.corner.modal
                sheet.prefersScrollingExpandsWhenScrolledToEdge = true
            }

            self.present(hostingController, animated: true)
            }
        }

        viewModel.loadDailySummaryModal(kind: kind, dateStamp: dateStamp) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .failure:
                    presentSummary(self.fallbackDailySummary(kind: kind, dateStamp: dateStamp))
                case .success(let summary):
                    presentSummary(summary)
                }
            }
        }
    }

    func presentReflectPlanFlow(preferredReflectionDate: Date?) {
        guard let viewModel else { return }
        guard let presentationDependencyContainer else { return }

        let reflectPlanViewModel = presentationDependencyContainer.makeDailyReflectPlanViewModel(
            preferredReflectionDate: preferredReflectionDate,
            analyticsTracker: { [weak self] action, metadata in
                self?.viewModel?.trackHomeInteraction(
                    action: action,
                    metadata: metadata.reduce(into: [String: Any]()) { partialResult, item in
                        partialResult[item.key] = item.value
                    }
                )
            },
            onComplete: { [weak self] result in
                self?.viewModel?.refreshAfterDailyReflectPlanSave(planningDate: result.target.planningDate)
                self?.dismiss(animated: true)
            }
        )

        let hostingController = UIHostingController(
            rootView: SunriseReflectPlanScreen(
                viewModel: reflectPlanViewModel,
                onClose: { [weak self] in
                    self?.dismiss(animated: true)
                }
            )
        )

        if traitCollection.horizontalSizeClass == .compact {
            hostingController.modalPresentationStyle = .fullScreen
        } else {
            hostingController.modalPresentationStyle = .pageSheet
            if let sheet = hostingController.sheetPresentationController {
                sheet.detents = [.large()]
                sheet.prefersGrabberVisible = true
            }
        }

        present(hostingController, animated: true)
        viewModel.trackHomeInteraction(
            action: "reflection_opened",
            metadata: ["source": "notification_nightly"]
        )
    }

    func fallbackDailySummary(kind: LifeBoardDailySummaryKind, dateStamp: String?) -> DailySummaryModalData {
        let date = fallbackSummaryDate(from: dateStamp)
        switch kind {
        case .morning:
            return .morning(
                MorningPlanSummary(
                    date: date,
                    openTodayCount: 0,
                    highPriorityCount: 0,
                    overdueCount: 0,
                    potentialXP: 0,
                    focusTasks: [],
                    blockedCount: 0,
                    longTaskCount: 0,
                    morningPlannedCount: 0,
                    eveningPlannedCount: 0
                )
            )
        case .nightly:
            return .nightly(
                NightlyRetrospectiveSummary(
                    date: date,
                    completedCount: 0,
                    totalCount: 0,
                    xpEarned: 0,
                    completionRate: 0,
                    streakCount: 0,
                    biggestWins: [],
                    carryOverDueTodayCount: 0,
                    carryOverOverdueCount: 0,
                    tomorrowPreview: [],
                    morningCompletedCount: 0,
                    eveningCompletedCount: 0
                )
            )
        }
    }

    func dateFromStamp(_ stamp: String?) -> Date? {
        guard let stamp, stamp.isEmpty == false else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.autoupdatingCurrent.timeZone
        return formatter.date(from: stamp)
    }

    func fallbackSummaryDate(from dateStamp: String?) -> Date {
        guard let dateStamp, dateStamp.count == 8 else { return Date() }
        var components = DateComponents()
        components.year = Int(dateStamp.prefix(4))
        components.month = Int(dateStamp.dropFirst(4).prefix(2))
        components.day = Int(dateStamp.suffix(2))
        return Calendar.current.date(from: components) ?? Date()
    }

    // MARK: - Insights Refresh Contract

    /// Executes refreshInsightsAfterTaskCompletion.
    func refreshInsightsAfterTaskCompletion() {
        refreshInsightsAfterTaskMutation(reason: .completed)
    }

    /// Executes refreshInsightsAfterTaskMutation.
    func refreshInsightsAfterTaskMutation(reason: HomeTaskMutationEvent? = nil) {
        if let reason {
            logDebug("🎯 HomeViewController insights refresh reason=\(reason.rawValue)")
        }
        insightsViewModel?.refresh()
        faceCoordinator.insightsViewModel?.refresh()
    }

    // MARK: - Theme

    /// Executes applyTheme.
    func applyTheme() {
        view.backgroundColor = LifeBoardThemeManager.shared.currentTheme.tokens.color.bgCanvas
    }
}
