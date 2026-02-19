import UIKit
import FSCalendar
import MaterialComponents

extension AddTaskViewController {

    // Backdrop identical to HomeVC – extracted for reuse
    func setupBackdrop() {
        backdropContainer.frame = view.bounds
        backdropContainer.backgroundColor = todoColors.bgCanvas
    }

    // The main foredrop sheet
    func setupAddTaskForedrop() {
        // Position the foredrop container below the calendar
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let safeAreaBottomInset = view.safeAreaInsets.bottom
        
        // Calculate position dynamically based on calendar position
        let calendarStartY = homeTopBar.frame.maxY - 6
        let calendarHeight = homeTopBar.frame.maxY
        let foredropTopY = calendarStartY + calendarHeight + 10 // Add 10pt padding
        let foredropHeight = screenHeight - foredropTopY - safeAreaBottomInset - 20
        
        foredropContainer.frame = CGRect(x: 0, 
                                       y: foredropTopY, 
                                       width: screenWidth, 
                                       height: foredropHeight)
        foredropContainer.backgroundColor = todoColors.surfacePrimary
        foredropContainer.layer.cornerRadius = 24
        foredropContainer.clipsToBounds = false
        foredropContainer.applyTaskerElevation(.e1)
        
        view.addSubview(foredropContainer)

        foredropStackContainer.translatesAutoresizingMaskIntoConstraints = false
        foredropContainer.addSubview(foredropStackContainer)
        NSLayoutConstraint.activate([
            foredropStackContainer.leadingAnchor.constraint(equalTo: foredropContainer.leadingAnchor, constant: 16),
            foredropStackContainer.trailingAnchor.constraint(equalTo: foredropContainer.trailingAnchor, constant: -16),
            foredropStackContainer.topAnchor.constraint(equalTo: foredropContainer.topAnchor, constant: 20),
            foredropStackContainer.bottomAnchor.constraint(lessThanOrEqualTo: foredropContainer.bottomAnchor, constant: -20)
        ])
    }

    // Pills across the top for project picking - method moved to AddTaskForedropView.swift to avoid duplicate declaration

    // MARK: – Actions wired from selectors

    @objc func cancelAddTaskAction() {
        dismiss(animated: true)
    }

    @objc func doneAddTaskAction() {
        guard !currentTaskInMaterialTextBox.isEmpty else { 
            return 
        }
        
        logDebug("🚀 AddTask: Starting task creation process...")
        logDebug("📝 AddTask: Task name: '\(currentTaskInMaterialTextBox)'")
        logDebug("📅 AddTask: Due date: \(dateForAddTaskView)")
        logDebug("📁 AddTask: Project: '\(currenttProjectForAddTaskView)'")
        createTaskUsingViewModel()
    }
    
    // MARK: - Clean Architecture Task Creation

    private func createTaskUsingViewModel() {
        guard let viewModel else {
            showCleanArchitectureError("Task service unavailable")
            return
        }

        let selectedProjectName = currenttProjectForAddTaskView.isEmpty
            ? ProjectConstants.inboxProjectName
            : currenttProjectForAddTaskView

        viewModel.taskName = currentTaskInMaterialTextBox
        viewModel.taskDetails = currentTaskDescription
        viewModel.selectedType = isThisEveningTask ? .evening : .morning
        viewModel.selectedPriority = currentTaskPriority
        viewModel.dueDate = dateForAddTaskView
        viewModel.selectedProject = selectedProjectName
        viewModel.hasReminder = alertReminderTime != nil
        if let alertReminderTime {
            viewModel.reminderTime = alertReminderTime
        }

        // Parent relationship and dependency links are independent; avoid self-conflicting metadata choices.
        if let selectedParentTaskID = viewModel.selectedParentTaskID {
            viewModel.selectedDependencyTaskIDs.remove(selectedParentTaskID)
        }

        viewModel.createTask()
    }
    
    // MARK: - Helper Methods
    
    /// Show error for Clean Architecture failures
    private func showCleanArchitectureError(_ message: String) {
        let alert = UIAlertController(
            title: "Clean Architecture Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// Show error for legacy failures
    private func showLegacyError(_ message: String) {
        let alert = UIAlertController(
            title: "Error Creating Task",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
