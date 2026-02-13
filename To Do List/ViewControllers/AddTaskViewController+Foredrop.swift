import UIKit
import FluentUI
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
            print("⚠️ AddTask: Task name is empty, returning early")
            return 
        }
        
        print("🚀 AddTask: Starting task creation process...")
        print("📝 AddTask: Task name: '\(currentTaskInMaterialTextBox)'")
        print("📅 AddTask: Due date: \(dateForAddTaskView)")
        print("📁 AddTask: Project: '\(currenttProjectForAddTaskView)'")
        print("🤝 AddTask: Delegate is set: \(delegate != nil)")
        
        // TODO: Re-enable when ViewModel is available
        // CHECK CLEAN ARCHITECTURE FIRST
        // if let viewModel = viewModel {
        //     print("✅ AddTask: Using Clean Architecture with ViewModel")
        //     createTaskUsingViewModel(viewModel)
        // } else {
            print("⚠️ AddTask: ViewModel not available, using legacy repository method")
            createTaskUsingRepository()
        // }
    }
    
    // MARK: - Clean Architecture Task Creation

    /// Create task using Clean Architecture ViewModel
    /// TODO: Re-enable when ViewModel is available
    // private func createTaskUsingViewModel(_ viewModel: AddTaskViewModel) {
    //     print("🏗️ AddTask: Creating task via ViewModel (Clean Architecture)")
    //
    //     // TODO: The ViewModel API has changed - this needs to be refactored to use the new API
    //     // For now, using legacy repository to avoid breaking the flow
    //     print("⚠️ AddTask: ViewModel API refactor needed - using legacy path")
    //
    //     /* New API expects:
    //     viewModel.taskName = currentTaskInMaterialTextBox
    //     viewModel.taskDetails = currentTaskDescription
    //     viewModel.selectedType = isThisEveningTask ? .evening : .morning
    //     viewModel.selectedPriority = currentTaskPriority
    //     viewModel.dueDate = dateForAddTaskView
    //     viewModel.selectedProject = currenttProjectForAddTaskView.isEmpty ? "Inbox" : currenttProjectForAddTaskView
    //     viewModel.createTask()
    //
    //     // Then subscribe to @Published properties for result
    //     viewModel.$isTaskCreated.sink { isCreated in
    //         if isCreated {
    //             // Handle success
    //         }
    //     }
    //     viewModel.$errorMessage.sink { error in
    //         if let error = error {
    //             // Handle error
    //         }
    //     }
    //     */
    //
    //     // For now, fall back to legacy repository path
    //     let request = CreateTaskRequest(
    //         name: currentTaskInMaterialTextBox,
    //         details: currentTaskDescription.isEmpty ? nil : currentTaskDescription,
    //         type: isThisEveningTask ? .evening : .morning,
    //         priority: currentTaskPriority,
    //         dueDate: dateForAddTaskView,
    //         project: currenttProjectForAddTaskView.isEmpty ? "Inbox" : currenttProjectForAddTaskView
    //     )
    //
    //     // TODO: Use legacy repository until ViewModel integration is complete
    //     // The TaskRepository API doesn't match - needs migration
    //     print("⚠️ AddTask: Falling back to legacy addTask path - Clean Architecture ViewModel not fully integrated yet")
    // }
    
    /// Legacy task creation using repository (fallback)
    private func createTaskUsingRepository() {
        print("🔧 AddTask: Using legacy repository method")
        // CRITICAL: Check taskRepository state before using it
        print("🔍 AddTask: Checking taskRepository state...")
        if taskRepository == nil {
            print("❌ AddTask: CRITICAL ERROR - taskRepository is nil!")
            print("🔧 AddTask: This indicates dependency injection failed")
            print("📊 AddTask: View controller type: \(String(describing: type(of: self)))")
            print("🏗️ AddTask: Attempting to get repository from DependencyContainer...")
            
            // Fallback: try to get repository from dependency container
            if let fallbackRepository = DependencyContainer.shared.taskRepository {
                print("✅ AddTask: Found fallback repository from DependencyContainer")
                taskRepository = fallbackRepository
            } else {
                print("💥 AddTask: FATAL - No repository available anywhere!")
                showLegacyError("Unable to save task. Please try again.")
                return
            }
        } else {
            print("✅ AddTask: taskRepository is properly initialized")
            print("📊 AddTask: Repository type: \(String(describing: type(of: taskRepository)))")
        }
        
        // Continue with legacy task creation...
        let taskType: Int32 = isThisEveningTask ? 2 : 1
        print("🌅 AddTask: Task type: \(taskType)")
        
        let taskData = TaskData(
            name: currentTaskInMaterialTextBox,
            details: currentTaskDescription.isEmpty ? nil : currentTaskDescription,
            type: taskType,
            priorityRawValue: Int32(currentTaskPriority.rawValue),
            dueDate: dateForAddTaskView,
            project: currenttProjectForAddTaskView,
            alertReminderTime: alertReminderTime
        )
        print("📦 AddTask: TaskData created successfully")
        
        taskRepository.addTask(data: taskData) { [weak self] (result: Result<NTask, Error>) in
            DispatchQueue.main.async {
                switch result {
                case .success(let createdTask):
                    print("✅ AddTask: Legacy task created successfully!")
                    self?.dismiss(animated: true) {
                        self?.delegate?.didAddTask(createdTask)
                    }
                    
                case .failure(let error):
                    print("❌ AddTask: Legacy task creation failed: \(error)")
                    self?.showLegacyError("Failed to create task: \(error.localizedDescription)")
                }
            }
        }
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
